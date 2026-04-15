import SwiftUI

struct MainWindowFooterView: View {
    @Binding var showLogs: Bool

    let isRunning: Bool
    let canUndoSort: Bool
    let canCancel: Bool
    let canPrimaryAction: Bool
    let primaryActionTitle: String
    let primaryActionIcon: String

    let reset: () -> Void
    let undo: () -> Void
    let cancel: () -> Void
    let primaryAction: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Toggle("Logs anzeigen", isOn: $showLogs)
                .toggleStyle(.checkbox)

            Spacer()

            Button(action: reset) {
                Label("Reset", systemImage: "arrow.counterclockwise")
            }
            .controlSize(.large)
            .disabled(isRunning)

            Button(action: undo) {
                Label("Rückgängig", systemImage: "arrow.uturn.backward")
            }
            .controlSize(.large)
            .disabled(!canUndoSort)

            if canCancel {
                Button(role: .destructive, action: cancel) {
                    Label("Abbrechen", systemImage: "xmark.circle")
                }
                .controlSize(.large)
            }

            Button(action: primaryAction) {
                Label(primaryActionTitle, systemImage: primaryActionIcon)
                    .font(.callout.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!canPrimaryAction)
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay { RoundedRectangle(cornerRadius: 8).stroke(.quaternary, lineWidth: 1) }
    }
}
