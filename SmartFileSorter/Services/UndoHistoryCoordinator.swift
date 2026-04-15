import Foundation

struct UndoHistoryCoordinator: UndoHistoryCoordinating {
    private let store: any UndoHistoryStoring

    init(store: any UndoHistoryStoring) {
        self.store = store
    }

    func loadActions() async -> [SortUndoAction] {
        await store.loadLatestActions()
    }

    func saveActions(_ actions: [SortUndoAction]) async {
        await store.saveLatestActions(actions)
    }
}
