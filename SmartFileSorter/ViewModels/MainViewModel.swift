import Foundation
import Observation

@MainActor
@Observable
final class MainViewModel {
    var selectedFolderURL: URL?
    var destinationBaseURL: URL? {
        didSet { persistDestinationSelection() }
    }
    var settings: AppSettings {
        didSet { settingsStore.save(settings) }
    }
    var detectedFiles: [FileItem] = []
    var logEntries: [SortAction] = []
    var summary = SortSummary.empty
    var appState: AppState = .ready
    var isShowingSortConfirmation = false
    var progress = SortProgress.empty
    var lastUndoActions: [SortUndoAction] = [] {
        didSet {
            Task(priority: .utility) { [undoHistoryCoordinator, actions = lastUndoActions] in
                await undoHistoryCoordinator.saveActions(actions)
            }
        }
    }

    private let folderPicker: any FolderPicking
    private let logger: any Logging
    private let undoService: any UndoPerforming
    private let workflowService: any SortWorkflowProviding
    private let sortTaskCoordinator: any SortTaskCoordinating
    private let undoHistoryCoordinator: any UndoHistoryCoordinating
    private let settingsStore: any AppSettingsStoring
    private let bookmarkService: BookmarkService

    private var itemIndexByID: [UUID: Int] = [:]
    private var currentOperationTask: Task<Void, Never>?

    convenience init() {
        let settingsStore = AppSettingsStore()
        let fileSystem = LocalFileSystem()
        let scanner = DirectoryScanner(fileSystem: fileSystem)
        let mover = FileMover(fileSystem: fileSystem, conflictResolver: ConflictResolver(fileSystem: fileSystem))
        let sorter = FileSorter(scanner: scanner, analyzer: FileAnalyzer(), mover: mover)
        let executionService = SortExecutionService(sorter: sorter)
        self.init(
            folderPicker: FolderPickerService(),
            logger: LoggerService(),
            undoService: UndoService(fileSystem: fileSystem),
            workflowService: SortWorkflowService(),
            sortTaskCoordinator: SortTaskCoordinator(executionService: executionService),
            undoHistoryCoordinator: UndoHistoryCoordinator(store: UndoHistoryStore()),
            settingsStore: settingsStore,
            bookmarkService: BookmarkService()
        )
    }

    init(
        folderPicker: any FolderPicking,
        logger: any Logging,
        undoService: any UndoPerforming,
        workflowService: any SortWorkflowProviding,
        sortTaskCoordinator: any SortTaskCoordinating,
        undoHistoryCoordinator: any UndoHistoryCoordinating,
        settingsStore: any AppSettingsStoring,
        bookmarkService: BookmarkService
    ) {
        self.folderPicker = folderPicker
        self.logger = logger
        self.undoService = undoService
        self.workflowService = workflowService
        self.sortTaskCoordinator = sortTaskCoordinator
        self.undoHistoryCoordinator = undoHistoryCoordinator
        self.settingsStore = settingsStore
        self.bookmarkService = bookmarkService

        let settingsLoad = settingsStore.load()
        settings = settingsLoad.settings
        destinationBaseURL = nil
        lastUndoActions = []

        if let diagnosticMessage = settingsLoad.diagnosticMessage {
            logEntries = [logger.entry(.warning, diagnosticMessage)]
        }

        Task {
            let loaded = await undoHistoryCoordinator.loadActions()
            await MainActor.run {
                self.lastUndoActions = loaded
            }
        }

        resolveDestinationSelectionFromSettings()
    }

    var selectedFolderPath: String {
        selectedFolderURL?.path ?? "Noch kein Ordner ausgewählt"
    }

    var selectedDestinationPath: String {
        destinationBaseURL?.path ?? "Gleich wie Quellordner"
    }

    var isRunning: Bool {
        appState == .analyzing || appState == .sorting
    }

    var canAnalyze: Bool {
        selectedFolderURL != nil && !isRunning
    }

    var canSort: Bool {
        selectedFolderURL != nil && !sortableItems.isEmpty && !isRunning
    }

    var canCancel: Bool {
        isRunning
    }

    var canUndoSort: Bool {
        !lastUndoActions.isEmpty && !isRunning
    }

    var plannedMoveItems: [FileItem] {
        detectedFiles.filter { $0.status == .planned && $0.isIncluded }
    }

    var canConfirmSort: Bool {
        selectedFolderURL != nil && !plannedMoveItems.isEmpty && !isRunning
    }

    private var sortableItems: [FileItem] {
        detectedFiles.filter { ($0.status == .detected || $0.status == .planned) && $0.isIncluded }
    }

    func pickFolder() {
        guard let url = folderPicker.pickFolder() else { return }
        selectedFolderURL = url
        replaceDetectedFiles(with: [])
        summary = .empty
        progress = .empty
        logEntries = [logger.entry(.info, "Ordner ausgewählt: \(url.lastPathComponent)")]
        isShowingSortConfirmation = false
        appState = .ready
    }

    func pickDestinationFolder() {
        guard let url = folderPicker.pickFolder() else { return }
        destinationBaseURL = url
        logEntries.append(logger.entry(.info, "Zielordner ausgewählt: \(url.path)"))
    }

    func clearDestinationFolder() {
        destinationBaseURL = nil
        logEntries.append(logger.entry(.info, "Zielordner zurückgesetzt: Quellordner wird verwendet."))
    }

    func startPrimaryAction() {
        if detectedFiles.isEmpty {
            startAnalyzeSelectedFolder()
        } else {
            startSortSelectedFolder()
        }
    }

    func startAnalyzeSelectedFolder() {
        currentOperationTask?.cancel()
        currentOperationTask = Task { [weak self] in
            await self?.analyzeSelectedFolder()
        }
    }

    func startSortSelectedFolder() {
        currentOperationTask?.cancel()
        currentOperationTask = Task { [weak self] in
            await self?.sortSelectedFolder()
        }
    }

    func startConfirmPlannedSort() {
        currentOperationTask?.cancel()
        currentOperationTask = Task { [weak self] in
            await self?.confirmPlannedSort()
        }
    }

    func analyzeSelectedFolder() async {
        guard let selectedFolderURL else { return }

        appState = .analyzing
        progress = .empty
        summary = .empty
        isShowingSortConfirmation = false
        logEntries.append(logger.entry(.info, "Analyse gestartet."))

        let settingsSnapshot = settings

        do {
            let items = try await sortTaskCoordinator.analyze(
                folderURL: selectedFolderURL,
                settings: settingsSnapshot
            )

            try Task.checkCancellation()

            replaceDetectedFiles(with: items)
            summary = workflowService.summary(for: items)
            progress = SortProgress(processedFiles: items.count, totalFiles: items.count, currentFileName: "")

            if items.isEmpty {
                logEntries.append(logger.entry(.warning, "Keine passenden Dateien gefunden."))
            } else {
                logEntries.append(logger.entry(.success, "Analyse abgeschlossen: \(items.count) Dateien erkannt."))
            }

            appState = .finished
        } catch {
            if Task.isCancelled {
                logEntries.append(logger.entry(.warning, "Analyse abgebrochen."))
                appState = .ready
                progress = .empty
                return
            }
            logEntries.append(logger.entry(.error, "Analyse fehlgeschlagen: \(error.localizedDescription)"))
            appState = .failed
        }
        currentOperationTask = nil
    }

    func sortSelectedFolder() async {
        guard let selectedFolderURL else { return }

        if detectedFiles.isEmpty {
            await analyzeSelectedFolder()
        }

        appState = .sorting
        progress = SortProgress(processedFiles: 0, totalFiles: sortableItems.count, currentFileName: "")
        isShowingSortConfirmation = false

        if settings.dryRun {
            logEntries.append(logger.entry(.info, "Sicherer Modus: Plan wird erstellt."))
        } else {
            logEntries.append(logger.entry(.info, "Sortierung gestartet."))
        }

        let itemsToSort = sortableItems
        let settingsSnapshot = settings
        let destinationSnapshot = destinationBaseURL
        let totalFiles = itemsToSort.count
        var incrementalUndoActions: [SortUndoAction] = []
        let persistBatchSize = 100

        let makeUndoAction: (FileItem) -> SortUndoAction? = { item in
            guard item.status == .moved, let destinationURL = item.destinationURL else { return nil }
            return SortUndoAction(
                originalURL: item.sourceURL,
                movedURL: destinationURL,
                fileName: item.originalName,
                originalBookmarkData: try? self.bookmarkService.bookmarkData(for: item.sourceURL),
                movedBookmarkData: try? self.bookmarkService.bookmarkData(for: destinationURL)
            )
        }

        do {
            let sortedItems = try await sortTaskCoordinator.sort(
                items: itemsToSort,
                folderURL: selectedFolderURL,
                destinationBaseURL: destinationSnapshot,
                settings: settingsSnapshot,
                progress: { [weak self] progress in
                    Task { @MainActor [weak self] in
                        self?.progress = progress
                    }
                },
                onItemProcessed: { processedItem in
                    guard !settingsSnapshot.dryRun, let action = makeUndoAction(processedItem) else { return }
                    incrementalUndoActions.append(action)
                    if incrementalUndoActions.count.isMultiple(of: persistBatchSize) {
                        let snapshot = incrementalUndoActions
                        Task.detached(priority: .utility) { [undoHistoryCoordinator = self.undoHistoryCoordinator] in
                            await undoHistoryCoordinator.saveActions(snapshot)
                        }
                    }
                }
            )

            if !settingsSnapshot.dryRun {
                lastUndoActions = incrementalUndoActions
            }

            updateDetectedFiles(with: sortedItems)
            summary = workflowService.summary(for: detectedFiles)
            logEntries.append(contentsOf: workflowService.logEntries(for: sortedItems, logger: logger))

            if settingsSnapshot.dryRun {
                if plannedMoveItems.isEmpty {
                    logEntries.append(logger.entry(.warning, "Keine verschiebbaren Dateien im Plan."))
                } else {
                    logEntries.append(logger.entry(.success, "Plan bereit: \(plannedMoveItems.count) Verschiebungen warten auf Bestätigung."))
                    isShowingSortConfirmation = true
                }
            } else {
                logEntries.append(logger.entry(.success, "Sortierung abgeschlossen."))
            }

            if progress.totalFiles == 0 {
                progress = SortProgress(processedFiles: totalFiles, totalFiles: totalFiles, currentFileName: "")
            }
            appState = .finished
        } catch {
            if Task.isCancelled {
                logEntries.append(logger.entry(.warning, "Vorgang abgebrochen."))
                appState = .ready
            } else {
                logEntries.append(logger.entry(.error, "Sortierung fehlgeschlagen: \(error.localizedDescription)"))
                appState = .failed
            }
        }
        currentOperationTask = nil
    }

    func confirmPlannedSort() async {
        guard let selectedFolderURL, canConfirmSort else { return }

        isShowingSortConfirmation = false
        appState = .sorting
        progress = SortProgress(processedFiles: 0, totalFiles: plannedMoveItems.count, currentFileName: "")
        logEntries.append(logger.entry(.info, "Bestätigte Sortierung gestartet."))

        var executionSettings = settings
        executionSettings.dryRun = false
        let destinationSnapshot = destinationBaseURL
        var incrementalUndoActions: [SortUndoAction] = []
        let persistBatchSize = 100

        let makeUndoAction: (FileItem) -> SortUndoAction? = { item in
            guard item.status == .moved, let destinationURL = item.destinationURL else { return nil }
            return SortUndoAction(
                originalURL: item.sourceURL,
                movedURL: destinationURL,
                fileName: item.originalName,
                originalBookmarkData: try? self.bookmarkService.bookmarkData(for: item.sourceURL),
                movedBookmarkData: try? self.bookmarkService.bookmarkData(for: destinationURL)
            )
        }

        do {
            let sortedItems = try await sortTaskCoordinator.sort(
                items: plannedMoveItems,
                folderURL: selectedFolderURL,
                destinationBaseURL: destinationSnapshot,
                settings: executionSettings,
                progress: { [weak self] progress in
                    Task { @MainActor [weak self] in
                        self?.progress = progress
                    }
                },
                onItemProcessed: { processedItem in
                    guard let action = makeUndoAction(processedItem) else { return }
                    incrementalUndoActions.append(action)
                    if incrementalUndoActions.count.isMultiple(of: persistBatchSize) {
                        let snapshot = incrementalUndoActions
                        Task.detached(priority: .utility) { [undoHistoryCoordinator = self.undoHistoryCoordinator] in
                            await undoHistoryCoordinator.saveActions(snapshot)
                        }
                    }
                }
            )

            lastUndoActions = incrementalUndoActions

            updateDetectedFiles(with: sortedItems)
            summary = workflowService.summary(for: detectedFiles)
            logEntries.append(contentsOf: workflowService.logEntries(for: sortedItems, logger: logger))

            let failures = sortedItems.filter { $0.status == .failed }.count
            if failures > 0 {
                logEntries.append(logger.entry(.warning, "Sortierung mit \(failures) Fehlern abgeschlossen."))
            } else {
                logEntries.append(logger.entry(.success, "Sortierung abgeschlossen."))
            }

            appState = .finished
        } catch {
            if Task.isCancelled {
                logEntries.append(logger.entry(.warning, "Sortierung abgebrochen."))
                appState = .ready
            } else {
                logEntries.append(logger.entry(.error, "Sortierung fehlgeschlagen: \(error.localizedDescription)"))
                appState = .failed
            }
        }
        currentOperationTask = nil
    }

    func cancelCurrentOperation() {
        currentOperationTask?.cancel()
        logEntries.append(logger.entry(.warning, "Abbruch angefordert."))
    }

    func undoLastSort() {
        guard canUndoSort else { return }
        let undoEntries = undoService.undo(lastUndoActions)
        logEntries.append(contentsOf: undoEntries)
        lastUndoActions = []
        replaceDetectedFiles(with: [])
        summary = .empty
        progress = .empty
        appState = .finished
    }

    func reset() {
        replaceDetectedFiles(with: [])
        logEntries = []
        summary = .empty
        progress = .empty
        lastUndoActions = []
        currentOperationTask?.cancel()
        currentOperationTask = nil
        isShowingSortConfirmation = false
        appState = .ready
    }

    func count(for category: Category) -> Int {
        detectedFiles.filter { $0.category == category }.count
    }

    func setIncluded(_ isIncluded: Bool, for item: FileItem) {
        ensureItemIndex()
        guard let index = itemIndexByID[item.id], detectedFiles.indices.contains(index) else { return }
        detectedFiles[index].isIncluded = isIncluded
        if !isIncluded {
            detectedFiles[index].status = .skipped
        } else if detectedFiles[index].status == .skipped {
            detectedFiles[index].status = .detected
        }
        summary = workflowService.summary(for: detectedFiles)
    }

    private func updateDetectedFiles(with updatedItems: [FileItem]) {
        ensureItemIndex()
        for updated in updatedItems {
            guard let index = itemIndexByID[updated.id], detectedFiles.indices.contains(index) else { continue }
            detectedFiles[index] = updated
        }
    }

    private func replaceDetectedFiles(with items: [FileItem]) {
        detectedFiles = items
        itemIndexByID = Dictionary(uniqueKeysWithValues: items.enumerated().map { ($1.id, $0) })
    }

    private func ensureItemIndex() {
        guard itemIndexByID.count != detectedFiles.count else { return }
        itemIndexByID = Dictionary(uniqueKeysWithValues: detectedFiles.enumerated().map { ($1.id, $0) })
    }

    private func persistDestinationSelection() {
        settings.destinationBasePath = destinationBaseURL?.path
        settings.destinationBaseBookmarkData = destinationBaseURL.flatMap { try? bookmarkService.bookmarkData(for: $0) }
    }

    private func resolveDestinationSelectionFromSettings() {
        if let bookmark = settings.destinationBaseBookmarkData,
           let resolved = try? bookmarkService.resolveBookmark(bookmark) {
            destinationBaseURL = resolved
            return
        }
        if let path = settings.destinationBasePath {
            destinationBaseURL = URL(fileURLWithPath: path, isDirectory: true)
        }
    }
}
