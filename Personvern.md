# Personvern

*Sist oppdatert: 2. mars 2026*

## Kort oppsummert

Lyttejeger samler ikke inn personopplysninger. All data lagres lokalt på din iPhone og forlater aldri telefonen din.

## Hva appen lagrer

Lyttejeger lagrer kun det som trengs for at appen skal fungere, og alt lagres lokalt på din iPhone:

- **Avspillingsposisjon** for episoder du har lyttet til
- **Spillekø** med episoder du har lagt til
- **Abonnementer** på podkaster du har valgt å følge

Denne informasjonen lagres i appens lokale database og synkroniseres ikke til noen sky- eller nettjeneste. Hvis du sletter appen, slettes også all data.

I tillegg lagrer appen midlertidige data i minnet (som transkripsjoner og kapittelmerker) for å gi raskere respons. Disse forsvinner automatisk når appen lukkes.

## Tredjepartstjenester

### Podcast Index API

Når du søker etter podkaster, sendes søketeksten til Podcast Index sine servere. IP-adressen din er synlig for dem i forbindelse med forespørselen. Lyttejeger sender ingen brukeridentifikatorer, enhets-ID-er eller sporingsinformasjon. Se [Podcast Index sin personvernpolicy](https://podcastindex.org/privacy) for detaljer.

### NRK-podkaster

Lyttejeger henter NRK-podkastkatalogen og RSS-feeder fra et offentlig GitHub-repo (GitHub Pages). IP-adressen din er synlig for GitHub i forbindelse med disse forespørslene. Ingen brukerdata sendes utover det.

## Hva appen ikke gjør

- Samler ikke inn navn, e-postadresser eller kontoer
- Har ingen analyse- eller sporingsverktøy
- Bruker ingen annonseringsnettverk
- Synkroniserer ingen data til skytjenester
- Deler ingen data med tredjeparter
- Bruker ingen informasjonskapsler (cookies)
- Krever ingen innlogging

## Datalagring og sletting

Avspillingsposisjoner for ferdige episoder slettes automatisk etter 90 dager. All annen data (abonnementer, spillekø) lagres inntil du sletter den manuelt.

## Dine rettigheter

Ettersom Lyttejeger ikke samler inn personopplysninger sentralt, er det ingen data å be om innsyn i, rette eller slette.

Du kan når som helst slette all lokalt lagret data via innstillingene i appen (Meny > Om Lyttejeger), eller ved å slette appen fra enheten.

## Eksport av data

Du kan eksportere all lokalt lagret data som en JSON-fil i appen (Meny > Om Lyttejeger). Denne filen inneholder abonnementer, spillekø og avspillingsposisjoner.

## Feilsøkingslogger

Appen bruker Apples innebygde loggfunksjon (`os.Logger`) for å registrere tekniske feilmeldinger. Disse loggene lagres kun lokalt på enheten, sendes aldri til oss eller tredjeparter, og er bare synlige via Apples utviklerverktøy når enheten er koblet til en Mac.

## Sikkerhet

- All nettverkskommunikasjon skjer over HTTPS
- API-nøkler er obfuskert i appen
- Sertifikatpinning sikrer kommunikasjon med Podcast Index
- Appen bruker ingen tredjepartsbiblioteker

## Kontakt

Har du spørsmål om personvern, kan du opprette en sak på [GitHub](https://github.com/elzacka/lyttejeger-ios/issues) eller kontakte meg på hei@tazk.no

## Åpen kildekode

Lyttejeger er åpen kildekode. Du kan inspisere all kode på [GitHub](https://github.com/elzacka/lyttejeger-ios).
