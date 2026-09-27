import SwiftData
import SwiftUI

struct DiagnosticView: View {
    @AppStorage(AppConstants.Storage.offlineMode) var isOfflineMode: Bool = false
    @State private var monitor = NetworkMonitor()
    @AppStorage(AppConstants.Storage.lastSync) var lastSync: Double = 0
    @Query(filter: #Predicate<PendingOperation> { $0.state.rawValue != "successful" })
    var openOperations: [PendingOperation]
    
    @State private var isSyncing: Bool = false

    var failedCount: Int {
        openOperations.filter { $0.state == .failed }.count
    }
    
    var pendingCount: Int {
        openOperations.filter { $0.state == .pending }.count
    }

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("System Status")) {
                    HStack {
                        Label("Network", systemImage: monitor.isConnected ? "wifi" : "wifi.slash")
                        Spacer()
                        HStack(spacing: 5) {
                            Circle()
                                .fill(monitor.isConnected ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                            Text(monitor.isConnected ? "Connected" : "Offline")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(monitor.isConnected ? Color.green : Color.red)
                        }
                    }
                    
                    HStack {
                        Label("Last Sync", systemImage: "clock.arrow.circlepath")
                        Spacer()
                        Text(lastSync == 0 ? "Never" : Date(timeIntervalSince1970: lastSync).formatted(date: .abbreviated, time: .shortened))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Label("Pending Queue", systemImage: "hourglass")
                        Spacer()
                        Text("\(pendingCount)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Label("Failed Queue", systemImage: "exclamationmark.triangle")
                        Spacer()
                        Text("\(failedCount)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(failedCount > 0 ? Color.red : Color.secondary)
                    }
                }

                Section(
                    header: Text("Synchronization"),
                    footer: Text("Re-attempts all pending and failed operations immediately against the server.")
                ) {
                    Button(action: forceSyncAll) {
                        HStack(spacing: 8) {
                            if isSyncing {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(.white)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                            Text(isSyncing ? "Syncing..." : "Force Sync Now")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.indigo)
                    .disabled(isSyncing || openOperations.isEmpty)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowBackground(Color.clear)
                }

                Section(header: Text("Developer Options")) {
                    Toggle(isOn: $isOfflineMode) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Simulate Offline Mode")
                                .font(.body)
                            Text("Prevents outgoing sync requests to test local queuing")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tint(.indigo)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Diagnostics")
        }
    }

    private func forceSyncAll() {
        guard !isSyncing else { return }
        isSyncing = true
        Task {
            for operation in openOperations {
                await operation.sync(force: true)
            }
            isSyncing = false
        }
    }
}

#Preview {
    DiagnosticView().modelContainer(
        for: [Product.self, PendingOperation.self], inMemory: true)
}
