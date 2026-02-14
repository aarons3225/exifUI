import Foundation
import SwiftUI

/// Central application state, shared across the app via the environment.
///
/// Uses the @Observable macro (Swift 5.9+) for automatic SwiftUI updates.
@Observable
final class AppState {

    // MARK: - Services

    let exifToolService = ExifToolService()

    // MARK: - File State

    /// Files currently loaded in the sidebar.
    var files: [MediaFile] = []

    /// The currently selected file.
    var selectedFile: MediaFile?

    /// Metadata for the currently selected file.
    var metadata: [MetadataItem] = []

    /// Whether metadata is currently being loaded.
    var isLoadingMetadata = false

    /// The most recent error, displayed in an alert.
    var currentError: ExifToolError?

    /// Whether the error alert is shown.
    var showErrorAlert = false

    // MARK: - Search & Filter

    /// Search text for filtering metadata tags.
    var metadataSearchText = ""

    /// The selected metadata group filter.
    var selectedGroup: MetadataGroup = .all

    /// Metadata filtered by search text and selected group.
    var filteredMetadata: [MetadataItem] {
        var result = metadata

        if selectedGroup != .all {
            result = result.filter {
                MetadataGroup.from($0.group) == selectedGroup
            }
        }

        if !metadataSearchText.isEmpty {
            let query = metadataSearchText.lowercased()
            result = result.filter {
                $0.tagName.lowercased().contains(query) ||
                $0.description.lowercased().contains(query) ||
                $0.value.lowercased().contains(query) ||
                $0.group.lowercased().contains(query)
            }
        }

        return result
    }

    /// Whether any metadata items have been modified.
    var hasUnsavedChanges: Bool {
        metadata.contains { $0.isModified }
    }

    /// Count of modified items.
    var modifiedCount: Int {
        metadata.filter { $0.isModified }.count
    }

    // MARK: - Editor State

    /// The metadata item currently being edited.
    var editingItem: MetadataItem?

    /// Whether the editor sheet is shown.
    var showEditor = false

    /// Whether the add metadata sheet is shown.
    var showAddMetadata = false

    /// New tag name being added.
    var newTagName = ""

    /// New tag value being added.
    var newTagValue = ""

    // MARK: - Batch Edit State

    /// Files selected for batch editing (multi-select in sidebar).
    var selectedFileIDs: Set<MediaFile.ID> = []

    /// Whether the batch edit sheet is shown.
    var showBatchEdit = false

    /// Files resolved for batch operations.
    var batchFiles: [MediaFile] {
        files.filter { selectedFileIDs.contains($0.id) }
    }

    /// Whether multiple files are selected for batch operations.
    var hasBatchSelection: Bool {
        selectedFileIDs.count > 1
    }

    // MARK: - File Operations

    /// Adds files from URLs — handles both files and folders.
    ///
    /// Uses FolderScanner to recursively resolve folder contents.
    func addFiles(_ urls: [URL]) {
        // Resolve folders into individual file URLs
        let resolvedURLs = FolderScanner.resolveURLs(urls)

        let newFiles = resolvedURLs
            .filter { url in
                !files.contains { $0.url == url }
            }
            .map { MediaFile(url: $0) }

        files.append(contentsOf: newFiles)

        // Auto-select the first file if nothing is selected
        if selectedFile == nil, let first = files.first {
            selectFile(first)
        }
    }

    /// Removes files from the sidebar.
    func removeFiles(_ fileIDs: Set<MediaFile.ID>) {
        files.removeAll { fileIDs.contains($0.id) }
        selectedFileIDs.subtract(fileIDs)

        if let selected = selectedFile, fileIDs.contains(selected.id) {
            selectedFile = files.first
            if let newSelection = selectedFile {
                Task { await loadMetadata(for: newSelection) }
            } else {
                metadata = []
            }
        }
    }

    /// Clears all loaded files.
    func clearFiles() {
        files = []
        selectedFile = nil
        selectedFileIDs = []
        metadata = []
        metadataSearchText = ""
        selectedGroup = .all
    }

    /// Selects a file and loads its metadata.
    func selectFile(_ file: MediaFile) {
        selectedFile = file
        Task { await loadMetadata(for: file) }
    }

    // MARK: - Metadata Operations

    /// Loads metadata for a given file.
    @MainActor
    func loadMetadata(for file: MediaFile) async {
        isLoadingMetadata = true
        metadataSearchText = ""
        selectedGroup = .all

        do {
            metadata = try await exifToolService.readMetadata(from: file.url)
        } catch let error as ExifToolError {
            metadata = []
            presentError(error)
        } catch {
            metadata = []
            presentError(.executionFailed(error.localizedDescription))
        }

        isLoadingMetadata = false
    }

    /// Saves all modified metadata back to the file.
    @MainActor
    func saveMetadata(overwriteOriginal: Bool = false) async {
        guard let file = selectedFile else { return }

        do {
            try await exifToolService.writeMetadata(
                metadata,
                to: file.url,
                overwriteOriginal: overwriteOriginal
            )

            // Reload metadata to reflect the saved state
            await loadMetadata(for: file)
        } catch let error as ExifToolError {
            presentError(error)
        } catch {
            presentError(.executionFailed(error.localizedDescription))
        }
    }

    /// Strips all metadata from the current file.
    @MainActor
    func stripAllMetadata(overwriteOriginal: Bool = false) async {
        guard let file = selectedFile else { return }

        do {
            try await exifToolService.stripAllMetadata(
                from: file.url,
                overwriteOriginal: overwriteOriginal
            )
            await loadMetadata(for: file)
        } catch let error as ExifToolError {
            presentError(error)
        } catch {
            presentError(.executionFailed(error.localizedDescription))
        }
    }

    /// Restores the original file from the _original backup.
    @MainActor
    func restoreOriginal() async {
        guard let file = selectedFile else { return }

        do {
            try await exifToolService.restoreOriginal(for: file.url)
            await loadMetadata(for: file)
        } catch let error as ExifToolError {
            presentError(error)
        } catch {
            presentError(.executionFailed(error.localizedDescription))
        }
    }

    /// Updates a metadata item's value (in-memory only until saved).
    func updateMetadataValue(id: MetadataItem.ID, newValue: String) {
        guard let index = metadata.firstIndex(where: { $0.id == id }) else { return }
        metadata[index].value = newValue
    }

    /// Adds a new metadata tag with the given name and value.
    @MainActor
    func addMetadataTag(tagName: String, value: String) async {
        guard let file = selectedFile else { return }
        guard !tagName.isEmpty else { return }

        do {
            // Write the new tag to the file using exiftool
            try await exifToolService.writeTag(tagName: tagName, value: value, to: file.url)

            // Reload metadata to show the new tag
            await loadMetadata(for: file)

            // Clear the form
            newTagName = ""
            newTagValue = ""
            showAddMetadata = false
        } catch let error as ExifToolError {
            presentError(error)
        } catch {
            presentError(.executionFailed(error.localizedDescription))
        }
    }

    // MARK: - Error Handling

    func presentError(_ error: ExifToolError) {
        currentError = error
        showErrorAlert = true
    }
}

// MARK: - Environment Key

private struct AppStateKey: EnvironmentKey {
    static let defaultValue = AppState()
}

extension EnvironmentValues {
    var appState: AppState {
        get { self[AppStateKey.self] }
        set { self[AppStateKey.self] = newValue }
    }
}
