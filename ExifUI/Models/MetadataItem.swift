import Foundation

/// Represents a single metadata tag read from or written to a file via exiftool.
struct MetadataItem: Identifiable, Hashable {
    let id = UUID()

    /// The metadata group (e.g., "EXIF", "IPTC", "XMP", "File").
    var group: String

    /// The tag name (e.g., "DateTimeOriginal", "Make", "Model").
    var tagName: String

    /// A human-readable description of the tag (e.g., "Date/Time Original").
    var description: String

    /// The current value as a string.
    var value: String

    /// Whether this tag is writable by exiftool.
    var isWritable: Bool

    /// The original value before any edits, used for change tracking.
    var originalValue: String

    /// Whether the value has been modified by the user.
    var isModified: Bool {
        value != originalValue
    }
}

// MARK: - Convenience Initializers

extension MetadataItem {
    /// Creates a MetadataItem from exiftool JSON output fields.
    init(group: String, tagName: String, description: String, value: String, isWritable: Bool = true) {
        self.group = group
        self.tagName = tagName
        self.description = description
        self.value = value
        self.isWritable = isWritable
        self.originalValue = value
    }
}

// MARK: - Metadata Group

/// Well-known metadata groups for filtering and display.
enum MetadataGroup: String, CaseIterable, Identifiable {
    case all = "All"
    case exif = "EXIF"
    case iptc = "IPTC"
    case xmp = "XMP"
    case file = "File"
    case system = "System"
    case composite = "Composite"
    case makernotes = "MakerNotes"
    case quicktime = "QuickTime"
    case other = "Other"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .all: return "list.bullet"
        case .exif: return "camera"
        case .iptc: return "newspaper"
        case .xmp: return "tag"
        case .file: return "doc"
        case .system: return "gearshape"
        case .composite: return "square.stack.3d.up"
        case .makernotes: return "wrench.and.screwdriver"
        case .quicktime: return "film"
        case .other: return "ellipsis.circle"
        }
    }

    /// Maps a raw group string from exiftool to a known group.
    static func from(_ rawGroup: String) -> MetadataGroup {
        let normalized = rawGroup.lowercased()
        if normalized.contains("exif") { return .exif }
        if normalized.contains("iptc") { return .iptc }
        if normalized.contains("xmp") { return .xmp }
        if normalized == "file" { return .file }
        if normalized == "system" { return .system }
        if normalized.contains("composite") { return .composite }
        if normalized.contains("makernotes") || normalized.contains("maker") { return .makernotes }
        if normalized.contains("quicktime") { return .quicktime }
        return .other
    }
}
