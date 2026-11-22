import SwiftUI
import UIKit
import CoreText

/// Interface type: Public Sans (400–800) everywhere, Red Hat Mono (500–600) only for course codes.
/// Both ship as variable fonts in Fonts/ (SIL Open Font License 1.1, see FONTS-LICENSE.md).
/// If a font can't be registered, UIKit falls back to the system font, so text never disappears.
enum AppFont {
    static let sans = "Public Sans"
    static let mono = "Red Hat Mono"
    private static let weightAxis = 0x7767_6874   // 'wght'

    /// Call once at launch.
    static func register() {
        for file in ["PublicSans-Variable", "RedHatMono-Variable"] {
            guard let url = Bundle.main.url(forResource: file, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
        // Navigation bar titles and tab bar labels are UIKit: give them the same face.
        let nav = UINavigationBar.appearance()
        nav.titleTextAttributes = [.font: uiFont(sans, size: 17, weight: 600)]
        nav.largeTitleTextAttributes = [.font: uiFont(sans, size: 34, weight: 800)]
        UITabBarItem.appearance().setTitleTextAttributes([.font: uiFont(sans, size: 10, weight: 500)], for: .normal)
    }

    static func uiFont(_ family: String, size: CGFloat, weight: CGFloat) -> UIFont {
        let attributes: [UIFontDescriptor.AttributeName: Any] = [
            .family: family,
            UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): [weightAxis: weight],
        ]
        return UIFont(descriptor: UIFontDescriptor(fontAttributes: attributes), size: size)
    }

    /// Public Sans goes from 400 to 800 here.
    static func value(_ w: Font.Weight) -> CGFloat {
        switch w {
        case .medium: return 500
        case .semibold: return 600
        case .bold: return 700
        case .heavy, .black: return 800
        default: return 400
        }
    }

    static func base(_ style: Font.TextStyle) -> (CGFloat, UIFont.TextStyle, Font.Weight) {
        switch style {
        case .largeTitle: return (34, .largeTitle, .regular)
        case .title: return (28, .title1, .regular)
        case .title2: return (22, .title2, .regular)
        case .title3: return (20, .title3, .regular)
        case .headline: return (17, .headline, .semibold)
        case .callout: return (16, .callout, .regular)
        case .subheadline: return (15, .subheadline, .regular)
        case .footnote: return (13, .footnote, .regular)
        case .caption: return (12, .caption1, .regular)
        case .caption2: return (11, .caption2, .regular)
        default: return (17, .body, .regular)
        }
    }
}

extension Font {
    /// Public Sans at a text style, scaled with the user's text size.
    static func app(_ style: Font.TextStyle, _ weight: Font.Weight? = nil) -> Font {
        let (size, uiStyle, defaultWeight) = AppFont.base(style)
        let font = AppFont.uiFont(AppFont.sans, size: size, weight: AppFont.value(weight ?? defaultWeight))
        return Font(UIFontMetrics(forTextStyle: uiStyle).scaledFont(for: font) as CTFont)
    }

    /// Public Sans at a fixed size (timetable blocks, tiny labels).
    static func app(size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        Font(AppFont.uiFont(AppFont.sans, size: size, weight: AppFont.value(weight)) as CTFont)
    }

    /// Red Hat Mono for course codes such as L002.25.03.F1 (weights 500–600).
    static func code(_ style: Font.TextStyle = .caption, semibold: Bool = false) -> Font {
        let (size, uiStyle, _) = AppFont.base(style)
        let font = AppFont.uiFont(AppFont.mono, size: size, weight: semibold ? 600 : 500)
        return Font(UIFontMetrics(forTextStyle: uiStyle).scaledFont(for: font) as CTFont)
    }

    static func code(size: CGFloat, semibold: Bool = true) -> Font {
        Font(AppFont.uiFont(AppFont.mono, size: size, weight: semibold ? 600 : 500) as CTFont)
    }
}
