# ExifUI — Setup Guide

A native macOS SwiftUI frontend for [exiftool](https://exiftool.org).

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15.0 or later
- exiftool installed (see below)

## Install exiftool

The easiest method is Homebrew:

```bash
brew install exiftool
```

Or download from https://exiftool.org and install manually.

## Option A: Create Xcode Project with XcodeGen (Recommended)

If you have [XcodeGen](https://github.com/yonaskolb/XcodeGen) installed:

```bash
# Install XcodeGen if needed
brew install xcodegen

# Generate the Xcode project
cd /path/to/exifUI
xcodegen generate

# Open in Xcode
open ExifUI.xcodeproj
```

## Option B: Create Xcode Project Manually

1. Open Xcode → File → New → Project
2. Choose **macOS → App**
3. Configure:
   - Product Name: `ExifUI`
   - Team: your personal team (or None)
   - Organization Identifier: `com.exifui`
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Uncheck "Include Tests" for now
4. Save the project in the same parent directory
5. Delete the auto-generated `ContentView.swift` and `ExifUIApp.swift`
6. Drag the entire `ExifUI/` folder into the Xcode project navigator
7. Make sure "Copy items if needed" is **unchecked** and "Create groups" is selected

## Build Settings to Verify

After creating the project, check these settings:

| Setting | Value |
|---------|-------|
| Deployment Target | macOS 14.0 |
| Swift Language Version | 5.9 |
| App Sandbox | NO (required for Process()) |
| Hardened Runtime | YES |

## Entitlements

The included `ExifUI.entitlements` disables App Sandbox so the app can
execute exiftool as a subprocess. If you want to distribute via the App
Store, you'd need to re-enable sandboxing and wrap exiftool calls in an
XPC service — that's a more advanced setup for later.

## Project Structure

```
ExifUI/
├── ExifUIApp.swift              # App entry point, menu commands
├── ContentView.swift            # Main NavigationSplitView layout
├── Models/
│   ├── MetadataItem.swift       # Metadata tag model
│   └── MediaFile.swift          # File representation + type detection
├── Services/
│   └── ExifToolService.swift    # exiftool CLI wrapper + batch operations
├── ViewModels/
│   └── AppState.swift           # Central @Observable state
├── Utilities/
│   ├── ThemeManager.swift       # Dark mode + accent color theming
│   └── FolderScanner.swift      # Recursive folder scanning
├── Views/
│   ├── Sidebar/
│   │   ├── SidebarView.swift    # File list with multi-select + drag-and-drop
│   │   └── FileRowView.swift    # Individual file row
│   ├── Detail/
│   │   ├── DetailView.swift     # Preview + metadata split
│   │   ├── MediaPreviewView.swift  # Image/video preview
│   │   └── MetadataTableView.swift # Sortable metadata table
│   ├── Editor/
│   │   └── MetadataEditorSheet.swift  # Edit tag values
│   ├── Batch/
│   │   └── BatchEditView.swift  # Batch edit multiple files
│   └── Settings/
│       └── SettingsView.swift   # Preferences with Appearance tab
├── Info.plist
└── ExifUI.entitlements
```

## Features

### Dark Mode & Custom Theming
- System / Light / Dark appearance modes
- 11 accent color presets (including teal, cyan, indigo)
- Translucent material backgrounds (frosted glass effect)
- Sidebar vibrancy that blends with your wallpaper
- Live preview in Settings → Appearance
- All settings persist via UserDefaults

### Batch Editing
- Multi-select files in the sidebar (⌘-click, ⇧-click)
- Three batch operations: Set Tags, Strip All Metadata, Copy Tags
- Per-file result reporting (success/failure)
- Accessible via toolbar button, context menu, or ⇧⌘B

### Drag & Drop
- Drop files and/or folders anywhere on the app window
- Folders are recursively scanned for supported media types
- Visual drop overlay with feedback animation
- Hidden files and macOS package contents are skipped

## Apple HIG Compliance

This app follows Apple Human Interface Guidelines:

- **NavigationSplitView** for sidebar + detail layout (standard macOS pattern)
- **SF Symbols** for all icons (no custom images needed)
- **System colors** (`.primary`, `.secondary`, `.accent`) for automatic Dark Mode
- **Custom theming** with accent colors and material effects
- **Standard menus** with keyboard shortcuts (⌘O open, ⌘S save, ⌘, settings)
- **`.searchable`** modifier for native search bar
- **Table** view with sortable columns
- **Form** with `.grouped` style for Settings
- **Drag-and-drop** for files and folders with visual feedback
- **Multi-select** in sidebar for batch operations
- **Context menus** on file rows and metadata rows
- **Alert** presentation for errors
- **Sheet** presentation for editor and batch edit
- **Accessibility labels** on key elements

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| ⌘O | Open files |
| ⇧⌘O | Open folder |
| ⌘S | Save changes |
| ⇧⌘R | Revert to saved |
| ⇧⌘B | Batch edit |
| ⌘W | Close file |
| ⌘, | Open Settings |

## First Run

1. Build and run in Xcode (⌘R)
2. The app will auto-detect exiftool — check Settings → exiftool tab
3. Drag image or video files into the sidebar (or use File → Open)
4. Click a file to see its metadata
5. Click the pencil icon on any writable tag to edit it
6. Save changes with ⌘S (creates a backup by default)

## Troubleshooting

**"exiftool was not found"**: Open Settings (⌘,) → exiftool tab → either
run `brew install exiftool` or set the custom path manually.

**App won't build**: Make sure deployment target is macOS 14.0+ and Swift
version is 5.9+. The `@Observable` macro requires both.

**Can't read metadata**: Check that the file path is accessible and
exiftool supports the file type. Try running `exiftool /path/to/file`
in Terminal to verify.
