import SwiftUI

/// Exchange@UPT colour tokens (COLOR-GUIDE.md). Same names as the web's CSS custom properties.
/// Every colour lives in Assets.xcassets with a light and a dark value, so dark mode is automatic.
/// Rule: components use these tokens, never raw hex.
enum Theme {
    // Frame (charcoal): top bar and toasts only
    static let shell = Color("shell")
    static let shellInk = Color("shellInk")
    static let shellSub = Color("shellSub")
    static let shellHover = Color("shellHover")
    static let shellStrip = Color("shellStrip")
    /// Highlighted part of the logo, on shell only.
    static let brandMark = Color("brandMark")

    // Content
    static let ground = Color("ground")
    static let panel = Color("panel")
    static let ink = Color("ink")
    static let sub = Color("sub")
    static let faint = Color("faint")
    static let line = Color("line")
    static let chip = Color("chip")

    // Teal: the only action colour. If it's teal, it's clickable or selected.
    static let accent = Color("accent")
    static let accentHover = Color("accentHover")
    static let accentInk = Color("accentInk")
    static let accentSoft = Color("accentSoft")
    static let accentSoftInk = Color("accentSoftInk")
    static let accentSoftLine = Color("accentSoftLine")
    static let selection = Color("selection")

    // Status
    static let ok = Color("ok")
    static let okBg = Color("okBg")
    static let okInk = Color("okInk")
    static let warnBg = Color("warnBg")
    static let warnInk = Color("warnInk")
    static let warnLine = Color("warnLine")
    static let err = Color("err")
    static let errBg = Color("errBg")

    /// Each faculty has one fixed colour, used for dots, left borders and timetable blocks (not small text).
    static func faculty(_ code: String) -> Color {
        // One colour for every faculty (user decision, 21 Nov): the faculty is shown by its label, not its colour.
        Color("facultyAC")
    }
}

extension View {
    /// Light ground behind lists and forms, white panels for rows.
    func erasmusList() -> some View {
        self.scrollContentBackground(.hidden)
            .background(Theme.ground)
    }

    /// Charcoal top bar with light text: the app's frame.
    func shellNavigationBar() -> some View {
        self.toolbarBackground(Theme.shell, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
    }

    /// A white card with a thin border.
    func panelCard(padding: CGFloat = 12) -> some View {
        self.padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.panel, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
    }
}

/// "Exchange@UPT" wordmark for the charcoal bar: the brand-mark teal only on "@UPT".
struct BrandWordmark: View {
    var body: some View {
        (Text("Exchange").foregroundColor(Theme.shellInk) + Text("@UPT").foregroundColor(Theme.brandMark))
            .font(.app(.headline, .bold))
            .accessibilityLabel("Exchange at UPT")
    }
}

/// Neutral tag (year, ECTS, semester).
struct ChipTag: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.app(.caption2, .semibold))
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Theme.chip, in: Capsule())
            .foregroundStyle(Theme.sub)
    }
}
