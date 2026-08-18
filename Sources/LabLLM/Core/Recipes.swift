import Foundation

/// The data a recipe needs, expressed as a Hugging Face repository so the recipe
/// can install it itself instead of telling the user to go find it.
struct RecipeDataset {
    let repo: String
    let title: String
    let kind: InstalledDataset.Kind
    /// Preferred file inside the repo. When nil (or absent upstream) the recipe
    /// falls back to the Dataset Viewer.
    let fileContains: String?
    /// Rows to pull when importing through the viewer.
    let rowLimit: Int
    let approximateSize: String
}

/// A recipe is a complete, runnable plan: architecture, hyperparameters, tokenizer,
/// the dataset to train on, and which run mode to start in. Applying one leaves the
/// Training page ready to press Start — it is not just a pair of config structs.
struct Recipe: Identifiable {
    let id: String
    let name: String
    let summary: String
    /// The concrete thing to watch while it runs. A recipe that teaches nothing is
    /// just a preset.
    let watchFor: String
    let icon: String
    let mode: RunMode
    let gpt: GPTConfig
    let train: TrainConfig
    let tokenizer: TokenizerKind
    let data: RecipeDataset
    /// Rough wall-clock range on Apple Silicon, stated as a range because it
    /// depends on the chip and what else is running.
    let minutes: ClosedRange<Int>
    /// Set when the recipe only makes sense on top of an existing trained model.
    let needsTrainedModel: Bool

    var shapeTag: String { "\(gpt.nLayers)L · \(gpt.nEmbd)d" }
    var contextTag: String { "ctx \(gpt.blockSize)" }
    var stepsTag: String { String(format: String(
        localized: "recipes.summary.steps-count",
        defaultValue: "%@ steps",
        comment: "Recipe summary showing total training steps"
    ), "\(train.maxSteps.formatted())") }
    var timeTag: String { String(format: String(
        localized: "recipes.summary.estimated-minutes-range",
        defaultValue: "≈%d–%d min",
        comment: "Recipe summary showing estimated minutes range"
    ), minutes.lowerBound, minutes.upperBound) }

    static let all: [Recipe] = [
        Recipe(id: "first-run",
               name: String(
                   localized: "recipes.preset.first-run.title",
                   defaultValue: "First run: Tiny Shakespeare",
                   comment: "Title for first-run recipe preset"
               ),
               summary: String(
                   localized: "recipes.preset.first-run.description",
                   defaultValue: "The smallest end-to-end run in the app: a 4-layer character model on 1 MB of Shakespeare.",
                   comment: "Description for first-run recipe preset"
               ),
               watchFor: String(
                   localized: "recipes.preset.first-run.watch-for",
                   defaultValue: "Loss drops from ~4.2 (random guessing over the vocabulary) to under 2.0, and the samples turn from noise into word-shaped text.",
                   comment: "Expected outcome text for first-run recipe preset"
               ),
               icon: "hare",
               mode: .pretrain,
               gpt: GPTConfig(blockSize: 64, nEmbd: 128, nLayers: 4, nHeads: 4),
               train: TrainConfig(batchSize: 32, maxSteps: 500, learningRate: 3e-3, warmupSteps: 50,
                                  evalEvery: 50, sampleEvery: 100, checkpointEvery: 250),
               tokenizer: .character,
               data: RecipeDataset(repo: "karpathy/tiny_shakespeare", title: String(
                   localized: "recipes.dataset.tiny-shakespeare",
                   defaultValue: "Tiny Shakespeare",
                   comment: "Dataset name used by recipe"
               ),
                                   kind: .corpus, fileContains: "input.txt", rowLimit: 40_000,
                                   approximateSize: "1.1 MB"),
               minutes: 1...4,
               needsTrainedModel: false),

        Recipe(id: "tinystories",
               name: String(
                   localized: "recipes.preset.tinystories.title",
                   defaultValue: "TinyStories: real sentences",
                   comment: "Title for TinyStories recipe preset"
               ),
               summary: String(
                   localized: "recipes.preset.tinystories.description",
                   defaultValue: "A 6-layer model on simple children's stories — the smallest setup that produces genuinely coherent sentences.",
                   comment: "Description for TinyStories recipe preset"
               ),
               watchFor: String(
                   localized: "recipes.preset.tinystories.watch-for",
                   defaultValue: "Validation loss keeps falling with training loss. Samples gain grammar, then plot. If val loss flattens while train loss falls, the model has started memorizing.",
                   comment: "Expected outcome text for TinyStories recipe preset"
               ),
               icon: "book",
               mode: .pretrain,
               gpt: GPTConfig(blockSize: 256, nEmbd: 384, nLayers: 6, nHeads: 6),
               train: TrainConfig(batchSize: 24, maxSteps: 3_000, learningRate: 6e-4, warmupSteps: 200,
                                  evalEvery: 100, sampleEvery: 250, checkpointEvery: 500),
               tokenizer: .byte,
               data: RecipeDataset(repo: "roneneldan/TinyStories", title: String(
                   localized: "recipes.dataset.tinystories",
                   defaultValue: "TinyStories",
                   comment: "Dataset name used by recipe"
               ),
                                   kind: .corpus, fileContains: nil, rowLimit: 20_000,
                                   approximateSize: String(
                                       localized: "recipes.dataset.tinystories.size",
                                       defaultValue: "~25 MB of rows",
                                       comment: "Approximate dataset size text for TinyStories"
                                   )),
               minutes: 15...45,
               needsTrainedModel: false),

        Recipe(id: "chat-lora",
               name: String(
                   localized: "recipes.preset.chat-lora.title",
                   defaultValue: "Teach it to chat (LoRA)",
                   comment: "Title for LoRA chat fine-tune recipe preset"
               ),
               summary: String(
                   localized: "recipes.preset.chat-lora.description",
                   defaultValue: "LoRA fine-tune on short everyday conversations, so a pretrained model starts answering instead of continuing text.",
                   comment: "Description for LoRA chat fine-tune recipe preset"
               ),
               watchFor: String(
                   localized: "recipes.preset.chat-lora.watch-for",
                   defaultValue: "Only the assistant turns count toward the loss. After a few hundred steps the model stops rambling and starts replying in turns — check it in Chat.",
                   comment: "Expected outcome text for LoRA chat fine-tune recipe preset"
               ),
               icon: "bubble.left.and.bubble.right",
               mode: .sft,
               gpt: GPTConfig(blockSize: 256, nEmbd: 384, nLayers: 6, nHeads: 6),
               train: TrainConfig(batchSize: 8, maxSteps: 800, learningRate: 2e-4, warmupSteps: 40,
                                  checkpointEvery: 200, loraRank: 8, loraAlpha: 16),
               tokenizer: .byte,
               data: RecipeDataset(repo: "HuggingFaceTB/everyday-conversations-llama3.1-2k",
                                   title: String(
                                       localized: "recipes.dataset.everyday-conversations-2k",
                                       defaultValue: "Everyday Conversations 2k",
                                       comment: "Dataset name used by chat fine-tune recipe"
                                   ),
                                   kind: .fineTune, fileContains: nil, rowLimit: 2_260,
                                   approximateSize: String(
                                       localized: "recipes.dataset.everyday-conversations-rows",
                                       defaultValue: "2,260 rows",
                                       comment: "Row count text for chat fine-tune dataset"
                                   )),
               minutes: 5...20,
               needsTrainedModel: true),

        Recipe(id: "instructions",
               name: String(
                   localized: "recipes.preset.instruction-following.title",
                   defaultValue: "Instruction following",
                   comment: "Title for instruction-following recipe preset"
               ),
               summary: String(
                   localized: "recipes.preset.instruction-following.description",
                   defaultValue: "Full fine-tune on Dolly-style instruction/response pairs for models that answer tasks rather than chat.",
                   comment: "Description for instruction-following recipe preset"
               ),
               watchFor: String(
                   localized: "recipes.preset.instruction-following.watch-for",
                   defaultValue: "Responses become instruction-shaped: they answer the asked question and stop, instead of inventing a new question.",
                   comment: "Expected outcome text for instruction-following recipe preset"
               ),
               icon: "list.bullet.rectangle",
               mode: .sft,
               gpt: GPTConfig(blockSize: 256, nEmbd: 384, nLayers: 6, nHeads: 6),
               train: TrainConfig(batchSize: 8, maxSteps: 1_500, learningRate: 1e-4, warmupSteps: 100,
                                  checkpointEvery: 300),
               tokenizer: .byte,
               data: RecipeDataset(repo: "databricks/databricks-dolly-15k", title: String(
                   localized: "recipes.dataset.dolly-15k",
                   defaultValue: "Dolly 15k",
                   comment: "Dataset name used by instruction-following recipe"
               ),
                                   kind: .fineTune, fileContains: "databricks-dolly-15k.jsonl",
                                   rowLimit: 5_000, approximateSize: "13 MB"),
               minutes: 10...35,
               needsTrainedModel: true),

        Recipe(id: "overfit-lab",
               name: String(
                   localized: "recipes.preset.overfitting-lab.title",
                   defaultValue: "Overfitting lab",
                   comment: "Title for recipe demonstrating overfitting behavior"
               ),
               summary: String(
                   localized: "recipes.preset.overfitting-lab.description",
                   defaultValue: "A deliberately oversized model on a deliberately tiny slice of text — the fastest way to see overfitting for yourself.",
                   comment: "Description for overfitting demonstration recipe"
               ),
               watchFor: String(
                   localized: "recipes.preset.overfitting-lab.watch-for",
                   defaultValue: "Training loss keeps diving while validation loss bottoms out and climbs. That gap is overfitting, and it is the reason validation exists.",
                   comment: "Expected behavior text for overfitting demonstration recipe"
               ),
               icon: "exclamationmark.triangle",
               mode: .pretrain,
               gpt: GPTConfig(blockSize: 128, nEmbd: 512, nLayers: 8, nHeads: 8),
               train: TrainConfig(batchSize: 8, maxSteps: 1_500, learningRate: 1e-3, warmupSteps: 20,
                                  evalEvery: 25, sampleEvery: 250, checkpointEvery: 500),
               tokenizer: .character,
               data: RecipeDataset(repo: "karpathy/tiny_shakespeare", title: String(
                   localized: "recipes.dataset.tiny-shakespeare-overfitting",
                   defaultValue: "Tiny Shakespeare",
                   comment: "Dataset name used by overfitting demonstration recipe"
               ),
                                   kind: .corpus, fileContains: "input.txt", rowLimit: 40_000,
                                   approximateSize: String(
                                       localized: "recipes.dataset.tiny-shakespeare-overfitting-size",
                                       defaultValue: "1.1 MB (5% used)",
                                       comment: "Dataset size note for overfitting demonstration recipe"
                                   )),
               minutes: 5...15,
               needsTrainedModel: false),
    ]

    /// The overfitting lab intentionally trains on a sliver of the corpus.
    var corpusPercent: Double { id == "overfit-lab" ? 5 : 100 }
}
