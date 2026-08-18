import SwiftUI
import UniformTypeIdentifiers

struct FineTuneDataView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var prefs: Preferences
    @EnvironmentObject var tutorial: TutorialState
    @StateObject private var browser = HFHubBrowser(kind: .fineTune)
    @State private var importingSFT = false
    @State private var importingIMessage = false

    /// Recommended sources stay pinned to the top in every mode. They are the
    /// repositories known to import cleanly here, which is just as useful to an
    /// expert as to a beginner.
    private var displayedResults: [HFHubDataset] {
        let remote = browser.results.filter { remote in !browser.pinned.contains(where: { $0.id == remote.id }) }
        return browser.pinned + remote.sorted { ($0.downloads ?? 0) > ($1.downloads ?? 0) }
    }

    private func isRecommended(_ dataset: HFHubDataset) -> Bool {
        browser.pinned.contains { $0.displayName == dataset.displayName && $0.id == dataset.id }
    }

    var body: some View {
        VStack(spacing: 0) {
            WorkbenchPageHeader(eyebrow: String(
                localized: "fine-tune-data.header.dataset-studio",
                defaultValue: "Dataset Studio",
                comment: "Top label for fine-tuning dataset studio page"
            ), title: String(
                localized: "fine-tune-data.header.title",
                defaultValue: "Fine-tuning Data",
                comment: "Main title for fine-tuning data page"
            ), subtitle: String(
                localized: "fine-tune-data.header.subtitle",
                defaultValue: "Find compatible instruction datasets and install them to disk. The SFT mix itself is composed in Training.",
                comment: "Subtitle explaining fine-tuning data workflow"
            ), icon: "tray.full")
                .padding(.horizontal, WorkbenchTheme.pagePadding).padding(.top, 22).padding(.bottom, 14)
            GeometryReader { proxy in
                let browserWidth = min(320, max(220, proxy.size.width * 0.34))
                HStack(spacing: 0) {
                    browserPane.frame(width: browserWidth).frame(maxHeight: .infinity)
                    Divider()
                    inspectorPane.frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { if browser.results.isEmpty { browser.search() } }
        .fileImporter(isPresented: $importingSFT, allowedContentTypes: [.item]) { result in
            if case .success(let url) = result, url.startAccessingSecurityScopedResource() {
                defer { url.stopAccessingSecurityScopedResource() }
                state.importLocalJSONL(url: url)
                tutorial.complete(.fineTuneSourceAdded)
            }
        }
        .fileImporter(isPresented: $importingIMessage, allowedContentTypes: [.item]) { result in
            if case .success(let url) = result, url.startAccessingSecurityScopedResource() {
                defer { url.stopAccessingSecurityScopedResource() }
                state.importIMessageDatabase(url: url)
                tutorial.complete(.fineTuneSourceAdded)
            }
        }
        .alert(String(
            localized: "fine-tune-data.alert.dataset-problem.title",
            defaultValue: "Dataset problem",
            comment: "Alert title for dataset issue"
        ), isPresented: Binding(get: { state.datasetImportError != nil }, set: { if !$0 { state.datasetImportError = nil } })) {
            Button(String(
                localized: "fine-tune-data.alert.ok",
                defaultValue: "OK",
                comment: "Acknowledgement button label in dataset alert"
            ), role: .cancel) { }
        } message: { Text(state.datasetImportError ?? "") }
    }

    private var browserPane: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(String(
                    localized: "fine-tune-data.actions.browse",
                    defaultValue: "Browse fine-tuning data",
                    comment: "Button label to open fine-tuning dataset browser"
                )).font(.headline)
                Spacer()
                Button { importingIMessage = true } label: { Image(systemName: "message.badge") }.help(String(
                    localized: "fine-tune-data.actions.import-imessage-chatdb",
                    defaultValue: "Import iMessage chat.db",
                    comment: "Button label to import iMessage chat database"
                ))
                Button { importingSFT = true } label: { Image(systemName: "folder.badge.plus") }.help(String(
                    localized: "fine-tune-data.actions.import-local-jsonl",
                    defaultValue: "Import local JSONL",
                    comment: "Button label to import local JSONL file"
                ))
            }
            WorkbenchSearchBar(query: $browser.query, prompt: String(
                localized: "fine-tune-data.actions.search-hugging-face",
                defaultValue: "Search Hugging Face",
                comment: "Button label to search datasets on Hugging Face"
            )) { browser.search() }
            if !browser.activityDetail.isEmpty {
                Text(browser.activityDetail).font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
            }
            if prefs.showDatasetHints {
                Label(String(
                    localized: "fine-tune-data.help.search-priority",
                    defaultValue: "Starred sources are pinned first in every mode. Results prioritize importable instruction and conversation data, including Parquet-backed datasets.",
                    comment: "Helper text explaining source ranking and dataset compatibility"
                ), systemImage: "sparkles")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if browser.isLoading && browser.results.isEmpty { ProgressView(String(
                localized: "fine-tune-data.search.loading",
                defaultValue: "Searching datasets…",
                comment: "Status text shown while searching datasets"
            )).frame(maxWidth: .infinity, maxHeight: .infinity) }
            else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(displayedResults) { dataset in
                            FineTuneBrowserRow(dataset: dataset, isSelected: browser.selected == dataset, recommended: isRecommended(dataset))
                                .contentShape(Rectangle())
                                .onTapGesture { browser.select(dataset) }
                                .onAppear { browser.loadMoreIfNeeded(dataset) }
                        }
                        if browser.isLoadingMore { ProgressView().padding() }
                    }
                }
            }
            if let error = browser.error { Text(error).font(.caption).foregroundStyle(.orange) }
        }
        .padding(16).background(WorkbenchTheme.panel)
    }

    private var inspectorPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let dataset = browser.selected {
                    datasetDetail(dataset)
                } else {
                    WorkbenchEmptyState(icon: "rectangle.and.text.magnifyingglass", title: String(
                        localized: "fine-tune-data.empty.select-dataset.title",
                        defaultValue: "Select a dataset",
                        comment: "Empty-state title prompting dataset selection"
                    ), message: String(
                        localized: "fine-tune-data.empty.select-dataset.subtitle",
                        defaultValue: "Inspect a compatible JSONL dataset before installing it.",
                        comment: "Empty-state subtitle describing dataset inspection before install"
                    ))
                }
                InstalledDatasetsPanel(kind: .fineTune)
            }.padding(WorkbenchTheme.pagePadding)
        }
    }

    @ViewBuilder private func datasetDetail(_ dataset: HFHubDataset) -> some View {
        VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(dataset.displayName).font(.title2.bold())
                            Text(dataset.id).font(.callout.monospaced()).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(prefs.mode == .simple ? String(
                            localized: "fine-tune-data.dataset.download-and-install",
                            defaultValue: "Download and install",
                            comment: "Button label to download and install selected dataset"
                        ) : String(
                            localized: "fine-tune-data.dataset.install",
                            defaultValue: "Install dataset",
                            comment: "Button label to install selected dataset"
                        )) { importSelected(dataset) }
                            .buttonStyle(WorkbenchPrimaryButtonStyle())
                            .disabled(browser.selectedFile == nil && browser.viewerSource == nil)
                            .tutorialTarget(.fineTuneSourceAdded)
                    }
                    Text(dataset.summary).foregroundStyle(.secondary)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                        WorkbenchMetric(label: String(
                            localized: "fine-tune-data.dataset.stats.downloads",
                            defaultValue: "Downloads",
                            comment: "Dataset metric label for download count"
                        ), value: format(dataset.downloads ?? 0), icon: "arrow.down.circle")
                        WorkbenchMetric(label: String(
                            localized: "fine-tune-data.dataset.stats.likes",
                            defaultValue: "Likes",
                            comment: "Dataset metric label for like count"
                        ), value: "\(dataset.likes ?? 0)", icon: "heart")
                        WorkbenchMetric(label: String(
                            localized: "fine-tune-data.dataset.stats.rows",
                            defaultValue: "Rows",
                            comment: "Dataset metric label for row count"
                        ), value: format(dataset.estimatedRows ?? 0), icon: "number")
                    }
                    GroupBox(String(
                        localized: "fine-tune-data.dataset.compatible-file",
                        defaultValue: "Compatible file",
                        comment: "Label showing compatible file for dataset import"
                    )) {
                        if browser.files.isEmpty && browser.isLoading { ProgressView(String(
                            localized: "fine-tune-data.dataset.reading-repository-files",
                            defaultValue: "Reading repository files…",
                            comment: "Status text while loading repository file listing"
                        )) }
                        else if browser.files.filter(\.isFineTuneData).isEmpty { Text(String(
                            localized: "fine-tune-data.repository.no-compatible-jsonl",
                            defaultValue: "No compatible JSON or JSONL file was found in this repository. Choose a different dataset or import a local JSONL file.",
                            comment: "Warning shown when selected repository has no compatible JSON or JSONL files"
                        )).foregroundStyle(.secondary) }
                        else {
                            Picker(String(
                                localized: "fine-tune-data.repository.data-file.label",
                                defaultValue: "Data file",
                                comment: "Label for selected data file in repository details"
                            ), selection: $browser.selectedFile) {
                                ForEach(browser.files.filter(\.isFineTuneData)) { file in Text(file.path).tag(Optional(file)) }
                            }.labelsHidden().frame(maxWidth: .infinity)
                        }
                    }
                    if let source = browser.viewerSource, browser.selectedFile == nil {
                        viewerImport(source)
                    }
                    GroupBox(String(
                        localized: "fine-tune-data.dataset-card.section-title",
                        defaultValue: "Dataset card",
                        comment: "Section title for rendered dataset card content"
                    )) {
                        if browser.isLoadingReadme { ProgressView(String(
                            localized: "fine-tune-data.dataset-card.loading-readme",
                            defaultValue: "Loading README…",
                            comment: "Placeholder text while loading dataset README content"
                        )) }
                        else { DatasetCardPreview(markdown: browser.readme) }
                    }
        }
    }

    private func viewerImport(_ source: HFViewerSource) -> some View {
        let maximum = max(1, source.totalRows)
        let step = maximum >= 100 ? 100 : 1
        return GroupBox(String(
            localized: "fine-tune-data.viewer-import.section-title",
            defaultValue: "Dataset Viewer import",
            comment: "Section title for Dataset Viewer import controls"
        )) {
            VStack(alignment: .leading, spacing: 8) {
                Text(String(format: String(
                    localized: "fine-tune-data.viewer-import.conversion-summary",
                    defaultValue: "Hugging Face will convert %@ / %@ into recognized chat or instruction rows.",
                    comment: "Explanation of Dataset Viewer conversion from selected config and split"
                ), "\(source.config)", "\(source.split)"))
                    .font(.callout).foregroundStyle(.secondary)
                Stepper(String(format: String(
                    localized: "fine-tune-data.viewer-import.row-limit-summary",
                    defaultValue: "Import %@ of %@ rows",
                    comment: "Button text showing import row limit and total rows"
                ), "\(format(browser.viewerRowLimit))", "\(format(source.totalRows))"), value: $browser.viewerRowLimit, in: 1...maximum, step: step)
            }
        }
    }

    private func importSelected(_ dataset: HFHubDataset) {
        if let file = browser.selectedFile { state.downloadHFDataset(dataset, file: file) }
        else if let source = browser.viewerSource { state.importHFViewerDataset(dataset, source: source, limit: browser.viewerRowLimit) }
        else { return }
        tutorial.complete(.fineTuneSourceAdded)
    }
    private func format(_ number: Int) -> String { NumberFormatter.localizedString(from: NSNumber(value: number), number: .decimal) }
}

private struct FineTuneBrowserRow: View {
    let dataset: HFHubDataset
    let isSelected: Bool
    let recommended: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(dataset.displayName).font(.callout.weight(.semibold)).lineLimit(1)
                Spacer()
                if recommended { Image(systemName: "star.fill").font(.caption2).foregroundStyle(.yellow) }
            }
            Text(dataset.id).font(.caption2.monospaced()).foregroundStyle(.secondary).lineLimit(1)
            HStack { Text(dataset.summary).font(.caption2).foregroundStyle(.secondary).lineLimit(1); Spacer(); Text(dataset.estimatedRows.map { String(format: String(
                localized: "fine-tune-data.search-result.rows",
                defaultValue: "%@ rows",
                comment: "Search result metadata showing dataset row count"
            ), "\($0)") } ?? String(format: String(
                localized: "fine-tune-data.search-result.download-count",
                defaultValue: "%d",
                comment: "Search result metadata showing dataset download count"
            ), dataset.downloads ?? 0)).font(.caption2.monospacedDigit()).foregroundStyle(.secondary) }
        }
        .padding(10).frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .background(isSelected ? WorkbenchTheme.accent.opacity(0.14) : Color.clear, in: RoundedRectangle(cornerRadius: WorkbenchTheme.cornerRadius, style: .continuous))
    }
}
