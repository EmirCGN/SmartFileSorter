import Foundation

struct LoggerService {
    func entry(_ kind: SortActionKind, _ message: String) -> SortAction {
        SortAction(kind: kind, message: message)
    }
}

struct UndoService {
    private let fileManager = FileManager.default

    func undo(_ actions: [SortUndoAction]) -> [SortAction] {
        actions.reversed().map { action in
            do {
                guard fileManager.fileExists(atPath: action.movedURL.path) else {
                    return SortAction(kind: .warning, message: "Nicht gefunden: \(action.fileName)")
                }

                let targetFolder = action.originalURL.deletingLastPathComponent()
                try fileManager.createDirectory(at: targetFolder, withIntermediateDirectories: true)

                if fileManager.fileExists(atPath: action.originalURL.path) {
                    return SortAction(kind: .warning, message: "Nicht zurückgesetzt, Quelle existiert bereits: \(action.fileName)")
                }

                try fileManager.moveItem(at: action.movedURL, to: action.originalURL)
                return SortAction(kind: .success, message: "Zurückgesetzt: \(action.fileName)")
            } catch {
                return SortAction(kind: .error, message: "Undo fehlgeschlagen: \(action.fileName) (\(error.localizedDescription))")
            }
        }
    }
}
