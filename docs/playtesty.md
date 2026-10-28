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
