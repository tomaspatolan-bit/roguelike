# Kontext: testy a ověřování

Soubory: `tests/`

## Jak testy běží
Claude nemá Godot v cloudu. Testy se pouštějí na Tomově počítači přes Blender MCP (Python v Blenderu spustí Godot):
- Godot: `C:\Users\sirko\Desktop\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`
- Pracovní kopie: `C:\Users\sirko\Documents\roguelike` (nejdřív `git pull`)
- Snímky: `C:\Users\sirko\Blender\Roguelike\godot_shots`

Postup: `git pull` → `--headless --import` → test simulace → test scény (otevře okno na ~1 min, spouštět jen když to Tomovi nevadí) → prohlédnout snímky.

## Co který test hlídá
| Test | Hlídá | Očekávaný výsledek |
| --- | --- | --- |
| `test_battle_sim.gd` | invarianty simulace a balanc | kód 0, „OK: všechny testy prošly“ |
| `screenshot_battle.gd` | scéna se načte, odehraje a skončí bez chyb | „Bitva skončila: win“, žádné ERROR v logu |

## Invarianty
1. **Před každým pushem** projde `gdparse` na změněných `.gd` souborech.
2. **Změna simulace nebo dat** = projde `test_battle_sim.gd`.
3. **Změna scény, UI nebo grafiky** = projde `screenshot_battle.gd` a snímky si prohlédnu.
4. **Nový invariant v kontextovém souboru** = ideálně i nový test, který ho hlídá.

## Historie významných změn
- 2026-10-28: založeno.
