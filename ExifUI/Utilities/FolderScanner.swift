import Foundation

/// Recursively scans folders for supported media files.
///
/// Handles both individual files and folders in a single pass,
/// making it ideal for drag-and-drop where the user may drop
/// a mix of files and folders.
enum FolderScanner {

    /// Resolves a mixed list of file and folder URLs into individual file URLs.
    ///
    /// - Folders are recursively scanned for supported file types
    /// - Individual files are passed through if they have a supported extension
    /// - Hidden files and directories are skipped
    /// - Duplicates are removed
    static func resolveURLs(_ urls: [URL]) -> [URL] {
        var result: [URL] = []
        var seen: Set<String> = []

        for url in urls {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
                continue
            }

            if isDirectory.boolValue {
                // It's a folder — scan recursively
                let folderFiles = scanFolder(url)
                for file in folderFiles {
                    let path = file.path
                    if !seen.contains(path) {
                        seen.insert(path)
                        result.append(file)
                    }
                }
            } else {
                // It's a single file
                let ext = url.pathExtension.lowercased()
                if FileType.supportedExtensions.contains(ext) {
                    let path = url.path
                    if !seen.contains(path) {
                        seen.insert(path)
                        result.append(url)
                    }
                }
            }
        }

        return result.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    /// Recursively scans a folder for supported files.
    private static func scanFolder(_ folderURL: URL) -> [URL] {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        var files: [URL] = []

        for case let fileURL as URL in enumerator {
            let ext = fileURL.pathExtension.lowercased()
            if FileType.supportedExtensions.contains(ext) {
                files.append(fileURL)
            }
        }

        return files
    }
}
