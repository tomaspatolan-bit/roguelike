# Deník rozhodnutí – rytířský roguelike

Nejnovější nahoře. Každé rozhodnutí: datum (formát DD.MM.RRRR), co, proč. Kopie je v projektu Roguelike v Claude (`claude/rozhodnuti.md`).

## 29.10.2026 – Bitva ve fázích, méně nepřátel, schopnosti bez slávy
- **Polovina nepřátel a v každé bitvě velitel:** běžná bitva 7–8 nepřátel, elita 9, boss 9, obrana 12 ve 3 vlnách po 4. Tom: moc nepřátel dělalo shluky na jednom místě a jednotky se do sebe prolínaly; méně, ale významnějších postav.
- **Bitva ve fázích:** nepřátelé stojí ve skupinkách (u mostu stráž, na břehu střelci, dál tábor) a skupinka se probudí, až se hrdinové přiblíží, až ji někdo zasáhne, nebo když se bojuje kousek od ní. Rozestavení před bitvou zůstává jen v obraně; ostatní bitvy začínají v pauze. Tom: „kdyby to bylo ve fázích, kdy přejdu most, najdu 2 strážce, přijdu do kempu, bude tam zbytek“.
- **Nejvýš 3 pěší útočí na jednoho hrdinu**, ostatní čekají stranou; těla se odtlačují. Proti shlukům a prolínání.
- **Schopnosti mají pevný počet použití za bitvu a nabíjení, slávou se nekupují:** Výzva 3× (15 s), Salva 3× (12 s), Úder ze stínu 2× (15 s), Nájezd 1× (omráčí, nadělá paseku), Požehnání 1×. Tom: hrdinové mají v bitvě ve fázích převahu, takže omezené schopnosti dávají rozhodnutím váhu a nejde se po každé skupince znovu doléčit.
- **Kněz léčí sám jen v boji** (bdělý nepřítel do 10 m), ne mezi skupinkami.
- **Sláva zůstává pro kroniku, události a porušení přísahy**, v bitvě už není měnou. Přísaha Slib chudoby (dřív za slávu) je teď Slib odříkání: +1 použití schopnosti, ale kněz hrdinu neléčí (pilíř Přísaha má cenu).
- **Velitelé** (Pálič Vok, Ostrostřelec Jíra, Setník Bořivoj, Hejtman Kuno) mají schopnost, kterou ohlásí textem a červeným kruhem; hráč má čas uhnout, nebo ji přerušit omráčením (Nájezd). Dává smysl reagovat v reálném čase.
- Obtížnost scénáře se ladí násobky `foe_hp` a `foe_dmg` (méně nepřátel, ale silnějších).

## 29.10.2026 – Bitva v reálném čase s pauzou
- **Rozkazy jdou dávat kdykoli**, i během bitvy: výběr hrdinů (klik, Shift) a pravé tlačítko na místo, nepřítele nebo spojence. Tom: hráč musí reagovat na to, co dělá nepřítel; má jen jeden pokus a prohra kvůli tomu, že nepřítel udělal něco jiného, než čekal, by ho naštvala.
- **Pauza na mezerníku** kdykoli (čas stojí, rozkazy a schopnosti jdou dál). Bez pauzy by rozhodovala rychlost klikání, ne úsudek. Zpomalení času nezavádíme.
- **Signál jako omezený zdroj zrušen** (nahrazuje rozhodnutí o signálu z dnešního dne níž).
- Další krok: nepřítel musí být čitelný a zajímavý (viditelné úmysly, vůdce, který mění plán), aby reagování mělo smysl; balanc pro hráče s plnou kontrolou podle playtestu.

## 29.10.2026 – Rozkazy místo tras a výchozího chování
- **Hrdina jedná podle rozkazu hráče:** na místo (dojde a drží ho), na skupinu nepřátel (jde po celé skupině, i když se hýbe) nebo ke spojenci (zůstane s ním). Bez rozkazu a po splnění rozkazu drží místo a brání se tomu, kdo přijde. Před bitvou hra varuje, kdo rozkaz nemá. Tom: „řídil bych se hlavně tím, kam uživatel vyšle svoje hrdiny; předejdeme tím bugům, kdy jednotky nebudou nic dělat“.
- **Zrušeno:** trasy, výchozí chování tříd (Drží frontu, Léčí frontu…), postup oddílu v útoku a obranný obvod. Typ bitvy mění jen nepřítele (útok: drží pozice, střet: jde proti vám, obrana: vlny).
- **Signál zůstává a dostal úkol:** zastaví čas a jen při něm jde rozkazy během bitvy měnit. V tutoriálu se to vysvětlí. Tím padá otázka z 29.10., jestli signál vymazat.
- Zůstává: schopnosti, Do boje!, léčení kněze, přísahy (Nikdy neustoupí: rozkaz k ústupu při signálu přísahu poruší; Přísaha pomsty: dokud žije viník, jde po něm a rozkaz neposlechne).

## 29.10.2026 – Oprava obrany
- V obraně hrdinové pomáhají každému z oddílu, s kým nepřítel bojuje (i kousek za hranicí obrany), a nepřítele, který se drží stranou, jdou po chvíli dorazit. Mezi vlnami stojí na místech a lišta ukazuje odpočet další vlny. Tom: hrdinové se v obraně nehýbali a v jednu chvíli se zastavili úplně.

## 29.10.2026 – Ragdoll a postoj rytíře
- **Padlí padají jako ragdoll** (fyzika): hrdinové s fyzikálními kostmi, nepřátelé jako tuhé tělo. Těla zůstávají ležet na bojišti. Tom chtěl, aby smrt vypadala opravdově (pilíř Smrt má váhu).
- **Rytíř drží paže u těla** ve všech animacích; stál v A-póze kostry jako „Y“.

## 29.10.2026 – Obrana a animace boje
- **Obrana:** nepřítel přichází ve vlnách, oddíl brání společné místo (do 7 m od něj), nikdo nevybíhá sám. Morálka nepřítele se nezlomí, dokud přicházejí vlny. První obranná mapa: Obrana Lesní vsi (3 vlny).
- **Animace boje hrdinů** podle třídy: tank a jezdec seknutí mečem, kněz palcátem, asasín bodnutí dýkou, lučištník výstřel z luku; schopnost (Výzva, Požehnání = zvednuté paže), zásah, smrt (hrdina padne a leží). Zbraně v ruce jsou zatím zástupné.
- Po bitvě se hrdina doléčí o 30 % (bylo 20 %) a tábory jsou na mapě častější; auto-hraní běhu s Lesní vsí bez toho vyhrávalo jen 1 z 20.

## 29.10.2026 – Typ bitvy řídí chování oddílu
- **Výchozí chování se řídí typem bitvy:** útok (nepřítel drží pozice, oddíl postupuje k cíli a k nepříteli), střet (oba jdou proti sobě, oddíl čeká), obrana (držíte místo; zatím jako střet, první obranná mapa přijde). Důvod: chování „reaguj na toho, kdo přijde“ proti nepříteli na pozici vedlo k patu.
- **Pak instrukce pro hrdiny** (úkoly), společné pro všechny typy bitev, případně zvlášť pro typ. Až po typech bitev.
- **Požehnání je mířené** (kruh 4 m do 10 m od kněze), léčení kněze dosáhne na 9 m.
- **Signál** zůstává do playtestu s hráčem mimo nás; když ho nepoužije, vymažeme ho (Tom ho nepoužil ani jednou).
- Pasivky a přísahy dostanou synergii (podle třídy, mezi hrdiny, s úkolem); kněz „Nikdy neustoupí“ nepotřebuje.

## 29.10.2026 – Mapa aktu (2.1)
- **Zranění se nesou mezi bitvami** (po bitvě +20 % zdraví samo, tábor vyléčí vše). Mění pravidlo zkušebního běhu, že se zranění vyléčí; jinak by tábor neměl smysl.
- **Kovář odložen**, dokud nebude výbava.
- **Běh končí, až padnou všichni** v jedné bitvě (ústup řešíme v 2.6).
- Elita: odměna 2 ze 4 nabídek. Události: rozhodnutí s cenou (sláva, zranění, přísaha, uprchlíci, kteří se vrátí u bosse). Tábor jen odpočinek.
- Hrdinové po zlomení morálky dobojují sami, když hráč 25 s nedá Do boje! (pojistka proti patu).

## 29.10.2026 – Struktura hry
- **Běh → 3 akty → 7 pater → uzly.** Akt = jedna mapa s bossem nahoře; na každém patře hráč navštíví jeden uzel (bitva, elita, událost, tábor, boss). Po bossovi následuje další akt, po bossovi 3. aktu je běh vyhraný.
- **Zánik oddílu ukončí celý běh**, další začíná od aktu 1 (žádné opakování aktu). Padlý hrdina běh neukončí (nástupce). Mezi běhy jen meta progrese do šířky (síň předků, odemčené rody), ne do síly.
- Lore je kulisa, ne jednotka postupu. Diagram: `docs/struktura-hry.md`.

## 29.10.2026 – Brána 1: pokračujeme
- **Model hry potvrzen, stavíme fázi 2.** Tom: o každé odměně vážně uvažoval, běh působí skvěle.
- Playtest s hráčem mimo nás (krok 1.8) zůstává otevřený a doplní se během fáze 2; jeho výsledek může model ještě korigovat.
- Větev `prapor-asasin` (bitva na hrdiny + zkušební běh) sloučena do `main`.

## 29.10.2026 – Po playtestu zkušebního běhu
- **Schopnost navíc za slávu jen jednou za bitvu na hrdinu** (`glory.extra_uses_max`). Důvod: neomezená použití za slávu dělala z Požehnání nekonečné léčení.
- **Nabíjení schopnosti** (`cooldown` v datech schopnosti): Požehnání 20 s, ostatní zatím bez nabíjení.
- **Do další bitvy běhu si rod nese nejvýš 50 slávy** (`glory.carry_max`).
- **Kněz pomáhá v boji**, když nikdo v jeho dosahu nepotřebuje léčit (léčí dál, couvne pod polovinou zdraví). Oddíl nechodí za asasínem, který se toulá sám.

## 28.10.2026 – Zkušební běh
- **Nástupce nastoupí za každého padlého** (stejná třída, nové jméno, bez pasivek). Smrt tedy stojí získané pasivky a příběh hrdiny, ne místo v sestavě. Běh končí, až padnou všichni v jedné bitvě.
- **Přísaha padlého** přechází na hrdinu bez přísahy podle volby hráče, nebo zanikne. Porušená přísaha po bitvě zmizí.
- **Vůdce nepřátel:** když padne, morálka jeho oddílu se zlomí. Závěrečná bitva má úkol „Hejtman Kuno padne“.
- **Uprchlíci se vrátí** v závěrečné bitvě (u vůdce).
- Hra startuje do menu (Zkušební běh / Volná bitva).

## 28.10.2026 – Pasivky a přísahy
- **15 pasivek** (2–3 na třídu + Veterán a Mstitel pro kohokoli) a **3 přísahy** (Nikdy neustoupí, Přísaha pomsty, Slib chudoby). Pasivky jsou čitelné efekty a obohacují mířené schopnosti (Ohnivá salva, Drtivý nájezd, Druhý nájezd), pohyb hrdiny nemění.
- **Získávají se po bitvě volbou 1 ze 3** (pasivka nebo přísaha pro konkrétního hrdinu). Hrdina má nejvýš 1 přísahu.
- Do zkušebního běhu jdou všechny. Do té doby je jde zapnout na zkoušku v rozestavení.
- Playtest bitvy na hrdiny: Tomovi se líbí mířené schopnosti (Salva, Nájezd s omráčením). Další schopnosti a pasivky mají stavět na mířeném rozhodnutí.

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
