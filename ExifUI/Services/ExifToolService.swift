import Foundation

/// Errors that can occur when interacting with exiftool.
enum ExifToolError: LocalizedError {
    case notFound
    case executionFailed(String)
    case parsingFailed(String)
    case fileNotFound(URL)
    case writeProtected(String)

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "exiftool was not found. Please install it via Homebrew (brew install exiftool) or set the path in Settings."
        case .executionFailed(let message):
            return "exiftool failed: \(message)"
        case .parsingFailed(let message):
            return "Failed to parse exiftool output: \(message)"
        case .fileNotFound(let url):
            return "File not found: \(url.lastPathComponent)"
        case .writeProtected(let tag):
            return "Tag '\(tag)' is not writable."
        }
    }
}

/// Manages communication with the exiftool command-line tool.
///
/// Uses Swift Concurrency (async/await) for non-blocking operations.
/// Supports both bundled and system-installed exiftool binaries.
@Observable
final class ExifToolService {

    // MARK: - Properties

    /// The resolved path to the exiftool binary.
    private(set) var exifToolPath: String?

    /// Whether exiftool has been located and is available.
    var isAvailable: Bool { exifToolPath != nil }

    /// The version string of the located exiftool.
    private(set) var version: String?

    // MARK: - Initialization

    init() {
        Task {
            await locateExifTool()
        }
    }

    // MARK: - Locating exiftool

    /// Searches for exiftool in order of preference:
    /// 1. Bundled within the app
    /// 2. User-configured custom path
    /// 3. Common system locations
    func locateExifTool() async {
        let candidates = Self.candidatePaths()

        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                exifToolPath = path
                version = await fetchVersion(at: path)
                return
            }
        }

        exifToolPath = nil
        version = nil
    }

    /// Sets a custom path to the exiftool binary.
    func setCustomPath(_ path: String) async throws {
        guard FileManager.default.isExecutableFile(atPath: path) else {
            throw ExifToolError.executionFailed("File at \(path) is not executable.")
        }

        exifToolPath = path
        version = await fetchVersion(at: path)
    }

    /// Returns candidate paths to search for exiftool.
    private static func candidatePaths() -> [String] {
        var paths: [String] = []

        // 1. Bundled copy inside the app
        if let bundled = Bundle.main.path(forResource: "exiftool", ofType: nil) {
            paths.append(bundled)
        }

        // 2. User-configured path from UserDefaults
        if let custom = UserDefaults.standard.string(forKey: "exifToolCustomPath"),
           !custom.isEmpty {
            paths.append(custom)
        }

        // 3. Common system locations
        paths.append(contentsOf: [
            "/opt/homebrew/bin/exiftool",     // Apple Silicon Homebrew
            "/usr/local/bin/exiftool",        // Intel Homebrew / manual install
            "/usr/bin/exiftool",              // System install
            "/opt/local/bin/exiftool",        // MacPorts
        ])

        return paths
    }

    private func fetchVersion(at path: String) async -> String? {
        do {
            let output = try await execute(["-ver"], at: path)
            return output.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }

    // MARK: - Reading Metadata

    /// Reads all metadata from a file, returning structured items.
    func readMetadata(from url: URL) async throws -> [MetadataItem] {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ExifToolError.fileNotFound(url)
        }

        // Use JSON output with groups for structured parsing.
        // -G1 gives family 1 group names, -json gives JSON output,
        // -a allows duplicate tags, -u shows unknown tags.
        let output = try await execute([
            "-json", "-G1", "-a", "-s", "-D",
            url.path,
        ])

        return try parseJSONOutput(output)
    }

    /// Reads metadata for specific tags only.
    func readTags(_ tags: [String], from url: URL) async throws -> [MetadataItem] {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ExifToolError.fileNotFound(url)
        }

        var args = ["-json", "-G1", "-s"]
        args.append(contentsOf: tags.map { "-\($0)" })
        args.append(url.path)

        let output = try await execute(args)
        return try parseJSONOutput(output)
    }

    // MARK: - Writing Metadata

    /// Writes modified metadata items back to the file.
    /// Creates a backup (_original) by default.
    func writeMetadata(
        _ items: [MetadataItem],
        to url: URL,
        overwriteOriginal: Bool = false
    ) async throws {
        let modifiedItems = items.filter { $0.isModified }
        guard !modifiedItems.isEmpty else { return }

        var args: [String] = []

        if overwriteOriginal {
            args.append("-overwrite_original")
        }

        for item in modifiedItems {
            // Format: -Group:TagName=Value
            if item.value.isEmpty {
                // Empty value removes the tag
                args.append("-\(item.group):\(item.tagName)=")
            } else {
                args.append("-\(item.group):\(item.tagName)=\(item.value)")
            }
        }

        args.append(url.path)

        let output = try await execute(args)

        // Check for errors in the output
        if output.lowercased().contains("error") {
            throw ExifToolError.executionFailed(output)
        }
    }

    /// Writes a single tag to a file.
    /// Tag name can be in format "TagName" or "Group:TagName".
    func writeTag(tagName: String, value: String, to url: URL, overwriteOriginal: Bool = false) async throws {
        var args: [String] = []

        if !overwriteOriginal {
            // Keep the backup
            args.append("-overwrite_original_in_place")
        } else {
            args.append("-overwrite_original")
        }

        // Format: -TagName=Value or -Group:TagName=Value
        if value.isEmpty {
            args.append("-\(tagName)=")
        } else {
            args.append("-\(tagName)=\(value)")
        }

        args.append(url.path)

        let output = try await execute(args)

        // Check for errors in the output
        if output.lowercased().contains("error") {
            throw ExifToolError.executionFailed(output)
        }
    }

    /// Removes all metadata from a file.
    func stripAllMetadata(from url: URL, overwriteOriginal: Bool = false) async throws {
        var args = ["-all="]
        if overwriteOriginal {
            args.append("-overwrite_original")
        }
        args.append(url.path)

        let output = try await execute(args)
        if output.lowercased().contains("error") {
            throw ExifToolError.executionFailed(output)
        }
    }

    /// Restores a file from its _original backup.
    func restoreOriginal(for url: URL) async throws {
        let output = try await execute(["-restore_original", url.path])
        if output.lowercased().contains("error") {
            throw ExifToolError.executionFailed(output)
        }
    }

    // MARK: - Batch Operations

    /// Represents the result of a batch operation on a single file.
    struct BatchResult: Identifiable {
        let id = UUID()
        let url: URL
        var fileName: String { url.lastPathComponent }
        let success: Bool
        let message: String
    }

    /// Applies tag changes to multiple files in batch.
    /// Returns individual results per file for granular feedback.
    func batchWriteMetadata(
        tags: [String: String],
        to urls: [URL],
        overwriteOriginal: Bool = false
    ) async throws -> [BatchResult] {
        guard !tags.isEmpty && !urls.isEmpty else { return [] }

        var results: [BatchResult] = []

        for url in urls {
            do {
                var args: [String] = []
                if overwriteOriginal {
                    args.append("-overwrite_original")
                }

                for (tag, value) in tags {
                    if value.isEmpty {
                        args.append("-\(tag)=")
                    } else {
                        args.append("-\(tag)=\(value)")
                    }
                }

                args.append(url.path)
                let output = try await execute(args)

                if output.lowercased().contains("error") {
                    results.append(BatchResult(url: url, success: false, message: output.trimmingCharacters(in: .whitespacesAndNewlines)))
                } else {
                    results.append(BatchResult(url: url, success: true, message: "Updated successfully"))
                }
            } catch {
                results.append(BatchResult(url: url, success: false, message: error.localizedDescription))
            }
        }

        return results
    }

    /// Strips all metadata from multiple files.
    func batchStripMetadata(
        from urls: [URL],
        overwriteOriginal: Bool = false
    ) async throws -> [BatchResult] {
        var results: [BatchResult] = []

        for url in urls {
            do {
                try await stripAllMetadata(from: url, overwriteOriginal: overwriteOriginal)
                results.append(BatchResult(url: url, success: true, message: "Stripped all metadata"))
            } catch {
                results.append(BatchResult(url: url, success: false, message: error.localizedDescription))
            }
        }

        return results
    }

    /// Copies metadata from a source file to multiple destination files.
    func batchCopyMetadata(
        from sourceURL: URL,
        to destinationURLs: [URL],
        overwriteOriginal: Bool = false
    ) async throws -> [BatchResult] {
        var results: [BatchResult] = []

        for destURL in destinationURLs {
            do {
                var args = ["-tagsFromFile", sourceURL.path]
                if overwriteOriginal {
                    args.append("-overwrite_original")
                }
                args.append(destURL.path)

                let output = try await execute(args)
                if output.lowercased().contains("error") {
                    results.append(BatchResult(url: destURL, success: false, message: output.trimmingCharacters(in: .whitespacesAndNewlines)))
                } else {
                    results.append(BatchResult(url: destURL, success: true, message: "Tags copied"))
                }
            } catch {
                results.append(BatchResult(url: destURL, success: false, message: error.localizedDescription))
            }
        }

        return results
    }

    // MARK: - Process Execution

    /// Executes exiftool with the given arguments and returns stdout.
    private func execute(_ arguments: [String], at path: String? = nil) async throws -> String {
        guard let toolPath = path ?? exifToolPath else {
            throw ExifToolError.notFound
        }

        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: toolPath)
            process.arguments = arguments

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            do {
                try process.run()
                process.waitUntilExit()

                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

                let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
                let stderr = String(data: stderrData, encoding: .utf8) ?? ""

                if process.terminationStatus != 0 && !stderr.isEmpty {
                    // exiftool uses non-zero exit for warnings too, so only fail on real errors
                    if stderr.lowercased().contains("error") {
                        continuation.resume(throwing: ExifToolError.executionFailed(stderr))
                        return
                    }
                }

                continuation.resume(returning: stdout)
            } catch {
                continuation.resume(throwing: ExifToolError.executionFailed(error.localizedDescription))
            }
        }
    }

    // MARK: - JSON Parsing

    /// Parses exiftool's JSON output into MetadataItems.
    private func parseJSONOutput(_ json: String) throws -> [MetadataItem] {
        guard let data = json.data(using: .utf8) else {
            throw ExifToolError.parsingFailed("Invalid UTF-8 data")
        }

        guard let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let fileDict = array.first else {
            throw ExifToolError.parsingFailed("Expected JSON array with file object")
        }

        var items: [MetadataItem] = []

        for (key, rawValue) in fileDict {
            // Skip the SourceFile entry
            if key == "SourceFile" { continue }

            // Keys from -G1 -s look like "EXIF:Make" or "File:FileSize"
            let components = key.split(separator: ":", maxSplits: 1)
            let group: String
            let tagName: String

            if components.count == 2 {
                group = String(components[0])
                tagName = String(components[1])
            } else {
                group = "Other"
                tagName = key
            }

            let valueString: String
            if let stringVal = rawValue as? String {
                valueString = stringVal
            } else if let numberVal = rawValue as? NSNumber {
                valueString = numberVal.stringValue
            } else if let dict = rawValue as? [String: Any] {
                // Handle nested dictionary with "val" or "value" key
                if let val = dict["val"] {
                    if let strVal = val as? String {
                        valueString = strVal
                    } else if let numVal = val as? NSNumber {
                        valueString = numVal.stringValue
                    } else {
                        valueString = String(describing: val)
                    }
                } else if let value = dict["value"] {
                    if let strVal = value as? String {
                        valueString = strVal
                    } else if let numVal = value as? NSNumber {
                        valueString = numVal.stringValue
                    } else {
                        valueString = String(describing: value)
                    }
                } else {
                    // If no val/value key, try to stringify the dict nicely
                    valueString = String(describing: rawValue)
                }
            } else {
                valueString = String(describing: rawValue)
            }

            // Generate a human-readable description from the tag name
            let description = tagName.humanReadable

            let item = MetadataItem(
                group: group,
                tagName: tagName,
                description: description,
                value: valueString,
                isWritable: !Self.readOnlyGroups.contains(group.lowercased())
            )
            items.append(item)
        }

        // Sort by group, then by tag name
        items.sort { ($0.group, $0.tagName) < ($1.group, $1.tagName) }
        return items
    }

    /// Groups that are read-only (system/file-level metadata).
    private static let readOnlyGroups: Set<String> = [
        "system", "file", "composite",
    ]
}

// MARK: - String Helpers

private extension String {
    /// Converts a CamelCase tag name to a human-readable description.
    /// e.g., "DateTimeOriginal" → "Date Time Original"
    var humanReadable: String {
        var result = ""
        for (index, char) in self.enumerated() {
            if char.isUppercase && index > 0 {
                let prevChar = self[self.index(self.startIndex, offsetBy: index - 1)]
                if prevChar.isLowercase || prevChar.isNumber {
                    result.append(" ")
                }
            }
            result.append(char)
        }
        return result
    }
}
