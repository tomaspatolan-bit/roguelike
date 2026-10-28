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
| Trasa | tlačítko Trasa na kartě hrdiny, pak táhnout myší po zemi (Esc zruší) |
| Výběr bitvy | nahoře vlevo v rozestavení |
| Rozkaz přesunu (při signálu) | přetáhnout rytíře na místo, které má držet |
| Schopnost hrdiny | tlačítko na kartě hrdiny nebo **1–5**; cílená schopnost pak klik na bojiště (**Esc** zruší) |
| Do boje! (po zlomení morálky nepřítele, jednou) | tlačítko nebo **F** |
| Signál (zastaví čas) | tlačítko nebo **mezerník**, pokračovat **mezerník** nebo **Enter** |
| Posun kamery | **WASD**, šipky, nebo tažení **pravým tlačítkem** |
| Otáčení kamery | tažení **prostředním tlačítkem**, nebo **Q/E** |
| Přiblížení | kolečko myši |

## Struktura

Viz `CLAUDE.md`. Data hry jsou v `data/`, logika bitvy v `scripts/sim/`, scéna v `scripts/battle/`, testy v `tests/`.
