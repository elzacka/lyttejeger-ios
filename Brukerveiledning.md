# Brukerveiledning

*Sist oppdatert: 12. februar 2026*

## Søk

Lyttejeger søker i to datakilder: [Podcast Index](https://podcastindex.org/) (åpen podkast-katalog med over 4 millioner podkaster) og NRK-podkaster (via åpne RSS-feeder). Resultater fra begge kildene vises samlet.

### Faner

- **Podkaster** — søker etter podkaster basert på tittel, beskrivelse og forfatter.
- **Episoder** — søker etter enkeltepisoder basert på tittel, beskrivelse og medvirkende.

### Søkeoperatorer

Du kan bruke spesielle operatorer for å presisere søket:

| Operator | Syntaks | Eksempel | Beskrivelse |
|----------|---------|----------|-------------|
| OG | mellomrom | `true crime` | Alle ordene må finnes (standard) |
| ELLER | `OR` | `krim OR true crime` | Minst ett av uttrykkene må finnes |
| Nøyaktig frase | `"frase"` | `"true crime"` | Hele frasen må finnes nøyaktig som skrevet |
| Utelukk | `-ord` | `krim -mord` | Fjerner resultater som inneholder ordet |

Operatorer kan kombineres fritt:

- `"true crime" -mord` — nøyaktig frase, men utelukk resultater med «mord»
- `fotball OR håndball -premier league` — fotball eller håndball, men ikke Premier League

**Tips:** iOS-tastaturet bytter automatisk ut bindestreken `-` med tankestrek `–` og rette anførselstegn `"` med typografiske `""`. Lyttejeger håndterer dette automatisk, så du trenger ikke tenke på det.

## Filter

Trykk på filterknappen ved siden av søkefeltet for å åpne filterpanelet. Aktive filter vises som merkede knapper øverst i panelet, og kan fjernes enkeltvis ved å trykke på krysset.

### Språk

Filtrerer resultater etter podkastens språk. Tilgjengelige valg:

- **Norsk** — inkluderer bokmål og nynorsk
- **Engelsk** — inkluderer alle engelske varianter (US, UK, AU, m.fl.)
- **Svensk**
- **Dansk**

Du kan velge flere språk samtidig. Uten språkfilter vises kun resultater på norsk, engelsk, svensk og dansk.

### Sortering

Endrer rekkefølgen på resultatene:

- **Relevans** — standard, sorterer etter treff i tittel, forfatter og aktualitet
- **Nyeste** — nylig oppdaterte podkaster eller nylig publiserte episoder først
- **Eldste** — eldst først
- **Populære** — podkaster med flest episoder først

### Kategorier

Filtrerer etter podkastens kategori fra Podcast Index sin taksonomi. Det finnes over 100 kategorier, fra «Astronomi» til «Vær». Du kan velge flere kategorier samtidig.

Kategorier fungerer for begge faner:

- **Podkaster** — viser kun podkaster som tilhører valgt(e) kategori(er)
- **Episoder** — viser kun episoder fra podkaster som tilhører valgt(e) kategori(er)

### Varighet

Kun tilgjengelig på **Episoder**-fanen. Filtrerer episoder etter lengde:

- **Under 15 min**
- **15–30 min**
- **30–60 min**
- **Over 60 min**

## Kombinere søk, operatorer og filter

Alle søkeoperatorer og filter kan kombineres fritt. For eksempel:

- Søk etter `"true crime"` med språk satt til **Norsk** og kategori **Krim** — gir norskspråklige true crime-podkaster
- Søk etter `fotball -tipping` på **Episoder**-fanen med varighet **Under 15 min** — gir korte fotballepisoder uten tippestoff
- Søk etter `teknologi OR vitenskap` sortert etter **Nyeste** — gir de ferskeste podkastene om teknologi eller vitenskap

## NRK-podkaster

NRK-podkaster er integrert i søket og vises sammen med øvrige resultater. Vær oppmerksom på at NRK-podkaster har noen begrensninger:

- **Kategorier** har ingen effekt — NRK-katalogen inneholder ikke kategoriinformasjon
- **Sortering** etter nyeste/eldste/populære er begrenset — NRK-katalogen mangler oppdateringsdato og popularitetsdata
- **Søkeoperatorer** fungerer best med enkle søkeord — NRK-søket matcher mot podkasttittel

For best resultat med NRK-podkaster: bruk enkle søkeord og eventuelt språkfilteret **Norsk**.

## Bla uten søkeord

Hvis du ikke skriver et søkeord, men aktiverer et eller flere filter, viser Lyttejeger populære podkaster som matcher filtrene dine. Dette er nyttig for å oppdage nye podkaster innen en bestemt kategori eller på et bestemt språk.
