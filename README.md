# Rytíři (pracovní název, ve hře „Knights“)

Taktický roguelike pro Steam ve středověku. Vedeš pět hrdinů jednoho rodu na výpravě. Hrdinové skládají přísahy, které dávají sílu za cenu, a kdo padne, zůstává padlý: jeho místo zaujme nástupce a přísahu po něm může převzít další hrdina.

Hra je v angličtině, dokumentace česky. Engine: Godot 4.7. Návrh názvu a identity (Oathline a další) je ve Figmě a čeká na rozhodnutí.

Aktualizováno 07.11.2026 (krok 2.3d).

## O co jde

**Háček:** velíš rodu, ne vojákovi. Každý běh je příběh jednoho rodu: kdo složil jakou přísahu, kdo ji porušil, kdo padl a kdo po něm převzal štít. Konec běhu shrne kronika rodu.

**Pilíře** (každá funkce musí aspoň jeden podporovat):
1. Velíš rodu: rod určuje, s kým a jak bojuješ; v bitvě ovládáš jeho hrdiny.
2. Přísaha má cenu: síla vždy za omezení.
3. Smrt má váhu: padlí zůstávají padlí a odkazují nástupcům.
4. Každý run je příběh rodu.

**Inspirace:** bitvy v reálném čase s pauzou v čitelném stylu Bad North, mapa běhu ve stylu Slay the Spire, rod a nástupci jako v Darkest Dungeon a Rogue Legacy.

## Jak se hraje

**Běh** = jedna výprava rodu. Zatím je hotový akt 1 (Hraběcí les): mapa o 7 patrech, na každém si vybereš jeden uzel, nahoře boss Hejtman Kuno. Později budou 3 akty. Podrobně v `docs/struktura-hry.md`.

**Uzly na mapě:**
- **Bitva:** po výhře odměna, jedna ze tří (2 pasivky a přísaha), nebo ji odmítneš za slávu.
- **Elita:** těžší bitva; vybíráš 2 ze 4 a jedna z nabídek je vždy nová schopnost.
- **Událost** (12 druhů): rozhodnutí s cenou, některé se týkají konkrétního hrdiny nebo dvojice.
- **Tábor:** jedna ze čtyř voleb: Odpočinek, Výcvik (pasivka), Obřad (přísaha), Hostina (sblíží dvojici).
- **Boss** na konci aktu.

Mapa hlídá, aby hráč měl vždy na výběr (nikdy tři klidné uzly za sebou, rozcestí nabízí různé typy).

**Bitva:** reálný čas s pauzou (mezerník). Hrdiny posíláš pravým tlačítkem na místo, na skupinu nepřátel nebo ke spojenci; bez rozkazu drží místo. Nepřátelé jsou ve skupinkách, které se probouzejí postupně, a velitelé ohlašují silné schopnosti, které jde omráčením přerušit. Typy bitev: útok, střet, obrana (vlny). Po zlomení morálky nepřítele jde jednou zavelet Do boje!. Hrdina, který padne, zůstane padlý. Když padnou všichni, běh končí.

## Rod a hrdinové

**Pět tříd:** tank, kněz, lučištník, jezdec, asasín. Každý hrdina má:
- **Schopnost** na klávese 1–5: jedna ze 3 schopností své třídy (15 celkem), vyměnit ji jde v běhu.
- **Zušlechtění:** 2 na každou schopnost, při výměně schopnosti propadnou.
- **Přísahu** (nejvýš jednu): 3 přísahy rodu a 3 osobní pro každou třídu. Dává sílu za omezení (zakázané cíle, žádný ústup, žádné rozkazy…). Rozkaz, který by ji porušil, se zeptá; porušení stojí slávu a přísaha zmizí.
- **Pasivky** a **vlastnosti** (Útok, Moc, Odolnost, Pohotovost; Síla = Útok i Moc).
- **Pouto** s jiným hrdinou. Roste ze společně vyhraných bitev (úroveň 1 až 3, 8 typů). Od úrovně 2 dává **kombo** na Q a E, kdy se obě schopnosti spojí (15 komb). Když jeden padne, druhý nese žal.

**Padlí a nástupci:** za padlého nastoupí nástupce bez pasivek; přísahu padlého může převzít jiný hrdina (osobní jen nástupce). **Sláva** je měna běhu (nejvýš 120): platí se jí za události, tábor a porušené přísahy.

**Stránka rodu** (tlačítko House na každé obrazovce běhu) ukazuje všechno pohromadě: schopnosti, zušlechtění, přísahy a jak sedí, vlastnosti, pouta a komba.

## Kde je hra teď

**Fáze 2: jeden celý běh.** Hotový je akt 1 s 8 bitvami (z toho 2 elity a boss), 12 událostmi a táborem, všechny systémy výše a 3D modely a animace všech pěti hrdinů. Nepřátelé, prostředí a vzhled obrazovek jsou zástupné; nový vzhled UI a ikon vzniká ve Figmě.

**Další kroky:** znamení rodu (relikvie běhu) a balanc běhu (2.3e), pak obsah podle playtestu, další rody (Medvěd, Sokol), ukládání a další akty. Plán je v `docs/plan.md`, aktuální stav v `docs/stav.md`, rozhodnutí v `docs/rozhodnuti.md`, anglické názvy v `docs/glosar.md`.

**Testovací build** pro hráče: větev `testovaci-buildy` na GitHubu.

## Jak spustit

1. Otevři Godot, v Project Manageru klikni na **Import** a vyber soubor `project.godot` z této složky.
2. Po načtení stiskni **F5** (nebo tlačítko ▶ vpravo nahoře). Hra začne úvodní obrazovkou: Nový běh, nebo Volná bitva (jednotlivé bitvy na zkoušku, s výběrem schopností a pasivek).

## Ovládání

| Akce | Ovládání |
| --- | --- |
| Rozestavit rytíře (jen obrana) | přetáhnout myší v modré zóně; puštění na jiného rytíře je prohodí |
| Výběr hrdiny | klik na hrdinu nebo jeho kartu (vybere jen jeho), **tažení obdélníku** levým tlačítkem přes víc hrdinů, **Ctrl+A** všichni; **Shift** přidá nebo ubere; klik na zem nebo **Esc** výběr zruší; druhý klik na kartu vybraného na něj posune výřez |
| Rozkaz (kdykoli, i v bitvě) | **pravé tlačítko** (provádí akce, kameru nehýbe): na zem = jdi tam (bez boje, tak hrdinu stáhneš z boje) a drž místo, na nepřítele = na celou jeho skupinu, na hrdinu = drž se ho |
| Zrušit rozkaz (drž místo) | **H** pro vybrané hrdiny |
| Co udělá pravé tlačítko | kruh pod kurzorem: červený = skupina nepřátel, modrý = ke spojenci, bílý = na místo |
| Cíl rozkazu | kruh v barvě hrdiny (v pauze u všech, v bitvě u vybraných) |
| Ohlášená schopnost velitele | červený kruh, který sílí; uhni, nebo velitele omrač |
| Schopnost hrdiny | tlačítko na kartě hrdiny nebo klávesa v rámečku na tlačítku (**1–5**); cílená schopnost pak **pravé** (nebo levé) tlačítko na bojiště (**Esc** zruší) |
| Kombo pouta | **Q** a **E** (panel „Bond combos“ vpravo od karet) |
| Do boje! (po zlomení morálky nepřítele, jednou) | tlačítko nebo **F** |
| Pauza (čas stojí, rozkazy a schopnosti jdou dál) | tlačítko nebo **mezerník**, pokračovat **mezerník** nebo **Enter**; v rozestavení obrany mezerník spustí bitvu |
| Výběr bitvy (volná bitva) | nahoře vlevo v úvodní pauze (obrana: v rozestavení) |
| Posun kamery | **WASD**, šipky, nebo myš u okraje obrazovky (jen v hranicích mapy) |
| Úhel kamery | pevný podle mapy, otáčet nejde |
| Přiblížení | kolečko myši (v malém rozsahu) |

## Struktura

Viz `CLAUDE.md`. Data hry jsou v `data/`, logika bitvy v `scripts/sim/`, běh v `scripts/run/`, scéna bitvy v `scripts/battle/`, modely v `art/`, testy v `tests/`.
