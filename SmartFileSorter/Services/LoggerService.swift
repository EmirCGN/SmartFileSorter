import Foundation

struct LoggerService: Logging {
    func entry(_ kind: SortActionKind, _ message: String) -> SortAction {
        SortAction(kind: kind, message: message)
    }
}

struct UndoService: UndoPerforming {
    private let fileSystem: any FileSystemManaging
    private let bookmarkService: BookmarkService

    init(fileSystem: any FileSystemManaging = LocalFileSystem(), bookmarkService: BookmarkService = BookmarkService()) {
        self.fileSystem = fileSystem
        self.bookmarkService = bookmarkService
    }

    func undo(_ actions: [SortUndoAction]) -> [SortAction] {
        var touchedFolders: Set<URL> = []
        var entries: [SortAction] = []

        for action in actions.reversed() {
            do {
                let sourceResolution = resolveURL(bookmarkData: action.movedBookmarkData, fallback: action.movedURL, label: "Quelle", fileName: action.fileName)
                let targetResolution = resolveURL(bookmarkData: action.originalBookmarkData, fallback: action.originalURL, label: "Ziel", fileName: action.fileName)
                if let warning = sourceResolution.warning {
                    entries.append(SortAction(kind: .warning, message: warning))
                }
                if let warning = targetResolution.warning {
                    entries.append(SortAction(kind: .warning, message: warning))
                }
                let sourceURL = sourceResolution.url
                let targetURL = targetResolution.url
                defer {
                    sourceResolution.scopedAccess?.stopAccessingSecurityScopedResource()
                    targetResolution.scopedAccess?.stopAccessingSecurityScopedResource()
                }

                guard fileSystem.fileExists(atPath: sourceURL.path) else {
                    entries.append(SortAction(kind: .warning, message: "Nicht gefunden: \(action.fileName)"))
                    continue
                }

                let targetFolder = targetURL.deletingLastPathComponent()
                try fileSystem.createDirectory(at: targetFolder, withIntermediateDirectories: true)

                if fileSystem.fileExists(atPath: targetURL.path) {
                    entries.append(SortAction(kind: .warning, message: "Nicht zurückgesetzt, Quelle existiert bereits: \(action.fileName)"))
                    continue
                }

                try fileSystem.moveItem(at: sourceURL, to: targetURL)
                touchedFolders.insert(sourceURL.deletingLastPathComponent())
                entries.append(SortAction(kind: .success, message: "Zurückgesetzt: \(action.fileName)"))
            } catch {
                entries.append(SortAction(kind: .error, message: "Undo fehlgeschlagen: \(action.fileName) (\(error.localizedDescription))"))
            }
        }

        for folder in touchedFolders {
            removeFolderIfEmpty(folder)
        }
        return entries
    }

    private func resolveURL(bookmarkData: Data?, fallback: URL, label: String, fileName: String) -> (url: URL, scopedAccess: URL?, warning: String?) {
        guard let bookmarkData else {
            return (fallback, nil, nil)
        }

        guard let resolvedURL = try? bookmarkService.resolveBookmark(bookmarkData) else {
            return (fallback, nil, "Bookmark konnte nicht aufgelöst werden (\(label)): \(fileName)")
        }

        if resolvedURL.startAccessingSecurityScopedResource() {
            return (resolvedURL, resolvedURL, nil)
        }
        return (resolvedURL, nil, "Security-Scoped Zugriff verweigert (\(label)): \(fileName)")
    }

    private func removeFolderIfEmpty(_ folder: URL) {
        guard let children = try? fileSystem.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil),
              children.isEmpty else {
            return
        }
        try? FileManager.default.removeItem(at: folder)
    }
}
