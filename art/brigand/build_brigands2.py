# Brigands (visual prototype, 15.11.2026): the enemies built with art/tools/char_kit.py and art/chars/hero_body.py like
# the heroes: the same body, proportions and knight skeleton, so the old animations (A_Knight_*, A_Archer_*) fit unchanged.
# Run in Blender with Knight.blend open:
#   exec(open(r"<repo>/art/brigand/build_brigands2.py", encoding="utf-8").read(),
#        {"KIT": r"<repo>/art/tools/char_kit.py", "BODY": r"<repo>/art/chars/hero_body.py", "PAL": r"<repo>/art/chars/T_Char_Palette_D.png", "OUT": r"<repo>/art/brigand"})
# Without OUT it only builds (window scene must be "Scene" for the export, see char_kit.export_glb).
# Result (collection BRIGAND2_game):
#   SK_Brigand2      brigand with an axe: rust hood with a ragged shoulder cape, undyed wool tunic, leather vest, rolled sleeves
#   SK_Spearman2     spearman: iron kettle hat with a wide brim, quilted tan gambeson, round shield on the back
#   SK_Bowman2       bowman: hood with a long tail, short rust tunic, quiver at the right hip
#   SK_BrigandBoss2  commanders (palette row 7): nasal helmet with a mail aventail, fur mantle, mail shirt, torn red surcoat
#   SM_Brigand2_Axe, SM_Brigand2_Spear, SM_Brigand2_Bow (bow geometry as the archer's: L = 0.78, SAG = 0.16, string in the game)
# Design (style guide): brigands are not of the order: no polished steel, no gold, no hero colour. Rust, mud, undyed wool
# and dull iron (palette row 6 overrides the steel and gold cells), commanders blood red with blackened iron (row 7).
# Each type has its own silhouette from above: hood and cape (axe), hat brim and shield disc (spear), hood tail and
# quiver (bow), helmet point and fur ring (commander). Ragged hems instead of the heroes' clean lines.
import math
import bmesh
import bpy
from mathutils import Matrix, Vector

exec(open(KIT, encoding="utf-8").read(), globals())
exec(open(BODY, encoding="utf-8").read(), globals())
preview_material(PAL, 6)
COL = "BRIGAND2_game"
HW = {"head": 1.0}
NECK = {"spine_03": 0.6, "neck_01": 0.4}
RESULT = {}


def ragged(v, u, depth=0.035, teeth=4.5):
    """Torn hem: the bottom edge goes up and down along u."""
    return depth * abs(math.sin(u * teeth * math.pi + 0.7)) * smoothstep(0.75, 1.0, v)


def tunic(K, cell, hem, top=0.95, length=0.42, flare=0.06, torn=True, inner=None):
    """Front and back panels from the waist down (split at the sides), optional torn hem, plus the hip tube."""
    for sgn in (-1.0, 1.0):
        def f(u, v, sg=sgn):
            z = top - length * v + (ragged(v, u + sg) if torn else 0.0)
            return (-sg * u * (0.14 + flare * v), sg * ((0.155 + 0.06 * v ** 0.6) - 0.02 * u * u), z)
        K.sheet(f, 8, 7, 0.014, cell, skirt_weights(top - 0.02, top - length, 0.75), cell_in=inner or hem,
                cell_fn=lambda u, v: hem if v > 0.9 else None)
    K.loft([((0, 0, top + 0.035), 0.19, 0.146), ((0, 0, top - 0.09), 0.205, 0.156), ((0, 0, top - 0.21), 0.216, 0.163)], cell,
           skirt_weights(top - 0.03, top - 0.21, 0.55), n=14, e=2.4, caps=("flat", "flat"))


def pouch(K, x, cell=LEATHER, z=0.9):
    y = -0.12 if x > 0 else -0.12
    K.ellipsoid((x, y, z), (0.05, 0.035, 0.06), cell, {"pelvis": 1.0}, n=8, m=4)
    K.box((x, y - 0.01, z + 0.045), (0.08, 0.05, 0.02), LEATHER_DARK, {"pelvis": 1.0}, bevel=0.005)


def shoulder_cape(K, cell, hem, length=0.15, torn=True):
    """A short cape around the shoulders under the hood (ragged hem)."""
    def w(co):
        return {"spine_03": 0.7, "clavicle_l": 0.15, "clavicle_r": 0.15} if co.z > 1.2 else torso_weights(co)
    z0 = 1.36
    rings = [((0, 0.0, z0), 0.15, 0.13), ((0, 0.0, z0 - 0.05), 0.25, 0.2), ((0, 0.012, z0 - 0.12), 0.31, 0.23),
             ((0, 0.02, z0 - 0.12 - length * 0.6), 0.325, 0.245)]
    K.loft(rings, cell, w, n=20, e=2.2, caps=("flat", "flat"))
    if torn:   # tatters hanging from the hem
        for k in range(10):
            a = 2 * math.pi * (k + 0.5) / 10
            p = Vector((math.cos(a) * 0.31, math.sin(a) * 0.235 + 0.02, z0 - 0.12 - length * 0.6))
            fr = frame_for((0, 0, -1))
            K.loft([(p, 0.07, 0.014, fr), (p + Vector((0, 0, -0.04 - 0.015 * (k % 3))), 0.03, 0.01, fr)], hem, w, n=6,
                   caps=("flat", "flat"))


def kettle_hat(K, dome=STEEL, brim=STEEL_DARK, z=1.62, r=(0.255, 0.27)):
    """Iron kettle hat: dome and a wide flat brim (the brigand's sign from above)."""
    K.ellipsoid((0, 0.005, z), (0.128, 0.142, 0.13), dome, HW, n=16, m=6, z_range=(0.0, 1.0))
    K.loft([((0, 0.005, z - 0.012), r[0], r[1]), ((0, 0.005, z + 0.006), r[0] * 0.97, r[1] * 0.97)], brim, HW, n=20, e=2.0,
           caps=("flat", "flat"))
    K.loft([((0, 0.005, z - 0.004), 0.132, 0.146), ((0, 0.005, z + 0.03), 0.13, 0.144)], LEATHER_DARK, HW, n=16, caps=("flat", "flat"))
    K.ellipsoid((0, 0.005, z + 0.13), (0.02, 0.02, 0.015), brim, HW, n=8, m=3)


# ===================================================================== brigand with an axe
ob = new_skinned("SK_Brigand2", COL)
bm = bmesh.new()
K = Kit(ob, bm)
legs(K, NAVY, boot=LEATHER, cuff=LEATHER_DARK, boot_top=0.2)
arms(K, ROLE, forearm=SKIN, glove=LEATHER, bracer=LEATHER, cuff=None, slim=1.04)
for s in (1.0, -1.0):     # rolled sleeve at the elbow
    S, E, W, d, fa = arm_frame(s)
    L = "l" if s > 0 else "r"
    K.loft([(E - d * 0.03, 0.07, 0.07, fa), (E + d * 0.04, 0.068, 0.068, fa)], ROLE_DARK, {"lowerarm_" + L: 0.5, "upperarm_" + L: 0.5},
           n=8, caps=("flat", "flat"))
tunic(K, LINEN, ROLE_DARK, length=0.43, inner=LINEN)
torso(K, LINEN, chest=1.04, waist=1.08)
# open leather vest: two front panels and the back
K.loft([((0, 0, 0.99), 0.212, 0.164), ((0, -0.012, 1.15), 0.236, 0.184), ((0, -0.006, 1.26), 0.22, 0.17)], LEATHER, torso_weights,
       n=10, arc=(-160.0, -100.0), thick=0.016, e=2.5)
K.loft([((0, 0, 0.99), 0.212, 0.164), ((0, -0.012, 1.15), 0.236, 0.184), ((0, -0.006, 1.26), 0.22, 0.17)], LEATHER, torso_weights,
       n=10, arc=(-80.0, -20.0), thick=0.016, e=2.5)
K.loft([((0, 0, 0.99), 0.212, 0.164), ((0, -0.012, 1.15), 0.236, 0.184), ((0, -0.006, 1.26), 0.22, 0.17)], LEATHER, torso_weights,
       n=12, arc=(20.0, 160.0), thick=0.016, e=2.5)
belt(K, LEATHER_DARK, STEEL_DARK, z=0.975, r=(0.218, 0.168))
pouch(K, 0.13)
# knife in a sheath on the left hip
K.loft([((0.2, -0.04, 0.95), 0.02, 0.012), ((0.215, -0.03, 0.78), 0.016, 0.01)], LEATHER_DARK, {"pelvis": 1.0}, n=6, caps=("flat", "round"))
K.box((0.2, -0.04, 0.985), (0.018, 0.018, 0.06), WOOD, {"pelvis": 1.0})
shoulder_cape(K, ROLE, ROLE_DARK, length=0.16)
face(K, beard=HAIR, hair=None)
hood(K, ROLE, point=0.05, opening=58.0)
RESULT["brigand"] = finish(ob, bm)
bm.free()

# ===================================================================== spearman
ob = new_skinned("SK_Spearman2", COL)
bm = bmesh.new()
K = Kit(ob, bm)
legs(K, LEATHER_DARK, shin=LINEN, boot=LEATHER, cuff=LEATHER_DARK, boot_top=0.2)
arms(K, ROLE_LIGHT, forearm=ROLE_LIGHT, glove=LEATHER_DARK, bracer=LEATHER, slim=1.08)
tunic(K, ROLE_LIGHT, ROLE_DARK, length=0.4, flare=0.07, torn=False, inner=ROLE_LIGHT)
torso(K, ROLE_LIGHT, chest=1.1, waist=1.1)
for z in (1.02, 1.1, 1.18, 0.88, 0.8, 0.72):   # quilting lines
    r = (0.232, 0.18) if z > 0.95 else (0.21 + (0.95 - z) * 0.17, 0.162 + (0.95 - z) * 0.09)
    K.loft([((0, -0.012 if z > 1.1 else 0, z - 0.006), r[0], r[1]), ((0, -0.012 if z > 1.1 else 0, z + 0.006), r[0], r[1])], ROLE,
           torso_weights if z > 0.95 else skirt_weights(0.93, 0.55, 0.6), n=16, e=2.5, caps=("flat", "flat"))
# dark sash across the chest, belt
K.loft([((0.17, -0.165, 1.28), 0.05, 0.014), ((0.0, -0.215, 1.12), 0.052, 0.014), ((-0.17, -0.18, 0.98), 0.05, 0.014)], NAVY,
       torso_weights, n=6, caps=("flat", "flat"), frame=frame_for((0, 1, 0)))
belt(K, LEATHER_DARK, STEEL_DARK, z=0.975, r=(0.226, 0.172))
pouch(K, -0.14)
collar(K, ROLE_DARK, r=(0.155, 0.14))
face(K, beard=HAIR, hair=HAIR)
kettle_hat(K)
# round shield on the back: rust boards, a dull iron boss and rim
fy = frame_for((0, 1, 0))
SHW = lambda co: {"spine_03": 1.0} if co.z > 1.15 else {"spine_02": 1.0}
K.ellipsoid((0.02, 0.215, 1.1), (0.24, 0.24, 0.022), ROLE, SHW, n=18, m=3, frame=fy)
K.loft([((0, 0, -0.01), 0.245, 0.245), ((0, 0, 0.026), 0.245, 0.245)], STEEL_DARK, SHW, n=18, caps=("flat", "flat"), frame=fy,
       origin=(0.02, 0.215, 1.1))
K.loft([((0, 0, -0.01), 0.232, 0.232), ((0, 0, 0.027), 0.232, 0.232)], ROLE, SHW, n=18, caps=("flat", "flat"), frame=fy,
       origin=(0.02, 0.215, 1.1))
K.box((0.02, 0.24, 1.1), (0.07, 0.006, 0.46), LINEN, SHW)   # painted stripe
K.ellipsoid((0.02, 0.24, 1.1), (0.06, 0.06, 0.035), STEEL, SHW, n=10, m=4, frame=fy, z_range=(0.0, 1.0))
RESULT["spearman"] = finish(ob, bm)
bm.free()

# ===================================================================== bowman
ob = new_skinned("SK_Bowman2", COL)
bm = bmesh.new()
K = Kit(ob, bm)
legs(K, LINEN, shin=NAVY, boot=LEATHER, cuff=LEATHER_DARK, slim=0.94, boot_top=0.22)
arms(K, ROLE_DARK, forearm=ROLE_DARK, glove=LEATHER, bracer=LEATHER_DARK, bracer_sides=(1.0,), slim=0.95)
tunic(K, ROLE, ROLE_DARK, length=0.36)
torso(K, ROLE, chest=0.96, waist=0.98)
K.loft([((0, 0, 1.0), 0.2, 0.156), ((0, -0.012, 1.15), 0.224, 0.174), ((0, -0.006, 1.26), 0.208, 0.16)], LEATHER, torso_weights,
       n=14, arc=(-150.0, 150.0), thick=0.014, e=2.5)     # jerkin, open at the front
belt(K, LEATHER_DARK, STEEL_DARK, z=0.97)
# quiver hanging at the right hip, arrows up and back
qa = Vector((-0.24, 0.06, 0.72))
qb = Vector((-0.25, 0.14, 1.06))
qd = (qb - qa).normalized()
fq = frame_for(qd, ref=(1, 0, 0))
QW = {"pelvis": 1.0}
K.loft([(qa, 0.05, 0.044, fq), (qa + qd * 0.03, 0.054, 0.048, fq), (qb, 0.058, 0.05, fq)], LEATHER, QW, n=10, caps=("round", "flat"), cap_k=0.4)
K.loft([(qb - qd * 0.03, 0.062, 0.054, fq), (qb, 0.062, 0.054, fq)], LEATHER_DARK, QW, n=10, caps=("flat", "flat"))
for k in range(4):
    off = Vector(((k % 2) * 0.02 - 0.01, (k // 2) * 0.02 - 0.01, 0.0))
    p0 = qb + off
    K.loft([(p0, 0.007, 0.007, fq), (p0 + qd * 0.05, 0.007, 0.007, fq)], WOOD, QW, n=4, caps=("flat", "flat"))
    K.box(p0 + qd * 0.085, (0.01, 0.026, 0.06), LINEN, QW)
# hood with a long tail (liripipe) and a short cape
shoulder_cape(K, ROLE_DARK, LEATHER_DARK, length=0.1, torn=False)
face(K, beard=HAIR, hair=None)
hood(K, ROLE_DARK, point=0.06, opening=58.0)
tail = K.loft([((0, 0.12, 1.69), 0.035, 0.03), ((0, 0.2, 1.6), 0.03, 0.025), ((0.02, 0.24, 1.46), 0.022, 0.02), ((0.04, 0.24, 1.33), 0.014, 0.012)],
              ROLE_DARK, lambda co: {"head": 1.0} if co.z > 1.5 else {"head": 0.4, "spine_03": 0.6}, n=8, caps=("flat", "round"))
RESULT["bowman"] = finish(ob, bm)
bm.free()

# ===================================================================== commander
ob = new_skinned("SK_BrigandBoss2", COL)
bm = bmesh.new()
K = Kit(ob, bm)
legs(K, LEATHER_DARK, knee=STEEL_DARK, shin=STEEL_DARK, boot=LEATHER_DARK, cuff=LEATHER, boot_top=0.16)
arms(K, MAIL, forearm=LEATHER_DARK, glove=LEATHER_DARK, bracer=STEEL_DARK, slim=1.08)
tunic(K, MAIL, MAIL, top=0.95, length=0.36, torn=False, inner=MAIL)      # mail shirt under the surcoat
torso(K, MAIL, chest=1.1, waist=1.08)
# torn red surcoat over the mail, longer, split front and back
for sgn in (-1.0, 1.0):
    def f(u, v, sg=sgn):
        z = 1.26 - 0.78 * v + ragged(v, u * 1.3 + sg, depth=0.05, teeth=3.5)
        return (-sg * u * (0.17 + 0.07 * v), sg * ((0.222 + 0.03 * v ** 0.6) - 0.025 * u * u), z)
    K.sheet(f, 8, 10, 0.014, ROLE, lambda co: torso_weights(co) if co.z > 0.98 else skirt_weights(0.95, 0.5, 0.7)(co), cell_in=ROLE_DARK,
            cell_fn=lambda u, v: ROLE_DARK if v > 0.93 else None)
belt(K, LEATHER_DARK, GOLD, z=0.985, r=(0.235, 0.2))
pouch(K, 0.16, z=0.92)
# heavy fur mantle around the shoulders
K.loft([((0, 0.02, 1.2), 0.3, 0.25), ((0, 0.015, 1.26), 0.31, 0.26), ((0, 0.005, 1.32), 0.25, 0.21), ((0, 0.0, 1.37), 0.16, 0.145)],
       HAIR, {"spine_03": 0.8, "clavicle_l": 0.1, "clavicle_r": 0.1}, n=20, e=2.2, caps=("flat", "flat"))
for k in range(12):   # fur tufts on the edge
    a = 2 * math.pi * (k + 0.5) / 12
    K.ellipsoid((math.cos(a) * 0.29, math.sin(a) * 0.24 + 0.02, 1.2), (0.05, 0.045, 0.04), HAIR,
                {"spine_03": 0.8, "clavicle_l": 0.1, "clavicle_r": 0.1}, n=6, m=3)
cloak(K, ROLE_DARK, inner=VOID, width=0.95, length=0.78, hem=ROLE_DARK)
face(K, beard=HAIR, hair=None)
hood(K, MAIL, lining=MAIL, point=0.0, opening=52.0)       # mail aventail
# nasal helmet (conical, blackened iron with a brass band)
K.loft([((0, 0.01, 1.585), 0.142, 0.156), ((0, 0.01, 1.66), 0.135, 0.15), ((0, 0.02, 1.74), 0.095, 0.108), ((0, 0.03, 1.81), 0.02, 0.024)],
       STEEL, HW, n=16, e=2.1, caps=("flat", "round"), cap_k=0.5)
K.loft([((0, 0.01, 1.58), 0.146, 0.16), ((0, 0.01, 1.615), 0.144, 0.158)], GOLD_DARK, HW, n=16, caps=("flat", "flat"))
K.box((0, -0.162, 1.54), (0.026, 0.016, 0.1), STEEL_DARK, HW, bevel=0.004)
RESULT["boss"] = finish(ob, bm)
bm.free()

# ===================================================================== weapons (grip at the origin, along +Z)
I3 = Matrix.Identity(3)
ax = new_skinned("SM_Brigand2_Axe", COL, armature=None)
wb = bmesh.new()
W = Kit(ax, wb)
W.loft([((0, 0, -0.18), 0.02, 0.02), ((0, 0, 0.64), 0.018, 0.018)], WOOD, {}, n=8, caps=("round", "round"), cap_k=0.4, frame=I3)
W.loft([((0, 0, -0.08), 0.024, 0.024), ((0, 0, 0.08), 0.024, 0.024)], LEATHER_DARK, {}, n=8, caps=("flat", "flat"), frame=I3)
W.box((0, 0, 0.56), (0.055, 0.05, 0.1), STEEL_DARK, {}, bevel=0.008)
W.sheet(lambda u, v: (0.03 + 0.2 * v, 0.0, 0.56 + u * (0.045 + 0.1 * v ** 1.6) - 0.04 * v * v), 4, 5, 0.02, STEEL, {},
        cell_fn=lambda u, v: STEEL_LIGHT if v > 0.8 else None)
W.box((-0.05, 0, 0.56), (0.05, 0.035, 0.045), STEEL_DARK, {}, bevel=0.006)
RESULT["axe"] = finish(ax, wb, ao=False)
wb.free()

sp = new_skinned("SM_Brigand2_Spear", COL, armature=None)
wb = bmesh.new()
W = Kit(sp, wb)
W.loft([((0, 0, -0.9), 0.021, 0.021), ((0, 0, 1.52), 0.019, 0.019)], WOOD, {}, n=8, caps=("flat", "flat"), frame=I3)
W.loft([((0, 0, 1.48), 0.027, 0.027), ((0, 0, 1.58), 0.022, 0.022)], STEEL_DARK, {}, n=8, caps=("flat", "flat"), frame=I3)
W.sheet(lambda u, v: (u * (0.008 + 0.05 * math.sin(math.pi * min(1.0, 0.15 + v * 0.95)) ** 0.8), 0.0, 1.57 + 0.28 * v), 4, 7, 0.018,
        STEEL, {}, cell_fn=lambda u, v: STEEL_LIGHT if abs(u) > 0.6 else None)
W.loft([((0, 0, 1.44), 0.03, 0.03), ((0, 0, 1.48), 0.03, 0.03)], LEATHER, {}, n=8, caps=("flat", "flat"), frame=I3)
W.sheet(lambda u, v: (0.02 + 0.07 * v, 0.0, 1.43 - 0.1 * (u + 1) * 0.5 - ragged(v, u, 0.03, 2.0) * 0.0 - 0.06 * v * v), 3, 4, 0.006,
        ROLE, {})   # rag tied below the head
W.loft([((0, 0, -0.95), 0.026, 0.026), ((0, 0, -0.9), 0.026, 0.026)], STEEL_DARK, {}, n=8, caps=("round", "flat"), cap_k=0.5, frame=I3)
RESULT["spear"] = finish(sp, wb, ao=False)
wb.free()

L_BOW = 0.78
SAG = 0.16
bw = new_skinned("SM_Brigand2_Bow", COL, armature=None)
wb = bmesh.new()
W = Kit(bw, wb)


def bow_pt(z):
    t = abs(z) / L_BOW
    return Vector((0, -SAG * t * t, z))


rings = []
for i in range(11):
    z = -L_BOW + 2 * L_BOW * i / 10
    th = 0.026 - 0.011 * abs(z) / L_BOW
    rings.append((bow_pt(z), th * 0.85, th * 1.15))
W.loft(rings, WOOD, {}, n=8, caps=("round", "round"), cap_k=0.5)
W.loft([((0, 0, -0.09), 0.031, 0.034), ((0, 0, 0.09), 0.031, 0.034)], LEATHER_DARK, {}, n=8, caps=("flat", "flat"), frame=I3)
W.sheet(lambda u, v: (0.03 + 0.05 * v, -0.01, 0.07 - 0.05 * (u + 1) * 0.5 - 0.1 * v), 2, 3, 0.006, ROLE, {})   # rag on the grip
for sz in (1, -1):
    a = bow_pt(sz * (L_BOW - 0.05))
    b = bow_pt(sz * (L_BOW + 0.01))
    W.loft([(a, 0.014, 0.014), (b, 0.009, 0.009)], LEATHER_DARK, {}, n=6, caps=("flat", "round"))
RESULT["bow"] = finish(bw, wb, ao=False)
wb.free()

# ===================================================================== export (with OUT set: the folder of the GLBs)
if "OUT" in globals():
    import os
    arm = bpy.data.objects["Armature"]
    for nm in ("SK_Brigand2", "SK_Spearman2", "SK_Bowman2", "SK_BrigandBoss2"):
        export_glb([arm, bpy.data.objects[nm]], os.path.join(OUT, nm + ".glb"))     # the skeleton must be in the selection (actions)
    for nm in ("SM_Brigand2_Axe", "SM_Brigand2_Spear", "SM_Brigand2_Bow"):
        export_glb([bpy.data.objects[nm]], os.path.join(OUT, nm + ".glb"), animations=False)
