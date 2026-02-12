# Lyttejeger

En podkastspiller for iOS, skrevet i SwiftUI. Rolig, retro design uten sporing eller kontoer.

## Funksjoner

- Søk etter podkaster via [Podcast Index](https://podcastindex.org)
- NRK-podkaster via dedikert katalog
- Spillekø med manuell sortering
- Abonnementer med nytt-fra-mine-podder-visning
- Fullskjermspiller med kapitler, transkripsjoner og sovetimer
- Eksplisitt-merking per Apple og Podcast Index sine retningslinjer
- Sortering og filtrering: språk, kategori, dato, popularitet
- Avansert søk med eksakte fraser (`"..."`), ekskludering (`-ord`) og OR-operator
- All data lagres lokalt — ingen sky, ingen kontoer

## Teknologi

| | |
|---|---|
| **Språk** | Swift 6.2, streng samtidighet |
| **Rammeverk** | SwiftUI, SwiftData, AVFoundation, MediaPlayer |
| **Minstekrav** | iOS 26, iPhone (stående) |
| **Avhengigheter** | Ingen tredjepartsbiblioteker |
| **Byggverktøy** | Xcode 26.2, xcodegen |
| **Typografi** | DM Mono (inkludert) |
| **Design** | Lys modus, beige/grønn retro |

## Bygg

Prosjektet bruker [xcodegen](https://github.com/yonaskolb/XcodeGen) for å generere `.xcodeproj` fra `project.yml`.

```bash
# Installer xcodegen (første gang)
brew install xcodegen

# Generer Xcode-prosjekt
xcodegen generate

# Bygg
xcodebuild -project Lyttejeger.xcodeproj -scheme Lyttejeger \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' build
```

API-nøkler er ikke inkludert i repoet. Opprett `Lyttejeger/Config/Secrets.swift` med dine egne Podcast Index-nøkler. Se [podcastindex.org/developer](https://podcastindex.org/developer) for å registrere deg.

## Prosjektstruktur

```
Lyttejeger/
  Config/          Konstanter, hemmeligheter (gitignored)
  Data/            Kategorier, språk (norske oversettelser)
  Models/          Podcast, Episode, SwiftData-modeller
  Services/        API-klienter (actor), lydtjeneste, transformasjoner
  Theme/           Farger, typografi, spacing
  Utilities/       Hastighetsbegrenser, søkeparser, tidsformatering
  ViewModels/      Søk, kø, abonnementer, spiller, fremdrift
  Views/
    Common/        Gjenbrukbare komponenter (bildecache, meny, personvern)
    Library/       Mine podder, kø
    Player/        Spiller, kontroller, kapitler, transkripsjoner
    Podcast/       Podkastdetaljer
    Search/        Hjem, søk, episodekort, filtre
```

## Personvern

Lyttejeger samler ikke inn personopplysninger. All data lagres lokalt på din iPhone. Les hele [personvernerklæringen](Personvern.md).

## Sikkerhet

Oppdaget en sårbarhet? Se [SECURITY.md](SECURITY.md) for rapportering.

## Lisens

MIT — se [LICENSE](LICENSE).

## Kontakt

hei@tazk.no
