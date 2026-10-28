# Rytíři

Rytířský roguelike pro Steam. Veď rytíře svého rodu: prapor nese sílu oddílu, přísahy sílu jednotlivců, a kdo padne, odkáže je dalším.

Engine: Godot 4.7. Prototyp obsahuje jednu bitvu, **Most přes řeku**.

## Jak spustit

1. Otevři Godot, v Project Manageru klikni na **Import** a vyber soubor `project.godot` z této složky.
2. Po načtení stiskni **F5** (nebo tlačítko ▶ vpravo nahoře).

## Ovládání

| Akce | Ovládání |
| --- | --- |
| Rozestavit rytíře | přetáhnout myší v modré zóně; puštění na jiného rytíře je prohodí |
| Rozkaz přesunu (při signálu) | přetáhnout rytíře na místo, které má držet |
| Pokřiky praporu | tlačítka v panelu nebo **1**, **2** |
| Signál praporu (zastaví čas) | tlačítko nebo **mezerník**, pokračovat **mezerník** nebo **Enter** |
| Posun kamery | **WASD**, šipky, nebo tažení **pravým tlačítkem** |
| Otáčení kamery | tažení **prostředním tlačítkem**, nebo **Q/E** |
| Přiblížení | kolečko myši |

## Struktura

Viz `CLAUDE.md`. Data hry jsou v `data/`, logika bitvy v `scripts/sim/`, scéna v `scripts/battle/`, testy v `tests/`.
