import XCTest
@testable import SmartFileSorterCore

final class FileItemFilterServiceTests: XCTestCase {
    func testFilteringBySearchAndStatus() {
        let service = FileItemFilterService()
        let files = [
            FileItem(originalName: "invoice.pdf", fileExtension: "pdf", sourceURL: URL(fileURLWithPath: "/tmp/invoice.pdf"), category: .documents, status: .detected),
            FileItem(originalName: "photo.jpg", fileExtension: "jpg", sourceURL: URL(fileURLWithPath: "/tmp/photo.jpg"), category: .images, status: .planned),
            FileItem(originalName: "song.mp3", fileExtension: "mp3", sourceURL: URL(fileURLWithPath: "/tmp/song.mp3"), category: .audio, status: .failed)
        ]

        let result = service.filteredItems(
            items: files,
            searchText: "photo",
            categoryFilter: "all",
            statusFilter: FileStatus.planned.rawValue,
            sortMode: "name"
        )

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.originalName, "photo.jpg")
    }

    func testSortingByCategory() {
        let service = FileItemFilterService()
        let files = [
            FileItem(originalName: "z-file.jpg", fileExtension: "jpg", sourceURL: URL(fileURLWithPath: "/tmp/z-file.jpg"), category: .images, status: .detected),
            FileItem(originalName: "a-file.pdf", fileExtension: "pdf", sourceURL: URL(fileURLWithPath: "/tmp/a-file.pdf"), category: .documents, status: .detected)
        ]

        let result = service.filteredItems(
            items: files,
            searchText: "",
            categoryFilter: "all",
            statusFilter: "all",
            sortMode: "category"
        )

        XCTAssertEqual(result.map(\.originalName), ["z-file.jpg", "a-file.pdf"])
    }
}

final class UndoHistoryStoreTests: XCTestCase {
    func testRoundTripStoresAndLoads() async {
        let store = UndoHistoryStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("undo-store-\(UUID().uuidString).json"))
        let action = SortUndoAction(
            originalURL: URL(fileURLWithPath: "/tmp/original.txt"),
            movedURL: URL(fileURLWithPath: "/tmp/moved.txt"),
            fileName: "original.txt"
        )

        await store.saveLatestActions([action])
        let loaded = await store.loadLatestActions()
        await store.saveLatestActions([])

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.fileName, "original.txt")
    }
}

final class AppSettingsStoreMigrationTests: XCTestCase {
    private let defaultsSuite = "SmartFileSorter.SettingsTests"
    private let settingsKey = "SmartFileSorter.AppSettings"

    override func tearDown() {
        super.tearDown()
        UserDefaults(suiteName: defaultsSuite)?.removePersistentDomain(forName: defaultsSuite)
    }

    func testLegacyPayloadLoadsWithDefaultsForMissingFields() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsSuite))
        let legacyPayload = #"{"dryRun":false,"ignoreHiddenFiles":false}"#.data(using: .utf8)
        defaults.set(legacyPayload, forKey: settingsKey)

        let result = AppSettingsStore(defaults: defaults).load()

        XCTAssertFalse(result.settings.dryRun)
        XCTAssertFalse(result.settings.ignoreHiddenFiles)
        XCTAssertEqual(result.settings.schemaVersion, AppSettings.currentSchemaVersion)
        XCTAssertEqual(result.settings.ignoreSubfolders, AppSettings().ignoreSubfolders)
        XCTAssertNotNil(result.diagnosticMessage)
    }

    func testCorruptPayloadFallsBackToDefaultsWithDiagnostic() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsSuite))
        defaults.set(Data("invalid-json".utf8), forKey: settingsKey)

        let result = AppSettingsStore(defaults: defaults).load()

        XCTAssertEqual(result.settings, AppSettings())
        XCTAssertNotNil(result.diagnosticMessage)
    }
}
