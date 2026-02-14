import SwiftUI
import UniformTypeIdentifiers

/// File list sidebar following Apple HIG sidebar patterns.
///
/// Features:
/// - File list with icons and names
/// - Multi-selection for batch operations (⌘-click, ⇧-click)
/// - Drag-and-drop to add files and folders
/// - Context menus for file operations
/// - Batch edit access from the sidebar
/// - Empty state with drop target
struct SidebarView: View {
    @Environment(\.appState) private var appState
    @State private var isDropTargeted = false

    var body: some View {
        @Bindable var state = appState

        Group {
            if appState.files.isEmpty {
                SidebarEmptyState(isDropTargeted: isDropTargeted)
            } else {
                fileList
            }
        }
        .safeAreaInset(edge: .bottom) {
            sidebarFooter
        }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers)
        }
        .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 350)
    }

    // MARK: - File List

    private var fileList: some View {
        @Bindable var state = appState

        return List(selection: $state.selectedFileIDs) {
            ForEach(appState.files) { file in
                FileRowView(
                    file: file,
                    isSelected: appState.selectedFileIDs.contains(file.id)
                )
                .tag(file.id)
                .contextMenu {
                    fileContextMenu(for: file)
                }
            }
            .onDelete { indexSet in
                let ids = Set(indexSet.map { appState.files[$0].id })
                appState.removeFiles(ids)
            }
        }
        .listStyle(.sidebar)
        .onChange(of: appState.selectedFileIDs) { _, newSelection in
            // When a single file is selected, show its metadata
            if newSelection.count == 1,
               let id = newSelection.first,
               let file = appState.files.first(where: { $0.id == id }) {
                appState.selectFile(file)
            }
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func fileContextMenu(for file: MediaFile) -> some View {
        Button {
            appState.selectFile(file)
        } label: {
            Label("Inspect Metadata", systemImage: "info.circle")
        }

        if appState.selectedFileIDs.count > 1 {
            Divider()

            Button {
                appState.showBatchEdit = true
            } label: {
                Label(
                    "Batch Edit \(appState.selectedFileIDs.count) Files…",
                    systemImage: "square.stack.3d.up.badge.automatic"
                )
            }
        }

        Divider()

        Button {
            NSWorkspace.shared.activateFileViewerSelecting([file.url])
        } label: {
            Label("Reveal in Finder", systemImage: "folder")
        }

        Button {
            NSWorkspace.shared.open(file.url)
        } label: {
            Label("Open with Default App", systemImage: "arrow.up.forward.app")
        }

        Divider()

        if appState.selectedFileIDs.count > 1 {
            Button(role: .destructive) {
                appState.removeFiles(appState.selectedFileIDs)
            } label: {
                Label(
                    "Remove \(appState.selectedFileIDs.count) Files",
                    systemImage: "xmark"
                )
            }
        } else {
            Button(role: .destructive) {
                appState.removeFiles([file.id])
            } label: {
                Label("Remove from List", systemImage: "xmark")
            }
        }
    }

    // MARK: - Footer

    private var sidebarFooter: some View {
        HStack {
            let selCount = appState.selectedFileIDs.count
            if selCount > 1 {
                Text("\(selCount) of \(appState.files.count) selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("\(appState.files.count) file\(appState.files.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !appState.files.isEmpty {
                if appState.selectedFileIDs.count > 1 {
                    Button {
                        appState.showBatchEdit = true
                    } label: {
                        Text("Batch Edit")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                }

                Button {
                    appState.clearFiles()
                } label: {
                    Text("Clear All")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
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
            // addFiles handles folders recursively via FolderScanner
            appState.addFiles(urls)
        }

        return true
    }
}

// MARK: - Sidebar Empty State

struct SidebarEmptyState: View {
    let isDropTargeted: Bool

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: isDropTargeted ? "square.and.arrow.down.fill" : "square.and.arrow.down")
                .font(.system(size: 32))
                .foregroundStyle(isDropTargeted ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.tertiary))
                .scaleEffect(isDropTargeted ? 1.15 : 1.0)
                .animation(.spring(response: 0.3), value: isDropTargeted)

            Text("Drop Files Here")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Files and folders accepted")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    isDropTargeted ? Color.accentColor : Color.clear,
                    style: StrokeStyle(lineWidth: 2, dash: [6])
                )
                .padding(8)
        )
        .animation(.easeInOut(duration: 0.2), value: isDropTargeted)
    }
}
