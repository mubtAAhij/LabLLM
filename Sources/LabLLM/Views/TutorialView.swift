import SwiftUI

/// A hands-on checklist: each step routes to the actual workspace and updates
/// when the learner completes the relevant action.
struct TutorialView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var state: AppState
    @EnvironmentObject var trainer: Trainer
    @State private var step = 0

    private struct Lesson {
        let icon: String
        let title: String
        let action: String
        let destination: NavSection
        let body: String
    }

    private let lessons: [Lesson] = [
        .init(icon: "cube.transparent", title: String(localized: "tutorial.step1.title", defaultValue: "1. Choose a model", comment: "Title for tutorial step 1"), action: String(localized: "tutorial.step1.cta", defaultValue: "Open Model Builder", comment: "Call-to-action for opening Model Builder in step 1"), destination: .model,
              body: String(localized: "tutorial.step1.description", defaultValue: "Pick Tiny for a quick first run. The estimates update as you change layers, width, and context length.", comment: "Description text for tutorial step 1")),
        .init(icon: "text.book.closed", title: String(localized: "tutorial.step2.title", defaultValue: "2. Pick training text", comment: "Title for tutorial step 2"), action: String(localized: "tutorial.step2.cta", defaultValue: "Open Dataset", comment: "Call-to-action for opening Dataset in step 2"), destination: .dataset,
              body: String(localized: "tutorial.step2.description", defaultValue: "Use the built-in sample, import a text file, or choose a public corpus from the marketplace. In Simple mode, the tokenizer is built when training starts.", comment: "Description text for tutorial step 2")),
        .init(icon: "waveform.path.ecg", title: String(localized: "tutorial.step3.title", defaultValue: "3. Start training", comment: "Title for tutorial step 3"), action: String(localized: "tutorial.step3.cta", defaultValue: "Open Training", comment: "Call-to-action for opening Training in step 3"), destination: .training,
              body: String(localized: "tutorial.step3.description", defaultValue: "Start a run, then watch loss and the sample timeline. Lower loss usually means the model is learning the patterns in your text.", comment: "Description text for tutorial step 3")),
        .init(icon: "text.cursor", title: String(localized: "tutorial.step4.title", defaultValue: "4. Generate and iterate", comment: "Title for tutorial step 4"), action: String(localized: "tutorial.step4.cta", defaultValue: "Open Sampling", comment: "Call-to-action for opening Sampling in step 4"), destination: .sampling,
              body: String(localized: "tutorial.step4.description", defaultValue: "Enter a prompt and generate. Blue text is the model's continuation. Change temperature or filters, then Continue to extend the same result.", comment: "Description text for tutorial step 4")),
        .init(icon: "tray.full", title: String(localized: "tutorial.step5.title", defaultValue: "5. Fine-tune a behavior", comment: "Title for tutorial step 5"), action: String(localized: "tutorial.step5.cta", defaultValue: "Open Fine-tune Data", comment: "Call-to-action for opening fine-tune data in step 5"), destination: .fineTuneData,
              body: String(localized: "tutorial.step5.description", defaultValue: "Add JSONL datasets to the mixer. Select a percent or number of rows from each source, then return to Training and choose Fine-tune.", comment: "Description text for tutorial step 5")),
    ]

    private var safeStep: Int {
        min(max(step, 0), max(lessons.count - 1, 0))
    }

    private var currentLesson: Lesson? {
        lessons.indices.contains(safeStep) ? lessons[safeStep] : nil
    }

    var body: some View {
        Group {
            if let lesson = currentLesson {
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack {
                            Image(systemName: lesson.icon).font(.system(size: 40)).foregroundStyle(.tint)
                            VStack(alignment: .leading) {
                                Text(lesson.title).font(.title.bold())
                                Text(String(localized: "tutorial.header.hands-on-guide", defaultValue: "Hands-on guide", comment: "Header title for tutorial sheet")).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Text(lesson.body).font(.title3).fixedSize(horizontal: false, vertical: true)
                        Button(lesson.action) {
                            NotificationCenter.default.post(name: .navigateToSection, object: lesson.destination.rawValue)
                            dismiss()
                        }
                        .buttonStyle(WorkbenchPrimaryButtonStyle())
                        Spacer()
                        HStack(spacing: 8) {
                            Image(systemName: completionIcon).foregroundStyle(completionIcon == "checkmark.circle.fill" ? .green : .secondary)
                            Text(completionText).font(.callout).foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(40)
                    Divider()
                    HStack {
                        Button(String(localized: "tutorial.navigation.back", defaultValue: "Back", comment: "Back button title in tutorial")) { step = max(0, safeStep - 1) }.disabled(safeStep == 0)
                        Spacer()
                        PageDots(count: lessons.count, index: safeStep)
                        Spacer()
                        if safeStep < lessons.count - 1 {
                            Button(String(localized: "tutorial.navigation.next", defaultValue: "Next", comment: "Next button title in tutorial")) { step = safeStep + 1 }.keyboardShortcut(.defaultAction)
                        } else {
                            Button(String(localized: "tutorial.navigation.finish", defaultValue: "Finish", comment: "Finish button title in tutorial")) { dismiss() }.keyboardShortcut(.defaultAction).buttonStyle(WorkbenchPrimaryButtonStyle())
                        }
                    }.padding()
                }
            }
        }
        .frame(width: 600, height: 440)
    }

    private var completionIcon: String {
        switch safeStep {
        case 1: return state.hasCorpus ? "checkmark.circle.fill" : "circle"
        case 2: return trainer.isTraining || trainer.step > 0 ? "checkmark.circle.fill" : "circle"
        case 3: return trainer.hasModel ? "checkmark.circle.fill" : "circle"
        case 4: return state.hasFineTuneData ? "checkmark.circle.fill" : "circle"
        default: return "checkmark.circle.fill"
        }
    }

    private var completionText: String { completionIcon == "checkmark.circle.fill" ? String(localized: "tutorial.step.status.completed", defaultValue: "Completed", comment: "Status label for completed tutorial step") : String(localized: "tutorial.step.status.complete-in-workspace", defaultValue: "Complete this in the workspace", comment: "Instruction shown for incomplete tutorial step") }
}
