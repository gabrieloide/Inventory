import SwiftUI
import SwiftData

struct PendingView: View {
    @Query(sort: \PendingOperation.tries, order: .reverse) var operations: [PendingOperation]

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
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Queue")
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
