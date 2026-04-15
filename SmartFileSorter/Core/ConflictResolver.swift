import Foundation

struct ConflictResolver {
    private let fileSystem: any FileSystemManaging

    nonisolated init(fileSystem: any FileSystemManaging = LocalFileSystem()) {
        self.fileSystem = fileSystem
    }

    nonisolated func resolvedURL(for proposedURL: URL) -> URL {
        guard fileSystem.fileExists(atPath: proposedURL.path) else {
            return proposedURL
        }

        let directoryURL = proposedURL.deletingLastPathComponent()
        let baseName = proposedURL.deletingPathExtension().lastPathComponent
        let fileExtension = proposedURL.pathExtension

        var counter = 1
        while true {
            let candidateName = fileExtension.isEmpty ? "\(baseName)_\(counter)" : "\(baseName)_\(counter).\(fileExtension)"
            let candidateURL = directoryURL.appendingPathComponent(candidateName)
            if !fileSystem.fileExists(atPath: candidateURL.path) {
                return candidateURL
            }
            counter += 1
        }
    }
}
