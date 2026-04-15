import SwiftUI

struct MainWindowView: View {
    @Bindable var viewModel: MainViewModel
    @State private var searchText = ""
    @State private var categoryFilter = "all"
    @State private var statusFilter = "all"
    @State private var sortMode = "name"
    @State private var showsAdvancedOptions = false
    @State private var showsActivityDetails = false
    @State private var filteredItemsCache: [FileItem] = []

    private let filterService = FileItemFilterService()

    var body: some View {
        ZStack {
            background

            VStack(spacing: 16) {
                MainWindowHeaderView(
                    focusMessage: focusMessage,
                    summary: viewModel.summary,
                    dryRun: viewModel.settings.dryRun,
                    appState: viewModel.appState
                )

                HStack(alignment: .top, spacing: 16) {
                    MainWindowSidebarView(
                        selectedFolderPath: viewModel.selectedFolderPath,
                        selectedDestinationPath: viewModel.selectedDestinationPath,
                        hasSelectedFolder: viewModel.selectedFolderURL != nil,
                        isRunning: viewModel.isRunning,
                        detectedFileCount: viewModel.detectedFiles.count,
                        movedCount: viewModel.summary.movedFiles,
                        progress: viewModel.progress,
                        settings: $viewModel.settings,
                        showsAdvancedOptions: $showsAdvancedOptions,
                        pickFolder: { viewModel.pickFolder() },
                        pickDestinationFolder: { viewModel.pickDestinationFolder() },
                        clearDestinationFolder: { viewModel.clearDestinationFolder() },
                        countForCategory: { viewModel.count(for: $0) }
                    )

                    VStack(spacing: 10) {
                        MainWindowPlanView(
                            detectedFiles: viewModel.detectedFiles,
                            filteredItems: filteredItemsCache,
                            dryRun: viewModel.settings.dryRun,
                            searchText: $searchText,
                            categoryFilter: $categoryFilter,
                            statusFilter: $statusFilter,
                            sortMode: $sortMode,
                            setIncluded: { isIncluded, item in
                                viewModel.setIncluded(isIncluded, for: item)
                            }
                        )
                        .layoutPriority(1)

                        CompactSummaryStrip(summary: viewModel.summary, dryRun: viewModel.settings.dryRun)

                        if viewModel.settings.showLogs {
                            ActivityDetailsView(logEntries: viewModel.logEntries, isExpanded: $showsActivityDetails)
                        }
                    }
                    .frame(maxHeight: .infinity, alignment: .top)
                }
                .frame(maxHeight: .infinity, alignment: .top)
                .layoutPriority(1)

                MainWindowFooterView(
                    showLogs: $viewModel.settings.showLogs,
                    isRunning: viewModel.isRunning,
                    canUndoSort: viewModel.canUndoSort,
                    canCancel: viewModel.canCancel,
                    canPrimaryAction: viewModel.detectedFiles.isEmpty ? viewModel.canAnalyze : viewModel.canSort,
                    primaryActionTitle: primaryActionTitle,
                    primaryActionIcon: primaryActionIcon,
                    reset: { viewModel.reset() },
                    undo: { viewModel.undoLastSort() },
                    cancel: { viewModel.cancelCurrentOperation() },
                    primaryAction: {
                        viewModel.startPrimaryAction()
                    }
                )
            }
            .padding(20)
        }
        .frame(minWidth: 980, minHeight: 560)
        .sheet(isPresented: sortConfirmationBinding) {
            SafeSortConfirmationView(viewModel: viewModel)
        }
        .task(id: filterInput) {
            await rebuildFilteredItems(for: filterInput)
        }
        .animation(.snappy(duration: 0.22), value: viewModel.appState)
        .animation(.snappy(duration: 0.22), value: viewModel.detectedFiles.count)
        .animation(.snappy(duration: 0.22), value: showsActivityDetails)
    }

    private struct FilterInput: Hashable {
        let items: [FileItem]
        let searchText: String
        let categoryFilter: String
        let statusFilter: String
        let sortMode: String
    }

    private var filterInput: FilterInput {
        FilterInput(
            items: viewModel.detectedFiles,
            searchText: searchText,
            categoryFilter: categoryFilter,
            statusFilter: statusFilter,
            sortMode: sortMode
        )
    }

    private var sortConfirmationBinding: Binding<Bool> {
        Binding(
            get: { _viewModel.wrappedValue.isShowingSortConfirmation },
            set: { _viewModel.wrappedValue.isShowingSortConfirmation = $0 }
        )
    }

    private var focusMessage: String {
        if viewModel.selectedFolderURL == nil {
            return "Bereit für Analyse"
        }
        if viewModel.isRunning {
            return viewModel.appState == .analyzing ? "Analyse läuft" : "Sortierung läuft"
        }
        if viewModel.detectedFiles.isEmpty {
            return "Ordner gewählt"
        }
        if viewModel.summary.failedFiles > 0 {
            return "Fehler prüfen"
        }
        if viewModel.summary.movedFiles > 0 {
            return viewModel.settings.dryRun ? "Plan prüfen" : "Ergebnis prüfen"
        }
        return "\(viewModel.detectedFiles.count) Dateien erkannt"
    }

    private var primaryActionTitle: String {
        viewModel.detectedFiles.isEmpty ? "Analyse starten" : (viewModel.settings.dryRun ? "Plan erstellen" : "Sortierung starten")
    }

    private var primaryActionIcon: String {
        viewModel.detectedFiles.isEmpty ? "magnifyingglass" : (viewModel.settings.dryRun ? "checklist" : "arrow.triangle.2.circlepath")
    }

    private var background: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color(nsColor: .controlBackgroundColor).opacity(0.72)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }

    private func rebuildFilteredItems(for input: FilterInput) async {
        try? await Task.sleep(nanoseconds: 120_000_000)
        guard !Task.isCancelled else { return }

        let filtered = await Task.detached(priority: .userInitiated) {
            filterService.filteredItems(
                items: input.items,
                searchText: input.searchText,
                categoryFilter: input.categoryFilter,
                statusFilter: input.statusFilter,
                sortMode: input.sortMode
            )
        }.value

        guard !Task.isCancelled else { return }
        filteredItemsCache = filtered
    }
}
