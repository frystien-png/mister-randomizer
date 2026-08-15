# Randomizer och spelbläddrare för MiSTer FPGA

*Svenska · [English](README.md)*

Två saker som delar samma lilla webbserver på MiSTern, båda gjorda för att
styras från telefonen:

**Seedsidan** — en seedgenerator och en spoilerfri tracker för *A Link to
the Past Randomizer* och *SMZ3* (Super Metroid + ALTTP kombinerat). Kartan
visar var du varit och — det som är hela poängen — vad du faktiskt kan nå
med det du har. Åtkomstlogiken är Archipelagos egen, alltså samma
regelverk som genererade seeden.

**Spelbläddraren** — alla dina MiSTer-spel som en lista i mobilen. Tryck
på ett spel, så byter MiSTern core och startar det. Systemen med bara ett
fåtal spel samlas bakom en enda ruta så att startsidan går att överblicka.

> **Inga ROM följer med, och inga kan följa med.** Bläddraren listar det
> som redan ligger på ditt eget SD-kort — har du inga spel där får du en
> tom lista. Det gäller också basrommen till seedgenereringen: de måste
> vara dina egna dumpar. Se *Dina egna ROM* nedan.

<p align="center">
  <img src="docs/seed-page.png" alt="Seed-sidan med två runs bredvid varandra" width="900">
</p>

<p align="center">
  <img src="docs/map-light-world.png" alt="Ljusvärlden med dungeonräknare" width="440">
  <img src="docs/map-zebes.png" alt="Zebes-kartan med tömda platser" width="440">
</p>

<p align="center">
  <em>Grönt går att nå nu, rött är låst, grått är klart. Etiketterna räknar
  kistorna som är kvar i varje dungeon.</em>
</p>

<p align="center">
  <img src="docs/game-browser.png" alt="Spelbläddraren med alla system på kortet" width="900">
</p>

---

## Vad du behöver

**Två maskiner, inte fler:**

1. En **MiSTer FPGA** på nätverket.
2. En **Home Assistant**-server — *Home Assistant OS* eller *Supervised*.
   Det här är ett hårt krav: HA Container och HA Core kan inte installera
   tillägg, och logiken är ett tillägg.

### Dina egna ROM

Spelbläddraren behöver inget alls — den visar de spel du redan har under
`/media/fat/games/`.

**Seedgenereringen** behöver två dumpar utan header, som du måste äga och
dumpa själv:

```
alttp.smc   1 048 576 byte   md5 03a63945398191337e896e5771f77173
sm.smc      3 145 728 byte   md5 21f3e98df4780ee1c667b84e57d88675
```

(Zelda 3 japansk 1.0 respektive Super Metroid JU.) Installationen letar
upp dem åt dig bland dina SNES-ROM — även inuti `.zip` och även om de har
en 512 byte lång header — så oftast behöver du inte göra något alls.

## Installation

Halvorna är oberoende av varandra och kan installeras i vilken ordning
som helst. Men börja med Home Assistant: då kan MiSTer-installationen
kontrollera att logiken svarar innan den säger sig vara klar.

### 1. Home Assistant

1. **Inställningar → Tillägg → Tilläggsbutiken**
2. Menyn uppe till höger → **Arkiv** → klistra in:
   ```
   https://github.com/frystien-png/mister-randomizer
   ```
3. Stäng rutan, leta upp **SMZ3- och ALTTPR-logik** → **Installera**
4. Fliken **Konfiguration** → fyll i MiSTerns IP-adress → **Spara**
5. **Starta**

Första bygget tar några minuter — Archipelago hämtas och trimmas då.

*Utan GitHub:* kopiera mappen `smz3-logic/` till Home Assistants
`/addons/` (via Samba- eller SSH-tillägget), välj **Sök efter
uppdateringar** i tilläggsbutikens meny, så dyker den upp under **Lokala
tillägg**.

### 2. MiSTer

Lägg **en enda fil** i `/media/fat/Scripts/` på SD-kortet — resten hämtar
den själv:

```
https://raw.githubusercontent.com/frystien-png/mister-randomizer/main/mister/Randomizer_install.sh
```

Kör sedan **Scripts → Randomizer_install** i MiSTer-menyn.

*Utan internet på MiSTern:* lägg `randomizer-payload.tar.gz` bredvid
skriptet, så används den i stället för nedladdningen.

Installationen letar själv upp Home Assistant, lägger ut filerna, skapar
menyposterna, ordnar autostart och startar servern. Den går att köra om
när som helst — dina anteckningar och kartmarkeringar rörs inte, och en
befintlig uppsättning skrivs inte över.

## Språk

Sidorna översätts när de serveras. **Engelska är standard**; installationen
frågar, och valet hamnar i `.mistergames/randomizer.conf`:

```
MISTER_LANG="sv"
```

Ändra raden och starta om MiSTern för att byta språk — ingen ominstallation
behövs. Med följer `en` (källspråk och standard), `es`, `fr`, `pl` och `sv`.

### Eget språk

Allt som behövs ligger redan på MiSTern, i `.mistergames/lang/`:

1. Kopiera `TEMPLATE.json` till `<kod>.json`, t.ex. `de.json`.
2. Sätt `__name` till språkets eget namn.
3. Översätt **högerledet**. Vänsterledet är den engelska källsträngen och
   får aldrig ändras — det är nyckeln som matchas i sidan.
4. Det du inte översätter står kvar på engelska, så en halvfärdig
   översättning fungerar utmärkt.
5. Kör installationen igen och välj språket ur menyn.

`python3 lang_check.py` granskar filerna: den visar hur stor del av mallen
du täckt och stoppar de två fel som faktiskt går sönder — en nyckel som
inte finns i sidorna (nästan alltid ett stavfel, ett saknat avslutande
mellanslag räcker) och en nyckel som också används som CSS-klass.

⚠️ **Föremålsnamnen står på engelska i alla språk utom svenska.** Det är
med flit: randomizersamfundet använder de engelska namnen oavsett språk.
Koden är skriven på engelska sedan 2026-08-14, så svenskan är numera en
översättning som alla andra.


## Så används det

| | |
|---|---|
| **Spelbläddraren** | `http://<mister-ip>:8182/` |
| **Seed-sidan** | `http://<mister-ip>:8182/seeds` |
| **Tillbaka till menyn** | knappen `⏏ Meny` i sidhuvudet, syns när ett spel kör |
| **Ny ALTTPR-seed** | MiSTer-menyn → Scripts → `ALTTPR_new_seed` |
| **Ny SMZ3-seed** | MiSTer-menyn → Scripts → `SMZ3_new_seed` |

Lägg till båda sidorna i Home Assistant som var sitt kort av typen
**webbsida** med MiSTerns adress, så når du dem från telefonen.

Bläddraren läser om spelmapparna var femtonde minut, och direkt om du
anropar `http://<mister-ip>:8182/api/rescan`. Nya spel dyker alltså upp av
sig själva utan omstart.

## Live-läsning (SNI)

Installationen erbjuder att sätta upp **SNI**, som låter servern läsa
spelets minne direkt. Då uppdateras kartan **medan du spelar**, i stället
för först när du öppnar OSD-menyn.

Det bygger på stöd som redan finns i MiSTers officiella SNES-core (sedan
mars 2026) och i huvudprogrammet (sedan april). Det som saknas är
daemonen [`snid`](https://github.com/NobodyNada/snid), som installationen
hämtar och kontrollerar mot en känd kontrollsumma.

**Ett steg måste du göra själv, en enda gång:** starta ett SNES-spel,
öppna OSD-menyn och välj **UART MODE → SNI**. Läget skickas till coren av
menyn, inte av någon fil, så det går inte att göra åt dig. Valet sparas
per core och återställs sedan automatiskt.

Kontrollera att det fungerar med `curl http://<mister>:8182/api/smz3` —
fältet `live` ska vara `true` för seeden som kör.

⚠️ På en MiSTer som funnits ett tag kan systemfilen `/usr/sbin/uartmode`
vara för gammal och sakna SNI-läget. Installationen upptäcker det och
frågar innan den rör något; originalet sparas som `uartmode.original` på
SD-kortet. En framtida firmware-uppdatering kan skriva över ändringen —
kör då installationen igen.

Hoppar du över SNI fungerar allt som förut, med sparfilen som källa.

## Det du måste veta i förväg

**Utan SNI skrivs sparfilen bara när du öppnar OSD-menyn.** MiSTer skriver
ut spelets sparminne till SD-kortet först då — inte löpande. Trackern kan
alltså inte se något du gjort sedan sist du öppnade menyn. Vana att lägga
sig till med: **öppna och stäng OSD:n när du sparat.**

Av samma skäl: **starta inte ett nytt spel från bläddraren mitt i en run**
utan att först ha öppnat OSD:n. Corebytet sker omedelbart och allt sedan
förra utskrivningen försvinner — det gäller alla spel, inte bara
randomizerseeds. Det går inte att lösa i mjukvaran: `/dev/MiSTer_cmd`
förstår bara `load_core` och en handfull bild- och ljudkommandon, inget
sätt att öppna menyn eller be om en sparning.

**Ge båda maskinerna fasta adresser** i routern. Byter någon av dem IP
slutar de hitta varandra, och det visar sig som en karta som inte
uppdateras — inte som ett felmeddelande.

## Om något inte stämmer

| Symptom | Trolig orsak |
|---|---|
| Sidan svarar inte alls | Servern körs inte. `Randomizer_install` igen. |
| Kartan visas men prickarna är färglösa | Tillägget svarar inte. Kolla dess logg och `mister_ip`. |
| Kartan uppdateras inte efter spelande | Du har inte öppnat OSD:n. Sparfilen är inte utskriven än. |
| "Fel ROM" trots rätt spel | Du har en annan dump. Kontrollera md5 mot listan ovan. |
| Inget händer efter omstart av MiSTern | `user-startup.sh` får inte heta `_user-startup.sh`. |
| Nedladdningen misslyckas på MiSTern | Gammal certifikatlista. Kör **Scripts → update_all** en gång, eller lägg `randomizer-payload.tar.gz` bredvid skriptet. |

Logg på MiSTern: `/tmp/mistergames.log`.
Logiktjänsten: `curl http://<home-assistant>:8183/health`.

## Vad som INTE ingår

**Inga ROM, inga skivavbilder, ingenting upphovsrättsskyddat.** Paketet är
kod och datatabeller. Att det stämmer kontrolleras av `check_payload.sh`,
som körs vid varje bygge och vägrar packa ihop något som ser ut som ett
ROM — och som du kan köra själv på den nedladdade filen:

```
./check_payload.sh randomizer-payload.tar.gz
```

Vakten stoppar också **privata nätverksuppgifter**: RFC 1918-adresser,
MAC-adresser, delningsnamn, tokens och nycklar. Ingen ska kunna råka
publicera sitt hemmanät med en release.

Utanför paketet står också core-status till Home Assistant (`ha_push.py`)
och NAS-monteringen av PS1-/Saturn-skivor (`nas_mount.sh`). Bläddraren
listar allt som är monterat under `/media/fat/games/`, så har du en egen
nätverksmontering fungerar den — men uppsättningen av den får du göra
själv.

Har du redan en egen `page.py` lämnar installationen den orörd och lägger
sin egen bredvid som `page.py.ny`.

---

## Licens och tack

Projektet är **MIT-licensierat** — se [LICENSE](LICENSE). Använd, ändra och
sprid; behåll upphovsrättsraden och räkna inte med några garantier.

Det står på andras arbete:

| | |
|---|---|
| [Archipelago](https://github.com/ArchipelagoMW/Archipelago) (MIT) | själva åtkomstlogiken. Tillägget pinnar den till en exakt commit och svarar med dess regler, inte med egna. |
| [hutchch/ALTTPR-Tracker](https://github.com/hutchch/ALTTPR-Tracker) (MIT) | kisttabellen som kopplar varje ALTTP-plats till sin exakta SRAM-flagga, och upplägget för medaljongvalet. |
| [TotalSMZ3](https://github.com/tewtal/SMZ3Randomizer) | SMZ3-logiken och den ROM-layout combo-bygget följer. |
| [pyz3r](https://github.com/tcprescott/pyz3r) (Apache-2.0) | tre vendorade filer för att applicera ALTTPR-patchar. Ändrat: aiohttp utbytt mot urllib, eftersom MiSTern saknar pip. Licens och NOTICE följer med i paketet. |
| [bps](https://pypi.org/project/bps/) (WTFPL) | vendorad BPS-patchning. COPYING följer med i paketet. |
| [snid](https://github.com/NobodyNada/snid) av NobodyNada | daemonen som gör live-läsning av SNES-minnet möjlig. Hämtas på begäran, paketeras aldrig. |
| alttpr.com och samus.link | seedgenerering och sprites. Bara patchdata utväxlas; ingen ROM laddas någonsin upp. |
| Skärmbilderna | Kartorna bakom prickarna är spelens egen grafik (© Nintendo); Zebes-kartan är gjord av Falcon Zero. De illustrerar trackern — ingen speldata följer med projektet. |

**Ingen speldata av något slag ingår** — se avsnittet *Vad som INTE ingår*.

## För den som bygger vidare

```
├── repository.yaml          maste ligga i roten - HA letar efter den dar
├── smz3-logic/              sjalva tillagget
│   ├── config.yaml          installningar, portar, arkitekturer
│   ├── Dockerfile           hamtar och trimmar Archipelago
│   └── logik/               reachd.py, smz3_logic.py, alttp_locmap.py
├── mister/
│   ├── Randomizer_install.sh
│   └── randomizer-payload.tar.gz
├── build_payload.sh            bygger om payloaden ur en korande MiSTer
└── check_payload.sh        vakten: inga rom, inga hemligheter
```

`build_payload.sh` hämtar hem koden från MiSTern och utelämnar det som är
personligt: ROM, lösenord, egna anteckningar. Innan något packas kör den
`check_payload.sh` på den uppackade katalogen — hittar vakten en
ROM-ändelse, en fil över 400 K, en binärfil av okänd typ, en hemlighet
eller ett användartillstånd som inte är tomt, avbryts bygget och den gamla
tarballen lämnas orörd.

Installationsskriptet går att provköra utan att röra en riktig
uppsättning:

```
FAT=/tmp/prov ./Randomizer_install.sh
```

Då rörs ingen körande server, och allt hamnar under `/tmp/prov`.
