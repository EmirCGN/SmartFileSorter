import SwiftUI

struct MainWindowSidebarView: View {
    let selectedFolderPath: String
    let selectedDestinationPath: String
    let hasSelectedFolder: Bool
    let isRunning: Bool
    let detectedFileCount: Int
    let movedCount: Int
    let progress: SortProgress

    @Binding var settings: AppSettings
    @Binding var showsAdvancedOptions: Bool

    let pickFolder: () -> Void
    let pickDestinationFolder: () -> Void
    let clearDestinationFolder: () -> Void
    let countForCategory: (Category) -> Int

    var body: some View {
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
        InfoCard(title: "Ablauf", systemImage: "checklist") {
            VStack(alignment: .leading, spacing: 10) {
                workflowStep("1", title: "Ordner", isActive: hasSelectedFolder)
                workflowStep("2", title: "Analyse", isActive: detectedFileCount > 0, showsLoading: isRunning && detectedFileCount == 0)
                workflowStep("3", title: settings.dryRun ? "Plan" : "Sortierung", isActive: movedCount > 0, showsLoading: isRunning && detectedFileCount > 0)
                if isRunning {
                    VStack(alignment: .leading, spacing: 6) {
                        ProgressView(value: progress.fractionCompleted)
                        if !progress.currentFileName.isEmpty {
                            Text(progress.currentFileName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                    .padding(.top, 4)
                    .transition(.opacity)
                }
            }
        }
    }

    private var folderCard: some View {
        InfoCard(title: "Ordner", systemImage: "folder") {
            VStack(alignment: .leading, spacing: 12) {
                Text(selectedFolderPath)
                    .font(.callout)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .foregroundStyle(hasSelectedFolder ? .primary : .secondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.background.opacity(0.52), in: RoundedRectangle(cornerRadius: 8))

                Button(action: pickFolder) {
                    Label("Ordner auswählen", systemImage: "folder.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)

                VStack(alignment: .leading, spacing: 8) {
                    Text(selectedDestinationPath)
                        .font(.caption)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .foregroundStyle(.secondary)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.background.opacity(0.52), in: RoundedRectangle(cornerRadius: 8))

                    HStack(spacing: 8) {
                        Button(action: pickDestinationFolder) {
                            Label("Zielordner", systemImage: "folder.badge.gearshape")
                                .frame(maxWidth: .infinity)
                        }
                        .controlSize(.regular)

                        Button(action: clearDestinationFolder) {
                            Label("Reset", systemImage: "arrow.uturn.backward")
                                .frame(maxWidth: .infinity)
                        }
                        .controlSize(.regular)
                    }
                }
            }
        }
    }

    private var settingsCard: some View {
        InfoCard(title: "Optionen", systemImage: "slider.horizontal.3") {
            VStack(spacing: 8) {
                settingRow("Dry Run", subtitle: "Nur planen, nichts verschieben", isOn: $settings.dryRun)
                settingRow("Konflikte lösen", subtitle: "Dateinamen automatisch durchnummerieren", isOn: $settings.resolveConflictsAutomatically)

                DisclosureGroup("Weitere Optionen", isExpanded: $showsAdvancedOptions) {
                    VStack(spacing: 8) {
                        settingRow("Versteckte Dateien ignorieren", subtitle: ".DS_Store und Punktdateien auslassen", isOn: $settings.ignoreHiddenFiles)
                        settingRow("Unterordner ignorieren", subtitle: "Nur die erste Ebene scannen", isOn: $settings.ignoreSubfolders)
                        settingRow("Unbekanntes einsortieren", subtitle: "Nicht erkannte Dateien zu Sonstiges", isOn: $settings.sortUnknownToOthers)
                        settingRow("Zielordner erstellen", subtitle: "Fehlende Kategorieordner anlegen", isOn: $settings.createMissingFolders)
                    }
                    .padding(.top, 8)
                }
                .font(.callout.weight(.medium))
            }
        }
    }

    private var categoriesCard: some View {
        InfoCard(title: "Kategorien", systemImage: "square.grid.2x2") {
            VStack(spacing: 8) {
                ForEach(Category.all) { category in
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
                        Text("\(countForCategory(category))")
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(.background.opacity(0.55), in: Capsule())
                    }
                    .padding(10)
                    .background(.background.opacity(0.38), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    private func workflowStep(_ number: String, title: String, isActive: Bool, showsLoading: Bool = false) -> some View {
        HStack(spacing: 10) {
            Text(number)
                .font(.caption.weight(.bold))
                .foregroundStyle(isActive ? .white : .secondary)
                .frame(width: 24, height: 24)
                .background(isActive ? Color.accentColor : Color.secondary.opacity(0.12), in: Circle())
            Text(title)
                .font(.callout.weight(.medium))
            Spacer()
            if showsLoading {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isActive ? .green : .secondary.opacity(0.45))
            }
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
}
