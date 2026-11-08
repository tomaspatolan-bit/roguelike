# Kontext: sandbox a galerie postav

Soubory: `scripts/sandbox/sandbox_panel.gd` (panel v bitvě), `scripts/sandbox/gallery.gd` (galerie postav), sandbox v `scripts/battle/battle.gd` (`sandbox`, `sandbox_state`, `_sandbox_*`), přepínače a příkazy v `scripts/sim/battle_sim.gd` (`setup.sandbox`, `sandbox_*`, `combo_setup`), tlačítko v `scripts/run/run_main.gd` (`open_sandbox`, `open_gallery`)
Hlídá: `tests/sandbox.gd` (s oknem), `_test_sandbox` v `tests/test_battle_sim.gd`

## Účel
Testovací nástroj pro Toma a Clauda (08.11.2026): vyzkoušet cokoli z bitvy bez procházení běhu a najít okrajové případy (schopnosti, komba, přísahy, pouta, znamení, nepřátelé, vzhled), a v galerii prohlédnout postavy a animace zblízka. Není to herní funkce, proto nemusí podporovat pilíř; v hlavním menu je jako „Sandbox“.

## Invarianty
1. **Sandbox nikdy neovlivní běh ani balanc.** Přepínače jsou jen v `setup.sandbox` (`god`, `free_uses`, `foes_idle`, `endless`, `no_foes`); běh je nikdy nenastaví a bez nich se simulace chová přesně jako dřív (testy balancu beze změny).
2. **Pravidla zůstávají v simulaci.** Panel jen posílá `request(druh, arg)`; `battle.gd` mění `setup` (pak `_sandbox_restart` = nová bitva) nebo volá příkazy simulace (`sandbox_spawn`, `sandbox_kill_foes`, `sandbox_heal`, `sandbox_refill`, `sandbox_break_morale`, `set_sandbox`). Žádný stav bitvy se nemění z panelu přímo.
3. **Co mění sestavu, restartuje bitvu:** mapa, vzhled, zdraví, vlastnosti, znamení, pouta, předvolba komba, bez nepřátel mapy. **Co je podvod, platí hned:** přepínače (kromě `no_foes`), vyléčit, doplnit schopnosti, zabít nepřátele, zlomit morálku, rychlost, přidání nepřátel klikem.
4. **Předvolba komba** (`Sim.combo_setup(units_data, setup, id_komba, typ_pouta)`): dá dvěma třídám schopnosti `a` a `b` komba a spojí je poutem na úrovni `bond_rules.combo_level`; jiná pouta té dvojice zmizí. Kombo je pak na Q nebo E. Platí pro všech 15 komb (test).
5. **Znamení v sandboxu** se počítají z dat stejně jako v běhu (`stats` zapečené do hrdinů, `extra_uses`); znamení jen pro běh (sláva, léčení po bitvě, nabídky) jsou v panelu vypnutá s „(run only)“.
6. **Nepřítel přidaný klikem** (`sandbox_spawn(typ, místo)`) je bdělý, má vlastní skupinu (dá se na něj poslat hrdina) a nevznikne ve vodě (vrací "").
7. **Nastavení drží celé sezení** (`battle.gd` `sandbox_state`: mapa, vzhled, znamení, vlastnosti, typ pouta, `setup`), i přes galerii a hlavní menu.
8. **Galerie** používá stejný `UnitView` jako bitva (co je vidět v galerii, ukáže i bitva): všichni hrdinové a všichni nepřátelé z dat na Mostě přes řeku, volná kamera (pravé nebo prostřední tlačítko otáčí, kolečko přibližuje, WASD posouvá), animace pro jednoho nebo všechny (`play_kind`, ragdoll přes `hp = 0`), opakování, rychlost, denní doba, obrys. Chybějící animace vypíše (`missing`).

## Rozhraní
- `battle.gd`: `sandbox` (nastaví `run_main` před přidáním), signály `left` (hlavní menu) a `gallery_requested`, `sb_panel`, `_sandbox_request(druh, arg)`, `_sandbox_spawn_at(bod_na_obrazovce)`, `_rebuild_field()`.
- Druhy požadavků: `scenario`, `look` ("", `off`, `noon`, `dawn`, `dusk`), `restart`, `gallery`, `menu`, `hp` [třída, podíl], `stat` [třída, vlastnost, podíl], `relic` [klíč, zapnuto], `bond_type`, `combo`, `bond_add` [a, b, typ, úroveň], `bond_remove` třída, `no_foes`, `spawn_mode` [zapnuto, typ, počet], `kill`, `morale`, `switch` [klíč, zapnuto], `heal`, `refill`, `speed`.
- `gallery.gd`: signál `back_pressed`, `_play(druh)`, `view_row`, `view_game`, `view_close`, `who`, `order`, `missing`.
- `unit_view.gd`: `play_kind(druh, rychlost)`, `oneshot_playing()`.

## Úskalí
- Formátování `%g` Godot nezná (chyba „unsupported format character“), čísla rychlosti přes `str()`.
- `_group_title` hledá členy v `units`: nového nepřítele nejdřív přidat do `units`, pak založit skupinu.
- Dlouhé položky v `OptionButton` (názvy komb) rozšiřují panel: `fit_to_longest_item = false`, `clip_text`.

## Historie významných změn
- 08.11.2026: sandbox a galerie postav (Tom: „sandbox, kde bych udělal úplně vše, i komba, schopnosti, abychom mohli vychytat edge casy“).
