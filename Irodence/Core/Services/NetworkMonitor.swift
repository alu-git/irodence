import Foundation
import Network

/// Monitors network connectivity using Apple's Network framework (NWPathMonitor).
/// Dispatches connection updates on MainActor and triggers automatic background sync.
@MainActor
final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    @Published private(set) var isConnected = true
    @Published private(set) var isCellular = false

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.irodence.networkmonitor", qos: .utility)

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                let connected = path.status == .satisfied
                let cellular = path.isExpensive || path.usesInterfaceType(.cellular)
                
                let wasDisconnected = !(self?.isConnected ?? true)
                self?.isConnected = connected
                self?.isCellular = cellular

                if wasDisconnected && connected {
                    // Reconnection event: trigger pending offline sync
                    OfflineSyncService.shared.syncPending()
                }
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
