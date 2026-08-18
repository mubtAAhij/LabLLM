import SwiftUI

struct ModelBuilderView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var tutorial: TutorialState

    private let presets: [(String, GPTConfig)] = [
        (String(
            localized: "model-builder.profile.tiny",
            defaultValue: "Tiny",
            comment: "Profile name for tiny starter architecture"
        ),   GPTConfig(blockSize: 64,  nEmbd: 128, nLayers: 4,  nHeads: 4)),
        (String(
            localized: "model-builder.profile.small",
            defaultValue: "Small",
            comment: "Profile name for small starter architecture"
        ),  GPTConfig(blockSize: 128, nEmbd: 256, nLayers: 6,  nHeads: 8)),
        (String(
            localized: "model-builder.profile.medium",
            defaultValue: "Medium",
            comment: "Profile name for medium starter architecture"
        ), GPTConfig(blockSize: 256, nEmbd: 512, nLayers: 8,  nHeads: 8)),
        (String(
            localized: "model-builder.profile.large",
            defaultValue: "Large",
            comment: "Profile name for large starter architecture"
        ),  GPTConfig(blockSize: 512, nEmbd: 768, nLayers: 12, nHeads: 12)),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                WorkbenchPageHeader(eyebrow: String(
                    localized: "model-builder.header.section",
                    defaultValue: "Architecture",
                    comment: "Section label in model builder header"
                ), title: String(
                    localized: "model-builder.header.title",
                    defaultValue: "Model Builder",
                    comment: "Title for model builder page"
                ), subtitle: String(
                    localized: "model-builder.header.subtitle",
                    defaultValue: "Shape the decoder that will learn from your corpus. Estimates update as you work.",
                    comment: "Subtitle describing model builder behavior"
                ), icon: "cube.transparent")

                GroupBox(String(
                    localized: "model-builder.actions.start-from-profile",
                    defaultValue: "Start from a profile",
                    comment: "Label for selecting a starter architecture profile"
                )) {
                    HStack(spacing: 10) {
                        ForEach(presets, id: \.0) { name, cfg in
                            Button(name) {
                                var c = cfg
                                c.vocabSize = state.gptConfig.vocabSize
                                state.gptConfig = c
                                tutorial.complete(.modelPreset)
                            }.buttonStyle(WorkbenchSecondaryButtonStyle()).controlSize(.large)
                        }
                    }.padding(6)
                }
                .tutorialTarget(.modelPreset)

                GroupBox(String(
                    localized: "model-builder.section.architecture",
                    defaultValue: "Architecture",
                    comment: "Section title for architecture controls"
                )) {
                    VStack(spacing: 14) {
                        stepper(String(
                            localized: "model-builder.field.context-length",
                            defaultValue: "Context length",
                            comment: "Field label for context length"
                        ), $state.gptConfig.blockSize, 16...2048, step: 16)
                        stepper(String(
                            localized: "model-builder.field.hidden-dimension",
                            defaultValue: "Hidden dimension",
                            comment: "Field label for hidden dimension"
                        ), $state.gptConfig.nEmbd, 32...2048, step: 32)
                        stepper(String(
                            localized: "model-builder.field.layers",
                            defaultValue: "Layers",
                            comment: "Field label for layer count"
                        ), $state.gptConfig.nLayers, 1...48, step: 1)
                        stepper(String(
                            localized: "model-builder.field.attention-heads",
                            defaultValue: "Attention heads",
                            comment: "Field label for attention heads"
                        ), $state.gptConfig.nHeads, 1...32, step: 1)
                        stepper(String(
                            localized: "model-builder.field.mlp-ratio",
                            defaultValue: "MLP ratio",
                            comment: "Field label for MLP ratio"
                        ), $state.gptConfig.mlpRatio, 1...8, step: 1)
                        Toggle(String(
                            localized: "model-builder.field.tie-embedding-output-weights",
                            defaultValue: "Tie embedding & output weights",
                            comment: "Toggle label for tying embedding and output weights"
                        ), isOn: $state.gptConfig.tieWeights)
                    }.padding(8)
                }

                estimatesPanel
                validationPanel
            }
            .padding(WorkbenchTheme.pagePadding)
        }
    }

    private var estimatesPanel: some View {
        GroupBox(String(
            localized: "model-builder.estimate.live-estimate",
            defaultValue: "Live estimate",
            comment: "Title for live architecture estimate panel"
        )) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                WorkbenchMetric(label: String(
                    localized: "model-builder.estimate.parameters",
                    defaultValue: "Parameters",
                    comment: "Label for estimated parameter count"
                ), value: format(state.gptConfig.estimatedParameters), icon: "cpu")
                WorkbenchMetric(label: String(
                    localized: "model-builder.estimate.vocabulary",
                    defaultValue: "Vocabulary",
                    comment: "Label for vocabulary size estimate"
                ), value: "\(state.gptConfig.vocabSize)", icon: "textformat")
                WorkbenchMetric(label: String(
                    localized: "model-builder.estimate.head-dimension",
                    defaultValue: "Head dimension",
                    comment: "Label for computed head dimension"
                ), value: "\(state.gptConfig.nHeads == 0 ? 0 : state.gptConfig.nEmbd / state.gptConfig.nHeads)", icon: "circle.grid.cross")
                let bytes = state.gptConfig.estimatedParameters * 4
                WorkbenchMetric(label: String(
                    localized: "model-builder.estimate.fp32-weights",
                    defaultValue: "FP32 weights",
                    comment: "Label for FP32 model weight memory estimate"
                ), value: "\(format(bytes / 1_048_576)) MB", icon: "internaldrive")
            }
        }
    }

    @ViewBuilder private var validationPanel: some View {
        let errors = state.gptConfig.validationErrors
        if errors.isEmpty {
            Label(String(
                localized: "model-builder.validation.configuration-valid",
                defaultValue: "Configuration valid",
                comment: "Validation status text when model configuration is valid"
            ), systemImage: "checkmark.seal.fill")
                .foregroundStyle(.green)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(errors, id: \.self) { e in
                    Label(e, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange).font(.callout)
                }
            }
        }
    }

    private func stepper(_ label: String, _ value: Binding<Int>, _ range: ClosedRange<Int>, step: Int) -> some View {
        HStack {
            Text(label).frame(width: 160, alignment: .leading)
            Slider(value: Binding(get: { Double(value.wrappedValue) },
                                  set: { value.wrappedValue = Int($0) }),
                   in: Double(range.lowerBound)...Double(range.upperBound), step: Double(step))
            Text(String(format: String(
                localized: "model-builder.architecture.value-display",
                defaultValue: "%@",
                comment: "Displayed architecture control value text"
            ), "\(value.wrappedValue)")).monospacedDigit().frame(width: 60, alignment: .trailing)
        }
    }

    private func format(_ n: Int) -> String {
        let f = NumberFormatter(); f.numberStyle = .decimal
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}
