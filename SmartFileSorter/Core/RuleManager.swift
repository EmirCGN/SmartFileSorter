import Foundation

struct RuleManager {
    func category(for url: URL) -> Category {
        let fileExtension = url.pathExtension.lowercased()

        if fileExtension == "app" || url.hasDirectoryPath && url.lastPathComponent.hasSuffix(".app") {
            return .apps
        }

        return Category.all.first { category in
            category.fileExtensions.contains(fileExtension)
        } ?? .other
    }
}
