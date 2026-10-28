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
  - [ ] Signály: 0, 1, nebo 2?
  - [ ] Je jasné, proč jsem prohrál?
- [ ] 1.3 Úpravy podle playtestu
  - [x] Přísaha určuje povolené postoje („Stát pevně“, Chránit prapor zakázán)
  - [x] Kamera: WASD, šipky, posun pravým tlačítkem; signál na mezerník
  - [x] Drag & drop rytířů, výběr podle postavy na obrazovce, prohození puštěním
  - [x] Prapor nese kterákoli třída (volba v rozestavení, nepředává se), efekt podle třídy, nositel nemá Chránit prapor
  - [x] Asasín místo praporečníka, jádro 5 tříd
  - [x] Nikdo nestojí bez práce: Držet pozici jde pomoct bojujícímu spolubojovníkovi
  - [ ] Další body podle dalšího playtestu
- [ ] 1.4 Čitelnost boje
  - [ ] Animace útoku, zásahu a smrti (zástupné)
  - [ ] Zvýraznění aktivního pokřiku a dosahu praporu
  - [ ] Ukazatel postupu volitelného úkolu
- [ ] 1.5 Druhá bitva s jiným terénem a více průchody (ověří, že data a scéna nejsou šité na jeden scénář)
  - [ ] Trasy rytířů: kreslení čarou zjednodušenou na 2–4 body, platí od startu bitvy
- [ ] 1.6 Testy: oba scénáře v testu balancu
- [ ] 1.7 Podmíněné instrukce a úmysly nepřátel
  - [ ] Slovník podmínek a akcí v datech, 1 instrukce na rytíře, kontrola přísah
  - [ ] Nepřátelé používají stejný slovník, jejich trasy a podmínky jsou vidět před bitvou
**Hotovo, když:** Tom řekne, že bitvy baví hrát opakovaně, a aspoň jeden člověk mimo nás to potvrdí.
**Brána 1 (Tom):** pokračujeme, nebo měníme model bitvy?

## Fáze 2 – Jeden run
Cíl: celý krátký run od výběru rodu po bosse.
- [ ] 2.1 Mapa aktu: uzly bitva, elita, událost, tábor, kovář, boss
- [ ] 2.2 Karta stage a volitelné úkoly z dat
- [ ] 2.3 Odměny po stagi: 1 ze 3 (znamení na prapor nebo přísaha)
- [ ] 2.4 Prapor se sloty pro znamení, přísahy jednotlivých rytířů (data + simulace)
- [ ] 2.5 Postupné odemykání: rod → prapor → přísahy
- [ ] 2.6 Smrt rytíře, nástupce a dědictví přísahy; prohra bitvy = ztráty a ústup, ne opakování
- [ ] 2.9 Průzkum: odhalování podmínek nepřátel jako zdroj v runu
- [ ] 2.7 Ukládání a načtení rozehraného runu
- [ ] 2.8 Generátor bitev (scénáře z dílků místo ručně psaných)
**Hotovo, když:** jde odehrát run o 6–8 stagích s bossem a rozhodnutí na mapě mají smysl.
**Brána 2 (Tom):** je run zábavný jako celek?

## Fáze 3 – Vizuální identita a zvuk
- [ ] 3.1 Finální styl (Tom schvaluje): rytíř, nepřátelé, prostředí
- [ ] 3.2 Kůň pro jezdce, sada nepřátel, kit bojiště (les, vesnice, most, pahorek)
- [ ] 3.3 Animace boje
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
