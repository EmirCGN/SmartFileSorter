import Foundation

struct RuleManager {
    private let categories: [Category]

    nonisolated init(categories: [Category] = RuleManager.loadCategories()) {
        self.categories = categories
    }

    nonisolated func category(for url: URL) -> Category {
        let fileExtension = url.pathExtension.lowercased()

        if fileExtension == "app" || (url.hasDirectoryPath && url.lastPathComponent.hasSuffix(".app")) {
            return category(withID: Category.apps.id) ?? .apps
        }

        return categories.first { category in
            category.fileExtensions.contains(fileExtension)
        } ?? category(withID: Category.other.id) ?? .other
    }

    nonisolated private func category(withID id: String) -> Category? {
        categories.first { $0.id == id }
    }

    nonisolated private static func loadCategories() -> [Category] {
        guard let url = Bundle.main.url(forResource: "DefaultRules", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let rules = try? JSONDecoder().decode(DefaultRules.self, from: data) else {
            return Category.all
        }

        let mappedCategories = rules.categories.compactMap { rule -> Category? in
            guard let fallback = Category.all.first(where: { $0.id == rule.id }) else { return nil }
            return Category(
                id: fallback.id,
                name: fallback.name,
                systemImage: fallback.systemImage,
                folderName: rule.folderName,
                fileExtensions: Set(rule.extensions.map { $0.lowercased() })
            )
        }

        let knownIDs = Set(mappedCategories.map(\.id))
        let missingFallbacks = Category.all.filter { !knownIDs.contains($0.id) }
        return mappedCategories + missingFallbacks
    }
}

private struct DefaultRules: Decodable {
    let categories: [DefaultRuleCategory]
}

private struct DefaultRuleCategory: Decodable {
    let id: String
    let folderName: String
    let extensions: [String]
}
