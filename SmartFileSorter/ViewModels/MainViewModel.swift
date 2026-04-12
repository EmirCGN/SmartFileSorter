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
        selectedFolderURL != nil && !detectedFiles.isEmpty && !isRunning
    }

    func pickFolder() {
        guard let url = folderPicker.pickFolder() else { return }
        selectedFolderURL = url
        detectedFiles = []
        summary = .empty
        logEntries = [logger.entry(.info, "Ordner ausgewählt: \(url.lastPathComponent)")]
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
        logEntries.append(logger.entry(.info, settings.dryRun ? "Dry Run gestartet." : "Sortierung gestartet."))

        let sortedItems = sorter.sort(items: detectedFiles, folderURL: selectedFolderURL, settings: settings)
        detectedFiles = sortedItems
        summary = summary(for: sortedItems)

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

        logEntries.append(logger.entry(.success, settings.dryRun ? "Dry Run abgeschlossen." : "Sortierung abgeschlossen."))
        appState = .finished
    }

    func reset() {
        detectedFiles = []
        logEntries = []
        summary = .empty
        appState = .ready
    }

    func count(for category: Category) -> Int {
        detectedFiles.filter { $0.category == category }.count
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
