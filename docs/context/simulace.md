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
5. **Řeka jde přejít jen po mostě** (`|x| <= bridge_half_width`). Jednotka nikdy neskončí ve vodě.
6. **Prapor:** bez živého nositele nefunguje aura, pokřiky ani signály. Padlý prapor někdo zvedne (přednostně postoj „Chránit prapor“). Smrt nositele vždy vyvolá událost `autopause`.
   - **Nositele určuje hráč jen v rozestavení** (`set_bearer`, `can_set_bearer` platí jen při `t == 0`). Během bitvy se prapor nepředává; jediná výjimka je zvednutí padlého praporu.
   - **Co prapor dělá, určuje třída nositele** (data `banner` u třídy, `banner_effects()`): poloměr aury, bonus k útoku, menší zranění, rychlost, léčení v auře. `aura_radius` se přepočítá při každé změně nositele.
   - **Nositel nemůže mít postoj „Chránit prapor“** (`bearer_forbids`). Kdo se stane nositelem s tímto postojem (volbou nebo zvednutím), přejde na „Držet pozici“.
7. **Přísahy** (data `oaths` v rodu): bonus jen dokud `oath_kept`. Přísaha může **zakázat postoje** (`forbidden_postures`, `set_posture` pak vrací false a nic nemění) a **přejmenovat je** (`posture_names`). `no_retreat` = rytíř nikdy sám necouvne: v postoji `drzet` („Stát pevně“) nechodí za nepřítelem ani se nevrací, jeho místo se posouvá s ním; nezvedá padlý prapor. Porušení stojí slávu podle dat a je nevratné. V kódu simulace nesmí být natvrdo klíč rytíře (`"tank"`), přísahy se hledají v datech.
8. **Žádný pat:** každá bitva musí skončit. Nepřátelští střelci postupují na 60 % dostřelu právě proto.
9. **Balanc scénáře Most přes řeku:** bez pokřiků vyhraje nejvýš čtvrtina bitev, s pokřiky aspoň tři čtvrtiny, bitva trvá 30–180 s.
10. **Nikdo nestojí bez práce:** rytíř v postoji `drzet` bez vlastního cíle jde pomoct nejbližšímu rytíři, který bojoval v posledních `behavior.help_window` s (útok nebo zásah), a jeho místo se posouvá s ním. Výjimka: `no_retreat` („Stát pevně“) stojí dál. Útočný postoj a Chránit prapor tohle nepotřebují.
11. **Morálka nepřátel:** když nepřítel ztratí podíl `break_losses` jednotek (padlí i uprchlí; data `morale`, scénář `enemy_morale`), zlomí se. Jednotka s `on_break: "flee"` prchá k `flee_y` a po dosažení okraje má `fled = true` a `hp = 0` (není to smrt: žádná událost `death`, žádná sláva). `"desperate"` útočí s bonusem `desperate_dmg_bonus`. Zlomení se stane jen jednou.
12. **Dobojování:** po zlomení morálky smí hráč jednou dát povel Do boje! (`can_charge`, `charge_all`), všichni rytíři pak jednají jako v Útočném postoji (i tank se Stát pevně; útok vpřed není ústup). Pojistka: když síla strany (`power()`) klesne pod `decided_ratio` síly druhé, nastaví se `decided` a rytíři dobojují sami; ve prospěch rytířů jen dokud morálka nepřítele není zlomená (potom rozhoduje hráč). Postoj rytíře se v datech nemění, jen chování.

## Rozhraní, na které spoléhá scéna a testy
- Stav: `units`, `projectiles`, `glory`, `fx`, `signals`, `bearer_id`, `aura_radius`, `foes_broken`, `charging`, `decided`, `banner_pos`, `banner_down`, `picker_id`, `oath_kept`, `task_ok`, `over` ("", "win", "lose"), `t`, `events`.
- Setup: `{"signals", "pos", "posture", "bearer"}` (`default_setup` bere nositele ze scénáře).
- Dotazy: `knights()`, `living(side)`, `by_id()`, `aura_center()`, `in_aura()`, `banner_effects()`, `can_set_bearer()`, `can_shout()`, `can_signal()`, `is_retreat()`, `oath_of()`, `has_oath()`, `posture_allowed()`, `oath_forbids()`, `bearer_forbids()`, `posture_name()`, `can_charge()`, `power()`.
- Příkazy: `step(dt)`, `shout()`, `use_signal()`, `order_move()`, `set_bearer()` (vrací bool), `set_posture()` (vrací bool), `charge_all()` (vrací bool), `break_oath()`.
- Události (`events`, scéna je po zpracování maže): `log`, `autopause`, `death`, `fled`, `decided`, `heal`, `shoot`, `end`.
- Jednotka: `fled`, `fleeing`, `desperate`, `combat_t`.
Změna názvu nebo významu čehokoli z tohoto seznamu = upravit i `battle.gd`, `battle_ui.gd` a testy.

## Úskalí
- `Array[Unit]` neplň výsledkem `filter()`, použij smyčku.
- Typ z `Dictionary` vždy explicitně: `var x: float = d["a"]`.
- Krok simulace je pevný (1/60 s ze scény, 1/30 s v testu). Logika nesmí záviset na velikosti kroku víc, než je nutné.

## Historie významných změn
- 28.10.2026: morálka nepřátel (střelci prchají, pěšáci zoufale dobojují), povel Do boje!, pojistka dobojování. Práh zlomení 0,7 (při 0,6 vyhrávala i bitva bez pokřiků). Balanc 0/40 a 40/40, bitva 37 s místo 64 s.
- 28.10.2026: pravidlo „nikdo nestojí bez práce“ (pomoc bojujícímu spolubojovníkovi, `combat_t`). Balanc 0/40 a 40/40, přeživší rytíři 4,0 místo 3,0.
- 28.10.2026: nositele praporu volí hráč v rozestavení, prapor se nepředává, efekt praporu podle třídy nositele, nositel nesmí Chránit prapor. Asasín cílí přednostně na střelce (`target_priority`). Balanc: 0/40 bez pokřiků, 40/40 s pokřiky.
- 2026-10-28: přísahy určují povolené postoje, „Stát pevně“ pro `no_retreat` (po playtestu). Balanc beze změny: 0/40 bez pokřiků, 40/40 s pokřiky.
- 2026-10-28: přenesena z webového dema, čísla z dema beze změny.
