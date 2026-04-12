import Foundation

struct ConflictResolver {
    private let fileManager = FileManager.default

    func resolvedURL(for proposedURL: URL) -> URL {
        guard fileManager.fileExists(atPath: proposedURL.path) else {
            return proposedURL
        }

        let directoryURL = proposedURL.deletingLastPathComponent()
        let baseName = proposedURL.deletingPathExtension().lastPathComponent
        let fileExtension = proposedURL.pathExtension

        var counter = 1
        while true {
            let candidateName = fileExtension.isEmpty ? "\(baseName)_\(counter)" : "\(baseName)_\(counter).\(fileExtension)"
            let candidateURL = directoryURL.appendingPathComponent(candidateName)
            if !fileManager.fileExists(atPath: candidateURL.path) {
                return candidateURL
            }
            counter += 1
        }
    }
}
