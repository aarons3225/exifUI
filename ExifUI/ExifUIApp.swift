import SwiftUI

/// The main entry point for ExifUI.
///
/// Follows Apple HIG by providing:
/// - A standard window group for the main interface
/// - A Settings scene for preferences (⌘,)
/// - Menu bar commands with keyboard shortcuts
/// - Theme support (dark mode, custom accent colors)
@main
struct ExifUIApp: App {
    @State private var appState = AppState()
    @State private var themeManager = ThemeManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.appState, appState)
                .environment(themeManager)
                .preferredColorScheme(themeManager.resolvedColorScheme)
                .tint(themeManager.accentColor)
                .frame(minWidth: 800, minHeight: 500)
                .onAppear {
                    themeManager.initialize()
                    NSApplication.shared.windows.first?.setContentSize(
                        NSSize(width: 1100, height: 700)
                    )
                }
        }
        .commands {
            AppCommands(appState: appState)
        }
        .defaultSize(width: 1100, height: 700)

        Settings {
            SettingsView()
                .environment(\.appState, appState)
                .environment(themeManager)
                .preferredColorScheme(themeManager.resolvedColorScheme)
                .tint(themeManager.accentColor)
        }
    }
}

// MARK: - App Commands (Menu Bar)

/// Custom menu bar commands following Apple HIG patterns.
struct AppCommands: Commands {
    let appState: AppState

    var body: some Commands {
        // Replace the default New Item command
        CommandGroup(replacing: .newItem) {
            Button("Open Files…") {
                openFiles()
            }
            .keyboardShortcut("o")

            Button("Open Folder…") {
                openFolder()
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])

            Divider()

            Button("Close File") {
                if let selected = appState.selectedFile {
                    appState.removeFiles([selected.id])
                }
            }
            .keyboardShortcut("w")
            .disabled(appState.selectedFile == nil)
        }

        // File operations
        CommandGroup(after: .newItem) {
            Divider()

            Button("Save Changes") {
                Task { await appState.saveMetadata() }
            }
            .keyboardShortcut("s")
            .disabled(!appState.hasUnsavedChanges)

            Button("Revert to Saved") {
                if let file = appState.selectedFile {
                    Task { await appState.loadMetadata(for: file) }
                }
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
            .disabled(appState.selectedFile == nil)

            Divider()

            Button("Batch Edit…") {
                if appState.hasBatchSelection {
                    appState.showBatchEdit = true
                } else if !appState.files.isEmpty {
                    // Select all files for batch if none multi-selected
                    appState.selectedFileIDs = Set(appState.files.map(\.id))
                    appState.showBatchEdit = true
                }
            }
            .keyboardShortcut("b", modifiers: [.command, .shift])
            .disabled(appState.files.isEmpty)
        }

        // Edit operations
        CommandGroup(after: .pasteboard) {
            Divider()

            Button("Strip All Metadata…") {
                Task { await appState.stripAllMetadata() }
            }
            .disabled(appState.selectedFile == nil)

            Button("Restore Original…") {
                Task { await appState.restoreOriginal() }
            }
            .disabled(appState.selectedFile == nil)
        }

        // Sidebar toggle (standard macOS behavior)
        SidebarCommands()

        // Toolbar commands
        ToolbarCommands()
    }

    private func openFiles() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = FileType.supportedContentTypes
        panel.message = "Select files or folders to inspect their metadata."

        if panel.runModal() == .OK {
            appState.addFiles(panel.urls)
        }
    }

    private func openFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.message = "Select folders to scan for media files."

        if panel.runModal() == .OK {
            appState.addFiles(panel.urls)
        }
    }
}
