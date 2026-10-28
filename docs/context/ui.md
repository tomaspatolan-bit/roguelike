# Kontext: rozhraní

Soubory: `scripts/battle/battle_ui.gd`
Hlídá: `tests/screenshot_battle.gd` (snímky panelu)

## Účel
Vykreslit stav a poslat úmysly hráče signálem. Nerozhoduje o pravidlech.

## Invarianty
1. **Žádná herní logika.** UI nemění simulaci, jen emituje signály, které zpracuje `battle.gd`.
2. **Signály:** `knight_clicked`, `posture_changed`, `signals_count_changed`, `start_pressed`, `shout_pressed`, `signal_pressed`, `resume_pressed`, `speed_changed`, `continue_pressed`, `retry_pressed`, `redeploy_pressed`.
3. **Panel se přestavuje jen při změně stavu** (`show_deploy`, `show_battle`). Co se mění plynule, aktualizuje `update_dynamic` (každých 0,1 s) a `update_hp_bars` (každý snímek). Přestavba panelu každý snímek je zakázaná.
4. **Hráč musí vždy vidět:** slávu, dostupnost pokřiků, zbývající signály, stav praporu, stav úkolu, zda čas stojí.
5. **Texty česky,** krátce, sloveso na začátku tlačítka. Zkratky kláves uvedené na tlačítkách odpovídají `battle.gd`.
6. **Font:** systémový (Segoe UI na Windows), musí umět českou diakritiku.

## Úskalí
- Kořenový `Control` má `mouse_filter = IGNORE`, jinak spolkne kliky do scény.
- Místní proměnná se nesmí jmenovat jako metoda `CanvasLayer` (`hide`, `show`).

## Historie významných změn
- 2026-10-28: založeno.
