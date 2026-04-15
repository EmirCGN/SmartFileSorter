import XCTest
@testable import SmartFileSorter

final class SmartFileSorterXcodeTests: XCTestCase {
    func testSortProgressFractionCompleted() {
        let progress = SortProgress(processedFiles: 5, totalFiles: 10, currentFileName: "")
        XCTAssertEqual(progress.fractionCompleted, 0.5)
    }

    func testDefaultSettingsUseDryRun() {
        let settings = AppSettings()
        XCTAssertTrue(settings.dryRun)
    }

    @MainActor
    func testMainViewModelLogsSettingsDiagnosticOnLoad() {
        let settingsStore = MockSettingsStore(
            loadResult: SettingsLoadResult(
                settings: AppSettings(),
                diagnosticMessage: "Migration executed"
            )
        )

        let viewModel = MainViewModel(
            folderPicker: MockFolderPicker(),
            logger: LoggerService(),
            undoService: UndoService(),
            workflowService: SortWorkflowService(),
            sortTaskCoordinator: MockSortTaskCoordinator(),
            undoHistoryCoordinator: MockUndoHistoryCoordinator(),
            settingsStore: settingsStore,
            bookmarkService: BookmarkService()
        )

        XCTAssertEqual(viewModel.logEntries.first?.kind, .warning)
        XCTAssertEqual(viewModel.logEntries.first?.message, "Migration executed")
    }

    @MainActor
    func testSetIncludedUsesIndexedLookupAndUpdatesSummary() {
        let files = [
            FileItem(
                originalName: "a.pdf",
                fileExtension: "pdf",
                sourceURL: URL(fileURLWithPath: "/tmp/a.pdf"),
                category: .documents,
                status: .detected
            ),
            FileItem(
                originalName: "b.jpg",
                fileExtension: "jpg",
                sourceURL: URL(fileURLWithPath: "/tmp/b.jpg"),
                category: .images,
                status: .detected
            )
        ]

        let viewModel = MainViewModel(
            folderPicker: MockFolderPicker(),
            logger: LoggerService(),
            undoService: UndoService(),
            workflowService: SortWorkflowService(),
            sortTaskCoordinator: MockSortTaskCoordinator(),
            undoHistoryCoordinator: MockUndoHistoryCoordinator(),
            settingsStore: MockSettingsStore(loadResult: SettingsLoadResult(settings: AppSettings(), diagnosticMessage: nil)),
            bookmarkService: BookmarkService()
        )

        viewModel.detectedFiles = files
        viewModel.setIncluded(false, for: files[1])

        XCTAssertFalse(viewModel.detectedFiles[1].isIncluded)
        XCTAssertEqual(viewModel.detectedFiles[1].status, .skipped)
        XCTAssertEqual(viewModel.summary.skippedFiles, 1)
    }
}

@MainActor
private struct MockFolderPicker: FolderPicking {
    func pickFolder() -> URL? { nil }
}

private struct MockSettingsStore: AppSettingsStoring {
    var loadResult: SettingsLoadResult
    var savedSettings: [AppSettings] = []

    func load() -> SettingsLoadResult {
        loadResult
    }

    func save(_ settings: AppSettings) {
        _ = settings
    }
}

private struct MockUndoHistoryCoordinator: UndoHistoryCoordinating {
    func loadActions() async -> [SortUndoAction] { [] }
    func saveActions(_ actions: [SortUndoAction]) async {
        _ = actions
    }
}

private struct MockSortTaskCoordinator: SortTaskCoordinating {
    var analyzeItems: [FileItem] = []
    var sortItems: [FileItem] = []

    func analyze(folderURL: URL, settings: AppSettings) async throws -> [FileItem] {
        _ = folderURL
        _ = settings
        return analyzeItems
    }

    func sort(
        items: [FileItem],
        folderURL: URL,
        destinationBaseURL: URL?,
        settings: AppSettings,
        progress: @escaping (SortProgress) -> Void,
        onItemProcessed: @escaping (FileItem) -> Void
    ) async throws -> [FileItem] {
        _ = items
        _ = folderURL
        _ = destinationBaseURL
        _ = settings
        progress(SortProgress(processedFiles: sortItems.count, totalFiles: sortItems.count, currentFileName: ""))
        sortItems.forEach(onItemProcessed)
        return sortItems
    }
}
