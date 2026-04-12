import AppKit
import Foundation
import Observation
import SwiftUI

struct Category: Identifiable, Hashable {
    let id: String
    let name: String
    let systemImage: String
    let folderName: String
    let fileExtensions: Set<String>

    static let images = Category(id: "images", name: "Bilder", systemImage: "photo", folderName: "Bilder", fileExtensions: ["jpg", "jpeg", "png", "gif", "heic", "webp", "tiff", "bmp", "svg"])
    static let documents = Category(id: "documents", name: "Dokumente", systemImage: "doc.text", folderName: "Dokumente", fileExtensions: ["pdf", "doc", "docx", "txt", "rtf", "md", "pages", "numbers", "key", "xls", "xlsx", "ppt", "pptx", "csv"])
    static let archives = Category(id: "archives", name: "Archive", systemImage: "archivebox", folderName: "Archive", fileExtensions: ["zip", "rar", "7z", "tar", "gz", "bz2", "xz"])
    static let audio = Category(id: "audio", name: "Audio", systemImage: "waveform", folderName: "Audio", fileExtensions: ["mp3", "m4a", "wav", "aiff", "flac", "aac", "ogg"])
    static let videos = Category(id: "videos", name: "Videos", systemImage: "film", folderName: "Videos", fileExtensions: ["mp4", "mov", "m4v", "avi", "mkv", "webm"])
    static let apps = Category(id: "apps", name: "Apps", systemImage: "app", folderName: "Apps", fileExtensions: ["app", "dmg", "pkg"])
    static let other = Category(id: "other", name: "Sonstiges", systemImage: "questionmark.folder", folderName: "Sonstiges", fileExtensions: [])

    static let all: [Category] = [.images, .documents, .archives, .audio, .videos, .apps, .other]
}

struct AppSettings: Hashable {
    var dryRun = true
    var ignoreHiddenFiles = true
    var ignoreSubfolders = true
    var resolveConflictsAutomatically = true
    var showLogs = true
    var sortUnknownToOthers = true
    var createMissingFolders = true
}

enum AppState: String {
    case ready = "Bereit"
    case analyzing = "Analysiere"
    case sorting = "Sortiere"
    case finished = "Fertig"
    case failed = "Fehler"
}

enum FileStatus: String, Hashable {
    case detected = "Erkannt"
    case planned = "Geplant"
    case moved = "Verschoben"
    case skipped = "Übersprungen"
    case failed = "Fehler"
}

struct FileItem: Identifiable, Hashable {
    let id = UUID()
    let originalName: String
    let fileExtension: String
    let sourceURL: URL
    var category: Category
    var destinationURL: URL?
    var status: FileStatus
    var errorMessage: String?
}

enum SortActionKind: String, Hashable {
    case info = "Info"
    case success = "Erfolg"
    case warning = "Warnung"
    case error = "Fehler"
}

struct SortAction: Identifiable, Hashable {
    let id = UUID()
    let date = Date()
    let kind: SortActionKind
    let message: String
}

struct SortSummary: Hashable {
    var totalFiles = 0
    var movedFiles = 0
    var skippedFiles = 0
    var failedFiles = 0

    static let empty = SortSummary()
}

struct RuleManager {
    func category(for url: URL) -> Category {
        let fileExtension = url.pathExtension.lowercased()

        if fileExtension == "app" || (url.hasDirectoryPath && url.lastPathComponent.hasSuffix(".app")) {
            return .apps
        }

        return Category.all.first { category in
            category.fileExtensions.contains(fileExtension)
        } ?? .other
    }
}

struct DirectoryScanner {
    private let fileManager = FileManager.default
    private let resourceKeys: Set<URLResourceKey> = [.isRegularFileKey, .isPackageKey, .isHiddenKey]

    func scan(folderURL: URL, settings: AppSettings) throws -> [URL] {
        if settings.ignoreSubfolders {
            let urls = try fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: Array(resourceKeys))
            return urls.filter { shouldInclude($0, settings: settings) }
        }

        let options: FileManager.DirectoryEnumerationOptions = settings.ignoreHiddenFiles ? [.skipsHiddenFiles] : []
        guard let enumerator = fileManager.enumerator(at: folderURL, includingPropertiesForKeys: Array(resourceKeys), options: options) else {
            return []
        }

        return enumerator.compactMap { item in
            guard let url = item as? URL else { return nil }
            return shouldInclude(url, settings: settings) ? url : nil
        }
    }

    private func shouldInclude(_ url: URL, settings: AppSettings) -> Bool {
        guard let values = try? url.resourceValues(forKeys: resourceKeys) else {
            return false
        }

        if settings.ignoreHiddenFiles && (values.isHidden == true || url.lastPathComponent.hasPrefix(".")) {
            return false
        }

        return values.isRegularFile == true || values.isPackage == true
    }
}

struct ConflictResolver {
    private let fileManager = FileManager.default

    func resolvedURL(for proposedURL: URL) -> URL {
        guard fileManager.fileExists(atPath: proposedURL.path) else { return proposedURL }

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

struct FileSorter {
    private let scanner = DirectoryScanner()
    private let ruleManager = RuleManager()
    private let conflictResolver = ConflictResolver()
    private let fileManager = FileManager.default

    func analyze(folderURL: URL, settings: AppSettings) throws -> [FileItem] {
        try scanner.scan(folderURL: folderURL, settings: settings).map { url in
            let category = ruleManager.category(for: url)
            let status: FileStatus = category == .other && !settings.sortUnknownToOthers ? .skipped : .detected
            return FileItem(originalName: url.lastPathComponent, fileExtension: url.pathExtension.lowercased(), sourceURL: url, category: category, status: status)
        }
    }

    func sort(items: [FileItem], folderURL: URL, settings: AppSettings) -> [FileItem] {
        items.map { item in
            var updatedItem = item

            if item.category == .other && !settings.sortUnknownToOthers {
                updatedItem.status = .skipped
                return updatedItem
            }

            let targetFolderURL = folderURL.appendingPathComponent(item.category.folderName, isDirectory: true)
            let proposedURL = targetFolderURL.appendingPathComponent(item.originalName)
            let destinationURL = settings.resolveConflictsAutomatically ? conflictResolver.resolvedURL(for: proposedURL) : proposedURL
            updatedItem.destinationURL = destinationURL

            if settings.dryRun {
                updatedItem.status = .planned
                return updatedItem
            }

            do {
                if settings.createMissingFolders {
                    try fileManager.createDirectory(at: targetFolderURL, withIntermediateDirectories: true)
                }
                try fileManager.moveItem(at: item.sourceURL, to: destinationURL)
                updatedItem.status = .moved
            } catch {
                updatedItem.status = .failed
                updatedItem.errorMessage = error.localizedDescription
            }

            return updatedItem
        }
    }
}

@MainActor
@Observable
final class MainViewModel {
    var selectedFolderURL: URL?
    var settings = AppSettings()
    var detectedFiles: [FileItem] = []
    var logEntries: [SortAction] = []
    var summary = SortSummary.empty
    var appState: AppState = .ready

    private let sorter = FileSorter()

    var selectedFolderPath: String {
        selectedFolderURL?.path ?? "Noch kein Ordner ausgewählt"
    }

    var isRunning: Bool {
        appState == .analyzing || appState == .sorting
    }

    var canAnalyze: Bool {
        selectedFolderURL != nil && !isRunning
    }

    var canSort: Bool {
        selectedFolderURL != nil && !detectedFiles.isEmpty && !isRunning
    }

    func pickFolder() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.prompt = "Auswählen"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        selectedFolderURL = url
        detectedFiles = []
        summary = .empty
        logEntries = [SortAction(kind: .info, message: "Ordner ausgewählt: \(url.lastPathComponent)")]
        appState = .ready
    }

    func analyzeSelectedFolder() async {
        guard let selectedFolderURL else { return }

        appState = .analyzing
        summary = .empty
        logEntries.append(SortAction(kind: .info, message: "Analyse gestartet."))

        do {
            let items = try sorter.analyze(folderURL: selectedFolderURL, settings: settings)
            detectedFiles = items
            summary = summary(for: items)
            logEntries.append(SortAction(kind: items.isEmpty ? .warning : .success, message: items.isEmpty ? "Keine passenden Dateien gefunden." : "Analyse abgeschlossen: \(items.count) Dateien erkannt."))
            appState = .finished
        } catch {
            logEntries.append(SortAction(kind: .error, message: "Analyse fehlgeschlagen: \(error.localizedDescription)"))
            appState = .failed
        }
    }

    func sortSelectedFolder() async {
        guard let selectedFolderURL else { return }
        if detectedFiles.isEmpty { await analyzeSelectedFolder() }

        appState = .sorting
        logEntries.append(SortAction(kind: .info, message: settings.dryRun ? "Dry Run gestartet." : "Sortierung gestartet."))

        detectedFiles = sorter.sort(items: detectedFiles, folderURL: selectedFolderURL, settings: settings)
        summary = summary(for: detectedFiles)

        let failures = detectedFiles.filter { $0.status == .failed }
        if failures.isEmpty {
            logEntries.append(SortAction(kind: .success, message: settings.dryRun ? "Dry Run abgeschlossen." : "Sortierung abgeschlossen."))
        } else {
            logEntries.append(SortAction(kind: .warning, message: "Abgeschlossen mit \(failures.count) Fehlern."))
        }
        appState = .finished
    }

    func reset() {
        detectedFiles = []
        logEntries = []
        summary = .empty
        appState = .ready
    }

    func count(for category: Category) -> Int {
        detectedFiles.filter { $0.category == category }.count
    }

    private func summary(for items: [FileItem]) -> SortSummary {
        SortSummary(
            totalFiles: items.count,
            movedFiles: items.filter { $0.status == .moved || $0.status == .planned }.count,
            skippedFiles: items.filter { $0.status == .skipped }.count,
            failedFiles: items.filter { $0.status == .failed }.count
        )
    }
}

struct MainWindowView: View {
    @Bindable var viewModel: MainViewModel

    var body: some View {
        ZStack {
            Color(nsColor: .underPageBackgroundColor).ignoresSafeArea()

            VStack(spacing: 18) {
                header

                HStack(alignment: .top, spacing: 18) {
                    leftColumn
                    rightColumn
                }
                .frame(maxHeight: .infinity, alignment: .top)

                footer
            }
            .padding(22)
        }
        .frame(minWidth: 940, minHeight: 660)
    }

    private var header: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("SmartFileSorter")
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                Text("Ordner analysieren, Kategorien prüfen und Dateien kontrolliert sortieren.")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            metricPill("Dateien", value: viewModel.summary.totalFiles, icon: "doc")
            metricPill(viewModel.settings.dryRun ? "Geplant" : "Verschoben", value: viewModel.summary.movedFiles, icon: "arrow.right.circle")
            statusBadge
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay { RoundedRectangle(cornerRadius: 8).stroke(.quaternary, lineWidth: 1) }
    }

    private var leftColumn: some View {
        ScrollView {
            VStack(spacing: 16) {
                card("Ordner", icon: "folder") {
                    Text(viewModel.selectedFolderPath)
                        .font(.callout)
                        .lineLimit(2)
                        .truncationMode(.middle)
                    Button { viewModel.pickFolder() } label: {
                        Label("Ordner auswählen", systemImage: "folder.badge.plus")
                    }
                }

                card("Einstellungen", icon: "slider.horizontal.3") {
                    Toggle("Dry Run", isOn: $viewModel.settings.dryRun)
                    Toggle("Versteckte Dateien ignorieren", isOn: $viewModel.settings.ignoreHiddenFiles)
                    Toggle("Unterordner ignorieren", isOn: $viewModel.settings.ignoreSubfolders)
                    Toggle("Konflikte automatisch lösen", isOn: $viewModel.settings.resolveConflictsAutomatically)
                    Toggle("Unbekanntes zu Sonstiges", isOn: $viewModel.settings.sortUnknownToOthers)
                    Toggle("Zielordner erstellen", isOn: $viewModel.settings.createMissingFolders)
                }

                card("Kategorien", icon: "square.grid.2x2") {
                    ForEach(Category.all) { category in
                        HStack {
                            Label(category.name, systemImage: category.systemImage)
                            Spacer()
                            Text("\(viewModel.count(for: category))")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
        .frame(minWidth: 320, idealWidth: 360, maxWidth: 400)
    }

    private var rightColumn: some View {
        VStack(spacing: 16) {
            filePreviewCard

            HStack(alignment: .top, spacing: 16) {
                activityLogCard
                    .frame(maxWidth: .infinity)
                summaryCard
                    .frame(width: 260)
            }
        }
    }

    private var filePreviewCard: some View {
        card("Dateivorschau", icon: "tablecells") {
            if viewModel.detectedFiles.isEmpty {
                ContentUnavailableView("Noch keine Vorschau", systemImage: "doc.text.magnifyingglass", description: Text("Starte die Analyse, um Dateien und Zielordner zu prüfen."))
                    .frame(maxWidth: .infinity, minHeight: 220)
            } else {
                VStack(spacing: 0) {
                    HStack {
                        Text("Datei").frame(maxWidth: .infinity, alignment: .leading)
                        Text("Kategorie").frame(width: 130, alignment: .leading)
                        Text("Ziel").frame(width: 150, alignment: .leading)
                        Text("Status").frame(width: 95, alignment: .leading)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)

                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(viewModel.detectedFiles) { item in
                                filePreviewRow(item)
                            }
                        }
                    }
                    .frame(minHeight: 230, maxHeight: 290)
                }
            }
        }
    }

    private var activityLogCard: some View {
        card("Aktivitätslog", icon: "list.bullet.rectangle") {
            if viewModel.logEntries.isEmpty {
                ContentUnavailableView("Noch keine Aktivität", systemImage: "text.alignleft", description: Text("Wähle einen Ordner und starte die Analyse."))
                    .frame(maxWidth: .infinity, minHeight: 210)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(viewModel.logEntries) { entry in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: icon(for: entry.kind))
                                    .foregroundStyle(color(for: entry.kind))
                                    .frame(width: 24, height: 24)
                                    .background(color(for: entry.kind).opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.message)
                                        .lineLimit(2)
                                    Text(entry.date, style: .time)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .padding(10)
                            .background(.background.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .frame(minHeight: 210)
            }
        }
    }

    private var summaryCard: some View {
        card("Zusammenfassung", icon: "chart.bar") {
            VStack(spacing: 10) {
                summaryTile("Dateien", value: viewModel.summary.totalFiles, color: .secondary)
                summaryTile(viewModel.settings.dryRun ? "Geplant" : "Verschoben", value: viewModel.summary.movedFiles, color: .green)
                summaryTile("Ignoriert", value: viewModel.summary.skippedFiles, color: .orange)
                summaryTile("Fehler", value: viewModel.summary.failedFiles, color: .red)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Toggle("Logs anzeigen", isOn: $viewModel.settings.showLogs).toggleStyle(.checkbox)
            Spacer()
            Button { viewModel.reset() } label: { Label("Reset", systemImage: "arrow.counterclockwise") }
                .controlSize(.large)
                .disabled(viewModel.isRunning)
            Button { Task { await viewModel.analyzeSelectedFolder() } } label: { Label("Analyse starten", systemImage: "magnifyingglass") }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!viewModel.canAnalyze)
            Button { Task { await viewModel.sortSelectedFolder() } } label: { Label(viewModel.settings.dryRun ? "Dry Run starten" : "Sortierung starten", systemImage: "arrow.triangle.2.circlepath") }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!viewModel.canSort)
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay { RoundedRectangle(cornerRadius: 8).stroke(.quaternary, lineWidth: 1) }
    }

    private var statusBadge: some View {
        Text(viewModel.appState.rawValue)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.tint.opacity(0.14), in: Capsule())
    }

    private func card<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.tint)
                    .frame(width: 26, height: 26)
                    .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                Text(title).font(.headline)
                Spacer(minLength: 0)
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay { RoundedRectangle(cornerRadius: 8).stroke(.quaternary, lineWidth: 1) }
        .shadow(color: .black.opacity(0.06), radius: 12, y: 5)
    }

    private func filePreviewRow(_ item: FileItem) -> some View {
        HStack(spacing: 12) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.originalName)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if let errorMessage = item.errorMessage {
                        Text(errorMessage)
                            .font(.caption2)
                            .foregroundStyle(.red)
                            .lineLimit(1)
                    }
                }
            } icon: {
                Image(systemName: fileIcon(for: item))
                    .foregroundStyle(.tint)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            categoryBadge(item.category)
                .frame(width: 130, alignment: .leading)

            Text(destinationText(for: item))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: 150, alignment: .leading)

            Text(item.status.rawValue)
                .font(.caption.weight(.semibold))
                .foregroundStyle(statusColor(for: item.status))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(statusColor(for: item.status).opacity(0.12), in: Capsule())
                .frame(width: 95, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.background.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
        .overlay { RoundedRectangle(cornerRadius: 8).stroke(.quaternary, lineWidth: 1) }
    }

    private func categoryBadge(_ category: Category) -> some View {
        Label(category.name, systemImage: category.systemImage)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.tint.opacity(0.1), in: Capsule())
    }

    private func metricPill(_ title: String, value: Int, icon: String) -> some View {
        Label("\(title) \(value)", systemImage: icon)
            .font(.caption)
            .monospacedDigit()
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.background.opacity(0.55), in: Capsule())
            .overlay { Capsule().stroke(.quaternary, lineWidth: 1) }
    }

    private func summaryTile(_ title: String, value: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(value)").font(.title2.weight(.semibold)).monospacedDigit()
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(color.opacity(0.09), in: RoundedRectangle(cornerRadius: 8))
        .overlay { RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.16), lineWidth: 1) }
    }

    private func destinationText(for item: FileItem) -> String {
        item.destinationURL?.lastPathComponent ?? item.category.folderName
    }

    private func fileIcon(for item: FileItem) -> String {
        switch item.category.id {
        case Category.images.id: "photo"
        case Category.documents.id: "doc.text"
        case Category.archives.id: "archivebox"
        case Category.audio.id: "waveform"
        case Category.videos.id: "film"
        case Category.apps.id: "app"
        default: "doc"
        }
    }

    private func statusColor(for status: FileStatus) -> Color {
        switch status {
        case .detected: .blue
        case .planned: .teal
        case .moved: .green
        case .skipped: .orange
        case .failed: .red
        }
    }

    private func icon(for kind: SortActionKind) -> String {
        switch kind {
        case .info: "info.circle"
        case .success: "checkmark.circle"
        case .warning: "exclamationmark.triangle"
        case .error: "xmark.octagon"
        }
    }

    private func color(for kind: SortActionKind) -> Color {
        switch kind {
        case .info: .secondary
        case .success: .green
        case .warning: .orange
        case .error: .red
        }
    }
}
