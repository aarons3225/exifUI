import SwiftUI

/// The main detail area showing file preview and metadata.
///
/// Uses a vertical split with:
/// - Media preview at the top (collapsible)
/// - Metadata table below
/// Follows Apple HIG patterns for inspector-style layouts.
struct DetailView: View {
    @Environment(\.appState) private var appState
    @State private var showPreview = true
    @State private var previewHeight: CGFloat = 250

    var body: some View {
        VStack(spacing: 0) {
            // File info header
            fileInfoHeader

            Divider()

            if showPreview, let file = appState.selectedFile {
                // Media preview
                MediaPreviewView(file: file)
                    .frame(height: previewHeight)
                    .frame(maxWidth: .infinity)
                    .background(.black.opacity(0.03))

                Divider()
            }

            // Metadata table
            if appState.isLoadingMetadata {
                loadingView
            } else if appState.filteredMetadata.isEmpty {
                noMetadataView
            } else {
                MetadataTableView()
            }
        }
    }

    // MARK: - File Info Header

    private var fileInfoHeader: some View {
        HStack(spacing: 12) {
            if let file = appState.selectedFile {
                Image(systemName: file.systemImage)
                    .font(.title2)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(file.name)
                        .font(.headline)
                        .lineLimit(1)

                    Text(file.url.deletingLastPathComponent().path)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                Spacer()

                // Tag count and modification status
                HStack(spacing: 8) {
                    if appState.hasUnsavedChanges {
                        Label("\(appState.modifiedCount) modified", systemImage: "pencil.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    Text("\(appState.metadata.count) tags")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Add new tag button
                Button {
                    appState.showAddMetadata = true
                } label: {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.borderless)
                .help("Add new metadata tag")

                // Toggle preview
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showPreview.toggle()
                    }
                } label: {
                    Image(systemName: showPreview ? "eye.fill" : "eye.slash")
                }
                .buttonStyle(.borderless)
                .help(showPreview ? "Hide preview" : "Show preview")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    // MARK: - Loading & Empty States

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)

            Text("Reading metadata…")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noMetadataView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)

            if appState.metadataSearchText.isEmpty && appState.selectedGroup == .all {
                Text("No metadata found")
                    .font(.body)
                    .foregroundStyle(.secondary)
            } else {
                Text("No matching tags")
                    .font(.body)
                    .foregroundStyle(.secondary)

                Text("Try a different search term or group filter.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
