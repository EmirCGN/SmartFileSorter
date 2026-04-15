import Foundation
import Observation

@MainActor
@Observable
final class MainViewModel {
    var selectedFolderURL: URL?
    var settings = AppSettingsStore.load() {
        didSet { AppSettingsStore.save(settings) }
    }
    var detectedFiles: [FileItem] = []
    var logEntries: [SortAction] = []
    var summary = SortSummary.empty
    var appState: AppState = .ready
    var isShowingSortConfirmation = false
    var progress = SortProgress.empty
    var lastUndoActions: [SortUndoAction] = []

    private let folderPicker = FolderPickerService()
    private let logger = LoggerService()
    private let sorter = FileSorter()
    private let undoService = UndoService()
    private var cancelRequested = false

    var selectedFolderPath: String {
        selectedFolderURL?.path ?? "Noch kein Ordner ausgewählt"
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
        detectedFiles = []
        summary = .empty
        progress = .empty
        lastUndoActions = []
        logEntries = [logger.entry(.info, "Ordner ausgewählt: \(url.lastPathComponent)")]
        isShowingSortConfirmation = false
        appState = .ready
    }

    func analyzeSelectedFolder() async {
        guard let selectedFolderURL else { return }

        cancelRequested = false
        appState = .analyzing
        progress = .empty
        summary = .empty
        lastUndoActions = []
        isShowingSortConfirmation = false
        logEntries.append(logger.entry(.info, "Analyse gestartet."))

        do {
            let items = try sorter.analyze(folderURL: selectedFolderURL, settings: settings)
            guard !cancelRequested else {
                logEntries.append(logger.entry(.warning, "Analyse abgebrochen."))
                appState = .ready
                progress = .empty
                return
            }

            detectedFiles = items
            summary = summary(for: items)
            progress = SortProgress(processedFiles: items.count, totalFiles: items.count, currentFileName: "")

            if items.isEmpty {
                logEntries.append(logger.entry(.warning, "Keine passenden Dateien gefunden."))
            } else {
                logEntries.append(logger.entry(.success, "Analyse abgeschlossen: \(items.count) Dateien erkannt."))
            }

            appState = .finished
        } catch {
            logEntries.append(logger.entry(.error, "Analyse fehlgeschlagen: \(error.localizedDescription)"))
            appState = .failed
        }
    }

    func sortSelectedFolder() async {
        guard let selectedFolderURL else { return }

        if detectedFiles.isEmpty {
            await analyzeSelectedFolder()
        }

        cancelRequested = false
        appState = .sorting
        progress = SortProgress(processedFiles: 0, totalFiles: sortableItems.count, currentFileName: "")
        isShowingSortConfirmation = false

        if settings.dryRun {
            lastUndoActions = []
            logEntries.append(logger.entry(.info, "Sicherer Modus: Plan wird erstellt."))
        } else {
            logEntries.append(logger.entry(.info, "Sortierung gestartet."))
        }

        let sortedItems = sorter.sort(
            items: sortableItems,
            folderURL: selectedFolderURL,
            settings: settings,
            progress: { [weak self] progress in
                Task { @MainActor in self?.progress = progress }
            },
            shouldCancel: { [weak self] in
                MainActor.assumeIsolated { self?.cancelRequested == true }
            }
        )

        let movedUndoActions = sortedItems.compactMap { item -> SortUndoAction? in
            guard item.status == .moved, let destinationURL = item.destinationURL else { return nil }
            return SortUndoAction(originalURL: item.sourceURL, movedURL: destinationURL, fileName: item.originalName)
        }

        if !settings.dryRun {
            lastUndoActions = movedUndoActions
        }

        updateDetectedFiles(with: sortedItems)
        summary = summary(for: detectedFiles)
        log(sortedItems)

        if cancelRequested {
            logEntries.append(logger.entry(.warning, "Vorgang abgebrochen."))
        } else if settings.dryRun {
            if plannedMoveItems.isEmpty {
                logEntries.append(logger.entry(.warning, "Keine verschiebbaren Dateien im Plan."))
            } else {
                logEntries.append(logger.entry(.success, "Plan bereit: \(plannedMoveItems.count) Verschiebungen warten auf Bestätigung."))
                isShowingSortConfirmation = true
            }
        } else {
            logEntries.append(logger.entry(.success, "Sortierung abgeschlossen."))
        }

        appState = .finished
    }

    func confirmPlannedSort() async {
        guard let selectedFolderURL, canConfirmSort else { return }

        cancelRequested = false
        isShowingSortConfirmation = false
        appState = .sorting
        progress = SortProgress(processedFiles: 0, totalFiles: plannedMoveItems.count, currentFileName: "")
        logEntries.append(logger.entry(.info, "Bestätigte Sortierung gestartet."))

        var executionSettings = settings
        executionSettings.dryRun = false

        let plannedItems = plannedMoveItems
        let sortedItems = sorter.sort(
            items: plannedItems,
            folderURL: selectedFolderURL,
            settings: executionSettings,
            progress: { [weak self] progress in
                Task { @MainActor in self?.progress = progress }
            },
            shouldCancel: { [weak self] in
                MainActor.assumeIsolated { self?.cancelRequested == true }
            }
        )

        lastUndoActions = sortedItems.compactMap { item -> SortUndoAction? in
            guard item.status == .moved, let destinationURL = item.destinationURL else { return nil }
            return SortUndoAction(originalURL: item.sourceURL, movedURL: destinationURL, fileName: item.originalName)
        }

        updateDetectedFiles(with: sortedItems)
        summary = summary(for: detectedFiles)
        log(sortedItems)

        let failures = sortedItems.filter { $0.status == .failed }.count
        if cancelRequested {
            logEntries.append(logger.entry(.warning, "Sortierung abgebrochen."))
        } else if failures > 0 {
            logEntries.append(logger.entry(.warning, "Sortierung mit \(failures) Fehlern abgeschlossen."))
        } else {
            logEntries.append(logger.entry(.success, "Sortierung abgeschlossen."))
        }

        appState = .finished
    }

    func cancelCurrentOperation() {
        cancelRequested = true
        logEntries.append(logger.entry(.warning, "Abbruch angefordert."))
    }

    func undoLastSort() {
        guard canUndoSort else { return }
        let undoEntries = undoService.undo(lastUndoActions)
        logEntries.append(contentsOf: undoEntries)
        lastUndoActions = []
        detectedFiles = []
        summary = .empty
        progress = .empty
        appState = .finished
    }

    func reset() {
        detectedFiles = []
        logEntries = []
        summary = .empty
        progress = .empty
        lastUndoActions = []
        cancelRequested = false
        isShowingSortConfirmation = false
        appState = .ready
    }

    func count(for category: Category) -> Int {
        detectedFiles.filter { $0.category == category }.count
    }

    func setIncluded(_ isIncluded: Bool, for item: FileItem) {
        guard let index = detectedFiles.firstIndex(where: { $0.id == item.id }) else { return }
        detectedFiles[index].isIncluded = isIncluded
        if !isIncluded {
            detectedFiles[index].status = .skipped
        } else if detectedFiles[index].status == .skipped {
            detectedFiles[index].status = .detected
        }
        summary = summary(for: detectedFiles)
    }

    private func updateDetectedFiles(with updatedItems: [FileItem]) {
        let updatedByID = Dictionary(uniqueKeysWithValues: updatedItems.map { ($0.id, $0) })
        detectedFiles = detectedFiles.map { item in
            updatedByID[item.id] ?? item
        }
    }

    private func log(_ items: [FileItem]) {
        for item in items {
            switch item.status {
            case .planned:
                logEntries.append(logger.entry(.info, "Geplant: \(item.originalName) -> \(item.category.folderName)"))
            case .moved:
                logEntries.append(logger.entry(.success, "Verschoben: \(item.originalName)"))
            case .skipped:
                logEntries.append(logger.entry(.warning, "Übersprungen: \(item.originalName)"))
            case .failed:
                let message = item.errorMessage.map { "Fehler: \(item.originalName) (\($0))" } ?? "Fehler: \(item.originalName)"
                logEntries.append(logger.entry(.error, message))
            case .detected:
                break
            }
        }
    }

    private func summary(for items: [FileItem]) -> SortSummary {
        SortSummary(
            totalFiles: items.count,
            movedFiles: items.filter { $0.status == .moved || $0.status == .planned }.count,
            skippedFiles: items.filter { $0.status == .skipped || !$0.isIncluded }.count,
            failedFiles: items.filter { $0.status == .failed }.count
        )
    }
}
