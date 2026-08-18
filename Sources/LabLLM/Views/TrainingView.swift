import SwiftUI
import Charts

struct TrainingView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var library: DatasetLibrary
    @EnvironmentObject var trainer: Trainer
    @EnvironmentObject var prefs: Preferences
    @EnvironmentObject var tutorial: TutorialState
    @State private var mode: RunMode = .pretrain
    @State private var useLoRA = true
    @State private var resumeFrom: URL?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                WorkbenchPageHeader(eyebrow: String(
                    localized: "training-view.run-studio.title",
                    defaultValue: "Run Studio",
                    comment: "Primary section title for training run workspace"
                ), title: String(
                    localized: "training-view.training.title",
                    defaultValue: "Training",
                    comment: "Main title label for training view"
                ), subtitle: String(
                    localized: "training-view.training.subtitle",
                    defaultValue: "Configure the run, watch learning happen, and compare training against validation loss.",
                    comment: "Subtitle describing training workflow and metrics comparison"
                ), icon: "waveform.path.ecg")
                HStack(spacing: 12) {
                    Picker("", selection: $mode) {
                        ForEach(RunMode.allCases) { Text($0.label).tag($0) }
                    }.pickerStyle(.segmented).frame(maxWidth: 420)
                    Spacer()
                    // Recipes are reachable from the page where runs actually start.
                    Menu {
                        ForEach(Recipe.all.filter { $0.mode == mode }) { recipe in
                            Button(String(format: String(
                                localized: "training-view.recipe.name-time-tag",
                                defaultValue: "%@ · %@",
                                comment: "Label combining recipe name with estimated time tag"
                            ), "\(recipe.name)", "\(recipe.timeTag)")) { state.run(recipe, inNewModel: false) }
                        }
                        Divider()
                        Button(String(
                            localized: "training-view.action.open-recipes",
                            defaultValue: "Open Recipes…",
                            comment: "Button title to open recipes picker"
                        )) {
                            NotificationCenter.default.post(name: .navigateToSection, object: NavSection.recipes.rawValue)
                        }
                    } label: { Label(String(
                        localized: "training-view.start-from-recipe.title",
                        defaultValue: "Start from a recipe",
                        comment: "Section heading encouraging recipe-based run setup"
                    ), systemImage: "wand.and.stars") }
                        .menuStyle(.borderlessButton).frame(width: 190)
                        .disabled(trainer.isTraining)
                }

                if let err = trainer.errorMessage {
                    Label(err, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange).padding(10)
                        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: WorkbenchTheme.cornerRadius))
                }
                modeTip
                restoredSessionPanel
                trainingDataPanel
                controlsPanel
                runProgressPanel
                metricsPanel
                chartPanel
                sampleTimeline
            }
            .padding(WorkbenchTheme.pagePadding)
        }
        .onAppear {
            // Open on the mode whose saved run is showing, so a relaunch lands on
            // the dashboard the user left behind.
            if !trainer.isTraining { mode = trainer.runMode }
            applyPendingContinuation()
        }
        .onChange(of: mode) { newMode in state.showSession(for: newMode) }
        .onReceive(NotificationCenter.default.publisher(for: .prepareTrainingContinuation)) { note in
            mode = note.object as? String == "sft" ? .sft : .pretrain
            applyPendingContinuation()
        }
    }

    @ViewBuilder private var modeTip: some View {
        switch mode {
        case .pretrain:
            if prefs.mode == .simple && prefs.showTips {
                tip(String(
                    localized: "training-view.pretraining.guidance",
                    defaultValue: "Choose the corpora this run trains on above, then press Start. Watch the loss fall — lower is better. A checkpoint saves periodically and again when the run finishes or is stopped.",
                    comment: "Guidance text for pretraining setup and checkpoint behavior"
                ))
            }
        case .sft:
            tip(String(
                localized: "training-view.finetune.guidance",
                defaultValue: "Fine-tuning continues from your pretrained (or resumed) model and trains only on the assistant's replies. LoRA trains a small adapter instead of the whole model — faster and swappable.",
                comment: "Guidance text for fine-tuning and LoRA behavior"
            ))
        case .dpo:
            tip(String(
                localized: "training-view.dpo.guidance",
                defaultValue: "DPO needs a fine-tuned model already in memory (run Fine-tune first, or resume from an SFT checkpoint). It nudges the model toward the 'chosen' replies and away from 'rejected' ones.",
                comment: "Guidance text for DPO prerequisites and optimization direction"
            ))
        }
    }

    private func tip(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lightbulb").foregroundStyle(.yellow)
            Text(text).font(.callout).foregroundStyle(.secondary)
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.yellow.opacity(0.10), in: RoundedRectangle(cornerRadius: WorkbenchTheme.cornerRadius, style: .continuous))
    }


    /// Shown when the metrics on screen come from a saved run rather than a live
    /// one, with a one-click way back into that run's checkpoint.
    @ViewBuilder private var restoredSessionPanel: some View {
        if !trainer.isTraining, let session = state.session(for: mode), session.step > 0 {
            HStack(spacing: 12) {
                Image(systemName: "clock.arrow.circlepath").foregroundStyle(WorkbenchTheme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(format: String(
                        localized: "training-view.session.restored-summary",
                        defaultValue: "Restored session · %@",
                        comment: "Status text showing restored training session summary"
                    ), "\(session.summary)")).font(.callout.weight(.medium))
                    let savedAt = session.updatedAt.formatted(date: .abbreviated, time: .shortened)
                    let datasetSuffix = session.datasetName.map { datasetName in
                        String(format: String(
                            localized: "training-view.session.dataset-suffix",
                            defaultValue: "· %@",
                            comment: "Optional suffix showing dataset name in restored session status"
                        ), datasetName)
                    } ?? ""
                    Text(String(format: String(
                        localized: "training-view.session.saved-at-with-dataset-optional",
                        defaultValue: "Saved %@%@",
                        comment: "Status text showing saved timestamp and optional dataset name"
                    ), savedAt, datasetSuffix))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if let url = session.lastCheckpointURL, FileManager.default.fileExists(atPath: url.path) {
                    Button(trainer.hasModel ? String(
                        localized: "training-view.action.reload-checkpoint",
                        defaultValue: "Reload checkpoint",
                        comment: "Button title to reload checkpoint from saved run"
                    ) : String(
                        localized: "training-view.action.load-model-from-run",
                        defaultValue: "Load model from this run",
                        comment: "Button subtitle or help text for loading model from selected run"
                    )) {
                        if let meta = try? Checkpoint.loadMeta(from: url) { state.loadCheckpoint(url, meta: meta) }
                    }.buttonStyle(WorkbenchSecondaryButtonStyle())
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(WorkbenchTheme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: WorkbenchTheme.cornerRadius, style: .continuous))
        }
    }

    // MARK: - Training data

    /// Dataset selection and mixing live with the run, not with the dataset
    /// browsers: the browsers install data, this panel decides what a run uses.
    @ViewBuilder private var trainingDataPanel: some View {
        switch mode {
        case .pretrain: mixPanel(kind: .corpus)
        case .sft: mixPanel(kind: .fineTune)
        case .dpo:
            GroupBox(String(
                localized: "training-view.training-data.title",
                defaultValue: "Training data",
                comment: "Section title for training data selection"
            )) {
                Text(String(
                    localized: "training-view.training-data.dpo-note",
                    defaultValue: "DPO reuses the preference pairs loaded for the current model. Run fine-tuning first, or resume from an SFT checkpoint.",
                    comment: "Note explaining DPO data source and prerequisite"
                ))
                    .font(.callout).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(8)
            }
        }
    }

    private func mixPanel(kind: InstalledDataset.Kind) -> some View {
        let mix = kind == .corpus ? state.corpusMix : state.fineTuneMix
        let installed = library.datasets(of: kind)
        let unused = installed.filter { dataset in !mix.contains { $0.datasetID == dataset.id } }
        return GroupBox(kind == .corpus ? String(
            localized: "training-view.training-data.pretraining-corpora",
            defaultValue: "Training data · pre-training corpora",
            comment: "Label for pretraining corpus mix section"
        ) : String(
            localized: "training-view.training-data.finetuning-datasets",
            defaultValue: "Training data · fine-tuning datasets",
            comment: "Label for fine-tuning dataset mix section"
        )) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(kind == .corpus ? state.corpusName : state.sftDatasetName)
                            .font(.headline)
                        Text(mixSummary(kind: kind)).font(.caption).foregroundStyle(.secondary).monospacedDigit()
                    }
                    Spacer()
                    if state.isLoadingMix { ProgressView().controlSize(.small) }
                    Menu {
                        if unused.isEmpty {
                            Text(String(
                                localized: "training-view.training-data.everything-installed-in-mix",
                                defaultValue: "Everything installed is already in this mix",
                                comment: "Informational text when all installed datasets are already included"
                            ))
                        } else {
                            ForEach(unused) { dataset in
                                Button(String(format: String(
                                    localized: "training-view.dataset.name-summary",
                                    defaultValue: "%@ · %@",
                                    comment: "Dataset row text combining dataset name and summary"
                                ), "\(dataset.name)", "\(dataset.summary)")) { state.addToMix(dataset) }
                            }
                        }
                    } label: { Label(String(
                        localized: "training-view.training-data.action.add-dataset",
                        defaultValue: "Add dataset",
                        comment: "Button title to add an installed dataset to current run mix"
                    ), systemImage: "plus") }
                        .menuStyle(.borderlessButton).frame(width: 130)
                    Button(String(
                        localized: "training-view.training-data.action.install-more",
                        defaultValue: "Install more…",
                        comment: "Button title to open dataset installation flow"
                    )) {
                        NotificationCenter.default.post(name: .navigateToSection,
                                                        object: kind == .corpus ? NavSection.dataset.rawValue : NavSection.fineTuneData.rawValue)
                    }.buttonStyle(WorkbenchSecondaryButtonStyle())
                }

                if mix.isEmpty {
                    Text(installed.isEmpty
                         ? String(format: String(
                             localized: "training-view.training-data.empty.none-installed-message",
                             defaultValue: "No %@ data is installed yet. Install a dataset and it stays on disk for future sessions.",
                             comment: "Empty-state message when no datasets of current kind are installed"
                         ), (kind == .corpus ? String(
                             localized: "training-view.training-data.kind.pre-training",
                             defaultValue: "pre-training",
                             comment: "Dataset kind label for corpus pre-training data"
                         ) : String(
                             localized: "training-view.training-data.kind.fine-tuning",
                             defaultValue: "fine-tuning",
                             comment: "Dataset kind label for fine-tuning data"
                         )))
                         : String(
                             localized: "training-view.training-data.empty.none-selected-message",
                             defaultValue: "Nothing selected for this run yet. Add one or more installed datasets to build the mix.",
                             comment: "Empty-state message when installed datasets exist but none are selected for run"
                         ))
                        .font(.callout).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(mix) { selection in
                        if let dataset = library.dataset(selection.datasetID) {
                            DatasetMixRow(dataset: dataset,
                                          selection: selection,
                                          onToggle: { state.setMixEnabled($0, for: dataset.id, kind: kind) },
                                          onMode: { state.setMixLimitMode($0, for: dataset.id, kind: kind) },
                                          onPercent: { state.setMixPercent($0, for: dataset.id, kind: kind) },
                                          onLines: { state.setMixLineLimit($0, for: dataset.id, kind: kind) },
                                          onRemove: { state.removeFromMix(dataset.id, kind: kind) })
                        }
                    }
                }
            }.padding(8)
        }
    }

    private func mixSummary(kind: InstalledDataset.Kind) -> String {
        switch kind {
        case .corpus:
            let suffix = state.isCorpusLoaded ? String(
                localized: "training-view.training-data.source.loaded",
                defaultValue: "loaded",
                comment: "Short status token indicating data already loaded in memory"
            ) : String(
                localized: "training-view.training-data.source.read-at-start",
                defaultValue: "read when the run starts",
                comment: "Short status token indicating data will be read on run start"
            )
            return String(format: String(
                localized: "training-view.training-data.summary.corpus-characters",
                defaultValue: "%@ characters · %@",
                comment: "Corpus summary showing character count and loading status suffix"
            ), "\(state.corpusCharCount.formatted())", "\(suffix)")
        case .fineTune:
            let suffix = state.isFineTuneDataLoaded ? String(
                localized: "training-view.training-data.source.loaded-alt",
                defaultValue: "loaded",
                comment: "Short status token indicating fine-tuning rows already loaded in memory"
            ) : String(
                localized: "training-view.training-data.source.read-at-start-alt",
                defaultValue: "read when the run starts",
                comment: "Short status token indicating fine-tuning rows will be read at run start"
            )
            return String(format: String(
                localized: "training-view.training-data.summary.sft-rows-pairs",
                defaultValue: "%@ rows · %@ pairs · %@",
                comment: "Fine-tuning summary showing row count pair count and loading status suffix"
            ), "\(state.sftRowCount.formatted())", "\(state.sftPairCount.formatted())", "\(suffix)")
        }
    }

    private var controlsPanel: some View {
        GroupBox(String(
            localized: "training-view.hyperparameters.title",
            defaultValue: "Hyperparameters",
            comment: "Section title for editable training hyperparameters"
        )) {
            VStack(spacing: 12) {
                if mode == .sft {
                    Toggle(String(
                        localized: "training-view.hyperparameters.use-lora-label",
                        defaultValue: "Use LoRA (train a small adapter instead of full fine-tuning)",
                        comment: "Toggle label describing LoRA fine-tuning mode"
                    ), isOn: $useLoRA)
                }
                if prefs.mode != .simple {
                    HStack {
                        Text(String(
                            localized: "training-view.hyperparameters.optimizer",
                            defaultValue: "Optimizer",
                            comment: "Label for optimizer selection control"
                        )).font(.caption).foregroundStyle(.secondary)
                        Picker("", selection: $state.trainConfig.optimizer) {
                            ForEach(OptimizerKind.allCases) { Text($0.label).tag($0) }
                        }.pickerStyle(.segmented).frame(width: 200)
                        Spacer()
                        resumeMenu
                    }
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                    intField(String(
                        localized: "training-view.hyperparameters.batch-size",
                        defaultValue: "Batch size",
                        comment: "Label for batch size control"
                    ), $state.trainConfig.batchSize)
                    intField(String(
                        localized: "training-view.hyperparameters.max-steps",
                        defaultValue: "Max steps",
                        comment: "Label for maximum training step count control"
                    ), $state.trainConfig.maxSteps)
                    floatField(String(
                        localized: "training-view.hyperparameters.learning-rate",
                        defaultValue: "Learning rate",
                        comment: "Label for learning rate control"
                    ), $state.trainConfig.learningRate)
                    intField(String(
                        localized: "training-view.hyperparameters.warmup-steps",
                        defaultValue: "Warmup steps",
                        comment: "Label for warmup step count control"
                    ), $state.trainConfig.warmupSteps)
                    if prefs.mode != .simple {
                        intField(String(
                            localized: "training-view.hyperparameters.grad-accum",
                            defaultValue: "Grad accum",
                            comment: "Label for gradient accumulation steps control"
                        ), $state.trainConfig.gradAccumSteps)
                        floatField(String(
                            localized: "training-view.hyperparameters.weight-decay",
                            defaultValue: "Weight decay",
                            comment: "Label for weight decay hyperparameter control"
                        ), $state.trainConfig.weightDecay)
                        floatField(String(
                            localized: "training-view.hyperparameters.grad-clip",
                            defaultValue: "Grad clip",
                            comment: "Label for gradient clipping hyperparameter control"
                        ), $state.trainConfig.gradClip)
                        intField(String(
                            localized: "training.checkpoint.interval.label",
                            defaultValue: "Checkpoint every",
                            comment: "Label for checkpoint interval control in training view"
                        ), $state.trainConfig.checkpointEvery)
                    }
                    if mode == .pretrain && prefs.mode != .simple { intField(String(
                        localized: "training-view.hyperparameters.eval-every",
                        defaultValue: "Eval every",
                        comment: "Label for evaluation interval control"
                    ), $state.trainConfig.evalEvery) }
                    if mode == .sft && useLoRA && prefs.mode == .expert {
                        intField(String(
                            localized: "training-view.hyperparameters.lora-rank",
                            defaultValue: "LoRA rank",
                            comment: "Label for LoRA rank hyperparameter control"
                        ), $state.trainConfig.loraRank)
                        floatField(String(
                            localized: "training-view.hyperparameters.lora-alpha",
                            defaultValue: "LoRA alpha",
                            comment: "Label for LoRA alpha hyperparameter control"
                        ), $state.trainConfig.loraAlpha)
                    }
                    if mode == .dpo { floatField(String(
                        localized: "training-view.hyperparameters.dpo-beta",
                        defaultValue: "DPO beta",
                        comment: "Label for DPO beta hyperparameter control"
                    ), $state.trainConfig.dpoBeta) }
                    if prefs.mode == .expert { intField(String(
                        localized: "training-view.hyperparameters.sample-every",
                        defaultValue: "Sample every",
                        comment: "Label for sample generation interval control"
                    ), $state.trainConfig.sampleEvery) }
                }
                HStack(spacing: 12) {
                    if !trainer.isTraining {
                        Button(action: startTapped) {
                            Label(startLabel, systemImage: "play.fill")
                        }
                        .buttonStyle(WorkbenchPrimaryButtonStyle())
                        .disabled(startDisabled)
                        .tutorialTarget(mode == .sft ? .fineTuneStarted : .trainingStarted)
                    } else {
                        if trainer.isPaused {
                            Button { trainer.resume() } label: { Label(String(
                                localized: "training-view.action.resume",
                                defaultValue: "Resume",
                                comment: "Button title to resume a paused training run"
                            ), systemImage: "play.fill") }
                                .buttonStyle(WorkbenchPrimaryButtonStyle())
                        } else {
                            Button { trainer.pause() } label: { Label(String(
                                localized: "training-view.action.pause",
                                defaultValue: "Pause",
                                comment: "Button title to pause an active training run"
                            ), systemImage: "pause.fill") }
                                .buttonStyle(WorkbenchSecondaryButtonStyle())
                        }
                        Button(role: .destructive) { trainer.stop() } label: {
                            Label(String(
                                localized: "training-view.action.stop-saves-progress",
                                defaultValue: "Stop (saves progress)",
                                comment: "Button title to stop training while saving progress"
                            ), systemImage: "stop.fill")
                        }.buttonStyle(WorkbenchSecondaryButtonStyle())
                    }
                    Spacer()
                    Text(trainer.statusMessage).foregroundStyle(.secondary).font(.callout)
                }
            }.padding(8)
        }
    }

    private var resumeMenu: some View {
        Menu {
            Button(String(
                localized: "training-view.action.start-fresh",
                defaultValue: "Start fresh",
                comment: "Button title to begin a new training run from scratch"
            )) { resumeFrom = nil }
            Divider()
            ForEach(Checkpoint.list(), id: \.self) { url in
                Button(url.lastPathComponent) { resumeFrom = url }
            }
        } label: {
            Label(resumeFrom?.lastPathComponent ?? String(
                localized: "training-view.action.resume-from-checkpoint",
                defaultValue: "Resume from checkpoint…",
                comment: "Button title to resume training from selected checkpoint"
            ), systemImage: "arrow.uturn.backward")
        }.menuStyle(.borderlessButton).frame(maxWidth: 260)
    }

    private var startDisabled: Bool {
        switch mode {
        case .pretrain: return !state.gptConfig.validationErrors.isEmpty || !state.hasCorpus
        case .sft: return !state.hasFineTuneData
        case .dpo: return false
        }
    }

    private var startLabel: String {
        switch mode {
        case .pretrain: return String(
            localized: "training-view.action.start-training",
            defaultValue: "Start training",
            comment: "Primary action label to start pretraining run"
        )
        case .sft: return String(
            localized: "training-view.action.start-fine-tuning",
            defaultValue: "Start fine-tuning",
            comment: "Primary action label to start fine-tuning run"
        )
        case .dpo: return String(
            localized: "training-view.action.start-dpo",
            defaultValue: "Start DPO",
            comment: "Primary action label to start DPO run"
        )
        }
    }

    private func startTapped() {
        if mode == .pretrain { tutorial.complete(.trainingStarted) }
        if mode == .sft { tutorial.complete(.fineTuneStarted) }
        switch mode {
        case .pretrain: state.startTraining(resumeFrom: resumeFrom)
        case .sft: state.startSFT(useLoRA: useLoRA, resumeFrom: resumeFrom)
        case .dpo: state.startDPO()
        }
    }

    private func applyPendingContinuation() {
        guard let request = state.pendingContinuation else { return }
        resumeFrom = request.url
        state.gptConfig = request.meta.config
        state.tokenizer = request.meta.tokenizer
    }

    private var metricsPanel: some View {
        GroupBox {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                WorkbenchMetric(label: String(
                    localized: "training-view.metrics.step-label",
                    defaultValue: "Step",
                    comment: "Metric label for current training step"
                ), value: String(format: String(
                    localized: "training-view.metrics.step-progress",
                    defaultValue: "%d/%d",
                    comment: "Metric value showing current step out of maximum steps"
                ), trainer.step, trainer.maxSteps))
                WorkbenchMetric(label: String(
                    localized: "training-view.metrics.progress-label",
                    defaultValue: "Progress",
                    comment: "Metric label for overall training progress"
                ), value: String(format: String(
                    localized: "training-view.metrics.progress-percent",
                    defaultValue: "%d%%",
                    comment: "Metric value showing rounded training progress percentage"
                ), Int((trainer.progress * 100).rounded())), tone: WorkbenchTheme.accent)
                WorkbenchMetric(label: String(
                    localized: "training.metrics.train-loss",
                    defaultValue: "Train loss",
                    comment: "Training metrics label for training loss value"
                ), value: String(format: "%.3f", trainer.trainLoss), tone: WorkbenchTheme.accent)
                WorkbenchMetric(label: String(
                    localized: "training.metrics.validation-loss-short",
                    defaultValue: "Val loss",
                    comment: "Training metrics label for validation loss short form"
                ), value: trainer.valLoss > 0 ? String(format: "%.3f", trainer.valLoss) : "—", tone: WorkbenchTheme.validation)
                WorkbenchMetric(label: String(
                    localized: "training.metrics.perplexity",
                    defaultValue: "Perplexity",
                    comment: "Training metrics label for perplexity value"
                ), value: trainer.trainLoss > 0 ? String(format: "%.1f", exp(trainer.trainLoss)) : "—")
                WorkbenchMetric(label: String(
                    localized: "training.metrics.tokens-per-second",
                    defaultValue: "Tokens / sec",
                    comment: "Training metrics label for token throughput per second"
                ), value: String(format: "%.0f", trainer.tokensPerSec))
                WorkbenchMetric(label: String(
                    localized: "training.hyperparameters.learning-rate",
                    defaultValue: "Learning rate",
                    comment: "Training metrics label for current learning rate"
                ), value: String(format: "%.2e", trainer.currentLR))
                WorkbenchMetric(label: String(
                    localized: "training.metrics.eta",
                    defaultValue: "ETA",
                    comment: "Training metrics label for estimated time remaining"
                ), value: formatETA(trainer.etaSeconds))
                if trainer.runIsLoRA { WorkbenchMetric(label: String(
                    localized: "training.metrics.mode",
                    defaultValue: "Training mode",
                    comment: "Training metrics label for active training mode"
                ), value: String(
                    localized: "training.mode.lora",
                    defaultValue: "LoRA",
                    comment: "Training mode value indicating LoRA adapter training"
                ), tone: WorkbenchTheme.accent) }
            }
        }
    }

    @ViewBuilder private var runProgressPanel: some View {
        if trainer.isTraining || trainer.step > 0 {
            GroupBox(String(
                localized: "training.progress.title",
                defaultValue: "Run progress",
                comment: "Section title for training run progress"
            )) {
                VStack(alignment: .leading, spacing: 8) {
                    ProgressView(value: trainer.progress)
                        .tint(WorkbenchTheme.accent)
                    HStack {
                        Text(String(format: String(
                            localized: "training.progress.percent-complete",
                            defaultValue: "%d%% complete",
                            comment: "Run progress text showing rounded percent complete"
                        ), Int((trainer.progress * 100).rounded())))
                            .font(.callout.weight(.semibold)).monospacedDigit()
                        Spacer()
                        Text(String(format: String(
                            localized: "training.progress.step-of-total",
                            defaultValue: "Step %@ of %@",
                            comment: "Run progress text showing current step and maximum steps"
                        ), "\(trainer.step.formatted())", "\(trainer.maxSteps.formatted())"))
                            .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }
                }
                .padding(8)
            }
        }
    }

    private var chartPanel: some View {
        GroupBox(String(
            localized: "training.charts.loss.title",
            defaultValue: "Loss",
            comment: "Section title for loss chart"
        )) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 16) {
                    Label(String(
                        localized: "training.charts.loss.series.training",
                        defaultValue: "Training loss",
                        comment: "Legend label for training loss series"
                    ), systemImage: "line.diagonal").foregroundStyle(.tint)
                    Label(String(
                        localized: "training.charts.loss.series.validation",
                        defaultValue: "Validation loss",
                        comment: "Legend label for validation loss series"
                    ), systemImage: "line.diagonal").foregroundStyle(WorkbenchTheme.validation)
                }.font(.caption)
                Chart {
                    ForEach(trainer.lossHistory.filter { $0.kind == .train }) { point in
                        LineMark(x: .value(String(
                            localized: "training.charts.loss.table.column.step",
                            defaultValue: "Step",
                            comment: "Loss table column header for training step"
                        ), point.step), y: .value(String(
                            localized: "training.charts.loss.table.column.loss",
                            defaultValue: "Loss",
                            comment: "Loss table column header for loss value"
                        ), point.value), series: .value(String(
                            localized: "training.charts.loss.table.column.series",
                            defaultValue: "Series",
                            comment: "Loss table column header for series name"
                        ), String(
                            localized: "training.charts.loss.series.training-short",
                            defaultValue: "Training",
                            comment: "Loss table value for training series"
                        )))
                            .foregroundStyle(WorkbenchTheme.accent)
                            .interpolationMethod(.linear)
                    }
                    ForEach(trainer.lossHistory.filter { $0.kind == .val }) { point in
                        LineMark(x: .value("Step", point.step), y: .value("Loss", point.value), series: .value("Series", "Validation"))
                            .foregroundStyle(WorkbenchTheme.validation)
                            .interpolationMethod(.linear)
                    }
                }
                .frame(height: 236)
            }
            .padding(8)
        }
    }

    @ViewBuilder private var sampleTimeline: some View {
        if !trainer.sampleHistory.isEmpty {
            GroupBox(String(
                localized: "training.samples.timeline.title",
                defaultValue: "Sample timeline",
                comment: "Section title for sampled output timeline"
            )) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(trainer.sampleHistory.reversed()) { sample in
                        HStack(alignment: .top, spacing: 12) {
                            VStack(spacing: 3) {
                                Circle().fill(Color.accentColor).frame(width: 8, height: 8)
                                Rectangle().fill(Color.secondary.opacity(0.25)).frame(width: 1, height: 42)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text(String(format: String(
                                    localized: "training.samples.timeline.step-and-method",
                                    defaultValue: "Step %d · %@",
                                    comment: "Sample timeline row text with step number and sampling method"
                                ), sample.step, "\(sample.method)")).font(.caption.bold()).foregroundStyle(.secondary)
                                Text(sample.text).font(.callout.monospaced()).textSelection(.enabled)
                            }
                        }
                    }
                }.padding(8)
            }
        }
    }

    private func intField(_ label: String, _ value: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            TextField(label, value: value, format: .number).textFieldStyle(.roundedBorder)
        }
    }
    private func floatField(_ label: String, _ value: Binding<Float>) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            TextField(label, value: value, format: .number).textFieldStyle(.roundedBorder)
        }
    }
    private func formatETA(_ s: Double) -> String {
        guard s > 0, s.isFinite else { return "—" }
        let m = Int(s) / 60, sec = Int(s) % 60
        return m > 0 ? String(format: String(
            localized: "training.duration.minutes-seconds-short",
            defaultValue: "%dm %ds",
            comment: "Short duration label showing minutes and seconds"
        ), m, sec) : String(format: String(
            localized: "training.duration.seconds-short",
            defaultValue: "%ds",
            comment: "Short duration label showing seconds"
        ), sec)
    }
}


/// One installed dataset's share of a run. Percentage and row limits are committed
/// when the control is released so dragging a slider doesn't re-read files on every
/// intermediate value.
private struct DatasetMixRow: View {
    let dataset: InstalledDataset
    let selection: DatasetSelection
    let onToggle: (Bool) -> Void
    let onMode: (DatasetLimitMode) -> Void
    let onPercent: (Double) -> Void
    let onLines: (Int) -> Void
    let onRemove: () -> Void

    @State private var draftPercent: Double = 100

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Toggle(dataset.name, isOn: Binding(get: { selection.isEnabled }, set: onToggle))
                    .toggleStyle(.checkbox)
                Spacer()
                Text(selectedSummary).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                Button(role: .destructive) { onRemove() } label: { Image(systemName: "minus.circle") }
                    .buttonStyle(.plain).help(String(
                        localized: "training.dataset.remove-from-mix",
                        defaultValue: "Remove from this model's mix (keeps it installed)",
                        comment: "Button title to remove a dataset from current model mix while keeping installation"
                    ))
            }
            Text(dataset.origin).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            Picker(String(
                localized: "training.dataset.selection.title",
                defaultValue: "Selection",
                comment: "Section title for dataset selection details"
            ), selection: Binding(get: { selection.limitMode }, set: onMode)) {
                ForEach(DatasetLimitMode.allCases) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented).labelsHidden()
            if selection.limitMode == .percent {
                HStack {
                    Slider(value: $draftPercent, in: 1...100, step: 1) { editing in
                        if !editing { onPercent(draftPercent) }
                    }
                    Text(String(format: String(
                        localized: "training.dataset.selection.percent",
                        defaultValue: "%d%%",
                        comment: "Selected percentage label in dataset selection"
                    ), Int(draftPercent))).font(.caption.monospacedDigit()).frame(width: 42)
                }
            } else {
                Stepper(String(format: String(
                    localized: "training.dataset.selection.limit",
                    defaultValue: "%@ %@",
                    comment: "Selection limit with numeric value and unit"
                ), "\(selection.lineLimit.formatted())", (dataset.kind == .corpus ? String(
                    localized: "training.dataset.selection.unit.lines",
                    defaultValue: "lines",
                    comment: "Unit label for corpus line-based selection limit"
                ) : String(
                    localized: "training.dataset.selection.unit.rows",
                    defaultValue: "rows",
                    comment: "Unit label for row-based selection limit"
                ))),
                        value: Binding(get: { selection.lineLimit }, set: onLines),
                        in: 1...max(1, dataset.rows))
            }
        }
        .padding(10)
        .opacity(selection.isEnabled ? 1 : 0.55)
        .background(WorkbenchTheme.elevatedPanel, in: RoundedRectangle(cornerRadius: WorkbenchTheme.cornerRadius, style: .continuous))
        .onAppear { draftPercent = selection.percent }
        .onChange(of: selection.percent) { draftPercent = $0 }
    }

    private var selectedSummary: String {
        switch dataset.kind {
        case .corpus:
            return String(format: String(
                localized: "training.dataset.selection.characters-summary",
                defaultValue: "%@ of %@ characters",
                comment: "Summary showing selected and total character counts"
            ), "\(selection.selectedCharacters(in: dataset).formatted())", "\(dataset.characters.formatted())")
        case .fineTune:
            return String(format: String(
                localized: "training.dataset.selection.rows-pairs-summary",
                defaultValue: "%@ of %@ rows · %@ pairs",
                comment: "Summary showing selected and total rows plus selected pair count"
            ), "\(selection.selectedRows(in: dataset).formatted())", "\(dataset.rows.formatted())", "\(selection.selectedPairs(in: dataset).formatted())")
        }
    }
}
