import Foundation

@MainActor
protocol FolderPicking {
    func pickFolder() -> URL?
}

protocol Logging {
    func entry(_ kind: SortActionKind, _ message: String) -> SortAction
}

protocol UndoPerforming {
    func undo(_ actions: [SortUndoAction]) -> [SortAction]
}

protocol UndoHistoryStoring {
    func loadLatestActions() async -> [SortUndoAction]
    func saveLatestActions(_ actions: [SortUndoAction]) async
}

protocol SortWorkflowProviding {
    func makeUndoActions(from items: [FileItem]) -> [SortUndoAction]
    func makeUndoAction(for item: FileItem) -> SortUndoAction?
    func summary(for items: [FileItem]) -> SortSummary
    func logEntries(for items: [FileItem], logger: any Logging) -> [SortAction]
}

protocol SortExecutionServing: AnyObject {
    func analyze(folderURL: URL, settings: AppSettings) async throws -> [FileItem]
    func sort(
        items: [FileItem],
        folderURL: URL,
        destinationBaseURL: URL?,
        settings: AppSettings,
        progress: @escaping (SortProgress) -> Void,
        onItemProcessed: @escaping (FileItem) -> Void
    ) async throws -> [FileItem]
}

protocol SortTaskCoordinating {
    func analyze(folderURL: URL, settings: AppSettings) async throws -> [FileItem]
    func sort(
        items: [FileItem],
        folderURL: URL,
        destinationBaseURL: URL?,
        settings: AppSettings,
        progress: @escaping (SortProgress) -> Void,
        onItemProcessed: @escaping (FileItem) -> Void
    ) async throws -> [FileItem]
}

protocol UndoHistoryCoordinating {
    func loadActions() async -> [SortUndoAction]
    func saveActions(_ actions: [SortUndoAction]) async
}
