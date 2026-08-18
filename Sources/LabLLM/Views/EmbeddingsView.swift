import SwiftUI

struct EmbeddingsView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var trainer: Trainer
    @State private var timer: Timer?
    @State private var iterations = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            if !trainer.hasModel {
                // The enclosing stack is leading-aligned, so the placeholder needs the
                // full width to sit in the middle of the page rather than hugging the edge.
                ContentUnavailableView(String(
                    localized: "embeddings-view.empty-state.no-model-title",
                    defaultValue: "No model to visualize yet",
                    comment: "Title shown when no model is available for embedding visualization"
                ), systemImage: "point.3.connected.trianglepath.dotted",
                    description: Text(String(
                        localized: "embeddings-view.empty-state.no-model-message",
                        defaultValue: "Train or load a model first.",
                        comment: "Instruction message when model is required for embeddings view"
                    )))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if state.embeddingPoints.isEmpty {
                ContentUnavailableView(String(
                    localized: "embeddings-view.empty-state.no-map-title",
                    defaultValue: "No map yet",
                    comment: "Title shown when embedding map has not been computed"
                ), systemImage: "circle.grid.3x3",
                    description: Text(String(
                        localized: "embeddings-view.empty-state.no-map-message",
                        defaultValue: "Press Compute to project the model's trained token embeddings into 2D.",
                        comment: "Instruction explaining how to generate embedding map"
                    )))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                canvas.frame(maxHeight: .infinity)
            }
        }
        .onDisappear { timer?.invalidate() }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(String(
                    localized: "embeddings-view.panel.embedding-map-title",
                    defaultValue: "Embedding Map",
                    comment: "Panel title for embeddings visualization map"
                )).font(.title2.bold())
                Text(String(
                    localized: "embeddings-view.panel.embedding-map-description",
                    defaultValue: "PCA of the model's real trained token embeddings, then a similarity-based layout pass pulls related tokens together.",
                    comment: "Description of embedding map projection and layout process"
                ))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if state.isComputingEmbeddings {
                ProgressView().controlSize(.small)
            } else {
                Button {
                    state.computeEmbeddingMap()
                    iterations = 0
                } label: { Label(String(
                    localized: "embeddings-view.action.compute",
                    defaultValue: "Compute",
                    comment: "Button title to compute embedding map"
                ), systemImage: "arrow.triangle.2.circlepath") }
                    .buttonStyle(WorkbenchPrimaryButtonStyle())
            }
            if !state.embeddingPoints.isEmpty {
                Button { toggleAnimation() } label: {
                    Label(timer == nil ? String(
                        localized: "embeddings-view.action.animate-clustering",
                        defaultValue: "Animate clustering",
                        comment: "Toggle label to animate token clustering in embedding map"
                    ) : String(
                        localized: "embeddings-view.action.stop-animation",
                        defaultValue: "Stop",
                        comment: "Button title to stop embedding animation"
                    ), systemImage: timer == nil ? "play.fill" : "stop.fill")
                }.buttonStyle(WorkbenchSecondaryButtonStyle())
            }
        }.padding()
    }

    private var canvas: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height) - 40
            let cx = geo.size.width / 2, cy = geo.size.height / 2
            ZStack {
                ForEach(state.embeddingPoints) { p in
                    Text(p.label)
                        .font(.system(size: 11, design: .monospaced))
                        .padding(.horizontal, 4).padding(.vertical, 2)
                        .background(colorFor(p).opacity(0.85), in: RoundedRectangle(cornerRadius: 4))
                        .foregroundStyle(.white)
                        .position(x: cx + CGFloat(p.x) * size / 2, y: cy + CGFloat(p.y) * size / 2)
                        .animation(.easeOut(duration: 0.3), value: p.x)
                }
            }
        }
        .background(Color.black.opacity(0.02))
    }

    private func colorFor(_ p: EmbeddingPoint) -> Color {
        // Hue derived from position angle so nearby clusters read as color families.
        let angle = atan2(Double(p.y), Double(p.x))
        let hue = (angle + .pi) / (2 * .pi)
        return Color(hue: hue, saturation: 0.55, brightness: 0.75)
    }

    private func toggleAnimation() {
        if let t = timer { t.invalidate(); timer = nil; return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { _ in
            state.relaxEmbeddingMap()
            iterations += 1
            if iterations > 80 { timer?.invalidate(); timer = nil }
        }
    }
}
