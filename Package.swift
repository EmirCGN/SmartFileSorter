// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "SmartFileSorterCore",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "SmartFileSorterCore", targets: ["SmartFileSorterCore"])
    ],
    targets: [
        .target(
            name: "SmartFileSorterCore",
            path: "SmartFileSorter",
            exclude: [
                "Assets.xcassets",
                "ContentView.swift",
                "SmartFileSorterApp.swift",
                "App",
                "ViewModels",
                "Views",
                "Services/FolderPickerService.swift"
            ],
            sources: [
                "Core/FileSystem.swift",
                "Core/ConflictResolver.swift",
                "Core/DirectoryScanner.swift",
                "Core/FileAnalyzer.swift",
                "Core/FileMover.swift",
                "Core/FileSorter.swift",
                "Core/RuleManager.swift",
                "Models/AppSettings.swift",
                "Models/Category.swift",
                "Models/FileItem.swift",
                "Models/SortAction.swift",
                "Models/SortSummary.swift",
                "Services/BookmarkService.swift",
                "Services/FileItemFilterService.swift",
                "Services/LoggerService.swift",
                "Services/ServiceProtocols.swift",
                "Services/SortExecutionService.swift",
                "Services/SortTaskCoordinator.swift",
                "Services/SortWorkflowService.swift",
                "Services/UndoHistoryCoordinator.swift",
                "Services/UndoHistoryStore.swift"
            ],
            resources: [
                .process("Resources/DefaultRules.json")
            ]
        ),
        .testTarget(
            name: "SmartFileSorterCoreTests",
            dependencies: ["SmartFileSorterCore"],
            path: "Tests/Unit"
        )
    ]
)
