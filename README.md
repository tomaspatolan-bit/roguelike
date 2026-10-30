# Rytíři

Rytířský roguelike pro Steam. Veď hrdiny svého rodu: každý má svou schopnost a osud, přísahy dávají sílu za cenu a kdo padne, odkáže je dalším.

Engine: Godot 4.7. Prototyp obsahuje jednu bitvu, **Most přes řeku**.

## Jak spustit

1. Otevři Godot, v Project Manageru klikni na **Import** a vyber soubor `project.godot` z této složky.
2. Po načtení stiskni **F5** (nebo tlačítko ▶ vpravo nahoře).

## Ovládání

| Akce | Ovládání |
| --- | --- |
| Rozestavit rytíře (jen obrana) | přetáhnout myší v modré zóně; puštění na jiného rytíře je prohodí |
| Výběr hrdiny | klik na hrdinu nebo jeho kartu (vybere jen jeho), **tažení obdélníku** levým tlačítkem přes víc hrdinů, **Ctrl+A** všichni; **Shift** přidá nebo ubere; klik na zem nebo **Esc** výběr zruší; druhý klik na kartu vybraného na něj posune výřez |
| Rozkaz (kdykoli, i v bitvě) | **pravé tlačítko** (provádí akce, kameru nehýbe): na zem = jdi tam (bez boje, tak hrdinu stáhneš z boje) a drž místo, na nepřítele = na celou jeho skupinu, na hrdinu = drž se ho |
| Zrušit rozkaz (drž místo) | **H** pro vybrané hrdiny |
| Co udělá pravé tlačítko | kruh pod kurzorem: červený = skupina nepřátel, modrý = ke spojenci, bílý = na místo |
| Cíl rozkazu | kruh v barvě hrdiny (v pauze u všech, v bitvě u vybraných) |
| Ohlášená schopnost velitele | červený kruh, který sílí; uhni, nebo velitele omrač (Nájezd) |
| Výběr bitvy | nahoře vlevo v úvodní pauze (obrana: v rozestavení) |
| Schopnost hrdiny | tlačítko na kartě hrdiny nebo klávesa v rámečku na tlačítku (**1–5**); cílená schopnost pak **pravé** (nebo levé) tlačítko na bojiště (**Esc** zruší) |
| Do boje! (po zlomení morálky nepřítele, jednou) | tlačítko nebo **F** |
| Pauza (čas stojí, rozkazy a schopnosti jdou dál) | tlačítko nebo **mezerník**, pokračovat **mezerník** nebo **Enter** |
| Posun kamery | **WASD**, šipky, nebo myš u okraje obrazovky (jen v hranicích mapy) |
| Úhel kamery | pevný podle mapy, otáčet nejde |
| Přiblížení | kolečko myši (v malém rozsahu) |

## Struktura

Viz `CLAUDE.md`. Data hry jsou v `data/`, logika bitvy v `scripts/sim/`, scéna v `scripts/battle/`, testy v `tests/`.
