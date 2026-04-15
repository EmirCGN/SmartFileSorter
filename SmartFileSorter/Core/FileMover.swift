import Foundation

struct FileMover {
    private let fileManager = FileManager.default
    private let conflictResolver: ConflictResolver

    init(conflictResolver: ConflictResolver = ConflictResolver()) {
        self.conflictResolver = conflictResolver
    }

    func move(_ item: FileItem, sourceFolderURL: URL, settings: AppSettings) throws -> FileItem {
        var updatedItem = item
        updatedItem.errorMessage = nil

        if !item.isIncluded {
            updatedItem.status = .skipped
            return updatedItem
        }

        if item.category == .other && !settings.sortUnknownToOthers {
            updatedItem.status = .skipped
            return updatedItem
        }

        let targetFolderURL = sourceFolderURL.appendingPathComponent(item.category.folderName, isDirectory: true)
        let proposedURL = targetFolderURL.appendingPathComponent(item.originalName)
        let destinationURL = item.destinationURL ?? (settings.resolveConflictsAutomatically ? conflictResolver.resolvedURL(for: proposedURL) : proposedURL)
        updatedItem.destinationURL = destinationURL

        if settings.dryRun {
            updatedItem.status = .planned
            return updatedItem
        }

        if fileManager.fileExists(atPath: destinationURL.path) && !settings.resolveConflictsAutomatically {
            updatedItem.status = .failed
            updatedItem.errorMessage = "Am Ziel existiert bereits eine Datei mit diesem Namen."
            return updatedItem
        }

        do {
            if settings.createMissingFolders {
                try fileManager.createDirectory(at: targetFolderURL, withIntermediateDirectories: true)
            }

            if item.sourceURL.standardizedFileURL == destinationURL.standardizedFileURL {
                updatedItem.status = .skipped
                return updatedItem
            }

            try fileManager.moveItem(at: item.sourceURL, to: destinationURL)
            updatedItem.status = .moved
            return updatedItem
        } catch {
            updatedItem.status = .failed
            updatedItem.errorMessage = error.localizedDescription
            return updatedItem
        }
    }
}
