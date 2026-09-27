import SwiftUI
import SwiftData

struct PendingView: View {
    @Query(sort: \PendingOperation.tries, order: .reverse) var operations: [PendingOperation]
    @Environment(\.modelContext) var environment

    var body: some View {
        NavigationStack {
            Group {
                if operations.isEmpty {
                    ContentUnavailableView(
                        "Queue is Empty",
                        systemImage: "checkmark.circle",
                        description: Text("All operations are synchronized with the server.")
                    )
                } else {
                    List {
                        Section(
                            header: Text("Sync Queue"),
                            footer: Text("Operations process automatically when network connectivity is restored.")
                        ) {
                            ForEach(operations) { op in
                                HStack(spacing: 12) {
                                    operationTypeIcon(for: op.type)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(op.productName.isEmpty ? "Product" : op.productName)
                                            .font(.headline)
                                        Text(op.type.displayName)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    statusBadge(for: op)
                                }
                                .padding(.vertical, 4)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        environment.delete(op)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .leading) {
                                    if (op.state ?? .pending) == .failed {
                                        Button {
                                            Task {
                                                op.tries = 0
                                                await op.sync(force: true)
                                            }
                                        } label: {
                                            Label("Retry", systemImage: "arrow.clockwise")
                                        }
                                        .tint(.blue)
                                    }
                                }
                            }
                            .onDelete(perform: deleteOperations)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Queue")
            .toolbar {
                if !operations.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button {
                                retryFailedOperations()
                            } label: {
                                Label("Retry Failed", systemImage: "arrow.clockwise")
                            }

                            Button(role: .destructive) {
                                clearFailedOperations()
                            } label: {
                                Label("Clear Failed", systemImage: "xmark.circle")
                            }

                            Button {
                                clearSyncedOperations()
                            } label: {
                                Label("Clear Synced History", systemImage: "checkmark.circle")
                            }

                            Divider()

                            Button(role: .destructive) {
                                clearAllOperations()
                            } label: {
                                Label("Clear All", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .accessibilityLabel("Queue Options")
                    }
                }
            }
        }
    }

    private func deleteOperations(at offsets: IndexSet) {
        for index in offsets {
            let op = operations[index]
            environment.delete(op)
        }
    }

    private func retryFailedOperations() {
        Task {
            for op in operations where (op.state ?? .pending) == .failed {
                op.tries = 0
                await op.sync(force: true)
            }
        }
    }

    private func clearFailedOperations() {
        for op in operations where (op.state ?? .pending) == .failed {
            environment.delete(op)
        }
    }

    private func clearSyncedOperations() {
        for op in operations where (op.state ?? .pending) == .successful {
            environment.delete(op)
        }
    }

    private func clearAllOperations() {
        for op in operations {
            environment.delete(op)
        }
    }

    @ViewBuilder
    private func operationTypeIcon(for type: OperationType) -> some View {
        let (icon, color) = iconAndColor(for: type)
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(color.opacity(0.12))
                .frame(width: 40, height: 40)
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(color)
        }
    }

    private func iconAndColor(for type: OperationType) -> (String, Color) {
        switch type {
        case .make:
            return ("plus", .blue)
        case .updateStock:
            return ("arrow.triangle.2.circlepath", .indigo)
        case .delete:
            return ("trash", .red)
        }
    }

    @ViewBuilder
    private func statusBadge(for op: PendingOperation) -> some View {
        switch op.state ?? .pending {
        case .pending:
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.system(size: 10, weight: .bold))
                Text("Pending")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Color.orange.opacity(0.14), in: Capsule())
            .foregroundStyle(Color.orange)

        case .successful:
            HStack(spacing: 4) {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                Text("Synced")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Color.green.opacity(0.14), in: Capsule())
            .foregroundStyle(Color.green)

        case .failed:
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 10, weight: .bold))
                Text("Failed (\(op.tries))")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Color.red.opacity(0.14), in: Capsule())
            .foregroundStyle(Color.red)
        }
    }
}

#Preview {
    PendingView().modelContainer(for: [Product.self, PendingOperation.self], inMemory: true)
}
