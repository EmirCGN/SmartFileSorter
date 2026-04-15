import SwiftUI

struct SummaryView: View {
    @Bindable var viewModel: MainViewModel

    var body: some View {
        InfoCard(title: "Zusammenfassung", systemImage: "chart.bar") {
            CompactSummaryStrip(summary: viewModel.summary, dryRun: viewModel.settings.dryRun)
        }
    }
}

struct CompactSummaryStrip: View {
    let summary: SortSummary
    let dryRun: Bool

    var body: some View {
        HStack(spacing: 10) {
            summaryTile("Dateien", value: summary.totalFiles, color: .secondary)
            summaryTile(dryRun ? "Geplant" : "Verschoben", value: summary.movedFiles, color: .green)
            summaryTile("Ignoriert", value: summary.skippedFiles, color: .orange)
            summaryTile("Fehler", value: summary.failedFiles, color: .red)
        }
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
}
