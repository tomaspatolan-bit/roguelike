# Kontext: simulace bitvy

Soubory: `scripts/sim/battle_sim.gd`
Hlídá: `tests/test_battle_sim.gd`

## Účel
Celá pravidla bitvy bez grafiky. Scéna i testy ji jen volají. Když jde něco spočítat, patří to sem, ne do scény.

## Invarianty (nesmí se rozbít)
1. **Žádná závislost na scéně.** Žádné `Node`, `get_tree()`, vstup ani vykreslování. Musí jít spustit v testu bez okna.
2. **Čísla pocházejí z dat** (`data/*.json`). V kódu jsou jen klíče, ne hodnoty.
3. **Deterministická se seedem**: stejný seed a stejné vstupy = stejný průběh.
4. **Souřadnice:** `Vector2(x, y)`, y dopředu k nepříteli, 1 = 1 m.
5. **Řeku jde přejít jen přechody** (`river.crossings`: most, brod, lávka; `_crossing_at`, `_best_crossing`). Jednotka nikdy neskončí ve vodě. Navigace volí přechod s nejkratší cestou. Terén mění rychlost (`terrain_speed`): brod a lávka podle `speed`, les podle `speed`, stezka lesem a jednotky s `ignores: ["les"]` bez zpomalení. Když krok vede do vody, jednotka zkusí sklouznout podél břehu, aby se nezasekla.
6. **Žádné bonusy pro celý oddíl.** Žádná aura, pokřiky ani nositel praporu (zrušeno 28.10.2026). Každý efekt v bitvě má jednoho původce: hrdinu, jeho schopnost nebo přísahu.
7. **Výchozí chování hrdinů** podle třídy (`behavior`, čísla v `behaviors`): `frontline` (tank: napadne nepřítele u sebe nebo u spojence, jinak stojí kus před oddílem), `healer` (kněz: drží se za bojujícím, léčí), `archer` (střílí na dostřel, před blízkým nepřítelem couvne, bez cíle jde k bojujícímu), `rider` (výpad na nepřítele do `engage` m od středu oddílu a návrat), `assassin` (střelci, jinak nejslabší). Nikdo nestojí bez práce.
8. **Schopnosti** (`abilities`, `use_ability`, `can_use_ability`, `ability_target_problem`): každý hrdina má jednu, s `uses` za bitvu. Bez použití se platí slávou (`house.glory.extra_use_cost`). Cíl `none` / `point` / `enemy`, dosah `range`; neplatný cíl nic nemění. Vyzva (přitáhne útoky do `radius`, menší zranění), Požehnání (léčí v `radius`), Salva (`arrows` × `dmg` náhodně mezi nepřátele v `radius`), Nájezd (jízda k bodu, každého v cestě zasáhne a omráčí; ne do vody), Úder ze stínu (skok za nepřítele, `mult` × útok). `ability_hint` je jen rada pro testy a automatické hraní.
9. **Sláva** je společná rezerva rodu: plní se činy hrdinů (zásah, zabití, přísaha v boji) a u hrdiny se zapisuje `glory_earned` (kronika).
10. **Přísahy** (data `oaths` v rodu): bonus jen dokud `oath_kept`. `no_retreat` = hrdina nikdy sám necouvne: nejde za nepřítelem dozadu, bez nepřítele stojí, `_go` ho nepustí tam, kde by byl dál od nepřítele; trasa ani rozkaz nesmí vést zpět (rozkaz zpět přísahu poruší, ptá se scéna). Porušení stojí slávu podle dat a je nevratné. V kódu simulace nesmí být natvrdo klíč hrdiny.
11. **Žádný pat:** každá bitva musí skončit. Nepřátelští střelci postupují na 60 % dostřelu, nepřátelé na pozici mají `hold_time`.
12. **Balanc každého scénáře v `index.json`:** bez schopností vyhraje nejvýš čtvrtina bitev, se schopnostmi (automatické hraní podle `ability_hint`) aspoň tři čtvrtiny, bitva trvá 30–180 s.
13. **Morálka nepřátel:** po ztrátě podílu `break_losses` jednotek (padlí i uprchlí) se nepřítel zlomí jednou: `flee` prchá k `flee_y` (`fled`, `hp = 0`, ne smrt), `desperate` útočí silněji. Vlastnosti (`traits`): `never_breaks`, `on_break`, `desperate_dmg_bonus`.
14. **Dobojování:** po zlomení morálky smí hráč jednou dát Do boje! (`can_charge`, `charge_all`), všichni hrdinové útočí. Pojistka `decided` (síla pod `decided_ratio`), ve prospěch hrdinů jen dokud morálka není zlomená.
15. **Trasy** (`set_route`, jen při `t == 0`, nejvýš 4 body, body ve vodě se zahazují): na trase hrdina bojuje jen s nepřítelem do `reach + 1 m`, na konci se vrátí k výchozímu chování. Rozkaz přesunu (`order_move`, při signálu) = hrdina drží místo (`holding`), dokud nepřijde Do boje! nebo `release`. Rozkaz, Do boje!, rozhodnutá bitva a Nájezd trasu ruší.
16. **Nepřátelé** cílí nejbližšího hrdinu; kdo je v dosahu Výzvy, útočí na tanka. Omráčený nepřítel nic nedělá. Nepřítel na pozici (`hold`): střelec střílí z místa, pěšák vyrazí jen do `engage` m; zasažený pěšák uvolní skupinu do 5 m.

## Rozhraní, na které spoléhá scéna a testy
- Stav: `units`, `projectiles`, `glory`, `signals`, `signals_used`, `abilities_used`, `foes_broken`, `charging`, `decided`, `oath_kept`, `task_ok`, `over` ("", "win", "lose"), `t`, `events`.
- Setup: `{"signals", "pos", "routes"}`.
- Dotazy: `knights()`, `living(side)`, `by_id()`, `can_signal()`, `is_retreat()`, `oath_of()`, `has_oath()`, `behavior_name()`, `behavior_desc()`, `ability_of()`, `ability_cost()`, `can_use_ability()`, `ability_target()`, `ability_target_problem()`, `ability_hint()`, `can_charge()`, `power()`, `terrain_speed()`, `route_problem()`, `on_route()`, `has_trait()`; statické `load_data(klíč)`, `scenario_list()`, `default_setup()`, `simplify_route()`.
- Příkazy: `step(dt)`, `use_signal()`, `use_ability(id, cíl)` (vrací bool), `order_move()`, `release()`, `charge_all()`, `set_route()`, `break_oath()`.
- Události (`events`, scéna je po zpracování maže): `log`, `death`, `fled`, `decided`, `heal`, `shoot`, `ability` (`id`, `key`, `pos`), `end`.
- Jednotka: `behavior`, `ability`, `uses`, `holding`, `taunt_t`, `stun_t`, `dashing`, `glory_earned`, `fled`, `fleeing`, `desperate`, `combat_t`, `route`, `route_i`, `hold`, `mounted`, `vs_mounted`, `ignores`, `traits`.
Změna názvu nebo významu čehokoli z tohoto seznamu = upravit i `battle.gd`, `battle_ui.gd` a testy.

## Úskalí
- `Array[Unit]` neplň výsledkem `filter()`, použij smyčku.
- Typ z `Dictionary` vždy explicitně: `var x: float = d["a"]`.
- Krok simulace je pevný (1/60 s ze scény, 1/30 s v testu). Logika nesmí záviset na velikosti kroku víc, než je nutné.

## Historie významných změn
- 28.10.2026: přestavba na hrdiny: zrušen prapor, aura, pokřiky a postoje; výchozí chování tříd, schopnosti s použitími, sláva jako použití navíc, rozkaz přesunu drží místo. Balanc: BALANC_TBD.
- 28.10.2026: postoje podle třídy (Výpad, Záloha/Číhat, Léčit frontu…), nepřátelé držící pozici, klouzání u břehu (oprava zaseknutí). Most 0/40 a 40/40 (přeživší 2,0), Brod 0/40 a 40/40.
- 28.10.2026: obecný terén (přechody, lesy), trasy rytířů, kopiníci a vlastnosti nepřátel, scénář Brod a les. Most beze změny: 0/40 a 40/40.
- 28.10.2026: morálka nepřátel (střelci prchají, pěšáci zoufale dobojují), povel Do boje!, pojistka dobojování. Práh zlomení 0,7 (při 0,6 vyhrávala i bitva bez pokřiků). Balanc 0/40 a 40/40, bitva 37 s místo 64 s.
- 28.10.2026: pravidlo „nikdo nestojí bez práce“ (pomoc bojujícímu spolubojovníkovi, `combat_t`). Balanc 0/40 a 40/40, přeživší rytíři 4,0 místo 3,0.
- 28.10.2026: nositele praporu volí hráč v rozestavení, prapor se nepředává, efekt praporu podle třídy nositele, nositel nesmí Chránit prapor. Asasín cílí přednostně na střelce (`target_priority`). Balanc: 0/40 bez pokřiků, 40/40 s pokřiky.
- 2026-10-28: přísahy určují povolené postoje, „Stát pevně“ pro `no_retreat` (po playtestu). Balanc beze změny: 0/40 bez pokřiků, 40/40 s pokřiky.
- 2026-10-28: přenesena z webového dema, čísla z dema beze změny.
