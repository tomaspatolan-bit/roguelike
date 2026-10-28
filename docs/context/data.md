# Kontext: herní data

Soubory: `data/units.json`, `data/rod_vlka.json`, `data/scenarios/*.json`
Hlídá: `tests/test_battle_sim.gd` (balanc), `tests/screenshot_battle.gd` (načtení)

## Účel
Veškerý obsah a čísla. Přidat obsah má znamenat přidat data, ne kód.

## Invarianty
1. **Klíče, na které se odkazuje kód, se nepřejmenovávají** bez úpravy kódu: rytíři `tank`, `knez`, `lucistnik`, `jezdec`, `asasin`; nepřátelé `lapka`, `strelec`; postoje `utok`, `drzet`, `chranit`; pokřiky `zarod`, `hradba`; přísaha `nikdy_neustoupi`.
2. **Jednotky:** vzdálenosti v metrech, čas v sekundách, rychlost v m/s, `armor` je podíl 0–1, bonusy jsou podíly (0.5 = +50 %).
3. **`palette_row`** odpovídá řádku paletové textury: 0 rod Vlka, 1 tank, 2 lučištník, 3 kněz, 4 jezdec, 5 asasín (6–7 volné).
4. **Každá změna čísla v bitvě = spustit test balancu** a výsledek zapsat do commitu.
5. Texty jsou česky, jak je uvidí hráč.
6. **Přísaha** (`oaths.<klíč>`): `knight` (id rytíře), `dmg_bonus`, `break_glory_cost`, `no_retreat` (bool), `forbidden_postures` (seznam klíčů postojů), `posture_names` (přejmenování postojů, dokud přísaha platí), `desc`. Nová přísaha = nový záznam, ne nový kód.
7. **Jádro tříd rytířů je pevné:** tank, kněz, lučištník, jezdec, asasín. Přidat nebo odebrat třídu jde jen po rozhodnutí v deníku (Tom). Praporečník jako třída neexistuje, prapor nese kterákoli třída.
8. **Prapor podle třídy** (`knights.<klíč>.banner`): `aura_radius`, `aura_dmg_bonus`, `aura_armor`, `aura_speed`, `aura_heal`, `desc` (text pro hráče). Každá třída musí mít `banner` s `desc`. Nový efekt = nový klíč i kód v simulaci, nová kombinace čísel = jen data.
9. **Scénář:** `banner_bearer` je výchozí nositel; `optional_task.protect` je id rytíře, nebo `"banner"` (nositel praporu nesmí padnout).

## Úskalí
- JSON nemá komentáře: popis patří do klíče `_info`.
- Při exportu hry je potřeba přidat `*.json` do filtru exportovaných souborů (zatím neřešeno).

## Historie významných změn
- 28.10.2026: praporečník nahrazen asasínem (řádek palety 5), `banner` u každé třídy, `target_priority`, `posture_desc`, úkol „Prapor nesmí padnout“. Lapka útok 6 → 7. Balanc: bez pokřiků 0/40, s pokřiky 40/40 (62 s); podle nositele s pokřiky: tank, kněz, lučištník, asasín 40/40, jezdec 0/40.
- 2026-10-28: přísaha `nikdy_neustoupi` dostala `no_retreat`, `forbidden_postures` a `posture_names`.
- 2026-10-28: založeno, čísla vyladěná simulací webového dema.
