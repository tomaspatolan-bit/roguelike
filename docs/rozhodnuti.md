# Deník rozhodnutí – rytířský roguelike

Nejnovější nahoře. Každé rozhodnutí: datum, co, proč. Kopie je v projektu Roguelike v Claude (`claude/rozhodnuti.md`).

## 2026-10-28 – Prototyp v Godotu
- **Godot 4.7.2** (verze na Tomově počítači). Repozitář `tomaspatolan-bit/roguelike`, práce na větvích.
- **Testy běží na Tomově počítači přes Blender MCP**, protože v cloudu Godot stáhnout nejde. Postup v `CLAUDE.md`.
- **Obsah jako JSON** v `data/` (jednotky, rod Vlka, scénář). Simulace bitvy oddělená od scény, aby šla testovat bez okna.
- **Barva role přes řádek palety** (shader `knight_palette.gdshader`): jeden model rytíře pro všechny role.

## 2026-10-28 – Tým a engine
- **Tým:** Tom + Claude. Tom = ředitel, designér, tester, art direction, business. Claude = kód, data a obsah, simulace balancu, technická práce v Blenderu, dokumentace a plánování.
- **Engine: Godot 4** (místo Unrealu). Důvod: scény i skripty jsou čitelný text, takže Claude může projekt přímo upravovat, testovat a hlídat. Model rytíře jde do Godotu přes `SK_Knight.glb`.
- **Pracovní paměť:** `CLAUDE.md`, `docs/stav.md` (aktuální sprint) a tento deník. Bez zápisu rozhodnutí neexistuje.

## 2026-10-26 – Grafika a pipeline
- Stylizovaný low-poly rytíř z tuhých dílů, paletová textura s řádky pro role, kostra s 27 kostmi. Herní síť ~5 400 trojúhelníků, LOD1 ~2 200.
- Steam: obsah vytvořený AI (grafika, texty, zvuk) se musí uvést na stránce hry; AI nástroje pro kód a vývoj se neuvádějí.

## 2026-10-25 – Koncept a bitva
- Háček: rod → prapor → přísahy rytířů, padlí odkazují přísahy a výbavu nástupcům.
- Bitva: hybrid. Příprava (rozestavení, postoje) + bitva běží sama + pokřiky praporu za slávu (bez zastavení času) + 1–2 signály praporu (zastavení času). Pravidla „když–pak“ jen pokud prototyp ukáže potřebu.
- Pilíře: velíš rodu, ne vojákovi · prapor je srdce oddílu · přísaha má cenu · každý run je příběh rodu.
- Webové demo „Most přes řeku“: bez pokřiků se prohrává, s nimi vyhrává. Zjištění: útočný postoj vede ke ztrátám mimo auru praporu; střelci + kněz můžou vytvořit pat.
