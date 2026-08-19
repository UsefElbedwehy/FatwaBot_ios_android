import SwiftUI

#if canImport(CoreText)
import CoreText
#endif

/// The Amiri family, bundled as a package resource (see `Package.swift`) and
/// registered with the system the first time anything here is touched.
///
/// SPM package resources are not `Info.plist`-declared app fonts, so nothing
/// registers them automatically the way `UIAppFonts` would — `Font.custom`
/// silently falls back to the system font for a name CoreText has never heard
/// of, with no error to notice. `register()` is what closes that gap.
public enum AmiriFont {
    private static let registered: Bool = {
        for name in ["Amiri-Regular", "Amiri-Bold", "Amiri-Italic", "Amiri-BoldItalic"] {
            guard let url = Bundle.module.url(forResource: name, withExtension: "ttf") else { continue }
            #if canImport(CoreText)
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            #endif
        }
        return true
    }()

    /// Regular weight at `size`, scaling with Dynamic Type against `style` —
    /// falls back to the system font if registration somehow failed (a
    /// missing glyph table beats a crash).
    public static func regular(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        _ = registered
        return .custom("Amiri-Regular", size: size, relativeTo: style)
    }

    public static func bold(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        _ = registered
        return .custom("Amiri-Bold", size: size, relativeTo: style)
    }
}
