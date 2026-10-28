# Kontext: běh (run)

Soubory: `scripts/run/run_state.gd` (logika), `scripts/run/run_main.gd` + `scenes/run/run.tscn` (obrazovky, hlavní scéna hry), `data/run_zkusebni.json`
Hlídá: `tests/test_run.gd` (pravidla a celé běhy bez okna), `tests/screenshot_run.gd` (běh přes obrazovky)

## Účel
Spojit bitvy do příběhu rodu: co se stane v jedné bitvě, nese se do další. Zkušební běh (krok 1.7) = 3 bitvy: Most přes řeku → Brod a les → Tábor na Vraní skále (vůdce Hejtman Kuno).

## Invarianty
1. **Logika běhu je v `run_state.gd`, bez grafiky.** Obrazovky (`run_main.gd`) jen čtou stav a volají jeho metody. Běh jde odehrát v testu bez okna.
2. **Průběh:** `battle_setup(data)` → bitva → `record_battle(sim.result())` → dědictví přísah (`legacy_*`) → odměna (`offers` / `pick_offer`) → další bitva. Po poslední bitvě nebo porážce `over` = `win` / `lose` a kronika.
3. **Padlí zůstanou padlí:** padlý jde do `fallen`, na jeho místo nastoupí nástupce stejné třídy s novým jménem (`successors` v datech) a **bez pasivek**. Po závěrečné bitvě už nikdo nenastupuje.
4. **Dědictví přísahy:** nedodržená přísaha padlého čeká v `pending_legacy`; převzít ji může živý hrdina bez přísahy (i nástupce), nebo zanikne. Hrdina má nejvýš 1 přísahu.
5. **Porušená přísaha** po bitvě zmizí (zápis do kroniky).
6. **Zranění se vyléčí:** každá bitva začíná s plným zdravím (simulace se staví znovu). **Sláva se přenáší** (`setup.glory`, strop `glory.max`).
7. **Odměna po vítězné bitvě:** 3 nabídky {hrdina, pasivka}, vybírá se jedna; pasivka sedí na třídu (nebo `any`), hrdina ji ještě nemá, přísahu nedostane hrdina, který už přísahu má. Nabídky se snaží o různé hrdiny a různé pasivky.
8. **Uprchlíci:** nepřátelé, kteří utečou v bitvě bez `returnees`, se vrátí v první bitvě, která `returnees` má (závěrečná), v řadách kolem `returnees.pos`.
9. **Prohra = padli všichni** (simulace jinak než vítězstvím neskončí) → běh končí.
10. **Kronika** (`chronicle`: {stage, text}) zapisuje: vítězství/porážky, padlé a kolik slávy přinesli, nástupce, útěky a návraty, přísahy (složené, převzaté, porušené, zaniklé), odměny.
11. **Bitva v běhu** (`battle.gd` s `run` ≠ null): bez výběru bitvy, pasivky jen ke čtení, počet signálů daný, výsledek s tlačítkem „Pokračovat v běhu“ → signál `battle_done(result)`.

## Rozhraní
- `Run.new(seed = -1, run_key = "run_zkusebni")`
- čtení: `stage`, `stage_count()`, `stage_key()`, `stage_name(i)`, `heroes` (třída → {name, passives, glory, joined}), `fallen`, `fled`, `returned`, `glory`, `chronicle`, `over`, `hero_name`, `class_name_of`, `passive_name`, `passive_desc`, `is_oath`, `oath_of`
- bitva: `load_stage_data()`, `battle_setup(data)`, `returnee_rows(scenario)`, `record_battle(result)`
- tábor: `has_legacy()`, `legacy_current()`, `legacy_candidates()`, `resolve_legacy(cls | "")`, `offers()`, `pick_offer(i)`

## Úskalí
- `record_battle` čte název scénáře z `stage` před jeho zvýšením; po zvýšení ukazuje `stage_name()` na další bitvu.
- Nabídky se počítají líně a po `resolve_legacy` znovu (dědictví může změnit, kdo smí dostat přísahu); proto obrazovka nejdřív vyřeší dědictví, pak ukáže odměnu.
- Vzhled obrazovek je zástupný (půjčuje si téma a tlačítka z `battle_ui.gd`); finální UI navrhne Tom.

## Historie významných změn
- 28.10.2026: založeno se zkušebním během (krok 1.7). Auto-hraní se schopnostmi a náhodnými odměnami: 17/20 vítězných běhů.
