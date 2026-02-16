import SwiftUI
import AppKit

/// Full export tab with queue, options, and progress
struct ExportTab: View {
    @ObservedObject var viewModel: ExportViewModel
    @State private var expandedFolders: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isEmpty {
                emptyState
            } else if viewModel.isExporting {
                progressView
            } else if case .idle = viewModel.completionState {
                queueContent
            } else {
                completionView
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("Export Queue Empty")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Add notes from search results\nusing the + button")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Queue Content

    private var queueContent: some View {
        VStack(spacing: 0) {
            // Queue header with counts
            queueHeader
                .padding(.horizontal)
                .padding(.vertical, 8)

            Divider()

            // Queue list grouped by folder
            queueList

            Divider()

            // Export options
            exportOptions
                .padding()

            Divider()

            // Actions footer
            actionsFooter
                .padding()
        }
    }

    private var queueHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(viewModel.queueCount) note(s)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("\(viewModel.selectedCount) selected")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Select/Deselect all
            Menu {
                Button("Select All") { viewModel.selectAll() }
                Button("Deselect All") { viewModel.deselectAll() }
                Divider()
                Button("Clear Queue", role: .destructive) { viewModel.clearQueue() }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
        }
    }

    private var queueList: some View {
        List {
            ForEach(viewModel.queueByFolder, id: \.folder) { group in
                Section {
                    ForEach(group.items) { item in
                        queueRow(item)
                    }
                } header: {
                    folderHeader(group.folder, itemCount: group.items.count)
                }
            }
        }
        .listStyle(.plain)
    }

    private func folderHeader(_ folder: String, itemCount: Int) -> some View {
        HStack {
            Image(systemName: "folder")
                .foregroundColor(.secondary)
            Text(folder)
                .fontWeight(.medium)
            Text("(\(itemCount))")
                .foregroundColor(.secondary)
        }
        .font(.caption)
    }

    private func queueRow(_ item: ExportQueueItem) -> some View {
        HStack(spacing: 8) {
            // Checkbox
            Button(action: { viewModel.toggleSelection(item) }) {
                Image(systemName: item.isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(item.isSelected ? .accentColor : .secondary)
            }
            .buttonStyle(.plain)

            // Title
            Text(item.title)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Remove button
            Button(action: { viewModel.removeFromQueue(item) }) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Remove from queue")
        }
        .padding(.vertical, 2)
    }

    // MARK: - Export Options

    private var exportOptions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Options")
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            // Format picker
            HStack {
                Text("Format:")
                    .frame(width: 80, alignment: .leading)
                Picker("", selection: $viewModel.format) {
                    ForEach(ExportFormat.allCases, id: \.self) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            // Frontmatter toggle (Markdown only)
            if viewModel.format == .markdown {
                Toggle("Include frontmatter", isOn: $viewModel.includeFrontmatter)
                    .font(.callout)
            }

            // JSON metadata toggle
            if viewModel.format == .json {
                Toggle("Full metadata", isOn: $viewModel.jsonFullMetadata)
                    .font(.callout)
            }

            // Attachments toggle
            Toggle("Include attachments", isOn: $viewModel.includeAttachments)
                .font(.callout)

            Divider()

            // Location picker
            HStack {
                Text("Location:")
                    .frame(width: 80, alignment: .leading)

                if let url = viewModel.outputURL {
                    Text(url.lastPathComponent)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text("Not selected")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button("Choose...") {
                    pickExportLocation()
                }
                .controlSize(.small)
            }
        }
    }

    // MARK: - Actions Footer

    private var actionsFooter: some View {
        HStack {
            Button("Clear") {
                viewModel.clearQueue()
            }
            .controlSize(.small)

            Spacer()

            Button("Export") {
                viewModel.startExport()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .disabled(!viewModel.canExport)
        }
    }

    // MARK: - Progress View

    private var progressView: some View {
        VStack(spacing: 16) {
            Spacer()

            if let progress = viewModel.progress {
                VStack(spacing: 12) {
                    ProgressView(value: progress.percentage)
                        .progressViewStyle(.linear)

                    Text("Exporting \(progress.current + 1) of \(progress.total)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if !progress.currentTitle.isEmpty {
                        Text(progress.currentTitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 32)
            } else {
                ProgressView()
            }

            Button("Cancel") {
                viewModel.cancelExport()
            }
            .controlSize(.small)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Completion View

    private var completionView: some View {
        VStack(spacing: 16) {
            Spacer()

            switch viewModel.completionState {
            case .success(let exported, let location):
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.green)
                Text("Export Complete")
                    .font(.headline)
                Text("\(exported) note(s) exported")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    Button("Show in Finder") {
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: location.path)
                    }
                    Button("Done") {
                        viewModel.dismissCompletion()
                        viewModel.clearQueue()
                    }
                    .buttonStyle(.borderedProminent)
                }

            case .partial(let exported, let failed, let failures):
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.orange)
                Text("Export Partially Complete")
                    .font(.headline)
                Text("\(exported) exported, \(failed) failed")
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Show first few failures
                if !failures.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(failures.prefix(3), id: \.noteId) { failure in
                            Text("• \(failure.title): \(failure.error)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        if failures.count > 3 {
                            Text("...and \(failures.count - 3) more")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                }

                HStack(spacing: 12) {
                    Button("Retry Failed") {
                        viewModel.dismissCompletion()
                        // Queue still contains items, user can retry
                    }
                    Button("Done") {
                        viewModel.dismissCompletion()
                        viewModel.clearQueue()
                    }
                    .buttonStyle(.borderedProminent)
                }

            case .cancelled(let completed, let remaining):
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text("Export Cancelled")
                    .font(.headline)
                Text("\(completed) completed, \(remaining) remaining")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button("Done") {
                    viewModel.dismissCompletion()
                }
                .buttonStyle(.borderedProminent)

            case .error(let message):
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.red)
                Text("Export Failed")
                    .font(.headline)
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    Button("Retry") {
                        viewModel.dismissCompletion()
                    }
                    Button("Done") {
                        viewModel.dismissCompletion()
                        viewModel.clearQueue()
                    }
                    .buttonStyle(.borderedProminent)
                }

            case .idle:
                EmptyView()
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    // MARK: - Helpers

    private func pickExportLocation() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.message = "Choose export location"
        panel.prompt = "Select"

        if panel.runModal() == .OK {
            viewModel.outputURL = panel.url
        }
    }
}
