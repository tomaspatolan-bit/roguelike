# Kontext: snímky a videa pro portfolio

Soubory: `tools/portfolio/`

Snímky a videa pro Tomovo portfolio (kapitola „Mám hru“, web `portfolio-black-seven-cmpvxmsqzt.vercel.app/kapitoly/mam-hru/`). Nástroj hru nemění: staví stav přes běžný kód (scéna bitvy, sandbox, obrazovky běhu) a ukládá čisté snímky. Kódy snímků (K2-01…, V2-01…) jsou podle Tomova zadání z 28.11.2026.

## Soubory
| Soubor | Co dělá |
| --- | --- |
| `lib.gd` | společné: start bitvy, přetočení simulace bez vykreslování (`ff`), kamera, snímek; `auto_run` odehraje běh bez okna (jako `test_run.gd`) |
| `shots.gd` | snímky aktuálního buildu, jedna funkce `k2_xx` na snímek; `probe` jako třetí argument uloží kandidáty kamer |
| `archive_shots.gd` | snímky starých buildů; kopíruje se do pracovní kopie starého commitu (`git worktree`), metody hledá podle jména |
| `seeds.gd` | najde semínka běhu s bohatým příběhem (padlí, pouta, znamení) pro kroniku a stránku rodu |
| `video.gd` | snímky videí po framech (30 fps) s kresleným kurzorem |
| `video.sh` | ffmpeg: segmenty → MP4 (H.264), prolínačky, smyčka |
| `finish.py` | z 2× renderů dodávané PNG: zmenšení, 21 : 9 pro K2-01, kurzor, split masky, karty, detail lišty |

## Jak spustit
- Okno 2× cílové velikosti (supersampling, obrys a UI se škálují s výškou okna): `godot --path . --resolution 5120x2880 --fixed-fps 60 --script res://tools/portfolio/shots.gd -- <raw> K2-03,K2-04,…`; K2-01 s `--resolution 5040x2160`.
- V cloudu bez GPU: Godot 4.7.2 pro Linux (GitHub release), `mesa-vulkan-drivers` (lavapipe), `VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json`, `xvfb-run -s "-screen 0 5120x2880x24"`. Snímek ve 2× trvá na CPU několik sekund, proto se bitva přetáčí bez vykreslování (`RenderingServer.render_loop_enabled = false`) a vykreslí se jen výsledný okamžik.
- Archiv: `git worktree add ../wt/<commit> <commit>`, `--headless --import`, zkopírovat `archive_shots.gd` do `tools/portfolio/` pracovní kopie, spustit s `-- <raw> <kód> battle|paused|routes|map|reward [t]`.
- `python3 tools/portfolio/finish.py <raw> <out> [figma_karta.png]`, videa `tools/portfolio/video.sh <frames> <out>`.

## Invarianty
1. Nástroj nemění pravidla ani data hry; jen čte stav a volá funkce, které volá hráč (rozkaz, schopnost, pauza).
2. Pozice na obrazovce (`unproject_position`, vstup myši) jsou v jednotkách UI 1600 × 900 (stretch `canvas_items`), ne v pixelech okna; metadata snímků ukládají i velikost viewportu (`vp`).
3. Efekty na zemi (kruhy schopností a rozkazů) se kreslí ve výšce země a pod palubou mostu nejsou vidět; snímky schopností a rozkazů proto míří mimo most.

## Mapování archivních buildů
K2-14 Build 1 = `63e5f4a`, K2-06a a K2-07a = `ef493cd`, K2-15 Build 2 = `6a6ecbb`, K2-16 Build 3 = `61c64b5`, K2-11a = `e8f8882`, K2-17 Build 4 = `f117e8e`, K2-18 Build 5 = `e879244` (aktuální `main`).

## Historie významných změn
- 28.11.2026: založeno (snímky K2-01 až K2-18, videa V2-01 až V2-03).
