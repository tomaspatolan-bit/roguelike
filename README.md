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
| `K2-09-split.png` | doporučená verze pro web: vlevo hra, vpravo maska, stejný výřez | z obou výše |
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

## Pro Clauda, který staví web portfolia

Snímky jsou ve větvi `portfolio-mam-hru` repa `tomaspatolan-bit/roguelike`, složka `mam-hru/`. Názvy souborů odpovídají kódům v zadání kapitoly. Doporučené volby: K2-09 → `K2-09-split.png`; K2-11a/b jako dvojice → verze `-detail` (stejný výřez); pro build 2 a 3 se nabízejí i `K2-15b` a `K2-16b`. Popisky se píšou na web, do obrázků se nic nepíše.
