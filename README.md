# Rytíři

Rytířský roguelike pro Steam. Veď rytíře svého rodu: prapor nese sílu oddílu, přísahy sílu jednotlivců, a kdo padne, odkáže je dalším.

Engine: Godot 4.7. Prototyp obsahuje jednu bitvu, **Most přes řeku**.

## Jak spustit

1. Otevři Godot, v Project Manageru klikni na **Import** a vyber soubor `project.godot` z této složky.
2. Po načtení stiskni **F5** (nebo tlačítko ▶ vpravo nahoře).

## Ovládání

| Akce | Ovládání |
| --- | --- |
| Vybrat rytíře | klik na rytíře nebo jeho jméno v panelu |
| Rozestavit / poslat na místo (při signálu) | vybrat rytíře, pak klik na zem |
| Pokřiky praporu | tlačítka v panelu nebo **1**, **2** |
| Signál praporu (zastaví čas) | tlačítko nebo **S**, pokračovat **Enter** |
| Kamera | kolečko = přiblížení, prostřední tlačítko = otáčení, šipky = posun, Q/E = otočení |

## Struktura

Viz `CLAUDE.md`. Data hry jsou v `data/`, logika bitvy v `scripts/sim/`, scéna v `scripts/battle/`, testy v `tests/`.
