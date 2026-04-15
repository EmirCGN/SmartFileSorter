import Foundation

struct SortTaskCoordinator: SortTaskCoordinating {
    private let executionService: any SortExecutionServing

    init(executionService: any SortExecutionServing) {
        self.executionService = executionService
    }

    func analyze(folderURL: URL, settings: AppSettings) async throws -> [FileItem] {
        try await executionService.analyze(folderURL: folderURL, settings: settings)
    }

    func sort(
        items: [FileItem],
        folderURL: URL,
        destinationBaseURL: URL?,
        settings: AppSettings,
        progress: @escaping (SortProgress) -> Void,
        onItemProcessed: @escaping (FileItem) -> Void
    ) async throws -> [FileItem] {
        try await executionService.sort(
            items: items,
            folderURL: folderURL,
            destinationBaseURL: destinationBaseURL,
            settings: settings,
            progress: progress,
            onItemProcessed: onItemProcessed
        )
    }
}
