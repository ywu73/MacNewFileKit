import SwiftUI

@main
struct MacNewFileKitApp: App {
    @StateObject private var model = SettingsModel()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .frame(minWidth: 700, minHeight: 680)
        }

        Settings {
            ContentView(model: model)
                .frame(width: 700, height: 680)
        }
    }
}
