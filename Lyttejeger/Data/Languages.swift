import Foundation

let allLanguages = ["Norsk", "Engelsk", "Svensk", "Dansk"]

// Language filter mapping for search
let languageFilterMap: [String: [String]] = [
    "Norsk": ["Norsk", "Nynorsk", "no", "nb", "nn", "no-no", "nb-no", "nn-no"],
    "Engelsk": ["English", "en", "en-us", "en-gb", "en-au", "en-ca"],
    "Svensk": ["Svenska", "sv", "sv-se"],
    "Dansk": ["Dansk", "da", "da-dk"],
]

let languageToAPICode: [String: String] = [
    "Norsk": "no,nb,nn",
    "Engelsk": "en",
    "Svensk": "sv",
    "Dansk": "da",
]

func getApiLanguageCodes(_ filterLabels: [String]) -> String? {
    guard !filterLabels.isEmpty else { return nil }
    let codes = filterLabels.compactMap { languageToAPICode[$0] }
    return codes.isEmpty ? nil : codes.joined(separator: ",")
}

func matchesLanguageFilter(_ podcastLanguage: String, filterLabel: String) -> Bool {
    guard let acceptedValues = languageFilterMap[filterLabel] else { return false }
    let normalized = podcastLanguage.lowercased()
    return acceptedValues.contains { val in
        normalized == val.lowercased() || normalized.hasPrefix(val.lowercased())
    }
}
