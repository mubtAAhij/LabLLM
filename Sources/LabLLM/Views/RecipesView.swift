import SwiftUI

/// Recipes as a launcher, not a gallery of presets. Picking one shows exactly what
/// it will do — the architecture, the hyperparameters, the dataset it needs and
/// whether that data is already installed — and starting it sets all of that up
/// and drops you on the Training page ready to run.
struct RecipesView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var library: DatasetLibrary
    @EnvironmentObject var models: ModelStore
    @EnvironmentObject var trainer: Trainer

    @State private var selected: Recipe = Recipe.all[0]

    var body: some View {
        VStack(spacing: 0) {
            WorkbenchPageHeader(eyebrow: String(
                localized: "recipes.header.section",
                defaultValue: "Build",
                comment: "Section label for recipe builder area"
            ), title: String(
                localized: "recipes.header.title",
                defaultValue: "Recipes",
                comment: "Main title for recipes screen"
            ),
                                subtitle: String(
                                    localized: "recipes.header.subtitle",
                                    defaultValue: "Complete runs you can start in one click: model, hyperparameters, tokenizer and the data they need.",
                                    comment: "Subtitle describing recipe quick-start capability"
                                ),
                                icon: "wand.and.stars")
                .padding(.horizontal, WorkbenchTheme.pagePadding).padding(.top, 22).padding(.bottom, 14)
            GeometryReader { proxy in
                let listWidth = min(320, max(230, proxy.size.width * 0.32))
                HStack(spacing: 0) {
                    recipeList.frame(width: listWidth).frame(maxHeight: .infinity)
                    Divider()
                    detail.frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - List

    private var recipeList: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(Recipe.all) { recipe in
                    row(recipe)
                        .contentShape(Rectangle())
                        .onTapGesture { selected = recipe }
                }
            }
            .padding(12)
        }
        .background(WorkbenchTheme.panel)
    }

    private func row(_ recipe: Recipe) -> some View {
        let isSelected = recipe.id == selected.id
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: recipe.icon)
                .foregroundStyle(isSelected ? Color.white : WorkbenchTheme.accent)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 3) {
                Text(recipe.name)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.white : Color.primary)
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    Text(recipe.mode.label)
                    Text("·")
                    Text(recipe.timeTag)
                }
                .font(.caption2.monospacedDigit())
                .foregroundStyle(isSelected ? Color.white.opacity(0.85) : Color.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10).padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? WorkbenchTheme.accent : Color.clear,
                    in: RoundedRectangle(cornerRadius: WorkbenchTheme.cornerRadius, style: .continuous))
    }

    // MARK: - Detail

    private var detail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                if let status = state.recipeStatus {
                    Label(status, systemImage: "sparkles")
                        .font(.callout).foregroundStyle(WorkbenchTheme.accent)
                        .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                        .background(WorkbenchTheme.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: WorkbenchTheme.cornerRadius, style: .continuous))
                }
                watchPanel
                dataPanel
                configPanel
                prerequisitePanel
            }
            .padding(WorkbenchTheme.pagePadding)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: selected.icon).font(.title).foregroundStyle(WorkbenchTheme.accent)
                VStack(alignment: .leading, spacing: 4) {
                    Text(selected.name).font(.title2.bold())
                    Text(selected.summary).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            HStack(spacing: 8) {
                WorkbenchPill(text: selected.mode.label)
                WorkbenchPill(text: selected.shapeTag)
                WorkbenchPill(text: selected.contextTag)
                WorkbenchPill(text: selected.stepsTag)
                WorkbenchPill(text: selected.timeTag)
            }
            HStack(spacing: 10) {
                Button(String(format: String(
                    localized: "recipes.actions.setup-in-active-model",
                    defaultValue: "Set up in %@",
                    comment: "Action title to apply recipe in current active model"
                ), "\(models.activeName)")) { state.run(selected, inNewModel: false) }
                    .buttonStyle(WorkbenchPrimaryButtonStyle())
                Button(String(
                    localized: "recipes.actions.setup-in-new-model",
                    defaultValue: "Set up in a new model",
                    comment: "Action title to apply recipe in a newly created model"
                )) { state.run(selected, inNewModel: true) }
                    .buttonStyle(WorkbenchSecondaryButtonStyle())
                Spacer()
            }
            Text(String(format: String(
                localized: "recipes.help.apply-replaces-and-opens-training",
                defaultValue: "Applying a recipe replaces this model's hyperparameters and its %@ mix, then opens Training.",
                comment: "Help text explaining what applying a recipe will overwrite"
            ), (selected.data.kind == .corpus ? String(
                localized: "recipes.data-kind.pre-training",
                defaultValue: "pre-training",
                comment: "Data kind label used in recipe apply explanation"
            ) : String(
                localized: "recipes.data-kind.fine-tuning",
                defaultValue: "fine-tuning",
                comment: "Data kind label used in recipe apply explanation"
            ))))
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var watchPanel: some View {
        GroupBox(String(
            localized: "recipes.section.what-to-watch",
            defaultValue: "What to watch",
            comment: "Section title for key monitoring notes"
        )) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "eye").foregroundStyle(.yellow)
                Text(selected.watchFor).font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
        }
    }

    private var dataPanel: some View {
        let installed = state.installedDataset(for: selected)
        return GroupBox(String(
            localized: "recipes.section.required-data",
            defaultValue: "Data this recipe needs",
            comment: "Section title for dataset requirements"
        )) {
            HStack(spacing: 12) {
                Image(systemName: selected.data.kind.icon).foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 3) {
                    Text(selected.data.title).font(.callout.weight(.semibold))
                    Text(String(format: String(
                        localized: "recipes.required-data.repo-and-size",
                        defaultValue: "%@ · %@",
                        comment: "Required data row showing repository and approximate size"
                    ), "\(selected.data.repo)", "\(selected.data.approximateSize)"))
                        .font(.caption.monospaced()).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                if let installed {
                    Label(String(
                        localized: "recipes.required-data.status.installed",
                        defaultValue: "Installed",
                        comment: "Status badge for already installed required dataset"
                    ), systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold)).foregroundStyle(.green)
                        .help(installed.summary)
                } else {
                    Label(String(
                        localized: "recipes.required-data.status.downloads-on-start",
                        defaultValue: "Downloads on start",
                        comment: "Status badge for datasets downloaded when run starts"
                    ), systemImage: "arrow.down.circle")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(8)
        }
    }

    private var configPanel: some View {
        GroupBox(String(
            localized: "recipes.section.exact-configuration",
            defaultValue: "Exact configuration it applies",
            comment: "Section title for exact recipe configuration values"
        )) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                WorkbenchMetric(label: String(
                    localized: "recipes.config.layers",
                    defaultValue: "Layers",
                    comment: "Configuration label for layer count"
                ), value: "\(selected.gpt.nLayers)")
                WorkbenchMetric(label: String(
                    localized: "recipes.config.hidden",
                    defaultValue: "Hidden",
                    comment: "Configuration label for hidden dimension"
                ), value: "\(selected.gpt.nEmbd)")
                WorkbenchMetric(label: String(
                    localized: "recipes.config.heads",
                    defaultValue: "Heads",
                    comment: "Configuration label for attention heads"
                ), value: "\(selected.gpt.nHeads)")
                WorkbenchMetric(label: String(
                    localized: "recipes.config.context",
                    defaultValue: "Context",
                    comment: "Configuration label for context length"
                ), value: "\(selected.gpt.blockSize)")
                WorkbenchMetric(label: String(
                    localized: "recipes.config.batch",
                    defaultValue: "Batch",
                    comment: "Configuration label for batch size"
                ), value: "\(selected.train.batchSize)")
                WorkbenchMetric(label: String(
                    localized: "recipes.config.steps",
                    defaultValue: "Steps",
                    comment: "Configuration label for training steps"
                ), value: selected.train.maxSteps.formatted())
                WorkbenchMetric(label: String(
                    localized: "recipes.config.learning-rate",
                    defaultValue: "Learning rate",
                    comment: "Configuration label for recipe learning rate"
                ), value: String(format: "%.0e", selected.train.learningRate))
                WorkbenchMetric(label: String(
                    localized: "recipes.config.tokenizer",
                    defaultValue: "Tokenizer",
                    comment: "Configuration label for recipe tokenizer type"
                ), value: selected.tokenizer.label)
            }
        }
    }

    @ViewBuilder private var prerequisitePanel: some View {
        if selected.needsTrainedModel {
            let ready = trainer.hasModel || !Checkpoint.list().isEmpty
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: ready ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(ready ? .green : .orange)
                VStack(alignment: .leading, spacing: 3) {
                    Text(ready ? String(
                        localized: "recipes.readiness.ready-with-checkpoint",
                        defaultValue: "Ready: this model has a checkpoint to fine-tune from.",
                        comment: "Readiness message when model has checkpoint for fine-tuning"
                    )
                               : String(
                                   localized: "recipes.readiness.pretrain-first",
                                   defaultValue: "Pretrain first — fine-tuning needs a trained model.",
                                   comment: "Guidance message when fine-tuning requires prior pretraining"
                               ))
                        .font(.callout.weight(.medium))
                    Text(ready ? String(
                        localized: "recipes.readiness.pick-checkpoint-help",
                        defaultValue: "Pick the checkpoint to continue from in Training's resume menu.",
                        comment: "Help text explaining where to choose resume checkpoint"
                    )
                               : String(
                                   localized: "recipes.readiness.run-pretraining-first-help",
                                   defaultValue: "Run a pre-training recipe for this model first, then come back.",
                                   comment: "Help text instructing user to run pretraining recipe first"
                               ))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .background((ready ? Color.green : Color.orange).opacity(0.10),
                        in: RoundedRectangle(cornerRadius: WorkbenchTheme.cornerRadius, style: .continuous))
        }
    }
}
