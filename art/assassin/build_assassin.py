# Asasín: nejlehčí z oddílu, staví se z herního rytíře SK_Knight (stejná kostra, paleta, styl).
# Spuštění v Blenderu (Knight.blend): exec(open(r"<repo>/art/assassin/build_assassin.py", encoding="utf-8").read(), {"KIT": r"<repo>/art/tools/hero_kit.py"})
# Výsledek: SK_Assassin (kolekce ASSASSIN_game), dýka SM_Assassin_Dagger (v obou rukou).
# Silueta: kápě v barvě hrdiny přes přilbu s tmavým průhledem, krátká pláštěnka přes ramena s cípem kápě na zádech,
# bez velkých nárameníků a bez pláště, tunika v barvě hrdiny, karmínová šerpa, kožené chrániče předloktí,
# vrhací nože na pravém stehně, pochvy dýk na zádech u pasu.
import math
import bmesh
from mathutils import Vector, Euler

exec(open(KIT, encoding="utf-8").read(), globals())

ob = new_object_from("SK_Knight", "SK_Assassin", "ASSASSIN_game")
bm = bmesh.new()
bm.from_mesh(ob.data)
B = Builder(ob, bm)
gi = {g.name: g.index for g in ob.vertex_groups}
name_of = {v: k for k, v in gi.items()}

to_delete = []
for p in islands(bm):
    bone = name_of.get(p["bone"], "")
    c, s = p["center"], p["size"]
    if bone == "weapon_scabbard" or bone.startswith("cape"):
        to_delete += p["verts"]                                   # meč a dlouhý plášť pryč
    elif bone == "head" and (p["cell"] == CRIMSON or (p["cell"] == GOLD and p["n"] == 18) or (p["n"] == 8 and c.y < -0.14)):
        to_delete += p["verts"]                                   # chochol, hrot, průzory (pod kápí)
    elif bone in ("upperarm_l", "upperarm_r") and p["n"] == 74:
        if s.x > 0.2:
            to_delete += p["verts"]                               # velké pláty nárameníku pryč
        else:
            for v in p["verts"]:
                v.co = c + (v.co - c) * 0.8 + Vector((-0.03 if c.x > 0 else 0.03, 0, -0.01))
    elif bone in ("lowerarm_l", "lowerarm_r") and p["n"] == 30 and abs(c.x) > 0.7:
        B.set_cell(p["verts"], LEATHER)                           # kožené chrániče předloktí
    elif bone == "spine_02" and p["cell"] == ROLE_DARK and c.y < -0.19:
        B.set_cell(p["verts"], NAVY_DARK)
    elif bone == "head":
        for v in p["verts"]:                                      # menší hlava pod kápí (štíhlejší silueta)
            v.co.x *= 0.85
            v.co.y *= 0.85
            v.co.z = 1.45 + (v.co.z - 1.45) * 0.9
    elif bone == "pelvis" and p["n"] == 126:
        for v in p["verts"]:                                      # užší a kratší tunika
            v.co.x *= 0.92
            if v.co.z < 0.66:
                v.co.z += 0.06
B.delete(to_delete)

W_HEAD = {"head": 1.0}
# --- kápě: oblá kolem přilby, špička dozadu, tmavý průhled na tvář, lem v navy, šála přes bradu
B.cylinder((0, 0.0, 1.41), (0, 0.01, 1.68), 0.19, ROLE, W_HEAD, r1=0.17, segs=12)
B.cylinder((0, 0.01, 1.68), (0, 0.12, 1.8), 0.17, ROLE, W_HEAD, r1=0.025, segs=12)
B.box((0, -0.18, 1.535), (0.18, 0.03, 0.15), VOID, W_HEAD)
B.box((0, -0.186, 1.625), (0.22, 0.03, 0.03), NAVY, W_HEAD)
B.box((0, -0.178, 1.445), (0.26, 0.04, 0.06), NAVY_DARK, W_HEAD)
# --- pláštěnka přes ramena (navy, lem v barvě hrdiny) a cíp kápě po zádech
W_SH = {"spine_03": 1.0}
B.cylinder((0, 0.01, 1.42), (0, 0.01, 1.25), 0.2, NAVY, W_SH, r1=0.31, segs=14)
B.cylinder((0, 0.01, 1.26), (0, 0.01, 1.23), 0.312, ROLE_DARK, W_SH, r1=0.318, segs=14)
B.box((0, 0.205, 1.03), (0.16, 0.035, 0.3), ROLE, {"spine_02": 1.0}, rot=Euler((0.12, 0, 0)), taper=(0.4, 1.0))
# --- karmínová šerpa, uzel vlevo s cípy
B.box((0, 0, 0.99), (0.5, 0.42, 0.07), CRIMSON, {"pelvis": 1.0})
B.box((0.21, -0.12, 0.88), (0.06, 0.03, 0.2), CRIMSON, {"pelvis": 0.7, "thigh_l": 0.3}, rot=Euler((0, 0.15, 0)))
B.box((0.25, -0.1, 0.9), (0.05, 0.03, 0.16), CRIMSON, {"pelvis": 0.7, "thigh_l": 0.3}, rot=Euler((0, -0.2, 0)))
# --- pochvy dýk na zádech u pasu (křížem)
for s in (1, -1):
    B.box((0.1 * s, 0.22, 0.92), (0.04, 0.03, 0.32), LEATHER, {"pelvis": 1.0}, rot=Euler((0, 0.5 * s, 0)))
    B.box((0.035 * s, 0.225, 0.8), (0.05, 0.035, 0.03), GOLD, {"pelvis": 1.0})
# --- vrhací nože na pravém stehně
W_TH = {"thigh_r": 1.0}
B.cylinder((-0.12, 0, 0.72), (-0.12, 0, 0.78), 0.09, LEATHER, W_TH, segs=8)
for k in range(3):
    a = -0.6 + 0.6 * k
    x = -0.12 + math.sin(a - math.pi / 2) * 0.095
    y = math.cos(a - math.pi / 2) * 0.095
    B.box((x - 0.005, y - 0.01, 0.79), (0.015, 0.025, 0.1), STEEL, W_TH)
    B.box((x - 0.005, y - 0.01, 0.725), (0.02, 0.03, 0.06), NAVY_DARK, W_TH)

bm.normal_update()
bm.to_mesh(ob.data)
bm.free()
ob.data.update()

# --- dýka: úchop v počátku, čepel po +Z
dag = new_weapon("SM_Assassin_Dagger", "ASSASSIN_game")
wd = bmesh.new()
WD = Builder(dag, wd)
W0 = {}
WD.cylinder((0, 0, -0.09), (0, 0, -0.07), 0.024, GOLD, W0, segs=8)            # hlavice
WD.cylinder((0, 0, -0.07), (0, 0, 0.06), 0.017, NAVY_DARK, W0, segs=8)         # rukojeť
WD.box((0, 0, 0.07), (0.1, 0.028, 0.022), GOLD, W0)                            # záštita
WD.box((0, 0, 0.23), (0.042, 0.012, 0.3), STEEL, W0, taper=(0.1, 0.5))         # čepel
WD.box((0, 0, 0.17), (0.01, 0.014, 0.16), STEEL_DARK, W0)                      # žlábek
wd.normal_update()
wd.to_mesh(dag.data)
wd.free()

RESULT = {"tris": sum(len(p.vertices) - 2 for p in ob.data.polygons),
          "dagger_tris": sum(len(p.vertices) - 2 for p in dag.data.polygons),
          "unweighted": sum(1 for v in ob.data.vertices if not v.groups)}
