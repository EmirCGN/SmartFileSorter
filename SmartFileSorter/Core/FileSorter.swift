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

    func sort(items: [FileItem], folderURL: URL, settings: AppSettings) -> [FileItem] {
        items.map { item in
            do {
                return try mover.move(item, sourceFolderURL: folderURL, settings: settings)
            } catch {
                var failedItem = item
                failedItem.status = .failed
                return failedItem
            }
        }
    }
}
