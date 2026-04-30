import Foundation

struct LocalizationConfiguration {
    let availableBundleLocalizations: [String]
    let preferredLanguages: [String]
    let resolvedLocalizations: [String]
    let effectiveLocalization: String
}

enum LocalizationBootstrap {
    static func readSystemLocalizationConfiguration(bundle: Bundle = .main) -> LocalizationConfiguration {
        let available = bundle.localizations
        let preferred = Locale.preferredLanguages
        let resolved = Bundle.preferredLocalizations(from: available, forPreferences: preferred)

        let effective = resolved.first
            ?? bundle.preferredLocalizations.first
            ?? bundle.developmentLocalization
            ?? "en"

        return LocalizationConfiguration(
            availableBundleLocalizations: available,
            preferredLanguages: preferred,
            resolvedLocalizations: resolved,
            effectiveLocalization: effective
        )
    }
}
