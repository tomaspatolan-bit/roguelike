# Plán vývoje (stepper)

Postupujeme krok za krokem. Krok je hotový, až splní „Hotovo, když“. Do další fáze se jde až po bráně (rozhoduje Tom). Nové nápady nepatří sem, ale do `napady.md`.

Značení: [x] hotovo · [ ] zbývá · (Tom) = rozhoduje nebo dělá Tom

## Fáze 0 – Základ
- [x] 0.1 Koncept, pilíře, model bitvy (příprava + pokřiky + signály)
- [x] 0.2 Webové demo bitvy a vyladění balancu simulací
- [x] 0.3 Rytíř v Blenderu: herní síť, kostra, paleta, export
- [x] 0.4 Repozitář, Godot projekt, testy na Tomově počítači
- [x] 0.5 Paměť projektu: `CLAUDE.md`, kontextové soubory, plán, deníky

## Fáze 1 – Bitva, která baví  ← teď
Cíl: jedna bitva, kterou chceme hrát opakovaně.
- [x] 1.1 První build: Most přes řeku v Godotu
- [ ] 1.2 Playtest (Tom): 3–5 bitev, zápis do `playtesty.md`
  - [x] První dojmy (2026-10-28): přísaha vs. postoje, kamera, přesouvání rytířů
  - [ ] Baví to? Co je nečitelné? Kdy se nudím?
  - [x] Signály: nahrazeny pauzou kdykoli (29.10.2026)
  - [ ] Je jasné, proč jsem prohrál?
- [ ] 1.3 Úpravy podle playtestu
  - [x] Přísaha určuje povolené postoje („Stát pevně“, Chránit prapor zakázán)
  - [x] Kamera: WASD, šipky, posun pravým tlačítkem; signál na mezerník
  - [x] Drag & drop rytířů, výběr podle postavy na obrazovce, prohození puštěním
  - [x] Prapor nese kterákoli třída (volba v rozestavení, nepředává se), efekt podle třídy, nositel nemá Chránit prapor
  - [x] Asasín místo praporečníka, jádro 5 tříd
  - [x] Nikdo nestojí bez práce: Držet pozici jde pomoct bojujícímu spolubojovníkovi
  - [x] Morálka nepřátel, povel Do boje!, pojistka dobojování
  - [ ] Další body podle dalšího playtestu
- [ ] 1.4 Čitelnost boje
  - [ ] Animace útoku, zásahu a smrti (zástupné)
  - [ ] Vlastní ikonky pasivek a stavů (teď stejná hvězdička; návrh Tom)
  - [ ] Ukazatel postupu volitelného úkolu
- [ ] 1.5 Druhá bitva s jiným terénem a více průchody (ověří, že data a scéna nejsou šité na jeden scénář)
  - [x] Brod a les: dva brody, lávka, les se stezkou; výběr bitvy v rozestavení
  - [x] Trasy rytířů: kreslení čarou zjednodušenou na 2–4 body, platí od startu bitvy
  - [x] Vlastnosti nepřátel (Zoufalec, Fanatik, Zbabělec) a kopiníci (proti jízdě)
  - [x] Nepřátelé drží pozice (brody, střelci na břehu), pěšák po zásahu vyrazí i se skupinou
  - [ ] Playtest druhé mapy (Tom)
- [x] 1.6 Postoje na míru třídám (2 na třídu, data), testy obou scénářů v testu balancu
- [x] 1.6b UI: lišta velení, karty rytířů, ikonky stavu (zástupné; Tom převezme návrh)
- [x] 1.6c Přestavba bitvy na hrdiny (změna směru 28.10.2026)
  - [x] Návrh hrdinů ke schválení (dokument „Rod Vlka a jeho hrdinové“)
  - [x] Odstranit prapor, pokřiky a postoje ze simulace, dat, scény a UI
  - [x] Schopnosti hrdinů (data), cílení z karty, sláva jako použití navíc
  - [x] Pevné výchozí chování tříd
  - [x] Balanc obou map, testy
  - [x] Pasivky a přísahy (15 + 3) v datech a simulaci, na zkoušku v rozestavení
- [x] 1.7 Zkušební běh (celý loop v malém)
  - [x] 3 bitvy za sebou: Most přes řeku → Brod a les → Tábor na Vraní skále s vůdcem (Hejtman Kuno)
  - [x] Mezi bitvami odměna 1 ze 3: pasivka nebo přísaha pro konkrétního hrdinu (15 + 3 hotové)
  - [x] Následky: padlí zůstanou mrtví, zranění se vyléčí, sláva se přenáší, nástupce a dědictví přísahy padlého hrdiny
  - [x] Uprchlíci z bitev 1 a 2 se vrátí v závěrečné bitvě
  - [x] Prohra: bitva se prohrává, jen když padnou všichni, a tím běh končí (ztráty po vítězství nahradí nástupci)
  - [x] Kronika rodu na konci běhu (kdo padl, kdo co přísahal, kdo utekl a vrátil se)
  - [x] Bez výběru rodu, meta progrese, ukládání a finální grafiky
- [ ] 1.8 Playtest běhu: Tom + aspoň jeden hráč mimo nás
  - Otázka k testu: **zvládá hráč bitvu v reálném čase s pauzou?** Používá pauzu, nebo kliká v běhu? Stíhá reagovat na nepřítele?
- [ ] (podle 1.8) Podmíněné instrukce a úmysly nepřátel, jen když postoje na míru nestačí
**Hotovo, když:** Tom řekne, že bitvy baví hrát opakovaně, a aspoň jeden člověk mimo nás to potvrdí.
**Brána 1: prošla 29.10.2026** (Tom, odměny vážně zvažoval; hráč mimo nás zatím chybí, doplní se).
**Brána 1 (Tom), podle zkušebního běhu:** chceš hned další běh? pamatuješ si z běhu příběh? rozhodoval ses mezi odměnami? potvrdí to hráč mimo nás? → pokračujeme, nebo měníme model hry?

## Fáze 2 – Jeden run
Cíl: celý krátký run od výběru rodu po bosse.
- [x] 2.1 Mapa aktu: uzly bitva, elita, událost, tábor, boss (kovář odložen, až bude výbava); zranění se nesou
- [x] 2.2a Typ bitvy (útok, střet, obrana) řídí výchozí chování oddílu; mířené Požehnání
- [x] 2.2b První obranná mapa (vlny): Obrana Lesní vsi
- [x] 2.2c Rozkazy pro hrdiny (29.10.2026): na místo, na skupinu nepřátel, ke spojenci, bez rozkazu drží místo; rozkazy kdykoli (od 29.10.2026 reálný čas s pauzou, výběr hrdinů a pravé tlačítko); pojmenované skupiny nepřátel; trasy a výchozí chování zrušeny. Hotovo, když: Tom odehraje bitvu každého typu jen s rozkazy a nikdo nestojí bez práce.
- [x] 2.2d Bitva ve fázích (29.10.2026): skupinky nepřátel se probouzejí postupně, polovina nepřátel, velitel v každé bitvě s ohlášenou schopností, nejvýš 3 pěší na hrdinu, schopnosti s pevným počtem a nabíjením, kněz léčí jen v boji. Hotovo, když: Tom odehraje bitvu a nevidí shluky ani prolínání; balanc všech scénářů prošel.
- [ ] 2.2 Karta stage a volitelné úkoly z dat
- [ ] 2.3 Odměny po stagi: pasivky, přísahy, nové schopnosti (2. a 3. slot u hrdiny)
- [ ] 2.4 Více pasivek, přísah a schopností (obsah)
- [ ] 2.5 Další rody jako sestavy: Medvěd (berserkr), Sokol (sokolník); meta odemykání rodů
- [ ] 2.6 Ústup s přeživšími, rozhodnutí, jestli prohraná bitva končí běh; najímání vojáků k hrdinům
- [ ] 2.9 Průzkum: odhalování podmínek nepřátel jako zdroj v runu
- [ ] 2.7 Ukládání a načtení rozehraného runu
- [ ] 2.8 Generátor bitev (scénáře z dílků místo ručně psaných)
**Hotovo, když:** jde odehrát run o 6–8 stagích s bossem a rozhodnutí na mapě mají smysl.
**Brána 2 (Tom):** je run zábavný jako celek?

## Fáze 3 – Vizuální identita a zvuk
- [ ] 3.1 Finální styl (Tom schvaluje): rytíř, nepřátelé, prostředí
- [ ] 3.2 Kůň pro jezdce, sada nepřátel, kit bojiště (les, vesnice, most, pahorek)
- [ ] 3.3 Animace boje (zástupné hotové 29.10.2026: útok podle třídy, schopnost, zásah, smrt; finální podle stylu)
- [ ] 3.4 Styl UI
- [ ] 3.5 Zvuky a hudba (koupit nebo zadat, Tom)
**Hotovo, když:** snímek obrazovky vypadá jako hra, kterou by si člověk koupil.

## Fáze 4 – Obsah a Steam stránka
- [ ] 4.1 Firma a Steamworks (Tom)
- [ ] 4.2 Capsule art a trailer (zadat, Tom)
- [ ] 4.3 Steam stránka, sbírání wishlistů
- [ ] 4.4 Obsah: 2–3 rody, 3 akty, 20+ přísah a znamení
- [ ] 4.5 Meta progrese mezi runy
- [ ] 4.6 Playtesty s lidmi zvenku každý měsíc

## Fáze 5 – Demo a Next Fest
- [ ] 5.1 Demo (první akt), registrace na Next Fest (Tom)
- [ ] 5.2 Oslovení streamerů
- [ ] 5.3 Lokalizace do angličtiny

## Fáze 6 – Vydání
- [ ] 6.1 Early Access, nebo 1.0 (Tom)
- [ ] 6.2 Ladění výkonu, gamepad, Steam Deck
- [ ] 6.3 Vyplnit evidenci AI obsahu na Steamu (podklady v `context/grafika.md`)
