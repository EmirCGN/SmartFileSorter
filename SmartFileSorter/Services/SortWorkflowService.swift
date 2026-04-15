import Foundation

struct SortWorkflowService: SortWorkflowProviding {
    private let bookmarkService: BookmarkService

    init(bookmarkService: BookmarkService = BookmarkService()) {
        self.bookmarkService = bookmarkService
    }

    func makeUndoActions(from items: [FileItem]) -> [SortUndoAction] {
        items.compactMap(makeUndoAction(for:))
    }

    func makeUndoAction(for item: FileItem) -> SortUndoAction? {
        guard item.status == .moved, let destinationURL = item.destinationURL else {
            return nil
        }

        return SortUndoAction(
            originalURL: item.sourceURL,
            movedURL: destinationURL,
            fileName: item.originalName,
            originalBookmarkData: try? bookmarkService.bookmarkData(for: item.sourceURL),
            movedBookmarkData: try? bookmarkService.bookmarkData(for: destinationURL)
        )
    }

    func summary(for items: [FileItem]) -> SortSummary {
        SortSummary(
            totalFiles: items.count,
            movedFiles: items.filter { $0.status == .moved || $0.status == .planned }.count,
            skippedFiles: items.filter { $0.status == .skipped || !$0.isIncluded }.count,
            failedFiles: items.filter { $0.status == .failed }.count
        )
    }

    func logEntries(for items: [FileItem], logger: any Logging) -> [SortAction] {
        items.compactMap { item in
            switch item.status {
            case .planned:
                return logger.entry(.info, "Geplant: \(item.originalName) -> \(item.category.folderName)")
            case .moved:
                return logger.entry(.success, "Verschoben: \(item.originalName)")
            case .skipped:
                return logger.entry(.warning, "Übersprungen: \(item.originalName)")
            case .failed:
                let message = item.errorMessage.map { "Fehler: \(item.originalName) (\($0))" } ?? "Fehler: \(item.originalName)"
                return logger.entry(.error, message)
            case .detected:
                return nil
            }
        }
    }
}
