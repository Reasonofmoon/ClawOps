import SwiftUI

@main
struct OpenClawControlApp: App {
    @StateObject private var viewModel = AppViewModel()

    var body: some Scene {
        Window("OpenClaw Control", id: "main") {
            ContentView()
                .environmentObject(viewModel)
        }
        .defaultSize(width: 1100, height: 760)
    }
}
