import SwiftUI

/// A single file row in the sidebar list.
///
/// Shows:
/// - File type icon (SF Symbol)
/// - File name
/// - File extension badge
/// - Modification indicator when metadata has been changed
struct FileRowView: View {
    let file: MediaFile
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            // File type icon
            Image(systemName: file.systemImage)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(width: 24)

            // File name and extension
            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(.body)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(file.url.deletingLastPathComponent().lastPathComponent)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer()

            // File extension badge
            Text(file.fileExtension.uppercased())
                .font(.caption2)
                .fontWeight(.medium)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(.quaternary)
                )
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(file.name), \(file.fileType.rawValue) file")
    }

    private var iconColor: Color {
        switch file.fileType {
        case _ where file.fileType.isImage: return .blue
        case _ where file.fileType.isVideo: return .purple
        case _ where file.fileType.isAudio: return .pink
        default: return .secondary
        }
    }
}
