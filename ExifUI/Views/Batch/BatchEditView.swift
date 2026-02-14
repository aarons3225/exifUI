import SwiftUI

/// A sheet for applying metadata changes across multiple files at once.
///
/// Supports three batch operations:
/// 1. Set tags — apply specific tag values to all selected files
/// 2. Strip metadata — remove all metadata from selected files
/// 3. Copy tags — copy metadata from one file to the others
///
/// Follows Apple HIG sheet patterns with a progress view for long operations.
struct BatchEditView: View {
    @Environment(\.appState) private var appState
    @Environment(\.dismiss) private var dismiss

    let files: [MediaFile]

    @State private var selectedOperation: BatchOperation = .setTags
    @State private var tagEntries: [TagEntry] = [TagEntry()]
    @State private var copySourceFile: MediaFile?
    @State private var overwriteOriginal = false
    @State private var isProcessing = false
    @State private var progress: Double = 0
    @State private var results: [ExifToolService.BatchResult] = []
    @State private var showResults = false

    var body: some View {
        VStack(spacing: 0) {
            sheetHeader
            Divider()

            if showResults {
                resultsView
            } else if isProcessing {
                processingView
            } else {
                configurationView
            }

            Divider()
            sheetFooter
        }
        .frame(width: 560, height: 500)
    }

    // MARK: - Header

    private var sheetHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Batch Edit")
                    .font(.headline)

                Text("\(files.count) file\(files.count == 1 ? "" : "s") selected")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
        }
        .padding(16)
    }

    // MARK: - Configuration

    private var configurationView: some View {
        Form {
            // Operation picker
            Section {
                Picker("Operation", selection: $selectedOperation) {
                    ForEach(BatchOperation.allCases) { op in
                        Label(op.label, systemImage: op.systemImage)
                            .tag(op)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Operation")
            }

            // Operation-specific UI
            switch selectedOperation {
            case .setTags:
                setTagsSection
            case .stripAll:
                stripAllSection
            case .copyTags:
                copyTagsSection
            }

            // Options
            Section {
                Toggle("Overwrite original files (no backup)", isOn: $overwriteOriginal)

                if !overwriteOriginal {
                    Label(
                        "Originals will be saved with '_original' suffix.",
                        systemImage: "info.circle"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            } header: {
                Text("Options")
            }

            // Files preview
            Section {
                ForEach(files.prefix(8)) { file in
                    HStack(spacing: 8) {
                        Image(systemName: file.systemImage)
                            .foregroundStyle(.secondary)
                        Text(file.name)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .font(.caption)
                }

                if files.count > 8 {
                    Text("… and \(files.count - 8) more")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            } header: {
                Text("Files")
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Set Tags Section

    private var setTagsSection: some View {
        Section {
            ForEach($tagEntries) { $entry in
                HStack(spacing: 8) {
                    TextField("Tag name", text: $entry.tagName)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 180)

                    TextField("Value", text: $entry.value)
                        .textFieldStyle(.roundedBorder)

                    Button {
                        if let index = tagEntries.firstIndex(where: { $0.id == entry.id }) {
                            tagEntries.remove(at: index)
                        }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .disabled(tagEntries.count <= 1)
                }
            }

            Button {
                tagEntries.append(TagEntry())
            } label: {
                Label("Add Tag", systemImage: "plus")
            }
            .buttonStyle(.borderless)
        } header: {
            Text("Tags to Set")
        } footer: {
            Text("Use exiftool tag names (e.g., Artist, Copyright, DateTimeOriginal). Leave value empty to remove the tag.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Strip All Section

    private var stripAllSection: some View {
        Section {
            Label(
                "This will remove ALL metadata from the selected files.",
                systemImage: "exclamationmark.triangle.fill"
            )
            .foregroundStyle(.orange)
        } header: {
            Text("Warning")
        }
    }

    // MARK: - Copy Tags Section

    private var copyTagsSection: some View {
        Section {
            Picker("Copy from", selection: $copySourceFile) {
                Text("Select a source file…")
                    .tag(nil as MediaFile?)

                ForEach(files) { file in
                    Text(file.name)
                        .tag(file as MediaFile?)
                }
            }

            if let source = copySourceFile {
                Label(
                    "Tags from \"\(source.name)\" will be copied to all other files.",
                    systemImage: "info.circle"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        } header: {
            Text("Source File")
        }
    }

    // MARK: - Processing View

    private var processingView: some View {
        VStack(spacing: 16) {
            Spacer()

            ProgressView(value: progress) {
                Text("Processing files…")
            } currentValueLabel: {
                Text("\(Int(progress * Double(files.count))) of \(files.count)")
            }
            .progressViewStyle(.linear)
            .frame(maxWidth: 300)

            Text("Please wait while changes are applied.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(32)
    }

    // MARK: - Results View

    private var resultsView: some View {
        VStack(spacing: 0) {
            // Summary bar
            HStack {
                let successCount = results.filter(\.success).count
                let failCount = results.filter({ !$0.success }).count

                Label("\(successCount) succeeded", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)

                if failCount > 0 {
                    Label("\(failCount) failed", systemImage: "xmark.circle.fill")
                        .foregroundStyle(.red)
                }

                Spacer()
            }
            .font(.subheadline)
            .padding(12)
            .background(.bar)

            Divider()

            // Results list
            List(results) { result in
                HStack(spacing: 10) {
                    Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(result.success ? .green : .red)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(result.fileName)
                            .font(.body)
                            .lineLimit(1)

                        Text(result.message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
            }
            .listStyle(.inset)
        }
    }

    // MARK: - Footer

    private var sheetFooter: some View {
        HStack {
            if showResults {
                Spacer()

                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            } else {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Apply to All Files") {
                    Task { await executeOperation() }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(!isOperationValid || isProcessing)
            }
        }
        .padding(16)
    }

    // MARK: - Validation

    private var isOperationValid: Bool {
        switch selectedOperation {
        case .setTags:
            return tagEntries.contains { !$0.tagName.isEmpty }
        case .stripAll:
            return true
        case .copyTags:
            return copySourceFile != nil
        }
    }

    // MARK: - Execution

    @MainActor
    private func executeOperation() async {
        isProcessing = true
        progress = 0

        let service = appState.exifToolService

        do {
            switch selectedOperation {
            case .setTags:
                var tags: [String: String] = [:]
                for entry in tagEntries where !entry.tagName.isEmpty {
                    tags[entry.tagName] = entry.value
                }
                results = try await service.batchWriteMetadata(
                    tags: tags,
                    to: files.map(\.url),
                    overwriteOriginal: overwriteOriginal
                )

            case .stripAll:
                results = try await service.batchStripMetadata(
                    from: files.map(\.url),
                    overwriteOriginal: overwriteOriginal
                )

            case .copyTags:
                if let source = copySourceFile {
                    let destinations = files.filter { $0.id != source.id }.map(\.url)
                    results = try await service.batchCopyMetadata(
                        from: source.url,
                        to: destinations,
                        overwriteOriginal: overwriteOriginal
                    )
                }
            }
        } catch {
            results = [ExifToolService.BatchResult(
                url: URL(fileURLWithPath: "/"),
                success: false,
                message: error.localizedDescription
            )]
        }

        isProcessing = false
        showResults = true

        // Reload current file's metadata if it was affected
        if let current = appState.selectedFile {
            await appState.loadMetadata(for: current)
        }
    }
}

// MARK: - Supporting Types

enum BatchOperation: String, CaseIterable, Identifiable {
    case setTags = "set"
    case stripAll = "strip"
    case copyTags = "copy"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .setTags: return "Set Tags"
        case .stripAll: return "Strip All"
        case .copyTags: return "Copy Tags"
        }
    }

    var systemImage: String {
        switch self {
        case .setTags: return "pencil"
        case .stripAll: return "trash"
        case .copyTags: return "doc.on.doc"
        }
    }
}

struct TagEntry: Identifiable {
    let id = UUID()
    var tagName: String = ""
    var value: String = ""
}
