import Foundation

struct AppSettings: Hashable {
    var dryRun = true
    var ignoreHiddenFiles = true
    var ignoreSubfolders = true
    var resolveConflictsAutomatically = true
    var showLogs = true
    var sortUnknownToOthers = true
    var createMissingFolders = true
}
