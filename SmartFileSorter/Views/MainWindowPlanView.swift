import SwiftUI

struct MainWindowPlanView: View {
    let detectedFiles: [FileItem]
    let filteredItems: [FileItem]
    let dryRun: Bool

    @Binding var searchText: String
    @Binding var categoryFilter: String
    @Binding var statusFilter: String
    @Binding var sortMode: String

    let setIncluded: (Bool, FileItem) -> Void

    @State private var hoveredItemID: UUID?

    var body: some View {
        InfoCard(title: "Sortierplan", systemImage: "tablecells") {
            if detectedFiles.isEmpty {
                ContentUnavailableView("Noch kein Plan", systemImage: "doc.text.magnifyingglass", description: Text("Starte die Analyse, um Dateien und Zielordner zu prüfen."))
                    .frame(maxWidth: .infinity, minHeight: 170)
            } else {
                VStack(spacing: 0) {
                    planToolbar

                    HStack {
                        Text("\(detectedFiles.count) Dateien erkannt")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(dryRun ? "Vorschau aktiv" : "Bereit zum Verschieben")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(dryRun ? .teal : .orange)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background((dryRun ? Color.teal : Color.orange).opacity(0.12), in: Capsule())
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

    private func filePreviewRow(_ item: FileItem) -> some View {
        HStack(spacing: 12) {
            Toggle("", isOn: includedBinding(for: item))
                .labelsHidden()
                .toggleStyle(.checkbox)

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
                    } else if item.category == .other {
                        Text("Review empfohlen")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
            } icon: {
                Image(systemName: fileIcon(for: item))
                    .foregroundStyle(item.isIncluded ? Color.accentColor : Color.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Label(item.category.name, systemImage: item.category.systemImage)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(.tint.opacity(0.1), in: Capsule())
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

    private func includedBinding(for item: FileItem) -> Binding<Bool> {
        Binding(
            get: { item.isIncluded },
            set: { setIncluded($0, item) }
        )
    }

    private func destinationText(for item: FileItem) -> String {
        let fileName = item.destinationURL?.lastPathComponent ?? item.originalName
        return "\(item.category.folderName)/\(fileName)"
    }

    private func rowBackground(for item: FileItem) -> Color {
        if hoveredItemID == item.id {
            return Color.accentColor.opacity(0.10)
        }
        if !item.isIncluded {
            return Color.secondary.opacity(0.08)
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
}
