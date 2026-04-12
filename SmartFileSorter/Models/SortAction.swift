import Foundation

struct SortAction: Identifiable, Hashable {
    let id = UUID()
    let date = Date()
    let kind: SortActionKind
    let message: String
}

enum SortActionKind: String, Hashable {
    case info = "Info"
    case success = "Erfolg"
    case warning = "Warnung"
    case error = "Fehler"
}
