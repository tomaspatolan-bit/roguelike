# Kontext: rozhraní

Soubory: `scripts/battle/battle_ui.gd`, `scripts/battle/ui_icon.gd`, `scripts/ui/ui_theme.gd` (vzhled), `scripts/ui/icon_svg.gd` (tvary ikon), `art/fonts/`
Hlídá: `tests/screenshot_battle.gd` (snímky panelu)

## Účel
Vykreslit stav a poslat úmysly hráče signálem. Nerozhoduje o pravidlech.

## Invarianty
1. **Žádná herní logika.** UI nemění simulaci, jen emituje signály, které zpracuje `battle.gd`.
2. **Signály:** `tutorial_skip_pressed`, `tutorial_ok_pressed`, `knight_clicked`, `ability_pressed`, `passive_toggled`, `ability_chosen` (volná bitva: zkusit jinou schopnost třídy), `scenario_changed`, `order_pressed`, `order_clear_pressed`, `start_pressed`, `pause_pressed`, `charge_pressed`, `resume_pressed`, `speed_changed`, `continue_pressed`, `retry_pressed`, `redeploy_pressed`, `run_continue_pressed`.
3. **Rozvržení:** nahoře uprostřed lišta velení (`top_row`: v rozestavení a úvodní pauze Začít bitvu; v bitvě čas, Pauza / Pokračovat, rychlost a za oddělovačem morálka nepřítele s All In!), vlevo nahoře karta bitvy (`info_box`), dole karty hrdinů (`cards_row`), vpravo nahoře sbalitelný deník. Přestavuje se jen při změně stavu (`show_deploy`, `show_battle`); plynulé věci aktualizuje `update_dynamic` (každých 0,1 s) a `update_hp_bars` (každý snímek). Ikonky se mění jen při změně podpisu (`_sig`).
4. **Hráč se soustředí na hrdiny:** žádné bonusy pro celý oddíl v UI. Musí vždy vidět: použití a nabíjení schopností na kartách, stav úkolu, zda čas stojí (pauza).
5. **Texty anglicky** (od 07.11.2026, názvy podle `docs/glosar.md`), krátce. Zkratky kláves na tlačítkách odpovídají `battle.gd`.
6. **Vzhled Royal Court Enamel** (od 07.11.2026, podle Figmy): barvy, písma a styly jen z `ui_theme.gd` (konstanty = proměnné Figmy „Oathline UI“, `UI.box`, `UI.panel_box`, `UI.primary`, `UI.label`, `UI.title`, `UI.eyebrow`, `UI.make_theme`). Světlé enamel panely s tmavým obrysem 2 px a tvrdým stínem, primární tlačítko červené (accent/oath). Písma OFL v `art/fonts/`: Inter (UI, variabilní, váha přes `FontVariation`), Cinzel (nadpisy verzálkami), EB Garamond (příběhový text, kurzíva). Bez souboru písma se použije systémové. Konstanty `INK`, `MUTED`, `GLORY`… v `battle_ui.gd` zůstávají jako přezdívky (půjčuje si je `run_main.gd`).
7. **Karta hrdiny:** rámeček a jméno v barvě hrdiny (`color` z dat; vybraný silnější rámeček), ikona třídy, zdraví, ikonky stavu a tlačítko schopnosti s použitími (●), nabíjením („●● 12 s“) nebo „vyčerpáno“ a s klávesou 1–5 v rámečku (`_add_keycap`, pořadí karet = `_ability_by_index`); při cílení je tlačítko zvýrazněné. Text rozkazu, Poslat ani ✕ na kartě nejsou (zrušeno 30.10.2026, Tom: ovládání pravým tlačítkem stačí; rozkaz je vidět kruhem cíle). V rozestavení a úvodní pauze menu Pasivky (na zkoušku, zaškrtávací) a ve volné bitvě menu Schopnost (tři schopnosti třídy). Nové schopnosti mají zatím ikonu své třídy (`ABILITY_ICONS`). Ikonky pasivek a přísahy s popisem, ikonka „Vlastnosti“ s bonusy k Útoku, Moci, Odolnosti a Pohotovosti (`sim.stats_of`). Ikonka pouta (typ, druh, úroveň, efekt a žal). Za kartami panel „Komba pout“ (`_build_combos`): tlačítko s klávesou Q/E, názvem komba a dvojicí, neaktivní s důvodem v popisku (`sim.combo_problem`). Dialog přísahy (`ask_oath(jméno, přísaha, proč, porušit, zachovat, text tlačítka)`) je vlastní enamel karta se závojem přes bojiště: proč by se přísaha porušila, POWER a RESTRICTION (`power`, `restriction` z dat přísahy) a IF BROKEN (cena ve slávě); Keep the oath / Break the oath, Esc přísahu zachová (`oath_open`, `oath_keep` pro `battle.gd`). Klik na kartu = výběr hrdiny (Shift přidá); vybraní mají zvýrazněný rámeček (`selection`).
8. **Žádné tlačítko nesmí brát fokus klávesnice** (`_no_focus` po každé přestavbě panelu).
9. **Morálka a All In!** (`_build_morale`, stav z `sim.morale_state()`, přestaví se jen při změně stavu): **A** ukazatel ztrát nepřítele s hranicí zlomu (výchozí 70 %, „More waves coming“ dokud přijdou vlny) a zámek s popiskem; **B** při zlomení jednorázové odhalení (nápověda nahoře a záblesk tlačítka); **C** tlačítko All In! [F] se štítkem ONCE a odpočtem „auto in 18 s“; **D** „All In! given“ (dal hráč); **E** „The heroes charged on their own“ (pojistka simulace).
10. **Rozestavení a úvodní pauza** (`t == 0`): vlevo nahoře výběr bitvy a nápověda; v bitvě karta ukazuje, kolik skupinek ještě čeká („Dál čeká nepřátel: skupinek N“). Výběr bitvy (`scenario_choices` nastavuje `battle.gd`). Výsledek bitvy bere nadpis ze scénáře (`win_title`) a ukáže, kdo přinesl nejvíc slávy.
11. **Ikonky** (`ui_icon.gd`): ikony Oathline z Figmy jsou SVG cesty v `icon_svg.gd`, za běhu se rasterizují (`Image.load_svg_from_string`, bez importu) a tónují barvou; staré názvy převádí `ALIAS`. Bez SVG (rozkazy, Fanatik, Zbabělec) zůstává vektorová kresba. Nad jednotkami mají ikony světlý kruhový podklad s obrysem (`plate`). Karta hrdiny: světlá s tmavým obrysem, proužek barvy hrdiny nahoře, vybraná má zlatý rámeček a značku nad kartou. Nad hlavou tmavý podklad zdraví, hrdinové s rámečkem své barvy. třída, schopnosti (`ABILITY_ICONS`), stav z `_status_icons` (přísaha/zlomená, Výzva, rozkaz: drží místo / jde na místo / na skupinu / se spojencem; zaklesnutý v boji (zámek, Nikdy neustoupí); u nepřátel omráčený, spí („Hlídá…“), velitel (zlatá), chystá schopnost, zoufalý, prchá, Fanatik, Zbabělec, kopí). Každá má popisek.
12. **`flash_hint(text, s = 2)`:** krátká nápověda nahoře uprostřed (např. proč cíl nejde), sama zmizí.

13. **Režim běhu** (`run_mode`): bez výběru bitvy, menu Pasivky jen ukazuje, co hrdina má, nad názvem bitvy `run_label` („Zkušební běh · bitva 2 ze 3“), výsledek má jediné tlačítko „Pokračovat v běhu“ / „Kronika rodu“.
14. **Dialog před bitvou** je zrušený (bitva začíná v pauze, hrdina bez rozkazu drží místo).
16. **Výcvik** (`show_tutorial`, `hide_tutorial`, signály `tutorial_skip_pressed`, `tutorial_ok_pressed`): karta přišpendlená šipkou a kroužkem k cíli kroku (`point_tutorial(bod)`: nad cílem, nebo pod ním v horní polovině obrazovky; bez cíle vpravo pod deníkem) s krokem („VÝCVIK · krok 2 z 7“), textem z dat, Přeskočit výcvik a u posledního kroku Rozumím. Nezakrývá hrdiny ani nepřátele u mostu.
15. **Obdélník výběru** (`select_box`, `show_box`, `hide_box`): při tažení levým tlačítkem na zemi.

17. **Figma** (soubor Roguelike, `https://www.figma.com/design/ac4cRXkaZhJ0qwnMuhiO6p`): cílový vzhled je **Royal Court Enamel** (světlé téma, od 07.11.2026): tokeny v kolekci „Oathline UI“, textové styly UI/*, stránky Oathline UI · Foundations / Components / Screens / Icons. Správa (mapa, odměny, události, tábor, stránka rodu, kronika) je světlá a slavnostnější, bitevní HUD světlý a kompaktní s tmavým obrysem. All In! je povel v liště (stavy A–E), ne schopnost. Padlí mají jen pamětní desku v sekci The Fallen. První tmavá verze zůstává na stránkách „v0“. Obrazovky běhu jsou ve Figmě taky (07.11.2026): sekce „Section · Run screens“ na stránce Components (Offer card, Bond offer card, Event option, Camp choice card, Hero picker tile, Glory chip, House button, Map info card, Chronicle entry, Roster panel, Legacy header) a na stránce Screens titul, mapa aktu, odměna, elita, pouto, dědictví přísahy, událost a její výsledek, tábor a výběr hrdiny, kronika a výsledek bitvy; ikony doplněné jen o použité (Camp/Rest, Training, Rite, Feast, HUD/Chronicle, HUD/House). Vzhled je přenesený do hry (07.11.2026: `battle_ui.gd`, `run_main.gd`, `map_view.gd`); když se změní obsah obrazovky ve hře, upravit i komponenty.

## Úskalí
- Kořenový `Control` má `mouse_filter = IGNORE`, jinak spolkne kliky do scény.
- Místní proměnná se nesmí jmenovat jako metoda `CanvasLayer` (`hide`, `show`).

## Historie významných změn
- 07.11.2026: přenesen vzhled Royal Court Enamel (`ui_theme.gd`, písma, SVG ikony), morálka nepřítele a All In! ve stavech A–E, vlastní dialog přísahy s POWER / RESTRICTION / IF BROKEN.
- 07.11.2026: menu Schopnost ve volné bitvě, ikony nových schopností (zástupné podle třídy).
- 07.11.2026: texty a komentáře přeložené do angličtiny (`docs/glosar.md`).
- 30.10.2026: panel výcviku.
- 30.10.2026: karta bez textu rozkazu, Poslat a ✕; klávesa schopnosti v rámečku na tlačítku.
- 29.10.2026: bitva ve fázích: pryč ukazatel slávy a dialog před bitvou, schopnost ukazuje použití a nabíjení, ikonky spící skupinky, velitele a chystané schopnosti, počet čekajících skupinek, úvodní pauza s výběrem bitvy.
- 29.10.2026: barvy hrdinů: rámeček karty a jméno, rámeček ukazatele zdraví nad hlavou.
- 29.10.2026: obdélník výběru tažením.
- 29.10.2026: reálný čas: tlačítko Pauza místo signálu (ikona pauzy), bez volby počtu signálů a řádku Signály ve výsledku, karty zvýrazní všechny vybrané, Poslat i v bitvě.
- 29.10.2026: rozkazy: karta ukazuje rozkaz místo výchozího chování, Poslat a ✕ místo Trasy, dialog před bitvou bez rozkazů, popis rozkazů v kartě bitvy.
- 29.10.2026: v obraně ukazuje lišta odpočet další vlny („vlna za 12 s“).
- 29.10.2026: karta bitvy ukazuje typ bitvy (útok, střet, obrana) s popisem; Požehnání se míří kruhem jako Salva.
- 29.10.2026: tlačítko schopnosti ukazuje nabíjení („12 s“) a „vyčerpáno“, nápověda řekne proč schopnost nejde (`ability_problem`).
- 28.10.2026: režim běhu (`run_mode`, `run_label`, `run_continue_pressed`).
- 28.10.2026: přestavba na hrdiny: pryč pokřiky, postoje a prapor; schopnost na kartě s použitími a cenou ve slávě, cílení, nápověda.
- 28.10.2026: nové rozvržení (lišta velení, karty rytířů dole, deník vpravo nahoře), vektorové ikonky stavu nad hlavami a na kartách. Tom si UI převezme a navrhne.
- 28.10.2026: tlačítko Do boje! po zlomení morálky.
- 28.10.2026: tlačítko Prapor v rozestavení, popisky postojů, „běží pro prapor“ v soupisce.
- 2026-10-28: postoje podle přísahy, mezerník v popiscích, tlačítka bez fokusu.
- 2026-10-28: založeno.
