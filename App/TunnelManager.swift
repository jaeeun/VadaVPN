import Foundation
import NetworkExtension
import WireGuardKit

/// Owns the NETunnelProviderManager for the WireGuard tunnel: installs/updates
/// the VPN configuration from the bundled wg-quick file and starts/stops it.
@MainActor
final class TunnelManager: ObservableObject {

    static let tunnelName = "Vada VPN"
    static let providerBundleIdentifier = "com.vada.appletv.vpn.tunnel"

    @Published private(set) var status: NEVPNStatus = .invalid
    @Published private(set) var endpointDescription: String = ""
    @Published private(set) var lastError: String?
    @Published var isBusy = false

    private var manager: NETunnelProviderManager?
    private var statusObserver: NSObjectProtocol?

    var isConnected: Bool { status == .connected }

    init() {
        statusObserver = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange, object: nil, queue: .main
        ) { [weak self] notification in
            guard let session = notification.object as? NETunnelProviderSession else { return }
            Task { @MainActor in
                self?.status = session.status
            }
        }
        Task { await load() }
    }

    deinit {
        if let statusObserver {
            NotificationCenter.default.removeObserver(statusObserver)
        }
    }

    /// Loads the bundled wg-quick config, validates it, and creates or updates
    /// the system VPN configuration.
    func load() async {
        do {
            let wgQuickConfig = try Self.bundledConfig()
            let tunnelConfiguration = try TunnelConfiguration(fromWgQuickConfig: wgQuickConfig, called: Self.tunnelName)
            endpointDescription = tunnelConfiguration.peers.first?.endpoint?.stringRepresentation ?? "unknown"

            let managers = try await NETunnelProviderManager.loadAllFromPreferences()
            let manager = managers.first ?? NETunnelProviderManager()

            let proto = NETunnelProviderProtocol()
            proto.providerBundleIdentifier = Self.providerBundleIdentifier
            proto.serverAddress = endpointDescription
            proto.providerConfiguration = ["WgQuickConfig": wgQuickConfig]

            manager.localizedDescription = Self.tunnelName
            manager.protocolConfiguration = proto
            manager.isEnabled = true

            try await manager.saveToPreferences()
            // Re-load after save: starting a freshly saved manager without
            // reloading fails with NEVPNErrorConfigurationInvalid.
            try await manager.loadFromPreferences()

            self.manager = manager
            self.status = manager.connection.status
            self.lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func connect() async {
        guard let manager else {
            await load()
            guard self.manager != nil else { return }
            await connect()
            return
        }
        isBusy = true
        defer { isBusy = false }
        do {
            if !manager.isEnabled {
                manager.isEnabled = true
                try await manager.saveToPreferences()
                try await manager.loadFromPreferences()
            }
            try manager.connection.startVPNTunnel()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func disconnect() {
        manager?.connection.stopVPNTunnel()
    }

    func toggle() async {
        switch status {
        case .connected, .connecting, .reasserting:
            disconnect()
        default:
            await connect()
        }
    }

    private static func bundledConfig() throws -> String {
        guard let url = Bundle.main.url(forResource: "appletv", withExtension: "conf") else {
            throw NSError(domain: "TunnelManager", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "appletv.conf not found in app bundle"
            ])
        }
        return try String(contentsOf: url, encoding: .utf8)
    }
}

extension NEVPNStatus {
    var displayText: String {
        switch self {
        case .invalid: return "Not Configured"
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting…"
        case .connected: return "Connected"
        case .reasserting: return "Reconnecting…"
        case .disconnecting: return "Disconnecting…"
        @unknown default: return "Unknown"
        }
    }
}
