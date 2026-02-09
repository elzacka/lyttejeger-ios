import Foundation

let allLanguages = ["Norsk", "Engelsk", "Svensk", "Dansk"]

private let languageToNorwegian: [String: String] = [
    // English names
    "English": "Engelsk",
    "Norwegian": "Norsk",
    "Swedish": "Svensk",
    "Danish": "Dansk",
    "German": "Tysk",
    "French": "Fransk",
    "Spanish": "Spansk",
    "Italian": "Italiensk",
    "Portuguese": "Portugisisk",
    "Dutch": "Nederlandsk",
    "Polish": "Polsk",
    "Russian": "Russisk",
    "Japanese": "Japansk",
    "Chinese": "Kinesisk",
    "Korean": "Koreansk",
    "Arabic": "Arabisk",
    "Hindi": "Hindi",
    "Finnish": "Finsk",
    "Icelandic": "Islandsk",
    // ISO 639-1 codes
    "en": "Engelsk",
    "no": "Norsk",
    "nb": "Norsk",
    "nn": "Norsk",
    "sv": "Svensk",
    "da": "Dansk",
    "de": "Tysk",
    "fr": "Fransk",
    "es": "Spansk",
    "it": "Italiensk",
    "pt": "Portugisisk",
    "nl": "Nederlandsk",
    "pl": "Polsk",
    "ru": "Russisk",
    "ja": "Japansk",
    "zh": "Kinesisk",
    "ko": "Koreansk",
    "ar": "Arabisk",
    "hi": "Hindi",
    "fi": "Finsk",
    "is": "Islandsk",
]

func toNorwegianLanguage(_ language: String?) -> String {
    guard let language, !language.isEmpty else { return "" }
    let normalized = language.lowercased()
    if let match = languageToNorwegian.first(where: { $0.key.lowercased() == normalized }) {
        return match.value
    }
    if allLanguages.contains(language) { return language }
    return language
}

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
