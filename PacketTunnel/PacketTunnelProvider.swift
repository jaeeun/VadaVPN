import NetworkExtension
import WireGuardKit
import os.log

class PacketTunnelProvider: NEPacketTunnelProvider {

    private lazy var adapter = WireGuardAdapter(with: self) { logLevel, message in
        os_log("%{public}@", log: .default, type: logLevel == .error ? .error : .info, message)
    }

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        guard let tunnelProviderProtocol = protocolConfiguration as? NETunnelProviderProtocol,
              let wgQuickConfig = tunnelProviderProtocol.providerConfiguration?["WgQuickConfig"] as? String else {
            os_log("Missing WgQuickConfig in providerConfiguration", log: .default, type: .error)
            completionHandler(NEVPNError(.configurationInvalid))
            return
        }

        let tunnelConfiguration: TunnelConfiguration
        do {
            tunnelConfiguration = try TunnelConfiguration(fromWgQuickConfig: wgQuickConfig)
        } catch {
            os_log("Invalid wg-quick config: %{public}@", log: .default, type: .error, "\(error)")
            completionHandler(NEVPNError(.configurationInvalid))
            return
        }

        adapter.start(tunnelConfiguration: tunnelConfiguration) { adapterError in
            if let adapterError {
                os_log("WireGuard adapter failed to start: %{public}@", log: .default, type: .error, adapterError.localizedDescription)
            } else {
                os_log("WireGuard tunnel started, interface: %{public}@", log: .default, type: .info, self.adapter.interfaceName ?? "unknown")
            }
            completionHandler(adapterError)
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        adapter.stop { error in
            if let error {
                os_log("Failed to stop WireGuard adapter: %{public}@", log: .default, type: .error, error.localizedDescription)
            }
            completionHandler()
        }
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)? = nil) {
        guard let completionHandler else { return }
        // Returns the live runtime configuration (includes transfer counters and
        // last-handshake time) so the app can display connection details.
        adapter.getRuntimeConfiguration { settings in
            completionHandler(settings?.data(using: .utf8))
        }
    }
}
