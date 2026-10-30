# Kontext: testy a ověřování

Soubory: `tests/`

## Jak testy běží
Claude nemá Godot v cloudu. Testy se pouštějí na Tomově počítači přes Blender MCP (Python v Blenderu spustí Godot):
- Godot: `C:\Users\sirko\Desktop\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`
- Pracovní kopie: `C:\Users\sirko\Documents\roguelike` (nejdřív `git pull`)
- Snímky: `C:\Users\sirko\Blender\Roguelike\godot_shots`

Test scény ukládá snímky, jen když dostane složku: `--script res://tests/screenshot_battle.gd -- <složka> [klíč scénáře]`. Snímky jiného scénáře než mostu mají předponu klíče.

Postup: `git pull` → `--headless --import` → test simulace → test scény (otevře okno na ~1 min, spouštět jen když to Tomovi nevadí) → prohlédnout snímky.

**Netestovaný kód se nepushuje.** Změny se na Tomův počítač přenesou jako patch: `git diff --cached --binary` → `/mnt/user-data/outputs/<nové jméno>.patch` → `device_commit_files` do `C:\Users\sirko\Blender\Roguelike\patches\` → v pracovní kopii `git checkout -- .` a `git apply`. **Patch pokaždé pod novým jménem**, stejná cesta se může přenést ze staré cache (ověř md5). Po pushi na Tomově počítači smaž nesledované soubory, které commit přidal (jinak `git pull` odmítne).

## Co který test hlídá
| Test | Hlídá | Očekávaný výsledek |
| --- | --- | --- |
| `test_battle_sim.gd` | invarianty simulace, klid (hrdina mimo boj nekmitá, kněz léčí), počet použití a nabíjení schopností, balanc každého scénáře (rozkazy z `auto_command` každý krok; bez schopností / se schopnostmi podle `ability_hint`), schopnosti, místa kolem hrdiny (`_test_slots`), kněz léčí jen v boji (`_test_priest_combat`), skupinky (`_test_pods`: spí, probudí je blízkost, zásah a poplach), skupiny nepřátel, rozkazy (na místo, na skupinu, ke spojenci, bez rozkazu, pomsta), rozkaz zpět s přísahou, přísaha, morálka, Do boje!, terén, kopiníci, vlastnosti | kód 0, „OK: všechny testy prošly“ |
| `passives_ingame.gd` | pasivky a přísahy ve skutečné hře: zapnutí přes menu na kartě (`_on_passive`), hodnoty v bitvě, ikonky, hořící zem, omráčení, Úkryt, deník (Druhý dech, Poslední pomazání), Probodnutí, Mstitel; sada A = Most, B = Brod (jezdec s Rozběhem vyrazí, až je tank v boji); spouští se s oknem: `--script res://tests/passives_ingame.gd -- <složka> <A\|B>` | „VÝSLEDEK: OK“, snímky `pasivky_<sada>_*.png` |
| `test_run.gd` | mapa aktu na 50 semínkách (patra, šířky, cesty, typy, obsah), pravidla běhu na podvržených výsledcích (nástupci, dědictví, nabídky, elita 2 ze 4, sláva, zranění, uprchlíci u bosse, porážka, porušená přísaha), události a tábor, vůdce, 20 celých běhů s náhodnou cestou (nic neuvízne, 30–99 % vítězných) | „VÝSLEDEK: OK“ |
| `screenshot_run.gd` | běh přes obrazovky: start → mapa → bitvy (auto), elita, událost, tábor, dědictví, odměna → boss → kronika; s oknem: `--script res://tests/screenshot_run.gd -- <složka>` | „VÝSLEDEK: OK“, snímky `beh_*.png` |
| `anim_sheet.gd` | řada pěti hrdinů se zbraněmi, jejich útok v několika okamžicích, schopnost, zásah a smrt (kontrola vzhledu animací bez bitvy); s oknem: `--script res://tests/anim_sheet.gd -- <složka>` | „VÝSLEDEK: OK“, žádné „CHYBÍ animace“, snímky `sheet_*.png` |
| `ragdoll_sheet.gd` | pět hrdinů a dva nepřátelé padnou: vznikne ragdoll, těla nepropadnou zemí a po 3 s leží (nikdo nestojí, neletí); s oknem: `--script res://tests/ragdoll_sheet.gd -- <složka>` | „VÝSLEDEK: OK“, snímky `ragdoll_*.png` |
| `vycvik.gd` | výcvik jako hráč: kroky jdou po sobě, karta je přišpendlená, bitva se zastaví u nepřátel, u boje a u velitele, Rozumím výcvik ukončí; s oknem: `--script res://tests/vycvik.gd -- <složka> [scénář]` | „VÝSLEDEK: OK“, snímky `vycvik_*.png` |
| `screenshot_battle.gd` | scéna se načte, bitva začíná v pauze (drag & drop jen v rozestavení obrany), po zlomení morálky jde dát povel Do boje!, bitva doběhne bez chyb | „Výcvik se ukázal: OK“, „Výcvik prošel kroky: OK“ (výcvik zapnutý, `tutorial_mode = 1`; ostatní testy se snímky ho vypínají), „Bitva začíná v pauze: OK“, „povel Do boje!: OK“, „Rozkazy klikem: OK“, „Start: OK“, „Pauza: OK“, „Rozkaz pravým tlačítkem v pauze: OK (čas stál: OK)“, „Rozkaz pravým tlačítkem na spojence: OK“, „Výběr tažením: OK“, „Klik na hrdinu vybere jen jeho: OK“, „Karta a Ctrl+A: OK“, „Kamera s pevným úhlem a hranicemi: OK“, „H drží místo, karta bez Poslat, schopnost s klávesou: OK“, „Náhled rozkazu nad nepřítelem: OK“, schopnosti jako v testu simulace, cílené přes klik („Cílená schopnost pravým tlačítkem: OK“, „Cílená schopnost přes klik: OK“), u mostu „Bitva skončila: win“ (u jiných scénářů jen doběhne), žádné ERROR v logu |

## Invarianty
1. **Před každým pushem** projde `gdparse` na změněných `.gd` souborech.
2. **Změna simulace nebo dat** = projde `test_battle_sim.gd`.
3. **Změna scény, UI nebo grafiky** = projde `screenshot_battle.gd` a snímky si prohlédnu.
4. **Nový invariant v kontextovém souboru** = ideálně i nový test, který ho hlídá.

## Export pro testery (Windows)
- Šablony exportu Godot 4.7.2 jsou na Tomově PC v `%APPDATA%\Godot\export_templates\4.7.2.stable` (stačí `windows_*_x86_64*.exe` a `version.txt` z oficiálního `.tpz`).
- `export_presets.cfg` (v `.gitignore`, leží jen na Tomově PC): preset „Windows Desktop“, `include_filter="*.json"`, `exclude_filter="tests/*, docs/*"`, `binary_format/embed_pck=true` (jeden soubor), `application/modify_resources=false`.
- Příkaz: `Godot_v4.7.2-stable_win64_console.exe --headless --path <repo> --export-release "Windows Desktop" <repo>\builds\Rytiri.exe` (`builds/` je v `.gitignore`).
- **Kam s buildem:** ZIP do větve `testovaci-buildy` (osiřelá větev jen s buildy a README s tabulkou verzí; kód tam není). GitHub Release ze sezení Clauda vytvořit nejde (zakázáno), Tom ho může udělat ručně na webu. Repo je soukromé: tester potřebuje přístup (collaborator s právem čtení), nebo mu Tom ZIP pošle přímo.
- Kontrola: exe se spustí (`--quit-after 600 --log-file …`) bez chyb, v souboru jsou JSONy. Pro testera ZIP s exe a návodem „Jak hrát.txt“ (ovládání, SmartScreen: Další informace → Přesto spustit).

## Historie významných změn
- 30.10.2026: `ragdoll_sheet.gd` bere posledního nepřítele scénáře (po přeladění nebyl `e11` a test hlásil chybu skriptu); `anim_sheet.gd` bere animace zásahu a smrti z dat třídy.
- 30.10.2026: druhý build pro testera (`Rytiri_test_2026-10-30.zip`, větev `testovaci-buildy`).
- 30.10.2026: `vycvik.gd` (výcvik krok po kroku jako hráč, zastavení bitvy, přišpendlení karty); `screenshot_battle.gd` pokračuje, když výcvik bitvu zastaví.
- 30.10.2026: `screenshot_battle.gd` prochází výcvik akcemi testu a zavře ho Rozumím; `passives_ingame.gd` a `screenshot_run.gd` mají výcvik vypnutý.
- 30.10.2026: `screenshot_battle.gd` testuje kameru (pevný úhel, hranice); testy se snímky vypínají posun myší u okraje (`TacticalCamera.edge_scroll_all = false`).
- 30.10.2026: `passives_ingame.gd` sada B požehná tanka, kterého test sám zraní (jinak se Požehnaná zbroj nemusela projevit); cílená schopnost na nepřítele, kterého by klik netrefil (překryv), se použije přímo. `screenshot_battle.gd` testuje výběr podle zvyklostí RTS (klik vybere jen hrdinu a nepohne s ním, Ctrl+A, karta) a náhled pravého tlačítka.
- 29.10.2026: bitva ve fázích: testy skupinek, míst kolem hrdiny, léčení jen v boji, počtu použití; auto-hraní volá `auto_command` každý krok; balanc bez dávky „bez rozkazů“; scéna začíná v pauze.
- 29.10.2026: první export pro testera (`Rytiri_test_2026-10-29.zip`).
- 29.10.2026: reálný čas: `screenshot_battle.gd` testuje pauzu a rozkaz pravým tlačítkem v pauze; test signálu v simulaci zrušen.
- 29.10.2026: rozkazy místo tras a chování: testy chování a tras nahrazené testy skupin a rozkazů, auto-hraní ve všech testech dává rozkazy z `suggest_orders` (v `passives_ingame` jde jezdec na skupinu kvůli Rozběhu), scéna testuje rozkazy klikem a varování před bitvou.
- 29.10.2026: `ragdoll_sheet.gd`.
- 29.10.2026: `anim_sheet.gd` (animace hrdinů), test vln a obrany (`_test_waves`). Po změně GLB nejdřív `--headless --import`.
- 29.10.2026: `test_run.gd` a `screenshot_run.gd` přepsané na mapu aktu; balanc elit (stačí 20/40).
- 29.10.2026: test kmitání a nečinnosti kněze (`_test_calm`), test limitu schopností navíc a nabíjení.
- 28.10.2026: `test_run.gd` a `screenshot_run.gd` (zkušební běh). Test balancu běží i na Táboře na Vraní skále.
- 28.10.2026: `passives_ingame.gd` (pasivky ve hře); odhalil, že oheň dával slávu za každý zásah v každém snímku.
- 28.10.2026: testy přepsané na hrdiny a schopnosti.
- 28.10.2026: testy nositele praporu a asasína. Dlouhé běhy Godotu spouštět přes `Popen` s logem do souboru (volání Blenderu má limit 60 s).
- 2026-10-28: testy přísah a postojů, drag & drop ve scéně, přenos změn patchem.
- 2026-10-28: založeno.
