import AppKit
import Foundation

@MainActor
struct FolderPickerService {
    func pickFolder() -> URL? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.prompt = "Auswählen"
        panel.message = "Wähle den Ordner aus, der analysiert oder sortiert werden soll."

        return panel.runModal() == .OK ? panel.url : nil
    }
}
