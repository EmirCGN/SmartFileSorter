import SwiftUI

struct CategoryOverviewView: View {
    @Bindable var viewModel: MainViewModel

    var body: some View {
        InfoCard(title: "Kategorien", systemImage: "square.grid.2x2") {
            VStack(spacing: 8) {
                ForEach(Category.all) { category in
                    HStack(spacing: 10) {
                        Image(systemName: category.systemImage)
                            .frame(width: 18)
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(category.name)
                            Text(category.folderName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(viewModel.count(for: category))")
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.quaternary, in: Capsule())
                    }
                }
            }
        }
    }
}
