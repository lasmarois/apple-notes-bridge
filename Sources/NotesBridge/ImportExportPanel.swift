import SwiftUI

/// Tab selection for import/export panel
enum ImportExportTab: String, CaseIterable {
    case export = "Export"
    case `import` = "Import"

    var icon: String {
        switch self {
        case .export: return "square.and.arrow.up"
        case .import: return "square.and.arrow.down"
        }
    }
}

/// Collapsible right sidebar panel for import/export operations
struct ImportExportPanel: View {
    @Binding var selectedTab: ImportExportTab
    @Binding var isOpen: Bool
    @ObservedObject var exportViewModel: ExportViewModel
    @ObservedObject var importViewModel: ImportViewModel

    @State private var showCloseConfirmation: Bool = false

    /// Check if any operation is in progress
    private var isOperationInProgress: Bool {
        exportViewModel.isExporting || importViewModel.isImporting
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with close button
            panelHeader

            Divider()

            // Tab picker (disabled during operations)
            tabPicker
                .disabled(isOperationInProgress)

            Divider()

            // Tab content
            tabContent
        }
        .frame(width: 320)
        .background(Color(nsColor: .windowBackgroundColor))
        .alert("Operation in Progress", isPresented: $showCloseConfirmation) {
            Button("Cancel Operation & Close", role: .destructive) {
                // Cancel the current operation
                if exportViewModel.isExporting {
                    exportViewModel.cancelExport()
                }
                if importViewModel.isImporting {
                    importViewModel.cancelImport()
                }
                withAnimation { isOpen = false }
            }
            Button("Continue", role: .cancel) { }
        } message: {
            Text("An import or export operation is currently running. Closing the panel will cancel it.")
        }
    }

    // MARK: - Header

    private var panelHeader: some View {
        HStack {
            Text(selectedTab == .export ? "Export Notes" : "Import Notes")
                .font(.headline)

            // Show operation indicator
            if isOperationInProgress {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 16, height: 16)
            }

            Spacer()

            Button(action: handleClose) {
                Image(systemName: "xmark")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Close panel")
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    private func handleClose() {
        if isOperationInProgress {
            showCloseConfirmation = true
        } else {
            withAnimation { isOpen = false }
        }
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        HStack(spacing: 0) {
            ForEach(ImportExportTab.allCases, id: \.self) { tab in
                tabButton(for: tab)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func tabButton(for tab: ImportExportTab) -> some View {
        Button(action: { selectedTab = tab }) {
            HStack(spacing: 6) {
                Image(systemName: tab.icon)
                    .font(.caption)
                Text(tab.rawValue)

                // Badge for export queue count
                if tab == .export && !exportViewModel.isEmpty {
                    Text("\(exportViewModel.queueCount)")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }

                // Badge for import staging count
                if tab == .import && !importViewModel.isEmpty {
                    Text("\(importViewModel.stagingCount)")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(selectedTab == tab ? Color.accentColor.opacity(0.15) : Color.clear)
            .foregroundColor(selectedTab == tab ? .accentColor : .secondary)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .export:
            ExportTab(viewModel: exportViewModel)
        case .import:
            ImportTab(viewModel: importViewModel)
        }
    }
}
