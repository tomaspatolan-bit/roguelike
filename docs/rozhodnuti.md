# Deník rozhodnutí – rytířský roguelike

Nejnovější nahoře. Každé rozhodnutí: datum (formát DD.MM.RRRR), co, proč. Kopie je v projektu Roguelike v Claude (`claude/rozhodnuti.md`).

## 28.10.2026 – Rody a hrdinové před pasivkami
- **Nejdřív rody a hrdinové, pak pasivky a jejich bonusy.**
- **Hrdina je konkrétní postava** (jméno, třída, povaha), ne jen třída. Když padne, nastoupí nástupce a může zdědit jeho přísahu.
- **Na zkušební běh jeden rod (Vlk).** Druhý (Medvěd) až bude běh fungovat. Náčrt rodů: Vlk 5 vyvážených, Medvěd 4 odolnější s berserkrem, Sokol 6 lehčích se sokolníkem.
- Návrh Rodu Vlka a jeho hrdinů je v dokumentu „Rod Vlka a jeho hrdinové“ (ke schválení).

## 28.10.2026 – Změna směru: hrdinové a jejich schopnosti místo praporu
- **Nové pilíře:** (1) Velíš rodu: rod určuje, s kým a jak bojuješ, v bitvě ovládáš jeho hrdiny. (2) Přísaha má cenu. (3) Smrt má váhu: padlí zůstávají padlí a odkazují nástupcům. (4) Každý run je příběh rodu. Pilíř „Prapor je srdce oddílu“ je zrušený.
- **Z bitvy mizí** aura praporu, nositel praporu, pokřiky a postoje. Důvod (Tom, po playtestu): prapor byl jediné, co drželo jednotky naživu, hráč ztrácel kontrolu a bitva byla nepředvídatelná; simulace to potvrzovala (výsledky 0/40 nebo 40/40, smrt nositele rozhodovala).
- **Žádné bonusy pro celý oddíl v bitvě.** Hráč se v bitvě soustředí jen na hrdiny.
- **Hrdina:** pevné výchozí chování podle třídy, jedna aktivní schopnost na kartě s počtem použití za bitvu (obnova po bitvě). Později až 3 sloty na schopnosti, odemykají se během běhu.
- **Pasivky** dostávají hrdinové jako odměny na mapě běhu. **Přísahy** jsou zvláštní druh pasivky: silnější, ale s omezením. Pasivky mají být čitelné efekty, pohyb hrdiny mění jen výjimečně.
- **Sláva** zůstává jako společná rezerva rodu: plní se činy hrdinů, utratí se za použití schopnosti navíc u kteréhokoli hrdiny. Zaznamenává se, kdo slávu přinesl (kronika).
- **Rod** zůstává jako sestava: jiní hrdinové, jejich velikost, velikost skupiny. Bonusy rodu jsou zapečené přímo v hodnotách hrdinů, ne jako zvláštní bonus v bitvě.
- **Zůstává:** signály, povel Do boje!, morálka nepřátel, trasy, nepřátelé na pozicích.
- **Odloženo na zkušební běh (1.7):** obnova silných schopností až v táboře, přenos slávy mezi bitvami, prapor jako symbol nebo příběh.

## 28.10.2026 – Postoje podle třídy, nepřátelé na pozicích, nové UI
- **Postoje podle třídy** (data u třídy): tank Stát pevně / Krýt prapor / Prorazit, kněz Léčit frontu / U praporu, lučištník Ostřelovat / U praporu, jezdec Výpad / Záloha, asasín Lovit střelce / Číhat. Důvod: obecné postoje v automatické bitvě nedávaly smysl (Tom).
- **Nepřátelé na Brodu drží pozice** 30 s: lapkové a kopiníci brody, střelci břeh a střílí přes řeku. Zasažený pěšák vyrazí i se skupinou. Důvod: aby se vyplatilo jít na nepřítele a rozdělit oddíl.
- **Nové UI (zástupné, Tom převezme):** lišta velení nahoře, karty rytířů dole, malý deník vpravo nahoře, ikonky stavu nad hlavami a na kartách. Ikonky kreslené vektorově v kódu.

## 28.10.2026 – Druhá mapa Brod a les
- **Mapa A „Brod a les“:** dva brody po stranách (zpomalí), úzká lávka uprostřed, za ní les se stezkou, nepřátelé ze dvou stran. Důvod: ověřit jednotky a jejich chování mimo most, rozdělení oddílu a trasy.
- **Trasy:** kreslení čarou zjednodušenou na nejvýš 4 body, jen v rozestavení. Na trase rytíř bojuje jen s tím, kdo mu vstoupí do cesty. Rytíř s přísahou Nikdy neustoupí nemá trasu zpět.
- **Nový nepřítel kopiník** (2× poškození proti jízdě, Fanatik). **Vlastnosti nepřátel** v datech: Zoufalec, Fanatik, Zbabělec.
- **Asasína les nezpomaluje.** Jezdec je jízda (kopí proti němu).
- **Zjištění:** na Brodu zatím nejlíp vychází sevřená obrana uprostřed s knězem jako nositelem; nepřátelé jdou k nám, takže trasy nejsou nutné. Další krok: nepřátelé drží pozice.

## 28.10.2026 – Zkušební běh před Bránou 1
- **Před Bránou 1 postavíme zkušební běh:** 3 bitvy (Most → druhá mapa → závěrečná bitva s vůdcem), mezi nimi odměna 1 ze 3, padlí zůstanou mrtví, dědictví přísahy, uprchlíci se vrátí v závěrečné bitvě, kronika rodu na konci. Důvod: háček hry je vidět až mezi bitvami, jedna bitva neodpoví, jestli hra jako celek dává smysl.
- **Pořadí:** druhá mapa s trasami a vlastnostmi nepřátel → postoje na míru třídám → zkušební běh → playtest (Tom + hráč mimo nás) → Brána 1.
- **Podmíněné instrukce až podle playtestu**, jen když postoje na míru nestačí.
- Mimo zkušební běh: výběr rodu, meta progrese, ukládání, finální grafika.

## 28.10.2026 – Morálka a dobojování
- **Morálka nepřátel:** po ztrátě 70 % se nepřítel zlomí. Reakce podle typu jednotky: pěšáci zoufale dobojují (silnější útok), střelci utečou z bojiště. Důvod: bitva nekončí naháněním posledních nepřátel a dává smysl (bitvy se rozhodovaly útěkem).
- **Povel Do boje!:** jednorázový, objeví se po zlomení morálky, všichni rytíři opustí postoje a dobojují (i tank se Stát pevně, útok vpřed není ústup).
- **Pojistka dobojování:** když je síla jedné strany pod 15 % druhé a morálka se nezlomila, rytíři dobojují sami a hra se zrychlí na 2×.
- **Ústup s praporem** a otázka, jestli prohraná bitva končí run, se řeší ve fázi 2 (stavba runu). Platí zatím: prohra = ztráty, ne konec runu.

## 28.10.2026 – Nikdo nestojí bez práce, postoje na míru třídám
- **Rytíř v Držet pozici bez cíle jde pomoct nejbližšímu bojujícímu spolubojovníkovi.** Důvod: na konci bitvy stáli rytíři daleko od sebe a nic nedělali. Tank s přísahou Nikdy neustoupí stojí dál (otevřená otázka pro Toma).
- **Směr: postoje na míru třídám** (2 na třídu, třetí jako odměna v runu), např. jezdec Výpad/Záloha, asasín Lovit střelce/Číhat. Až po druhé mapě.
- **Pořadí:** oprava nečinnosti → druhá mapa s trasami → doplnit zážitek → Brána 1 (dává hra smysl?).

## 28.10.2026 – Prapor, jádro tříd a opakování bitev
- **Bitvy se neopakují.** Žádné opakování po prohře, žádné vracení času, žádné cvičiště. Prohra v runu znamená ztráty (padlí rytíři, propadlá odměna, ústup), ne nutně konec runu; přesná pravidla ve fázi 2. Tlačítka „Znovu stejně“ a „Nové rozestavení“ zůstávají jen v prototypu pro playtesty.
- **Hloubka rozhodnutí přes informace o nepříteli:** hráč před bitvou uvidí, kudy nepřátelé půjdou a jaké mají podmínky (stejný slovník jako instrukce hráče). Pojistky proti „hádance s jedním řešením“: trochu náhody v boji, podmínky nepřátel jako odhalovaná informace (průzkum, fáze 2).
- **Prapor nese kterákoli třída, volí se v rozestavení a během bitvy se nepředává.** Padlý prapor dál někdo zvedne (přednostně postoj Chránit prapor, který to má v popisu).
- **Efekt praporu určuje třída nositele:** tank −15 % zranění v auře, kněz léčí v auře, lučištník aura 7 m, jezdec +25 % rychlost v auře, asasín aura 4 m a +30 % útok. Postih za nošení není; cenou je, že rytíř dělá svou práci jinak.
- **Nositel nemá postoj Chránit prapor.**
- **Praporečník jako třída zaniká, místo něj asasín** (rychlý, křehký, přednostně jde po střelcích).
- **Jádro tříd je pevné: tank, kněz, lučištník, jezdec, asasín.** Mění se jen po úvaze a zápisu sem.
- **Do budoucna:** každý hrdina si najímá vlastní jednotky; prapor nese vždy hrdina, nikdy najatý voják (nápad, fáze 2+).
- Plán dalších kroků: trasy s druhou mapou (1.5), pak podmíněné instrukce a viditelné úmysly nepřátel (1.7).

## 28.10.2026 – Po prvním playtestu
- **Přísaha určuje povolené postoje** (data `forbidden_postures`, `posture_names`). Důvod: postoj „Držet pozici“ vracel rytíře na místo, což byl skrytý ústup a porušení přísahy, o kterém hra nevěděla.
- **„Nikdy neustoupí“ = varianta A:** rytíř smí Útočný a „Stát pevně“ (bojuje s tím, co přijde, nikam se nevrací), Chránit prapor má zakázaný. Porušit přísahu jde jen vědomým rozkazem při signálu. Varianta B („Jen vpřed“) je v `napady.md` jako budoucí přísaha.
- **Ovládání:** drag & drop rytířů s výběrem podle postavy na obrazovce; kamera WASD/šipky a pravé tlačítko; signál na mezerník (klávesa S patří kameře).
- **Netestovaný kód se nepushuje**, na Tomův počítač jde jako patch.

## 28.10.2026 – Prototyp v Godotu
- **Godot 4.7.2** (verze na Tomově počítači). Repozitář `tomaspatolan-bit/roguelike`, práce na větvích.
- **Testy běží na Tomově počítači přes Blender MCP**, protože v cloudu Godot stáhnout nejde. Postup v `CLAUDE.md`.
- **Obsah jako JSON** v `data/` (jednotky, rod Vlka, scénář). Simulace bitvy oddělená od scény, aby šla testovat bez okna.
- **Barva role přes řádek palety** (shader `knight_palette.gdshader`): jeden model rytíře pro všechny role.

## 28.10.2026 – Tým a engine
- **Tým:** Tom + Claude. Tom = ředitel, designér, tester, art direction, business. Claude = kód, data a obsah, simulace balancu, technická práce v Blenderu, dokumentace a plánování.
- **Engine: Godot 4** (místo Unrealu). Důvod: scény i skripty jsou čitelný text, takže Claude může projekt přímo upravovat, testovat a hlídat. Model rytíře jde do Godotu přes `SK_Knight.glb`.
- **Pracovní paměť:** `CLAUDE.md`, `docs/stav.md` (aktuální sprint) a tento deník. Bez zápisu rozhodnutí neexistuje.

## 26.10.2026 – Grafika a pipeline
- Stylizovaný low-poly rytíř z tuhých dílů, paletová textura s řádky pro role, kostra s 27 kostmi. Herní síť ~5 400 trojúhelníků, LOD1 ~2 200.
- Steam: obsah vytvořený AI (grafika, texty, zvuk) se musí uvést na stránce hry; AI nástroje pro kód a vývoj se neuvádějí.

## 25.10.2026 – Koncept a bitva
- Háček: rod → prapor → přísahy rytířů, padlí odkazují přísahy a výbavu nástupcům.
- Bitva: hybrid. Příprava (rozestavení, postoje) + bitva běží sama + pokřiky praporu za slávu (bez zastavení času) + 1–2 signály praporu (zastavení času). Pravidla „když–pak“ jen pokud prototyp ukáže potřebu.
- Pilíře: velíš rodu, ne vojákovi · prapor je srdce oddílu · přísaha má cenu · každý run je příběh rodu.
- Webové demo „Most přes řeku“: bez pokřiků se prohrává, s nimi vyhrává. Zjištění: útočný postoj vede ke ztrátám mimo auru praporu; střelci + kněz můžou vytvořit pat.
