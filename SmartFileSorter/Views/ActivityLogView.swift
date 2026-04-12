import SwiftUI

struct ActivityLogView: View {
    @Bindable var viewModel: MainViewModel

    var body: some View {
        InfoCard(title: "Aktivitätslog", systemImage: "list.bullet.rectangle") {
            if !viewModel.settings.showLogs {
                Text("Logs sind ausgeblendet.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else if viewModel.logEntries.isEmpty {
                ContentUnavailableView("Noch keine Aktivität", systemImage: "text.alignleft", description: Text("Wähle einen Ordner und starte die Analyse."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 10) {
                            ForEach(viewModel.logEntries) { entry in
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: icon(for: entry.kind))
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(color(for: entry.kind))
                                        .frame(width: 24, height: 24)
                                        .background(color(for: entry.kind).opacity(0.12), in: RoundedRectangle(cornerRadius: 6))

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(entry.message)
                                            .lineLimit(2)
                                        Text(entry.date, style: .time)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer(minLength: 0)
                                }
                                .font(.callout)
                                .padding(10)
                                .background(.background.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(.quaternary, lineWidth: 1)
                                }
                                .id(entry.id)
                            }
                        }
                    }
                    .onChange(of: viewModel.logEntries.count) { _, _ in
                        if let lastID = viewModel.logEntries.last?.id {
                            proxy.scrollTo(lastID, anchor: .bottom)
                        }
                    }
                }
            }
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
