import Foundation

struct FileItem: Identifiable, Hashable {
    let id = UUID()
    let originalName: String
    let fileExtension: String
    let sourceURL: URL
    var category: Category
    var destinationURL: URL?
    var status: FileStatus
}

enum FileStatus: String, Hashable {
    case detected = "Erkannt"
    case planned = "Geplant"
    case moved = "Verschoben"
    case skipped = "Übersprungen"
    case failed = "Fehler"
}
