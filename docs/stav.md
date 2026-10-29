# Stav projektu

Aktualizováno: 28.10.2026

## Aktuální cíl
**Fáze 2: jeden celý run.** Hotová mapa aktu 1 (2.1): menu Nový běh → mapa Hraběcího lesa (7 pater, bitvy, elity, události, tábory, boss Hejtman Kuno). Další: 2.2 karta stage. Otevřené: playtest s hráčem mimo nás (1.8).

## Hotovo
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
- **Zahrát běh na mapě** (Nový běh): dávají volby cesty smysl? Je vidět, co tě v uzlu čeká? Jsou události zajímavé? Mapa a obrazovky jsou zástupné, UI převezmeš.
- Asasín v simulaci často padá (sám loví střelce za řekou). Chtěná cena, nebo upravit?
- Smazat na GitHubu větev `hrdinove-wip`.
- Projít nové UI a navrhnout vlastní podobu (rozvržení, ikonky). Kód UI je v `scripts/battle/battle_ui.gd` a `ui_icon.gd`.
- Vyzkoušet postoje podle třídy: dávají v automatické bitvě smysl?
- Zahrát Brod a les: výběr bitvy nahoře v panelu rozestavení, trasa tlačítkem Kreslit trasu u vybraného rytíře. Simulace: nejlíp vychází sevřená obrana uprostřed s knězem jako nositelem (bez ztrát); nepřátelé jdou k nám, takže trasy zatím nejsou nutné.
- Zahrát si bitvu a říct: baví to? co je nečitelné? 0, 1, nebo 2 signály?
- Vyzkoušet různé nositele praporu. Simulace: jezdec s praporem prohrává (vyběhne s praporem z oddílu), ostatní vyhrávají. Je to chtěná cena, nebo jezdcův prapor upravit?
- Asasín v Útočném postoji zemře sám za ~8 s (vyběhne na střelce za lapky). Výchozí postoj je proto Držet pozici.

## Další kroky
- 1.5: druhá mapa s více průchody, trasy rytířů, vlastnosti nepřátel.
- 1.6: postoje na míru třídám.
- 1.7: zkušební běh (3 bitvy, odměny, dědictví, návrat uprchlíků, kronika) → playtest → Brána 1.
