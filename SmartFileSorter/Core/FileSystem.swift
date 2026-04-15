import Foundation

protocol FileSystemManaging {
    nonisolated func contentsOfDirectory(at url: URL, includingPropertiesForKeys keys: [URLResourceKey]?) throws -> [URL]
    nonisolated func enumerator(at url: URL, includingPropertiesForKeys keys: [URLResourceKey]?, options: FileManager.DirectoryEnumerationOptions) -> FileManager.DirectoryEnumerator?
    nonisolated func fileExists(atPath path: String) -> Bool
    nonisolated func createDirectory(at url: URL, withIntermediateDirectories createIntermediates: Bool) throws
    nonisolated func moveItem(at srcURL: URL, to dstURL: URL) throws
}

struct LocalFileSystem: FileSystemManaging {
    private let manager: FileManager

    nonisolated init(manager: FileManager = .default) {
        self.manager = manager
    }

    nonisolated func contentsOfDirectory(at url: URL, includingPropertiesForKeys keys: [URLResourceKey]?) throws -> [URL] {
        try manager.contentsOfDirectory(at: url, includingPropertiesForKeys: keys)
    }

    nonisolated func enumerator(at url: URL, includingPropertiesForKeys keys: [URLResourceKey]?, options: FileManager.DirectoryEnumerationOptions) -> FileManager.DirectoryEnumerator? {
        manager.enumerator(at: url, includingPropertiesForKeys: keys, options: options)
    }

    nonisolated func fileExists(atPath path: String) -> Bool {
        manager.fileExists(atPath: path)
    }

    nonisolated func createDirectory(at url: URL, withIntermediateDirectories createIntermediates: Bool) throws {
        try manager.createDirectory(at: url, withIntermediateDirectories: createIntermediates)
    }

    nonisolated func moveItem(at srcURL: URL, to dstURL: URL) throws {
        try manager.moveItem(at: srcURL, to: dstURL)
    }
}
