import Foundation

struct AppSettings: Hashable, Codable {
    var dryRun = true
    var ignoreHiddenFiles = true
    var ignoreSubfolders = true
    var resolveConflictsAutomatically = true
    var showLogs = true
    var sortUnknownToOthers = true
    var createMissingFolders = true
}

struct AppSettingsStore {
    private static let key = "SmartFileSorter.AppSettings"
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    static func load() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: key),
              let settings = try? decoder.decode(AppSettings.self, from: data) else {
            return AppSettings()
        }
        return settings
    }

    static func save(_ settings: AppSettings) {
        guard let data = try? encoder.encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
