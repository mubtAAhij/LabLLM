import Foundation
import SwiftUI

enum TutorialAction: String {
    case idle, sectionNav, welcomeOpened, modelPreset, corpusAdded, trainingStarted, sampleGenerated, chatOpened, fineTuneSourceAdded, fineTuneStarted
    case openSettingsForAdvanced, enableAdvanced, recipesOpened, modelsOpened, estimatorOpened, hardwareOpened
    case openSettingsForExpert, enableExpert, xrayOpened, embeddingsOpened, serverOpened, roadmapOpened
}

@MainActor
final class TutorialState: ObservableObject {
    enum StepKind {
        case visit
        case task
        case mode(AppMode)
    }

    private enum StorageKey {
        static let step = "labllm.tutorial.step"
        static let currentStepComplete = "labllm.tutorial.currentStepComplete"
        static let hasStarted = "labllm.tutorial.hasStarted"
    }

    @Published var isActive = false
    @Published private(set) var step: Int
    @Published private(set) var isCurrentStepComplete: Bool
    struct Step {
        let phase: String
        let title: String
        let message: String
        let section: NavSection
        let action: TutorialAction
        let kind: StepKind
        let checkpoint: String
    }
    let steps: [Step] = [
        .init(phase: String(
            localized: "tutorial-state.step.start.mode",
            defaultValue: "Start",
            comment: "Tutorial step mode label for beginning workflow"
        ), title: String(
            localized: "tutorial-state.step.start.title",
            defaultValue: "Enter the workspace",
            comment: "Tutorial step title for entering the main workspace"
        ), message: String(
            localized: "tutorial-state.step.start.description",
            defaultValue: "Begin at Welcome so the app starts from the real workflow, not a disconnected help screen.",
            comment: "Tutorial step guidance describing why onboarding starts from Welcome"
        ), section: .welcome, action: .welcomeOpened, kind: .visit, checkpoint: String(
            localized: "tutorial-state.step.start.completion",
            defaultValue: "Welcome page opened",
            comment: "Tutorial completion state text for opening the welcome page"
        )),
        .init(phase: String(
            localized: "tutorial-state.step.choose-model.mode.simple",
            defaultValue: "Simple",
            comment: "Tutorial step mode label for simple onboarding tier"
        ), title: String(
            localized: "tutorial-state.step.choose-model.title",
            defaultValue: "Choose a starting model",
            comment: "Tutorial step title for selecting a model profile"
        ), message: String(
            localized: "tutorial-state.step.choose-model.description",
            defaultValue: "Choose any profile that fits the experiment. Tiny is fast; larger profiles are for bigger datasets and more memory.",
            comment: "Tutorial step guidance for choosing model profile size"
        ), section: .model, action: .modelPreset, kind: .task, checkpoint: String(
            localized: "tutorial-state.step.choose-model.completion",
            defaultValue: "Model profile chosen",
            comment: "Tutorial completion state text for model profile selection"
        )),
        .init(phase: String(
            localized: "tutorial-state.step.install-corpus.mode.simple",
            defaultValue: "Simple",
            comment: "Tutorial step mode label for simple dataset install step"
        ), title: String(
            localized: "tutorial-state.step.install-corpus.title",
            defaultValue: "Install pre-training data",
            comment: "Tutorial step title for installing pre-training corpus"
        ), message: String(
            localized: "tutorial-state.step.install-corpus.description",
            defaultValue: "Search or choose a recommended corpus, inspect the dataset card, then install it. Installed data is written to disk and stays available next session.",
            comment: "Tutorial step guidance for dataset discovery and install persistence"
        ), section: .dataset, action: .corpusAdded, kind: .task, checkpoint: String(
            localized: "tutorial-state.step.install-corpus.completion",
            defaultValue: "Corpus installed",
            comment: "Tutorial completion state text for successful corpus installation"
        )),
        .init(phase: String(
            localized: "tutorial-state.step.start-pretraining.mode.simple",
            defaultValue: "Simple",
            comment: "Tutorial step mode label for pretraining start step"
        ), title: String(
            localized: "tutorial-state.step.start-pretraining.title",
            defaultValue: "Start pretraining",
            comment: "Tutorial step title for launching pretraining run"
        ), message: String(
            localized: "tutorial-state.step.start-pretraining.description",
            defaultValue: "Pick the corpora for this run in the training data panel, then start a small run. Simple mode builds the tokenizer when training begins.",
            comment: "Tutorial step guidance for selecting corpora and starting initial run"
        ), section: .training, action: .trainingStarted, kind: .task, checkpoint: String(
            localized: "tutorial-state.step.start-pretraining.completion",
            defaultValue: "Training started",
            comment: "Tutorial completion state text for started training run"
        )),
        .init(phase: String(
            localized: "tutorial-state.step.watch-learning.mode.simple",
            defaultValue: "Simple",
            comment: "Tutorial step mode label for monitoring learning step"
        ), title: String(
            localized: "tutorial-state.step.watch-learning.title",
            defaultValue: "Watch learning",
            comment: "Tutorial step title for observing training progress"
        ), message: String(
            localized: "tutorial-state.step.watch-learning.description",
            defaultValue: "Use the Training page to compare blue training loss against orange validation loss and review generated samples in the timeline.",
            comment: "Tutorial step guidance for reading training and validation signals"
        ), section: .training, action: .trainingStarted, kind: .visit, checkpoint: String(
            localized: "tutorial-state.step.watch-learning.completion",
            defaultValue: "Training dashboard reviewed",
            comment: "Tutorial completion state text for reviewing training dashboard"
        )),
        .init(phase: String(
            localized: "tutorial-state.step.generate-text.mode.simple",
            defaultValue: "Simple",
            comment: "Tutorial step mode label for simple text generation step"
        ), title: String(
            localized: "tutorial-state.step.generate-text.title",
            defaultValue: "Generate text",
            comment: "Tutorial step title for running text generation"
        ), message: String(
            localized: "tutorial-state.step.generate-text.description",
            defaultValue: "Open Sampling, adjust generation settings if needed, then generate or continue inside the prompt surface.",
            comment: "Tutorial step guidance for sampling and generation controls"
        ), section: .sampling, action: .sampleGenerated, kind: .task, checkpoint: String(
            localized: "tutorial-state.step.generate-text.completion",
            defaultValue: "Sample generated",
            comment: "Tutorial completion status after generating sample text"
        )),
        .init(phase: String(
            localized: "tutorial-state.step.try-local-chat.mode.simple",
            defaultValue: "Simple",
            comment: "Tutorial step mode label for local chat step in simple mode"
        ), title: String(
            localized: "tutorial-state.step.try-local-chat.title",
            defaultValue: "Try local chat",
            comment: "Tutorial step title encouraging user to try local chat"
        ), message: String(
            localized: "tutorial-state.step.try-local-chat.description",
            defaultValue: "Use Chat once a model or checkpoint is loaded. This keeps conversation testing in the same local project.",
            comment: "Tutorial step guidance explaining prerequisites and purpose of local chat"
        ), section: .chat, action: .chatOpened, kind: .visit, checkpoint: String(
            localized: "tutorial-state.step.try-local-chat.completion",
            defaultValue: "Chat opened",
            comment: "Tutorial completion status for opening chat"
        )),
        .init(phase: String(
            localized: "tutorial-state.step.install-finetuning-data.mode.simple",
            defaultValue: "Simple",
            comment: "Tutorial step mode label for fine-tuning data install step"
        ), title: String(
            localized: "tutorial-state.step.install-finetuning-data.title",
            defaultValue: "Install fine-tuning data",
            comment: "Tutorial step title for installing fine-tuning rows"
        ), message: String(
            localized: "tutorial-state.step.install-finetuning-data.description",
            defaultValue: "Browse instruction or conversation datasets, inspect the rendered README, then install compatible rows. You choose how much of each to use in Training.",
            comment: "Tutorial step guidance for selecting and installing compatible fine-tuning rows"
        ), section: .fineTuneData, action: .fineTuneSourceAdded, kind: .task, checkpoint: String(
            localized: "tutorial-state.step.install-finetuning-data.completion",
            defaultValue: "Fine-tuning rows installed",
            comment: "Tutorial completion status for fine-tuning row installation"
        )),
        .init(phase: String(
            localized: "tutorial-state.step.start-finetuning.mode.simple",
            defaultValue: "Simple",
            comment: "Tutorial step mode label for starting fine-tuning"
        ), title: String(
            localized: "tutorial-state.step.start-finetuning.title",
            defaultValue: "Start fine-tuning",
            comment: "Tutorial step title for launching fine-tuning run"
        ), message: String(
            localized: "tutorial-state.step.start-finetuning.description",
            defaultValue: "Return to Training, choose Fine-tune, and run a tiny SFT pass before scaling up.",
            comment: "Tutorial step guidance recommending a small SFT pass first"
        ), section: .training, action: .fineTuneStarted, kind: .task, checkpoint: String(
            localized: "tutorial-state.step.start-finetuning.completion",
            defaultValue: "Fine-tuning started",
            comment: "Tutorial completion status for started fine-tuning run"
        )),
        .init(phase: String(
            localized: "tutorial-state.step.open-settings.mode.advanced",
            defaultValue: "Advanced",
            comment: "Tutorial step mode label for advanced settings step"
        ), title: String(
            localized: "tutorial-state.step.open-settings.title",
            defaultValue: "Open Settings",
            comment: "Tutorial step title to open app settings"
        ), message: String(
            localized: "tutorial-state.step.open-settings.description",
            defaultValue: "Mode changes are explicit. Open Settings when you want additional controls; the guide will not switch modes by itself.",
            comment: "Tutorial step guidance explaining explicit mode changes via settings"
        ), section: .settings, action: .openSettingsForAdvanced, kind: .visit, checkpoint: String(
            localized: "tutorial-state.step.open-settings.completion",
            defaultValue: "Settings opened",
            comment: "Tutorial completion status for opening settings"
        )),
        .init(phase: String(
            localized: "tutorial-state.step.enable-advanced-mode.mode.advanced",
            defaultValue: "Advanced",
            comment: "Tutorial step mode label for enabling advanced mode"
        ), title: String(
            localized: "tutorial-state.step.enable-advanced-mode.title",
            defaultValue: "Enable Advanced mode",
            comment: "Tutorial step title for switching to advanced mode"
        ), message: String(
            localized: "tutorial-state.step.enable-advanced-mode.description",
            defaultValue: "Choose Advanced to reveal recipes, model management, hardware, and planning tools.",
            comment: "Tutorial step guidance describing what advanced mode unlocks"
        ), section: .settings, action: .enableAdvanced, kind: .mode(.advanced), checkpoint: String(
            localized: "tutorial-state.step.enable-advanced-mode.completion",
            defaultValue: "Advanced mode enabled",
            comment: "Tutorial completion status after enabling advanced mode"
        )),
        .init(phase: String(
            localized: "tutorial-state.step.use-recipe.mode.advanced",
            defaultValue: "Advanced",
            comment: "Tutorial step mode label for recipe usage step"
        ), title: String(
            localized: "tutorial-state.step.use-recipe.title",
            defaultValue: "Use a recipe",
            comment: "Tutorial step title for applying a recipe"
        ), message: String(
            localized: "tutorial-state.step.use-recipe.description",
            defaultValue: "Open Recipes to apply a focused configuration before a run.",
            comment: "Tutorial step guidance for using recipe-driven configuration"
        ), section: .recipes, action: .recipesOpened, kind: .visit, checkpoint: String(
            localized: "tutorial-state.step.use-recipe.completion",
            defaultValue: "Recipes opened",
            comment: "Tutorial completion status after opening recipes"
        )),
        .init(phase: String(
            localized: "tutorial-state.step.manage-checkpoints.mode.advanced",
            defaultValue: "Advanced",
            comment: "Tutorial step mode label for checkpoint management step"
        ), title: String(
            localized: "tutorial-state.step.manage-checkpoints.title",
            defaultValue: "Manage checkpoints",
            comment: "Tutorial step title for checkpoint management"
        ), message: String(
            localized: "tutorial-state.step.manage-checkpoints.description",
            defaultValue: "Open Checkpoints to load, continue, or organize the saved runs that belong to the model selected in the top-left box.",
            comment: "Tutorial step guidance for working with model-specific checkpoints"
        ), section: .checkpoints, action: .modelsOpened, kind: .visit, checkpoint: String(
            localized: "tutorial-state.step.manage-checkpoints.completion",
            defaultValue: "Checkpoints opened",
            comment: "Tutorial completion status after opening checkpoints"
        )),
        .init(phase: String(
            localized: "tutorial-state.step.estimate-resources.mode.advanced",
            defaultValue: "Advanced",
            comment: "Tutorial step mode label for resource estimation step"
        ), title: String(
            localized: "tutorial-state.step.estimate-resources.title",
            defaultValue: "Estimate resources",
            comment: "Tutorial step title for opening resource estimator"
        ), message: String(
            localized: "tutorial-state.step.estimate-resources.description",
            defaultValue: "Open Estimator before a bigger experiment to check memory, disk, token budget, and rough time.",
            comment: "Tutorial step guidance for pre-run resource planning"
        ), section: .estimator, action: .estimatorOpened, kind: .visit, checkpoint: String(
            localized: "tutorial-state.step.estimate-resources.completion",
            defaultValue: "Estimator opened",
            comment: "Tutorial completion status after opening estimator"
        )),
        .init(phase: String(
            localized: "tutorial-state.step.check-hardware.mode.advanced",
            defaultValue: "Advanced",
            comment: "Tutorial step mode label for hardware check step"
        ), title: String(
            localized: "tutorial-state.step.check-hardware.title",
            defaultValue: "Check hardware",
            comment: "Tutorial step title for reviewing hardware information"
        ), message: String(
            localized: "tutorial-state.step.check-hardware.description",
            defaultValue: "Open Hardware to compare your Apple Silicon and memory against recommended model sizes.",
            comment: "Tutorial step guidance for validating hardware against model recommendations"
        ), section: .hardware, action: .hardwareOpened, kind: .visit, checkpoint: String(
            localized: "tutorial-state.step.check-hardware.completion",
            defaultValue: "Hardware opened",
            comment: "Tutorial completion status after opening hardware view"
        )),
        .init(phase: String(
            localized: "tutorial-state.step.return-to-settings.mode.expert",
            defaultValue: "Expert",
            comment: "Tutorial step mode label for expert-mode settings return step"
        ), title: String(
            localized: "tutorial-state.step.return-to-settings.title",
            defaultValue: "Return to Settings",
            comment: "Tutorial step title for returning to app settings"
        ), message: String(
            localized: "tutorial-state.step.return-to-settings.description",
            defaultValue: "Expert mode reveals analysis, serving, and deeper inspection tools. Switch only when you want the full surface area.",
            comment: "Tutorial step guidance describing expert mode scope before switching"
        ), section: .settings, action: .openSettingsForExpert, kind: .visit, checkpoint: String(
            localized: "tutorial-state.step.return-to-settings.completion",
            defaultValue: "Settings reopened",
            comment: "Tutorial completion status for reopening settings"
        )),
        .init(phase: String(
            localized: "tutorial-state.step.enable-expert-mode.mode.expert",
            defaultValue: "Expert",
            comment: "Tutorial step mode label for enabling expert mode"
        ), title: String(
            localized: "tutorial-state.step.enable-expert-mode.title",
            defaultValue: "Enable Expert mode",
            comment: "Tutorial step title for switching app into expert mode"
        ), message: String(
            localized: "tutorial-state.step.enable-expert-mode.description",
            defaultValue: "Choose Expert to unlock X-Ray, embeddings, local serving, and the full roadmap.",
            comment: "Tutorial step guidance listing capabilities unlocked in expert mode"
        ), section: .settings, action: .enableExpert, kind: .mode(.expert), checkpoint: String(
            localized: "tutorial-state.step.enable-expert-mode.completion",
            defaultValue: "Expert mode enabled",
            comment: "Tutorial completion status for enabling expert mode"
        )),
        .init(phase: String(
            localized: "tutorial-state.step.inspect-generation.mode.expert",
            defaultValue: "Expert",
            comment: "Tutorial step mode label for generation inspection step"
        ), title: String(
            localized: "tutorial-state.step.inspect-generation.title",
            defaultValue: "Inspect generation",
            comment: "Tutorial step title for inspecting generated output details"
        ), message: String(
            localized: "tutorial-state.step.inspect-generation.description",
            defaultValue: "Open X-Ray to review token probabilities, entropy, and sampling decisions.",
            comment: "Tutorial step guidance for using X-Ray token analysis"
        ), section: .xray, action: .xrayOpened, kind: .visit, checkpoint: String(
            localized: "tutorial-state.step.inspect-generation.completion",
            defaultValue: "X-Ray opened",
            comment: "Tutorial completion status for opening X-Ray view"
        )),
        .init(phase: String(
            localized: "tutorial-state.step.explore-embeddings.mode.expert",
            defaultValue: "Expert",
            comment: "Tutorial step mode label for embeddings exploration step"
        ), title: String(
            localized: "tutorial-state.step.explore-embeddings.title",
            defaultValue: "Explore embeddings",
            comment: "Tutorial step title for embeddings exploration"
        ), message: String(
            localized: "tutorial-state.step.explore-embeddings.description",
            defaultValue: "Open Embeddings to inspect the learned token space and similarity structure.",
            comment: "Tutorial step guidance for exploring embedding space and similarity"
        ), section: .embeddings, action: .embeddingsOpened, kind: .visit, checkpoint: String(
            localized: "tutorial-state.step.explore-embeddings.completion",
            defaultValue: "Embeddings opened",
            comment: "Tutorial completion status for opening embeddings view"
        )),
        .init(phase: String(
            localized: "tutorial-state.step.serve-locally.mode.expert",
            defaultValue: "Expert",
            comment: "Tutorial step mode label for local serving step"
        ), title: String(
            localized: "tutorial-state.step.serve-locally.title",
            defaultValue: "Serve locally",
            comment: "Tutorial step title for exposing local model server"
        ), message: String(
            localized: "tutorial-state.step.serve-locally.description",
            defaultValue: "Open Local Server to expose a loaded model through the local API and streaming endpoint.",
            comment: "Tutorial step guidance for enabling local serving endpoints"
        ), section: .server, action: .serverOpened, kind: .visit, checkpoint: String(
            localized: "tutorial-state.step.serve-locally.completion",
            defaultValue: "Local server opened",
            comment: "Tutorial completion status for opening local server view"
        )),
        .init(phase: String(
            localized: "tutorial-state.step.finish.mode.finish",
            defaultValue: "Finish",
            comment: "Tutorial step mode label for final wrap-up step"
        ), title: String(
            localized: "tutorial-state.step.finish.title.review-roadmap",
            defaultValue: "Review the roadmap",
            comment: "Tutorial step title for reviewing product roadmap"
        ), message: String(
            localized: "tutorial-state.step.finish.description.open-roadmap-status-overview",
            defaultValue: "Open Roadmap to see what is built, what is in progress, and what is planned next.",
            comment: "Tutorial step description explaining roadmap status categories"
        ), section: .roadmap, action: .roadmapOpened, kind: .visit, checkpoint: String(
            localized: "tutorial-state.step.finish.completion.roadmap-opened",
            defaultValue: "Roadmap opened",
            comment: "Tutorial completion text after opening roadmap"
        ))
    ]
    init() {
        let storedStep = UserDefaults.standard.integer(forKey: StorageKey.step)
        step = min(max(0, storedStep), steps.count - 1)
        isCurrentStepComplete = UserDefaults.standard.bool(forKey: StorageKey.currentStepComplete)
    }

    var current: Step? { steps.indices.contains(step) ? steps[step] : nil }
    var progress: Double { Double(step + (isCurrentStepComplete ? 1 : 0)) / Double(steps.count) }
    var completedCount: Int { step + (isCurrentStepComplete ? 1 : 0) }

    /// Resume the guide without moving the user or replacing their current work.
    func resume() {
        isActive = true
        UserDefaults.standard.set(true, forKey: StorageKey.hasStarted)
    }

    /// Used only by the explicit Replay Tutorial commands.
    func restart() {
        step = 0
        isCurrentStepComplete = false
        isActive = true
        persistProgress()
    }

    func complete(_ action: TutorialAction) {
        guard current?.action == action else { return }
        isCurrentStepComplete = true
        persistProgress()
    }

    func navigationTarget(for section: NavSection) -> TutorialAction? {
        current?.section == section ? .sectionNav : nil
    }

    func noteNavigation(to section: NavSection) {
        guard let current, current.section == section else { return }
        switch current.kind {
        case .visit:
            complete(current.action)
        case .task, .mode:
            persistProgress()
        }
    }

    func modeAction(for mode: AppMode) -> TutorialAction? {
        guard let current else { return nil }
        switch current.kind {
        case .mode(let required) where required == mode:
            return current.action
        default: return nil
        }
    }

    func goToCurrentSection() {
        guard let current else { return }
        NotificationCenter.default.post(name: .navigateToSection, object: current.section.rawValue)
        noteNavigation(to: current.section)
    }

    func targetAction(from available: [TutorialAction: Anchor<CGRect>]) -> TutorialAction? {
        guard let current else { return nil }
        if available[current.action] != nil { return current.action }
        if available[.sectionNav] != nil { return .sectionNav }
        return nil
    }

    func advance() {
        guard isCurrentStepComplete else { return }
        if step == steps.count - 1 {
            isActive = false
        } else {
            step += 1
            isCurrentStepComplete = false
            persistProgress()
        }
    }

    func back() {
        guard step > 0 else { return }
        step -= 1
        isCurrentStepComplete = true
        persistProgress()
    }

    func skipStep() {
        isCurrentStepComplete = true
        advance()
    }

    func dismiss() { isActive = false }

    private func persistProgress() {
        UserDefaults.standard.set(step, forKey: StorageKey.step)
        UserDefaults.standard.set(isCurrentStepComplete, forKey: StorageKey.currentStepComplete)
        UserDefaults.standard.set(true, forKey: StorageKey.hasStarted)
    }
}

struct TutorialTargetKey: PreferenceKey {
    static var defaultValue: [TutorialAction: Anchor<CGRect>] = [:]
    static func reduce(value: inout [TutorialAction: Anchor<CGRect>], nextValue: () -> [TutorialAction: Anchor<CGRect>]) { value.merge(nextValue(), uniquingKeysWith: { $1 }) }
}

extension View {
    func tutorialTarget(_ action: TutorialAction) -> some View {
        anchorPreference(key: TutorialTargetKey.self, value: .bounds) { [action: $0] }
    }
}

struct TutorialHighlightOverlay: View {
    let highlight: CGRect?

    var body: some View {
        GeometryReader { proxy in
            if let highlight {
                let target = highlight
                    .insetBy(dx: -10, dy: -10)
                    .intersection(CGRect(origin: .zero, size: proxy.size))

                // `highlight` is the target's preference anchor resolved into this
                // overlay's coordinate space. No sidebar or window-size constants.
                ZStack {
                    Color.black.opacity(0.32)
                    RoundedRectangle(cornerRadius: WorkbenchTheme.cornerRadius, style: .continuous)
                        .frame(width: target.width, height: target.height)
                        .position(x: target.midX, y: target.midY)
                        .blendMode(.destinationOut)
                }
                .compositingGroup()
                RoundedRectangle(cornerRadius: WorkbenchTheme.cornerRadius, style: .continuous)
                    .strokeBorder(WorkbenchTheme.accent, lineWidth: 2)
                    .frame(width: target.width, height: target.height)
                    .position(x: target.midX, y: target.midY)
            }
        }
    }
}

struct TutorialCoachCard: View {
    @ObservedObject var state: TutorialState

    var body: some View {
        if let step = state.current {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(step.phase.uppercased()).font(.caption.weight(.bold)).foregroundStyle(WorkbenchTheme.accent)
                    Spacer()
                    Text(String(format: String(
                        localized: "tutorial-state.progress.percent",
                        defaultValue: "%d%%",
                        comment: "Tutorial progress percentage label"
                    ), Int((state.progress * 100).rounded()))).font(.caption.monospacedDigit().weight(.bold)).foregroundStyle(.secondary)
                    Button { state.dismiss() } label: { Image(systemName: "xmark") }.buttonStyle(.plain).help(String(
                        localized: "tutorial-state.action.exit-tutorial",
                        defaultValue: "Exit tutorial",
                        comment: "Button label to exit tutorial flow"
                    ))
                }
                ProgressView(value: state.progress).tint(WorkbenchTheme.accent)
                HStack(spacing: 8) {
                    Text(String(format: String(
                        localized: "tutorial-state.progress.step-of-total",
                        defaultValue: "Step %d of %d",
                        comment: "Progress label showing current tutorial step and total steps"
                    ), state.step + 1, state.steps.count)).font(.caption).foregroundStyle(.secondary)
                    Text(step.section.rawValue).font(.caption.weight(.semibold)).foregroundStyle(WorkbenchTheme.accent)
                }
                Text(step.title).font(.title3.bold())
                Text(step.message).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Button {
                        state.goToCurrentSection()
                    } label: {
                        Label(String(format: String(
                            localized: "tutorial-state.action.go-to-section",
                            defaultValue: "Go to %@",
                            comment: "Button label to navigate to the tutorial target section"
                        ), "\(step.section.rawValue)"), systemImage: "arrow.turn.down.right")
                    }
                    .buttonStyle(WorkbenchSecondaryButtonStyle())
                    Spacer()
                }
                miniMap
                HStack {
                    Image(systemName: state.isCurrentStepComplete ? "checkmark.circle.fill" : "cursorarrow.click")
                        .foregroundStyle(state.isCurrentStepComplete ? WorkbenchTheme.success : WorkbenchTheme.accent)
                    Text(state.isCurrentStepComplete ? String(format: String(
                        localized: "tutorial-state.checkpoint.ready-message",
                        defaultValue: "%@. Continue when you are ready.",
                        comment: "Message shown when checkpoint condition is satisfied"
                    ), "\(step.checkpoint)") : String(format: String(
                        localized: "tutorial-state.checkpoint.waiting-message",
                        defaultValue: "Waiting for: %@.",
                        comment: "Message shown while waiting for checkpoint condition"
                    ), "\(step.checkpoint)"))
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    if state.step > 0 {
                        Button(String(
                            localized: "tutorial-state.navigation.back",
                            defaultValue: "Back",
                            comment: "Tutorial navigation button to go to previous step"
                        )) { state.back() }.buttonStyle(WorkbenchSecondaryButtonStyle())
                    }
                    if state.isCurrentStepComplete {
                        Button(String(
                            localized: "tutorial-state.navigation.next",
                            defaultValue: "Next",
                            comment: "Tutorial navigation button to go to next step"
                        )) { state.advance() }.buttonStyle(WorkbenchPrimaryButtonStyle())
                    } else {
                        Button(String(
                            localized: "tutorial-state.navigation.skip",
                            defaultValue: "Skip",
                            comment: "Tutorial navigation button to skip current step"
                        )) { state.skipStep() }.buttonStyle(WorkbenchSecondaryButtonStyle())
                    }
                }
            }
            .padding(18).frame(width: 380, alignment: .leading)
            .background(WorkbenchTheme.elevatedPanel, in: RoundedRectangle(cornerRadius: WorkbenchTheme.cornerRadius, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: WorkbenchTheme.cornerRadius, style: .continuous).strokeBorder(WorkbenchTheme.accent.opacity(0.35)) }
        }
    }

    private var miniMap: some View {
        HStack(spacing: 5) {
            ForEach(state.steps.indices, id: \.self) { index in
                let completed = index < state.step || (index == state.step && state.isCurrentStepComplete)
                let current = index == state.step
                Image(systemName: completed ? "checkmark.circle.fill" : (current ? "clock.fill" : "circle"))
                    .font(.caption2)
                    .foregroundStyle(completed ? WorkbenchTheme.success : (current ? WorkbenchTheme.accent : Color.secondary.opacity(0.55)))
            }
        }
        .accessibilityLabel(String(format: String(
            localized: "tutorial-state.progress.completed-steps-summary",
            defaultValue: "%d of %d tutorial steps complete",
            comment: "Summary text of completed tutorial steps"
        ), state.completedCount, state.steps.count))
    }
}
