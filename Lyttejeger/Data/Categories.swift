import Foundation

struct CategoryGroup: Identifiable, Sendable {
    var id: String { title }
    let title: String
    let icon: String
    let categories: [FilterOption]
}

let categoryGroups: [CategoryGroup] = [
    CategoryGroup(title: "Annet", icon: "ellipsis.circle", categories: [
        FilterOption(value: "Alternative", label: "Alternativt"),
        FilterOption(value: "Journals", label: "Dagbøker"),
        FilterOption(value: "Interviews", label: "Intervjuer"),
    ]),
    CategoryGroup(title: "Familie og relasjoner", icon: "person.2", categories: [
        FilterOption(value: "Kids", label: "Barn"),
        FilterOption(value: "Family", label: "Familie"),
        FilterOption(value: "Parenting", label: "Foreldreskap"),
        FilterOption(value: "Relationships", label: "Forhold"),
        FilterOption(value: "Home", label: "Hjem"),
        FilterOption(value: "Social", label: "Sosialt"),
    ]),
    CategoryGroup(title: "Film og medier", icon: "play.rectangle", categories: [
        FilterOption(value: "Animation", label: "Animasjon"),
        FilterOption(value: "Reviews", label: "Anmeldelser"),
        FilterOption(value: "Documentary", label: "Dokumentar"),
        FilterOption(value: "After-Shows", label: "Etterprat"),
        FilterOption(value: "Film", label: "Film"),
        FilterOption(value: "TV", label: "TV"),
    ]),
    CategoryGroup(title: "Helse og livsstil", icon: "heart.text.square", categories: [
        FilterOption(value: "Nutrition", label: "Ernæring"),
        FilterOption(value: "Health", label: "Helse"),
        FilterOption(value: "Life", label: "Liv"),
        FilterOption(value: "Medicine", label: "Medisin"),
        FilterOption(value: "Mental", label: "Mental helse"),
        FilterOption(value: "Personal", label: "Personlig"),
        FilterOption(value: "Sexuality", label: "Seksualitet"),
        FilterOption(value: "Self-Improvement", label: "Selvutvikling"),
        FilterOption(value: "Fitness", label: "Trening"),
    ]),
    CategoryGroup(title: "Hobbyer og interesser", icon: "puzzlepiece", categories: [
        FilterOption(value: "Automotive", label: "Bil og motor"),
        FilterOption(value: "Tabletop", label: "Brettspill"),
        FilterOption(value: "Animals", label: "Dyr"),
        FilterOption(value: "Garden", label: "Hage"),
        FilterOption(value: "Hobbies", label: "Hobbyer"),
        FilterOption(value: "Crafts", label: "Håndverk"),
        FilterOption(value: "Pets", label: "Kjæledyr"),
        FilterOption(value: "Aviation", label: "Luftfart"),
        FilterOption(value: "Manga", label: "Manga"),
        FilterOption(value: "Food", label: "Mat"),
        FilterOption(value: "Role-Playing", label: "Rollespill"),
        FilterOption(value: "Games", label: "Spill"),
        FilterOption(value: "Video-Games", label: "Videospill"),
    ]),
    CategoryGroup(title: "Krim og fiksjon", icon: "book", categories: [
        FilterOption(value: "Drama", label: "Drama"),
        FilterOption(value: "Fantasy", label: "Fantasy"),
        FilterOption(value: "Fiction", label: "Fiksjon"),
        FilterOption(value: "Stories", label: "Historier"),
        FilterOption(value: "True Crime", label: "Krim"),
    ]),
    CategoryGroup(title: "Kultur og underholdning", icon: "theatermasks", categories: [
        FilterOption(value: "Design", label: "Design"),
        FilterOption(value: "Comedy", label: "Humor"),
        FilterOption(value: "Improv", label: "Improvisasjon"),
        FilterOption(value: "Culture", label: "Kultur"),
        FilterOption(value: "Arts", label: "Kunst"),
        FilterOption(value: "Fashion", label: "Mote"),
        FilterOption(value: "Music", label: "Musikk"),
        FilterOption(value: "Performing", label: "Scenekunst"),
        FilterOption(value: "Beauty", label: "Skjønnhet"),
        FilterOption(value: "Stand-Up", label: "Standup"),
        FilterOption(value: "Entertainment", label: "Underholdning"),
        FilterOption(value: "Visual", label: "Visuell kunst"),
    ]),
    CategoryGroup(title: "Nyheter og samfunn", icon: "newspaper", categories: [
        FilterOption(value: "Daily", label: "Daglig"),
        FilterOption(value: "Government", label: "Forvaltning"),
        FilterOption(value: "Climate", label: "Klima"),
        FilterOption(value: "Commentary", label: "Kommentar"),
        FilterOption(value: "News", label: "Nyheter"),
        FilterOption(value: "Politics", label: "Politikk"),
        FilterOption(value: "Society", label: "Samfunn"),
    ]),
    CategoryGroup(title: "Næringsliv og karriere", icon: "briefcase", categories: [
        FilterOption(value: "Entrepreneurship", label: "Entreprenørskap"),
        FilterOption(value: "Non-Profit", label: "Ideelle org."),
        FilterOption(value: "Investing", label: "Investering"),
        FilterOption(value: "Careers", label: "Karriere"),
        FilterOption(value: "Management", label: "Ledelse"),
        FilterOption(value: "Marketing", label: "Markedsføring"),
        FilterOption(value: "Business", label: "Næringsliv"),
    ]),
    CategoryGroup(title: "Reise og natur", icon: "mountain.2", categories: [
        FilterOption(value: "Travel", label: "Reise"),
        FilterOption(value: "Places", label: "Steder"),
        FilterOption(value: "Wilderness", label: "Villmark"),
    ]),
    CategoryGroup(title: "Religion og livssyn", icon: "sparkles", categories: [
        FilterOption(value: "Buddhism", label: "Buddhisme"),
        FilterOption(value: "Hinduism", label: "Hinduisme"),
        FilterOption(value: "Islam", label: "Islam"),
        FilterOption(value: "Judaism", label: "Jødedom"),
        FilterOption(value: "Christianity", label: "Kristendom"),
        FilterOption(value: "Religion", label: "Religion"),
    ]),
    CategoryGroup(title: "Sport og fritid", icon: "sportscourt", categories: [
        FilterOption(value: "Baseball", label: "Baseball"),
        // "Football" is American football in the Podcast Index taxonomy;
        // association football is "Soccer". The chip labelled Fotball must
        // carry the Soccer value or it filters for the wrong sport.
        FilterOption(value: "Football", label: "Amerikansk fotball"),
        FilterOption(value: "Basketball", label: "Basketball"),
        FilterOption(value: "Wrestling", label: "Bryting"),
        FilterOption(value: "Cricket", label: "Cricket"),
        FilterOption(value: "Soccer", label: "Fotball"),
        FilterOption(value: "Leisure", label: "Fritid"),
        FilterOption(value: "Golf", label: "Golf"),
        FilterOption(value: "Hockey", label: "Hockey"),
        FilterOption(value: "Running", label: "Løping"),
        FilterOption(value: "Rugby", label: "Rugby"),
        FilterOption(value: "Sports", label: "Sport"),
        FilterOption(value: "Swimming", label: "Svømming"),
        FilterOption(value: "Tennis", label: "Tennis"),
        FilterOption(value: "Volleyball", label: "Volleyball"),
    ]),
    CategoryGroup(title: "Utdanning og kunnskap", icon: "graduationcap", categories: [
        FilterOption(value: "Books", label: "Bøker"),
        FilterOption(value: "Philosophy", label: "Filosofi"),
        FilterOption(value: "History", label: "Historie"),
        FilterOption(value: "Courses", label: "Kurs"),
        FilterOption(value: "Learning", label: "Læring"),
        FilterOption(value: "How-To", label: "Slik gjør du"),
        FilterOption(value: "Language", label: "Språk"),
        FilterOption(value: "Education", label: "Utdanning"),
    ]),
    CategoryGroup(title: "Vitenskap og teknologi", icon: "atom", categories: [
        FilterOption(value: "Astronomy", label: "Astronomi"),
        FilterOption(value: "Physics", label: "Fysikk"),
        FilterOption(value: "Earth", label: "Jorda"),
        FilterOption(value: "Chemistry", label: "Kjemi"),
        FilterOption(value: "Cryptocurrency", label: "Kryptovaluta"),
        FilterOption(value: "Mathematics", label: "Matematikk"),
        FilterOption(value: "Nature", label: "Natur"),
        FilterOption(value: "Technology", label: "Teknologi"),
        FilterOption(value: "Science", label: "Vitenskap"),
        FilterOption(value: "Weather", label: "Vær"),
    ]),
]

// Flat list for compatibility (used by search/browse APIs)
let allCategories: [FilterOption] = categoryGroups.flatMap(\.categories)

// Build lookup map for O(1) translation
private let categoryLookup: [String: String] = {
    var map = Dictionary(uniqueKeysWithValues: allCategories.map { ($0.value, $0.label) })
    // Add common API variations
    map["Natural"] = "Natur"
    return map
}()

func translateCategory(_ name: String) -> String {
    categoryLookup[name] ?? name
}
