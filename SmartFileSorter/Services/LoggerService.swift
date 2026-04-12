import Foundation

struct LoggerService {
    func entry(_ kind: SortActionKind, _ message: String) -> SortAction {
        SortAction(kind: kind, message: message)
    }
}
