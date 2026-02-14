import SwiftUI
import AVKit

/// Displays a preview of the selected media file.
///
/// - Images: Shown using native NSImage for reliable local file loading
/// - Videos: Shown using AVKit VideoPlayer with proper player retention
/// - Other files: Shows a file icon placeholder
struct MediaPreviewView: View {
    let file: MediaFile

    var body: some View {
        Group {
            switch file.fileType {
            case _ where file.fileType.isImage:
                imagePreview
            case _ where file.fileType.isVideo:
                VideoPreviewWrapper(url: file.url)
            default:
                genericPreview
            }
        }
        .accessibilityLabel("Preview of \(file.name)")
    }

    // MARK: - Image Preview

    private var imagePreview: some View {
        Group {
            if let nsImage = NSImage(contentsOf: file.url) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .padding(8)
            } else {
                fallbackPreview(message: "Unable to load image")
            }
        }
    }

    // MARK: - Generic Preview

    private var genericPreview: some View {
        fallbackPreview(message: file.fileType.rawValue.uppercased())
    }

    private func fallbackPreview(message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: file.systemImage)
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)

            Text(message)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Video Preview

/// A wrapper that properly retains the AVPlayer instance via @State.
struct VideoPreviewWrapper: View {
    let url: URL
    @State private var player: AVPlayer?

    var body: some View {
        Group {
            if let player {
                VideoPlayer(player: player)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .padding(8)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            player = AVPlayer(url: url)
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
        .onChange(of: url) { _, newURL in
            player?.pause()
            player = AVPlayer(url: newURL)
        }
    }
}
