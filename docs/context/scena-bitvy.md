# Kontext: scéna bitvy

Soubory: `scenes/battle/battle.tscn`, `scripts/battle/battle.gd`, `unit_view.gd`, `battlefield.gd`, `orbit_camera.gd`, `art/knight/knight_palette.gdshader`
Hlídá: `tests/screenshot_battle.gd` (načtení, odehrání, snímky)

## Účel
Zobrazit simulaci a předat jí příkazy hráče. Žádná pravidla hry.

## Invarianty
1. **Scéna jen čte stav simulace a volá její příkazy.** Nové pravidlo patří do simulace.
2. **Fáze:** rozestavení → bitva ⇄ signál → konec. V rozestavení a při signálu čas stojí. Rozkazy přesunu jen při signálu, rozestavení jen v zóně.
3. **Pauza (`paused`)** zastaví simulaci a pokřiky. Zapíná ji smrt nositele praporu a otevřený dialog přísahy; vždy musí jít zrušit (Enter, tlačítko, odpověď v dialogu).
4. **Pevný krok 1/60 s**, nejvýš 8 kroků na snímek. Rychlost 2× = víc kroků, ne delší krok.
5. **Převod souřadnic** `Vector3(x, výška, -y)`, natočení `atan2(face.x, -face.y)` (model kouká po +Z).
6. **Rytíř z GLB:** očekává `MeshInstance3D` a `AnimationPlayer` s animacemi `A_Knight_Idle` a `A_Knight_Walk`. Barva role přes `role_row` v shaderu, materiál je na jednotku vlastní (kvůli záblesku zásahu).
7. **Ovládání:** 1, 2 pokřiky · mezerník signál / pokračovat · Enter pokračovat · kamera: WASD nebo šipky a tažení pravým tlačítkem = posun, prostřední tlačítko nebo Q/E = otáčení, kolečko = přiblížení. Klávesa S patří kameře, ne signálu. Změna = upravit README a popisky v UI.
8. **Výběr a přesun rytířů:** rytíř se vybírá podle své postavy na obrazovce (úsečka nohy–hlava, tolerance `PICK_PX` = 30 px), ne podle bodu na zemi. Drag & drop: v rozestavení přesun v zóně a puštění na jiného rytíře je prohodí; při signálu rozkaz přesunu s kontrolou přísahy. Pohyb a puštění myši se čtou v `_input`, aby táhnutí neuvízlo nad panelem. Klik na rytíře a pak na zem funguje dál.
9. **Přísahy se ve scéně ověřují přes simulaci** (`posture_allowed`, `has_oath`, `is_retreat`), nikdy podle klíče rytíře.

## Úskalí
- Proměnná s typem `Node3D` nezná metody skriptu: použij typ skriptu (`var v := UnitView.new()`).
- Víceřádkové lambdy jako argumenty funkce raději ulož nejdřív do proměnné.
- Limity testů počítej v čase bitvy, ne ve snímcích (monitor může mít 144 Hz).

## Historie významných změn
- 2026-10-28: po playtestu drag & drop, výběr podle obrazovky, kamera WASD a pravé tlačítko, signál na mezerníku.
- 2026-10-28: založeno. Bez mlhy, ACES tonemap, kontrast 1.12.
