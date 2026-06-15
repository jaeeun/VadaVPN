import SwiftUI
import NetworkExtension

struct ContentView: View {
    @EnvironmentObject private var tunnelManager: TunnelManager

    var body: some View {
        VStack(spacing: 50) {
            Image(systemName: tunnelManager.isConnected ? "lock.shield.fill" : "lock.open")
                .font(.system(size: 120))
                .foregroundStyle(statusColor)

            VStack(spacing: 12) {
                Text(tunnelManager.status.displayText)
                    .font(.title)
                    .fontWeight(.semibold)

                Text("Server: \(tunnelManager.endpointDescription)")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            Button {
                Task { await tunnelManager.toggle() }
            } label: {
                Text(buttonTitle)
                    .frame(minWidth: 320)
            }
            .disabled(tunnelManager.isBusy || tunnelManager.status == .invalid && tunnelManager.lastError != nil)

            if let error = tunnelManager.lastError {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 80)
            }
        }
        .padding()
    }

    private var statusColor: Color {
        switch tunnelManager.status {
        case .connected: return .green
        case .connecting, .reasserting, .disconnecting: return .yellow
        default: return .secondary
        }
    }

    private var buttonTitle: String {
        switch tunnelManager.status {
        case .connected, .connecting, .reasserting: return "Disconnect"
        default: return "Connect"
        }
    }
}
