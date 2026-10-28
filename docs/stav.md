# Stav projektu

Aktualizováno: 2026-10-28

## Aktuální cíl
Fáze 1, krok 1.2 (viz `docs/plan.md`). První hratelný build v Godotu: jedna bitva (Most přes řeku) a otázka, jestli nás baví ji hrát opakovaně.

## Hotovo
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
- Zahrát si bitvu a říct: baví to? co je nečitelné? 0, 1, nebo 2 signály?

## Další kroky (návrh)
- Podle zpětné vazby upravit bitvu.
- Mapa runu (pár stagí za sebou) a odměny po stagi.
