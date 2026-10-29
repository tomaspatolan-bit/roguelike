# Rytíři – instrukce pro Clauda

Rytířský roguelike pro Steam. Tým: **Tom** (ředitel, designér, tester, art direction, business) a **Claude** (kód, data, simulace balancu, 3D v Blenderu, dokumentace). Engine **Godot 4.7** (GDScript). Texty ve hře i dokumentace jsou česky, identifikátory v kódu anglicky.

## Na začátku každého sezení

Přečti `docs/stav.md` (co se teď dělá), `docs/plan.md` (kde jsme ve stepperu) a `docs/rozhodnuti.md` (co platí).

## Postup u každé změny (povinný)

1. **Najdi dotčené oblasti** v mapě níže a **přečti jejich kontextové soubory** v `docs/context/`. Vždy, i u malé změny.
2. **Zkontroluj požadavek proti invariantům a pilířům.** Když by ho porušil, **neprováděj ho**: řekni Tomovi, který invariant by se rozbil a proč, a navrhni alternativu. Tom rozhodne; když invariant změní, zapiš to do `docs/rozhodnuti.md`.
3. **Proveď změnu.** Pravidla hry patří do simulace, čísla do dat.
4. **Ověř:** `gdparse` a testy podle `docs/context/testy.md`. Neprošlé testy se nepushují.
5. **Aktualizuj ve stejném commitu:** kontextový soubor (invarianty, rozhraní, historie), `docs/stav.md`, případně `docs/plan.md` a deník rozhodnutí. Data v deníku rozhodnutí piš ve formátu DD.MM.RRRR. Stejný deník je i v projektu Roguelike v Claude (`claude/rozhodnuti.md`), drž je v souladu.
6. Nový nápad, který není v plánu, nezapracovávej rovnou: zapiš ho do `docs/napady.md`.

## Mapa oblastí → kontextové soubory

| Měníš | Přečti |
| --- | --- |
| `scripts/sim/` | `docs/context/simulace.md`, `docs/context/data.md` |
| `data/` | `docs/context/data.md`, `docs/context/simulace.md` |
| `scripts/battle/battle.gd`, `unit_view.gd`, `battlefield.gd`, `orbit_camera.gd`, `scenes/` | `docs/context/scena-bitvy.md`, `docs/context/simulace.md` (rozhraní) |
| `scripts/battle/battle_ui.gd` | `docs/context/ui.md`, `docs/context/scena-bitvy.md` |
| `art/`, Blender | `docs/context/grafika.md` |
| `scripts/run/`, `scenes/run/`, `data/akt_*.json`, `data/udalosti.json` | `docs/context/beh.md`, `docs/context/simulace.md` (rozhraní) |
| `tests/` | `docs/context/testy.md` |
| nová oblast | založ pro ni kontextový soubor podle vzoru ostatních a přidej ji sem |

## Ostatní dokumenty

- `docs/plan.md` – stepper fází a kroků s kritérii „hotovo, když“.
- `docs/playtesty.md` – Tomova zpětná vazba z hraní. Po každém playtestu z ní vyvoď úkoly.
- `docs/napady.md` – parkoviště nápadů.
- `docs/struktura-hry.md` – jak hráč postupuje hrou (běh, akty, patra, uzly), diagram.

## Pilíře (každá nová funkce musí aspoň jeden podporovat)

1. Velíš rodu: rod určuje, s kým a jak bojuješ; v bitvě ovládáš jeho hrdiny.
2. Přísaha má cenu: síla vždy za omezení.
3. Smrt má váhu: padlí zůstávají padlí a odkazují nástupcům.
4. Každý run je příběh rodu.

(Od 28.10.2026. Dřívější pilíř „Prapor je srdce oddílu“ je zrušený, viz `docs/rozhodnuti.md`.)

## Struktura

- `data/` – obsah jako JSON (jednotky, rod, scénáře). Nový obsah = nová data, ne nový kód.
- `scripts/sim/battle_sim.gd` – logika bitvy bez grafiky. Musí jít spustit v testech bez okna.
- `scripts/run/` – běh: `run_state.gd` (logika běhu bez grafiky), `act_map.gd` (generátor mapy aktu), `run_main.gd` (start, mapa, po bitvě, událost, tábor, kronika; hlavní scéna `scenes/run/run.tscn`), `map_view.gd`.
- `scripts/battle/` – scéna bitvy: `battle.gd` (fáze, vstup, propojení), `battle_ui.gd` (jen vykreslení, signály), `unit_view.gd`, `battlefield.gd`, `orbit_camera.gd`.
- `art/knight/` – rytíř z Blenderu (`SK_Knight.glb`), paletové textury, shader `knight_palette.gdshader` (řádek palety = barva role).
- `tests/` – `test_battle_sim.gd` (balanc a pravidla), `test_run.gd` (běh), `screenshot_battle.gd` a `screenshot_run.gd` (scény se načtou, odehrají se, uloží snímky), `passives_ingame.gd`.

## Konvence

- Souřadnice simulace: `Vector2(x, y)`, x doprava, y dopředu k nepříteli, 1 = 1 m. Ve 3D `Vector3(x, výška, -y)`. Model rytíře kouká po +Z, natočení `atan2(face.x, -face.y)`.
- Logika patří do simulace, ne do scény. Scéna jen čte stav simulace a posílá příkazy hráče.
- Skripty se navzájem načítají přes `preload` do konstanty (`const Sim := preload(...)`), ne přes `class_name`, aby fungovaly i v testech spuštěných přes `--script`.
- Pozor na odvození typu z Variantu: `var x: float = dict["a"]`, ne `var x := dict["a"]`.
- U pole s typem (`Array[Unit]`) neplň výsledkem `filter()`; použij smyčku.

## Testy

Claude nemá Godot v cloudu; testy běží na Tomově počítači přes Blender MCP. Cesty, příkazy a co který test hlídá: `docs/context/testy.md`. Syntaxi jde ověřit i v cloudu: `gdparse <soubor>` (balíček gdtoolkit).

## Git

Práce na větvích, Tom je slučuje do `main`. Commity česky, stručně, co a proč.
