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
| `test_battle_sim.gd` | invarianty simulace, balanc každého scénáře (bez schopností / se schopnostmi podle `ability_hint`), schopnosti, sláva za použití navíc, výchozí chování tříd, rozkaz přesunu, přísaha, morálka, Do boje!, terén, trasy, kopiníci, vlastnosti, nepřátelé na pozici | kód 0, „OK: všechny testy prošly“ |
| `screenshot_battle.gd` | scéna se načte, drag & drop prohodí rytíře tam i zpět, po zlomení morálky jde dát povel Do boje!, bitva doběhne bez chyb | „Drag & drop … OK“, „povel Do boje!: OK“, „Kreslení trasy: OK“ (trasa se pak smaže), schopnosti jako v testu simulace, cílené přes klik („Cílená schopnost přes klik: OK“), u mostu „Bitva skončila: win“ (u jiných scénářů jen doběhne), žádné ERROR v logu |

## Invarianty
1. **Před každým pushem** projde `gdparse` na změněných `.gd` souborech.
2. **Změna simulace nebo dat** = projde `test_battle_sim.gd`.
3. **Změna scény, UI nebo grafiky** = projde `screenshot_battle.gd` a snímky si prohlédnu.
4. **Nový invariant v kontextovém souboru** = ideálně i nový test, který ho hlídá.

## Historie významných změn
- 28.10.2026: testy přepsané na hrdiny a schopnosti.
- 28.10.2026: testy nositele praporu a asasína. Dlouhé běhy Godotu spouštět přes `Popen` s logem do souboru (volání Blenderu má limit 60 s).
- 2026-10-28: testy přísah a postojů, drag & drop ve scéně, přenos změn patchem.
- 2026-10-28: založeno.
