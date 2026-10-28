# Stav projektu

Aktualizováno: 28.10.2026

## Aktuální cíl
Fáze 1, krok 1.2 (viz `docs/plan.md`). První hratelný build v Godotu: jedna bitva (Most přes řeku) a otázka, jestli nás baví ji hrát opakovaně.

## Hotovo
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
- Zahrát Brod a les: výběr bitvy nahoře v panelu rozestavení, trasa tlačítkem Kreslit trasu u vybraného rytíře. Simulace: nejlíp vychází sevřená obrana uprostřed s knězem jako nositelem (bez ztrát); nepřátelé jdou k nám, takže trasy zatím nejsou nutné.
- Zahrát si bitvu a říct: baví to? co je nečitelné? 0, 1, nebo 2 signály?
- Vyzkoušet různé nositele praporu. Simulace: jezdec s praporem prohrává (vyběhne s praporem z oddílu), ostatní vyhrávají. Je to chtěná cena, nebo jezdcův prapor upravit?
- Asasín v Útočném postoji zemře sám za ~8 s (vyběhne na střelce za lapky). Výchozí postoj je proto Držet pozici.

## Další kroky
- 1.5: druhá mapa s více průchody, trasy rytířů, vlastnosti nepřátel.
- 1.6: postoje na míru třídám.
- 1.7: zkušební běh (3 bitvy, odměny, dědictví, návrat uprchlíků, kronika) → playtest → Brána 1.
