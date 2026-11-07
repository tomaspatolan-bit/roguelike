# Kontext: běh (run)

Soubory: `scripts/run/run_state.gd` (logika běhu), `scripts/run/act_map.gd` (generátor mapy aktu), `scripts/run/run_main.gd` + `scenes/run/run.tscn` (obrazovky, hlavní scéna hry), `scripts/run/map_view.gd` (kreslení mapy), `data/akt_1.json`, `data/udalosti.json`
Hlídá: `tests/test_run.gd` (mapa, pravidla, události, tábor, celé běhy bez okna), `tests/screenshot_run.gd` (běh přes obrazovky)

## Účel
Spojit bitvy do příběhu rodu na mapě aktu. Struktura hry: `docs/struktura-hry.md` (běh → 3 akty → 7 pater → uzly). Zatím je jen akt 1 (Hraběcí les), běh končí jeho bossem (Hejtman Kuno).

## Invarianty
1. **Logika běhu je v `run_state.gd` a `act_map.gd`, bez grafiky.** Obrazovky jen čtou stav a volají metody. Běh jde odehrát v testu bez okna.
2. **Mapa aktu** (`ActMap.generate(act, rng)`, deterministická se semínkem): `floors` pater po `width_min`–`width_max` uzlech, nahoře boss. Každý uzel má cestu dál, každý uzel nad prvním patrem cestu dovnitř, cesty se nekříží, poslední patro vede k bossovi. První patro samé `first_floor` (bitvy), poslední `last_floor` (tábor), na předposledním není tábor, elity až od `elite_from`, dvě elity ani dva tábory za sebou na jedné cestě nejsou. Bitvy a elity berou scénáře z promíchaných seznamů, události z `events`. **Chytrý shuffle** (`_balance_types`, rozhodnutí 07.11.2026 po playtestu se třemi událostmi za sebou): na cestě nikdy dvakrát za sebou stejný typ bez boje (událost, elita, tábor), nejvýš `max_calm` (2) uzly bez boje za sebou, rozcestí vždy nabízí různé typy (když žádný typ nesedí, zbytečná cesta se zruší), na předposledním patře žádný tábor.
3. **Postup:** `available()` (na začátku celé 1. patro, pak cesty z uzlu) → `choose(id)`. Dokud uzel není vyřízený (`node_finished`: bitva s dědictvím a odměnou, rozhodnutá událost), dál se nejde.
4. **Padlí zůstanou padlí:** padlý jde do `fallen`, na jeho místo nastoupí nástupce stejné třídy (`successors` v rodu, pak římské číslice) **bez pasivek a zdravý**. Po bossovi už nikdo nenastupuje.
5. **Dědictví přísahy:** nedodržená přísaha padlého čeká v `pending_legacy`; přísahu rodu může převzít kdokoli bez přísahy, osobní přísahu třídy jen nástupce stejné třídy (`legacy_candidates`), nebo zanikne. Bitva dostává `ancestors` = počet padlých (Přísaha předků). Hrdina má nejvýš 1 přísahu. Porušená přísaha po bitvě zmizí.
6. **Zranění se nesou** (`heroes[cls].hp`, podíl 0–1, do bitvy přes `setup.hp`): po bitvě se hrdina doléčí o `regen`; v táboře jen volbou Odpočinek (Hostina +50 %). Zranění z události nikoho nezabije (minimum 10 %). **Sláva se přenáší**, nejvýš `glory.carry_max` (120, měna běhu).
7. **Odměna po vítězné bitvě** (`_make_offers`): `offers` nabídek, z toho `offer_oaths` (1) přísaha a zbytek pasivky, různí hrdinové a různé pasivky; elita `elite_offers` (4) a `elite_picks` (2). Hrdina, který v bitvě padl, nabídku nedostane (ani jeho nástupce). Pasivka sedí na třídu, hrdina ji nemá, druhou přísahu nedostane. Odměnu jde odmítnout za `decline_glory` (15) slávy (`decline_offers`). Karta nabídky ukazuje dopad (`offer_notes`: přísaha sedí / tluče se se schopností hrdiny s důvodem, bonus k vlastnosti, na které hrdinovi skoro nezáleží, je promrhaný). **Obecná volba** (`_open_choice`, `offer_title`): stejné nabídky slouží událostem a táboru, druhy `passive` (i přísaha), `max_hp`, `release_oath`.
8. **Události** (`udalosti.json`, 12): každá nejvýš jednou za běh (`used_events`). `target` určuje, koho se týká (melee, priest, oath, unbonded_pair, fallen_successor); podmíněná událost se objeví, jen když cíl existuje, jinak `choose` vybere jinou nepoužitou (`_resolve_event`, `event_ctx`, texty s {hero}, {a}, {b}, {fallen}). Efekty: `glory`, `heal`/`wound` (who: all, random, random2, wounded, target), `gift`, `fled`, `oath_choice`, `passive_choice`, `max_hp_choice`, `chance` (win/lose), `pair_wins`, `next_battle` (`remove_pods`, `pair_stats`), `inherit`, `perm_stats`, `oath_boost`, `release_oath`. Volba bez dost slávy nebo bez možného příjemce nejde (`event_option_problem`). Po události může přijít volba nebo pouto.
9. **Uprchlíci:** nepřátelé, kteří utečou v bitvě bez `returnees` (nebo z události), se vrátí v bitvě, která `returnees` má (boss), nejvýš `returnees.max` (u Hejtmana 3), ostatní se rozutekli nadobro.
10. **Prohra = padli všichni** v jedné bitvě → běh končí (`over = "lose"`). Po bossovi `over = "win"`.
14. **Pouta** (rozhodnutí 07.11.2026): `pair_wins` (`pair_key` „a|b“ podle abecedy) se po každé vyhrané bitvě zvýší všem dvojicím, které obě přežily (`_count_wins`). Dvojice s `bond_rules.levels[0]` vítězstvími, kde nikdo nemá pouto ani Přísahu samotáře, dostane nabídku (`bond_offer`: nejvíc vítězství první, `choices` typů, které na dvojici sedí, `bond_fits`); `choose_bond(typ | "")` (odložení = znovu až po dalším společném vítězství, `bond_declined`). Pořadí po bitvě: dědictví → pouto → odměna. Úroveň pouta z počtu vítězství (`bond_level`, `level_for`), bitva dostává `setup.bonds`. Smrt: druh přijde o pouto (Učitel a žák: žák zdědí pasivku učitele), padlého historie se smaže a nástupce začíná od nuly (`_bonds_after_deaths`). Přísahu samotáře nedostane hrdina s poutem.

15. **Tábor** (`camp_options`, `camp_choose(id, arg)`, act `camp`): jedna volba za tábor: Odpočinek (vše vyléčí), Výcvik (hrdina, pasivka ze 3), Obřad (hrdina: přísaha ze 2, nebo zrušení přísahy bez trestu), Hostina (30 slávy: všichni +50 % zdraví, vybraná dvojice +1 společné vítězství, může vzniknout pouto). Tábor jde opustit i bez volby; započatá volba se musí dokončit.
16. **Jednorázové a trvalé efekty v bitvě:** `next_battle` platí jen pro příští bitvu (`remove_pods` = o skupinu nepřátel méně, `stats`), `heroes[cls].stats` natrvalo (kovář, zbraň předka), `heroes[cls].oath_boost` (Soud o přísahu); do simulace přes `setup.hero_stats`, `oath_boost`, `remove_pods`.

11. **Kronika** (`chronicle`: {stage, text}): vítězství a porážky, padlí a jejich sláva, nástupci, útěky a návraty, přísahy (složené, převzaté, porušené, zaniklé), odměny, události, tábor.
13. **Úvodní obrazovka:** Nový běh, Volná bitva a po dokončeném výcviku „Výcvik znovu“ (`BattleScript.set_tutorial_done(false)`).
12. **Bitva v běhu** (`battle.gd` s `run` ≠ null): scénář z uzlu, bez výběru bitvy, pasivky jen ke čtení, výsledek s „Pokračovat v běhu“ → `battle_done(result)`.

## Rozhraní
- `Run.new(seed = -1, act_key = "akt_1")`
- mapa: `map` ({floors, boss, nodes}), `node(id)`, `node_type(id)`, `node_label(id)`, `node_id`, `path`, `available()`, `choose(id)`, `node_finished()`, `current_floor()`, `floor_count()`, `scenario_info(key)`, `is_battle_node()`
- rod: `heroes` (třída → {name, passives, glory, hp, joined}), `fallen`, `fled`, `returned`, `glory`, `chronicle`, `over`, `hero_name`, `class_name_of`, `passive_name`, `passive_desc`, `is_oath`, `oath_of`, `hp_of`
- bitva: `load_stage_data()`, `battle_setup(data)`, `returnee_rows(scenario)`, `record_battle(result)`
- po bitvě: `has_legacy()`, `legacy_current()`, `legacy_candidates()`, `resolve_legacy(cls | "")`, `bond_offer()`, `choose_bond(typ | "")`, `pair_wins`, `wins_of()`, `bond_level()`, `bond_fits()`, `bond_name()`, `bond_desc()`, `offers()`, `offer_valid(o)`, `picks_left()`, `pick_offer(i)`
- odměna a volby: `offers()`, `offer_valid()`, `offer_notes(o)`, `pick_offer(i)`, `picks_left()`, `decline_offers()`, `offer_title`, `offer_declinable`
- událost: `event()`, `event_option_problem(i)`, `event_choose(i)`, `event_done`, `event_ctx`, `used_events`, `next_battle`; tábor: `camp_options()`, `camp_choose(id, arg)`, `camp_rest()`, `camp_done`

## Úskalí
- Nabídky se počítají líně a po `resolve_legacy` znovu (dědictví může změnit, kdo smí dostat přísahu); obrazovka nejdřív vyřeší dědictví, pak odměnu.
- Varianty scénářů (`base`) se skládají přes `Sim.read_scenario`; pro název a popis uzlu používej `scenario_info`, ne surový JSON.
- Vzhled obrazovek a mapy je zástupný (půjčuje si téma z `battle_ui.gd`); finální UI navrhne Tom.

## Historie významných změn
- 07.11.2026: krok 2.3c: chytrý shuffle mapy, odměny 2 pasivky + přísaha s vysvětlením dopadu a odmítnutím za slávu, tábor se čtyřmi volbami, 12 událostí s cíli a novými efekty, sláva do 120.
- 07.11.2026: texty a komentáře přeložené do angličtiny (`docs/glosar.md`).
- 07.11.2026: pouta rostou společnými vítězstvími, obrazovka volby pouta po bitvě, pouto v soupisce.
- 07.11.2026: osobní přísahu dědí jen nástupce, přísahu rodu kdokoli; setup bitvy nese počet padlých předků.
- 29.10.2026: u Hejtmana se vrátí nejvýš 3 uprchlíci (auto-hraní vyhrávalo jen 3–4 běhy z 20, skoro vždy se prohrálo u bosse).
- 29.10.2026: Lesní ves (obrana) mezi bitvami aktu, po bitvě se hrdina doléčí o 30 %, tábory častěji (váha 2).
- 29.10.2026: na mapě (najetí na uzel, tooltip) je vidět typ bitvy.
- 29.10.2026: mapa aktu 1 (2.1): 7 pater, bitvy, elity (2 ze 4 odměn), události (4), tábor, boss; zranění se nesou; nástupci v datech rodu; zkušební běh nahrazen. Auto-hraní s náhodnou cestou: ~50–65 % vítězných běhů, nejčastěji se prohrává u bosse.
- 28.10.2026: založeno se zkušebním během (krok 1.7). Auto-hraní se schopnostmi a náhodnými odměnami: 17/20 vítězných běhů.
