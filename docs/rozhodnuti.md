# Deník rozhodnutí – rytířský roguelike

Nejnovější nahoře. Každé rozhodnutí: datum (formát DD.MM.RRRR), co, proč. Kopie je v projektu Roguelike v Claude (`claude/rozhodnuti.md`).

## 28.10.2026 – Prapor, jádro tříd a opakování bitev
- **Bitvy se neopakují.** Žádné opakování po prohře, žádné vracení času, žádné cvičiště. Prohra v runu znamená ztráty (padlí rytíři, propadlá odměna, ústup), ne nutně konec runu; přesná pravidla ve fázi 2. Tlačítka „Znovu stejně“ a „Nové rozestavení“ zůstávají jen v prototypu pro playtesty.
- **Hloubka rozhodnutí přes informace o nepříteli:** hráč před bitvou uvidí, kudy nepřátelé půjdou a jaké mají podmínky (stejný slovník jako instrukce hráče). Pojistky proti „hádance s jedním řešením“: trochu náhody v boji, podmínky nepřátel jako odhalovaná informace (průzkum, fáze 2).
- **Prapor nese kterákoli třída, volí se v rozestavení a během bitvy se nepředává.** Padlý prapor dál někdo zvedne (přednostně postoj Chránit prapor, který to má v popisu).
- **Efekt praporu určuje třída nositele:** tank −15 % zranění v auře, kněz léčí v auře, lučištník aura 7 m, jezdec +25 % rychlost v auře, asasín aura 4 m a +30 % útok. Postih za nošení není; cenou je, že rytíř dělá svou práci jinak.
- **Nositel nemá postoj Chránit prapor.**
- **Praporečník jako třída zaniká, místo něj asasín** (rychlý, křehký, přednostně jde po střelcích).
- **Jádro tříd je pevné: tank, kněz, lučištník, jezdec, asasín.** Mění se jen po úvaze a zápisu sem.
- **Do budoucna:** každý hrdina si najímá vlastní jednotky; prapor nese vždy hrdina, nikdy najatý voják (nápad, fáze 2+).
- Plán dalších kroků: trasy s druhou mapou (1.5), pak podmíněné instrukce a viditelné úmysly nepřátel (1.7).

## 28.10.2026 – Po prvním playtestu
- **Přísaha určuje povolené postoje** (data `forbidden_postures`, `posture_names`). Důvod: postoj „Držet pozici“ vracel rytíře na místo, což byl skrytý ústup a porušení přísahy, o kterém hra nevěděla.
- **„Nikdy neustoupí“ = varianta A:** rytíř smí Útočný a „Stát pevně“ (bojuje s tím, co přijde, nikam se nevrací), Chránit prapor má zakázaný. Porušit přísahu jde jen vědomým rozkazem při signálu. Varianta B („Jen vpřed“) je v `napady.md` jako budoucí přísaha.
- **Ovládání:** drag & drop rytířů s výběrem podle postavy na obrazovce; kamera WASD/šipky a pravé tlačítko; signál na mezerník (klávesa S patří kameře).
- **Netestovaný kód se nepushuje**, na Tomův počítač jde jako patch.

## 28.10.2026 – Prototyp v Godotu
- **Godot 4.7.2** (verze na Tomově počítači). Repozitář `tomaspatolan-bit/roguelike`, práce na větvích.
- **Testy běží na Tomově počítači přes Blender MCP**, protože v cloudu Godot stáhnout nejde. Postup v `CLAUDE.md`.
- **Obsah jako JSON** v `data/` (jednotky, rod Vlka, scénář). Simulace bitvy oddělená od scény, aby šla testovat bez okna.
- **Barva role přes řádek palety** (shader `knight_palette.gdshader`): jeden model rytíře pro všechny role.

## 28.10.2026 – Tým a engine
- **Tým:** Tom + Claude. Tom = ředitel, designér, tester, art direction, business. Claude = kód, data a obsah, simulace balancu, technická práce v Blenderu, dokumentace a plánování.
- **Engine: Godot 4** (místo Unrealu). Důvod: scény i skripty jsou čitelný text, takže Claude může projekt přímo upravovat, testovat a hlídat. Model rytíře jde do Godotu přes `SK_Knight.glb`.
- **Pracovní paměť:** `CLAUDE.md`, `docs/stav.md` (aktuální sprint) a tento deník. Bez zápisu rozhodnutí neexistuje.

## 26.10.2026 – Grafika a pipeline
- Stylizovaný low-poly rytíř z tuhých dílů, paletová textura s řádky pro role, kostra s 27 kostmi. Herní síť ~5 400 trojúhelníků, LOD1 ~2 200.
- Steam: obsah vytvořený AI (grafika, texty, zvuk) se musí uvést na stránce hry; AI nástroje pro kód a vývoj se neuvádějí.

## 25.10.2026 – Koncept a bitva
- Háček: rod → prapor → přísahy rytířů, padlí odkazují přísahy a výbavu nástupcům.
- Bitva: hybrid. Příprava (rozestavení, postoje) + bitva běží sama + pokřiky praporu za slávu (bez zastavení času) + 1–2 signály praporu (zastavení času). Pravidla „když–pak“ jen pokud prototyp ukáže potřebu.
- Pilíře: velíš rodu, ne vojákovi · prapor je srdce oddílu · přísaha má cenu · každý run je příběh rodu.
- Webové demo „Most přes řeku“: bez pokřiků se prohrává, s nimi vyhrává. Zjištění: útočný postoj vede ke ztrátám mimo auru praporu; střelci + kněz můžou vytvořit pat.
