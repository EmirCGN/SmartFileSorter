import Foundation

struct FileSorter {
    private let scanner: DirectoryScanner
    private let analyzer: FileAnalyzer
    private let mover: FileMover
    private static let ioQueue = DispatchQueue(label: "de.emir.smartfilesorter.file-io", qos: .userInitiated, attributes: .concurrent)

    nonisolated init(scanner: DirectoryScanner = DirectoryScanner(), analyzer: FileAnalyzer = FileAnalyzer(), mover: FileMover = FileMover()) {
        self.scanner = scanner
        self.analyzer = analyzer
        self.mover = mover
    }

    nonisolated func analyze(folderURL: URL, settings: AppSettings) throws -> [FileItem] {
        try scanner.scan(folderURL: folderURL, settings: settings).map { url in
            analyzer.analyze(url, settings: settings)
        }
    }

    nonisolated func sort(
        items: [FileItem],
        folderURL: URL,
        destinationBaseURL: URL?,
        settings: AppSettings,
        progress: ((SortProgress) -> Void)? = nil,
        onItemProcessed: ((FileItem) -> Void)? = nil
    ) async throws -> [FileItem] {
        var sortedItems: [FileItem] = []
        let totalFiles = items.count

        for item in items {
            try Task.checkCancellation()
            await Task.yield()

            let result = await moveOnIOQueue(
                item: item,
                sourceFolderURL: folderURL,
                destinationBaseURL: destinationBaseURL,
                settings: settings
            )
            sortedItems.append(result)
            onItemProcessed?(result)
            progress?(SortProgress(processedFiles: sortedItems.count, totalFiles: totalFiles, currentFileName: item.originalName))
        }

        progress?(SortProgress(processedFiles: sortedItems.count, totalFiles: totalFiles, currentFileName: ""))
        return sortedItems
    }

    nonisolated private func failedItem(_ item: FileItem, message: String) -> FileItem {
        var failedItem = item
        failedItem.status = .failed
        failedItem.errorMessage = message
        return failedItem
    }

    nonisolated private func moveOnIOQueue(
        item: FileItem,
        sourceFolderURL: URL,
        destinationBaseURL: URL?,
        settings: AppSettings
    ) async -> FileItem {
        let mover = self.mover
        return await withCheckedContinuation { continuation in
            Self.ioQueue.async {
                let moved = (try? mover.move(
                    item,
                    sourceFolderURL: sourceFolderURL,
                    destinationBaseURL: destinationBaseURL,
                    settings: settings
                )) ?? {
                    var failedItem = item
                    failedItem.status = .failed
                    failedItem.errorMessage = "Unbekannter Fehler"
                    return failedItem
                }()
                continuation.resume(returning: moved)
            }
        }
    }
}
