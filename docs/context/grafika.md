# Kontext: grafika a 3D pipeline

Soubory: `art/`; zdroj v Blenderu `C:\Users\sirko\Documents\Knight.blend`, exporty v `C:\Users\sirko\Blender\Roguelike\`
Hlídá: `tests/screenshot_battle.gd` (model se načte a animuje)

## Účel
Modely, textury a shadery hry a cesta z Blenderu do Godotu.

## Invarianty
1. **Měřítko 1 jednotka = 1 m**, rytíř ~1,87 m, pivot u chodidel, kouká po +Z v Godotu (−Y v Blenderu).
2. **Rytíř = jedna síť, jeden materiál, paletová textura** 128×64 px, buňky 8×8 px. Řádek 0 je základ; role jsou další řádky (viz `data.md`).
3. **Kostra s názvy kostí podle UE5 Mannequina** (27 kostí, `cape_01–03`, `weapon_scabbard`). Přejmenování kostí rozbije animace.
4. **Animace** se jmenují `A_Knight_<Činnost>`; scéna používá `A_Knight_Idle` a `A_Knight_Walk`.
5. **Rozpočet:** rytíř ~5 400 trojúhelníků (LOD1 ~2 200). Nová postava se drží podobně.
6. **Kolekce v Blenderu:** `KNIGHT_game` (herní), `KN_game_parts` (zdrojové díly), `KNIGHT_hero` (prezentační), `PRESENTATION`. Herní export jen z `KNIGHT_game`.
7. **Evidence AI obsahu pro Steam:** každý asset vytvořený AI zapiš níže.
8. Godot si z GLB vytahuje kopie palety (`SK_Knight_T_Knight_Palette_*`); jsou v `.gitignore`, hra používá vlastní materiál s `art/knight/T_Knight_Palette_*.png`.

## Evidence AI obsahu
| Asset | Vznik | Poznámka |
| --- | --- | --- |
| `SK_Knight.glb` | Claude, skriptem v Blenderu | herní rytíř |
| `T_Knight_Palette_*.png` | Claude, vygenerováno skriptem | paleta barev |
| bojiště, nepřátelé (i kopiník, brody, lávka, les) | Claude, primitiva v kódu | zástupná grafika |

## Historie významných změn
- 28.10.2026: řádek palety 5 přebarven na fialovou šeď pro asasína (byl praporečník).
- 2026-10-26: herní rytíř, kostra, paleta, export.
