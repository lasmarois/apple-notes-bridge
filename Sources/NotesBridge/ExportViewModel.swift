import Foundation
import SwiftUI
import NotesLib

/// Item in the export queue
struct ExportQueueItem: Identifiable, Hashable {
    let id: String
    let title: String
    let folder: String?
    var isSelected: Bool = true

    init(from result: SearchResult) {
        self.id = result.id
        self.title = result.title
        self.folder = result.folder
    }

    init(id: String, title: String, folder: String?) {
        self.id = id
        self.title = title
        self.folder = folder
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: ExportQueueItem, rhs: ExportQueueItem) -> Bool {
        lhs.id == rhs.id
    }
}

/// Export format options
enum ExportFormat: String, CaseIterable {
    case markdown = "Markdown"
    case json = "JSON"

    var fileExtension: String {
        switch self {
        case .markdown: return "md"
        case .json: return "json"
        }
    }
}

/// Progress state during export
struct ExportProgress {
    var current: Int
    var total: Int
    var currentTitle: String
    var isCancelled: Bool = false

    var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(current) / Double(total)
    }
}

/// Result state after export completes
enum ExportCompletionState {
    case idle
    case success(exported: Int, location: URL)
    case partial(exported: Int, failed: Int, failures: [ExportFailure])
    case cancelled(completed: Int, remaining: Int)
    case error(String)
}

/// Manages the export queue and export operations
@MainActor
class ExportViewModel: ObservableObject {
    // MARK: - Queue State

    @Published var queue: [ExportQueueItem] = []
    @Published var isExporting: Bool = false
    @Published var progress: ExportProgress?
    @Published var completionState: ExportCompletionState = .idle

    // MARK: - Export Options

    @Published var format: ExportFormat = .markdown
    @Published var includeFrontmatter: Bool = true
    @Published var includeAttachments: Bool = false
    @Published var jsonFullMetadata: Bool = false
    @Published var outputURL: URL?

    // MARK: - Private

    private let database = NotesDatabase()
    private var exporter: NotesExporter?
    private var exportTask: Task<Void, Never>?

    // MARK: - Computed Properties

    var queueCount: Int { queue.count }

    var selectedCount: Int { queue.filter { $0.isSelected }.count }

    var isEmpty: Bool { queue.isEmpty }

    var canExport: Bool {
        !queue.isEmpty && selectedCount > 0 && outputURL != nil && !isExporting
    }

    /// Queue grouped by folder for display
    var queueByFolder: [(folder: String, items: [ExportQueueItem])] {
        let grouped = Dictionary(grouping: queue) { $0.folder ?? "Notes" }
        return grouped.map { (folder: $0.key, items: $0.value) }
            .sorted { $0.folder < $1.folder }
    }

    // MARK: - Initialization

    init() {
        exporter = NotesExporter(database: database)
    }

    // MARK: - Queue Management

    /// Add a single item to the queue
    func addToQueue(_ result: SearchResult) {
        // Don't add duplicates
        guard !queue.contains(where: { $0.id == result.id }) else { return }
        queue.append(ExportQueueItem(from: result))
    }

    /// Add multiple items to the queue
    func addAllToQueue(_ results: [SearchResult]) {
        for result in results {
            addToQueue(result)
        }
    }

    /// Remove an item from the queue
    func removeFromQueue(_ item: ExportQueueItem) {
        queue.removeAll { $0.id == item.id }
    }

    /// Remove item by ID
    func removeFromQueue(id: String) {
        queue.removeAll { $0.id == id }
    }

    /// Toggle selection state of an item
    func toggleSelection(_ item: ExportQueueItem) {
        if let index = queue.firstIndex(where: { $0.id == item.id }) {
            queue[index].isSelected.toggle()
        }
    }

    /// Select all items
    func selectAll() {
        for index in queue.indices {
            queue[index].isSelected = true
        }
    }

    /// Deselect all items
    func deselectAll() {
        for index in queue.indices {
            queue[index].isSelected = false
        }
    }

    /// Clear the entire queue
    func clearQueue() {
        queue.removeAll()
        completionState = .idle
    }

    /// Check if an item is already in the queue
    func isInQueue(id: String) -> Bool {
        queue.contains { $0.id == id }
    }

    // MARK: - Export Operations

    /// Start the export operation
    func startExport() {
        guard canExport, let outputURL = outputURL, let exporter = exporter else { return }

        let selectedItems = queue.filter { $0.isSelected }
        guard !selectedItems.isEmpty else { return }

        isExporting = true
        completionState = .idle
        progress = ExportProgress(current: 0, total: selectedItems.count, currentTitle: "")

        exportTask = Task {
            var exported = 0
            var failures: [ExportFailure] = []

            let options = ExportOptions(
                includeFrontmatter: includeFrontmatter,
                includeHTML: false,
                fullMetadata: jsonFullMetadata,
                includeAttachments: includeAttachments
            )

            let formatter: NoteFormatter = format == .json ? JSONFormatter() : MarkdownFormatter()

            for (index, item) in selectedItems.enumerated() {
                // Check for cancellation
                if Task.isCancelled || progress?.isCancelled == true {
                    completionState = .cancelled(completed: exported, remaining: selectedItems.count - index)
                    break
                }

                progress = ExportProgress(
                    current: index,
                    total: selectedItems.count,
                    currentTitle: item.title
                )

                do {
                    let content: String
                    if format == .markdown {
                        content = try exporter.exportNoteStyled(id: item.id, options: options)
                    } else {
                        content = try exporter.exportNote(id: item.id, formatter: formatter, options: options)
                    }

                    // Write to file
                    let filename = safeFilename(item.title) + ".\(format.fileExtension)"
                    let fileURL = outputURL.appendingPathComponent(filename)
                    try content.write(to: fileURL, atomically: true, encoding: .utf8)

                    exported += 1
                } catch {
                    failures.append(ExportFailure(
                        noteId: item.id,
                        title: item.title,
                        error: error.localizedDescription
                    ))
                }
            }

            // Update final progress
            progress = ExportProgress(
                current: selectedItems.count,
                total: selectedItems.count,
                currentTitle: ""
            )

            // Set completion state
            if progress?.isCancelled != true {
                if failures.isEmpty {
                    completionState = .success(exported: exported, location: outputURL)
                } else if exported > 0 {
                    completionState = .partial(exported: exported, failed: failures.count, failures: failures)
                } else {
                    completionState = .error("All exports failed")
                }
            }

            isExporting = false
        }
    }

    /// Cancel the current export operation
    func cancelExport() {
        progress?.isCancelled = true
        exportTask?.cancel()
    }

    /// Reset completion state to idle
    func dismissCompletion() {
        completionState = .idle
    }

    // MARK: - Helpers

    private func safeFilename(_ name: String) -> String {
        var safe = name
        let replacements: [(String, String)] = [
            ("/", "-"),
            (":", "-"),
            ("\"", ""),
            ("<", ""),
            (">", ""),
            ("|", "-"),
            ("?", ""),
            ("*", ""),
            ("\\", "-")
        ]

        for (from, to) in replacements {
            safe = safe.replacingOccurrences(of: from, with: to)
        }

        safe = safe.trimmingCharacters(in: .whitespaces)
        if safe.count > 200 {
            safe = String(safe.prefix(200))
        }

        if safe.isEmpty {
            safe = "Untitled"
        }

        return safe
    }
}
