import Foundation

struct FileAnalyzer {
    private let ruleManager: RuleManager

    init(ruleManager: RuleManager = RuleManager()) {
        self.ruleManager = ruleManager
    }

    func analyze(_ url: URL, settings: AppSettings) -> FileItem {
        let category = ruleManager.category(for: url)
        let status: FileStatus = category == .other && !settings.sortUnknownToOthers ? .skipped : .detected

        return FileItem(
            originalName: url.lastPathComponent,
            fileExtension: url.pathExtension.lowercased(),
            sourceURL: url,
            category: category,
            destinationURL: nil,
            status: status
        )
    }
}
