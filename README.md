# Lyttejeger

En podkastspiller for iOS, laget i Swift. Rolig, retro design uten sporing eller kontoer.

## Funksjoner

- Søk etter podkaster via [Podcast Index](https://podcastindex.org)
- NRK-podkaster via dedikert katalog
- Spillekø med manuell sortering, total spilletid og automatisk avspilling av neste episode
- Abonnementer med egen visning av nye episoder
- Fullskjermspiller med kapitler, transkripsjoner og søvntimer
- Avspillingshastighet per podkast, som appen husker
- Smart gjenopptakelse med 10 sekunders tilbakespoling etter lange pauser
- Eksport av lydfiler direkte fra spilleren
- Import og eksport av egne data: OPML for abonnementer, JSON for alt
- Eksplisitt-merking etter retningslinjene til Apple og Podcast Index
- Sortering og filtrering på språk, kategori, dato, popularitet og varighet
- Avansert søk med eksakte fraser (`"..."`), ekskludering (`-ord`) og OR-operator
- Bakgrunnsoppdatering av abonnementer
- All data lagres lokalt, uten sky og kontoer

Se [brukerveiledningen](Brukerveiledning.md) for hvordan appen brukes.

## Teknologi

| Område | Valg |
| ----------------- | --------------------------------------------- |
| **Språk**         | Swift 6.3, strict concurrency                 |
| **Rammeverk**     | SwiftUI, SwiftData, AVFoundation, MediaPlayer |
| **Minstekrav**    | iOS 26, iPhone                                |
| **Avhengigheter** | Ingen tredjepartsbiblioteker                  |
| **Tester**        | Swift Testing (enhetstester) og XCUITest (grensesnitt) |
| **Byggverktøy**   | Xcode 26.6, xcodegen                          |
| **Typografi**     | DM Mono (inkludert)                           |
| **Design**        | Lys modus, beige/blågrønn retro               |

## Bygg

Prosjektet bruker [xcodegen](https://github.com/yonaskolb/XcodeGen) for å generere `.xcodeproj` fra `project.yml`.

```bash
# Installer xcodegen (første gang)
brew install xcodegen

# Opprett Secrets.swift (første gang) og legg inn dine egne nøkler
# NB: må gjøres før xcodegen, ellers kommer ikke filen med i prosjektet
cp Lyttejeger/Config/Secrets.example.swift Lyttejeger/Config/Secrets.swift

# Generer Xcode-prosjekt
xcodegen generate

# Bygg
xcodebuild -project Lyttejeger.xcodeproj -scheme Lyttejeger \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' build

# Kjør tester
xcodebuild -project Lyttejeger.xcodeproj -scheme Lyttejeger \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' test
```

API-nøkler ligger ikke i repoet. Registrer deg på [podcastindex.org/developer](https://podcastindex.org/developer) og legg inn dine egne nøkler i `Lyttejeger/Config/Secrets.swift`.

Appen bruker ikke sertifikatpinning. Begrunnelsen og resten av sikkerhetsmodellen står i [SECURITY.md](SECURITY.md).

## Prosjektstruktur

```
Lyttejeger/
  Config/          Konstanter, hemmeligheter (gitignored)
  Data/            Kategorier, språk
  Models/          Podcast, Episode, SwiftData-modeller
  Services/        API-klienter (actor), lydtjeneste, bakgrunnsoppdatering
  Theme/           Farger, typografi, spacing
  Utilities/       Hastighetsbegrenser, søkeparser, tidsformatering, TTL-cache
  ViewModels/      Søk, kø, abonnementer, spiller, fremdrift
  Views/
    Common/        Gjenbrukbare komponenter (bildecache, meny, episodekort, menyrader)
    Library/       Følgeliste, kø
    Player/        Spiller, kontroller, kapitler, transkripsjoner
    Podcast/       Podkastdetaljer
    Search/        Hjem, søk, podkastkort, filtre
  Preview Content/ Forhåndsvisningsdata for SwiftUI Previews
LyttejegerTests/   Enhetstester (Swift Testing)
LyttejegerUITests/ Grensesnittstester (XCUITest)
```

## Personvern

Se [personvernerklæringen](Personvern.md).

## Sikkerhet

Oppdaget en sårbarhet? Se [SECURITY.md](SECURITY.md) for rapportering.

## Lisens

MIT. Se [LICENSE](LICENSE).

## Kontakt

hei@tazk.no
