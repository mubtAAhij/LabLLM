import SwiftUI
import AppKit

struct CheckpointsView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var models: ModelStore
    @State private var items: [CheckpointItem] = []
    @State private var bestURL: URL?
    @State private var quantizeError: String?
    @State private var quantizeResult: String?
    @State private var renaming: CheckpointItem?
    @State private var renameValue = ""

    struct CheckpointItem: Identifiable {
        let id = UUID()
        let url: URL
        let meta: Checkpoint.Meta
        var name: String { url.lastPathComponent }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    WorkbenchPageHeader(eyebrow: String(localized: "checkpoints.header.run-studio", defaultValue: "Run Studio", comment: "Section header label above checkpoints view"),
                                        title: String(localized: "checkpoints.header.title", defaultValue: "Checkpoints", comment: "Title for checkpoints page"),
                                        subtitle: String(format: String(localized: "checkpoints.header.subtitle", defaultValue: "Saved runs for “%@”. Inspect, continue, duplicate, quantize, and organize this model's checkpoints.", comment: "Descriptive subtitle for checkpoints page with active model name"), "\(models.activeName)"),
                                        icon: "cube.box")
                    Spacer()
                    Button { refresh() } label: { Label(String(localized: "checkpoints.actions.refresh", defaultValue: "Refresh", comment: "Button title to refresh checkpoint list"), systemImage: "arrow.clockwise") }
                }
                Label(String(localized: "checkpoints.help.switch-model", defaultValue: "Checkpoints belong to the selected model. Switch models from the box at the top left of the sidebar.", comment: "Help text explaining model-scoped checkpoints"), systemImage: "square.stack.3d.up")
                    .font(.caption).foregroundStyle(.secondary)

                if let r = quantizeResult {
                    Label(r, systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                }
                if let e = quantizeError {
                    Label(e, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                }

                if items.isEmpty {
                    ContentUnavailableView(String(localized: "checkpoints.empty.title", defaultValue: "No checkpoints for this model yet", comment: "Empty state title when active model has no checkpoints"), systemImage: "tray",
                        description: Text(String(format: String(localized: "checkpoints.empty.message", defaultValue: "Finish (or stop) a training run for “%@” and it will be saved here automatically.", comment: "Empty state message with active model name"), "\(models.activeName)")))
                        .frame(height: 220)
                } else {
                    ForEach(items) { item in row(item) }
                }
            }.padding(WorkbenchTheme.pagePadding)
        }
        .onAppear(perform: refresh)
        .alert(String(localized: "checkpoints.rename.title", defaultValue: "Rename checkpoint", comment: "Dialog title for renaming a checkpoint"), isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField(String(localized: "checkpoints.rename.name-field-label", defaultValue: "Checkpoint name", comment: "Label for checkpoint name input field"), text: $renameValue)
            Button(String(localized: "checkpoints.rename.confirm", defaultValue: "Rename", comment: "Confirmation button title for rename action")) { renameSelected() }
            Button(String(localized: "checkpoints.rename.cancel", defaultValue: "Cancel", comment: "Cancel button title in rename dialog"), role: .cancel) { renaming = nil }
        } message: { Text(String(localized: "checkpoints.rename.help", defaultValue: "Use a concise local name for this checkpoint.", comment: "Helper text for checkpoint rename dialog")) }
        .onChange(of: models.activeID) { _ in refresh() }
    }

    private func row(_ item: CheckpointItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "cube.box").foregroundStyle(.tint)
                Text(item.name).font(.headline)
                if item.url == bestURL {
                    Text(String(localized: "checkpoints.badge.best", defaultValue: "BEST", comment: "Badge label marking best checkpoint")).font(.caption2.bold()).padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.green.opacity(0.2), in: Capsule()).foregroundStyle(.green)
                }
                if item.meta.loraRank != nil {
                    Text("LoRA").font(.caption2.bold()).padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.purple.opacity(0.15), in: Capsule()).foregroundStyle(.purple)
                }
                Spacer()
                Text(item.meta.method).font(.caption).foregroundStyle(.secondary)
                Text(item.meta.createdAt, style: .date).font(.caption).foregroundStyle(.secondary)
            }
            HStack(spacing: 20) {
                stat(String(localized: "checkpoints.table.column.step", defaultValue: "Step", comment: "Column title for checkpoint step"), "\(item.meta.step)")
                stat(String(localized: "checkpoints.table.column.loss", defaultValue: "Loss", comment: "Column title for checkpoint loss"), String(format: "%.3f", item.meta.loss))
                stat(String(localized: "checkpoints.table.column.val", defaultValue: "Val", comment: "Column title for validation metric"), item.meta.valLoss > 0 ? String(format: "%.3f", item.meta.valLoss) : "—")
                stat(String(localized: "checkpoints.table.column.params", defaultValue: "Params", comment: "Column title for model parameter count"), format(item.meta.config.estimatedParameters))
                stat(String(localized: "checkpoints.table.column.vocab", defaultValue: "Vocab", comment: "Column title for vocabulary size"), "\(item.meta.config.vocabSize)")
            }
            HStack {
                Button(String(localized: "checkpoints.actions.load-for-sampling", defaultValue: "Load for sampling", comment: "Menu action to load checkpoint for sampling only")) { state.loadCheckpoint(item.url, meta: item.meta) }.buttonStyle(WorkbenchSecondaryButtonStyle())
                Button(String(localized: "checkpoints.actions.continue-training", defaultValue: "Continue training", comment: "Menu action to continue training from checkpoint")) { state.prepareContinuation(from: item.url, meta: item.meta, asFineTune: false) }
                    .buttonStyle(WorkbenchSecondaryButtonStyle())
                    .disabled(item.meta.quantizedBits != nil)
                Button(String(localized: "checkpoints.actions.continue-fine-tuning", defaultValue: "Continue fine-tuning", comment: "Menu action to continue fine-tuning from selected checkpoint")) { state.prepareContinuation(from: item.url, meta: item.meta, asFineTune: true) }
                    .buttonStyle(WorkbenchPrimaryButtonStyle())
                    .disabled(item.meta.quantizedBits != nil)
                Menu(String(localized: "checkpoints.actions.quantize", defaultValue: "Quantize", comment: "Menu action to quantize selected checkpoint")) {
                    Button("8-bit") { quantize(item, bits: 8) }
                    Button("4-bit") { quantize(item, bits: 4) }
                }.menuStyle(.borderlessButton).frame(width: 100)
                Button(String(localized: "checkpoints.actions.view-model-card", defaultValue: "View model card", comment: "Menu action to open model card for selected checkpoint")) { NSWorkspace.shared.open(item.url.appendingPathComponent("model_card.md")) }
                    .buttonStyle(WorkbenchSecondaryButtonStyle())
                Menu {
                    Button(String(localized: "checkpoints.actions.rename", defaultValue: "Rename", comment: "Menu action to rename selected checkpoint")) { renaming = item; renameValue = item.name }
                    Button(String(localized: "checkpoints.actions.duplicate", defaultValue: "Duplicate", comment: "Menu action to duplicate selected checkpoint")) { duplicate(item) }
                    Button(String(localized: "checkpoints.actions.reveal-in-finder", defaultValue: "Reveal in Finder", comment: "Menu action to reveal checkpoint in Finder")) { NSWorkspace.shared.activateFileViewerSelecting([item.url]) }
                } label: { Image(systemName: "ellipsis.circle") }
                    .menuStyle(.borderlessButton)
                Button(role: .destructive) {
                    try? FileManager.default.removeItem(at: item.url); refresh()
                } label: { Text(String(localized: "checkpoints.actions.delete", defaultValue: "Delete", comment: "Menu action to delete selected checkpoint")) }.buttonStyle(WorkbenchSecondaryButtonStyle())
            }
        }
        .padding(14)
        .background(WorkbenchTheme.panel, in: RoundedRectangle(cornerRadius: WorkbenchTheme.cornerRadius, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: WorkbenchTheme.cornerRadius, style: .continuous).strokeBorder(WorkbenchTheme.grid) }
    }

    private func quantize(_ item: CheckpointItem, bits: Int) {
        quantizeError = nil; quantizeResult = nil
        state.quantizeCheckpoint(item.url, bits: bits) { result in
            switch result {
            case .success(let (url, origBytes, qBytes)):
                let origMB = Double(origBytes) / 1_048_576, qMB = Double(qBytes) / 1_048_576
                quantizeResult = String(format: String(localized: "checkpoints.quantize.saved-size-summary", defaultValue: "Saved %@ — %.1f MB → %.1f MB", comment: "Success message after quantization with filename and size change"), "\(url.lastPathComponent)", String(format: "%.1f", origMB), String(format: "%.1f", qMB))
                refresh()
            case .failure(let error):
                quantizeError = String(format: String(localized: "checkpoints.quantize.failed", defaultValue: "Quantization failed: %@", comment: "Error message when checkpoint quantization fails"), "\(error.localizedDescription)")
            }
        }
    }

    private func refresh() {
        items = Checkpoint.list().compactMap { url in
            guard let meta = try? Checkpoint.loadMeta(from: url) else { return nil }
            return CheckpointItem(url: url, meta: meta)
        }
        bestURL = Checkpoint.best()
    }

    private func renameSelected() {
        guard let item = renaming else { return }
        let name = renameValue.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "-")
        guard !name.isEmpty else { return }
        do {
            try FileManager.default.moveItem(at: item.url, to: item.url.deletingLastPathComponent().appendingPathComponent(name, isDirectory: true))
            quantizeResult = String(format: String(localized: "checkpoints.rename.success", defaultValue: "Renamed checkpoint to %@", comment: "Success message after renaming checkpoint"), "\(name)")
        } catch { quantizeError = String(format: String(localized: "checkpoints.rename.failed", defaultValue: "Couldn't rename checkpoint: %@", comment: "Error message when checkpoint rename fails"), "\(error.localizedDescription)") }
        renaming = nil
        refresh()
    }

    private func duplicate(_ item: CheckpointItem) {
        let copyName = "\(item.name)-copy-\(Int(Date().timeIntervalSince1970))"
        do {
            try FileManager.default.copyItem(at: item.url, to: item.url.deletingLastPathComponent().appendingPathComponent(copyName, isDirectory: true))
            quantizeResult = String(format: String(localized: "checkpoints.duplicate.success", defaultValue: "Duplicated %@", comment: "Success message after duplicating checkpoint"), "\(item.name)")
        } catch { quantizeError = String(format: String(localized: "checkpoints.duplicate.failed", defaultValue: "Couldn't duplicate checkpoint: %@", comment: "Error message when checkpoint duplication fails"), "\(error.localizedDescription)") }
        refresh()
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value).font(.callout.bold()).monospacedDigit()
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }
    private func format(_ n: Int) -> String {
        let f = NumberFormatter(); f.numberStyle = .decimal
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}
