# Kontext: scéna bitvy

Soubory: `scenes/battle/battle.tscn`, `scripts/battle/battle.gd`, `unit_view.gd`, `battlefield.gd`, `orbit_camera.gd`, `art/knight/knight_palette.gdshader`
Hlídá: `tests/screenshot_battle.gd` (načtení, odehrání, snímky)

## Účel
Zobrazit simulaci a předat jí příkazy hráče. Žádná pravidla hry.

## Invarianty
1. **Scéna jen čte stav simulace a volá její příkazy.** Nové pravidlo patří do simulace.
2. **Fáze:** rozestavení → bitva ⇄ signál → konec. V rozestavení a při signálu čas stojí. Rozkazy přesunu jen při signálu, rozestavení jen v zóně. Schopnosti jdou v bitvě i při signálu.
3. **Pauza (`paused`)** zastaví simulaci. Zapíná ji otevřený dialog přísahy; vždy musí jít zrušit.
4. **Pevný krok 1/60 s**, nejvýš 8 kroků na snímek. Rychlost 2× = víc kroků, ne delší krok.
5. **Převod souřadnic** `Vector3(x, výška, -y)`, natočení `atan2(face.x, -face.y)` (model kouká po +Z).
6. **Hrdina z GLB:** očekává `MeshInstance3D` a `AnimationPlayer` s `A_Knight_Idle` a `A_Knight_Walk`. Barva role přes `role_row` v shaderu.
7. **Ovládání:** 1–5 schopnost hrdiny podle pořadí karet · F Do boje! · mezerník signál / pokračovat · Enter pokračovat · Esc zruší cílení nebo kreslení trasy · kamera: WASD/šipky a pravé tlačítko = posun, prostřední tlačítko nebo Q/E = otáčení, kolečko = přiblížení. Změna = upravit README a popisky v UI.
8. **Výběr a přesun hrdinů:** podle postavy na obrazovce (úsečka nohy–hlava, `PICK_PX` = 30 px). Drag & drop v rozestavení (prohození puštěním), při signálu rozkaz přesunu s kontrolou přísahy.
9. **Cílení schopnosti:** `_aim_id` = hrdina, jehož schopnost se cílí; kruh pod kurzorem v poloměru schopnosti (červený mimo dosah), klik pošle cíl do `sim.use_ability`, neplatný cíl ukáže `flash_hint`. Nepřítel se vybírá podle postavy na obrazovce (`_pick_foe`). Událost `ability` = krátký kruh efektu.
10. **Přísahy se ve scéně ověřují přes simulaci** (`has_oath`, `is_retreat`), nikdy podle klíče hrdiny.
11. **Rozhodnutá bitva** (událost `decided`) přepne rychlost aspoň na 2×. Uprchlá jednotka (`fled`) je skrytá.
12. **Výběr bitvy** jen v rozestavení (`_load_scenario`, bojiště v `field_root`). **Trasy:** Kreslit trasu → tažení po zemi → zjednodušení → `sim.set_route`; Esc zruší; trasy žlutě se šipkami.

## Úskalí
- Proměnná s typem `Node3D` nezná metody skriptu: použij typ skriptu (`var v := UnitView.new()`).
- Víceřádkové lambdy jako argumenty funkce raději ulož nejdřív do proměnné.
- Limity testů počítej v čase bitvy, ne ve snímcích (monitor může mít 144 Hz).

## Historie významných změn
- 28.10.2026: režim běhu (`run` nastaví `run_main.gd`): setup z běhu, bez výběru bitvy a zkoušení pasivek, signál `battle_done(result)`. Vůdce nepřátel je větší (×1,3). Hlavní scéna hry je `scenes/run/run.tscn`; `battle.tscn` jde dál spustit samostatně (volná bitva).
- 28.10.2026: přestavba na hrdiny: pryč aura a prapor; schopnosti klávesami 1–5 a z karet, cílení kruhem, efekty schopností.
- 28.10.2026: výběr bitvy, kreslení a zobrazení tras, bojiště z obecného terénu (most, brody, lávka, les), kopiník.
- 28.10.2026: povel Do boje! (F), rozhodnutá bitva se zrychlí na 2×, uprchlí nepřátelé zmizí.
- 28.10.2026: volba nositele praporu, kruh aury podle nositele.
- 2026-10-28: po playtestu drag & drop, výběr podle obrazovky, kamera WASD a pravé tlačítko, signál na mezerníku.
- 2026-10-28: založeno. Bez mlhy, ACES tonemap, kontrast 1.12.
