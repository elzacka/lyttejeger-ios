# Lyttejeger

En podkastspiller for iOS, skrevet i SwiftUI. Rolig, retro design uten sporing eller kontoer.

## Funksjoner

- Sok etter podkaster via [Podcast Index](https://podcastindex.org)
- NRK-podkaster via dedikert katalog
- Spilleko med manuell sortering
- Abonnementer med nytt-fra-mine-podder-visning
- Fullskjermspiller med kapitler, transkripsjoner og sovetimer
- Eksplisitt-merking per Apple og Podcast Index sine retningslinjer
- Sortering og filtrering: sprak, kategori, dato, popularitet
- Avansert sok med eksakt fraser (`"..."`), ekskludering (`-ord`) og OR-operator
- All data lagres lokalt — ingen sky, ingen kontoer

## Teknologi

| | |
|---|---|
| **Sprak** | Swift 6.2, streng samtidighet |
| **Rammeverk** | SwiftUI, SwiftData, AVFoundation, MediaPlayer |
| **Minkrav** | iOS 26, iPhone (staaende) |
| **Avhengigheter** | Ingen tredjepartsbiblioteker |
| **Byggverktoy** | Xcode 26.2, xcodegen |
| **Typografi** | DM Mono (inkludert) |
| **Design** | Lys modus, beige/gronn retro |

## Bygg

Prosjektet bruker [xcodegen](https://github.com/yonaskolb/XcodeGen) for a generere `.xcodeproj` fra `project.yml`.

```bash
# Installer xcodegen (forste gang)
brew install xcodegen

# Generer Xcode-prosjekt
xcodegen generate

# Bygg
xcodebuild -project Lyttejeger.xcodeproj -scheme Lyttejeger \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' build
```

API-nokler er ikke inkludert i repoet. Opprett `Lyttejeger/Config/Secrets.swift` med dine egne Podcast Index-nokler. Se [podcastindex.org/developer](https://podcastindex.org/developer) for a registrere deg.

## Prosjektstruktur

```
Lyttejeger/
  Config/          Konstanter, hemmeligheter (gitignored)
  Data/            Kategorier, sprak (norske oversettelser)
  Models/          Podcast, Episode, SwiftData-modeller
  Services/        API-klienter (actor), lydtjeneste, transformasjoner
  Theme/           Farger, typografi, spacing
  Utilities/       Ratebegrenser, sokparser, tidsformatering
  ViewModels/      Sok, ko, abonnementer, spiller, fremgang
  Views/
    Common/        Gjenbrukbare komponenter (bildecache, meny, personvern)
    Library/       Mine podder, ko
    Player/        Spiller, kontroller, kapitler, transkripsjoner
    Podcast/       Podkastdetaljer
    Search/        Hjem, sok, episodekort, filtre
```

## Personvern

Lyttejeger samler ikke inn personopplysninger. All data lagres lokalt pa din iPhone. Les hele [personvernerklaering](Personvern.md).

## Sikkerhet

Oppdaget en sarbarhet? Se [SECURITY.md](SECURITY.md) for rapportering.

## Lisens

MIT — se [LICENSE](LICENSE).

## Kontakt

hei@tazk.no
