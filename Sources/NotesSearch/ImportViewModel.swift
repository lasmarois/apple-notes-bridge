import Foundation
import SwiftUI
import NotesLib

/// Item in the import staging area
struct ImportStagingItem: Identifiable, Hashable {
    let id: UUID
    let fileURL: URL
    let title: String
    let folder: String?
    var conflict: ImportConflict?
    var isSelected: Bool = true

    var filename: String {
        fileURL.lastPathComponent
    }

    var hasConflict: Bool {
        conflict != nil
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: ImportStagingItem, rhs: ImportStagingItem) -> Bool {
        lhs.id == rhs.id
    }
}

/// Progress state during import
struct ImportProgress {
    var current: Int
    var total: Int
    var currentTitle: String
    var isCancelled: Bool = false

    var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(current) / Double(total)
    }
}

/// Result state after import completes
enum ImportCompletionState {
    case idle
    case success(imported: Int, location: String?)
    case partial(imported: Int, skipped: Int, failed: Int)
    case cancelled(completed: Int, remaining: Int)
    case error(String)
}

/// Manages the import staging area and import operations
@MainActor
class ImportViewModel: ObservableObject {
    // MARK: - Staging State

    @Published var staging: [ImportStagingItem] = []
    @Published var isImporting: Bool = false
    @Published var isScanning: Bool = false
    @Published var progress: ImportProgress?
    @Published var completionState: ImportCompletionState = .idle

    // MARK: - Import Options

    @Published var defaultFolder: String = "Notes"
    @Published var conflictStrategy: ConflictStrategy = .skip

    // MARK: - Private

    private let database = NotesDatabase()
    private var importer: NotesImporter?
    private var importTask: Task<Void, Never>?
    private let frontmatterParser = FrontmatterParser()

    // MARK: - Computed Properties

    var stagingCount: Int { staging.count }

    var selectedCount: Int { staging.filter { $0.isSelected }.count }

    var conflictCount: Int { staging.filter { $0.hasConflict }.count }

    var isEmpty: Bool { staging.isEmpty }

    var canImport: Bool {
        !staging.isEmpty && selectedCount > 0 && !isImporting
    }

    /// Staging grouped by folder for display
    var stagingByFolder: [(folder: String, items: [ImportStagingItem])] {
        let grouped = Dictionary(grouping: staging) { $0.folder ?? defaultFolder }
        return grouped.map { (folder: $0.key, items: $0.value) }
            .sorted { $0.folder < $1.folder }
    }

    // MARK: - Initialization

    init() {
        importer = NotesImporter(database: database)
    }

    // MARK: - File/Folder Picker

    /// Show file picker for markdown files
    func pickFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.plainText]
        panel.allowsOtherFileTypes = true
        panel.message = "Select Markdown files to import"

        if panel.runModal() == .OK {
            addFiles(panel.urls)
        }
    }

    /// Show folder picker
    func pickFolder() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.message = "Select folder containing Markdown files"

        if panel.runModal() == .OK, let url = panel.url {
            addFolder(url)
        }
    }

    // MARK: - Staging Management

    /// Add files to staging
    func addFiles(_ urls: [URL]) {
        isScanning = true

        Task {
            for url in urls {
                // Filter for markdown files
                let ext = url.pathExtension.lowercased()
                guard ext == "md" || ext == "markdown" || ext == "txt" else { continue }

                // Don't add duplicates
                guard !staging.contains(where: { $0.fileURL == url }) else { continue }

                // Parse the file to get title and folder
                if let item = await parseFile(url) {
                    staging.append(item)
                }
            }

            // Check for conflicts after adding
            await detectAllConflicts()
            isScanning = false
        }
    }

    /// Add all markdown files from a folder
    func addFolder(_ url: URL) {
        isScanning = true

        Task {
            let files = findMarkdownFiles(in: url, recursive: true)
            for fileURL in files {
                // Don't add duplicates
                guard !staging.contains(where: { $0.fileURL == fileURL }) else { continue }

                if let item = await parseFile(fileURL, baseDir: url) {
                    staging.append(item)
                }
            }

            // Check for conflicts after adding
            await detectAllConflicts()
            isScanning = false
        }
    }

    /// Remove an item from staging
    func removeFromStaging(_ item: ImportStagingItem) {
        staging.removeAll { $0.id == item.id }
    }

    /// Remove item by ID
    func removeFromStaging(id: UUID) {
        staging.removeAll { $0.id == id }
    }

    /// Toggle selection state of an item
    func toggleSelection(_ item: ImportStagingItem) {
        if let index = staging.firstIndex(where: { $0.id == item.id }) {
            staging[index].isSelected.toggle()
        }
    }

    /// Select all items
    func selectAll() {
        for index in staging.indices {
            staging[index].isSelected = true
        }
    }

    /// Deselect all items
    func deselectAll() {
        for index in staging.indices {
            staging[index].isSelected = false
        }
    }

    /// Clear the entire staging area
    func clearStaging() {
        staging.removeAll()
        completionState = .idle
    }

    // MARK: - Conflict Detection

    /// Detect conflicts for all staged items
    func detectAllConflicts() async {
        guard let importer = importer else { return }

        for index in staging.indices {
            let item = staging[index]
            let folder = item.folder ?? defaultFolder
            let conflict = importer.detectConflict(title: item.title, folder: folder)
            staging[index].conflict = conflict
        }
    }

    /// Refresh conflict detection (e.g., after changing default folder)
    func refreshConflicts() {
        Task {
            await detectAllConflicts()
        }
    }

    // MARK: - Import Operations

    /// Start the import operation
    func startImport() {
        guard canImport, let importer = importer else { return }

        let selectedItems = staging.filter { $0.isSelected }
        guard !selectedItems.isEmpty else { return }

        isImporting = true
        completionState = .idle
        progress = ImportProgress(current: 0, total: selectedItems.count, currentTitle: "")

        importTask = Task {
            var imported = 0
            var skipped = 0
            var failed = 0

            for (index, item) in selectedItems.enumerated() {
                // Check for cancellation
                if Task.isCancelled || progress?.isCancelled == true {
                    completionState = .cancelled(completed: imported, remaining: selectedItems.count - index)
                    break
                }

                progress = ImportProgress(
                    current: index,
                    total: selectedItems.count,
                    currentTitle: item.title
                )

                let options = ImportOptions(
                    targetFolder: item.folder ?? defaultFolder,
                    conflictStrategy: conflictStrategy,
                    dryRun: false
                )

                do {
                    let result = try importer.importFile(item.fileURL, options: options)

                    if !result.imported.isEmpty {
                        imported += 1
                    } else if !result.skipped.isEmpty {
                        skipped += 1
                    } else if !result.failures.isEmpty {
                        failed += 1
                    }
                } catch {
                    failed += 1
                }
            }

            // Update final progress
            progress = ImportProgress(
                current: selectedItems.count,
                total: selectedItems.count,
                currentTitle: ""
            )

            // Set completion state
            if progress?.isCancelled != true {
                if failed == 0 && skipped == 0 {
                    completionState = .success(imported: imported, location: defaultFolder)
                } else if imported > 0 {
                    completionState = .partial(imported: imported, skipped: skipped, failed: failed)
                } else {
                    completionState = .error("All imports failed")
                }
            }

            isImporting = false
        }
    }

    /// Cancel the current import operation
    func cancelImport() {
        progress?.isCancelled = true
        importTask?.cancel()
    }

    /// Reset completion state to idle
    func dismissCompletion() {
        completionState = .idle
    }

    // MARK: - Private Helpers

    private func parseFile(_ url: URL, baseDir: URL? = nil) async -> ImportStagingItem? {
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            let filename = url.lastPathComponent
            let parsed = frontmatterParser.parse(content, filename: filename)

            // Derive folder from directory structure if baseDir provided
            var folder: String? = parsed.frontmatter.folder
            if folder == nil, let baseDir = baseDir {
                let relativePath = url.deletingLastPathComponent().path
                    .replacingOccurrences(of: baseDir.path, with: "")
                    .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                if !relativePath.isEmpty {
                    folder = relativePath
                }
            }

            return ImportStagingItem(
                id: UUID(),
                fileURL: url,
                title: parsed.resolvedTitle,
                folder: folder
            )
        } catch {
            return nil
        }
    }

    private func findMarkdownFiles(in directory: URL, recursive: Bool) -> [URL] {
        let fm = FileManager.default
        var files: [URL] = []

        let contents: [URL]
        if recursive {
            guard let enumerator = fm.enumerator(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else {
                return []
            }
            contents = enumerator.compactMap { $0 as? URL }
        } else {
            contents = (try? fm.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )) ?? []
        }

        for url in contents {
            let resourceValues = try? url.resourceValues(forKeys: [.isRegularFileKey])
            if resourceValues?.isRegularFile == true {
                let ext = url.pathExtension.lowercased()
                if ext == "md" || ext == "markdown" {
                    files.append(url)
                }
            }
        }

        return files.sorted { $0.path < $1.path }
    }
}
