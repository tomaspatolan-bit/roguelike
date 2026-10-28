# Kontext: rozhraní

Soubory: `scripts/battle/battle_ui.gd`
Hlídá: `tests/screenshot_battle.gd` (snímky panelu)

## Účel
Vykreslit stav a poslat úmysly hráče signálem. Nerozhoduje o pravidlech.

## Invarianty
1. **Žádná herní logika.** UI nemění simulaci, jen emituje signály, které zpracuje `battle.gd`.
2. **Signály:** `knight_clicked`, `posture_changed`, `bearer_changed`, `scenario_changed`, `route_draw_pressed`, `route_clear_pressed`, `signals_count_changed`, `start_pressed`, `shout_pressed`, `signal_pressed`, `charge_pressed`, `resume_pressed`, `speed_changed`, `continue_pressed`, `retry_pressed`, `redeploy_pressed`.
3. **Rozvržení:** nahoře uprostřed lišta velení (`top_row`: v rozestavení signály a Začít bitvu; v bitvě čas, sláva, pokřiky, signál, Do boje!, rychlost), vlevo nahoře karta bitvy (`info_box`), dole karty rytířů (`cards_row`), vpravo nahoře sbalitelný deník. Nic dalšího se do pravé strany nepřidává. Přestavuje se jen při změně stavu (`show_deploy`, `show_battle`); plynulé věci aktualizuje `update_dynamic` (každých 0,1 s) a `update_hp_bars` (každý snímek). Přestavba každý snímek je zakázaná; ikonky se mění jen při změně podpisu (`_sig`).
4. **Hráč musí vždy vidět:** slávu, dostupnost pokřiků, zbývající signály, stav praporu, stav úkolu, zda čas stojí.
5. **Texty česky,** krátce, sloveso na začátku tlačítka. Zkratky kláves uvedené na tlačítkách odpovídají `battle.gd`.
6. **Font:** systémový (Segoe UI na Windows), musí umět českou diakritiku.
7. **Postoje podle přísahy:** názvy z `sim.posture_name()`. V rozestavení jsou zakázané postoje zašedlé s popiskem důvodu; při signálu jdou zvolit s dovětkem „(poruší přísahu)“ a `battle.gd` se zeptá dialogem. Dialog přísahy bere text z dat přísahy.
8. **Žádné tlačítko nesmí brát fokus klávesnice** (`_no_focus` po každé přestavbě panelu), jinak by mezerník mačkal tlačítko místo signálu.
9. **Nositel praporu:** v rozestavení má každý rytíř tlačítko „Prapor“ s popisem efektu jeho třídy; při bitvě tlačítko není (prapor se nepředává). Postoj „Chránit prapor“ je u nositele vždy zašedlý s důvodem, nikdy „(poruší přísahu)“. Panel rodu ukazuje, kdo prapor nese a co dělá.
10. **Povel Do boje!** se v panelu bitvy ukáže až po zlomení morálky nepřítele (klávesa F), po použití zůstane zašedlý s textem „Rytíři dobojují“.
11. **Rozestavení:** nahoře výběr bitvy (`scenario_choices` nastavuje `battle.gd`), pod soupiskou řádek s trasou vybraného rytíře (Kreslit trasu / Smazat) a během kreslení nápověda. Výsledek bitvy bere nadpis ze scénáře (`win_title`).
12. **Ikonky** (`ui_icon.gd`, vektorově v `_draw`, zástupné): třída rytíře na kartě; stav nad hlavou i na kartě z `_status_icons` (prapor, přísaha/zlomená, aura, aktivní pokřik, záloha, trasa; u nepřátel drží pozici, zoufalý, prchá, Fanatik, Zbabělec, kopí proti jízdě). Každá ikonka má popisek. Nová ikonka = nový `kind` v `ui_icon.gd`.
13. **Karty rytířů:** klik na kartu = výběr rytíře. V rozestavení postoj, Prapor, Trasa (a ✕ smazat), při signálu postoj, v bitvě jen název postoje.

## Úskalí
- Kořenový `Control` má `mouse_filter = IGNORE`, jinak spolkne kliky do scény.
- Místní proměnná se nesmí jmenovat jako metoda `CanvasLayer` (`hide`, `show`).

## Historie významných změn
- 28.10.2026: nové rozvržení (lišta velení, karty rytířů dole, deník vpravo nahoře), vektorové ikonky stavu nad hlavami a na kartách. Tom si UI převezme a navrhne.
- 28.10.2026: tlačítko Do boje! po zlomení morálky.
- 28.10.2026: tlačítko Prapor v rozestavení, popisky postojů, „běží pro prapor“ v soupisce.
- 2026-10-28: postoje podle přísahy, mezerník v popiscích, tlačítka bez fokusu.
- 2026-10-28: založeno.
