import Network
import Observation

@Observable
class NetworkMonitor{
    var isConnected: Bool = true
    private let monitor = NWPathMonitor()

    init(){
        monitor.pathUpdateHandler = { path in
            self.isConnected = path.status == .satisfied
            print("Network status updated: \(self.isConnected)")
        }
        monitor.start(queue: .main)
    }
}