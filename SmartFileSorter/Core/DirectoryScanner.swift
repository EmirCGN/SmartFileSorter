import Foundation

struct DirectoryScanner {
    private let fileSystem: any FileSystemManaging
    private let resourceKeys: [URLResourceKey] = [.isRegularFileKey, .isDirectoryKey, .isPackageKey, .isHiddenKey]

    nonisolated init(fileSystem: any FileSystemManaging = LocalFileSystem()) {
        self.fileSystem = fileSystem
    }

    nonisolated func scan(folderURL: URL, settings: AppSettings) throws -> [URL] {
        if settings.ignoreSubfolders {
            let urls = try fileSystem.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: resourceKeys)
            return urls.filter { shouldInclude($0, settings: settings) }
        }

        var options: FileManager.DirectoryEnumerationOptions = [.skipsPackageDescendants]
        if settings.ignoreHiddenFiles {
            options.insert(.skipsHiddenFiles)
        }

        guard let enumerator = fileSystem.enumerator(at: folderURL, includingPropertiesForKeys: resourceKeys, options: options) else {
            return []
        }

        return enumerator.compactMap { item in
            guard let url = item as? URL else { return nil }
            return shouldInclude(url, settings: settings) ? url : nil
        }
    }

    nonisolated private func shouldInclude(_ url: URL, settings: AppSettings) -> Bool {
        guard let values = try? url.resourceValues(forKeys: Set(resourceKeys)) else {
            return false
        }

        if settings.ignoreHiddenFiles && (values.isHidden == true || url.lastPathComponent.hasPrefix(".")) {
            return false
        }

        return values.isRegularFile == true || values.isPackage == true
    }
}
