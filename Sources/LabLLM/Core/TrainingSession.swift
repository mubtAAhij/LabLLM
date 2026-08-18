import Foundation

/// Which kind of run produced a session. Each model keeps the latest session for
/// each mode, so switching between Pretrain, Fine-tune and DPO shows that mode's
/// own loss curve and samples instead of whatever ran most recently.
enum RunMode: String, Codable, CaseIterable, Identifiable {
    case pretrain, sft, dpo
    var id: String { rawValue }
    var label: String {
        switch self {
        case .pretrain: return String(
            localized: "core.training-session.method.pretrain",
            defaultValue: "Pretrain",
            comment: "Training method display name for pretraining mode"
        )
        case .sft: return String(
            localized: "core.training-session.method.fine-tune-chat",
            defaultValue: "Fine-tune (chat)",
            comment: "Training method display name for chat fine-tuning mode"
        )
        case .dpo: return String(
            localized: "core.training-session.method.dpo",
            defaultValue: "DPO",
            comment: "Training method display name for DPO mode"
        )
        }
    }
}

/// Everything worth keeping from a run once the process exits: the metrics that
/// were on screen, the full loss curve, the sample timeline, and which checkpoint
/// it left behind. Saved per model so reopening the app restores the dashboard.
struct TrainingSession: Codable, Equatable {
    struct LossSample: Codable, Equatable {
        var step: Int
        var value: Double
        var isValidation: Bool
    }

    struct SampleRecord: Codable, Equatable {
        var step: Int
        var text: String
        var method: String
        var createdAt: Date
    }

    var mode: RunMode
    var method: String = ""
    var datasetName: String?
    var step: Int = 0
    var maxSteps: Int = 0
    var trainLoss: Double = 0
    var valLoss: Double = 0
    var tokensPerSec: Double = 0
    var currentLR: Double = 0
    var runIsLoRA: Bool = false
    var completed: Bool = false
    var updatedAt: Date = Date()
    var lossHistory: [LossSample] = []
    var samples: [SampleRecord] = []
    var lastCheckpointPath: String?

    var lastCheckpointURL: URL? { lastCheckpointPath.map { URL(fileURLWithPath: $0) } }

    var summary: String {
        guard step > 0 else { return String(
            localized: "core.training-session.status.no-run-yet",
            defaultValue: "No run yet",
            comment: "Status text when no training run has started"
        ) }
        let state = completed ? String(
            localized: "core.training-session.status.finished",
            defaultValue: "finished",
            comment: "Short lowercase status text for a finished training run"
        ) : String(
            localized: "core.training-session.status.stopped",
            defaultValue: "stopped",
            comment: "Short lowercase status text for a stopped training run"
        )
        return String(format: String(
            localized: "core.training-session.progress.summary",
            defaultValue: "%@ · step %@/%@ · loss %.3f · %@",
            comment: "Training run summary with method, current and max steps, loss, and status"
        ), "\(method)", "\(step.formatted())", "\(maxSteps.formatted())", String(format: "%.3f", trainLoss), "\(state)")
    }
}

/// Reads and writes `sessions.json` inside a model's folder.
enum TrainingSessionStore {
    static func url(for modelDirectory: URL) -> URL {
        modelDirectory.appendingPathComponent("sessions.json")
    }

    static func load(from modelDirectory: URL) -> [RunMode: TrainingSession] {
        guard let data = try? Data(contentsOf: url(for: modelDirectory)) else { return [:] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let stored = try? decoder.decode([String: TrainingSession].self, from: data) else { return [:] }
        return stored.reduce(into: [:]) { result, entry in
            if let mode = RunMode(rawValue: entry.key) { result[mode] = entry.value }
        }
    }

    static func save(_ sessions: [RunMode: TrainingSession], to modelDirectory: URL) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let stored = sessions.reduce(into: [String: TrainingSession]()) { $0[$1.key.rawValue] = $1.value }
        do {
            try FileManager.default.createDirectory(at: modelDirectory, withIntermediateDirectories: true)
            try encoder.encode(stored).write(to: url(for: modelDirectory), options: .atomic)
        } catch {
            // A lost dashboard is not worth interrupting a run over; the next
            // save attempt (every run reports repeatedly) will try again.
        }
    }
}
