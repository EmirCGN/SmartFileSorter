import Foundation

@discardableResult
func expect(_ condition: @autoclosure () -> Bool, _ message: String) -> Bool {
    if condition() { return true }
    fputs("FAIL: \(message)\n", stderr)
    return false
}

func runConflictResolverTest(in tempDir: URL) -> Bool {
    let existing = tempDir.appendingPathComponent("report.pdf")
    FileManager.default.createFile(atPath: existing.path, contents: Data(), attributes: nil)

    let resolved = ConflictResolver().resolvedURL(for: existing)
    return expect(resolved.lastPathComponent == "report_1.pdf", "ConflictResolver should append numeric suffix")
}

func runDryRunMoveTest(in tempDir: URL) -> Bool {
    let source = tempDir.appendingPathComponent("photo.jpg")
    FileManager.default.createFile(atPath: source.path, contents: Data(), attributes: nil)

    let item = FileItem(
        originalName: "photo.jpg",
        fileExtension: "jpg",
        sourceURL: source,
        category: .images,
        status: .detected
    )

    var settings = AppSettings()
    settings.dryRun = true

    let result = (try? FileMover().move(item, sourceFolderURL: tempDir, destinationBaseURL: nil, settings: settings))
    guard let result else {
        return expect(false, "FileMover dry-run returned nil")
    }

    let expectedDestination = tempDir.appendingPathComponent("Bilder").appendingPathComponent("photo.jpg")
    return expect(result.status == .planned && result.destinationURL == expectedDestination, "Dry-run should plan move without touching files")
}

func runNoOverwriteTest(in tempDir: URL) -> Bool {
    let source = tempDir.appendingPathComponent("invoice.pdf")
    let destinationFolder = tempDir.appendingPathComponent("Dokumente", isDirectory: true)
    let destination = destinationFolder.appendingPathComponent("invoice.pdf")

    try? FileManager.default.createDirectory(at: destinationFolder, withIntermediateDirectories: true)
    FileManager.default.createFile(atPath: source.path, contents: Data(), attributes: nil)
    FileManager.default.createFile(atPath: destination.path, contents: Data(), attributes: nil)

    let item = FileItem(
        originalName: "invoice.pdf",
        fileExtension: "pdf",
        sourceURL: source,
        category: .documents,
        status: .detected
    )

    var settings = AppSettings()
    settings.dryRun = false
    settings.resolveConflictsAutomatically = false

    let result = (try? FileMover().move(item, sourceFolderURL: tempDir, destinationBaseURL: nil, settings: settings))
    guard let result else {
        return expect(false, "FileMover conflict test returned nil")
    }

    return expect(result.status == .failed, "FileMover should fail instead of overwriting existing file")
}

func runUndoStoreRoundTripTest() -> Bool {
    let store = UndoHistoryStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("undo-smoke-\(UUID().uuidString).json"))
    let action = SortUndoAction(
        originalURL: URL(fileURLWithPath: "/tmp/original.txt"),
        movedURL: URL(fileURLWithPath: "/tmp/moved.txt"),
        fileName: "original.txt"
    )

    let semaphore = DispatchSemaphore(value: 0)
    var loaded: [SortUndoAction] = []
    Task {
        await store.saveLatestActions([action])
        loaded = await store.loadLatestActions()
        await store.saveLatestActions([])
        semaphore.signal()
    }
    semaphore.wait()

    return expect(loaded.count == 1 && loaded.first?.fileName == "original.txt", "UndoHistoryStore should persist and restore latest actions")
}

let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("SmartFileSorter-SmokeTests-\(UUID().uuidString)", isDirectory: true)
try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: tempDir) }

let checks: [Bool] = [
    runConflictResolverTest(in: tempDir),
    runDryRunMoveTest(in: tempDir),
    runNoOverwriteTest(in: tempDir),
    runUndoStoreRoundTripTest()
]

if checks.allSatisfy({ $0 }) {
    print("All smoke tests passed.")
    exit(EXIT_SUCCESS)
}

exit(EXIT_FAILURE)
