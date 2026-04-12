import SwiftUI

struct MainWindowView: View {
    @Bindable var viewModel: MainViewModel

    var body: some View {
        ZStack {
            Color(nsColor: .underPageBackgroundColor)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                header

                HStack(alignment: .top, spacing: 18) {
                    ScrollView {
                        VStack(spacing: 16) {
                            FolderSelectionView(viewModel: viewModel)
                            SettingsPanelView(viewModel: viewModel)
                            CategoryOverviewView(viewModel: viewModel)
                        }
                        .padding(.trailing, 2)
                    }
                    .scrollIndicators(.hidden)
                    .frame(minWidth: 320, idealWidth: 360, maxWidth: 400)

                    VStack(spacing: 16) {
                        ActivityLogView(viewModel: viewModel)
                            .frame(minHeight: 380)
                        SummaryView(viewModel: viewModel)
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)

                footer
            }
            .padding(22)
        }
        .frame(minWidth: 940, minHeight: 660)
        .sheet(isPresented: $viewModel.isShowingSortConfirmation) {
            SafeSortConfirmationView(viewModel: viewModel)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("SmartFileSorter")
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                Text("Ordner analysieren, Kategorien prüfen und Dateien kontrolliert sortieren.")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 10) {
                metricPill(title: "Dateien", value: viewModel.summary.totalFiles, icon: "doc")
                metricPill(title: viewModel.settings.dryRun ? "Geplant" : "Verschoben", value: viewModel.summary.movedFiles, icon: "arrow.right.circle")
                StatusBadge(state: viewModel.appState)
            }
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.quaternary, lineWidth: 1)
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Toggle("Logs anzeigen", isOn: $viewModel.settings.showLogs)
                .toggleStyle(.checkbox)

            Spacer()

            Button {
                viewModel.reset()
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
            }
            .controlSize(.large)
            .disabled(viewModel.isRunning)

            PrimaryButton(title: "Analyse starten", systemImage: "magnifyingglass", isDisabled: !viewModel.canAnalyze) {
                Task { await viewModel.analyzeSelectedFolder() }
            }

            PrimaryButton(title: viewModel.settings.dryRun ? "Plan erstellen" : "Direkt sortieren", systemImage: viewModel.settings.dryRun ? "checklist" : "arrow.triangle.2.circlepath", isDisabled: !viewModel.canSort) {
                Task { await viewModel.sortSelectedFolder() }
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.quaternary, lineWidth: 1)
        }
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
        .overlay {
            Capsule().stroke(.quaternary, lineWidth: 1)
        }
    }
}
