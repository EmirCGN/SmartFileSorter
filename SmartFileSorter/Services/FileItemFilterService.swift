import Foundation

struct FileItemFilterService {
    nonisolated func filteredItems(
        items: [FileItem],
        searchText: String,
        categoryFilter: String,
        statusFilter: String,
        sortMode: String,
        maxItems: Int? = nil
    ) -> [FileItem] {
        let searchedItems = items.filter { item in
            let matchesSearch = searchText.isEmpty
                || item.originalName.localizedCaseInsensitiveContains(searchText)
                || item.category.name.localizedCaseInsensitiveContains(searchText)
                || destinationText(for: item).localizedCaseInsensitiveContains(searchText)
            let matchesCategory = categoryFilter == "all" || item.category.id == categoryFilter
            let matchesStatus = statusFilter == "all" || item.status.rawValue == statusFilter
            return matchesSearch && matchesCategory && matchesStatus
        }

        let sorted = searchedItems.sorted { lhs, rhs in
            switch sortMode {
            case "category":
                if lhs.category.name == rhs.category.name {
                    return lhs.originalName.localizedStandardCompare(rhs.originalName) == .orderedAscending
                }
                return lhs.category.name.localizedStandardCompare(rhs.category.name) == .orderedAscending
            case "status":
                if lhs.status.rawValue == rhs.status.rawValue {
                    return lhs.originalName.localizedStandardCompare(rhs.originalName) == .orderedAscending
                }
                return lhs.status.rawValue.localizedStandardCompare(rhs.status.rawValue) == .orderedAscending
            default:
                return lhs.originalName.localizedStandardCompare(rhs.originalName) == .orderedAscending
            }
        }

        if let maxItems, maxItems > 0, sorted.count > maxItems {
            return Array(sorted.prefix(maxItems))
        }
        return sorted
    }

    nonisolated private func destinationText(for item: FileItem) -> String {
        let fileName = item.destinationURL?.lastPathComponent ?? item.originalName
        return "\(item.category.folderName)/\(fileName)"
    }
}
