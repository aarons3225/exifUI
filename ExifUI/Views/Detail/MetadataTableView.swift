import SwiftUI

/// A clean table of metadata tags with tag names and values.
///
/// Displays metadata in a simple two-column table:
/// - Tag name column (left)
/// - Value column (right)
/// - Context menus for actions
struct MetadataTableView: View {
    @Environment(\.appState) private var appState
    @State private var sortOrder = [KeyPathComparator(\MetadataItem.tagName)]
    @State private var selectedItemIDs: Set<MetadataItem.ID> = []

    var body: some View {
        Table(of: MetadataItem.self, selection: $selectedItemIDs, sortOrder: $sortOrder) {
            // Tag name column
            TableColumn("Tag", value: \.tagName) { item in
                HStack(spacing: 6) {
                    Text(item.description)
                        .lineLimit(1)
                        .foregroundStyle(item.isModified ? .orange : .primary)
                        .fontWeight(item.isModified ? .semibold : .regular)

                    if item.isModified {
                        Image(systemName: "pencil.circle.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)
                            .help("Modified (was: \(item.originalValue))")
                    }
                }
            }
            .width(min: 180, ideal: 250, max: 350)

            // Value column - just the plain string value
            TableColumn("Value", value: \.value) { item in
                HStack(spacing: 8) {
                    Text(item.value)
                        .textSelection(.enabled)
                        .lineLimit(3)

                    Spacer()

                    if item.isWritable {
                        Button {
                            appState.editingItem = item
                            appState.showEditor = true
                        } label: {
                            Image(systemName: "pencil")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.borderless)
                        .help("Edit this value")
                    }
                }
            }
            .width(min: 200, ideal: 400)

        } rows: {
            ForEach(sortedMetadata) { item in
                TableRow(item)
                    .contextMenu {
                        rowContextMenu(for: item)
                    }
            }
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .onChange(of: sortOrder) { _, newOrder in
            _ = newOrder
        }
    }

    // MARK: - Sorted Data

    private var sortedMetadata: [MetadataItem] {
        appState.filteredMetadata.sorted(using: sortOrder)
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func rowContextMenu(for item: MetadataItem) -> some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(item.value, forType: .string)
        } label: {
            Label("Copy Value", systemImage: "doc.on.doc")
        }

        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString("\(item.tagName): \(item.value)", forType: .string)
        } label: {
            Label("Copy Tag & Value", systemImage: "doc.on.clipboard")
        }

        if item.isWritable {
            Divider()

            Button {
                appState.editingItem = item
                appState.showEditor = true
            } label: {
                Label("Edit Value…", systemImage: "pencil")
            }

            if item.isModified {
                Button {
                    appState.updateMetadataValue(id: item.id, newValue: item.originalValue)
                } label: {
                    Label("Revert to Original", systemImage: "arrow.uturn.backward")
                }
            }
        }
    }
}

// MARK: - Group Badge

/// A colored badge showing the metadata group name.
struct GroupBadge: View {
    let group: String

    var body: some View {
        let metadataGroup = MetadataGroup.from(group)

        Label(group, systemImage: metadataGroup.systemImage)
            .font(.caption)
            .foregroundStyle(groupColor)
            .lineLimit(1)
    }

    private var groupColor: Color {
        switch MetadataGroup.from(group) {
        case .exif: return .blue
        case .iptc: return .green
        case .xmp: return .orange
        case .file: return .secondary
        case .system: return .secondary
        case .composite: return .purple
        case .makernotes: return .pink
        case .quicktime: return .teal
        default: return .secondary
        }
    }
}

// MARK: - Metadata Value Cell

/// Displays a metadata value with modification indicator.
struct MetadataValueCell: View {
    @Environment(\.appState) private var appState
    let item: MetadataItem

    var body: some View {
        HStack(spacing: 6) {
            if item.isModified {
                Circle()
                    .fill(.orange)
                    .frame(width: 6, height: 6)
                    .help("Modified (was: \(item.originalValue))")
            }

            Text(item.value)
                .lineLimit(2)
                .foregroundStyle(item.isModified ? .primary : .primary)
                .fontWeight(item.isModified ? .medium : .regular)

            Spacer()

            if item.isWritable {
                Button {
                    appState.editingItem = item
                    appState.showEditor = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .opacity(0.6)
                .help("Edit this value")
            }
        }
    }
}
