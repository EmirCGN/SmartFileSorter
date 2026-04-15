import Foundation

struct SortSummary: Hashable {
    var totalFiles = 0
    var movedFiles = 0
    var skippedFiles = 0
    var failedFiles = 0

    static let empty = SortSummary()
}

struct SortProgress: Hashable {
    var processedFiles = 0
    var totalFiles = 0
    var currentFileName = ""

    var fractionCompleted: Double {
        guard totalFiles > 0 else { return 0 }
        return Double(processedFiles) / Double(totalFiles)
    }

    static let empty = SortProgress()
}

struct SortUndoAction: Identifiable, Hashable {
    let id = UUID()
    let originalURL: URL
    let movedURL: URL
    let fileName: String
}
