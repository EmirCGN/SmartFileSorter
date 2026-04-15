import Foundation

struct FileMover {
    private let fileSystem: any FileSystemManaging
    private let conflictResolver: ConflictResolver

    nonisolated init(fileSystem: any FileSystemManaging = LocalFileSystem(), conflictResolver: ConflictResolver? = nil) {
        self.fileSystem = fileSystem
        self.conflictResolver = conflictResolver ?? ConflictResolver(fileSystem: fileSystem)
    }

    nonisolated init(conflictResolver: ConflictResolver = ConflictResolver()) {
        self.fileSystem = LocalFileSystem()
        self.conflictResolver = conflictResolver
    }

    nonisolated func move(_ item: FileItem, sourceFolderURL: URL, destinationBaseURL: URL?, settings: AppSettings) throws -> FileItem {
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

        let baseDestination = destinationBaseURL ?? sourceFolderURL
        let targetFolderURL = baseDestination.appendingPathComponent(item.category.folderName, isDirectory: true)
        let proposedURL = targetFolderURL.appendingPathComponent(item.originalName)
        let destinationURL = item.destinationURL ?? (settings.resolveConflictsAutomatically ? conflictResolver.resolvedURL(for: proposedURL) : proposedURL)
        updatedItem.destinationURL = destinationURL

        if settings.dryRun {
            updatedItem.status = .planned
            return updatedItem
        }

        if fileSystem.fileExists(atPath: destinationURL.path) && !settings.resolveConflictsAutomatically {
            updatedItem.status = .failed
            updatedItem.errorMessage = "Am Ziel existiert bereits eine Datei mit diesem Namen."
            return updatedItem
        }

        do {
            if settings.createMissingFolders {
                try fileSystem.createDirectory(at: targetFolderURL, withIntermediateDirectories: true)
            }

            if item.sourceURL.standardizedFileURL == destinationURL.standardizedFileURL {
                updatedItem.status = .skipped
                return updatedItem
            }

            try fileSystem.moveItem(at: item.sourceURL, to: destinationURL)
            updatedItem.status = .moved
            return updatedItem
        } catch {
            updatedItem.status = .failed
            updatedItem.errorMessage = error.localizedDescription
            return updatedItem
        }
    }
}
