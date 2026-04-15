import Foundation

struct AppSettings: Hashable, Codable {
    static let currentSchemaVersion = 2

    var schemaVersion = AppSettings.currentSchemaVersion
    var dryRun = true
    var ignoreHiddenFiles = true
    var ignoreSubfolders = true
    var resolveConflictsAutomatically = true
    var showLogs = true
    var sortUnknownToOthers = true
    var createMissingFolders = true
    var destinationBasePath: String?
    var destinationBaseBookmarkData: Data?

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case dryRun
        case ignoreHiddenFiles
        case ignoreSubfolders
        case resolveConflictsAutomatically
        case showLogs
        case sortUnknownToOthers
        case createMissingFolders
        case destinationBasePath
        case destinationBaseBookmarkData
    }

    init() {}

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = AppSettings()

        schemaVersion = max(
            (try? container.decodeIfPresent(Int.self, forKey: .schemaVersion)) ?? 0,
            AppSettings.currentSchemaVersion
        )
        dryRun = (try? container.decodeIfPresent(Bool.self, forKey: .dryRun)) ?? defaults.dryRun
        ignoreHiddenFiles = (try? container.decodeIfPresent(Bool.self, forKey: .ignoreHiddenFiles)) ?? defaults.ignoreHiddenFiles
        ignoreSubfolders = (try? container.decodeIfPresent(Bool.self, forKey: .ignoreSubfolders)) ?? defaults.ignoreSubfolders
        resolveConflictsAutomatically = (try? container.decodeIfPresent(Bool.self, forKey: .resolveConflictsAutomatically)) ?? defaults.resolveConflictsAutomatically
        showLogs = (try? container.decodeIfPresent(Bool.self, forKey: .showLogs)) ?? defaults.showLogs
        sortUnknownToOthers = (try? container.decodeIfPresent(Bool.self, forKey: .sortUnknownToOthers)) ?? defaults.sortUnknownToOthers
        createMissingFolders = (try? container.decodeIfPresent(Bool.self, forKey: .createMissingFolders)) ?? defaults.createMissingFolders
        destinationBasePath = (try? container.decodeIfPresent(String.self, forKey: .destinationBasePath)) ?? defaults.destinationBasePath
        destinationBaseBookmarkData = (try? container.decodeIfPresent(Data.self, forKey: .destinationBaseBookmarkData)) ?? defaults.destinationBaseBookmarkData
    }
}

struct SettingsLoadResult {
    let settings: AppSettings
    let diagnosticMessage: String?
}

protocol AppSettingsStoring {
    func load() -> SettingsLoadResult
    func save(_ settings: AppSettings)
}

struct AppSettingsStore: AppSettingsStoring {
    private static let key = "SmartFileSorter.AppSettings"
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> SettingsLoadResult {
        guard let data = defaults.data(forKey: Self.key) else {
            return SettingsLoadResult(settings: AppSettings(), diagnosticMessage: nil)
        }

        do {
            let decoded = try Self.decoder.decode(AppSettings.self, from: data)
            let normalized = normalizedSettings(decoded)
            let migrated = decoded.schemaVersion < AppSettings.currentSchemaVersion || !hasSchemaVersionKey(in: data)
            if migrated || normalized != decoded {
                save(normalized)
                return SettingsLoadResult(
                    settings: normalized,
                    diagnosticMessage: "Einstellungen wurden auf das aktuelle Format migriert."
                )
            }
            return SettingsLoadResult(settings: normalized, diagnosticMessage: nil)
        } catch {
            let fallback = AppSettings()
            save(fallback)
            return SettingsLoadResult(
                settings: fallback,
                diagnosticMessage: "Einstellungen konnten nicht geladen werden (\(error.localizedDescription)). Standardwerte wurden wiederhergestellt."
            )
        }
    }

    func save(_ settings: AppSettings) {
        let normalized = normalizedSettings(settings)
        guard let data = try? Self.encoder.encode(normalized) else { return }
        defaults.set(data, forKey: Self.key)
    }

    private func normalizedSettings(_ settings: AppSettings) -> AppSettings {
        var normalized = settings
        normalized.schemaVersion = AppSettings.currentSchemaVersion
        return normalized
    }

    private func hasSchemaVersionKey(in data: Data) -> Bool {
        guard let object = try? JSONSerialization.jsonObject(with: data),
              let dictionary = object as? [String: Any] else {
            return false
        }
        return dictionary.keys.contains("schemaVersion")
    }
}
