# Kontext: běh (run)

Soubory: `scripts/run/run_state.gd` (logika běhu), `scripts/run/act_map.gd` (generátor mapy aktu), `scripts/run/run_main.gd` + `scenes/run/run.tscn` (obrazovky, hlavní scéna hry), `scripts/run/map_view.gd` (kreslení mapy), `data/akt_1.json`, `data/udalosti.json`
Hlídá: `tests/test_run.gd` (mapa, pravidla, události, tábor, celé běhy bez okna), `tests/screenshot_run.gd` (běh přes obrazovky)

## Účel
Spojit bitvy do příběhu rodu na mapě aktu. Struktura hry: `docs/struktura-hry.md` (běh → 3 akty → 7 pater → uzly). Zatím je jen akt 1 (Hraběcí les), běh končí jeho bossem (Hejtman Kuno).

## Invarianty
1. **Logika běhu je v `run_state.gd` a `act_map.gd`, bez grafiky.** Obrazovky jen čtou stav a volají metody. Běh jde odehrát v testu bez okna.
2. **Mapa aktu** (`ActMap.generate(act, rng)`, deterministická se semínkem): `floors` pater po `width_min`–`width_max` uzlech, nahoře boss. Každý uzel má cestu dál, každý uzel nad prvním patrem cestu dovnitř, cesty se nekříží, poslední patro vede k bossovi. První patro samé `first_floor` (bitvy), poslední `last_floor` (tábor), na předposledním není tábor, elity až od `elite_from`, dvě elity ani dva tábory za sebou na jedné cestě nejsou. Bitvy a elity berou scénáře z promíchaných seznamů, události z `events`.
3. **Postup:** `available()` (na začátku celé 1. patro, pak cesty z uzlu) → `choose(id)`. Dokud uzel není vyřízený (`node_finished`: bitva s dědictvím a odměnou, rozhodnutá událost), dál se nejde.
4. **Padlí zůstanou padlí:** padlý jde do `fallen`, na jeho místo nastoupí nástupce stejné třídy (`successors` v rodu, pak římské číslice) **bez pasivek a zdravý**. Po bossovi už nikdo nenastupuje.
5. **Dědictví přísahy:** nedodržená přísaha padlého čeká v `pending_legacy`; převzít ji může hrdina bez přísahy (i nástupce), nebo zanikne. Hrdina má nejvýš 1 přísahu. Porušená přísaha po bitvě zmizí.
6. **Zranění se nesou** (`heroes[cls].hp`, podíl 0–1, do bitvy přes `setup.hp`): po bitvě se hrdina doléčí o `regen` (0,2), tábor o `camp_heal` (vše), jednou za tábor. Zranění z události nikoho nezabije (minimum 10 %). **Sláva se přenáší**, nejvýš `glory.carry_max` (50).
7. **Odměna po vítězné bitvě:** `offers` nabídek {hrdina, pasivka} a 1 výběr; elita `elite_offers` (4) a `elite_picks` (2). Pasivka sedí na třídu (nebo `any`), hrdina ji nemá, druhou přísahu nedostane; po první volbě u elity se neplatné nabídky vyřadí.
8. **Události** (`udalosti.json`): volby s efekty `glory`, `heal`, `wound`, `gift` (náhodná pasivka/přísaha náhodnému hrdinovi, kterému sedí), `fled` (nepřátelé, kteří se vrátí u bosse). Volba bez dost slávy nebo bez možného příjemce nejde (`event_option_problem`). Text volby jde do kroniky.
9. **Uprchlíci:** nepřátelé, kteří utečou v bitvě bez `returnees` (nebo z události), se vrátí v bitvě, která `returnees` má (boss).
10. **Prohra = padli všichni** v jedné bitvě → běh končí (`over = "lose"`). Po bossovi `over = "win"`.
11. **Kronika** (`chronicle`: {stage, text}): vítězství a porážky, padlí a jejich sláva, nástupci, útěky a návraty, přísahy (složené, převzaté, porušené, zaniklé), odměny, události, tábor.
12. **Bitva v běhu** (`battle.gd` s `run` ≠ null): scénář z uzlu, bez výběru bitvy, pasivky jen ke čtení, výsledek s „Pokračovat v běhu“ → `battle_done(result)`.

## Rozhraní
- `Run.new(seed = -1, act_key = "akt_1")`
- mapa: `map` ({floors, boss, nodes}), `node(id)`, `node_type(id)`, `node_label(id)`, `node_id`, `path`, `available()`, `choose(id)`, `node_finished()`, `current_floor()`, `floor_count()`, `scenario_info(key)`, `is_battle_node()`
- rod: `heroes` (třída → {name, passives, glory, hp, joined}), `fallen`, `fled`, `returned`, `glory`, `chronicle`, `over`, `hero_name`, `class_name_of`, `passive_name`, `passive_desc`, `is_oath`, `oath_of`, `hp_of`
- bitva: `load_stage_data()`, `battle_setup(data)`, `returnee_rows(scenario)`, `record_battle(result)`
- po bitvě: `has_legacy()`, `legacy_current()`, `legacy_candidates()`, `resolve_legacy(cls | "")`, `offers()`, `offer_valid(o)`, `picks_left()`, `pick_offer(i)`
- událost: `event()`, `event_option_problem(i)`, `event_choose(i)`, `event_done`; tábor: `camp_rest()`, `camp_done`

## Úskalí
- Nabídky se počítají líně a po `resolve_legacy` znovu (dědictví může změnit, kdo smí dostat přísahu); obrazovka nejdřív vyřeší dědictví, pak odměnu.
- Varianty scénářů (`base`) se skládají přes `Sim.read_scenario`; pro název a popis uzlu používej `scenario_info`, ne surový JSON.
- Vzhled obrazovek a mapy je zástupný (půjčuje si téma z `battle_ui.gd`); finální UI navrhne Tom.

## Historie významných změn
- 29.10.2026: na mapě (najetí na uzel, tooltip) je vidět typ bitvy.
- 29.10.2026: mapa aktu 1 (2.1): 7 pater, bitvy, elity (2 ze 4 odměn), události (4), tábor, boss; zranění se nesou; nástupci v datech rodu; zkušební běh nahrazen. Auto-hraní s náhodnou cestou: ~50–65 % vítězných běhů, nejčastěji se prohrává u bosse.
- 28.10.2026: založeno se zkušebním během (krok 1.7). Auto-hraní se schopnostmi a náhodnými odměnami: 17/20 vítězných běhů.
