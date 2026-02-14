import SwiftUI

/// Manages the app's visual theme including color scheme, accent color,
/// and material effects.
///
/// Inspired by Apple's own apps and the translucent dark UI aesthetic.
/// Persists all settings via @AppStorage for automatic UserDefaults sync.
@Observable
final class ThemeManager {

    // MARK: - Color Scheme

    /// The user's preferred appearance mode.
    var appearanceMode: AppearanceMode {
        get { AppearanceMode(rawValue: _appearanceModeRaw) ?? .system }
        set {
            _appearanceModeRaw = newValue.rawValue
            applyAppearance()
        }
    }

    /// Backing storage for @AppStorage compatibility.
    @ObservationIgnored
    @AppStorage("appearanceMode") private var _appearanceModeRaw: String = AppearanceMode.system.rawValue

    /// Resolved color scheme based on appearance mode.
    var resolvedColorScheme: ColorScheme? {
        switch appearanceMode {
        case .system: return nil  // Follow system
        case .light: return .light
        case .dark: return .dark
        }
    }

    // MARK: - Accent Color

    /// The user's chosen accent color preset.
    var accentColorPreset: AccentColorPreset {
        get { AccentColorPreset(rawValue: _accentColorRaw) ?? .system }
        set {
            _accentColorRaw = newValue.rawValue
        }
    }

    @ObservationIgnored
    @AppStorage("accentColorPreset") private var _accentColorRaw: String = AccentColorPreset.system.rawValue

    /// The resolved accent Color to use.
    var accentColor: Color {
        accentColorPreset.color
    }

    // MARK: - Material & Vibrancy

    /// Whether to use translucent material backgrounds (glass effect).
    var useTranslucentBackground: Bool {
        get { _useTranslucent }
        set { _useTranslucent = newValue }
    }

    @ObservationIgnored
    @AppStorage("useTranslucentBackground") private var _useTranslucent: Bool = true

    /// Whether the sidebar uses vibrancy (NSVisualEffectView-style).
    var useSidebarVibrancy: Bool {
        get { _useSidebarVibrancy }
        set { _useSidebarVibrancy = newValue }
    }

    @ObservationIgnored
    @AppStorage("useSidebarVibrancy") private var _useSidebarVibrancy: Bool = true

    // MARK: - Convenience

    /// The material style to apply to main content areas.
    var contentMaterial: Material {
        useTranslucentBackground ? .ultraThinMaterial : .bar
    }

    /// The material style for the sidebar.
    var sidebarMaterial: Material {
        useSidebarVibrancy ? .ultraThinMaterial : .bar
    }

    // MARK: - Apply to NSApp

    /// Forces the NSApp appearance to match the selected mode.
    func applyAppearance() {
        switch appearanceMode {
        case .system:
            NSApp.appearance = nil
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }

    /// Call on app launch to sync initial state.
    func initialize() {
        applyAppearance()
    }
}

// MARK: - Appearance Mode

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var systemImage: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
}

// MARK: - Accent Color Presets

enum AccentColorPreset: String, CaseIterable, Identifiable {
    case system = "system"
    case blue = "blue"
    case teal = "teal"
    case cyan = "cyan"
    case green = "green"
    case indigo = "indigo"
    case purple = "purple"
    case pink = "pink"
    case orange = "orange"
    case red = "red"
    case graphite = "graphite"

    var id: String { rawValue }

    var label: String { rawValue.capitalized }

    /// The SwiftUI Color for this preset.
    var color: Color {
        switch self {
        case .system: return .accentColor
        case .blue: return .blue
        case .teal: return .teal
        case .cyan: return .cyan
        case .green: return .green
        case .indigo: return .indigo
        case .purple: return .purple
        case .pink: return .pink
        case .orange: return .orange
        case .red: return .red
        case .graphite: return Color(nsColor: .systemGray)
        }
    }

    /// Preview swatch color (always specific, even for "system").
    var swatchColor: Color {
        switch self {
        case .system: return .accentColor
        default: return color
        }
    }
}

// MARK: - Theme View Modifier

/// Applies the current theme to a view hierarchy.
struct ThemedViewModifier: ViewModifier {
    @Environment(ThemeManager.self) private var theme

    func body(content: Content) -> some View {
        content
            .preferredColorScheme(theme.resolvedColorScheme)
            .tint(theme.accentColor)
    }
}

extension View {
    /// Applies the app's theme (color scheme + accent color).
    func themed() -> some View {
        modifier(ThemedViewModifier())
    }
}

// MARK: - Themed Background Modifier

/// Adds a themed material background to a view.
struct ThemedBackgroundModifier: ViewModifier {
    @Environment(ThemeManager.self) private var theme
    let useContent: Bool

    func body(content: Content) -> some View {
        if theme.useTranslucentBackground {
            content
                .background(useContent ? theme.contentMaterial : theme.sidebarMaterial)
        } else {
            content
                .background(Color(nsColor: .windowBackgroundColor))
        }
    }
}

extension View {
    /// Applies a themed background material.
    func themedBackground(content: Bool = true) -> some View {
        modifier(ThemedBackgroundModifier(useContent: content))
    }
}
