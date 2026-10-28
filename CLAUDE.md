# Rytíři – instrukce pro Clauda

Rytířský roguelike pro Steam. Tým: **Tom** (ředitel, designér, tester, art direction, business) a **Claude** (kód, data, simulace balancu, 3D v Blenderu, dokumentace). Engine **Godot 4.7** (GDScript). Texty ve hře i dokumentace jsou česky, identifikátory v kódu anglicky.

## Na začátku a na konci každého sezení

1. Přečti `docs/stav.md` (co se teď dělá) a `docs/rozhodnuti.md` (co platí).
2. Na konci aktualizuj `docs/stav.md`; každé nové rozhodnutí zapiš do `docs/rozhodnuti.md` (nejnovější nahoře, s datem a důvodem). Stejný deník je i v projektu Roguelike v Claude (`claude/rozhodnuti.md`), drž je v souladu.

## Pilíře (každá nová funkce musí aspoň jeden podporovat)

1. Velíš rodu, ne vojákovi.
2. Prapor je srdce oddílu.
3. Přísaha má cenu.
4. Každý run je příběh rodu.

## Struktura

- `data/` – obsah jako JSON (jednotky, rod, scénáře). Nový obsah = nová data, ne nový kód.
- `scripts/sim/battle_sim.gd` – logika bitvy bez grafiky. Musí jít spustit v testech bez okna.
- `scripts/battle/` – scéna bitvy: `battle.gd` (fáze, vstup, propojení), `battle_ui.gd` (jen vykreslení, signály), `unit_view.gd`, `battlefield.gd`, `orbit_camera.gd`.
- `art/knight/` – rytíř z Blenderu (`SK_Knight.glb`), paletové textury, shader `knight_palette.gdshader` (řádek palety = barva role).
- `tests/` – `test_battle_sim.gd` (balanc a pravidla), `screenshot_battle.gd` (scéna se načte, odehraje se, uloží snímky).

## Konvence

- Souřadnice simulace: `Vector2(x, y)`, x doprava, y dopředu k nepříteli, 1 = 1 m. Ve 3D `Vector3(x, výška, -y)`. Model rytíře kouká po +Z, natočení `atan2(face.x, -face.y)`.
- Logika patří do simulace, ne do scény. Scéna jen čte stav simulace a posílá příkazy hráče.
- Skripty se navzájem načítají přes `preload` do konstanty (`const Sim := preload(...)`), ne přes `class_name`, aby fungovaly i v testech spuštěných přes `--script`.
- Pozor na odvození typu z Variantu: `var x: float = dict["a"]`, ne `var x := dict["a"]`.
- U pole s typem (`Array[Unit]`) neplň výsledkem `filter()`; použij smyčku.

## Testy

Claude nemá Godot v cloudu (stahování blokuje síťová politika). Testy se pouštějí na Tomově počítači přes Blender MCP (Python v Blenderu volá Godot):

- Godot: `C:\Users\sirko\Desktop\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`
- Pracovní kopie projektu: `C:\Users\sirko\Documents\roguelike`
- Import: `godot --headless --path . --import`
- Simulace: `godot --headless --path . --script res://tests/test_battle_sim.gd` (kód 0 = prošlo)
- Scéna a snímky: `godot --path . --script res://tests/screenshot_battle.gd -- C:\Users\sirko\Blender\Roguelike\godot_shots`

Syntaxi jde ověřit i v cloudu: `gdparse <soubor>` (balíček gdtoolkit).

## Git

Práce na větvích, Tom je slučuje do `main`. Commity česky, stručně, co a proč.
