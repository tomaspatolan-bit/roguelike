# Jak hráč postupuje hrou (zjednodušeně)

Schváleno 29.10.2026. Podrobnosti v `rozhodnuti.md`.

```mermaid
flowchart TD
    L["Lore a svět<br/>(kulisa: proč rod válčí, s kým a kde)"]
    B["Běh = jedna výprava rodu"]
    A1["Akt 1: Hraběcí les<br/>mapa + boss"]
    A2["Akt 2: další kraj<br/>mapa + boss"]
    A3["Akt 3: hrad<br/>mapa + boss"]
    W["Vítězství<br/>kronika rodu"]
    X["Oddíl padl<br/>běh končí, kronika"]
    N["Nový běh od aktu 1<br/>(meta: síň předků, odemčené rody)"]

    L -.-> B
    B --> A1 -->|boss poražen| A2 -->|boss poražen| A3 -->|boss poražen| W
    A1 & A2 & A3 -->|padnou všichni| X --> N
    W --> N
```

## Uvnitř aktu

```mermaid
flowchart BT
    S["Start aktu"]
    P1["Patro 1: vybereš 1 ze 2–3 uzlů"]
    P2["Patro 2"]
    P3["…"]
    P7["Patro 7"]
    BOSS["Boss aktu"]
    S --> P1 --> P2 --> P3 --> P7 --> BOSS
```

- **Akt** = jedna mapa, 7 pater, nahoře boss.
- **Patro** = vrstva mapy. Jdeš jednou cestou: na každém patře navštívíš jeden uzel, ostatní vynecháš.
- **Uzel** = zastávka: bitva, elita (těžší, lepší odměna), událost (rozhodnutí s cenou), tábor (odpočinek), boss.
- **Co se nese dál:** hrdinové, pasivky, přísahy, nástupci padlých, sláva, kronika (a zranění, pokud se tak rozhodne).
- **Dvě různé smrti:** padlý hrdina = běh pokračuje s nástupcem. Padne celý oddíl = konec běhu, další začíná od aktu 1.
