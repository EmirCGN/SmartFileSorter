import SwiftUI

struct MainWindowHeaderView: View {
    let focusMessage: String
    let summary: SortSummary
    let dryRun: Bool
    let appState: AppState

    var body: some View {
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
                        .foregroundStyle(summary.failedFiles > 0 ? .red : .secondary)
                }
            }

            Spacer()

            metricPill(title: "Dateien", value: summary.totalFiles, icon: "doc")
            metricPill(title: dryRun ? "Geplant" : "Verschoben", value: summary.movedFiles, icon: "arrow.right.circle")
            StatusBadge(state: appState)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay { RoundedRectangle(cornerRadius: 8).stroke(.quaternary, lineWidth: 1) }
        .shadow(color: .black.opacity(0.06), radius: 14, y: 6)
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
}
