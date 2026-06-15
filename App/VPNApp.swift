import SwiftUI

@main
struct VPNApp: App {
    @StateObject private var tunnelManager = TunnelManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(tunnelManager)
        }
    }
}
