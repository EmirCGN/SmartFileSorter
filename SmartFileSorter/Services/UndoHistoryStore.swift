import Foundation

actor UndoHistoryStore: UndoHistoryStoring {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let fileURL: URL

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            self.fileURL = Self.defaultFileURL()
        }
    }

    func loadLatestActions() async -> [SortUndoAction] {
        guard let data = try? Data(contentsOf: fileURL),
              let actions = try? decoder.decode([SortUndoAction].self, from: data) else {
            return []
        }
        return actions
    }

    func saveLatestActions(_ actions: [SortUndoAction]) async {
        do {
            let directory = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if actions.isEmpty {
                try? FileManager.default.removeItem(at: fileURL)
                return
            }
            let data = try encoder.encode(actions)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            return
        }
    }

    private static func defaultFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let directory = base.appendingPathComponent("SmartFileSorter", isDirectory: true)
        return directory.appendingPathComponent("undo-history.json")
    }
}
