# Oathline – snímky a videa pro portfolio

Kapitola „Mám hru“ (https://portfolio-black-seven-cmpvxmsqzt.vercel.app/kapitoly/mam-hru/). Větev obsahuje jen hotové soubory, kód je ve větvi `portfolio-snimky` (`tools/portfolio/`, popis v `docs/context/portfolio.md`).

Všechny snímky jsou PNG 2560 × 1440 (16 : 9) bez debug výpisů a FPS. K2-01 je 21 : 9, 2520 × 1080. Snímky aktuálního buildu jsou renderované ve 2× rozlišení a zmenšené (ostré obrysy a písmo). Archivní snímky jsou ze skutečných starých commitů, žádná rekonstrukce. Kurzor je jen tam, kde něco ukazuje (K2-07a, K2-07b, K2-16).

## Snímky (`mam-hru/`)

| Soubor | Co je na něm | Odkud |
| --- | --- | --- |
| `K2-01.png` | Most přes řeku, filmový záběr zdola přes jezdce: tank drží most, lapkové tlačí, lučištník a kněz za ním | aktuální build |
| `K2-01-master-3360x1440.png` | totéž ve větším rozlišení (retina), navíc | aktuální build |
| `K2-03.png` | mapa aktu Hraběcí les uprostřed běhu (4. patro z 8), prošlá cesta, panel „What awaits“, soupiska s nástupci a padlými | aktuální build, odehraný běh (semínko 22) |
| `K2-04.png` | kronika rodu po vyhraném běhu: kdo bojoval, kdo padl, kdo nastoupil, odkázaná přísaha, pouta a znamení | aktuální build, běh se semínkem 22 |
| `K2-06a.png` | bitva s praporem a postoji (aura praporu, pokřiky v liště, postoje na kartách) | build 28.10. (`ef493cd`) |
| `K2-06b.png` | Výzva tanka a Požehnání kněze právě spuštěné (modrý a zelený kruh), karty s počtem použití a nabíjením | aktuální build |
| `K2-07a.png` | rozestavení: trasy lučištníka a jezdce nakreslené, asasínovi se právě kreslí (režim „Kreslím“) | build 28.10. (`ef493cd`) |
| `K2-07b.png` | pauza v reálném čase, vybraný jezdec, kurzor na střelci, červený kruh = co udělá pravé tlačítko | aktuální build |
| `K2-08.png` | odměna po elitě, karty ukazují dopad: „Fits Blessing“, znamení s cenou, „Replaces Shadow Strike“ | aktuální build |
| `K2-09.png` | pět hrdinů před bitvou z běžné bitevní kamery (pevný úhel, nejbližší zoom) | aktuální build |
| `K2-09-maska.png` | stejný záběr jako maska: barva třídy, zbytek postavy šedě (stejné pravidlo jako test 40 %) | aktuální build |
| `K2-09-split.png` | doporučená verze pro web: vlevo hra, vpravo maska, stejný výřez; celé plátno 2560 × 1440 bez pruhu (opraveno 28.11. v kole 2) | z obou výše |
| `K2-10a.png` | karta tanka z Figmy (frame „Battle · A Normal“, vybraná) uprostřed plátna 2560 × 1440, 3,2 px na bod UI | Figma, export 3× |
| `K2-10b.png` | stejná karta ve hře, vybraná, stejné plátno, měřítko i umístění | aktuální build |
| `K2-10a-obrazovka.png`, `K2-10b-obrazovka.png` | navíc: celá obrazovka bitvy ve Figmě a ve hře, obě 2560 × 1440 ve stejném měřítku | Figma / aktuální build |
| `K2-11a.png`, `K2-11a-detail.png` | lišta bez morálky (čas a pauza); detail = horní část obrazovky přiblížená | build 7.11. před vzhledem Royal Court (`e8f8882`) |
| `K2-11b.png`, `K2-11b-detail.png` | lišta s morálkou nepřítele 63 / 70 % a hranicí zlomu; detail se stejným výřezem jako 11a | aktuální build |
| `K2-12.png` | stránka rodu: komba pout, znamení a „The Fallen“ s pamětními deskami a nástupci | aktuální build |
| `K2-13.png` | dialog přísahy Never Retreat (POWER / RESTRICTION / IF BROKEN) | aktuální build |
| `K2-14.png` | Build 1 (28.10.): kostičky na Mostě přes řeku, bitva s praporem | `63e5f4a` |
| `K2-15.png` | Build 2 (28.10.): hrdinové se schopnostmi v bitvě zkušebního běhu | `6a6ecbb` |
| `K2-15b.png` | Build 2, navíc: tábor po bitvě s odměnou, padlými a nástupci | `6a6ecbb` |
| `K2-16.png` | Build 3 (29.10.): reálný čas, pauza a rozkaz jezdci (kurzor) | `61c64b5` |
| `K2-16b.png` | Build 3, navíc: první mapa aktu (tmavé UI) | `61c64b5` |
| `K2-17.png` | Build 4 (7.11.): světlé UI z Figmy, morálka v liště, komba Q/E | `f117e8e` |
| `K2-17b.png` | Build 4, navíc: odměna s dopadem na kartách | `f117e8e` |
| `K2-18.png` | Build 5 (17.11.): nový vzhled Oathline a čtyři velitelé s vlastní postavou (Vok, Kuno, Bořivoj, Jíra) proti rodu | `e879244` (main) |

## Videa (`mam-hru/`)

| Soubor | Co | Parametry |
| --- | --- | --- |
| `V2-01.mp4` | výběr odměny → bitva, pauza a rozkaz jezdci → All In! a vítězství bez padlých → zápis „Victory“ po bitvě; konec navazuje na začátek (stejná obrazovka a kurzor), mezi scénami prolínačky, bez černé | 1920 × 1080, 25 s, H.264, 4,1 MB, bez zvuku |
| `V2-02.mp4` | spuštění Výzvy a Požehnání (k K2-06b), bez UI | 1920 × 1080, 4,6 s smyčka |
| `V2-03.mp4` | rozkaz v pauze: výběr jezdce a poslání na střelce (k K2-07b) | 1920 × 1080, 4,6 s smyčka |

| `V2-02-dlouhe.mp4` | Výzva tanka a Požehnání kněze, kamera v klidu, bez UI; kruh Výzvy je vidět celou dobu účinku | 2560 × 1440, 30 fps, 8,6 s smyčka, 3,0 MB |
| `V2-03-dlouhe.mp4` | rozkaz v pauze: pomalé najetí, výběr jezdce, chvíle nad cílem, potvrzení pravým, puštění času, jezdec vyrazí | 2560 × 1440, 30 fps, 9,6 s smyčka, 2,2 MB |
| `V2-10.mp4` | filmová smyčka: pomalý oblet nad bitvou u Mostu, aktuální vzhled, bez UI, kurzoru a zvuku; děj v pravých ~60 %, vlevo klidná tráva a les | 2520 × 1080, 30 fps, 9,2 s, 3,7 MB |
| `V2-10-m.mp4` | totéž pro mobil, děj uprostřed (stejný render, jiný výřez, stejná délka a smyčka) | 1920 × 1080, 30 fps, 9,2 s, 3,2 MB |
| `V2-10-poster.png` | první snímek `V2-10.mp4` | 2520 × 1080 |

Všechna videa jsou H.264 (yuv420p, faststart), bez zvuku. Smyčka: konec se během posledních 0,4 s (V2-10: 0,8 s) prolne do začátku, poslední snímek = první. Kamera V2-10 letí po uzavřené dráze, takže se na švu nehýbe skokem.

### Časy událostí (s od začátku souboru)

`V2-02-dlouhe.mp4`

| Čas | Událost |
| --- | --- |
| 2,6 | Výzva a Požehnání spuštěny: kruh Výzvy (modrý) i kruh Požehnání (zelený) se objeví |
| 3,2 | kruh Požehnání zmizí (léčení je okamžité, kruh je záblesk) |
| 6,6 | kruh Výzvy zmizí (Výzva trvá 4 s, posledních 0,6 s dohasíná) |

`V2-03-dlouhe.mp4`

| Čas | Událost |
| --- | --- |
| 0,0–2,2 | pauza, kurzor pomalu najíždí na jezdce |
| 2,2 | výběr jezdce (klik) |
| 4,8 | kurzor nad střelci, náhled cíle rozkazu (červený kruh a oblouk) |
| 6,0 | potvrzení rozkazu pravým tlačítkem |
| 6,6 | puštění času (mezerník) |
| 6,6 | jezdec vyrazí (první pohyb o 3 snímky později) |

## 3D modely (`mam-hru/`)

Pět hrdinů rodu a čtyři velitelé lapků. GLB 2.0 s vloženými texturami (paleta hry 256 × 128 px s barvou role, ORM pro drsnost), PBR materiál (metallic 0, drsnost z textury, ambientní okluze zapečená), metry, Y nahoru, počátek mezi nohama na zemi, čelem +Z, všechny ve stejném měřítku jako ve hře. Každý má jednu animaci `Idle` (smyčka). Bez Draco/Meshopt komprese, není potřeba dekodér; všechny jsou pod 1 MB. Prošly gltf-validatorem bez chyb (jen informativní hlášky o kostře).

Náhledy `hrdina-<trida>.png` jsou 1200 × 1200 s průhledností, 3/4 zepředu, renderované v enginu hry (světlo „morning“), každá postava zvlášť vycentrovaná (velikost v náhledu tedy neodpovídá skutečné výšce; ta je v `hrdinove.json`). V prohlížeči (`<model-viewer>`, three.js) budou modely trochu jiné než ve hře: herní shader má ploché stínování a obrys, standardní PBR ne. Pro věrnost hře použij náhledy PNG.

| Soubor | Co | Velikost | Výška (vč. zbraně) | Idle |
| --- | --- | --- | --- | --- |
| `hrdina-tank.glb` | Sir Bořek, tank (meč, štít) | 0,45 MB, 5 890 △ | 1,81 m | 2,5 s |
| `hrdina-knez.glb` | Father Jan, kněz (berla) | 0,31 MB, 4 040 △ | 2,20 m | 2,54 s |
| `hrdina-lucistnik.glb` | Matěj, lučištník (luk bez tětivy, ta se ve hře kreslí za běhu) | 0,33 MB, 4 250 △ | 1,84 m | 2,54 s |
| `hrdina-jezdec.glb` | Sir Radek na koni (kopí s praporcem); jezdec i kůň mají vlastní idle v jedné animaci | 0,73 MB, 9 994 △ | 3,79 m | 2,54 s |
| `hrdina-asasin.glb` | Kryštof, asasín (dvě dýky) | 0,30 MB, 4 292 △ | 1,79 m | 2,04 s |
| `hrdina-vok.glb` | Vok the Burner (Pálič Vok), pochodeň a sekera | 0,29 MB, 3 924 △ | 1,96 m | 2,54 s |
| `hrdina-kuno.glb` | Captain Kuno (Vůdce Kuno), halapartna, plná zbroj | 0,50 MB, 6 680 △ | 2,86 m | 2,54 s |
| `hrdina-borivoj.glb` | Sergeant Bořivoj (Setník Bořivoj), kopí a štít | 0,41 MB, 5 628 △ | 2,05 m | 2,54 s |
| `hrdina-jira.glb` | Jíra the Marksman (Ostrostřelec Jíra), dlouhý luk | 0,33 MB, 4 232 △ | 2,42 m | 2,54 s |
| `hrdina-<trida>-maska.glb` | jen u pěti hrdinů: stejný model, barva třídy barevně, zbytek šedě (pravidlo testu 40 %) | stejná jako model | | |
| `hrdina-<trida>.png` | náhled 1200 × 1200, průhledné pozadí | | | |
| `hrdinove.json` | jméno, třída, schopnost s krátkým popisem (z `data/units.json`), barva třídy hex, naměřený podíl barvy třídy | | | |

Podíl barvy třídy je z testu `tests/prototype_shots.gd` (maska z bitevní kamery, 8 póz × 4 natočení, stav 28.11.2026): tank min 40,8 / průměr 48,8 %, kněz 44,8 / 47,4 %, lučištník 42,7 / 45,8 %, jezdec 40,6 / 46,4 %, asasín 44,5 / 47,8 %. Všichni nad cílem 40 %.

Velitelé nemají masku ani podíl barvy: nepřátelé záměrně nenesou barvu žádného hrdiny (rozhodnutí 15.11.2026). Místo toho mají v `hrdinove.json` profil (jak se v boji chovají) a schopnost.

Pozn.: kruh Výzvy dřív problikl jen 0,6 s; kvůli V2-02-dlouhe je teď ve hře vidět celé 4 s (commit `4cc3b09` na větvi `portfolio-snimky`).

## Pro Clauda, který staví web portfolia

Snímky jsou ve větvi `portfolio-mam-hru` repa `tomaspatolan-bit/roguelike`, složka `mam-hru/`. Názvy souborů odpovídají kódům v zadání kapitoly. Doporučené volby: K2-09 → `K2-09-split.png`; hero video kapitoly → `V2-10.mp4` s `V2-10-poster.png`, na mobilu `V2-10-m.mp4`; 3D prohlížeč → `hrdina-*.glb`, přepínač masky → `hrdina-*-maska.glb`, data k nim v `hrdinove.json`; K2-11a/b jako dvojice → verze `-detail` (stejný výřez); pro build 2 a 3 se nabízejí i `K2-15b` a `K2-16b`. Popisky se píšou na web, do obrázků se nic nepíše.
