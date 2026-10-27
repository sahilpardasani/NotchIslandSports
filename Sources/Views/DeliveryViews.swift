import SwiftUI
import IslandCore

struct DeliverySetupView: View {
    @ObservedObject var manager: DeliveryManager
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Swiggy deliveries").font(.headline)
            HStack {
                if manager.connecting {
                    ProgressView().controlSize(.small)
                    Button("Cancel sign-in") { manager.cancelSignIn() }
                } else {
                    Button(manager.connected ? "Reconnect Swiggy…" : "Connect Swiggy…") { manager.connect() }
                    Button("Disconnect") { manager.disconnect() }
                }
            }
            Text(manager.status).font(.caption).foregroundColor(.secondary)
            if !manager.addresses.isEmpty {
                ForEach(manager.addresses) { address in
                    Button { manager.selectAddress(address.id) } label: {
                        Text(address.addressLine).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                if manager.hasMoreAddresses { Button("More addresses") { manager.moreAddresses() } }
            }
            Text("Sign in once in your browser. Active food orders appear when you swipe to Deliveries. Tracking is read-only; credentials stay in Keychain.")
                .font(.caption).foregroundColor(.secondary)
        }
    }
}

struct DeliveryExpandedView: View {
    @ObservedObject var manager: DeliveryManager
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Label("Swiggy", systemImage: "takeoutbag.and.cup.and.straw.fill")
                    .font(.system(size: 13, weight: .semibold)).foregroundColor(.orange)
                if manager.orders.isEmpty {
                    Text(manager.connected ? "No active deliveries" : "Connect Swiggy in About → Configure")
                        .font(.system(size: 14, weight: .semibold))
                }
                ForEach(manager.orders) { order in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(order.restaurant).font(.system(size: 17, weight: .semibold)).lineLimit(2)
                            Spacer(minLength: 8)
                            if let eta = order.eta { Text(eta).font(.system(size: 15, weight: .bold)).foregroundColor(.orange).fixedSize() }
                        }
                        Text(order.status).font(.system(size: 13)).foregroundColor(.white.opacity(0.85))
                        Text("Updated \(order.observedAt.formatted(date: .omitted, time: .shortened))")
                            .font(.system(size: 10)).foregroundColor(.secondary)
                    }
                    if order.id != manager.orders.last?.id { Divider() }
                }
            }.padding(.horizontal, 16).padding(.vertical, 10)
        }
    }
}
