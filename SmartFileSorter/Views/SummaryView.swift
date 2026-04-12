import SwiftUI

struct SummaryView: View {
    @Bindable var viewModel: MainViewModel

    var body: some View {
        InfoCard(title: "Zusammenfassung", systemImage: "chart.bar") {
            HStack(spacing: 10) {
                summaryTile("Dateien", value: viewModel.summary.totalFiles, icon: "doc", color: .secondary)
                summaryTile(viewModel.settings.dryRun ? "Geplant" : "Verschoben", value: viewModel.summary.movedFiles, icon: "arrow.right.circle", color: .green)
                summaryTile("Ignoriert", value: viewModel.summary.skippedFiles, icon: "forward", color: .orange)
                summaryTile("Fehler", value: viewModel.summary.failedFiles, icon: "exclamationmark.octagon", color: .red)
            }
        }
    }

    private func summaryTile(_ title: String, value: Int, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text("\(value)")
                .font(.title2.weight(.semibold))
                .monospacedDigit()
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(color.opacity(0.16), lineWidth: 1)
        }
    }
}
