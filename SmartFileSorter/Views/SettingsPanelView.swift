import SwiftUI

struct SettingsPanelView: View {
    @Bindable var viewModel: MainViewModel

    var body: some View {
        InfoCard(title: "Einstellungen", systemImage: "slider.horizontal.3") {
            VStack(alignment: .leading, spacing: 10) {
                SettingRow(title: "Dry Run", subtitle: "Nur planen, nichts verschieben", isOn: $viewModel.settings.dryRun)
                SettingRow(title: "Versteckte Dateien ignorieren", subtitle: ".DS_Store und Punktdateien auslassen", isOn: $viewModel.settings.ignoreHiddenFiles)
                SettingRow(title: "Unterordner ignorieren", subtitle: "Nur die erste Ordnerebene scannen", isOn: $viewModel.settings.ignoreSubfolders)
                SettingRow(title: "Konflikte lösen", subtitle: "Namen automatisch durchnummerieren", isOn: $viewModel.settings.resolveConflictsAutomatically)
                SettingRow(title: "Unbekanntes zu Sonstiges", subtitle: "Nicht erkannte Typen einsortieren", isOn: $viewModel.settings.sortUnknownToOthers)
                SettingRow(title: "Zielordner erstellen", subtitle: "Fehlende Kategorieordner anlegen", isOn: $viewModel.settings.createMissingFolders)
            }
        }
    }
}
