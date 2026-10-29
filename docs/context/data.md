# Kontext: herní data

Soubory: `data/units.json`, `data/rod_vlka.json`, `data/scenarios/*.json`, `data/akt_*.json`, `data/udalosti.json`
Hlídá: `tests/test_battle_sim.gd` (balanc), `tests/screenshot_battle.gd` (načtení)

## Účel
Veškerý obsah a čísla. Přidat obsah má znamenat přidat data, ne kód.

## Invarianty
1. **Klíče, na které se odkazuje kód, se nepřejmenovávají** bez úpravy kódu: hrdinové `tank`, `knez`, `lucistnik`, `jezdec`, `asasin`; nepřátelé `lapka`, `strelec`, `kopinik`; chování `frontline`, `healer`, `archer`, `rider`, `assassin`; schopnosti `vyzva`, `pozehnani`, `salva`, `najezd`, `uder`; vlastnosti `zoufalec`, `fanatik`, `zbabelec`; scénáře `most_pres_reku`, `brod_a_les`; pasivky a přísahy podle `passives` (klíče, na které se odkazuje kód: `ochrance`, `druhy_dech`, `posledni_pomazani`, `probodnuti`, `rozbeh`, `ze_stinu`, `ukryt`, `lovec`, `mstitel`, `pomsta`).
2. **Jednotky:** vzdálenosti v metrech, čas v sekundách, rychlost v m/s, `armor` je podíl 0–1, bonusy jsou podíly (0.5 = +50 %).
3. **`palette_row`** odpovídá řádku paletové textury: 0 rod Vlka, 1 tank, 2 lučištník, 3 kněz, 4 jezdec, 5 asasín (6–7 volné).
4. **Každá změna čísla v bitvě = spustit test balancu** a výsledek zapsat do commitu.
5. Texty jsou česky, jak je uvidí hráč.
6. **Hrdina** (`knights.<klíč>`): statistiky, `behavior` (klíč z `behaviors`), `ability` (klíč z `abilities`). Bonusy rodu se zapékají přímo do hodnot hrdinů, žádné bonusy pro celý oddíl.
7. **Jádro tříd Rodu Vlka je pevné:** tank, kněz, lučištník, jezdec, asasín. Přidat nebo odebrat třídu jde jen po rozhodnutí v deníku (Tom).
8. **Chování** (`behaviors`): `name`, `desc` a čísla (`engage`, `guard`, `ahead`, `behind`, `kite`, `kite_step`); `_common`: `help_window`, `decided_ratio`.
9. **Schopnosti** (`abilities`): `name`, `desc`, `uses`, `target` (none/point/enemy), `range` a čísla podle schopnosti (`radius`, `duration`, `damage_taken`, `heal_frac`, `arrows`, `dmg`, `stun`, `width`, `speed_mult`, `land`, `mult`). Nová schopnost = nový záznam + kód v `use_ability`; nová čísla = jen data.
10. **Rod** (`rod_vlka.json`): `glory` (`start`, `max`, `per_hit`, `per_kill`, `oath_per_second`, `extra_use_cost`) a `start_passives` (pasivky hrdinů na začátku; přísaha tanka je v prototypu jen na zkoušku).
16. **Pasivky a přísahy** (`passives` v `units.json`): `name`, `class` (klíč hrdiny nebo `any`), `kind` (`passive` / `oath`), `desc` a efekty: `stat_mult` (`hp`, `heal`, `cd`), `ability_mod` (čísla schopnosti), `extra_uses`, `dmg_bonus`, `no_retreat`, `break_glory_cost`, `vs_grudge`, `ignores_orders`, `no_glory`, `vs_ranged`, `mult`, `hidden_t`, `guard_radius`/`guard_taken`, `at`/`heal_frac`, `radius`/`revive_frac`, `pierce_radius`/`pierce_frac`. Nová kombinace čísel = data; nový druh efektu = kód v simulaci.
11. **Morálka** (`morale` v `units.json`): `break_losses`, `desperate_dmg_bonus`; nepřítel má `on_break` (`flee` / `desperate`). Scénář: `enemy_morale` (`break_losses`, `flee_y`).
12. **Terén ve scénáři:** `river` {`y0`, `y1`, `crossings`: [{`x0`, `x1`, `kind`: most/brod/lavka, `speed`}]}, `forests`: [{`x0`, `x1`, `y0`, `y1`, `speed`, `path`: [x0, x1]}], volitelně `trees`, `rocks`. Rozestavení: `deploy.<klíč>` = `pos` (+ volitelně `route`).
13. **Nový scénář = nový soubor** v `data/scenarios/` a zápis do `index.json` (test balancu jede přes všechny). Scénář má `win_title`, `optional_task.protect` je id hrdiny nebo `"all"`, nebo `optional_task.kill` (klíč nepřítele). **Varianta** má `base` (klíč základního scénáře) a přepisuje jen svá pole (`Sim.read_scenario`). `elite: true` = elita (stačí 20/40 výher se schopnostmi). `returnees` = kde se vrátí uprchlíci.
17. **Akt** (`akt_1.json`): `name`, `floors`, `width_min`/`width_max`, `first_floor`, `last_floor`, `weights` typů uzlů, `elite_from`, `battles`, `elites`, `boss`, `events`, `regen`, `camp_heal`, `offers`, `elite_offers`, `elite_picks`.
19. **Typy bitev** (`battle_modes` v `units.json`): `utok` (`leaders`, `follow`, `cohesion`), `stret`, `obrana`; `name` a `desc` vidí hráč. Scénář: `mode` (výchozí `stret`), u útoku volitelně `objective` [x, y] (kam oddíl postupuje nejdřív) a `alarm_radius` (jak daleko se šíří poplach mezi nepřáteli na pozici).
18. **Události** (`udalosti.json`): `name`, `text`, `options` [{`label`, `hint`, `effects`, `text`}]; efekty `glory`, `heal`/`wound` {`who`: all/random/wounded, `frac`}, `gift` (passive/oath), `fled` {klíč nepřítele: počet}. Nová událost = jen data; nový druh efektu = kód v `run_state.gd`.
14. **Vlastnosti** (`traits`): `name`, `desc` a efekty `never_breaks`, `on_break`, `desperate_dmg_bonus`. Jízda: `mounted`; kopí: `dmg_vs_mounted`; terén: `ignores`.
15. **Rozkazy nepřátel ve scénáři:** řádek `[typ, x, y, (vlastnosti), (rozkazy)]`, rozkazy `{"hold": true, "engage": m, "hold_time": s}`.

## Úskalí
- JSON nemá komentáře: popis patří do klíče `_info`.
- Při exportu hry je potřeba přidat `*.json` do filtru exportovaných souborů (zatím neřešeno).

## Historie významných změn
- 29.10.2026: `battle_modes`, `mode` u scénářů (Most a Most pod palbou střet, ostatní útok), `objective` (Brod: levý brod), `alarm_radius`; Požehnání mířené (`target: point`, `range` 10, `radius` 4), `heal_range` kněze 9; Brod +1 střelec, Brod elita bez kopiníků na lávce, Garda −1 kopiník, boss +2 lapkové a Hejtman 480 zdraví.
- 29.10.2026: akt 1 (`akt_1.json`), události (`udalosti.json`), varianty scénářů přes `base` (Most pod palbou, Brod za svítání, elity Lapkovská garda a Posádka Černého brodu), `successors` přesunuty do rodu (`run_zkusebni.json` zrušen), `morale.auto_charge_after` (25 s).
- 29.10.2026: `glory.extra_uses_max` (1), `glory.carry_max` (50), `cooldown` u schopnosti (Požehnání 20 s), chování `healer.defend`/`assist`, `assassin.roams`.
- 28.10.2026: `run_zkusebni.json` (pořadí bitev, počet nabídek, jména nástupců), scénář `zaverecna_bitva` (Tábor na Vraní skále: `returnees`, úkol `kill`), nepřítel `vudce` (Hejtman Kuno, `leader`).
- 28.10.2026: `passives` (15 pasivek, 3 přísahy), `start_passives` v rodu místo `oaths`.
- 28.10.2026: přestavba na hrdiny: pryč `banner`, `postures`, `aura`, `shouts`, `banner_bearer`, postoje v rozestavení; nové `behaviors`, `abilities`, `glory.extra_use_cost`. Most: úkol Otec Jan nesmí padnout.
- 28.10.2026: postoje jako slovníky s názvem, popisem a čísly, seznam postojů u třídy (`posture_desc` zrušeno), Brod: nepřátelé drží pozice 30 s, +1 lapka a +1 kopiník.
- 28.10.2026: řeka s přechody místo `river_lo`/`bridge_half_width`, lesy, `index.json`, scénář Brod a les, kopiník, vlastnosti (zoufalství lapky 20 % + Zoufalec 10 % = 30 % jako dřív), `mounted`, `ignores`.
- 28.10.2026: `morale`, `on_break` u nepřátel, `enemy_morale` ve scénáři (práh 0,7, okraj y = 20), `behavior.decided_ratio` 0,15.
- 28.10.2026: praporečník nahrazen asasínem (řádek palety 5), `banner` u každé třídy, `target_priority`, `posture_desc`, úkol „Prapor nesmí padnout“. Lapka útok 6 → 7. Balanc: bez pokřiků 0/40, s pokřiky 40/40 (62 s); podle nositele s pokřiky: tank, kněz, lučištník, asasín 40/40, jezdec 0/40.
- 2026-10-28: přísaha `nikdy_neustoupi` dostala `no_retreat`, `forbidden_postures` a `posture_names`.
- 2026-10-28: založeno, čísla vyladěná simulací webového dema.
