import Foundation

struct FileSorter {
    private let scanner: DirectoryScanner
    private let analyzer: FileAnalyzer
    private let mover: FileMover

    init(scanner: DirectoryScanner = DirectoryScanner(), analyzer: FileAnalyzer = FileAnalyzer(), mover: FileMover = FileMover()) {
        self.scanner = scanner
        self.analyzer = analyzer
        self.mover = mover
    }

    func analyze(folderURL: URL, settings: AppSettings) throws -> [FileItem] {
        try scanner.scan(folderURL: folderURL, settings: settings).map { url in
            analyzer.analyze(url, settings: settings)
        }
    }

    func sort(
        items: [FileItem],
        folderURL: URL,
        settings: AppSettings,
        progress: ((SortProgress) -> Void)? = nil,
        shouldCancel: (() -> Bool)? = nil
    ) -> [FileItem] {
        var sortedItems: [FileItem] = []
        let totalFiles = items.count

        for (index, item) in items.enumerated() {
            if shouldCancel?() == true {
                var skippedItem = item
                skippedItem.status = .skipped
                skippedItem.errorMessage = "Vorgang abgebrochen."
                sortedItems.append(skippedItem)
                continue
            }

            progress?(SortProgress(processedFiles: index, totalFiles: totalFiles, currentFileName: item.originalName))
            sortedItems.append((try? mover.move(item, sourceFolderURL: folderURL, settings: settings)) ?? failedItem(item, message: "Unbekannter Fehler"))
        }

        progress?(SortProgress(processedFiles: totalFiles, totalFiles: totalFiles, currentFileName: ""))
        return sortedItems
    }

    private func failedItem(_ item: FileItem, message: String) -> FileItem {
        var failedItem = item
        failedItem.status = .failed
        failedItem.errorMessage = message
        return failedItem
    }
}
