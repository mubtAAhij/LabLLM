import SwiftUI

struct SamplingView: View {
    @EnvironmentObject var trainer: Trainer
    @EnvironmentObject var tutorial: TutorialState

    @State private var prompt = "the "
    @State private var maxTokens: Double = 200
    @State private var temperature: Double = 0.8
    @State private var topK: Double = 0
    @State private var topP: Double = 1.0
    @State private var minP: Double = 0.0
    @State private var repPenalty: Double = 1.0
    @State private var greedy = false
    @State private var seedText = ""
    @State private var stopText = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                WorkbenchPageHeader(eyebrow: String(
                    localized: "sampling.header.section",
                    defaultValue: "Playground",
                    comment: "Section eyebrow label for sampling playground"
                ), title: String(
                    localized: "sampling.header.title",
                    defaultValue: "Sampling",
                    comment: "Main title for sampling view"
                ), subtitle: String(
                    localized: "sampling.header.subtitle",
                    defaultValue: "Steer the loaded model and watch its continuation emerge token by token.",
                    comment: "Subtitle explaining sampling behavior"
                ), icon: "text.cursor")

                if !trainer.hasModel {
                    WorkbenchEmptyState(icon: "text.cursor", title: String(
                        localized: "sampling.empty.no-model.title",
                        defaultValue: "No model in memory",
                        comment: "Empty state title when no model is loaded"
                    ), message: String(
                        localized: "sampling.empty.no-model.message",
                        defaultValue: "Train a model or load a checkpoint, then return here to generate.",
                        comment: "Empty state message guiding user to load or train model"
                    ))
                } else {
                    GroupBox(String(
                        localized: "sampling.prompt.label",
                        defaultValue: "Prompt",
                        comment: "Label for prompt input field"
                    )) {
                        promptSurface
                    }

                    GroupBox(String(
                        localized: "sampling.decoding.section-title",
                        defaultValue: "Decoding",
                        comment: "Section title for decoding controls"
                    )) {
                        VStack(spacing: 12) {
                            slider(String(
                                localized: "sampling.decoding.max-tokens",
                                defaultValue: "Max tokens",
                                comment: "Label for maximum generated token count"
                            ), $maxTokens, 16...1000, step: 8, fmt: "%.0f")
                            Toggle(String(
                                localized: "sampling.decoding.greedy-argmax",
                                defaultValue: "Greedy (argmax)",
                                comment: "Toggle label for greedy decoding mode"
                            ), isOn: $greedy)
                            if !greedy {
                                slider(String(
                                    localized: "sampling.decoding.temperature",
                                    defaultValue: "Temperature",
                                    comment: "Label for temperature parameter"
                                ), $temperature, 0.1...2.0, step: 0.05, fmt: "%.2f")
                                slider(String(
                                    localized: "sampling.decoding.top-k",
                                    defaultValue: "Top-k (0 = off)",
                                    comment: "Label for top-k sampling parameter"
                                ), $topK, 0...200, step: 1, fmt: "%.0f")
                                slider(String(
                                    localized: "sampling.decoding.top-p",
                                    defaultValue: "Top-p (1 = off)",
                                    comment: "Label for top-p sampling parameter"
                                ), $topP, 0.1...1.0, step: 0.01, fmt: "%.2f")
                                slider(String(
                                    localized: "sampling.decoding.min-p",
                                    defaultValue: "Min-p (0 = off)",
                                    comment: "Label for min-p sampling parameter"
                                ), $minP, 0.0...0.5, step: 0.01, fmt: "%.2f")
                                slider(String(
                                    localized: "sampling.decoding.repetition-penalty",
                                    defaultValue: "Repetition penalty",
                                    comment: "Label for repetition penalty parameter"
                                ), $repPenalty, 1.0...2.0, step: 0.05, fmt: "%.2f")
                                HStack {
                                    Text(String(
                                        localized: "sampling.decoding.seed",
                                        defaultValue: "Seed",
                                        comment: "Label for random seed setting"
                                    )).frame(width: 160, alignment: .leading)
                                    TextField(String(
                                        localized: "sampling.decoding.seed-random",
                                        defaultValue: "random",
                                        comment: "Text indicating random seed mode"
                                    ), text: $seedText).textFieldStyle(.roundedBorder).frame(width: 160)
                                    Spacer()
                                }
                                HStack {
                                    Text(String(
                                        localized: "sampling.decoding.stop-sequences",
                                        defaultValue: "Stop sequences",
                                        comment: "Label for stop sequence configuration"
                                    )).frame(width: 160, alignment: .leading)
                                    TextField(String(
                                        localized: "sampling.decoding.stop-sequences-placeholder",
                                        defaultValue: "comma,separated",
                                        comment: "Placeholder text for comma-separated stop sequences input"
                                    ), text: $stopText).textFieldStyle(.roundedBorder)
                                }
                            }
                        }.padding(8)
                    }

                    HStack {
                        Button {
                            trainer.sample(prompt: prompt, params: params())
                            tutorial.complete(.sampleGenerated)
                        } label: {
                            Label(trainer.isSampling ? String(
                                localized: "sampling.actions.generating",
                                defaultValue: "Generating…",
                                comment: "Button label while generation is in progress"
                            ) : String(
                                localized: "sampling.actions.generate",
                                defaultValue: "Generate",
                                comment: "Button label to start text generation"
                            ), systemImage: "sparkles")
                        }
                        .buttonStyle(WorkbenchPrimaryButtonStyle())
                        .disabled(trainer.isSampling)
                        .tutorialTarget(.sampleGenerated)
                        Button {
                            trainer.continueSample(params: params())
                        } label: {
                            Label(String(
                                localized: "sampling.actions.continue",
                                defaultValue: "Continue",
                                comment: "Button title to continue generation"
                            ), systemImage: "arrow.right")
                        }
                        .disabled(trainer.isSampling || trainer.sampleOutput.isEmpty)
                    }

                }
            }
            .padding(WorkbenchTheme.pagePadding)
        }
    }

    private func params() -> SamplingParams {
        let stops = stopText.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        return SamplingParams(
            maxTokens: Int(maxTokens),
            temperature: Float(temperature),
            topK: Int(topK),
            topP: Float(topP),
            minP: Float(minP),
            repetitionPenalty: Float(repPenalty),
            greedy: greedy,
            seed: UInt64(seedText),
            stopSequences: stops)
    }

    private var continuation: String {
        guard trainer.sampleOutput.hasPrefix(prompt) else { return trainer.sampleOutput }
        return String(trainer.sampleOutput.dropFirst(prompt.count))
    }

    @ViewBuilder private var promptSurface: some View {
        if trainer.sampleOutput.isEmpty {
            TextEditor(text: $prompt)
                .font(.callout.monospaced())
                .frame(height: 80)
                .padding(4)
        } else {
            HStack(alignment: .top, spacing: 10) {
                ScrollView {
                    (Text(prompt).foregroundStyle(.primary) + Text(continuation).foregroundStyle(.blue))
                        .font(.callout.monospaced())
                        .frame(maxWidth: .infinity, minHeight: 80, alignment: .topLeading)
                        .textSelection(.enabled)
                }
                Button {
                    prompt = trainer.sampleOutput
                    trainer.sampleOutput = ""
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.plain)
                .help(String(
                    localized: "sampling.actions.edit-prompt",
                    defaultValue: "Edit prompt",
                    comment: "Button title to edit sampling prompt"
                ))
            }
            .padding(4)
            .frame(height: 88)
        }
    }

    private func slider(_ label: String, _ value: Binding<Double>, _ range: ClosedRange<Double>, step: Double, fmt: String) -> some View {
        HStack {
            Text(label).frame(width: 160, alignment: .leading)
            Slider(value: value, in: range, step: step)
            Text(String(format: fmt, value.wrappedValue)).monospacedDigit().frame(width: 60, alignment: .trailing)
        }
    }
}
