import SwiftUI
import UniformTypeIdentifiers

/// The root view using a NavigationSplitView layout.
///
/// Follows Apple HIG for macOS:
/// - Sidebar for file navigation with multi-select
/// - Content area for metadata inspection
/// - Toolbar for primary actions
/// - Searchable metadata with group filtering
/// - Full-window drag-and-drop for files and folders
struct ContentView: View {
    @Environment(\.appState) private var appState
    @State private var isDropTargeted = false

    var body: some View {
        @Bindable var state = appState

        NavigationSplitView {
            SidebarView()
                .environment(\.appState, appState)
        } detail: {
            if appState.selectedFile != nil {
                DetailView()
                    .environment(\.appState, appState)
            } else {
                EmptyStateView()
                    .environment(\.appState, appState)
            }
        }
        .searchable(
            text: $state.metadataSearchText,
            placement: .toolbar,
            prompt: "Filter metadata tags…"
        )
        .navigationTitle("")
        .toolbar {
            MainToolbar(appState: appState)
        }
        .alert(
            "Error",
            isPresented: $state.showErrorAlert,
            presenting: appState.currentError
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { error in
            Text(error.localizedDescription)
        }
        .sheet(isPresented: $state.showEditor) {
            if let item = appState.editingItem {
                MetadataEditorSheet(item: item)
                    .environment(\.appState, appState)
            }
        }
        .sheet(isPresented: $state.showAddMetadata) {
            AddMetadataSheet()
                .environment(\.appState, appState)
        }
        .sheet(isPresented: $state.showBatchEdit) {
            BatchEditView(files: appState.batchFiles.isEmpty ? appState.files : appState.batchFiles)
                .environment(\.appState, appState)
        }
        .overlay {
            if isDropTargeted {
                dropOverlay
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers)
        }
    }

    // MARK: - Drop Overlay

    /// A full-window overlay shown when dragging files over the app.
    private var dropOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                Image(systemName: "square.and.arrow.down.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.white)

                Text("Drop files or folders")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)

                Text("Folders will be scanned recursively for supported media files.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )
        }
        .animation(.easeInOut(duration: 0.15), value: isDropTargeted)
    }

    // MARK: - Drop Handling

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var urls: [URL] = []

        let group = DispatchGroup()
        for provider in providers {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    urls.append(url)
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            // addFiles now handles both files and folders via FolderScanner
            appState.addFiles(urls)
        }

        return true
    }
}

// MARK: - Empty State

/// Shown when no file is selected, following Apple HIG empty state patterns.
struct EmptyStateView: View {
    @Environment(\.appState) private var appState
    @State private var isDropTargeted = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 56))
                .foregroundStyle(isDropTargeted ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.tertiary))
                .scaleEffect(isDropTargeted ? 1.1 : 1.0)
                .animation(.spring(response: 0.3), value: isDropTargeted)

            Text("No File Selected")
                .font(.title2)
                .foregroundStyle(.secondary)

            Text("Open files, drop them here, or drag entire folders\nto view their metadata.")
                .font(.body)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 340)

            HStack(spacing: 12) {
                Button {
                    openFiles()
                } label: {
                    Label("Open Files…", systemImage: "doc.badge.plus")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button {
                    openFolder()
                } label: {
                    Label("Open Folder…", systemImage: "folder.badge.plus")
                }
                .controlSize(.large)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            var urls: [URL] = []
            let group = DispatchGroup()
            for provider in providers {
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    if let data = item as? Data,
                       let url = URL(dataRepresentation: data, relativeTo: nil) {
                        urls.append(url)
                    }
                    group.leave()
                }
            }
            group.notify(queue: .main) {
                appState.addFiles(urls)
            }
            return true
        }
    }

    private func openFiles() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = FileType.supportedContentTypes

        if panel.runModal() == .OK {
            appState.addFiles(panel.urls)
        }
    }

    private func openFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true

        if panel.runModal() == .OK {
            appState.addFiles(panel.urls)
        }
    }
}

// MARK: - Main Toolbar

/// Toolbar items following Apple HIG placement conventions.
struct MainToolbar: ToolbarContent {
    let appState: AppState

    var body: some ToolbarContent {
        // Leading: file operations
        ToolbarItem(placement: .primaryAction) {
            Button {
                openFiles()
            } label: {
                Label("Open", systemImage: "plus")
            }
            .help("Open files or folders (⌘O)")
        }

        // Metadata group filter
        ToolbarItem(placement: .principal) {
            if appState.selectedFile != nil {
                GroupFilterPicker(appState: appState)
            }
        }

        // Trailing: save and actions
        ToolbarItemGroup(placement: .automatic) {
            if appState.hasUnsavedChanges {
                Button {
                    Task { await appState.saveMetadata() }
                } label: {
                    Label("Save", systemImage: "square.and.arrow.down")
                }
                .help("Save changes (⌘S)")

                Button {
                    if let file = appState.selectedFile {
                        Task { await appState.loadMetadata(for: file) }
                    }
                } label: {
                    Label("Revert", systemImage: "arrow.uturn.backward")
                }
                .help("Discard changes")
            }

            // Batch edit button
            if appState.files.count > 1 {
                Button {
                    if !appState.hasBatchSelection {
                        appState.selectedFileIDs = Set(appState.files.map(\.id))
                    }
                    appState.showBatchEdit = true
                } label: {
                    Label("Batch Edit", systemImage: "square.stack.3d.up.badge.automatic")
                }
                .help("Batch edit metadata (⇧⌘B)")
            }

            if appState.selectedFile != nil {
                Menu {
                    Button {
                        Task { await appState.stripAllMetadata() }
                    } label: {
                        Label("Strip All Metadata", systemImage: "trash")
                    }

                    Button {
                        Task { await appState.restoreOriginal() }
                    } label: {
                        Label("Restore Original", systemImage: "arrow.uturn.backward.circle")
                    }

                    Divider()

                    Button {
                        if let file = appState.selectedFile {
                            Task { await appState.loadMetadata(for: file) }
                        }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                } label: {
                    Label("Actions", systemImage: "ellipsis.circle")
                }
                .help("More actions")
            }
        }
    }

    private func openFiles() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = FileType.supportedContentTypes

        if panel.runModal() == .OK {
            appState.addFiles(panel.urls)
        }
    }
}

// MARK: - Group Filter Picker

/// Segmented-style picker for metadata groups, shown in the toolbar.
struct GroupFilterPicker: View {
    let appState: AppState

    /// Only show groups that have data.
    private var availableGroups: [MetadataGroup] {
        var groups: [MetadataGroup] = [.all]
        let presentGroups = Set(appState.metadata.map { MetadataGroup.from($0.group) })
        groups.append(contentsOf: MetadataGroup.allCases.filter {
            $0 != .all && presentGroups.contains($0)
        })
        return groups
    }

    var body: some View {
        @Bindable var state = appState

        Picker("Group", selection: $state.selectedGroup) {
            ForEach(availableGroups) { group in
                Label(group.rawValue, systemImage: group.systemImage)
                    .tag(group)
            }
        }
        .pickerStyle(.menu)
        .frame(maxWidth: 180)
    }
}
