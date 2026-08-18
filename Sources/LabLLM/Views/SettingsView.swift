import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var prefs: Preferences
    @EnvironmentObject var state: AppState
    @EnvironmentObject var tutorial: TutorialState
    var showTutorial: () -> Void
    var showWelcome: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                WorkbenchPageHeader(eyebrow: String(
                    localized: "settings.system.section-title",
                    defaultValue: "System",
                    comment: "Settings page section title for system settings"
                ), title: String(
                    localized: "settings.system.page-title",
                    defaultValue: "Settings",
                    comment: "Settings page title"
                ), subtitle: String(
                    localized: "settings.system.page-subtitle",
                    defaultValue: "Control how LabLLM presents itself and guides your work.",
                    comment: "Settings page subtitle describing system configuration"
                ), icon: "gearshape")

                GroupBox(String(
                    localized: "settings.system.mode.label",
                    defaultValue: "Mode",
                    comment: "Label for app mode selector"
                )) {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(AppMode.allCases) { mode in
                            let tutorialAction = tutorial.modeAction(for: mode)
                            Button {
                                prefs.mode = mode
                                if let tutorialAction { tutorial.complete(tutorialAction) }
                            } label: {
                                HStack {
                                    Image(systemName: mode.icon).frame(width: 26)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(mode.label).font(.headline)
                                        Text(mode.blurb).font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: prefs.mode == mode ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(prefs.mode == mode ? Color.accentColor : .secondary)
                                }
                            }
                            .buttonStyle(.plain)
                            .tutorialTarget(tutorialAction ?? .idle)
                        }
                    }.padding(8)
                }

                GroupBox(String(
                    localized: "settings.appearance.section-title",
                    defaultValue: "Appearance",
                    comment: "Settings section title for appearance options"
                )) {
                    VStack(alignment: .leading, spacing: 16) {
                        Picker(String(
                            localized: "settings.appearance.theme.label",
                            defaultValue: "Theme",
                            comment: "Label for theme picker in appearance settings"
                        ), selection: Binding(get: { prefs.appearance }, set: { prefs.appearance = $0 })) {
                            ForEach(Preferences.Appearance.allCases) { Text($0.label).tag($0) }
                        }.pickerStyle(.segmented)

                        VStack(alignment: .leading, spacing: 8) {
                            Text(String(
                                localized: "settings.appearance.accent.label",
                                defaultValue: "Accent",
                                comment: "Label for accent color picker in appearance settings"
                            )).font(.caption).foregroundStyle(.secondary)
                            HStack(spacing: 8) {
                                ForEach(Preferences.Accent.allCases) { accent in
                                    Button {
                                        prefs.accent = accent
                                    } label: {
                                        Circle()
                                            .fill(accent.color)
                                            .frame(width: 26, height: 26)
                                            .overlay {
                                                if prefs.accent == accent {
                                                    Image(systemName: "checkmark")
                                                        .font(.caption.bold())
                                                        .foregroundStyle(.white)
                                                }
                                            }
                                    }
                                    .buttonStyle(.plain)
                                    .help(accent.label)
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text(String(
                                localized: "settings.appearance.validation-loss-color.label",
                                defaultValue: "Validation loss color",
                                comment: "Label for validation loss color setting"
                            )).font(.caption).foregroundStyle(.secondary)
                            HStack(spacing: 8) {
                                ForEach(Preferences.ValidationColor.allCases) { color in
                                    Button {
                                        prefs.validationColor = color
                                    } label: {
                                        RoundedRectangle(cornerRadius: max(4, WorkbenchTheme.cornerRadius - 2), style: .continuous)
                                            .fill(color.color)
                                            .frame(width: 34, height: 22)
                                            .overlay {
                                                if prefs.validationColor == color {
                                                    Image(systemName: "checkmark")
                                                        .font(.caption.bold())
                                                        .foregroundStyle(.white)
                                                }
                                            }
                                    }
                                    .buttonStyle(.plain)
                                    .help(color.label)
                                }
                            }
                        }
                    }.padding(8)
                }

                GroupBox(String(
                    localized: "settings.guidance.section-title",
                    defaultValue: "Guidance",
                    comment: "Settings section title for guidance options"
                )) {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle(String(
                            localized: "settings.guidance.show-inline-tips",
                            defaultValue: "Show inline tips",
                            comment: "Toggle label to show or hide inline tips"
                        ), isOn: Binding(get: { prefs.showTips }, set: { prefs.showTips = $0 }))
                        Toggle(String(
                            localized: "settings.guidance.show-animated-welcome-background",
                            defaultValue: "Show animated welcome background",
                            comment: "Toggle label to show animated welcome background"
                        ), isOn: Binding(get: { prefs.showWelcomeAnimation }, set: { prefs.showWelcomeAnimation = $0 }))
                        Toggle(String(
                            localized: "settings.guidance.show-welcome-on-first-launch",
                            defaultValue: "Show welcome automatically on first launch",
                            comment: "Toggle label for first-launch welcome screen behavior"
                        ), isOn: Binding(get: { prefs.autoShowWelcome }, set: { prefs.autoShowWelcome = $0 }))
                        HStack {
                            Button(String(
                                localized: "settings.guidance.replay-tutorial.button",
                                defaultValue: "Replay tutorial",
                                comment: "Button title to replay tutorial"
                            )) { showTutorial() }
                            Button(String(
                                localized: "settings.guidance.show-welcome-screen.button",
                                defaultValue: "Show welcome screen",
                                comment: "Button title to show welcome screen"
                            )) { showWelcome() }
                        }
                    }.padding(8)
                }

                GroupBox(String(
                    localized: "settings.features.section-title",
                    defaultValue: "Features",
                    comment: "Settings section title for feature toggles"
                )) {
                    VStack(alignment: .leading, spacing: 14) {
                        Toggle(String(
                            localized: "settings.features.use-feature-gates",
                            defaultValue: "Use Simple / Advanced / Expert feature gates",
                            comment: "Toggle label to enable mode-based feature gating"
                        ), isOn: Binding(get: { prefs.respectModeFeatureGates }, set: { prefs.respectModeFeatureGates = $0 }))
                        Toggle(String(
                            localized: "settings.features.show-sidebar-section-headers",
                            defaultValue: "Show sidebar section headers",
                            comment: "Toggle label to show sidebar section headers"
                        ), isOn: Binding(get: { prefs.showSidebarGroups }, set: { prefs.showSidebarGroups = $0 }))
                        Toggle(String(
                            localized: "settings.features.show-training-status-badge",
                            defaultValue: "Show training status badge",
                            comment: "Toggle label to show training status badge"
                        ), isOn: Binding(get: { prefs.showTrainingStatusBadge }, set: { prefs.showTrainingStatusBadge = $0 }))
                        Toggle(String(
                            localized: "settings.features.show-dataset-browser-hints",
                            defaultValue: "Show dataset browser hints",
                            comment: "Toggle label to show dataset browser hints"
                        ), isOn: Binding(get: { prefs.showDatasetHints }, set: { prefs.showDatasetHints = $0 }))

                        Divider()

                        Text(String(
                            localized: "settings.features.visible-pages.label",
                            defaultValue: "Visible pages",
                            comment: "Label for visible pages configuration"
                        )).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 10)], spacing: 10) {
                            ForEach(NavSection.allCases) { section in
                                featureButton(section)
                            }
                        }

                        Button(String(
                            localized: "settings.features.reset-visibility.button",
                            defaultValue: "Reset feature visibility",
                            comment: "Button title to reset sidebar feature visibility settings"
                        )) { prefs.resetFeatureVisibility() }
                            .buttonStyle(WorkbenchSecondaryButtonStyle())
                    }.padding(8)
                }

                GroupBox(String(
                    localized: "settings.layout.section-title",
                    defaultValue: "Layout",
                    comment: "Settings section title for layout customization"
                )) {
                    VStack(alignment: .leading, spacing: 14) {
                        Picker(String(
                            localized: "settings.layout.density.label",
                            defaultValue: "Density",
                            comment: "Label for layout density setting"
                        ), selection: Binding(get: { prefs.density }, set: { prefs.density = $0 })) {
                            ForEach(Preferences.Density.allCases) { Text($0.label).tag($0) }
                        }
                        .pickerStyle(.segmented)

                        slider(String(
                            localized: "settings.layout.corner-radius.label",
                            defaultValue: "Corner radius",
                            comment: "Label for corner radius setting"
                        ), value: Binding(get: { prefs.cornerRadius }, set: { prefs.cornerRadius = $0 }), range: 2...18, suffix: "px")
                        slider(String(
                            localized: "settings.layout.panel-opacity.label",
                            defaultValue: "Panel opacity",
                            comment: "Label for panel opacity setting"
                        ), value: Binding(get: { prefs.panelOpacity }, set: { prefs.panelOpacity = $0 }), range: 0.35...1.0, suffix: "")
                        slider(String(
                            localized: "settings.layout.sidebar-width.label",
                            defaultValue: "Sidebar width",
                            comment: "Label for sidebar width setting"
                        ), value: Binding(get: { prefs.sidebarWidth }, set: { prefs.sidebarWidth = $0 }), range: 200...320, suffix: "px")

                        Button(String(
                            localized: "settings.layout.reset-customization.button",
                            defaultValue: "Reset customization",
                            comment: "Button title to reset layout customization options"
                        )) { prefs.resetCustomization() }
                            .buttonStyle(WorkbenchSecondaryButtonStyle())
                    }.padding(8)
                }

                GroupBox(String(
                    localized: "settings.about.section-title",
                    defaultValue: "About",
                    comment: "Settings section title for app information"
                )) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(
                            localized: "settings.about.description",
                            defaultValue: "LabLLM — local GPT training on Apple MLX.",
                            comment: "About section description text"
                        )).font(.callout)
                        Text(String(format: String(
                            localized: "settings.about.hardware-summary",
                            defaultValue: "Chip: %@ · %@ unified memory",
                            comment: "About section hardware summary with chip name and memory amount"
                        ), "\(state.hardware.chip)", String(format: "%.0f GB", state.hardware.physicalMemoryGB)))
                            .font(.caption).foregroundStyle(.secondary)
                    }.padding(8)
                }
            }
            .padding(WorkbenchTheme.pagePadding)
        }
    }

    private func slider(_ label: String, value: Binding<Double>, range: ClosedRange<Double>, suffix: String) -> some View {
        HStack {
            Text(label).frame(width: 130, alignment: .leading)
            Slider(value: value, in: range)
            Text(formatted(value.wrappedValue, suffix: suffix))
                .font(.caption.monospacedDigit())
                .frame(width: 58, alignment: .trailing)
        }
    }

    private func featureButton(_ section: NavSection) -> some View {
        let visible = section == .settings || prefs.isNavigationSectionVisible(section.rawValue)
        let gated = prefs.respectModeFeatureGates && !prefs.unlocked(section.minMode)
        return Button {
            guard section != .settings else { return }
            prefs.setNavigationSection(section.rawValue, visible: !visible)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: section.icon)
                    .foregroundStyle(visible ? section.iconColor : .secondary)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                    Text(section.rawValue).font(.callout.weight(.semibold))
                    Text(section == .settings ? String(
                        localized: "settings.visible-pages.always-visible",
                        defaultValue: "Always visible",
                        comment: "Visibility status label indicating a page is always visible"
                    ) : (gated ? String(
                        localized: "settings.visible-pages.hidden-by-mode",
                        defaultValue: "Hidden by current mode",
                        comment: "Visibility status label indicating page is hidden by selected mode"
                    ) : section.group.capitalized))
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: visible ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(visible ? WorkbenchTheme.success : .secondary)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(visible ? WorkbenchTheme.accent.opacity(0.10) : Color.secondary.opacity(0.07),
                        in: RoundedRectangle(cornerRadius: WorkbenchTheme.cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: WorkbenchTheme.cornerRadius, style: .continuous)
                    .strokeBorder(gated && visible ? Color.orange.opacity(0.35) : WorkbenchTheme.grid)
            }
        }
        .buttonStyle(.plain)
        .disabled(section == .settings)
        .help(section == .settings ? String(
            localized: "settings.visible-pages.settings-cannot-hide",
            defaultValue: "Settings cannot be hidden.",
            comment: "Help text explaining that settings page visibility cannot be disabled"
        ) : String(format: String(
            localized: "settings.visible-pages.show-or-hide-section",
            defaultValue: "Show or hide %@ in the sidebar.",
            comment: "Help text describing sidebar visibility toggle for a section"
        ), "\(section.rawValue)"))
    }

    private func formatted(_ value: Double, suffix: String) -> String {
        if suffix.isEmpty { return String(format: "%.2f", value) }
        return "\(Int(value.rounded()))\(suffix)"
    }
}
