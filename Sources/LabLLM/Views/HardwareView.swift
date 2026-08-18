import SwiftUI

struct HardwareView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        let hw = state.hardware
        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                WorkbenchPageHeader(eyebrow: String(
                    localized: "hardware-view.section.analyze",
                    defaultValue: "Analyze",
                    comment: "Sidebar or section group label for hardware analysis"
                ), title: String(
                    localized: "hardware-view.title.hardware",
                    defaultValue: "Hardware",
                    comment: "Main title of hardware view"
                ), subtitle: String(
                    localized: "hardware-view.subtitle.apple-silicon-resources",
                    defaultValue: "The Apple Silicon resources available to this local model studio.",
                    comment: "Subtitle describing available local Apple Silicon resources"
                ), icon: "cpu")

                if !hw.isAppleSilicon {
                    Label(String(
                        localized: "hardware-view.warning.not-apple-silicon",
                        defaultValue: "Not running on Apple Silicon — MLX training requires an M-series chip.",
                        comment: "Warning shown when app runs on unsupported non-Apple-Silicon hardware"
                    ),
                          systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }

                GroupBox(String(
                    localized: "hardware-view.section.chip",
                    defaultValue: "Chip",
                    comment: "Section heading for chip details"
                )) {
                    VStack(alignment: .leading, spacing: 10) {
                        row(String(
                            localized: "hardware-view.field.processor",
                            defaultValue: "Processor",
                            comment: "Label for processor name/value row"
                        ), hw.chip)
                        row(String(
                            localized: "hardware-view.field.apple-silicon",
                            defaultValue: "Apple Silicon",
                            comment: "Label indicating whether machine is Apple Silicon"
                        ), hw.isAppleSilicon ? String(
                            localized: "hardware-view.value.yes",
                            defaultValue: "Yes",
                            comment: "Boolean yes value for hardware capabilities"
                        ) : String(
                            localized: "hardware-view.value.no",
                            defaultValue: "No",
                            comment: "Boolean no value for hardware capabilities"
                        ))
                        row(String(
                            localized: "hardware-view.field.logical-cores",
                            defaultValue: "Logical cores",
                            comment: "Label for logical CPU core count"
                        ), "\(hw.processorCount)")
                        if hw.performanceCores > 0 {
                            row(String(
                                localized: "hardware-view.field.performance-cores",
                                defaultValue: "Performance cores",
                                comment: "Label for performance CPU core count"
                            ), "\(hw.performanceCores)")
                            row(String(
                                localized: "hardware-view.field.efficiency-cores",
                                defaultValue: "Efficiency cores",
                                comment: "Label for efficiency CPU core count"
                            ), "\(hw.efficiencyCores)")
                        }
                        row(String(
                            localized: "hardware-view.field.unified-memory",
                            defaultValue: "Unified memory",
                            comment: "Label for unified memory amount"
                        ), String(format: "%.0f GB", hw.physicalMemoryGB))
                    }.padding(8)
                }

                GroupBox(String(
                    localized: "hardware-view.section.guidance",
                    defaultValue: "Guidance",
                    comment: "Section heading for sizing guidance"
                )) {
                    VStack(alignment: .leading, spacing: 10) {
                        row(String(
                            localized: "hardware-view.field.recommended-max-params",
                            defaultValue: "Recommended max params",
                            comment: "Label for recommended maximum parameter count"
                        ), format(hw.recommendedMaxParameters))
                        let fits = state.gptConfig.estimatedParameters <= hw.recommendedMaxParameters
                        HStack {
                            Text(String(
                                localized: "hardware-view.field.current-model-fits",
                                defaultValue: "Current model fits",
                                comment: "Label indicating if current model likely fits hardware limits"
                            )).frame(width: 200, alignment: .leading)
                            Label(fits ? String(
                                localized: "hardware-view.value.fits-comfortably",
                                defaultValue: "Comfortably",
                                comment: "Value text indicating model fits comfortably"
                            ) : String(
                                localized: "hardware-view.value.fits-may-be-tight",
                                defaultValue: "May be tight",
                                comment: "Value text indicating model may be near hardware limits"
                            ),
                                  systemImage: fits ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                .foregroundStyle(fits ? .green : .orange)
                        }
                        Text(String(
                            localized: "hardware-view.guidance.footnote.upper-bound-fp32-adamw",
                            defaultValue: "Guidance is a rough upper bound assuming fp32 AdamW state. Real usage depends on batch size, context length, and precision.",
                            comment: "Footnote clarifying assumptions behind hardware sizing guidance"
                        ))
                            .font(.caption).foregroundStyle(.secondary)
                    }.padding(8)
                }
            }
            .padding(WorkbenchTheme.pagePadding)
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).frame(width: 200, alignment: .leading).foregroundStyle(.secondary)
            Text(value).monospacedDigit()
            Spacer()
        }
    }

    private func format(_ n: Int) -> String {
        let f = NumberFormatter(); f.numberStyle = .decimal
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}
