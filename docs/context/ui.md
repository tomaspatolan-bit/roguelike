# Kontext: rozhraní

Soubory: `scripts/battle/battle_ui.gd`
Hlídá: `tests/screenshot_battle.gd` (snímky panelu)

## Účel
Vykreslit stav a poslat úmysly hráče signálem. Nerozhoduje o pravidlech.

## Invarianty
1. **Žádná herní logika.** UI nemění simulaci, jen emituje signály, které zpracuje `battle.gd`.
2. **Signály:** `knight_clicked`, `ability_pressed`, `passive_toggled`, `scenario_changed`, `order_pressed`, `order_clear_pressed`, `start_pressed`, `pause_pressed`, `charge_pressed`, `resume_pressed`, `speed_changed`, `continue_pressed`, `retry_pressed`, `redeploy_pressed`, `run_continue_pressed`.
3. **Rozvržení:** nahoře uprostřed lišta velení (`top_row`: v rozestavení a úvodní pauze Začít bitvu; v bitvě čas, Pauza / Pokračovat, Do boje!, rychlost), vlevo nahoře karta bitvy (`info_box`), dole karty hrdinů (`cards_row`), vpravo nahoře sbalitelný deník. Přestavuje se jen při změně stavu (`show_deploy`, `show_battle`); plynulé věci aktualizuje `update_dynamic` (každých 0,1 s) a `update_hp_bars` (každý snímek). Ikonky se mění jen při změně podpisu (`_sig`).
4. **Hráč se soustředí na hrdiny:** žádné bonusy pro celý oddíl v UI. Musí vždy vidět: použití a nabíjení schopností na kartách, stav úkolu, zda čas stojí (pauza).
5. **Texty česky,** krátce. Zkratky kláves na tlačítkách odpovídají `battle.gd`.
6. **Font:** systémový (Segoe UI na Windows), musí umět českou diakritiku.
7. **Karta hrdiny:** rámeček a jméno v barvě hrdiny (`color` z dat; vybraný silnější rámeček), ikona třídy, zdraví, ikonky stavu a tlačítko schopnosti s použitími (●), nabíjením („●● 12 s“) nebo „vyčerpáno“ a s klávesou 1–5 v rámečku (`_add_keycap`, pořadí karet = `_ability_by_index`); při cílení je tlačítko zvýrazněné. Text rozkazu, Poslat ani ✕ na kartě nejsou (zrušeno 30.10.2026, Tom: ovládání pravým tlačítkem stačí; rozkaz je vidět kruhem cíle). V rozestavení a úvodní pauze menu Pasivky (na zkoušku, zaškrtávací). Ikonky pasivek a přísahy s popisem. Klik na kartu = výběr hrdiny (Shift přidá); vybraní mají zvýrazněný rámeček (`selection`).
8. **Žádné tlačítko nesmí brát fokus klávesnice** (`_no_focus` po každé přestavbě panelu).
9. **Povel Do boje!** se ukáže až po zlomení morálky nepřítele (klávesa F).
10. **Rozestavení a úvodní pauza** (`t == 0`): vlevo nahoře výběr bitvy a nápověda; v bitvě karta ukazuje, kolik skupinek ještě čeká („Dál čeká nepřátel: skupinek N“). Výběr bitvy (`scenario_choices` nastavuje `battle.gd`). Výsledek bitvy bere nadpis ze scénáře (`win_title`) a ukáže, kdo přinesl nejvíc slávy.
11. **Ikonky** (`ui_icon.gd`, vektorově, zástupné; finální navrhne Tom): třída, schopnosti (`ABILITY_ICONS`), stav z `_status_icons` (přísaha/zlomená, Výzva, rozkaz: drží místo / jde na místo / na skupinu / se spojencem; u nepřátel omráčený, spí („Hlídá…“), velitel (zlatá), chystá schopnost, zoufalý, prchá, Fanatik, Zbabělec, kopí). Každá má popisek.
12. **`flash_hint`:** krátká nápověda nahoře uprostřed (např. proč cíl nejde), sama zmizí.

13. **Režim běhu** (`run_mode`): bez výběru bitvy, menu Pasivky jen ukazuje, co hrdina má, nad názvem bitvy `run_label` („Zkušební běh · bitva 2 ze 3“), výsledek má jediné tlačítko „Pokračovat v běhu“ / „Kronika rodu“.
14. **Dialog před bitvou** je zrušený (bitva začíná v pauze, hrdina bez rozkazu drží místo).
15. **Obdélník výběru** (`select_box`, `show_box`, `hide_box`): při tažení levým tlačítkem na zemi.

## Úskalí
- Kořenový `Control` má `mouse_filter = IGNORE`, jinak spolkne kliky do scény.
- Místní proměnná se nesmí jmenovat jako metoda `CanvasLayer` (`hide`, `show`).

## Historie významných změn
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
