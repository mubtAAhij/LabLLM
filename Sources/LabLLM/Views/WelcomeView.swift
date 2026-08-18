import SwiftUI

/// First-launch welcome + mode selection. Shown until the user finishes onboarding;
/// re-openable from Settings.
struct WelcomeView: View {
    @EnvironmentObject var prefs: Preferences
    @Environment(\.dismiss) private var dismiss
    var onFinish: () -> Void

    @State private var page = 0
    private let pages = 3

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                intro.tag(0)
                modePicker.tag(1)
                flow.tag(2)
            }
            .tabViewStyle(.automatic)
            .frame(minHeight: 420)

            Divider()
            HStack {
                if page > 0 {
                    Button(String(localized: "welcome-view.navigation.back", defaultValue: "Back", comment: "Button title to go to previous onboarding step")) { withAnimation { page -= 1 } }
                }
                Spacer()
                PageDots(count: pages, index: page)
                Spacer()
                if page < pages - 1 {
                    Button(String(localized: "welcome-view.navigation.next", defaultValue: "Next", comment: "Button title to go to next onboarding step")) { withAnimation { page += 1 } }
                        .keyboardShortcut(.defaultAction)
                } else {
                    Button(String(localized: "welcome-view.navigation.get-started", defaultValue: "Get started", comment: "Button title to finish onboarding and start using app")) {
                        prefs.hasOnboarded = true
                        onFinish()
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(WorkbenchPrimaryButtonStyle())
                }
            }
            .padding()
        }
        .frame(width: 640, height: 520)
    }

    private var intro: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 64)).foregroundStyle(.tint)
            Text(String(localized: "welcome-view.hero.title", defaultValue: "Welcome to LabLLM", comment: "Main title on welcome screen")).font(.largeTitle.bold())
            Text(String(localized: "welcome-view.hero.subtitle", defaultValue: "Design, train, and sample small GPT language models locally on your Mac — powered by Apple MLX. No cloud, no account.", comment: "Introductory subtitle describing app capabilities and local-first operation"))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 420)
        }.padding(40)
    }

    private var modePicker: some View {
        VStack(spacing: 16) {
            Text(String(localized: "welcome-view.experience-level.title", defaultValue: "Pick your comfort level", comment: "Title for choosing onboarding experience level")).font(.title.bold())
            Text(String(localized: "welcome-view.experience-level.subtitle", defaultValue: "You can change this anytime in Settings.", comment: "Helper text explaining experience level can be changed later")).foregroundStyle(.secondary)
            ForEach(AppMode.allCases) { mode in
                Button {
                    prefs.mode = mode
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: mode.icon).font(.title2).frame(width: 34)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(mode.label).font(.headline)
                            Text(mode.blurb).font(.callout).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: prefs.mode == mode ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(prefs.mode == mode ? Color.accentColor : .secondary)
                    }
                    .padding(14)
                    .background(prefs.mode == mode ? Color.accentColor.opacity(0.12) : Color.gray.opacity(0.08),
                                in: RoundedRectangle(cornerRadius: WorkbenchTheme.cornerRadius, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }.padding(40)
    }

    private var flow: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(String(localized: "welcome-view.basic-flow.title", defaultValue: "The basic flow", comment: "Section heading introducing core workflow steps")).font(.title.bold()).frame(maxWidth: .infinity, alignment: .center)
            step("1", "cube.transparent", String(localized: "welcome-view.basic-flow.design-model.title", defaultValue: "Design a model", comment: "Workflow step title for model design"), String(localized: "welcome-view.basic-flow.design-model.description", defaultValue: "Choose a size preset or tune the architecture.", comment: "Workflow step description for model design options"))
            step("2", "text.book.closed", String(localized: "welcome-view.basic-flow.bring-data.title", defaultValue: "Bring data", comment: "Workflow step title for adding training data"), String(localized: "welcome-view.basic-flow.bring-data.description", defaultValue: "Use the built-in sample or import a .txt file, then build a tokenizer.", comment: "Workflow step description for data import and tokenizer creation"))
            step("3", "waveform.path.ecg", String(localized: "welcome-view.basic-flow.train.title", defaultValue: "Train", comment: "Workflow step title for model training"), String(localized: "welcome-view.basic-flow.train.description", defaultValue: "Watch the loss drop live. Pause or stop anytime.", comment: "Workflow step description for monitoring and controlling training"))
            step("4", "text.cursor", String(localized: "welcome-view.basic-flow.sample.title", defaultValue: "Sample", comment: "Workflow step title for text generation"), String(localized: "welcome-view.basic-flow.sample.description", defaultValue: "Generate text from your trained model.", comment: "Workflow step description for sampling from trained model"))
            Text(String(localized: "welcome-view.basic-flow.tip.tutorial", defaultValue: "Tip: turn on the tutorial from the toolbar if you'd like guided coach-marks.", comment: "Tip text explaining how to enable tutorial coach marks"))
                .font(.footnote).foregroundStyle(.secondary).padding(.top, 6)
        }.padding(40)
    }

    private func step(_ n: String, _ icon: String, _ title: String, _ desc: String) -> some View {
        HStack(spacing: 14) {
            Text(n).font(.headline.monospacedDigit())
                .frame(width: 28, height: 28)
                .background(Color.accentColor.opacity(0.15), in: Circle())
            Image(systemName: icon).frame(width: 24).foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.headline)
                Text(desc).font(.callout).foregroundStyle(.secondary)
            }
        }
    }
}

struct PageDots: View {
    let count: Int; let index: Int
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0 ..< count, id: \.self) { i in
                Circle().fill(i == index ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 7, height: 7)
            }
        }
    }
}
