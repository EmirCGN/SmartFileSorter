import SwiftUI

struct MainWindowView: View {
    @Bindable var viewModel: MainViewModel
    @State private var searchText = ""
    @State private var categoryFilter = "all"
    @State private var statusFilter = "all"
    @State private var sortMode = "name"
    @State private var showsAdvancedOptions = false
    @State private var showsActivityDetails = false
    @State private var hoveredItemID: UUID?

    var body: some View {
        ZStack {
            background

            VStack(spacing: 16) {
                header

                HStack(alignment: .top, spacing: 16) {
                    leftColumn
                    rightColumn
                }
                .frame(maxHeight: .infinity, alignment: .top)
                .layoutPriority(1)

                footer
            }
            .padding(20)
        }
        .frame(minWidth: 980, minHeight: 560)
        .sheet(isPresented: sortConfirmationBinding) {
            SafeSortConfirmationView(viewModel: viewModel)
        }
        .animation(.snappy(duration: 0.22), value: viewModel.appState)
        .animation(.snappy(duration: 0.22), value: viewModel.detectedFiles.count)
        .animation(.snappy(duration: 0.22), value: showsActivityDetails)
    }

    private var sortConfirmationBinding: Binding<Bool> {
        Binding(
            get: { _viewModel.wrappedValue.isShowingSortConfirmation },
            set: { _viewModel.wrappedValue.isShowingSortConfirmation = $0 }
        )
    }

    private var filteredItems: [FileItem] {
        let searchedItems = viewModel.detectedFiles.filter { item in
            let matchesSearch = searchText.isEmpty
                || item.originalName.localizedCaseInsensitiveContains(searchText)
                || item.category.name.localizedCaseInsensitiveContains(searchText)
                || destinationText(for: item).localizedCaseInsensitiveContains(searchText)
            let matchesCategory = categoryFilter == "all" || item.category.id == categoryFilter
            let matchesStatus = statusFilter == "all" || item.status.rawValue == statusFilter
            return matchesSearch && matchesCategory && matchesStatus
        }

        return searchedItems.sorted { lhs, rhs in
            switch sortMode {
            case "category":
                if lhs.category.name == rhs.category.name {
                    return lhs.originalName.localizedStandardCompare(rhs.originalName) == .orderedAscending
                }
                return lhs.category.name.localizedStandardCompare(rhs.category.name) == .orderedAscending
            case "status":
                if lhs.status.rawValue == rhs.status.rawValue {
                    return lhs.originalName.localizedStandardCompare(rhs.originalName) == .orderedAscending
                }
                return lhs.status.rawValue.localizedStandardCompare(rhs.status.rawValue) == .orderedAscending
            default:
                return lhs.originalName.localizedStandardCompare(rhs.originalName) == .orderedAscending
            }
        }
    }

    private var focusMessage: String {
        if viewModel.selectedFolderURL == nil {
            return "Bereit für Analyse"
        }
        if viewModel.isRunning {
            return viewModel.appState == .analyzing ? "Analyse läuft" : "Sortierung läuft"
        }
        if viewModel.detectedFiles.isEmpty {
            return "Ordner gewählt"
        }
        if viewModel.summary.failedFiles > 0 {
            return "Fehler prüfen"
        }
        if viewModel.summary.movedFiles > 0 {
            return viewModel.settings.dryRun ? "Plan prüfen" : "Ergebnis prüfen"
        }
        return "\(viewModel.detectedFiles.count) Dateien erkannt"
    }

    private var primaryActionTitle: String {
        viewModel.detectedFiles.isEmpty ? "Analyse starten" : (viewModel.settings.dryRun ? "Plan erstellen" : "Sortierung starten")
    }

    private var primaryActionIcon: String {
        viewModel.detectedFiles.isEmpty ? "magnifyingglass" : (viewModel.settings.dryRun ? "checklist" : "arrow.triangle.2.circlepath")
    }

    private var background: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color(nsColor: .controlBackgroundColor).opacity(0.72)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 18) {
            HStack(spacing: 14) {
                Image(systemName: "folder.badge.gearshape")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(.tint, in: RoundedRectangle(cornerRadius: 8))
                    .shadow(color: .black.opacity(0.16), radius: 10, y: 4)

                VStack(alignment: .leading, spacing: 5) {
                    Text("SmartFileSorter")
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    Text(focusMessage)
                        .font(.callout)
                        .foregroundStyle(viewModel.summary.failedFiles > 0 ? .red : .secondary)
                }
            }

            Spacer()

            metricPill(title: "Dateien", value: viewModel.summary.totalFiles, icon: "doc")
            metricPill(title: viewModel.settings.dryRun ? "Geplant" : "Verschoben", value: viewModel.summary.movedFiles, icon: "arrow.right.circle")
            StatusBadge(state: viewModel.appState)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay { RoundedRectangle(cornerRadius: 8).stroke(.quaternary, lineWidth: 1) }
        .shadow(color: .black.opacity(0.06), radius: 14, y: 6)
    }

    private var leftColumn: some View {
        ScrollView {
            VStack(spacing: 14) {
                workflowStrip
                folderCard
                settingsCard
                categoriesCard
            }
            .padding(.bottom, 4)
        }
        .scrollIndicators(.hidden)
        .frame(minWidth: 300, idealWidth: 340, maxWidth: 370)
        .frame(maxHeight: .infinity)
    }

    private var workflowStrip: some View {
        card("Ablauf", icon: "checklist") {
            VStack(alignment: .leading, spacing: 10) {
                workflowStep("1", title: "Ordner", isActive: viewModel.selectedFolderURL != nil)
                workflowStep("2", title: "Analyse", isActive: !viewModel.detectedFiles.isEmpty)
                workflowStep("3", title: viewModel.settings.dryRun ? "Plan" : "Sortierung", isActive: viewModel.summary.movedFiles > 0)
                if viewModel.isRunning {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.top, 4)
                        .transition(.opacity)
                }
            }
        }
    }

    private var folderCard: some View {
        card("Ordner", icon: "folder") {
            VStack(alignment: .leading, spacing: 12) {
                Text(viewModel.selectedFolderPath)
                    .font(.callout)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .foregroundStyle(viewModel.selectedFolderURL == nil ? .secondary : .primary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.background.opacity(0.52), in: RoundedRectangle(cornerRadius: 8))

                Button { viewModel.pickFolder() } label: {
                    Label("Ordner auswählen", systemImage: "folder.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
            }
        }
    }

    private var settingsCard: some View {
        quietGroup("Optionen", icon: "slider.horizontal.3") {
            VStack(spacing: 8) {
                settingRow("Dry Run", subtitle: "Nur planen, nichts verschieben", isOn: $viewModel.settings.dryRun)
                settingRow("Konflikte lösen", subtitle: "Dateinamen automatisch durchnummerieren", isOn: $viewModel.settings.resolveConflictsAutomatically)

                DisclosureGroup("Weitere Optionen", isExpanded: $showsAdvancedOptions) {
                    VStack(spacing: 8) {
                        settingRow("Versteckte Dateien ignorieren", subtitle: ".DS_Store und Punktdateien auslassen", isOn: $viewModel.settings.ignoreHiddenFiles)
                        settingRow("Unterordner ignorieren", subtitle: "Nur die erste Ebene scannen", isOn: $viewModel.settings.ignoreSubfolders)
                        settingRow("Unbekanntes einsortieren", subtitle: "Nicht erkannte Dateien zu Sonstiges", isOn: $viewModel.settings.sortUnknownToOthers)
                        settingRow("Zielordner erstellen", subtitle: "Fehlende Kategorieordner anlegen", isOn: $viewModel.settings.createMissingFolders)
                    }
                    .padding(.top, 8)
                }
                .font(.callout.weight(.medium))
            }
        }
    }

    private var categoriesCard: some View {
        quietGroup("Kategorien", icon: "square.grid.2x2") {
            VStack(spacing: 8) {
                ForEach(Category.all) { category in
                    categoryRow(category)
                }
            }
        }
    }

    private var rightColumn: some View {
        VStack(spacing: 10) {
            filePreviewCard
                .layoutPriority(1)
            compactStatusStrip
            activityDetails
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var filePreviewCard: some View {
        card("Sortierplan", icon: "tablecells") {
            if viewModel.detectedFiles.isEmpty {
                ContentUnavailableView("Noch kein Plan", systemImage: "doc.text.magnifyingglass", description: Text("Starte die Analyse, um Dateien und Zielordner zu prüfen."))
                    .frame(maxWidth: .infinity, minHeight: 170)
            } else {
                VStack(spacing: 0) {
                    planToolbar

                    HStack {
                        Text("\(viewModel.detectedFiles.count) Dateien erkannt")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(viewModel.settings.dryRun ? "Vorschau aktiv" : "Bereit zum Verschieben")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(viewModel.settings.dryRun ? .teal : .orange)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background((viewModel.settings.dryRun ? Color.teal : Color.orange).opacity(0.12), in: Capsule())
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)

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

                    if filteredItems.isEmpty {
                        ContentUnavailableView("Keine Treffer", systemImage: "line.3.horizontal.decrease.circle", description: Text("Passe Suche oder Filter an."))
                            .frame(maxWidth: .infinity, minHeight: 170)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(filteredItems) { item in
                                    filePreviewRow(item)
                                }
                            }
                        }
                        .frame(minHeight: 120, idealHeight: 220, maxHeight: 260)
                    }
                }
            }
        }
    }

    private var planToolbar: some View {
        HStack(spacing: 10) {
            Label("Plan prüfen", systemImage: "checkmark.shield")
                .font(.callout.weight(.semibold))

            Spacer()

            TextField("Suchen", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 190)

            Picker("Kategorie", selection: $categoryFilter) {
                Text("Alle").tag("all")
                ForEach(Category.all) { category in
                    Text(category.name).tag(category.id)
                }
            }
            .labelsHidden()
            .frame(width: 150)

            Picker("Status", selection: $statusFilter) {
                Text("Alle Status").tag("all")
                Text(FileStatus.detected.rawValue).tag(FileStatus.detected.rawValue)
                Text(FileStatus.planned.rawValue).tag(FileStatus.planned.rawValue)
                Text(FileStatus.moved.rawValue).tag(FileStatus.moved.rawValue)
                Text(FileStatus.skipped.rawValue).tag(FileStatus.skipped.rawValue)
                Text(FileStatus.failed.rawValue).tag(FileStatus.failed.rawValue)
            }
            .labelsHidden()
            .frame(width: 130)

            Picker("Sortierung", selection: $sortMode) {
                Text("Name").tag("name")
                Text("Kategorie").tag("category")
                Text("Status").tag("status")
            }
            .labelsHidden()
            .frame(width: 120)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }

    private var compactStatusStrip: some View {
        HStack(spacing: 10) {
            summaryTile("Dateien", value: viewModel.summary.totalFiles, color: .secondary)
            summaryTile(viewModel.settings.dryRun ? "Geplant" : "Verschoben", value: viewModel.summary.movedFiles, color: .green)
            summaryTile("Ignoriert", value: viewModel.summary.skippedFiles, color: .orange)
            summaryTile("Fehler", value: viewModel.summary.failedFiles, color: .red)
        }
    }

    private var activityDetails: some View {
        DisclosureGroup(isExpanded: $showsActivityDetails) {
            if viewModel.logEntries.isEmpty {
                Text("Noch keine Aktivität.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 70, alignment: .center)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
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
                            .background(.background.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .frame(minHeight: 80, maxHeight: 130)
            }
        } label: {
            HStack {
                Label(viewModel.logEntries.isEmpty ? "Details" : "Details (\(viewModel.logEntries.count))", systemImage: "list.bullet.rectangle")
                Spacer()
                if let latest = viewModel.logEntries.last {
                    Text(latest.kind.rawValue)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(color(for: latest.kind))
                }
            }
            .font(.callout.weight(.medium))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Toggle("Logs anzeigen", isOn: $viewModel.settings.showLogs)
                .toggleStyle(.checkbox)

            Spacer()

            Button { viewModel.reset() } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
            }
            .controlSize(.large)
            .disabled(viewModel.isRunning)

            Button {
                Task {
                    if viewModel.detectedFiles.isEmpty {
                        await viewModel.analyzeSelectedFolder()
                    } else {
                        await viewModel.sortSelectedFolder()
                    }
                }
            } label: {
                Label(primaryActionTitle, systemImage: primaryActionIcon)
                    .font(.callout.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.detectedFiles.isEmpty ? !viewModel.canAnalyze : !viewModel.canSort)
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay { RoundedRectangle(cornerRadius: 8).stroke(.quaternary, lineWidth: 1) }
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

    private func quietGroup<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(.secondary)
            content()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func workflowStep(_ number: String, title: String, isActive: Bool) -> some View {
        HStack(spacing: 10) {
            Text(number)
                .font(.caption.weight(.bold))
                .foregroundStyle(isActive ? .white : .secondary)
                .frame(width: 24, height: 24)
                .background(isActive ? Color.accentColor : Color.secondary.opacity(0.12), in: Circle())
            Text(title)
                .font(.callout.weight(.medium))
            Spacer()
            Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isActive ? .green : .secondary.opacity(0.45))
        }
    }

    private func settingRow(_ title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(.background.opacity(0.42), in: RoundedRectangle(cornerRadius: 8))
    }

    private func categoryRow(_ category: Category) -> some View {
        HStack(spacing: 10) {
            Image(systemName: category.systemImage)
                .foregroundStyle(.tint)
                .frame(width: 24, height: 24)
                .background(.tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 2) {
                Text(category.name)
                    .font(.callout.weight(.medium))
                Text(category.folderName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(viewModel.count(for: category))")
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(.background.opacity(0.55), in: Capsule())
        }
        .padding(10)
        .background(.background.opacity(0.38), in: RoundedRectangle(cornerRadius: 8))
    }

    private func filePreviewRow(_ item: FileItem) -> some View {
        HStack(spacing: 12) {
            Label {
                Text(item.originalName)
                    .lineLimit(1)
                    .truncationMode(.middle)
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
        .background(rowBackground(for: item), in: RoundedRectangle(cornerRadius: 8))
        .overlay { RoundedRectangle(cornerRadius: 8).stroke(.quaternary, lineWidth: 1) }
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .onHover { isHovering in
            hoveredItemID = isHovering ? item.id : nil
        }
    }

    private func categoryBadge(_ category: Category) -> some View {
        Label(category.name, systemImage: category.systemImage)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.tint.opacity(0.1), in: Capsule())
    }

    private func metricPill(title: String, value: Int, icon: String) -> some View {
        Label {
            HStack(spacing: 5) {
                Text(title)
                    .foregroundStyle(.secondary)
                Text("\(value)")
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(.tint)
        }
        .font(.caption)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.background.opacity(0.55), in: Capsule())
        .overlay { Capsule().stroke(.quaternary, lineWidth: 1) }
    }

    private func summaryTile(_ title: String, value: Int, color: Color) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color.opacity(0.75))
                .frame(width: 7, height: 7)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 4)
            Text("\(value)")
                .font(.callout.weight(.semibold))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
        .padding(.horizontal, 10)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        .overlay { RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.14), lineWidth: 1) }
    }

    private func destinationText(for item: FileItem) -> String {
        let fileName = item.destinationURL?.lastPathComponent ?? item.originalName
        return "\(item.category.folderName)/\(fileName)"
    }

    private func rowBackground(for item: FileItem) -> Color {
        if hoveredItemID == item.id {
            return Color.accentColor.opacity(0.10)
        }
        if item.status == .failed {
            return Color.red.opacity(0.08)
        }
        if item.category == .other {
            return Color.orange.opacity(0.08)
        }
        return Color(nsColor: .textBackgroundColor).opacity(0.55)
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
