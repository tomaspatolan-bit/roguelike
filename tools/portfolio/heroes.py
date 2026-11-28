#!/usr/bin/env python3
"""Round 2 of the portfolio: finishes the hero models' previews and writes hrdinove.json.

- previews: the 2x renders from models.gd (hrdina-<x>_2x.png) are cropped to the figure (alpha), given the same
  margin and fitted into 1200x1200 with a transparent background (resized premultiplied, no dark fringes);
- hrdinove.json: per figure the name, class, ability with its short description (data/units.json), class colour
  (hex), the measured class colour share (tests/prototype_shots.gd report: minimum and average over poses and
  facings from the battle camera), size and file names. Commanders have no class colour (decision 15.11.2026):
  they get their profile instead.

Usage: python3 tools/portfolio/heroes.py <models dir> <out dir> [prototype_shots log]
"""
import json
import os
import re
import sys

from PIL import Image

SIZE = 1200
MARGIN = 0.07

CLASS_CZ = {"tank": "tank", "knez": "kněz", "lucistnik": "lučištník", "jezdec": "jezdec", "asasin": "asasín"}
COMMANDER = {
    "vok": ("palic", "Pálič Vok", "rychlý a křehký: bez zbroje, nejrychlejší krok i údery, pochodeň v ruce"),
    "kuno": ("vudce", "Hejtman Kuno", "těžký: největší, nejvíc zdraví a zbroje, pomalé silné údery, odhození a omráčení na něj platí míň"),
    "borivoj": ("setnik", "Setník Bořivoj", "zeď: velký štít zepředu zachytí část zásahu (110°, ×0,55), ze strany a zezadu ne"),
    "jira": ("ostrostrelec", "Ostrostřelec Jíra", "daleko: nejdelší dostřel, silné pomalé rány, couvá od hrdiny, který se přiblíží"),
}
HERO_KEY = {"tank": "tank", "knez": "knez", "lucistnik": "lucistnik", "jezdec": "jezdec", "asasin": "asasin"}


def preview(src, dst):
    im = Image.open(src).convert("RGBA")
    bbox = im.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox()
    im = im.crop(bbox)
    inner = int(SIZE * (1 - 2 * MARGIN))
    k = inner / max(im.width, im.height)
    pm = im.convert("RGBa").resize((max(1, round(im.width * k)), max(1, round(im.height * k))), Image.LANCZOS).convert("RGBA")
    canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    canvas.paste(pm, ((SIZE - pm.width) // 2, (SIZE - pm.height) // 2))
    canvas.save(dst, optimize=True)


def coverage(log_path):
    """class_colour_coverage_percent from the report line of tests/prototype_shots.gd."""
    if not log_path or not os.path.exists(log_path):
        return {}
    for line in open(log_path, encoding="utf-8", errors="replace"):
        m = re.search(r"Zpráva: (\{.*\})", line)
        if m:
            rep = json.loads(m.group(1))
            return rep.get("class_colour_coverage_percent", {})
    return {}


def main():
    src, out = sys.argv[1], sys.argv[2]
    cov = coverage(sys.argv[3] if len(sys.argv) > 3 else "")
    os.makedirs(out, exist_ok=True)
    info = json.load(open(os.path.join(src, "models.json")))
    units = json.load(open(os.path.join(os.path.dirname(__file__), "../../data/units.json")))
    heroes, commanders = [], []
    for f in ["tank", "knez", "lucistnik", "jezdec", "asasin", "vok", "kuno", "borivoj", "jira"]:
        if f not in info:
            print("chybí", f)
            continue
        i = info[f]
        p2 = os.path.join(src, "hrdina-%s_2x.png" % f)
        if os.path.exists(p2):
            preview(p2, os.path.join(out, "hrdina-%s.png" % f))
        files = {"model": "hrdina-%s.glb" % f, "nahled": "hrdina-%s.png" % f}
        size = {"vyska_m": i["height_m"], "sirka_m": i["width_m"], "trojuhelniky": i["triangles"],
                "idle_s": i["idle_s"]}
        if f in HERO_KEY:
            k = units["knights"][HERO_KEY[f]]
            ab = units["abilities"][k["ability"]]
            c = cov.get(HERO_KEY[f], {})
            vals = [float(v) for v in c.values()]
            files["maska"] = "hrdina-%s-maska.glb" % f
            heroes.append({
                "id": f, "jmeno": k["name"], "trida": k["role"], "trida_cz": CLASS_CZ[f],
                "schopnost": {"nazev": ab["name"], "popis": ab["desc"]},
                "barva_tridy": k["color"],
                "podil_barvy_tridy_pct": {
                    "min": round(min(vals), 1) if vals else None,
                    "prumer": round(sum(vals) / len(vals), 1) if vals else None,
                    "cil": 40,
                    "mereni": "maska z bitevní kamery, 8 póz × 4 natočení (tests/prototype_shots.gd)",
                },
                "soubory": files, "velikost": size,
            })
        else:
            key, cz, profil = COMMANDER[f]
            fd = units["foes"][key]
            sk = units["foe_skills"][fd["skill"]]
            commanders.append({
                "id": f, "jmeno": fd["name"], "jmeno_cz": cz, "role": fd["role"],
                "schopnost": {"nazev": sk["name"], "popis": sk.get("warn", "").replace(": %s!", "!")},
                "profil": profil, "postava_scale": fd.get("scale"),
                "barva_tridy": None, "podil_barvy_tridy_pct": None,
                "poznamka": "nepřátelé nemají barvu žádného hrdiny (rozhodnutí 15.11.2026), proto bez masky",
                "soubory": files, "velikost": size,
            })
    doc = {
        "_info": "Postavy Oathline pro otáčecí prohlížeč (<model-viewer>). Metry, osa Y nahoru, počátek mezi nohama "
                 "na zemi, čelem k +Z, všechny ve stejném měřítku. Jediná animace `Idle` (smyčka). Barva třídy = "
                 "hlavní látka hrdiny; podíl = kolik plochy postavy viděné z bitevní kamery má barvu třídy.",
        "hrdinove": heroes, "velitele": commanders,
    }
    json.dump(doc, open(os.path.join(out, "hrdinove.json"), "w"), ensure_ascii=False, indent=2)
    print("OK hrdinove.json", len(heroes), "hrdinů,", len(commanders), "velitelů")


if __name__ == "__main__":
    main()
