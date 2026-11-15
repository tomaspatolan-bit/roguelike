# Archer, Matej (visual prototype, 15.11.2026): built from scratch with art/tools/char_kit.py and art/chars/hero_body.py
# on the knight skeleton (the animations A_Archer_* stay, so does the bow string in the game: same bow geometry).
# Run in Blender with Knight.blend open:
#   exec(open(r"<repo>/art/archer/build_archer2.py", encoding="utf-8").read(),
#        {"KIT": r"<repo>/art/tools/char_kit.py", "BODY": r"<repo>/art/chars/hero_body.py", "PAL": r"<repo>/art/chars/T_Char_Palette_D.png"})
# Result: SK_Archer2, SM_Archer2_Bow (left hand, grip at the origin, limbs along Z, tips towards -Y by SAG = 0.16 as before)
# and SM_Archer2_Arrow (projectile, tip along +Z) in the collection ARCHER2_game.
# Design (style guide): slim and asymmetric from above. Forest green carries the hood with its short shoulder cape, the
# padded tunic to the knee, the sleeves and gloves and the quiver (light bands and fletchings), a leather jerkin, brown boots, a feather on the hood. Open face with a short beard.
import math
import bmesh
import bpy
from mathutils import Matrix, Vector

exec(open(KIT, encoding="utf-8").read(), globals())
exec(open(BODY, encoding="utf-8").read(), globals())
preview_material(PAL, 2)
COL = "ARCHER2_game"

ob = new_skinned("SK_Archer2", COL)
bm = bmesh.new()
K = Kit(ob, bm)

# ------------------------------------------------------------------ legs, arms
legs(K, ROLE_DARK, boot=LEATHER, cuff=LEATHER, slim=0.92, boot_top=0.22)
arms(K, ROLE, forearm=ROLE_DARK, glove=ROLE_DARK, bracer=ROLE_LIGHT, bracer_sides=(1.0,), slim=0.94)

# ------------------------------------------------------------------ tunic to mid-thigh, split at the sides


def tunic_hem(u, v):
    return ROLE_DARK if v > 0.92 else None


for sgn in (-1.0, 1.0):     # front and back panels
    K.sheet(lambda u, v, sg=sgn: (-sg * u * (0.13 + 0.06 * v), sg * ((0.152 + 0.055 * v ** 0.6) - 0.02 * u * u), 0.95 - 0.44 * v),
            6, 7, 0.014, ROLE, skirt_weights(0.93, 0.55, 0.75), cell_in=ROLE_DARK, cell_fn=tunic_hem)
K.loft([((0, 0, 0.985), 0.186, 0.142), ((0, 0, 0.86), 0.2, 0.152), ((0, 0, 0.74), 0.212, 0.16)], ROLE_DARK,
       skirt_weights(0.92, 0.74, 0.55), n=14, e=2.4, caps=("flat", "flat"))
torso(K, ROLE, chest=0.94, waist=0.95)
# leather jerkin over the tunic (front and back plates of the torso)
K.loft([((0, 0, 1.0), 0.196, 0.153), ((0, -0.012, 1.15), 0.222, 0.172), ((0, -0.006, 1.26), 0.205, 0.158)], LEATHER, torso_weights,
       n=10, arc=(-140.0, -40.0), thick=0.014, e=2.5)
K.loft([((0, 0, 1.0), 0.196, 0.153), ((0, -0.012, 1.15), 0.222, 0.172), ((0, -0.006, 1.26), 0.205, 0.158)], LEATHER, torso_weights,
       n=10, arc=(40.0, 140.0), thick=0.014, e=2.5)
belt(K, LEATHER_DARK, STEEL_LIGHT, z=0.97)
# quiver strap from the right shoulder to the left hip (across the chest)
K.loft([((-0.15, -0.16, 1.3), 0.03, 0.012), ((0.0, -0.21, 1.15), 0.03, 0.012), ((0.16, -0.17, 0.98), 0.03, 0.012)], LEATHER_DARK,
       torso_weights, n=6, caps=("flat", "flat"), frame=frame_for((0, 1, 0)))
# left shoulder (towards the enemy when drawing): a leather spaulder; the right stays light
shoulder_cap(K, 1.0, ROLE_PAINT, size=(0.11, 0.12, 0.075), rim=LEATHER)

# ------------------------------------------------------------------ head: face under the green hood with a short cape


def cape_w(co):
    return {"spine_03": 0.7, "clavicle_l": 0.15, "clavicle_r": 0.15} if co.z > 1.2 else torso_weights(co)


K.loft([((0, 0.0, 1.36), 0.15, 0.13), ((0, 0.0, 1.31), 0.24, 0.19), ((0, 0.012, 1.24), 0.3, 0.22), ((0, 0.02, 1.16), 0.31, 0.235)],
       ROLE, cape_w, n=18, e=2.2, caps=("flat", "flat"))
K.loft([((0, 0.02, 1.17), 0.312, 0.237), ((0, 0.02, 1.15), 0.314, 0.239)], ROLE_DARK, cape_w, n=18, e=2.2, caps=("flat", "flat"))
face(K, beard=HAIR, hair=None)
hood(K, ROLE, point=0.08)
# feather on the left side of the hood
fr = frame_for((0.25, 0.5, 0.83))
feather = K.loft([((0.13, 0.03, 1.58), 0.006, 0.015, fr), ((0.16, 0.09, 1.68), 0.012, 0.03, fr), ((0.19, 0.15, 1.77), 0.008, 0.022, fr),
                  ((0.2, 0.18, 1.81), 0.003, 0.006, fr)], CRIMSON, {"head": 1.0}, n=6, caps=("flat", "flat"))
scale_about(feather, (0, 0, 1.37), 1.08)

# ------------------------------------------------------------------ quiver on the back: slanted, mouth above the right shoulder
qa = Vector((0.13, 0.2, 0.92))      # bottom
qb = Vector((-0.14, 0.22, 1.4))     # mouth
qd = (qb - qa).normalized()
fq = frame_for(qd, ref=(1, 0, 0))
QW = lambda co: {"spine_03": 1.0} if co.z > 1.18 else {"spine_02": 1.0} if co.z > 1.05 else {"spine_01": 1.0}
K.loft([(qa, 0.052, 0.046, fq), (qa + qd * 0.03, 0.056, 0.05, fq), (qb, 0.06, 0.054, fq)], ROLE_DARK, QW, n=10, caps=("round", "flat"), cap_k=0.4)
K.loft([(qb - qd * 0.02, 0.064, 0.058, fq), (qb + qd * 0.01, 0.064, 0.058, fq)], LINEN, QW, n=10, caps=("flat", "flat"))
K.loft([(qa + qd * 0.12, 0.058, 0.052, fq), (qa + qd * 0.15, 0.058, 0.052, fq)], LINEN, QW, n=10, caps=("flat", "flat"))
for k in range(5):   # fletchings above the mouth
    off = Vector(((k - 2) * 0.018, (k % 2) * 0.016 - 0.008, 0.0))
    p0 = qb + off
    K.loft([(p0, 0.008, 0.008, fq), (p0 + qd * 0.05, 0.008, 0.008, fq)], WOOD, QW, n=4, caps=("flat", "flat"))
    K.box(p0 + qd * 0.09, (0.012, 0.03, 0.07), CRIMSON if k % 2 else IVORY, QW)

RESULT = finish(ob, bm)
bm.free()

# ------------------------------------------------------------------ longbow (as before: L = 0.78, SAG = 0.16; the game draws the string)
L_BOW = 0.78
SAG = 0.16
bw = new_skinned("SM_Archer2_Bow", COL, armature=None)
wb = bmesh.new()
B2 = Kit(bw, wb)


def bow_pt(z):
    t = abs(z) / L_BOW
    return Vector((0, -SAG * t * t, z))


rings = []
for i in range(11):
    z = -L_BOW + 2 * L_BOW * i / 10
    th = 0.028 - 0.012 * abs(z) / L_BOW
    rings.append((bow_pt(z), th * 0.85, th * 1.2))
B2.loft(rings, WOOD, {}, n=8, caps=("round", "round"), cap_k=0.5)
B2.loft([((0, 0, -0.1), 0.032, 0.036), ((0, 0, 0.1), 0.032, 0.036)], ROLE_DARK, {}, n=8, caps=("flat", "flat"), frame=Matrix.Identity(3))
for z in (0.1, -0.12):
    B2.loft([((0, 0, z), 0.035, 0.038), ((0, 0, z + 0.02), 0.035, 0.038)], GOLD, {}, n=8, caps=("flat", "flat"), frame=Matrix.Identity(3))
for sz in (1, -1):
    a = bow_pt(sz * (L_BOW - 0.07))
    b = bow_pt(sz * (L_BOW + 0.015))
    B2.loft([(a, 0.016, 0.016), (b, 0.01, 0.01)], STEEL_LIGHT, {}, n=6, caps=("flat", "round"))
RESULT["bow"] = finish(bw, wb, ao=False)
wb.free()

# ------------------------------------------------------------------ arrow (projectile): tip along +Z, 0.8 m, origin in the middle
ar = new_skinned("SM_Archer2_Arrow", COL, armature=None)
wa = bmesh.new()
A2 = Kit(ar, wa)
I3 = Matrix.Identity(3)
A2.loft([((0, 0, -0.4), 0.011, 0.011), ((0, 0, 0.33), 0.011, 0.011)], WOOD, {}, n=6, caps=("flat", "flat"), frame=I3)
A2.loft([((0, 0, 0.33), 0.024, 0.008), ((0, 0, 0.43), 0.002, 0.002)], STEEL_LIGHT, {}, n=6, caps=("flat", "flat"), frame=I3)
for k in range(3):
    a = 2 * math.pi * k / 3
    d = Vector((math.cos(a), math.sin(a), 0))
    A2.box(Vector((0, 0, -0.32)) + d * 0.022, (0.004, 0.04, 0.12), CRIMSON, {},
           rot=Matrix.Rotation(a + math.pi / 2, 3, "Z"))
RESULT["arrow"] = finish(ar, wa, ao=False)
wa.free()
