import SwiftUI

struct EstimatorView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        let cfg = state.gptConfig
        let tc = state.trainConfig
        let params = cfg.estimatedParameters

        // Rough memory: weights + AdamW state (2x) + gradients (1x), fp32 (~16 B/param),
        // plus a crude activation term.
        let optimizerBytes = params * 16
        let activationBytes = tc.batchSize * cfg.blockSize * cfg.nEmbd * cfg.nLayers * 4 * 4
        let totalMemMB = Double(optimizerBytes + activationBytes) / 1_048_576.0

        let tokensPerStep = tc.batchSize * cfg.blockSize
        let totalTokens = tokensPerStep * tc.maxSteps

        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                WorkbenchPageHeader(eyebrow: String(localized: "estimator.header.analyze", defaultValue: "Analyze", comment: "Section badge title for estimator view"), title: String(localized: "estimator.header.title", defaultValue: "Resource Estimator", comment: "Main title of estimator screen"), subtitle: String(localized: "estimator.header.subtitle", defaultValue: "A practical read on memory, weights, and token volume before committing to a run.", comment: "Subtitle explaining estimator purpose"), icon: "function")

                GroupBox(String(localized: "estimator.model.section", defaultValue: "Model", comment: "Model section heading")) {
                    grid {
                        cell(String(localized: "estimator.model.parameters", defaultValue: "Parameters", comment: "Estimated parameter count label"), format(params))
                        cell(String(localized: "estimator.model.weights-fp32", defaultValue: "Weights (fp32)", comment: "FP32 weights size label"), "\(format(params * 4 / 1_048_576)) MB")
                        cell(String(localized: "estimator.model.weights-fp16", defaultValue: "Weights (fp16)", comment: "FP16 weights size label"), "\(format(params * 2 / 1_048_576)) MB")
                        cell(String(localized: "estimator.model.head-dim", defaultValue: "Head dim", comment: "Attention head dimension label"), "\(cfg.nHeads == 0 ? 0 : cfg.nEmbd / cfg.nHeads)")
                    }
                }

                GroupBox(String(localized: "estimator.training-memory.section", defaultValue: "Training memory (rough)", comment: "Training memory section heading")) {
                    grid {
                        cell(String(localized: "estimator.training-memory.optimizer-state", defaultValue: "Optimizer state", comment: "Optimizer state memory label"), "\(format(optimizerBytes / 1_048_576)) MB")
                        cell(String(localized: "estimator.training-memory.activations", defaultValue: "Activations", comment: "Activation memory label"), "\(format(activationBytes / 1_048_576)) MB")
                        cell(String(localized: "estimator.training-memory.peak-estimate", defaultValue: "Peak (est.)", comment: "Peak estimated memory label"), "\(format(Int(totalMemMB))) MB")
                        cell(String(localized: "estimator.training-memory.unified-ram", defaultValue: "Unified RAM", comment: "Unified RAM label"), String(format: "%.0f GB", state.hardware.physicalMemoryGB))
                    }
                }

                GroupBox(String(localized: "estimator.data.section", defaultValue: "Data", comment: "Data section heading")) {
                    grid {
                        cell(String(localized: "estimator.data.tokens-per-step", defaultValue: "Tokens / step", comment: "Tokens per step label"), format(tokensPerStep))
                        cell(String(localized: "estimator.data.total-tokens", defaultValue: "Total tokens", comment: "Total token count label"), format(totalTokens))
                        cell(String(localized: "estimator.data.steps", defaultValue: "Steps", comment: "Training steps label"), format(tc.maxSteps))
                        // Only measurable once the selected mix has been read off disk;
                        // otherwise fall back to the character estimate from metadata.
                        cell(String(localized: "estimator.data.corpus-tokens", defaultValue: "Corpus tokens", comment: "Corpus token count label"), corpusTokenEstimate)
                    }
                }

                let fits = totalMemMB < (state.hardware.physicalMemoryGB - 3) * 1024
                Label(fits ? String(localized: "estimator.memory-fit.good", defaultValue: "Should fit comfortably in unified memory.", comment: "Message indicating memory requirements are safe") :
                             String(localized: "estimator.memory-fit.warning", defaultValue: "Peak memory may approach your RAM — reduce batch size, context, or model size.", comment: "Warning when estimated peak memory is high"),
                      systemImage: fits ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(fits ? .green : .orange)

                Text(String(localized: "estimator.disclaimer.order-of-magnitude", defaultValue: "These are order-of-magnitude estimates, not measurements. Real usage depends on MLX's lazy allocation, precision, and graph fusion.", comment: "Disclaimer about estimate accuracy in estimator view"))
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(WorkbenchTheme.pagePadding)
        }
    }

    private var corpusTokenEstimate: String {
        if state.isCorpusLoaded, let tokenizer = state.tokenizer {
            return format(tokenizer.encode(state.corpus).count)
        }
        guard state.hasCorpus else { return "—" }
        return "≈ \(format(state.corpusCharCount))"
    }

    private func grid<C: View>(@ViewBuilder _ c: () -> C) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: 4), spacing: 14, content: c)
            .padding(8)
    }
    private func cell(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.title3.bold()).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }
    private func format(_ n: Int) -> String {
        let f = NumberFormatter(); f.numberStyle = .decimal
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}
