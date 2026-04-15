import Foundation

struct FileItem: Identifiable, Hashable {
    let id: UUID
    let originalName: String
    let fileExtension: String
    let sourceURL: URL
    var category: Category
    var destinationURL: URL?
    var status: FileStatus
    var errorMessage: String?
    var isIncluded = true

    init(
        id: UUID = UUID(),
        originalName: String,
        fileExtension: String,
        sourceURL: URL,
        category: Category,
        destinationURL: URL? = nil,
        status: FileStatus,
        errorMessage: String? = nil,
        isIncluded: Bool = true
    ) {
        self.id = id
        self.originalName = originalName
        self.fileExtension = fileExtension
        self.sourceURL = sourceURL
        self.category = category
        self.destinationURL = destinationURL
        self.status = status
        self.errorMessage = errorMessage
        self.isIncluded = isIncluded
    }
}

enum FileStatus: String, Hashable, Codable, CaseIterable {
    case detected = "Erkannt"
    case planned = "Geplant"
    case moved = "Verschoben"
    case skipped = "Übersprungen"
    case failed = "Fehler"
}
