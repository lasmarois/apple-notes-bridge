import SwiftUI
import AppKit
import UniformTypeIdentifiers
import NotesLib

/// Full import tab with staging, options, and progress
struct ImportTab: View {
    @ObservedObject var viewModel: ImportViewModel
    @State private var isDragOver: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isEmpty {
                emptyState
            } else if viewModel.isImporting {
                progressView
            } else if case .idle = viewModel.completionState {
                stagingContent
            } else {
                completionView
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isDragOver) { providers in
            handleDrop(providers)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
                    .foregroundColor(isDragOver ? .accentColor : .secondary.opacity(0.5))
                    .frame(height: 120)

                VStack(spacing: 8) {
                    Image(systemName: "tray.and.arrow.down")
                        .font(.system(size: 32))
                        .foregroundColor(isDragOver ? .accentColor : .secondary)
                    Text(isDragOver ? "Drop files here" : "Drag files here")
                        .font(.callout)
                        .foregroundColor(isDragOver ? .accentColor : .secondary)
                }
            }
            .padding(.horizontal)
            .animation(.easeInOut(duration: 0.15), value: isDragOver)

            Text("or")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                Button("Add Files...") {
                    viewModel.pickFiles()
                }
                Button("Add Folder...") {
                    viewModel.pickFolder()
                }
            }

            Text("Supports .md and .markdown files")
                .font(.caption2)
                .foregroundColor(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Staging Content

    private var stagingContent: some View {
        VStack(spacing: 0) {
            // Header with counts
            stagingHeader
                .padding(.horizontal)
                .padding(.vertical, 8)

            Divider()

            // Staging list
            stagingList

            Divider()

            // Import options
            importOptions
                .padding()

            Divider()

            // Actions footer
            actionsFooter
                .padding()
        }
    }

    private var stagingHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(viewModel.stagingCount) file(s)")
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack(spacing: 8) {
                    Text("\(viewModel.selectedCount) selected")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if viewModel.conflictCount > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("\(viewModel.conflictCount) conflict(s)")
                        }
                        .font(.caption)
                    }
                }
            }

            Spacer()

            // Menu for actions
            Menu {
                Button("Select All") { viewModel.selectAll() }
                Button("Deselect All") { viewModel.deselectAll() }
                Divider()
                Button("Add Files...") { viewModel.pickFiles() }
                Button("Add Folder...") { viewModel.pickFolder() }
                Divider()
                Button("Refresh Conflicts") { viewModel.refreshConflicts() }
                Divider()
                Button("Clear All", role: .destructive) { viewModel.clearStaging() }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
        }
    }

    private var stagingList: some View {
        List {
            ForEach(viewModel.stagingByFolder, id: \.folder) { group in
                Section {
                    ForEach(group.items) { item in
                        stagingRow(item)
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

    private func stagingRow(_ item: ImportStagingItem) -> some View {
        HStack(spacing: 8) {
            // Checkbox
            Button(action: { viewModel.toggleSelection(item) }) {
                Image(systemName: item.isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(item.isSelected ? .accentColor : .secondary)
            }
            .buttonStyle(.plain)

            // Title and filename
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(item.title)
                        .lineLimit(1)

                    if item.hasConflict {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                            .help("Note with same title exists in target folder")
                    }
                }

                Text(item.filename)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Remove button
            Button(action: { viewModel.removeFromStaging(item) }) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Remove from staging")
        }
        .padding(.vertical, 2)
    }

    // MARK: - Import Options

    private var importOptions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Options")
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            // Default folder
            HStack {
                Text("Folder:")
                    .frame(width: 80, alignment: .leading)

                TextField("Notes", text: $viewModel.defaultFolder)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
                    .onChange(of: viewModel.defaultFolder) { _ in
                        viewModel.refreshConflicts()
                    }
            }

            // Conflict strategy
            HStack(alignment: .top) {
                Text("Conflicts:")
                    .frame(width: 80, alignment: .leading)

                VStack(alignment: .leading, spacing: 4) {
                    Picker("", selection: $viewModel.conflictStrategy) {
                        Text("Skip").tag(ConflictStrategy.skip)
                        Text("Replace").tag(ConflictStrategy.replace)
                        Text("Duplicate").tag(ConflictStrategy.duplicate)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    Text(conflictStrategyDescription)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var conflictStrategyDescription: String {
        switch viewModel.conflictStrategy {
        case .skip:
            return "Skip files that conflict with existing notes"
        case .replace:
            return "Replace existing notes with imported content"
        case .duplicate:
            return "Import as new notes (may create duplicates)"
        case .ask:
            return "Ask for each conflict"
        }
    }

    // MARK: - Actions Footer

    private var actionsFooter: some View {
        HStack {
            Button("Clear") {
                viewModel.clearStaging()
            }
            .controlSize(.small)

            Spacer()

            Button("Add More...") {
                viewModel.pickFiles()
            }
            .controlSize(.small)

            Button("Import") {
                viewModel.startImport()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .disabled(!viewModel.canImport)
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

                    Text("Importing \(progress.current + 1) of \(progress.total)")
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
                viewModel.cancelImport()
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
            case .success(let imported, let location):
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.green)
                Text("Import Complete")
                    .font(.headline)
                Text("\(imported) note(s) imported")
                    .font(.caption)
                    .foregroundColor(.secondary)
                if let folder = location {
                    Text("to \(folder)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 12) {
                    Button("Import More") {
                        viewModel.dismissCompletion()
                        viewModel.clearStaging()
                    }
                    Button("Done") {
                        viewModel.dismissCompletion()
                        viewModel.clearStaging()
                    }
                    .buttonStyle(.borderedProminent)
                }

            case .partial(let imported, let skipped, let failed):
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.orange)
                Text("Import Partially Complete")
                    .font(.headline)

                VStack(spacing: 4) {
                    if imported > 0 {
                        Text("\(imported) imported")
                            .foregroundColor(.green)
                    }
                    if skipped > 0 {
                        Text("\(skipped) skipped")
                            .foregroundColor(.orange)
                    }
                    if failed > 0 {
                        Text("\(failed) failed")
                            .foregroundColor(.red)
                    }
                }
                .font(.caption)

                HStack(spacing: 12) {
                    Button("Retry Failed") {
                        viewModel.dismissCompletion()
                        // Staging still contains items, user can retry
                    }
                    Button("Done") {
                        viewModel.dismissCompletion()
                        viewModel.clearStaging()
                    }
                    .buttonStyle(.borderedProminent)
                }

            case .cancelled(let completed, let remaining):
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text("Import Cancelled")
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
                Text("Import Failed")
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
                        viewModel.clearStaging()
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

    // MARK: - Drag and Drop

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var urls: [URL] = []

        let group = DispatchGroup()

        for provider in providers {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                defer { group.leave() }
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else {
                    return
                }
                urls.append(url)
            }
        }

        group.notify(queue: .main) {
            self.processDroppedURLs(urls)
        }

        return true
    }

    private func processDroppedURLs(_ urls: [URL]) {
        var files: [URL] = []
        var folders: [URL] = []

        for url in urls {
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) {
                if isDirectory.boolValue {
                    folders.append(url)
                } else {
                    files.append(url)
                }
            }
        }

        // Add files first
        if !files.isEmpty {
            viewModel.addFiles(files)
        }

        // Then add folders
        for folder in folders {
            viewModel.addFolder(folder)
        }
    }
}
