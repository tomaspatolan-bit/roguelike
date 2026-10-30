# Kontext: grafika a 3D pipeline

Soubory: `art/` (`art/knight/` rytíř a paleta, `art/cleric/` kněz, `art/tools/hero_kit.py` stavebnice hrdinů); zdroj v Blenderu `C:\Users\sirko\Documents\Knight.blend`, exporty v `C:\Users\sirko\Blender\Roguelike\`
Hlídá: `tests/screenshot_battle.gd` (model se načte a animuje)

## Účel
Modely, textury a shadery hry a cesta z Blenderu do Godotu.

## Invarianty
1. **Měřítko 1 jednotka = 1 m**, rytíř ~1,87 m, pivot u chodidel, kouká po +Z v Godotu (−Y v Blenderu).
2. **Rytíř = jedna síť, jeden materiál, paletová textura** 128×64 px, buňky 8×8 px. Řádek 0 je základ; role jsou další řádky (viz `data.md`).
3. **Kostra s názvy kostí podle UE5 Mannequina** (27 kostí, `cape_01–03`, `weapon_scabbard`). Přejmenování kostí rozbije animace.
4. **Animace** se jmenují `A_Knight_<Činnost>`: `Idle`, `Walk` (smyčky), `Attack_Slash`, `Attack_Stab`, `Attack_Shoot`, `Cast`, `Hit`, `Death` (jednorázové, 24 fps, klíčují všech 27 kostí kvůli exportu se vzorkováním). Export: jen `Armature` + `SK_Knight`, `export_animation_mode = ACTIONS`, `export_force_sampling`. Klidová póza kostry je A-póza (paže od těla, „Y“); všechny animace proto drží paže u těla (`upperarm` rotace Z ±0,5, loket ±0,2), jinak by rytíř stál jako Y. Zbraně v ruce nejsou v GLB (zástupné v kódu `unit_view.gd`), meč v pochvě na boku je součást sítě.
5. **Rozpočet:** rytíř ~5 400 trojúhelníků (LOD1 ~2 200). Nová postava se drží podobně.
6. **Kolekce v Blenderu:** `KNIGHT_game` (herní), `KN_game_parts` (zdrojové díly), `KNIGHT_hero` (prezentační), `PRESENTATION`. Herní export jen z `KNIGHT_game`.
7. **Evidence AI obsahu pro Steam:** každý asset vytvořený AI zapiš níže.
8. Godot si z GLB rytíře vytahuje kopie palety (`SK_Knight_T_Knight_Palette_*`); jsou v `.gitignore`, hra používá vlastní materiál s `art/knight/T_Knight_Palette_*.png`. **Nové postavy a zbraně se exportují bez materiálu** (`export_materials = NONE`, UV zůstávají): GLB pak nezávisí na vytažených texturách (palcát se bez nich nenačetl).
9. **Soupiska tříd (od 30.10.2026, zadání Toma):** každá třída má vlastní model postavený z tanka (`SK_Knight`) jako vzoru: stejná kostra a měřítko, stejná paleta, stejná stavba zbroje, ale vlastní silueta a výbava. Postava se staví skriptem v repozitáři (`art/<třída>/build_<třída>.py` + `art/tools/hero_kit.py`: díly z tanka se upraví nebo vymění, nové díly dostanou UV buňky palety a tuhé váhy), animace skriptem `anims_<třída>.py`. Vždy jde postavit znovu (skript, ze kterého vznikl tank, se nedochoval).
10. **Barvy (rozhodnutí 30.10.2026):** stříbrná zbroj, zlato a karmínové detaily pro všechny; navy řádu ve sloupcích palety 9 a 10 (stejné ve všech řádcích); barva hrdiny (sloupce 3 a 4, řádek role) na plášti a hlavní látce, protože ve hře je hrdina vidět hlavně zezadu. Buňky palety: 0 ocel, 1 tmavá ocel, 2 zlato, 3–4 barva hrdiny, 5 karmín, 6 kůže, 7 kroužková zbroj, 8 tmavá, 9–10 navy.
11. **Zbraně jsou samostatné GLB** (`SM_<Třída>_<Zbraň>.glb`, paleta jako postava). Úchop: počátek zbraně v pěsti, zbraň míří po +Z (v Blenderu); ve hře ji `unit_view` připne na kost ruky (`weapon_bone`, výchozí `hand_r`) posunutou o 0,08 m po ose Y kosti a otočenou tak, že osa zbraně leží v ose Z kosti. S předloktím vodorovně dopředu pak zbraň stojí svisle.
12. **Animace třídy** `A_<Třída>_<Činnost>` (kněz `A_Cleric_Idle`, `_Walk`, `_Attack`, `_Bless`), na stejné kostře; co třída nemá vlastní, bere z rytíře (zásah, smrt). Exportér glTF nejde omezit na akce jedné třídy, proto každý GLB nese i ostatní akce (malé, hra vybírá podle jména z dat). Jen animace, které hra používá (Tom 30.10.2026); další až s mechanikou (`napady.md`).

13. **Kontrola kvality každé postavy** (zadání, oddíl 9): normály nových dílů ven (`hero_kit` je přepočítá u uzavřených dílů), žádné nevážené vrcholy a součet vah 1, počátek u chodidel, zbraň s počátkem v pěsti, nohy neprochází dlouhým šatem v chůzi ani při výpadu (paprsky na deformované síti), siluety zepředu, 3/4, z boku a zezadu. Prezentace: `Blender\Roguelike\renders\<třída>_*.png` (pohledy, detail zbraně, pózy animací) ve scéně `PREVIEW` v `Knight.blend`. Kontrolní bod po každé třídě: `Knight_kontrola_<třída>.blend`.
14. **Herní síť je jedna** (jako tank): díly se v Blenderu neukládají jako samostatné objekty, stavěcí skript je zdroj modularity (zadání chtělo samostatné objekty pro díly; jedna síť = jedno vykreslení ve hře). Formát pro hru je GLB (glTF), ne FBX.

## Evidence AI obsahu
| Asset | Vznik | Poznámka |
| --- | --- | --- |
| `SK_Knight.glb` | Claude, skriptem v Blenderu | herní rytíř |
| `T_Knight_Palette_*.png` | Claude, vygenerováno skriptem | paleta barev |
| bojiště, nepřátelé (i kopiník, brody, lávka, les) | Claude, primitiva v kódu | zástupná grafika |
| ikonky UI (`scripts/battle/ui_icon.gd`) | Claude, vektorově v kódu | zástupné, finální navrhne Tom |
| animace boje rytíře (útok ×3, schopnost, zásah, smrt) | Claude, klíčové snímky skriptem v Blenderu | zástupné, `Knight.blend` |
| zbraně v ruce, chalupy | Claude, primitiva v kódu | zástupná grafika |
| `SK_Cleric.glb`, `SM_Cleric_Mace.glb`, animace `A_Cleric_*` | Claude, skriptem v Blenderu (`art/cleric/`) | kněz: model, palcát, klid, chůze, úder, Požehnání |

## Historie významných změn
- 30.10.2026: kněz (`SK_Cleric`, palcát `SM_Cleric_Mace`, animace `A_Cleric_*`), stavebnice hrdinů `art/tools/hero_kit.py`, paleta má navy sloupce 9 a 10, zbraně jako samostatné GLB s úchopem v pěsti.
- 29.10.2026: paže u těla ve všech animacích (rytíř už nestojí v A-póze jako „Y“), nový export GLB.
- 29.10.2026: animace boje (`A_Knight_Attack_Slash`, `_Stab`, `_Shoot`, `A_Knight_Cast`, `A_Knight_Hit`, `A_Knight_Death`) v `Knight.blend` (záloha před změnou `Blender\Roguelike\Knight_zaloha_2910.blend`), nový export `SK_Knight.glb`.
- 28.10.2026: řádek palety 5 přebarven na fialovou šeď pro asasína (byl praporečník).
- 2026-10-26: herní rytíř, kostra, paleta, export.
