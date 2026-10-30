# Deník playtestů

Nejnovější nahoře. Každý záznam: datum, kdo hrál, build (větev nebo commit), co se dělo, co bavilo, co ne, co z toho plyne.

Šablona:

```markdown
## RRRR-MM-DD – kdo, build
- Odehráno: kolik bitev, výsledky, nastavení (signály, rozestavení)
- Bavilo:
- Nebavilo / nečitelné:
- Překvapilo:
- Z toho plyne (úkol v plan.md / nápad v napady.md / rozhodnutí):
```

## 30.10.2026 – Tom, build `faze2-mapa` (27074b9), pravé tlačítko provádí akci
- Bavilo: „feeluje o dost lépe“, ovládání dostal do ruky rychle. Slib odříkání je přesně směr odměn: interakce mezi hrdiny, odměna i riziko.
- Nebavilo / nečitelné: na kartě zbytečný text rozkazu a Poslat; u schopnosti chybí klávesa.
- Z toho plyne: karta bez rozkazů, klávesa na tlačítku schopnosti, H drží místo; směr odměn do deníku rozhodnutí a plánu (2.4).

## 30.10.2026 – Tom, build `faze2-mapa` (48553b2), kamera s pevným úhlem
- Nebavilo / nečitelné: rozkaz se dává pravým, ale cílená schopnost levým tlačítkem („ux fail“).
- Z toho plyne: pravé tlačítko provede i schopnost a rozkaz z tlačítka Poslat.

## 30.10.2026 – Tom, build `faze2-mapa` (3d1ac35), bitva ve fázích
- Bavilo: shluky jsou v pohodě.
- Nebavilo / nečitelné: „mega těžký“, nepřešel ani první bitvu. Nešel odznačit celý oddíl, často misclick. Trochu prolínání pořád je, hlavně na mostě (spíš design mapy).
- Nápad (Tom): ovládat hrdiny jen z karet, ne klikáním na bojišti.
- Z toho plyne: každá schopnost 3× za bitvu; výběr a rozkazy podle zvyklostí RTS (klik vybere jen hrdinu, bez přetahování v bitvě, Ctrl+A, náhled pravého tlačítka); most na mapách širší nebo víc přechodů (napady.md).

## 29.10.2026 – Tom, build `faze2-mapa` (22e78a5), barvy hrdinů a uhýbání
- Nebavilo / nečitelné: nepřátel je moc, vznikají situace, kdy je spousta lidí na jednom místě, a nefeeluje to dobře (shluky, prolínání).
- Nápady (Tom): polovina nepřátel, ale každá bitva má svého „bosse“ nebo významnější postavy; skupinky nepřátel potkávat postupně (most → 2 strážci → kemp se zbytkem), tím odpadne plánování kromě obrany; omezit schopnosti pevným počtem a nabíjením místo slávy (léčení 1× za mapu, Nájezd 1×), aby se nešlo po každé skupince doléčit.
- Z toho plyne: bitva ve fázích se skupinkami, místa kolem hrdiny (nejvýš 3 pěší), schopnosti s pevným počtem, kněz léčí jen v boji, velitelé s ohlášenými schopnostmi, přeladění všech bitev (viz deník rozhodnutí).

## 29.10.2026 – Tom, build `faze2-mapa` (ffbe96c), reálný čas s výběrem tažením
- Bavilo: funguje relativně dobře.
- Nebavilo / nečitelné: jednotky při pohybu procházejí skrz sebe (clipping); asasín po Úderu ze stínu skočí, ale vrátí se a jde útočit odjinud; čáry rozkazů nejsou potřeba, stačí kruh, kam jsem ukázal; hrdinové nejdou rozlišit.
- Z toho plyne: uhýbání spojencům, krátké setrvání na cíli po skoku a nájezdu, kruhy cílů a barvy hrdinů v UI.

## 29.10.2026 – Tom, build `faze2-mapa` (c87e73e), reálný čas s pauzou
- Bavilo: „o hodně víc“ než rozkazy předem.
- Chybí: výběr víc hrdinů tažením. Hrdina v boji neodejde, i když dostane rozkaz.
- Z toho plyne: obdélník výběru; rozkaz na místo jde bez boje, na skupinu bojuje jen s ní.

## 29.10.2026 – Tom, rozhovor o rozkazech (build `faze2-mapa` 9b4b921)
- Nebavilo: rozkazy předem a změna jen při signálu působí divně; hráč musí reagovat na nepřítele, jinak prohraje kvůli tomu, co nemohl předvídat.
- Z toho plyne: rozhodnutí „Bitva v reálném čase s pauzou“.

## 29.10.2026 – Tom, rozhovor o ovládání (po buildu `faze2-mapa` c1db378)
- Nebavilo: asasín má zabudované chování, že rushuje dopředu; ve střetu všichni stojí na místě a působí to divně. Výchozí chování neodpovídá všem typům bitev.
- Návrh Toma: smazat trasy, řídit se tím, kam hráč hrdiny vyšle; kdo nedostane rozkaz, nic nedělá. Signál použít ke změně rozkazů, v tutoriálu vysvětlit.
- Z toho plyne: rozhodnutí „Rozkazy místo tras a výchozího chování“, krok 2.2c.

## 29.10.2026 – Tom, build `faze2-mapa` (7ab345d), obrana a ragdoll
- Nebavilo: v obraně se hrdinové vůbec nehýbou a v jednu chvíli (asi po vyhrané vlně) se zastaví úplně.
- Příčina: tank s přísahou Nikdy neustoupí stál kousek za hranicí obrany, nesměl se vrátit a ostatní mu nepomohli, protože nepřítel byl „mimo obranu“; nepřítel ho bil a bitva stála.
- Z toho plyne: oprava pravidel obrany (pomoc oddílu, dorazit nepřítele stranou), odpočet vlny v liště.

## 29.10.2026 – Tom, build `prapor-asasin` (b39f103), zkušební běh
- Odehráno: celý zkušební běh.
- Bavilo: funguje „fakt skvěle“, povedený celek.
- Nebavilo / nečitelné:
  - Bez trasy všichni kromě asasína stojí; rozběhnou se, až tank někoho uvidí. Lučištník, kněz a jezdec do prvního kontaktu kmitají. Kněz celou bitvu stojí a nic nedělá.
  - Schopnosti jdou za slávu použít neomezeně, Požehnání je pak přesilné (dá se přeléčit k vítězství).
- Z toho plyne: klidová místa s tolerancí (proti kmitání), lučištník couvá, dokud nemá odstup, oddíl nechodí za asasínem, kněz za vodou jde k bojujícímu přes přechod a když nikdo nepotřebuje léčit, pomáhá v boji. Schopnost navíc za slávu jen jednou za bitvu, Požehnání se 20 s nabíjí, do další bitvy si rod nese nejvýš 50 slávy. Test kmitání v `test_battle_sim.gd`.

## 28.10.2026 – Tom, build `prapor-asasin` (20ce480), bitva na hrdiny
- Odehráno: Most a Brod se schopnostmi hrdinů.
- Bavilo: funguje celkem dobře; přímé ovládání schopností, hlavně mířená Salva lučištníka a Nájezd jezdce s omráčením.
- Z toho plyne: směr hrdinů se schopnostmi potvrzen. Další krok: pasivky a přísahy jako odměny (návrh ke schválení), pak zkušební běh. Otevřené: sláva pro kněze (léčení), úkol „Nikdo nepadne“ na Brodu.

## 2026-10-28 – Tom, build `prvni-build` (f6073a4)
- Odehráno: první bitvy, hra funguje.
- Nebavilo / nečitelné:
  - Rytíř s přísahou „Nikdy neustoupí“ měl na výběr „Držet pozici“; nedávalo smysl. (Postoj ho navíc vracel na místo, což je vlastně ústup.)
  - Kamera jde otáčet, ale ne posouvat (šipky nikdo nečeká).
  - Přesouvání rytířů v rozestavení klikáním: spousta chybných kliků. Běžný hráč by měl problém.
- Z toho plyne:
  - Rozhodnutí: přísaha určuje povolené postoje, „Nikdy neustoupí“ = varianta A (Stát pevně, Chránit prapor zakázán).
  - Nápad: přísaha „Jen vpřed“ (jen útočný postoj) do `napady.md`.
  - Úkoly 1.3: kamera WASD a pravé tlačítko, drag & drop s výběrem podle obrazovky, signál na mezerník. Hotovo.
