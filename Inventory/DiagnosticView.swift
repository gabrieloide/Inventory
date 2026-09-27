import SwiftData
import SwiftUI

struct DiagnosticView: View {
    @AppStorage(AppConstants.Storage.offlineMode) var isOfflineMode: Bool = false
    @State private var monitor = NetworkMonitor()
    @AppStorage(AppConstants.Storage.lastSync) var lastSync: Double = 0

    @Query var allOperations: [PendingOperation]
    var openOperations: [PendingOperation] {
        allOperations.filter { ($0.state ?? .pending) != .successful }
    }

    @Environment(\.modelContext) var environment

    var failedCount: Int {
        openOperations.filter { ($0.state ?? .pending) == .failed }.count
    }

    var pendingCount: Int {
        openOperations.filter { ($0.state ?? .pending) == .pending || ($0.state ?? .pending) == .inProgress }.count
    }

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("System Status")) {
                    HStack {
                        Label("Network Status", systemImage: monitor.isConnected ? "wifi" : "wifi.slash")
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
                        Label("Sync Engine", systemImage: "arrow.triangle.2.circlepath")
                        Spacer()
                        Text(SyncEngine.shared.isSyncing ? "Syncing..." : "Idle")
                            .font(.subheadline)
                            .foregroundStyle(SyncEngine.shared.isSyncing ? Color.blue : Color.secondary)
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
                    header: Text("Synchronization Actions"),
                    footer: Text("Forces a full flush of all pending operations and reconciles remote server inventory.")
                ) {
                    Button(action: forceSyncAll) {
                        HStack(spacing: 8) {
                            if SyncEngine.shared.isSyncing {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(.white)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                            Text(SyncEngine.shared.isSyncing ? "Syncing..." : "Force Full Sync Now")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.indigo)
                    .disabled(SyncEngine.shared.isSyncing)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowBackground(Color.clear)

                    if failedCount > 0 {
                        Button(role: .destructive, action: clearFailedOperations) {
                            HStack(spacing: 8) {
                                Image(systemName: "trash")
                                Text("Clear Failed Operations (\(failedCount))")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowBackground(Color.clear)
                    }
                }

                Section(header: Text("Developer Simulation")) {
                    Toggle(isOn: $isOfflineMode) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Simulate Offline Mode")
                                .font(.body)
                            Text("Suspends all network synchronization to test local queue buffering")
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
        Task {
            await SyncEngine.shared.fullSync(context: environment, force: true)
        }
    }

    private func clearFailedOperations() {
        for op in allOperations where (op.state ?? .pending) == .failed {
            environment.delete(op)
        }
    }
}

#Preview {
    DiagnosticView()
        .modelContainer(for: [Product.self, PendingOperation.self, StockChange.self], inMemory: true)
}
