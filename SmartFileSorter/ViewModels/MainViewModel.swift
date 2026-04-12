import Foundation
import Observation

@MainActor
@Observable
final class MainViewModel {
    var selectedFolderURL: URL?
    var settings = AppSettings()
    var detectedFiles: [FileItem] = []
    var logEntries: [SortAction] = []
    var summary = SortSummary.empty
    var appState: AppState = .ready
    var isShowingSortConfirmation = false

    private let folderPicker = FolderPickerService()
    private let logger = LoggerService()
    private let sorter = FileSorter()

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

    var plannedMoveItems: [FileItem] {
        detectedFiles.filter { $0.status == .planned }
    }

    var canConfirmSort: Bool {
        selectedFolderURL != nil && !plannedMoveItems.isEmpty && !isRunning
    }

    private var sortableItems: [FileItem] {
        detectedFiles.filter { $0.status == .detected || $0.status == .planned }
    }

    func pickFolder() {
        guard let url = folderPicker.pickFolder() else { return }
        selectedFolderURL = url
        detectedFiles = []
        summary = .empty
        logEntries = [logger.entry(.info, "Ordner ausgewählt: \(url.lastPathComponent)")]
        isShowingSortConfirmation = false
        appState = .ready
    }

    func analyzeSelectedFolder() async {
        guard let selectedFolderURL else { return }

        appState = .analyzing
        summary = .empty
        logEntries.append(logger.entry(.info, "Analyse gestartet."))

        do {
            let items = try sorter.analyze(folderURL: selectedFolderURL, settings: settings)
            detectedFiles = items
            summary = summary(for: items)

            if items.isEmpty {
                logEntries.append(logger.entry(.warning, "Keine passenden Dateien gefunden."))
            } else {
                for item in items {
                    logEntries.append(logger.entry(.info, "\(item.originalName) -> \(item.category.name)"))
                }
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

        appState = .sorting
        isShowingSortConfirmation = false

        if settings.dryRun {
            logEntries.append(logger.entry(.info, "Sicherer Modus: Plan wird erstellt."))
        } else {
            logEntries.append(logger.entry(.info, "Sortierung gestartet."))
        }

        let sortedItems = sorter.sort(items: sortableItems, folderURL: selectedFolderURL, settings: settings)
        updateDetectedFiles(with: sortedItems)
        summary = summary(for: detectedFiles)

        for item in sortedItems {
            switch item.status {
            case .planned:
                logEntries.append(logger.entry(.info, "Geplant: \(item.originalName) -> \(item.category.folderName)"))
            case .moved:
                logEntries.append(logger.entry(.success, "Verschoben: \(item.originalName)"))
            case .skipped:
                logEntries.append(logger.entry(.warning, "Übersprungen: \(item.originalName)"))
            case .failed:
                logEntries.append(logger.entry(.error, "Fehler: \(item.originalName)"))
            case .detected:
                break
            }
        }

        if settings.dryRun {
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

        isShowingSortConfirmation = false
        appState = .sorting
        logEntries.append(logger.entry(.info, "Bestätigte Sortierung gestartet."))

        var executionSettings = settings
        executionSettings.dryRun = false

        let plannedItems = plannedMoveItems
        let sortedItems = sorter.sort(items: plannedItems, folderURL: selectedFolderURL, settings: executionSettings)
        updateDetectedFiles(with: sortedItems)
        summary = summary(for: detectedFiles)

        for item in sortedItems {
            switch item.status {
            case .moved:
                logEntries.append(logger.entry(.success, "Verschoben: \(item.originalName)"))
            case .skipped:
                logEntries.append(logger.entry(.warning, "Übersprungen: \(item.originalName)"))
            case .failed:
                logEntries.append(logger.entry(.error, "Fehler: \(item.originalName)"))
            case .planned, .detected:
                break
            }
        }

        let failures = sortedItems.filter { $0.status == .failed }.count
        if failures > 0 {
            logEntries.append(logger.entry(.warning, "Sortierung mit \(failures) Fehlern abgeschlossen."))
        } else {
            logEntries.append(logger.entry(.success, "Sortierung abgeschlossen."))
        }

        appState = .finished
    }

    func reset() {
        detectedFiles = []
        logEntries = []
        summary = .empty
        isShowingSortConfirmation = false
        appState = .ready
    }

    func count(for category: Category) -> Int {
        detectedFiles.filter { $0.category == category }.count
    }

    private func updateDetectedFiles(with updatedItems: [FileItem]) {
        let updatedByID = Dictionary(uniqueKeysWithValues: updatedItems.map { ($0.id, $0) })
        detectedFiles = detectedFiles.map { item in
            updatedByID[item.id] ?? item
        }
    }

    private func summary(for items: [FileItem]) -> SortSummary {
        SortSummary(
            totalFiles: items.count,
            movedFiles: items.filter { $0.status == .moved || $0.status == .planned }.count,
            skippedFiles: items.filter { $0.status == .skipped }.count,
            failedFiles: items.filter { $0.status == .failed }.count
        )
    }
}
