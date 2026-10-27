import SwiftUI
import IslandCore

struct ApprovalCompactView: View {
    @ObservedObject var manager: ApprovalManager
    var minimal = false
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "exclamationmark.bubble.fill")
            Text(minimal ? "\(manager.requests.count)" : "Approval needed")
                .font(.system(size: 11, weight: .semibold))
        }.foregroundColor(.orange).lineLimit(1)
            .accessibilityLabel("\(manager.requests.count) pending approval requests")
    }
}
struct ApprovalExpandedView: View {
    @ObservedObject var manager: ApprovalManager
    @State private var selected: UUID?
    @State private var submitting: UUID?
    private var current: ApprovalRequest? {
        if let selected { return manager.requests.first { $0.id == selected } }
        return manager.requests.first
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let request = current {
                HStack {
                    Label("Approval needed", systemImage: "exclamationmark.bubble.fill").foregroundColor(.orange)
                    Spacer()
                    Text(request.provider.label).foregroundColor(.secondary)
                }.font(.system(size: 13, weight: .semibold))
                if manager.requests.count > 1 {
                    Picker("Pending request", selection: Binding(get: { request.id }, set: { selected = $0; submitting = nil })) {
                        ForEach(manager.requests) { item in Text("\(item.provider.label) · \(item.tool)").tag(item.id) }
                    }.pickerStyle(.menu)
                }
                Text(request.tool).font(.headline)
                Text("Full hook request · expires after two minutes").font(.caption).foregroundColor(.secondary)
                ScrollView {
                    Text(request.details).font(.system(size: 11, design: .monospaced))
                        .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                }.frame(maxHeight: .infinity).background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                HStack(spacing: 12) {
                    Button("Use app prompt") { act(.passthrough, request: request) }
                    Spacer()
                    Button("Deny") { act(.deny, request: request) }
                    Button("Approve once") { act(.allow, request: request) }
                        .buttonStyle(.borderedProminent).tint(.orange)
                }.disabled(submitting == request.id || request.expires <= Date())
                Text("Only this request. No permanent permission is granted.").font(.caption2).foregroundColor(.secondary)
            } else {
                Spacer()
                Label(manager.requests.isEmpty ? "No pending approvals" : "This request is no longer pending", systemImage: "checkmark.bubble")
                    .frame(maxWidth: .infinity)
                Text("Connected local Codex and Claude Code requests appear here.")
                    .font(.caption).foregroundColor(.secondary).frame(maxWidth: .infinity)
                if !manager.requests.isEmpty {
                    Button("Review next request") { selected = manager.requests.first?.id; submitting = nil }
                        .frame(maxWidth: .infinity)
                }
                Spacer()
            }
        }.onAppear { if selected == nil { selected = manager.requests.first?.id } }
        .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 6)
    }
    private func act(_ decision: ApprovalDecision, request: ApprovalRequest) {
        guard submitting != request.id else { return }
        selected = request.id
        submitting = request.id
        manager.decide(request.id, decision)
    }
}
