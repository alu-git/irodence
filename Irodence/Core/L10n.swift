import Foundation
import SwiftUI

/// In-app language override. Chinese is the default regardless of system
/// language; the choice is applied live via `.environment(\.locale)` at the
/// root for view strings (Localizable.xcstrings) and read here directly for
/// model/service strings (display names, error messages).
enum AppLanguage: String, CaseIterable {
    case zh = "zh-Hans"
    case en = "en"

    static let storageKey = "appLanguage"

    static var current: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? zh.rawValue) ?? .zh
    }

    static var isEnglish: Bool { current == .en }

    var displayName: String { self == .zh ? "中文" : "English" }
    var locale: Locale { Locale(identifier: rawValue) }
}

/// Bilingual helper for strings that never pass through SwiftUI's
/// localization (model display names, service error messages).
enum L10n {
    static func t(_ zh: String, _ en: String) -> String {
        AppLanguage.isEnglish ? en : zh
    }
}

/// Accessibility text-size preference, applied as a `.dynamicTypeSize`
/// override at the root.
enum TextSizePreference: String, CaseIterable {
    case small, standard, large, xlarge

    static let storageKey = "textSizePreference"

    static var current: TextSizePreference {
        TextSizePreference(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? standard.rawValue) ?? .standard
    }

    var displayName: String {
        switch self {
        case .small:    return L10n.t("小", "Small")
        case .standard: return L10n.t("标准", "Default")
        case .large:    return L10n.t("大", "Large")
        case .xlarge:   return L10n.t("特大", "Extra Large")
        }
    }

    var dynamicTypeSize: DynamicTypeSize {
        switch self {
        case .small:    return .medium
        case .standard: return .large
        case .large:    return .xLarge
        case .xlarge:   return .xxxLarge
        }
    }
}
