import SwiftUI

// MARK: - Runtime Language Switching via Bundle Override

private var bundleKey: UInt8 = 0

final class BundleEx: Bundle {
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        guard let bundle = objc_getAssociatedObject(self, &bundleKey) as? Bundle else {
            return super.localizedString(forKey: key, value: value, table: tableName)
        }
        return bundle.localizedString(forKey: key, value: value, table: tableName)
    }
}

extension Bundle {
    /// Switch the app's language at runtime without restarting.
    /// Call this before any UI is presented.
    static func setLanguage(_ language: String) {
        defer { object_setClass(Bundle.main, BundleEx.self) }
        objc_setAssociatedObject(Bundle.main, &bundleKey,
            Bundle.main.path(forResource: language, ofType: "lproj").flatMap(Bundle.init(path:)),
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}

// MARK: - Supported Language

struct AppLanguage: Identifiable, Equatable {
    let code: String         // e.g. "en", "zh-Hans"
    let nativeName: String   // e.g. "English", "简体中文"
    let englishName: String  // e.g. "English", "Chinese (Simplified)"
    let flag: String

    var id: String { code }

    static let supported: [AppLanguage] = [
        AppLanguage(code: "en",      nativeName: "English",               englishName: "English",              flag: "🇺🇸"),
        AppLanguage(code: "zh-Hans", nativeName: "简体中文",                englishName: "Chinese (Simplified)", flag: "🇨🇳"),
    ]

    /// Returns the matching AppLanguage for a language code, or English as fallback.
    static func fromCode(_ code: String) -> AppLanguage {
        supported.first { $0.code == code } ?? supported[0]
    }
}

// MARK: - Language Manager (ObservableObject)

final class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    /// UserDefaults key used to persist the user's language choice.
    static let storageKey = "app_language"

    /// The currently active language code (persisted in UserDefaults).
    @Published var currentCode: String {
        didSet {
            UserDefaults.standard.set(currentCode, forKey: LanguageManager.storageKey)
            Bundle.setLanguage(currentCode)
            objectWillChange.send()
        }
    }

    /// The full AppLanguage model for the current language.
    var currentLanguage: AppLanguage { AppLanguage.fromCode(currentCode) }

    private init() {
        let saved = UserDefaults.standard.string(forKey: LanguageManager.storageKey) ?? ""
        if !saved.isEmpty, AppLanguage.supported.contains(where: { $0.code == saved }) {
            // A choice was already made (onboarding completed previously) — trust it.
            currentCode = saved
        } else {
            // First launch: start in English and let the onboarding language picker
            // decide. We deliberately do NOT auto-pick from the device locale here,
            // so the first-run language selection is always explicit.
            currentCode = "en"
        }
        // Apply the resolved language immediately so onboarding UI renders correctly.
        Bundle.setLanguage(currentCode)
    }

    /// Switch language at runtime (restart-free).
    func switchTo(_ code: String) {
        guard AppLanguage.supported.contains(where: { $0.code == code }) else { return }
        currentCode = code
    }
}
