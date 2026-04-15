import XCTest
@testable import SmartFileSorter

final class SmartFileSorterCoreBehaviorTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SmartFileSorter-XcodeTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
    }

    func testConflictResolverAppendsCounterWhenTargetExists() {
        let proposedURL = tempDirectory.appendingPathComponent("report.pdf")
        FileManager.default.createFile(atPath: proposedURL.path, contents: Data())

        let resolvedURL = ConflictResolver().resolvedURL(for: proposedURL)

        XCTAssertEqual(resolvedURL.lastPathComponent, "report_1.pdf")
    }

    func testFileMoverDryRunPlansMoveWithoutMovingFile() {
        let sourceURL = tempDirectory.appendingPathComponent("photo.jpg")
        FileManager.default.createFile(atPath: sourceURL.path, contents: Data())

        let item = FileItem(
            originalName: "photo.jpg",
            fileExtension: "jpg",
            sourceURL: sourceURL,
            category: .images,
            status: .detected
        )

        var settings = AppSettings()
        settings.dryRun = true

        let result = try? FileMover().move(item, sourceFolderURL: tempDirectory, destinationBaseURL: nil, settings: settings)

        XCTAssertEqual(result?.status, .planned)
        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceURL.path))
    }

    func testFileMoverFailsOnExistingTargetWithoutAutoConflictResolution() {
        let sourceURL = tempDirectory.appendingPathComponent("invoice.pdf")
        FileManager.default.createFile(atPath: sourceURL.path, contents: Data())

        let destinationFolder = tempDirectory.appendingPathComponent("Dokumente", isDirectory: true)
        try? FileManager.default.createDirectory(at: destinationFolder, withIntermediateDirectories: true)
        let conflictingTarget = destinationFolder.appendingPathComponent("invoice.pdf")
        FileManager.default.createFile(atPath: conflictingTarget.path, contents: Data())

        let item = FileItem(
            originalName: "invoice.pdf",
            fileExtension: "pdf",
            sourceURL: sourceURL,
            category: .documents,
            status: .detected
        )

        var settings = AppSettings()
        settings.dryRun = false
        settings.resolveConflictsAutomatically = false

        let result = try? FileMover().move(item, sourceFolderURL: tempDirectory, destinationBaseURL: nil, settings: settings)

        XCTAssertEqual(result?.status, .failed)
        XCTAssertNotNil(result?.errorMessage)
    }

    func testDirectoryScannerSkipsHiddenFilesWhenConfigured() throws {
        let visible = tempDirectory.appendingPathComponent("visible.txt")
        let hidden = tempDirectory.appendingPathComponent(".hidden.txt")
        FileManager.default.createFile(atPath: visible.path, contents: Data())
        FileManager.default.createFile(atPath: hidden.path, contents: Data())

        var settings = AppSettings()
        settings.ignoreSubfolders = true
        settings.ignoreHiddenFiles = true

        let urls = try DirectoryScanner().scan(folderURL: tempDirectory, settings: settings)

        XCTAssertTrue(urls.contains(visible))
        XCTAssertFalse(urls.contains(hidden))
    }

    func testDirectoryScannerIncludesNestedFilesWhenSubfoldersEnabled() throws {
        let nestedFolder = tempDirectory.appendingPathComponent("nested", isDirectory: true)
        try FileManager.default.createDirectory(at: nestedFolder, withIntermediateDirectories: true)
        let nestedFile = nestedFolder.appendingPathComponent("note.txt")
        FileManager.default.createFile(atPath: nestedFile.path, contents: Data())

        var settings = AppSettings()
        settings.ignoreSubfolders = false

        let urls = try DirectoryScanner().scan(folderURL: tempDirectory, settings: settings)

        XCTAssertTrue(urls.contains(nestedFile))
    }

    func testDirectoryScannerSkipsPackageDescendants() throws {
        let appPackage = tempDirectory.appendingPathComponent("Sample.app", isDirectory: true)
        try FileManager.default.createDirectory(at: appPackage, withIntermediateDirectories: true)

        let innerFile = appPackage.appendingPathComponent("Contents/MacOS/bin")
        try FileManager.default.createDirectory(at: innerFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: innerFile.path, contents: Data())

        var settings = AppSettings()
        settings.ignoreSubfolders = false

        let urls = try DirectoryScanner().scan(folderURL: tempDirectory, settings: settings)

        XCTAssertFalse(urls.contains(innerFile))
    }

    func testSortWorkflowCreatesUndoActionsOnlyForMovedItems() {
        let movedSource = tempDirectory.appendingPathComponent("moved.txt")
        let movedDestination = tempDirectory.appendingPathComponent("Dokumente/moved.txt")

        let moved = FileItem(
            originalName: "moved.txt",
            fileExtension: "txt",
            sourceURL: movedSource,
            category: .documents,
            destinationURL: movedDestination,
            status: .moved
        )

        let skipped = FileItem(
            originalName: "skipped.txt",
            fileExtension: "txt",
            sourceURL: tempDirectory.appendingPathComponent("skipped.txt"),
            category: .documents,
            status: .skipped
        )

        let actions = SortWorkflowService().makeUndoActions(from: [moved, skipped])

        XCTAssertEqual(actions.count, 1)
        XCTAssertEqual(actions.first?.fileName, "moved.txt")
    }

    func testUndoServiceMovesFileBackToOriginalLocation() {
        let originalURL = tempDirectory.appendingPathComponent("original.txt")
        let movedFolder = tempDirectory.appendingPathComponent("Dokumente", isDirectory: true)
        try? FileManager.default.createDirectory(at: movedFolder, withIntermediateDirectories: true)

        let movedURL = movedFolder.appendingPathComponent("original.txt")
        FileManager.default.createFile(atPath: movedURL.path, contents: Data())

        let action = SortUndoAction(originalURL: originalURL, movedURL: movedURL, fileName: "original.txt")
        let entries = UndoService().undo([action])

        XCTAssertTrue(entries.contains(where: { $0.kind == .success }))
        XCTAssertTrue(FileManager.default.fileExists(atPath: originalURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: movedURL.path))
    }
}
