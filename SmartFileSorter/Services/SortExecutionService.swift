import Foundation

actor SortExecutionService: SortExecutionServing {
    private let sorter: FileSorter

    init(sorter: FileSorter) {
        self.sorter = sorter
    }

    func analyze(folderURL: URL, settings: AppSettings) async throws -> [FileItem] {
        try Task.checkCancellation()
        let items = try sorter.analyze(folderURL: folderURL, settings: settings)
        try Task.checkCancellation()
        return items
    }

    func sort(
        items: [FileItem],
        folderURL: URL,
        destinationBaseURL: URL?,
        settings: AppSettings,
        progress: @escaping (SortProgress) -> Void,
        onItemProcessed: @escaping (FileItem) -> Void
    ) async throws -> [FileItem] {
        try await sorter.sort(
            items: items,
            folderURL: folderURL,
            destinationBaseURL: destinationBaseURL,
            settings: settings,
            progress: progress,
            onItemProcessed: onItemProcessed
        )
    }
}
