import SwiftUI

@main
struct MacNewFileKitApp: App {
    @StateObject private var model = SettingsModel()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .frame(minWidth: 560, minHeight: 520)
        }

        Settings {
            ContentView(model: model)
                .frame(width: 560, height: 520)
        }
    }
}
