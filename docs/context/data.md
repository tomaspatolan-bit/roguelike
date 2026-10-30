# Kontext: herní data

Soubory: `data/vycvik.json`, `data/units.json`, `data/rod_vlka.json`, `data/scenarios/*.json`, `data/akt_*.json`, `data/udalosti.json`
Hlídá: `tests/test_battle_sim.gd` (balanc), `tests/screenshot_battle.gd` (načtení)

## Účel
Veškerý obsah a čísla. Přidat obsah má znamenat přidat data, ne kód.

## Invarianty
1. **Klíče, na které se odkazuje kód, se nepřejmenovávají** bez úpravy kódu: hrdinové `tank`, `knez`, `lucistnik`, `jezdec`, `asasin`; nepřátelé `lapka`, `strelec`, `kopinik`; schopnosti `vyzva`, `pozehnani`, `salva`, `najezd`, `uder`; vlastnosti `zoufalec`, `fanatik`, `zbabelec`; scénáře `most_pres_reku`, `brod_a_les`; pasivky a přísahy podle `passives` (klíče, na které se odkazuje kód: `ochrance`, `druhy_dech`, `posledni_pomazani`, `probodnuti`, `rozbeh`, `ze_stinu`, `ukryt`, `lovec`, `mstitel`, `pomsta`).
2. **Jednotky:** vzdálenosti v metrech, čas v sekundách, rychlost v m/s, `armor` je podíl 0–1, bonusy jsou podíly (0.5 = +50 %).
3. **`palette_row`** odpovídá řádku paletové textury: 0 rod Vlka, 1 tank, 2 lučištník, 3 kněz, 4 jezdec, 5 asasín (6–7 volné).
4. **Každá změna čísla v bitvě = spustit test balancu** a výsledek zapsat do commitu.
5. Texty jsou česky, jak je uvidí hráč.
6. **Hrdina** (`knights.<klíč>`): statistiky, `ability` (klíč z `abilities`). Bonusy rodu se zapékají přímo do hodnot hrdinů, žádné bonusy pro celý oddíl.
7. **Jádro tříd Rodu Vlka je pevné:** tank, kněz, lučištník, jezdec, asasín. Přidat nebo odebrat třídu jde jen po rozhodnutí v deníku (Tom).
8. **Rozkazy** (`orders` v `units.json`): `hold_radius`, `on_way`, `on_way_ranged`, `ally_dist`, `ally_dist_back`, `ally_guard`, `ally_leash`, `focus_leash`, `focus_time`, `hint_support`, `hint_dive_hp` (rada pro auto-hraní: pod tímto podílem zdraví hrdina neskáče), `melee_slots` (kolik pěších smí útočit na jednoho hrdinu), `wait_gap` (odstup čekajících), `body_gap` (odtlačování těl), `avoid_look`, `avoid_strength`, `settle`, `group_link` a `names` (texty rozkazů pro hráče). Nepřítel má `plural` (název skupiny). Výchozí chování tříd (`behaviors`) je zrušené.
9. **Schopnosti** (`abilities`): `name`, `desc`, `uses` (pevný počet za bitvu), `cooldown`, `target` (none/point/enemy), `range` a čísla podle schopnosti (`radius`, `duration`, `damage_taken`, `heal_frac`, `arrows`, `dmg`, `stun`, `width`, `speed_mult`, `land`, `mult`). Nová schopnost = nový záznam + kód v `use_ability`; nová čísla = jen data.
10. **Rod** (`rod_vlka.json`): `glory` (`start`, `max`, `per_hit`, `per_kill`, `oath_per_second`; sláva už neplatí schopnosti) a `start_passives` (pasivky hrdinů na začátku; přísaha tanka je v prototypu jen na zkoušku).
16. **Pasivky a přísahy** (`passives` v `units.json`): `name`, `class` (klíč hrdiny nebo `any`), `kind` (`passive` / `oath`), `desc` a efekty: `stat_mult` (`hp`, `heal`, `cd`), `ability_mod` (čísla schopnosti), `extra_uses`, `no_heal` (kněz ho neléčí), `dmg_bonus`, `no_retreat`, `break_glory_cost`, `vs_grudge`, `ignores_orders`, `no_glory`, `vs_ranged`, `mult`, `hidden_t`, `guard_radius`/`guard_taken`, `at`/`heal_frac`, `radius`/`revive_frac`, `pierce_radius`/`pierce_frac`. Nová kombinace čísel = data; nový druh efektu = kód v simulaci.
11. **Morálka** (`morale` v `units.json`): `break_losses`, `desperate_dmg_bonus`, `auto_charge_after`, `decided_ratio`; nepřítel má `on_break` (`flee` / `desperate`). Scénář: `enemy_morale` (`break_losses`, `flee_y`).
12. **Terén ve scénáři:** `river` {`y0`, `y1`, `crossings`: [{`x0`, `x1`, `kind`: most/brod/lavka, `speed`}]}, `forests`: [{`x0`, `x1`, `y0`, `y1`, `speed`, `path`: [x0, x1]}], volitelně `trees`, `rocks`. Rozestavení: `deploy.<klíč>` = `pos`.
13. **Nový scénář = nový soubor** v `data/scenarios/` a zápis do `index.json` (test balancu jede přes všechny). Scénář má `win_title`, `optional_task.protect` je id hrdiny nebo `"all"`, nebo `optional_task.kill` (klíč nepřítele). **Varianta** má `base` (klíč základního scénáře) a přepisuje jen svá pole (`Sim.read_scenario`). `elite: true` = elita (stačí 20/40 výher se schopnostmi). `returnees` = kde se vrátí uprchlíci.
17. **Akt** (`akt_1.json`): `name`, `floors`, `width_min`/`width_max`, `first_floor`, `last_floor`, `weights` typů uzlů, `elite_from`, `battles`, `elites`, `boss`, `events`, `regen`, `camp_heal`, `offers`, `elite_offers`, `elite_picks`.
19. **Typy bitev** (`battle_modes` v `units.json`): `utok`, `stret`, `obrana`, jen `name` a `desc` (vidí hráč). Scénář: `mode` (výchozí `stret`), `alarm_radius` (jak daleko se šíří poplach mezi nepřáteli na pozici), `auto_plan` (`attack` / `hold`: jen pro automatického velitele v testech; varianta s `base` ho dědí, proto ho varianty uvádějí samy).
18. **Události** (`udalosti.json`): `name`, `text`, `options` [{`label`, `hint`, `effects`, `text`}]; efekty `glory`, `heal`/`wound` {`who`: all/random/wounded, `frac`}, `gift` (passive/oath), `fled` {klíč nepřítele: počet}. Nová událost = jen data; nový druh efektu = kód v `run_state.gd`.
21. **Velitelé:** nepřítel má `skill` (klíč z `foe_skills`); `foe_skills.<klíč>`: `name`, `kind` (`zone` / `shot` / `smash` / `rally`), `first` (s do prvního použití), `cd`, `windup` (s ohlášení), `range`, `radius`, `dmg`, `burn`/`burn_dps` (zóna), `dmg_mult`/`duration` (povel), `warn` (text, `%s` = jméno cíle). Velitelé: Pálič Vok (`palic`), Ostrostřelec Jíra (`ostrostrelec`), Setník Bořivoj (`setnik`), Hejtman Kuno (`vudce`).
14. **Vlastnosti** (`traits`): `name`, `desc` a efekty `never_breaks`, `on_break`, `desperate_dmg_bonus`. Jízda: `mounted`; kopí: `dmg_vs_mounted`; terén: `ignores`.
15. **Nepřátelé ve scénáři:** řádek `[typ, x, y, (vlastnosti), (rozkazy)]`, rozkazy `{"pod": n, "arrive": s}` (`pod` = číslo skupinky z `pods`, `arrive` = nepřítel z pozdější vlny dorazí v daný čas). Skupinky: `pods` [{`name`, `wake` (m, kdy ji hrdina probudí), `alarm` (m, volitelně), `awake` (bdí od začátku)}], výchozí `wake_radius` a `alarm_radius` ve scénáři. Obtížnost: `foe_hp`, `foe_dmg` (násobky pro všechny nepřátele scénáře). Cíl: běžná bitva 7–8 nepřátel, elita 9, boss 9, obrana 12 ve 3 vlnách; v každé bitvě jeden velitel. `returnees` může mít `pod` (do které skupinky se uprchlíci vrátí). Scénář může mít `houses` [x, y, šířka, hloubka, otočení°] (zástupné chalupy).
20. **Vzhled hrdiny** (`knights.<klíč>`): `model` (GLB třídy, jinak rytíř), `weapon_model` (GLB zbraně), `weapon_bone`, `projectile` (vzhled střely: `svetlo` = zlatá koule, jinak šíp), `projectile_model` (GLB střely, lučištník `SM_Archer_Arrow`), `bow_string` {`top`, `bottom`} (konce tětivy v prostoru luku, Godot), `mount_model` (GLB koně), `rider_offset`, `mount_anims` {`idle`, `walk`, `gallop`, `hit`, `death`}, `mount_walk_speed`, `anims` {`idle`, `walk`, `attack`, `ability`, `hit`, `death`} (chybějící = rytířské), starší `anim_attack`, `anim_ability`, `weapon` (`sword`, `dagger`, `mace`, `bow`; zástupná zbraň, když třída nemá `weapon_model`).

22. **Kamera** (`camera` v `units.json` výchozí, ve scénáři přepíše jednotlivé klíče): `target` [x, y] výchozí střed výřezu, `yaw`, `pitch` (°), `distance`, `zoom` [min, max], `bounds` [x0, x1, y0, y1] (kam smí střed výřezu; stejné hodnoty = tím směrem se nehýbe), `pan_speed`. Výchozí výřez má ukázat hrdiny nad kartami.

23. **Výcvik** (`vycvik.json`): `title`, `steps` [{`done`, `text`, volitelně `trigger`, `wait_text`, `anchor`}]; klíče `done` viz `scena-bitvy.md` (invariant 16). Nový krok s existujícím klíčem = jen data, nový klíč = kód v `battle.gd`.

## Úskalí
- JSON nemá komentáře: popis patří do klíče `_info`.
- Při exportu hry musí být `*.json` ve filtru exportovaných souborů (`include_filter` v `export_presets.cfg`, viz `testy.md`, Export).

## Historie významných změn
- 30.10.2026: jezdec má koně (`mount_model`, `rider_offset`, `mount_anims`, `mount_walk_speed`), vlastní model jezdce, kopí a animace `A_Cavalier_*`; zástupná zvětšená postava ×1,08 v kódu pryč.
- 30.10.2026: lučištník má vlastní model, luk v levé ruce (`weapon_bone: hand_l`), `bow_string`, `projectile_model` a animace `A_Archer_*`; starší `anim_attack`, `anim_ability`, `weapon` u něj pryč.
- 30.10.2026: Most přes řeku `foe_hp`/`foe_dmg` 2,45 (bylo 2,3; po změně, že hrdinové sami nebudí spící skupinky, vyhrával i bez schopností).
- 30.10.2026: kněz má `model`, `weapon_model` (hůl) a `anims`; kněz útočí na dálku (`ranged`, dosah 6 m, útok 6, prodleva 1,5 s, `projectile: svetlo`), dřív na blízko (1,4 m, 5, 1,2 s).
- 30.10.2026: `camera` (výchozí v `units.json`, ve scénářích Most, Brod a les, Lesní ves s pevným výřezem, Tábor na Vraní skále).
- 30.10.2026: každá schopnost má 3 použití za bitvu (Tom: bitvy moc těžké), Požehnání a Nájezd nabíjení 20 s, Druhý nájezd = 4 použití.
- 29.10.2026: bitva ve fázích: `pods` a `{"pod": n}` ve scénářích místo `hold`/`engage`/`hold_time`, `foe_hp`/`foe_dmg`, polovina nepřátel (7–9, obrana 12), noví velitelé `palic`, `ostrostrelec`, `setnik` a `foe_skills` (Hejtman má Rozmach); schopnosti: Výzva 3×/15 s, Salva 3×/12 s, Úder 2×/15 s, Nájezd 1×, Požehnání 1×; `glory.extra_use_cost`/`extra_uses_max` pryč; Slib chudoby → Slib odříkání (+1 použití, kněz ho neléčí), Druhý nájezd = 2 použití; kněz `heal_combat` 10; `orders.melee_slots` 3, `wait_gap`, `body_gap`.
- 29.10.2026: `orders.focus_leash`, `focus_time`, `avoid_look`, `avoid_strength`, `hint_support`; Most +1 lapka, Lapkovská garda +1 lapka a +1 střelec, Brod a les +1 lapka u levého brodu (bez schopností vyhrával 40/40).
- 29.10.2026: rozkazy: `orders` místo `behaviors`, `behavior` u hrdinů pryč, `battle_modes` jen texty, `decided_ratio` do `morale`, `plural` u nepřátel, `objective` ze scénářů pryč, `auto_plan`. Balanc: Most +2 střelci (`auto_plan: hold`), Most pod palbou +3 lapkové, Tábor na Vraní skále +3 lapkové, Lesní ves −1 lapka ve 3. vlně, Brod a les `auto_plan: hold`.
- 29.10.2026: scénář Lesní ves (obrana, 3 vlny, chalupy), `battle_modes.obrana.leash` 7, `arrive`, `houses`; animace a zbraně hrdinů (`anim_attack`, `anim_ability`, `weapon`); akt 1: Lesní ves mezi bitvami, `regen` 0,3, tábor váha 2.
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
