import SwiftUI

/// The Settings window, accessible via ⌘, (standard macOS convention).
///
/// Follows Apple HIG for preferences:
/// - TabView with labeled sections
/// - Form-style layout
/// - Sensible defaults
/// - Appearance tab for theme customization
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            AppearanceSettingsTab()
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }

            ExifToolSettingsTab()
                .tabItem {
                    Label("exiftool", systemImage: "terminal")
                }

            AboutTab()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 520, height: 420)
    }
}

// MARK: - General Settings

struct GeneralSettingsTab: View {
    @AppStorage("overwriteOriginal") private var overwriteOriginal = false
    @AppStorage("showPreviewByDefault") private var showPreviewByDefault = true
    @AppStorage("autoRefreshOnFocus") private var autoRefreshOnFocus = false

    var body: some View {
        Form {
            Section {
                Toggle("Overwrite original files when saving", isOn: $overwriteOriginal)
                    .help("When disabled, exiftool creates a backup with '_original' suffix")

                if overwriteOriginal {
                    Label(
                        "Changes will be written directly to the file with no backup.",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(.orange)
                    .font(.caption)
                }
            } header: {
                Text("File Handling")
            }

            Section {
                Toggle("Show media preview by default", isOn: $showPreviewByDefault)
                Toggle("Refresh metadata when app regains focus", isOn: $autoRefreshOnFocus)
            } header: {
                Text("Display")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Appearance Settings

struct AppearanceSettingsTab: View {
    @Environment(ThemeManager.self) private var theme

    var body: some View {
        @Bindable var themeBinding = theme

        Form {
            // Appearance Mode
            Section {
                Picker("Appearance", selection: $themeBinding.appearanceMode) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Label(mode.label, systemImage: mode.systemImage)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Mode")
            } footer: {
                Text("Choose System to follow your macOS appearance settings.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            // Accent Color
            Section {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(56)), count: 6), spacing: 12) {
                    ForEach(AccentColorPreset.allCases) { preset in
                        AccentColorSwatch(
                            preset: preset,
                            isSelected: theme.accentColorPreset == preset
                        ) {
                            theme.accentColorPreset = preset
                        }
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Accent Color")
            } footer: {
                Text("Choose System to use your macOS accent color preference.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            // Material Effects
            Section {
                Toggle("Translucent backgrounds", isOn: $themeBinding.useTranslucentBackground)
                    .help("Adds a frosted glass effect to backgrounds")

                Toggle("Sidebar vibrancy", isOn: $themeBinding.useSidebarVibrancy)
                    .help("Makes the sidebar blend with the desktop wallpaper")
            } header: {
                Text("Visual Effects")
            }

            // Preview
            Section {
                themePreview
            } header: {
                Text("Preview")
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Theme Preview

    private var themePreview: some View {
        HStack(spacing: 12) {
            // Mini sidebar preview
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Circle().fill(theme.accentColor).frame(width: 6, height: 6)
                    RoundedRectangle(cornerRadius: 2).fill(.secondary.opacity(0.5)).frame(width: 60, height: 8)
                }
                HStack(spacing: 6) {
                    Circle().fill(.secondary.opacity(0.3)).frame(width: 6, height: 6)
                    RoundedRectangle(cornerRadius: 2).fill(.secondary.opacity(0.3)).frame(width: 45, height: 8)
                }
                HStack(spacing: 6) {
                    Circle().fill(.secondary.opacity(0.3)).frame(width: 6, height: 6)
                    RoundedRectangle(cornerRadius: 2).fill(.secondary.opacity(0.3)).frame(width: 52, height: 8)
                }
            }
            .padding(8)
            .frame(width: 100)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(theme.useTranslucentBackground ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color(nsColor: .controlBackgroundColor)))
            )

            // Mini detail preview
            VStack(alignment: .leading, spacing: 4) {
                RoundedRectangle(cornerRadius: 2).fill(.secondary.opacity(0.2)).frame(height: 24)
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2).fill(theme.accentColor.opacity(0.3)).frame(width: 40, height: 12)
                    RoundedRectangle(cornerRadius: 2).fill(.secondary.opacity(0.2)).frame(height: 12)
                }
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2).fill(.secondary.opacity(0.15)).frame(width: 40, height: 12)
                    RoundedRectangle(cornerRadius: 2).fill(.secondary.opacity(0.2)).frame(height: 12)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
        }
        .frame(height: 60)
    }
}

// MARK: - Accent Color Swatch

struct AccentColorSwatch: View {
    let preset: AccentColorPreset
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(preset.swatchColor)
                        .frame(width: 28, height: 28)

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    }
                }

                Text(preset.label)
                    .font(.system(size: 9))
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(preset.label) accent color\(isSelected ? ", selected" : "")")
    }
}

// MARK: - ExifTool Settings

struct ExifToolSettingsTab: View {
    @Environment(\.appState) private var appState
    @AppStorage("exifToolCustomPath") private var customPath = ""
    @State private var detectedPath = ""
    @State private var detectedVersion = ""
    @State private var isChecking = false

    var body: some View {
        Form {
            Section {
                LabeledContent("Status") {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(appState.exifToolService.isAvailable ? .green : .red)
                            .frame(width: 8, height: 8)

                        Text(appState.exifToolService.isAvailable ? "Available" : "Not Found")
                            .foregroundStyle(
                                appState.exifToolService.isAvailable ? .primary : Color.red
                            )
                    }
                }

                if let version = appState.exifToolService.version {
                    LabeledContent("Version") {
                        Text(version)
                            .font(.system(.body, design: .monospaced))
                    }
                }

                if let path = appState.exifToolService.exifToolPath {
                    LabeledContent("Location") {
                        Text(path)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            } header: {
                Text("Current Configuration")
            }

            Section {
                HStack {
                    TextField("Custom path to exiftool", text: $customPath)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))

                    Button("Browse…") {
                        browseForExifTool()
                    }
                }

                HStack {
                    Button("Apply") {
                        Task {
                            isChecking = true
                            try? await appState.exifToolService.setCustomPath(customPath)
                            isChecking = false
                        }
                    }
                    .disabled(customPath.isEmpty || isChecking)

                    Button("Auto-Detect") {
                        Task {
                            isChecking = true
                            customPath = ""
                            UserDefaults.standard.removeObject(forKey: "exifToolCustomPath")
                            await appState.exifToolService.locateExifTool()
                            isChecking = false
                        }
                    }
                    .disabled(isChecking)

                    if isChecking {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            } header: {
                Text("Custom Path")
            } footer: {
                Text("Leave empty to auto-detect. ExifUI checks: bundled copy → custom path → Homebrew → system install.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            if !appState.exifToolService.isAvailable {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Install exiftool")
                            .font(.headline)

                        Text("The easiest way is via Homebrew:")
                            .foregroundStyle(.secondary)

                        HStack {
                            Text("brew install exiftool")
                                .font(.system(.body, design: .monospaced))
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(.background)
                                )

                            Button {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(
                                    "brew install exiftool",
                                    forType: .string
                                )
                            } label: {
                                Image(systemName: "doc.on.doc")
                            }
                            .help("Copy to clipboard")
                        }

                        if let exiftoolURL = URL(string: "https://exiftool.org") {
                            Link(
                                "Or download from exiftool.org →",
                                destination: exiftoolURL
                            )
                            .font(.caption)
                        }
                    }
                } header: {
                    Text("Installation")
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func browseForExifTool() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.title = "Select exiftool Binary"
        panel.directoryURL = URL(fileURLWithPath: "/usr/local/bin")

        if panel.runModal() == .OK, let url = panel.url {
            customPath = url.path
        }
    }
}

// MARK: - About Tab

struct AboutTab: View {
    @Environment(ThemeManager.self) private var theme

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.badge.magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(theme.accentColor)

            Text("ExifUI")
                .font(.title)
                .fontWeight(.bold)

            Text("A native macOS frontend for exiftool")
                .font(.body)
                .foregroundStyle(.secondary)

            Text("Version 1.0.0")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Divider()
                .frame(width: 200)

            VStack(spacing: 4) {
                Text("exiftool by Phil Harvey")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let url = URL(string: "https://exiftool.org") {
                    Link("exiftool.org", destination: url)
                        .font(.caption)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
