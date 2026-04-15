import SwiftUI

struct SafeSortConfirmationView: View {
    @Bindable var viewModel: MainViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.plannedMoveItems) { item in
                        plannedMoveRow(item)
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(minHeight: 260, maxHeight: 380)

            footer
        }
        .padding(22)
        .frame(minWidth: 620, minHeight: 500)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.shield")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.green)
                    .frame(width: 34, height: 34)
                    .background(.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Sortierung bestätigen")
                        .font(.title2.weight(.semibold))
                    Text("\(viewModel.plannedMoveItems.count) geplante Verschiebungen")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            Text("Prüfe die Ziele. Erst nach deiner Bestätigung werden Dateien verschoben.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button {
                viewModel.isShowingSortConfirmation = false
                dismiss()
            } label: {
                Label("Abbrechen", systemImage: "xmark")
            }
            .controlSize(.large)
            .disabled(viewModel.isRunning)

            Spacer()

            Button {
                viewModel.startConfirmPlannedSort()
                dismiss()
            } label: {
                Label("Jetzt verschieben", systemImage: "arrow.right.circle.fill")
                    .font(.callout.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!viewModel.canConfirmSort)
        }
        .padding(.top, 4)
    }

    private func plannedMoveRow(_ item: FileItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.category.systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.tint)
                .frame(width: 30, height: 30)
                .background(.tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 5) {
                Text(item.originalName)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack(spacing: 6) {
                    Text(item.sourceURL.deletingLastPathComponent().lastPathComponent)
                        .foregroundStyle(.secondary)
                    Image(systemName: "arrow.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                    Text(destinationText(for: item))
                        .foregroundStyle(.primary)
                }
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
            }

            Spacer(minLength: 12)

            Text(item.category.name)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(.tint.opacity(0.1), in: Capsule())
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.quaternary, lineWidth: 1)
        }
    }

    private func destinationText(for item: FileItem) -> String {
        let fileName = item.destinationURL?.lastPathComponent ?? item.originalName
        return "\(item.category.folderName)/\(fileName)"
    }
}
