import SwiftUI

struct FolderSelectionView: View {
    @Bindable var viewModel: MainViewModel

    var body: some View {
        InfoCard(title: "Ordner", systemImage: "folder") {
            VStack(alignment: .leading, spacing: 10) {
                Text(viewModel.selectedFolderPath)
                    .font(.callout)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .foregroundStyle(viewModel.selectedFolderURL == nil ? .secondary : .primary)

                Button {
                    viewModel.pickFolder()
                } label: {
                    Label("Ordner auswählen", systemImage: "folder.badge.plus")
                }
            }
        }
    }
}
