import SwiftUI

struct ServerView: View {
    @EnvironmentObject var server: ModelServer
    @EnvironmentObject var trainer: Trainer
    @State private var portText = "8080"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                WorkbenchPageHeader(eyebrow: String(localized: "server-view.section.system", defaultValue: "System", comment: "Section title for local model server system panel"), title: String(localized: "server-view.title.local-model-server", defaultValue: "Local Model Server", comment: "Main title for local model server view"), subtitle: String(localized: "server-view.subtitle.local-endpoint-description", defaultValue: "Expose the loaded model through an OpenAI-shaped endpoint for tools running on this Mac.", comment: "Description explaining local OpenAI-compatible server endpoint"), icon: "server.rack")

                if !trainer.hasModel {
                    Label(String(localized: "server-view.state.no-model-loaded", defaultValue: "No model loaded — train or load a checkpoint first.", comment: "Status message shown when no model is loaded for serving"), systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }

                GroupBox(String(localized: "server-view.field.status", defaultValue: "Status", comment: "Label for server status field")) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Circle().fill(server.isRunning ? .green : .secondary).frame(width: 8, height: 8)
                            Text(server.isRunning ? String(format: String(localized: "server-view.status.running-on-localhost-port", defaultValue: "Running on http://127.0.0.1:%d", comment: "Status text showing running local server address and port"), server.port) : String(localized: "server-view.status.stopped", defaultValue: "Stopped", comment: "Status text when local server is not running"))
                            Spacer()
                            TextField(String(localized: "server-view.field.port", defaultValue: "Port", comment: "Label for server port setting"), text: $portText).textFieldStyle(.roundedBorder).frame(width: 80)
                                .disabled(server.isRunning)
                            if server.isRunning {
                                Button(String(localized: "server-view.action.stop", defaultValue: "Stop", comment: "Button title to stop local model server")) { server.stop() }.buttonStyle(WorkbenchSecondaryButtonStyle())
                            } else {
                                Button(String(localized: "server-view.action.start", defaultValue: "Start", comment: "Button title to start local model server")) {
                                    let port = UInt16(portText) ?? 8080
                                    server.start(trainer: trainer, port: port)
                                }.buttonStyle(WorkbenchPrimaryButtonStyle()).disabled(!trainer.hasModel)
                            }
                        }
                        if let err = server.lastError {
                            Label(err, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange).font(.caption)
                        }
                    }.padding(8)
                }

                GroupBox(String(localized: "server-view.section.try-it", defaultValue: "Try it", comment: "Section title introducing server usage example")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "server-view.example.curl-title", defaultValue: "curl example", comment: "Label for curl request example snippet")).font(.caption).foregroundStyle(.secondary)
                        Text("""
                        curl http://127.0.0.1:\(server.port)/v1/chat/completions \\
                          -H "Content-Type: application/json" \\
                          -d '{"messages":[{"role":"user","content":"Hello"}],"stream":true}'
                        """)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                        .padding(10)
                        .background(Color.gray.opacity(0.08), in: RoundedRectangle(cornerRadius: WorkbenchTheme.cornerRadius))
                    }.padding(8)
                }

                GroupBox(String(localized: "server-view.section.notes", defaultValue: "Notes", comment: "Section title for server behavior notes")) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "server-view.notes.endpoints", defaultValue: "• Endpoints: GET /v1/models, POST /v1/chat/completions", comment: "Note listing supported API endpoints")).font(.caption)
                        Text(String(localized: "server-view.notes.stream-flag", defaultValue: "• Add stream: true to receive OpenAI-shaped Server-Sent Events.", comment: "Note explaining stream flag behavior for server responses")).font(.caption)
                        Text(String(localized: "server-view.notes.requests-refused-during-training", defaultValue: "• Requests are refused while a training run is active.", comment: "Note describing request rejection during active training")).font(.caption)
                    }.foregroundStyle(.secondary).padding(8)
                }

                if !server.requestLog.isEmpty {
                    GroupBox(String(localized: "server-view.section.recent-requests", defaultValue: "Recent requests", comment: "Section title for recent server request log")) {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(server.requestLog, id: \.self) { Text($0).font(.caption.monospaced()) }
                        }.padding(8)
                    }
                }
            }.padding(WorkbenchTheme.pagePadding)
        }
    }
}
