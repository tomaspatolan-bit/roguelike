# Lučištník (Archer): střelec řádu, staví se z herního rytíře SK_Knight (stejná kostra, paleta, styl).
# Spuštění v Blenderu (Knight.blend): exec(open(r"<repo>/art/archer/build_archer.py", encoding="utf-8").read(), {"KIT": r"<repo>/art/tools/hero_kit.py"})
# Výsledek: SK_Archer (kolekce ARCHER_game), luk SM_Archer_Bow (levá ruka), šíp SM_Archer_Arrow (střela).
# Silueta: bez pláště, toulec na zádech, přilba s krempou (kapalín), těžší levé rameno (k nepříteli), lehčí pravé,
# kožený chránič na levém předloktí, krátká tunika v barvě hrdiny (zelená), navy a zlato na detailech, dýka u pasu.
import math
import bmesh
from mathutils import Vector, Euler
from mathutils.bvhtree import BVHTree

exec(open(KIT, encoding="utf-8").read(), globals())

ob = new_object_from("SK_Knight", "SK_Archer", "ARCHER_game")
bm = bmesh.new()
bm.from_mesh(ob.data)
B = Builder(ob, bm)
gi = {g.name: g.index for g in ob.vertex_groups}
name_of = {v: k for k, v in gi.items()}

isl = islands(bm)
to_delete = []
for p in isl:
    bone = name_of.get(p["bone"], "")
    c, s = p["center"], p["size"]
    if bone == "weapon_scabbard":
        to_delete += p["verts"]                                  # meč v pochvě pryč (místo něj dýka)
    elif bone.startswith("cape"):
        to_delete += p["verts"]                                  # bez pláště: na zádech je toulec
    elif bone == "head" and p["cell"] == CRIMSON:
        to_delete += p["verts"]                                  # chochol pryč (krempa, malé pírko)
    elif bone == "head" and p["cell"] == GOLD and p["n"] == 18 and c.z > 1.74:
        to_delete += p["verts"]
    elif bone == "head" and p["n"] == 8 and c.y < -0.14:
        to_delete += p["verts"]                                  # průzory a hřeben hledí pryč: otevřená tvář
    elif bone == "upperarm_r" and p["n"] == 74:
        # pravé rameno lehčí (táhne tětivu): menší plát
        for v in p["verts"]:
            v.co = c + (v.co - c) * 0.72 + Vector((0.035, 0, -0.015))
    elif bone == "upperarm_l" and p["n"] == 74:
        for v in p["verts"]:
            v.co = c + (v.co - c) * 1.05
    elif bone == "lowerarm_l" and p["n"] == 30 and c.x > 0.7:
        B.set_cell(p["verts"], LEATHER)                          # kožený chránič na předloktí s lukem
    elif bone == "pelvis" and p["n"] == 126:
        # kratší tunika (do půli stehen)
        for v in p["verts"]:
            if v.co.z < 0.66:
                v.co.z += 0.1
    elif bone == "spine_02" and p["cell"] == ROLE_DARK and c.y < -0.19:
        B.set_cell(p["verts"], NAVY_DARK)                        # znak na hrudi: navy pole řádu
B.delete(to_delete)

W_HEAD = {"head": 1.0}
# --- krempa přilby (kapalín): komolý kužel kolem přilby, zlatý okraj, malé karmínové pírko na boku
# (krempa nad průzory: průzory jsou ve výšce 1,585)
B.cylinder((0, 0, 1.632), (0, 0, 1.672), 0.27, STEEL, W_HEAD, r1=0.165, segs=16)
B.cylinder((0, 0, 1.624), (0, 0, 1.638), 0.276, GOLD, W_HEAD, r1=0.272, segs=16)
B.box((0.17, 0.05, 1.73), (0.025, 0.05, 0.13), CRIMSON, W_HEAD, rot=Euler((0.35, -0.25, 0)), taper=(0.4, 0.4))

# otevřená tvář: tmavý průhled pod krempou, nánosník, kroužkový závěs kolem brady
B.box((0, -0.168, 1.53), (0.2, 0.012, 0.15), VOID, W_HEAD)
B.box((0, -0.178, 1.55), (0.022, 0.014, 0.13), STEEL, W_HEAD)
B.box((0, -0.168, 1.437), (0.25, 0.018, 0.04), CHAIN, W_HEAD)

# --- navy lem tuniky (vpředu i vzadu)
for sy in (-1, 1):
    B.box((0, sy * 0.189, 0.70), (0.452, 0.108, 0.04), NAVY, {"pelvis": 1.0})

# --- toulec na zádech (šikmo, ústí nad pravým ramenem) a šípy
W_BACK = {"spine_02": 1.0}
q_rot = Euler((-0.12, -0.38, 0))
q_axis = q_rot.to_matrix() @ Vector((0, 0, 1))
q_c = Vector((-0.04, 0.215, 1.2))
B.box(q_c, (0.12, 0.09, 0.5), LEATHER, W_BACK, rot=q_rot)
B.box(q_c + q_axis * 0.235, (0.13, 0.1, 0.035), GOLD, W_BACK, rot=q_rot)          # zlaté ústí
B.box(q_c - q_axis * 0.2, (0.125, 0.095, 0.03), NAVY_DARK, W_BACK, rot=q_rot)     # navy pruh dole
for k, (dx, dy) in enumerate(((-0.03, -0.015), (0.0, 0.02), (0.03, -0.01), (-0.01, 0.0), (0.025, 0.025))):
    base = q_c + q_rot.to_matrix() @ Vector((dx, dy, 0.25))
    tip = base + q_axis * 0.13
    B.cylinder(base, tip, 0.007, LEATHER, W_BACK, segs=4)
    B.box(tip + q_axis * 0.025, (0.004, 0.035, 0.05), CRIMSON if k % 2 == 0 else STEEL, W_BACK, rot=q_rot)
# řemen toulce přes hruď (od pravého ramene k levému boku)
B.box((0.0, -0.196, 1.14), (0.04, 0.05, 0.46), LEATHER, W_BACK, rot=Euler((0, -0.62, 0)))
B.box((0.087, -0.198, 1.02), (0.05, 0.05, 0.035), GOLD, W_BACK, rot=Euler((0, -0.62, 0)))

# --- výbava u pasu: dýka na pravém boku, váček na levém
W_HIP_R = {"pelvis": 0.75, "thigh_r": 0.25}
W_HIP_L = {"pelvis": 0.75, "thigh_l": 0.25}
B.box((-0.25, -0.02, 0.86), (0.03, 0.05, 0.2), LEATHER, W_HIP_R)                  # pochva
B.box((-0.25, -0.02, 0.975), (0.035, 0.09, 0.016), GOLD, W_HIP_R)                 # záštita
B.box((-0.25, -0.02, 1.02), (0.022, 0.026, 0.08), NAVY_DARK, W_HIP_R)             # rukojeť
B.box((-0.25, -0.02, 1.065), (0.03, 0.03, 0.02), GOLD, W_HIP_R)                   # hlavice
B.box((0.25, -0.04, 0.89), (0.05, 0.1, 0.09), LEATHER, W_HIP_L)                   # váček
B.box((0.252, -0.04, 0.925), (0.054, 0.104, 0.02), NAVY_DARK, W_HIP_L)

bm.normal_update()
bm.to_mesh(ob.data)
bm.free()
ob.data.update()

# --- dlouhý luk (levá ruka): úchop v počátku, ramena po +Z/−Z, konce se stáčí k lučištníkovi (−Y), tětiva v kódu hry
bow = new_weapon("SM_Archer_Bow", "ARCHER_game")
wb = bmesh.new()
WB = Builder(bow, wb)
W0 = {}
L = 0.78          # půl délky luku
SAG = 0.16        # o kolik jsou konce blíž lučištníkovi než rukojeť (tětiva leží v y = -SAG)
def bow_pt(z):
    t = abs(z) / L
    return Vector((0, -SAG * t * t, z))
N = 9
for i in range(N):
    z0 = -L + 2 * L * i / N
    z1 = -L + 2 * L * (i + 1) / N
    th = 0.028 - 0.012 * abs((z0 + z1) / 2) / L            # ramena se ke koncům zužují
    WB.cylinder(bow_pt(z0), bow_pt(z1), th, LEATHER, W0, segs=6)
WB.cylinder((0, 0, -0.09), (0, 0, 0.09), 0.033, NAVY_DARK, W0, segs=8)         # omotávka rukojeti
WB.cylinder((0, 0, 0.09), (0, 0, 0.11), 0.036, GOLD, W0, segs=8)               # zlaté objímky
WB.cylinder((0, 0, -0.11), (0, 0, -0.09), 0.036, GOLD, W0, segs=8)
for sz in (1, -1):                                                           # stříbrné okované konce
    a = bow_pt(sz * (L - 0.07))
    b = bow_pt(sz * (L + 0.02))
    WB.cylinder(a, b, 0.017, STEEL, W0, r1=0.01, segs=6)
wb.normal_update()
wb.to_mesh(bow.data)
wb.free()

# --- šíp (střela ve hře): hrot po +Z, délka 0,8 m, počátek uprostřed
arrow = new_weapon("SM_Archer_Arrow", "ARCHER_game")
wa = bmesh.new()
WA = Builder(arrow, wa)
WA.cylinder((0, 0, -0.4), (0, 0, 0.33), 0.009, LEATHER, W0, segs=5)
WA.cylinder((0, 0, 0.33), (0, 0, 0.42), 0.022, STEEL, W0, r1=0.002, segs=5)
for k in range(3):
    a = 2 * math.pi * k / 3
    d = Vector((math.cos(a), math.sin(a), 0))
    pts = [Vector((0, 0, -0.38)) + d * 0.008, Vector((0, 0, -0.38)) + d * 0.045,
           Vector((0, 0, -0.25)) + d * 0.02, Vector((0, 0, -0.22)) + d * 0.008]
    WA.prism(pts, 0.004, Vector((-math.sin(a), math.cos(a), 0)), CRIMSON, W0)
wa.normal_update()
wa.to_mesh(arrow.data)
wa.free()

BOW_STRING = {"top": [0.0, -SAG, L + 0.01], "bottom": [0.0, -SAG, -L - 0.01]}   # konce tětivy (Blender, prostor luku)
RESULT = {"tris": sum(len(p.vertices) - 2 for p in ob.data.polygons),
          "bow_tris": sum(len(p.vertices) - 2 for p in bow.data.polygons),
          "arrow_tris": sum(len(p.vertices) - 2 for p in arrow.data.polygons), "string": BOW_STRING}
