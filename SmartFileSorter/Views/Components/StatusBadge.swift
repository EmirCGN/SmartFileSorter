import SwiftUI

struct StatusBadge: View {
    let state: AppState

    var body: some View {
        Label(state.rawValue, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(backgroundColor.opacity(0.14), in: Capsule())
            .overlay {
                Capsule().stroke(backgroundColor.opacity(0.22), lineWidth: 1)
            }
            .foregroundStyle(backgroundColor)
    }

    private var systemImage: String {
        switch state {
        case .ready: "checkmark.circle"
        case .analyzing: "magnifyingglass"
        case .sorting: "arrow.triangle.2.circlepath"
        case .finished: "checkmark.seal"
        case .failed: "xmark.octagon"
        }
    }

    private var backgroundColor: Color {
        switch state {
        case .ready: .secondary
        case .analyzing: .blue
        case .sorting: .orange
        case .finished: .green
        case .failed: .red
        }
    }
}
