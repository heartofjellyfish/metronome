import Foundation

/// Localize presentation only. Stored rhythms, sound IDs and user preset names stay unchanged.
enum L10n {
    static func text(_ key: String) -> String {
        Bundle.main.localizedString(forKey: key, value: key, table: nil)
    }
    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: text(key), locale: Locale.current, arguments: arguments)
    }
    static func bars(_ count: Int) -> String {
        format(count == 1 ? "%d BAR" : "%d BARS", count)
    }
    /// CJK labels need natural spacing; other locales retain the printed instrument feel.
    static let letterSpacingScale: CGFloat = {
        let language = Bundle.main.preferredLocalizations.first ?? "en"
        return ["zh", "ja", "ko"].contains(where: { language.hasPrefix($0) }) ? 0.25 : 1
    }()
}
