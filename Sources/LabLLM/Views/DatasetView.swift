import SwiftUI
import UniformTypeIdentifiers

struct DatasetView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var prefs: Preferences
    @EnvironmentObject var tutorial: TutorialState
    @StateObject private var browser = HFHubBrowser(kind: .corpus)
    @State private var importing = false

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
                localized: "dataset.header.studio",
                defaultValue: "Dataset Studio",
                comment: "Header eyebrow label for dataset studio screen"
            ), title: String(
                localized: "dataset.header.title",
                defaultValue: "Pre-Training Data",
                comment: "Main title for pre-training dataset screen"
            ), subtitle: String(
                localized: "dataset.header.subtitle",
                defaultValue: "Browse public Hugging Face corpora and install them to disk. How much of each one a run uses is set in Training.",
                comment: "Subtitle explaining pre-training dataset workflow"
            ), icon: "text.book.closed")
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
        .fileImporter(isPresented: $importing, allowedContentTypes: [.plainText, .text, .json, .commaSeparatedText]) { result in
            if case .success(let url) = result, url.startAccessingSecurityScopedResource() {
                defer { url.stopAccessingSecurityScopedResource() }
                state.loadCorpus(from: url)
                tutorial.complete(.corpusAdded)
            }
        }
        .alert(String(
            localized: "dataset.alert.problem.title",
            defaultValue: "Dataset problem",
            comment: "Alert title shown when dataset action fails"
        ), isPresented: Binding(get: { state.datasetImportError != nil }, set: { if !$0 { state.datasetImportError = nil } })) {
            Button(String(
                localized: "dataset.alert.ok",
                defaultValue: "OK",
                comment: "Confirmation button in dataset alert"
            ), role: .cancel) { }
        } message: { Text(state.datasetImportError ?? "") }
    }

    private var browserPane: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(String(
                    localized: "dataset.actions.browse",
                    defaultValue: "Browse pre-training data",
                    comment: "Primary action to browse pre-training datasets"
                )).font(.headline)
                Spacer()
                Button { importing = true } label: { Image(systemName: "folder.badge.plus") }.help(String(
                    localized: "dataset.actions.import-local-text",
                    defaultValue: "Import local text",
                    comment: "Action to import local text file as corpus"
                ))
            }
            WorkbenchSearchBar(query: $browser.query, prompt: String(
                localized: "dataset.actions.search-hugging-face",
                defaultValue: "Search Hugging Face",
                comment: "Action to search datasets on Hugging Face"
            )) { browser.search() }
            if !browser.activityDetail.isEmpty {
                Text(browser.activityDetail).font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
            }
            if prefs.showDatasetHints {
                Label(String(
                    localized: "dataset.search.help.pinned-and-persisted",
                    defaultValue: "Starred sources are pinned first in every mode. Installed data is written to disk and stays available after a relaunch.",
                    comment: "Help text about search ordering and installed dataset persistence"
                ), systemImage: "sparkles")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if browser.isLoading && browser.results.isEmpty {
                ProgressView(String(
                    localized: "dataset.search.loading",
                    defaultValue: "Searching datasets…",
                    comment: "Progress text while dataset search is running"
                )).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(displayedResults, id: \.displayName) { dataset in
                            DatasetBrowserRow(dataset: dataset, isSelected: browser.selected == dataset, recommended: isRecommended(dataset))
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
        .padding(16)
        .background(WorkbenchTheme.panel)
    }

    private var inspectorPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let dataset = browser.selected {
                    datasetDetail(dataset)
                } else {
                    WorkbenchEmptyState(icon: "rectangle.and.text.magnifyingglass", title: String(
                        localized: "dataset.empty.select.title",
                        defaultValue: "Select a dataset",
                        comment: "Empty state title prompting dataset selection"
                    ), message: String(
                        localized: "dataset.empty.select.subtitle",
                        defaultValue: "Search or browse the list to inspect a public dataset before installing it.",
                        comment: "Empty state subtitle describing selection workflow"
                    ))
                }
                InstalledDatasetsPanel(kind: .corpus)
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
                            localized: "dataset.actions.download-and-install",
                            defaultValue: "Download and install",
                            comment: "Button label to download and install selected dataset"
                        ) : String(
                            localized: "dataset.actions.install-corpus",
                            defaultValue: "Install corpus",
                            comment: "Button label to install selected corpus dataset"
                        )) { importSelected(dataset) }
                            .buttonStyle(WorkbenchPrimaryButtonStyle())
                            .disabled(browser.selectedFile == nil && browser.viewerSource == nil)
                            .tutorialTarget(.corpusAdded)
                    }
                    Text(dataset.summary).foregroundStyle(.secondary)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                        WorkbenchMetric(label: String(
                            localized: "dataset.metadata.downloads",
                            defaultValue: "Downloads",
                            comment: "Metadata label for dataset download count"
                        ), value: format(dataset.downloads ?? 0), icon: "arrow.down.circle")
                        WorkbenchMetric(label: String(
                            localized: "dataset.metadata.likes",
                            defaultValue: "Likes",
                            comment: "Metadata label for dataset like count"
                        ), value: "\(dataset.likes ?? 0)", icon: "heart")
                        WorkbenchMetric(label: String(
                            localized: "dataset.file-selection.download.label",
                            defaultValue: "Download",
                            comment: "Label for downloadable file section"
                        ), value: browser.selectedFile?.formattedSize ?? dataset.downloadSize ?? String(
                            localized: "dataset.file-selection.choose-file",
                            defaultValue: "Choose a file",
                            comment: "Prompt to choose a file from repository listing"
                        ), icon: "arrow.down.to.line")
                    }
                    GroupBox(String(
                        localized: "dataset.file-selection.import-file",
                        defaultValue: "Import file",
                        comment: "Button label to import selected repository file"
                    )) {
                        if browser.files.isEmpty && browser.isLoading { ProgressView(String(
                            localized: "dataset.file-selection.loading-repository-files",
                            defaultValue: "Reading repository files…",
                            comment: "Progress text while repository files are being listed"
                        )) }
                        else if browser.files.isEmpty { Text(String(
                            localized: "dataset.repository.no-importable-file",
                            defaultValue: "This repository has no directly importable text, JSON, JSONL, or CSV file.",
                            comment: "Warning shown when repository has no importable files"
                        )).foregroundStyle(.secondary) }
                        else {
                            Picker(String(
                                localized: "dataset.repository.file.label",
                                defaultValue: "File",
                                comment: "Label for repository file selector"
                            ), selection: $browser.selectedFile) {
                                ForEach(browser.files) { file in Text(file.path).tag(Optional(file)) }
                            }.labelsHidden().frame(maxWidth: .infinity)
                        }
                    }
                    if let source = browser.viewerSource, browser.selectedFile == nil {
                        viewerImport(source)
                    }
                    GroupBox(String(
                        localized: "dataset.details.card.title",
                        defaultValue: "Dataset card",
                        comment: "Section title for dataset card preview"
                    )) {
                        if browser.isLoadingReadme { ProgressView(String(
                            localized: "dataset.details.card.loading-readme",
                            defaultValue: "Loading README…",
                            comment: "Placeholder while dataset README is loading"
                        )) }
                        else { DatasetCardPreview(markdown: browser.readme) }
                    }
        }
    }

    private func viewerImport(_ source: HFViewerSource) -> some View {
        let maximum = max(1, source.totalRows)
        let step = maximum >= 100 ? 100 : 1
        return GroupBox(String(
            localized: "dataset.viewer-import.title",
            defaultValue: "Dataset Viewer import",
            comment: "Section title for dataset viewer import controls"
        )) {
            VStack(alignment: .leading, spacing: 8) {
                Text(String(format: String(
                    localized: "dataset.viewer-import.conversion-summary",
                    defaultValue: "Hugging Face will convert this dataset's %@ / %@ split into training text.",
                    comment: "Description of dataset viewer conversion source config and split"
                ), "\(source.config)", "\(source.split)"))
                    .font(.callout).foregroundStyle(.secondary)
                Stepper(String(format: String(
                    localized: "dataset.viewer-import.row-limit-summary",
                    defaultValue: "Import %@ of %@ rows",
                    comment: "Label showing selected import row limit and total rows"
                ), "\(format(browser.viewerRowLimit))", "\(format(source.totalRows))"), value: $browser.viewerRowLimit, in: 1...maximum, step: step)
            }
        }
    }

    private func importSelected(_ dataset: HFHubDataset) {
        if let file = browser.selectedFile { state.downloadHFCorpus(dataset, file: file) }
        else if let source = browser.viewerSource { state.importHFViewerCorpus(dataset, source: source, limit: browser.viewerRowLimit) }
        else { return }
        tutorial.complete(.corpusAdded)
    }
    private func format(_ number: Int) -> String { NumberFormatter.localizedString(from: NSNumber(value: number), number: .decimal) }
}

private struct DatasetBrowserRow: View {
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
            HStack(spacing: 8) {
                Text(dataset.summary).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                Spacer()
                Text(dataset.downloadSize ?? String(format: String(
                    localized: "dataset.search-result.download-count",
                    defaultValue: "%d",
                    comment: "Download count value shown in dataset search results"
                ), dataset.downloads ?? 0)).font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .background(isSelected ? WorkbenchTheme.accent.opacity(0.14) : Color.clear, in: RoundedRectangle(cornerRadius: WorkbenchTheme.cornerRadius, style: .continuous))
    }
}
