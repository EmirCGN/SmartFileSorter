import SwiftUI

struct ContentView: View {
    @State private var viewModel = MainViewModel()

    var body: some View {
        MainWindowView(viewModel: viewModel)
    }
}

#Preview {
    ContentView()
}
