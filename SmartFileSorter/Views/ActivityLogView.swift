import SwiftUI

struct ActivityLogView: View {
    @Bindable var viewModel: MainViewModel

    var body: some View {
        InfoCard(title: "Aktivitätslog", systemImage: "list.bullet.rectangle") {
            ActivityDetailsView(logEntries: viewModel.logEntries, isExpanded: .constant(true))
        }
    }
}

struct ActivityDetailsView: View {
    let logEntries: [SortAction]
    @Binding var isExpanded: Bool

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            if logEntries.isEmpty {
                Text("Noch keine Aktivität.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 70, alignment: .center)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(logEntries) { entry in
                            logRow(entry)
                        }
                    }
                }
                .frame(minHeight: 80, maxHeight: 130)
            }
        } label: {
            HStack {
                Label(logEntries.isEmpty ? "Details" : "Details (\(logEntries.count))", systemImage: "list.bullet.rectangle")
                Spacer()
                if let latest = logEntries.last {
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

    private func logRow(_ entry: SortAction) -> some View {
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
