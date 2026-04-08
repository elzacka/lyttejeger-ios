import Foundation

struct CategoryGroup: Identifiable, Sendable {
    var id: String { title }
    let title: String
    let icon: String
    let categories: [FilterOption]
}

let categoryGroups: [CategoryGroup] = [
    CategoryGroup(title: "Nyheter & Samfunn", icon: "newspaper", categories: [
        FilterOption(value: "News", label: "Nyheter"),
        FilterOption(value: "Politics", label: "Politikk"),
        FilterOption(value: "Government", label: "Forvaltning"),
        FilterOption(value: "Commentary", label: "Kommentar"),
        FilterOption(value: "Daily", label: "Daglig"),
        FilterOption(value: "Society", label: "Samfunn"),
        FilterOption(value: "Climate", label: "Klima"),
    ]),
    CategoryGroup(title: "Kultur & Underholdning", icon: "theatermasks", categories: [
        FilterOption(value: "Culture", label: "Kultur"),
        FilterOption(value: "Entertainment", label: "Underholdning"),
        FilterOption(value: "Comedy", label: "Humor"),
        FilterOption(value: "Stand-Up", label: "Standup"),
        FilterOption(value: "Improv", label: "Improvisasjon"),
        FilterOption(value: "Arts", label: "Kunst"),
        FilterOption(value: "Performing", label: "Scenekunst"),
        FilterOption(value: "Visual", label: "Visuell kunst"),
        FilterOption(value: "Design", label: "Design"),
        FilterOption(value: "Music", label: "Musikk"),
        FilterOption(value: "Fashion", label: "Mote"),
        FilterOption(value: "Beauty", label: "Skjønnhet"),
    ]),
    CategoryGroup(title: "Krim & Fiksjon", icon: "book", categories: [
        FilterOption(value: "True Crime", label: "Krim"),
        FilterOption(value: "Fiction", label: "Fiksjon"),
        FilterOption(value: "Drama", label: "Drama"),
        FilterOption(value: "Fantasy", label: "Fantasy"),
        FilterOption(value: "Stories", label: "Historier"),
    ]),
    CategoryGroup(title: "Vitenskap & Teknologi", icon: "atom", categories: [
        FilterOption(value: "Science", label: "Vitenskap"),
        FilterOption(value: "Technology", label: "Teknologi"),
        FilterOption(value: "Astronomy", label: "Astronomi"),
        FilterOption(value: "Physics", label: "Fysikk"),
        FilterOption(value: "Chemistry", label: "Kjemi"),
        FilterOption(value: "Mathematics", label: "Matematikk"),
        FilterOption(value: "Nature", label: "Natur"),
        FilterOption(value: "Earth", label: "Jorda"),
        FilterOption(value: "Weather", label: "Vær"),
        FilterOption(value: "Cryptocurrency", label: "Kryptovaluta"),
    ]),
    CategoryGroup(title: "Helse & Livsstil", icon: "heart.text.square", categories: [
        FilterOption(value: "Health", label: "Helse"),
        FilterOption(value: "Mental", label: "Mental helse"),
        FilterOption(value: "Medicine", label: "Medisin"),
        FilterOption(value: "Nutrition", label: "Ernæring"),
        FilterOption(value: "Fitness", label: "Trening"),
        FilterOption(value: "Self-Improvement", label: "Selvutvikling"),
        FilterOption(value: "Sexuality", label: "Seksualitet"),
        FilterOption(value: "Personal", label: "Personlig"),
        FilterOption(value: "Life", label: "Liv"),
    ]),
    CategoryGroup(title: "Næringsliv & Karriere", icon: "briefcase", categories: [
        FilterOption(value: "Business", label: "Næringsliv"),
        FilterOption(value: "Entrepreneurship", label: "Entreprenørskap"),
        FilterOption(value: "Careers", label: "Karriere"),
        FilterOption(value: "Marketing", label: "Markedsføring"),
        FilterOption(value: "Management", label: "Ledelse"),
        FilterOption(value: "Investing", label: "Investering"),
        FilterOption(value: "Non-Profit", label: "Ideelle org."),
    ]),
    CategoryGroup(title: "Utdanning & Kunnskap", icon: "graduationcap", categories: [
        FilterOption(value: "Education", label: "Utdanning"),
        FilterOption(value: "Learning", label: "Læring"),
        FilterOption(value: "Courses", label: "Kurs"),
        FilterOption(value: "How-To", label: "Slik gjør du"),
        FilterOption(value: "History", label: "Historie"),
        FilterOption(value: "Philosophy", label: "Filosofi"),
        FilterOption(value: "Language", label: "Språk"),
        FilterOption(value: "Books", label: "Bøker"),
    ]),
    CategoryGroup(title: "Sport & Fritid", icon: "sportscourt", categories: [
        FilterOption(value: "Sports", label: "Sport"),
        FilterOption(value: "Football", label: "Fotball"),
        FilterOption(value: "Running", label: "Løping"),
        FilterOption(value: "Swimming", label: "Svømming"),
        FilterOption(value: "Basketball", label: "Basketball"),
        FilterOption(value: "Baseball", label: "Baseball"),
        FilterOption(value: "Hockey", label: "Hockey"),
        FilterOption(value: "Tennis", label: "Tennis"),
        FilterOption(value: "Golf", label: "Golf"),
        FilterOption(value: "Wrestling", label: "Bryting"),
        FilterOption(value: "Cricket", label: "Cricket"),
        FilterOption(value: "Rugby", label: "Rugby"),
        FilterOption(value: "Volleyball", label: "Volleyball"),
        FilterOption(value: "Leisure", label: "Fritid"),
    ]),
    CategoryGroup(title: "Hobbyer & Interesser", icon: "puzzlepiece", categories: [
        FilterOption(value: "Hobbies", label: "Hobbyer"),
        FilterOption(value: "Games", label: "Spill"),
        FilterOption(value: "Video-Games", label: "Videospill"),
        FilterOption(value: "Tabletop", label: "Brettspill"),
        FilterOption(value: "Role-Playing", label: "Rollespill"),
        FilterOption(value: "Crafts", label: "Håndverk"),
        FilterOption(value: "Automotive", label: "Bil og motor"),
        FilterOption(value: "Aviation", label: "Luftfart"),
        FilterOption(value: "Garden", label: "Hage"),
        FilterOption(value: "Pets", label: "Kjæledyr"),
        FilterOption(value: "Animals", label: "Dyr"),
        FilterOption(value: "Food", label: "Mat"),
        FilterOption(value: "Manga", label: "Manga"),
    ]),
    CategoryGroup(title: "Film & Medier", icon: "play.rectangle", categories: [
        FilterOption(value: "Film", label: "Film"),
        FilterOption(value: "TV", label: "TV"),
        FilterOption(value: "Animation", label: "Animasjon"),
        FilterOption(value: "Reviews", label: "Anmeldelser"),
        FilterOption(value: "After-Shows", label: "Etterprat"),
        FilterOption(value: "Documentary", label: "Dokumentar"),
    ]),
    CategoryGroup(title: "Familie & Relasjoner", icon: "person.2", categories: [
        FilterOption(value: "Family", label: "Familie"),
        FilterOption(value: "Kids", label: "Barn"),
        FilterOption(value: "Parenting", label: "Foreldreskap"),
        FilterOption(value: "Relationships", label: "Forhold"),
        FilterOption(value: "Social", label: "Sosialt"),
        FilterOption(value: "Home", label: "Hjem"),
    ]),
    CategoryGroup(title: "Religion & Livssyn", icon: "sparkles", categories: [
        FilterOption(value: "Religion", label: "Religion"),
        FilterOption(value: "Christianity", label: "Kristendom"),
        FilterOption(value: "Islam", label: "Islam"),
        FilterOption(value: "Buddhism", label: "Buddhisme"),
        FilterOption(value: "Hinduism", label: "Hinduisme"),
        FilterOption(value: "Judaism", label: "Jødedom"),
    ]),
    CategoryGroup(title: "Reise & Natur", icon: "mountain.2", categories: [
        FilterOption(value: "Travel", label: "Reise"),
        FilterOption(value: "Places", label: "Steder"),
        FilterOption(value: "Wilderness", label: "Villmark"),
    ]),
    CategoryGroup(title: "Annet", icon: "ellipsis.circle", categories: [
        FilterOption(value: "Alternative", label: "Alternativt"),
        FilterOption(value: "Journals", label: "Dagbøker"),
        FilterOption(value: "Interviews", label: "Intervjuer"),
    ]),
]

// Flat list for compatibility (used by search/browse APIs)
let allCategories: [FilterOption] = categoryGroups.flatMap(\.categories)

// Build lookup map for O(1) translation
private let categoryLookup: [String: String] = {
    var map = Dictionary(uniqueKeysWithValues: allCategories.map { ($0.value, $0.label) })
    // Add common API variations
    map["Natural"] = "Natur"
    map["Soccer"] = "Fotball"
    return map
}()

func translateCategory(_ name: String) -> String {
    categoryLookup[name] ?? name
}
