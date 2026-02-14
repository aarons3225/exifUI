import Foundation
import UniformTypeIdentifiers

/// Represents a media file that can be inspected and edited.
struct MediaFile: Identifiable, Hashable {
    let id: UUID
    let url: URL

    var name: String { url.lastPathComponent }
    var path: String { url.path }
    var fileExtension: String { url.pathExtension.lowercased() }

    var fileType: FileType {
        FileType.from(extension: fileExtension)
    }

    /// SF Symbol name appropriate for this file type.
    var systemImage: String {
        switch fileType {
        case .jpeg, .png, .tiff, .heic, .raw, .gif, .bmp, .webp:
            return "photo"
        case .mp4, .mov, .avi, .mkv:
            return "film"
        case .mp3, .aac, .wav, .flac:
            return "music.note"
        case .pdf:
            return "doc.richtext"
        case .unknown:
            return "doc"
        }
    }

    init(url: URL) {
        self.id = UUID()
        self.url = url
    }
}

// MARK: - File Type Classification

enum FileType: String, CaseIterable {
    // Images
    case jpeg, png, tiff, heic, raw, gif, bmp, webp
    // Video
    case mp4, mov, avi, mkv
    // Audio
    case mp3, aac, wav, flac
    // Documents
    case pdf
    // Fallback
    case unknown

    var isImage: Bool {
        switch self {
        case .jpeg, .png, .tiff, .heic, .raw, .gif, .bmp, .webp: return true
        default: return false
        }
    }

    var isVideo: Bool {
        switch self {
        case .mp4, .mov, .avi, .mkv: return true
        default: return false
        }
    }

    var isAudio: Bool {
        switch self {
        case .mp3, .aac, .wav, .flac: return true
        default: return false
        }
    }

    static func from(extension ext: String) -> FileType {
        let mapping: [String: FileType] = [
            "jpg": .jpeg, "jpeg": .jpeg,
            "png": .png,
            "tif": .tiff, "tiff": .tiff,
            "heic": .heic, "heif": .heic,
            "cr2": .raw, "cr3": .raw, "nef": .raw, "arw": .raw,
            "dng": .raw, "orf": .raw, "rw2": .raw, "raf": .raw,
            "gif": .gif,
            "bmp": .bmp,
            "webp": .webp,
            "mp4": .mp4, "m4v": .mp4,
            "mov": .mov,
            "avi": .avi,
            "mkv": .mkv,
            "mp3": .mp3,
            "aac": .aac, "m4a": .aac,
            "wav": .wav,
            "flac": .flac,
            "pdf": .pdf,
        ]
        return mapping[ext.lowercased()] ?? .unknown
    }

    /// Supported file extensions for the open panel.
    static var supportedExtensions: [String] {
        [
            "jpg", "jpeg", "png", "tif", "tiff", "heic", "heif",
            "cr2", "cr3", "nef", "arw", "dng", "orf", "rw2", "raf",
            "gif", "bmp", "webp",
            "mp4", "m4v", "mov", "avi", "mkv",
            "mp3", "aac", "m4a", "wav", "flac",
            "pdf",
        ]
    }

    /// UTTypes for the open panel.
    static var supportedContentTypes: [UTType] {
        [.image, .movie, .audio, .pdf]
    }
}
