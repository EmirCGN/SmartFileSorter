import Foundation

struct SortSummary: Hashable {
    var totalFiles = 0
    var movedFiles = 0
    var skippedFiles = 0
    var failedFiles = 0

    static let empty = SortSummary()
}
