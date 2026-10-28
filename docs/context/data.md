# Kontext: herní data

Soubory: `data/units.json`, `data/rod_vlka.json`, `data/scenarios/*.json`
Hlídá: `tests/test_battle_sim.gd` (balanc), `tests/screenshot_battle.gd` (načtení)

## Účel
Veškerý obsah a čísla. Přidat obsah má znamenat přidat data, ne kód.

## Invarianty
1. **Klíče, na které se odkazuje kód, se nepřejmenovávají** bez úpravy kódu: rytíři `tank`, `praporecnik`, `knez`, `lucistnik`, `jezdec`; nepřátelé `lapka`, `strelec`; postoje `utok`, `drzet`, `chranit`; pokřiky `zarod`, `hradba`; přísaha `nikdy_neustoupi`.
2. **Jednotky:** vzdálenosti v metrech, čas v sekundách, rychlost v m/s, `armor` je podíl 0–1, bonusy jsou podíly (0.5 = +50 %).
3. **`palette_row`** odpovídá řádku paletové textury: 0 rod Vlka, 1 tank, 2 lučištník, 3 kněz, 4 jezdec, 5 praporečník (6–7 volné).
4. **Každá změna čísla v bitvě = spustit test balancu** a výsledek zapsat do commitu.
5. Texty jsou česky, jak je uvidí hráč.

## Úskalí
- JSON nemá komentáře: popis patří do klíče `_info`.
- Při exportu hry je potřeba přidat `*.json` do filtru exportovaných souborů (zatím neřešeno).

## Historie významných změn
- 2026-10-28: založeno, čísla vyladěná simulací webového dema.
