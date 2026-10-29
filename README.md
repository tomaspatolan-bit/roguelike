# Rytíři

Rytířský roguelike pro Steam. Veď hrdiny svého rodu: každý má svou schopnost a osud, přísahy dávají sílu za cenu a kdo padne, odkáže je dalším.

Engine: Godot 4.7. Prototyp obsahuje jednu bitvu, **Most přes řeku**.

## Jak spustit

1. Otevři Godot, v Project Manageru klikni na **Import** a vyber soubor `project.godot` z této složky.
2. Po načtení stiskni **F5** (nebo tlačítko ▶ vpravo nahoře).

## Ovládání

| Akce | Ovládání |
| --- | --- |
| Rozestavit rytíře | přetáhnout myší v modré zóně; puštění na jiného rytíře je prohodí |
| Výběr hrdiny | klik na hrdinu nebo jeho kartu, nebo **tažení obdélníku** levým tlačítkem přes víc hrdinů; **Shift** přidá k výběru; klik na zem nebo **Esc** výběr zruší |
| Rozkaz (kdykoli, i v bitvě) | **pravé tlačítko**: na zem = jdi tam (bez boje, tak hrdinu stáhneš z boje) a drž místo, na nepřítele = na celou jeho skupinu, na hrdinu = drž se ho; nebo **Poslat** na kartě a klik |
| Rozkaz na místo v bitvě | přetáhnout hrdinu |
| Cíl rozkazu | kruh v barvě hrdiny (v pauze u všech, v bitvě u vybraných) |
| Výběr bitvy | nahoře vlevo v rozestavení |
| Schopnost hrdiny | tlačítko na kartě hrdiny nebo **1–5**; cílená schopnost pak klik na bojiště (**Esc** zruší) |
| Do boje! (po zlomení morálky nepřítele, jednou) | tlačítko nebo **F** |
| Pauza (čas stojí, rozkazy a schopnosti jdou dál) | tlačítko nebo **mezerník**, pokračovat **mezerník** nebo **Enter** |
| Posun kamery | **WASD**, šipky, nebo tažení **pravým tlačítkem** (klik pravým = rozkaz) |
| Otáčení kamery | tažení **prostředním tlačítkem**, nebo **Q/E** |
| Přiblížení | kolečko myši |

## Struktura

Viz `CLAUDE.md`. Data hry jsou v `data/`, logika bitvy v `scripts/sim/`, scéna v `scripts/battle/`, testy v `tests/`.
