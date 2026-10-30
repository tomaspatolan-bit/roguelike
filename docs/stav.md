# Stav projektu

Aktualizováno: 30.10.2026

## Aktuální cíl
**Fáze 2: jeden celý run.** Hotová mapa aktu 1 (2.1): menu Nový běh → mapa Hraběcího lesa (7 pater, bitvy, elity, události, tábory, boss Hejtman Kuno). Hotové všechny tři typy bitev (útok, střet, obrana s Lesní vsí) a animace boje hrdinů. Hotové rozkazy pro hrdiny (2.2c). Další: karta stage a volitelné úkoly (2.2). Otevřené: playtest s hráčem mimo nás (1.8).

## Hotovo
- Výcvik ve hře: v první bitvě karta přišpendlená šipkou k cíli provede hráče sedmi kroky (výběr, rozkaz, pauza, útok, schopnost, H, velitelé); u nepřátel, boje a velitele se bitva sama zastaví a kamera se tam posune; krok skončí akcí hráče, jde přeskočit, po dokončení se neukáže (úvodní obrazovka: „Výcvik znovu“). Mezerník v rozestavení obrany spustí bitvu.
- Karta hrdiny bez textu rozkazu, Poslat a ✕; tlačítko schopnosti ukazuje klávesu (1–5). Klávesa H: vybraní hrdinové zruší rozkaz a drží místo.
- Pravé tlačítko vždy provede akci: rozkaz, cílenou schopnost (po tlačítku nebo klávese 1–5) i rozkaz z tlačítka Poslat; levé vybírá.
- Kamera s pevným úhlem podle mapy: výřez se posouvá WASD, šipkami nebo myší u okraje obrazovky jen v hranicích mapy, kolečko trochu přiblíží, otáčet nejde, pravé tlačítko je jen na rozkazy. Obrana Lesní vsi má výřez úplně pevný. Rozhodnuto, jak budeme dělat mapy: kit assetů (Claude) a vzhled map v editoru (Tom).
- Po hraní bitvy ve fázích: každá schopnost 3× za bitvu (bylo moc těžké); ovládání podle zvyklostí RTS: klik na hrdinu vybere jen jeho, v bitvě se hrdinové netahají, Ctrl+A vybere všechny, druhý klik na kartu natočí kameru, kruh pod kurzorem ukazuje, co udělá pravé tlačítko (červený skupina, modrý spojenec, bílý místo). Balanc s automatickým velitelem: se schopnostmi 38–40/40 všude, bez schopností 0/40; běh 13/20.
- Bitva ve fázích (po Tomově hraní: moc nepřátel, shluky): polovina nepřátel (bitva 7–8, elita a boss 9, obrana 12 ve 3 vlnách), skupinky se probouzejí postupně (přiblížení, zásah, boj kousek od nich), v každé bitvě velitel s ohlášenou schopností (Pálič Vok: hořící kruh, Ostrostřelec Jíra: mířená rána, Setník Bořivoj: povel, Hejtman Kuno: rozmach), kterou přeruší omráčení. Na hrdinu útočí nejvýš 3 pěší, ostatní čekají stranou. Schopnosti mají pevný počet a nabíjení (Výzva 3×, Salva 3×, Úder 2×, Nájezd 1×, Požehnání 1×), sláva je už jen pro kroniku a události. Kněz léčí jen v boji. Bitva začíná v pauze, rozestavení jen v obraně. Balanc: bez schopností všude 0/40, se schopnostmi 40/40 (Garda 29/40, Lesní ves 31/40); běh 6/20 vítězných.
- Po hraní v reálném čase: hrdinové mají barvy (rámeček a jméno na kartě, rámeček zdraví nad hlavou, kroužek výběru, kruh cíle rozkazu); místo čar rozkazů kruhy tam, kam jsi ukázal; jednotky obcházejí spojence v cestě; asasín po Úderu ze stínu (a jezdec po Nájezdu) chvíli bojuje s cílem, než se vrátí k rozkazu.
- Reálný čas s pauzou místo signálu: hrdinu vybereš klikem nebo víc hrdinů tažením obdélníku (Shift přidá další), pravým tlačítkem ho pošleš na místo, na nepřítele nebo ke spojenci, kdykoli i v bitvě. Mezerník bitvu pozastaví, v pauze jdou dávat rozkazy i schopnosti. Přetažení hrdiny v bitvě = rozkaz na místo. Rozkaz na místo stáhne hrdinu z boje (cestou nebojuje), rozkaz na skupinu bojuje jen s ní.
- Rozkazy místo tras a výchozího chování (2.2c): v rozestavení každého hrdinu pošleš tlačítkem Poslat na kartě a klikem na místo, na nepřítele (jde po celé jeho skupině) nebo na spojence (zůstane s ním). Bez rozkazu a po splnění drží místo a brání se. Před bitvou hra varuje, kdo rozkaz nemá. Čáry rozkazů k cíli. Opraven Nájezd, který uvízl, když cíl zabíral nepřítel. Balanc všech 8 scénářů prošel s automatickým velitelem (Most +2 střelci, Most pod palbou a boss +3 lapkové, Lesní ves −1 lapka).
- Ragdoll padlých: hrdina při smrti padne s fyzikálními kostmi dozadu od nepřítele, nepřátelé se jako tuhé tělo překotí. Rytíři už nestojí jako „Y“ (paže u těla v klidu i v chůzi).
- Obrana Lesní vsi: tři vlny lapků (0 s, 22 s, 45 s), oddíl brání ves a nevybíhá, kněz léčí mezi vlnami, chalupy na bojišti. Animace boje: každá třída má vlastní útok (meč, palcát, dýka, luk), schopnost, zásah a smrt; zástupné zbraně v ruce. Oprava zaseknutí jednotek u břehu.
- Typ bitvy: v útoku (Brod, elity, boss) oddíl postupuje k cíli a k nepříteli místo čekání, ve střetu (Most) čeká. Typ je vidět na mapě i v bitvě. Požehnání se míří kruhem, kněz léčí do 9 m. Poplach mezi nepřáteli na pozici (`alarm_radius`). Balanc všech 7 scénářů prošel.
- Mapa aktu 1 (2.1): generovaná mapa 7 pater po 2–3 uzlech, bitvy (4 varianty map), elity (2, odměna 2 ze 4), události (Poutník, Vypálená ves, Zajatý lapka, Lesní kaple), tábor (odpočinek), boss. Zranění se nesou (+20 % po bitvě), sláva do další bitvy nejvýš 50. Pojistka: hrdinové po 25 s od zlomení dobojují sami. Struktura hry v `docs/struktura-hry.md`.
- Po playtestu běhu: hrdinové bez trasy nekmitají (klidová místa s tolerancí, lučištník couvá s odstupem), kněz nestojí (jde k bojujícímu i přes přechod, když nikdo nepotřebuje léčit, pomáhá v boji), oddíl nechodí za asasínem přes řeku. Schopnost navíc za slávu jen 1× za bitvu, Požehnání se nabíjí 20 s, do další bitvy nejvýš 50 slávy.
- Zkušební běh (1.7): Most přes řeku → Brod a les → Tábor na Vraní skále (vůdce Hejtman Kuno, smrt vůdce zlomí morálku). Po bitvě odměna 1 ze 3 (pasivka nebo přísaha pro konkrétního hrdinu), padlí zůstanou padlí a nastoupí nástupce bez pasivek, přísahu padlého může převzít hrdina bez přísahy, porušená přísaha zmizí, sláva se přenáší, uprchlíci z bitev 1–2 se vrátí v závěrečné bitvě, prohra = padli všichni, kronika rodu. Opraveny dva paty (lučištník couval donekonečna, kněz, který zbyl sám, utíkal). Testy: 20 auto-běhů 17 vítězných; Tábor 0/40 bez schopností, 40/40 se schopnostmi.
- Test pasivek ve hře (`passives_ingame.gd`): všech 18 pasivek a přísah se ve hře projevuje (sady A a B prošly). Oprava: oheň z Ohnivé salvy dával slávu za zásah v každém snímku.
- Pasivky a přísahy: 15 pasivek a 3 přísahy v datech i simulaci, v rozestavení jdou zapnout na zkoušku (menu Pasivky na kartě). Testy prošly.
- Přestavba bitvy na hrdiny: výchozí chování tříd (Drží frontu, Léčí frontu, Střílí zezadu, Výpady, Loví střelce), schopnost na kartě (Výzva, Požehnání, Salva, Nájezd, Úder ze stínu) s použitími za bitvu, sláva platí použití navíc (40), cílení kruhem a klikem, klávesy 1–5. Most +2 lapkové. Testy obou map prošly.
- Postoje podle třídy (tank Stát pevně/Krýt prapor/Prorazit, kněz Léčit frontu/U praporu, lučištník Ostřelovat/U praporu, jezdec Výpad/Záloha, asasín Lovit střelce/Číhat). Na Brodu nepřátelé drží pozice. Nové UI: lišta velení nahoře, karty rytířů dole, ikonky stavu nad hlavami. Testy prošly.
- Druhá mapa Brod a les (brody zpomalí, lávka, les se stezkou, asasína les nezpomalí), výběr bitvy v rozestavení, kreslení tras, kopiníci (2× proti jízdě, Fanatik), vlastnosti nepřátel. Testy obou map prošly.
- Morálka nepřátel (po 70 % ztrát střelci prchají, pěšáci zoufale dobojují), jednorázový povel Do boje! (F), pojistka dobojování. Bitva s pokřiky trvá ~37 s. Testy prošly.
- Nikdo nestojí bez práce: rytíř v Držet pozici bez cíle jde pomoct nejbližšímu bojujícímu (kromě tanka se Stát pevně). Testy prošly.
- Prapor: nositele volí hráč v rozestavení (tlačítko Prapor), během bitvy se nepředává, efekt podle třídy nositele, nositel nemá Chránit prapor. Asasín nahradil praporečníka (jádro 5 tříd). Lapkové mají útok 7 místo 6 (balanc). Testy prošly.
- Po prvním playtestu: přísaha určuje postoje (Stát pevně), drag & drop rytířů, kamera WASD a pravé tlačítko, signál na mezerníku. Testy prošly.
- Hygiena projektu: kontextové soubory pro každou oblast (`docs/context/`), plán vývoje (`docs/plan.md`), deník playtestů, parkoviště nápadů, povinný postup u změn v `CLAUDE.md`.
- Projekt Godot 4.7, data v JSON, simulace bitvy přenesená z webového dema.
- Scéna bitvy: bojiště, rytíř z Blenderu s barvou role a animacemi klidu a chůze, rozestavení, postoje, pokřiky, sláva, signály praporu, přísaha tanka, padlý prapor, výsledek bitvy.
- Testy: `test_battle_sim.gd` (balanc a pravidla), `screenshot_battle.gd` (scéna).

## Známá omezení prototypu
- Jezdec nemá koně (je jen větší a rychlejší rytíř).
- Útoky, zásahy a smrt nemají animace (výpad, záblesk, pád).
- Nepřátelé jsou kostičkoví panáci.
- Žádný zvuk.

## Čeká na Toma
- **Vyzkoušet kameru** na každé mapě: je vidět, co potřebuješ? Nejsou hrdinové pod kartami? Sedí úhel (dá se změnit v datech scénáře)?
- **Poslat testerovi** build `Rytiri_test_2026-10-30.zip` (větev `testovaci-buildy` na GitHubu, nebo ve složce Blender\Roguelike). Repo je soukromé: testera přidej jako collaboratora s právem čtení (Settings → Collaborators), nebo mu ZIP pošli. Jeho dojmy zapiš do `playtesty.md` (krok 1.8).
- **Vyzkoušet bitvu ve fázích** (Most, Brod, Lesní ves, boss): nejsou shluky a prolínání? Čtou se probuzení skupinek a ohlášené schopnosti velitelů (stihneš uhnout)? Nejsou schopnosti moc skoupé, nebo bitvy moc lehké s plnou kontrolou? Nový exe pro testera na požádání.
- **Zahrát běh na mapě** (Nový běh): dávají volby cesty smysl? Je vidět, co tě v uzlu čeká? Jsou události zajímavé? Mapa a obrazovky jsou zástupné, UI převezmeš.
- Podívat se na animace (snímky `sheet_*.png`, nebo rovnou ve hře) a na obranu vsi: čtou se? Jsou zbraně v ruce v pořádku jako zástupné?
- Smazat na GitHubu větev `hrdinove-wip`.
- Projít nové UI a navrhnout vlastní podobu (rozvržení, ikonky). Kód UI je v `scripts/battle/battle_ui.gd` a `ui_icon.gd`.

## Další kroky
- 1.5: druhá mapa s více průchody, trasy rytířů, vlastnosti nepřátel.
- 1.6: postoje na míru třídám.
- 1.7: zkušební běh (3 bitvy, odměny, dědictví, návrat uprchlíků, kronika) → playtest → Brána 1.
