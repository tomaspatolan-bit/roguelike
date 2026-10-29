# Kontext: scéna bitvy

Soubory: `scenes/battle/battle.tscn`, `scripts/battle/battle.gd`, `unit_view.gd`, `battlefield.gd`, `orbit_camera.gd`, `art/knight/knight_palette.gdshader`
Hlídá: `tests/screenshot_battle.gd` (načtení, odehrání, snímky)

## Účel
Zobrazit simulaci a předat jí příkazy hráče. Žádná pravidla hry.

## Invarianty
1. **Scéna jen čte stav simulace a volá její příkazy.** Nové pravidlo patří do simulace.
2. **Fáze:** rozestavení → bitva ⇄ signál → konec. V rozestavení a při signálu čas stojí. Rozkazy hrdinům v rozestavení a při signálu (v bitvě jinak ne), rozestavení jen v zóně. Začít bitvu se zeptá, když někdo nemá rozkaz (`_try_start`, `ui.ask_start`). Schopnosti jdou v bitvě i při signálu.
3. **Pauza (`paused`)** zastaví simulaci. Zapíná ji otevřený dialog přísahy; vždy musí jít zrušit.
4. **Pevný krok 1/60 s**, nejvýš 8 kroků na snímek. Rychlost 2× = víc kroků, ne delší krok.
5. **Převod souřadnic** `Vector3(x, výška, -y)`, natočení `atan2(face.x, -face.y)` (model kouká po +Z).
6. **Hrdina z GLB:** očekává `MeshInstance3D`, `Skeleton3D` (kost `hand_r`, `hand_l`) a `AnimationPlayer` s `A_Knight_Idle`, `A_Knight_Walk` (smyčka) a jednorázovými `A_Knight_Attack_Slash`/`_Stab`/`_Shoot`, `A_Knight_Cast`, `A_Knight_Hit`, `A_Knight_Death`. `unit_view` hraje útok při náběhu `u.atk`, zásah při náběhu `u.hit` (když neútočí), schopnost při události `ability` (`play_ability`), smrt jednou a hrdina zůstane ležet. Která animace a zbraň patří ke třídě, je v datech (`anim_attack`, `anim_ability`, `weapon`); zbraň je zástupná primitiva na `BoneAttachment3D`. Barva role přes `role_row` v shaderu.
13. **Vlny:** událost `arrive` vytvoří pohled nově příchozího nepřítele.
14. **Ragdoll padlých:** hrdina dostane při smrti fyzikální kosti (`PhysicalBoneSimulator3D`, kosti v `RAGDOLL`: kapsle, kuželové klouby, loket a koleno jako pant) a padne dozadu od směru, kam se díval; nepřítel padne jako jedno tuhé tělo (`RigidBody3D`, `top_level`). Těla jsou ve vrstvě 2 a narážejí jen do země (`StaticBody3D` ve vrstvě 1 z `battlefield.gd`). Po smrti `sync` pohled už nehýbe. Když ragdoll nejde vytvořit, zůstává animace smrti.
7. **Ovládání:** 1–5 schopnost hrdiny podle pořadí karet · F Do boje! · mezerník signál / pokračovat · Enter pokračovat · Esc zruší cílení nebo výběr cíle rozkazu · kamera: WASD/šipky a pravé tlačítko = posun, prostřední tlačítko nebo Q/E = otáčení, kolečko = přiblížení. Změna = upravit README a popisky v UI.
8. **Výběr a přesun hrdinů:** podle postavy na obrazovce (úsečka nohy–hlava, `PICK_PX` = 30 px). Drag & drop v rozestavení (prohození puštěním), při signálu přetažení = rozkaz na místo.
9. **Cílení schopnosti:** `_aim_id` = hrdina, jehož schopnost se cílí; kruh pod kurzorem v poloměru schopnosti (červený mimo dosah), klik pošle cíl do `sim.use_ability`, neplatný cíl ukáže `flash_hint`. Nepřítel se vybírá podle postavy na obrazovce (`_pick_foe`). Událost `ability` = krátký kruh efektu.
10. **Přísahy se ve scéně ověřují přes simulaci** (`has_oath`, `is_retreat`), nikdy podle klíče hrdiny.
11. **Rozhodnutá bitva** (událost `decided`) přepne rychlost aspoň na 2×. Uprchlá jednotka (`fled`) je skrytá.
12. **Výběr bitvy** jen v rozestavení (`_load_scenario`, bojiště v `field_root`). **Rozkazy:** Poslat na kartě (`_order_id`) → klik: na nepřítele = jeho skupina, na hrdinu = spojenec, jinak místo na zemi (`_order_click` → `_give_order`); v rozestavení se rozkaz uloží do `setup.orders` (simulace se při startu staví znovu). Rozkaz k ústupu u přísahy Nikdy neustoupí: v rozestavení odmítnut s nápovědou, při signálu dialog přísahy. Čáry rozkazů v rozestavení a při signálu (`_draw_orders`): na místo žlutě, na skupinu červeně ke středu skupiny, ke spojenci zeleně; při výběru cíle bílá ke kurzoru.

## Úskalí
- Proměnná s typem `Node3D` nezná metody skriptu: použij typ skriptu (`var v := UnitView.new()`).
- Víceřádkové lambdy jako argumenty funkce raději ulož nejdřív do proměnné.
- Limity testů počítej v čase bitvy, ne ve snímcích (monitor může mít 144 Hz).

## Historie významných změn
- 29.10.2026: rozkazy místo tras: Poslat na kartě, klik na místo/nepřítele/spojence, čáry rozkazů, varování před bitvou bez rozkazů, přetažení při signálu = rozkaz na místo.
- 29.10.2026: ragdoll padlých (hrdinové fyzikální kosti, nepřátelé tuhé tělo), fyzikální zem na bojišti.
- 29.10.2026: animace boje hrdinů (útok podle třídy, schopnost, zásah, smrt), zástupné zbraně v ruce, chalupy na bojišti, nepřátelé z dalších vln se objeví při události `arrive`.
- 28.10.2026: režim běhu (`run` nastaví `run_main.gd`): setup z běhu, bez výběru bitvy a zkoušení pasivek, signál `battle_done(result)`. Vůdce nepřátel je větší (×1,3). Hlavní scéna hry je `scenes/run/run.tscn`; `battle.tscn` jde dál spustit samostatně (volná bitva).
- 28.10.2026: přestavba na hrdiny: pryč aura a prapor; schopnosti klávesami 1–5 a z karet, cílení kruhem, efekty schopností.
- 28.10.2026: výběr bitvy, kreslení a zobrazení tras, bojiště z obecného terénu (most, brody, lávka, les), kopiník.
- 28.10.2026: povel Do boje! (F), rozhodnutá bitva se zrychlí na 2×, uprchlí nepřátelé zmizí.
- 28.10.2026: volba nositele praporu, kruh aury podle nositele.
- 2026-10-28: po playtestu drag & drop, výběr podle obrazovky, kamera WASD a pravé tlačítko, signál na mezerníku.
- 2026-10-28: založeno. Bez mlhy, ACES tonemap, kontrast 1.12.
