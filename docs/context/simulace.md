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
7. **Přísaha tanka:** bonus jen dokud `oath_kept`. Porušení stojí slávu podle dat a je nevratné.
8. **Žádný pat:** každá bitva musí skončit. Nepřátelští střelci postupují na 60 % dostřelu právě proto.
9. **Balanc scénáře Most přes řeku:** bez pokřiků vyhraje nejvýš čtvrtina bitev, s pokřiky aspoň tři čtvrtiny, bitva trvá 30–180 s.

## Rozhraní, na které spoléhá scéna a testy
- Stav: `units`, `projectiles`, `glory`, `fx`, `signals`, `bearer_id`, `banner_pos`, `banner_down`, `oath_kept`, `task_ok`, `over` ("", "win", "lose"), `t`, `events`.
- Dotazy: `knights()`, `living(side)`, `by_id()`, `aura_center()`, `in_aura()`, `can_shout()`, `can_signal()`, `is_retreat()`.
- Příkazy: `step(dt)`, `shout()`, `use_signal()`, `order_move()`, `set_posture()`, `break_oath()`.
- Události (`events`, scéna je po zpracování maže): `log`, `autopause`, `death`, `heal`, `shoot`, `end`.
Změna názvu nebo významu čehokoli z tohoto seznamu = upravit i `battle.gd`, `battle_ui.gd` a testy.

## Úskalí
- `Array[Unit]` neplň výsledkem `filter()`, použij smyčku.
- Typ z `Dictionary` vždy explicitně: `var x: float = d["a"]`.
- Krok simulace je pevný (1/60 s ze scény, 1/30 s v testu). Logika nesmí záviset na velikosti kroku víc, než je nutné.

## Historie významných změn
- 2026-10-28: přenesena z webového dema, čísla z dema beze změny.
