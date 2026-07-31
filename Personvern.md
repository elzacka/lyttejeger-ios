# Personvern

*Sist oppdatert: 31. juli 2026*

## Kort oppsummert

Lyttejeger samler ikke inn personopplysninger. Alt appen lagrer, blir liggende lokalt på iPhonen din.

## Hva appen lagrer

Lyttejeger lagrer bare det som trengs for at appen skal fungere:

- **Avspillingsposisjon** for episoder du har lyttet til
- **Spillekø** med episoder du har lagt til
- **Abonnementer** på podkaster du har valgt å følge

Dette ligger i appens lokale database og synkroniseres ikke til noen sky- eller nettjeneste. Sletter du appen, slettes også all data.

I tillegg holder appen midlertidige data i minnet, som transkripsjoner og kapittelmerker, for å svare raskere. Disse forsvinner når appen lukkes.

## Tredjepartstjenester

### Podcast Index

Når du søker etter podkaster, sendes søketeksten til serverne til Podcast Index. IP-adressen din er synlig for dem i forbindelse med forespørselen. Lyttejeger sender ingen brukeridentifikatorer, enhets-ID-er eller sporingsinformasjon. Se [personvernerklæringen til Podcast Index](https://podcastindex.org/privacy) for detaljer.

### NRK-podkaster

Appen henter NRK-katalogen og RSS-feeder fra et offentlig GitHub-repo. IP-adressen din er synlig for GitHub i forbindelse med disse forespørslene. Ingen brukerdata sendes utover det.

### Podkastutgivere

Når du spiller av eller laster ned en episode, hentes lydfilen direkte fra utgiveren. IP-adressen din er synlig for dem.

## Hva appen ikke gjør

- Samler ikke inn navn, e-postadresser eller kontoer
- Har ingen analyse- eller sporingsverktøy
- Bruker ingen annonseringsnettverk
- Synkroniserer ingen data til skytjenester
- Deler ingen data med tredjeparter
- Bruker ingen informasjonskapsler
- Krever ingen innlogging

## Hvor lenge data lagres

Avspillingsposisjoner for ferdige episoder slettes automatisk etter 90 dager. Posisjoner for episoder du ikke har hørt ferdig, slettes etter 180 dager. Abonnementer og spillekø ligger til du sletter dem selv.

## Dine rettigheter

Lyttejeger lagrer ingen personopplysninger sentralt. Det finnes derfor ingen sentral data å be om innsyn i, rette eller slette.

Du kan når som helst eksportere alt appen har lagret, importere data du har med deg, eller slette alt. Alle tre ligger under **Dine data** i menyen i appen. Du kan også slette appen fra enheten.

Eksport gir deg enten en JSON-fil med alt, eller en OPML-fil med abonnementene dine. OPML kan leses av andre podkastapper, så du står fritt til å ta dataene dine med videre.

Når du importerer en OPML-fil, sender appen feed-adressene i filen til Podcast Index for å hente tittel, bilde og annen informasjon om podkastene. Det er den eneste gangen import bruker nettet. NRK-feeder gjenkjennes lokalt og sendes ikke. Import av JSON skjer helt lokalt.

## Feilsøkingslogger

Appen bruker den innebygde loggfunksjonen til Apple (`os.Logger`) for tekniske feilmeldinger. Loggene ligger bare lokalt på enheten, sendes aldri til oss eller tredjeparter, og er synlige bare via utviklerverktøyene til Apple når enheten er koblet til en Mac.

## Sikkerhet

- All nettverkskommunikasjon skjer over HTTPS, med unntak av lydstrømmer fra utgivere som ikke tilbyr HTTPS
- Sertifikatpinning sikrer kommunikasjonen med Podcast Index
- API-nøkler er skjult i appen
- Appen bruker ingen tredjepartsbiblioteker

Du kan kontrollere alle påstandene i denne erklæringen ved å lese [kildekoden](https://github.com/elzacka/lyttejeger-ios).

## Kontakt

Har du spørsmål om personvern, kan du opprette en sak på [GitHub](https://github.com/elzacka/lyttejeger-ios/issues) eller sende e-post til hei@tazk.no.
