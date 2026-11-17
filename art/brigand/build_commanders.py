# Brigand commanders (17.11.2026, decision 17.11.2026): four own models instead of one shared SK_BrigandBoss2, so each
# commander can be told apart from the battle camera and his build hints at how to fight him. Same kit, body and knight
# skeleton as the heroes and brigands (the old animations fit); palette row 7 (blood red, blackened iron). Size comes on
# top in the game from the data (`scale` [width, height] per commander), the meshes carry the build itself.
# Run in Blender with Knight.blend open:
#   exec(open(r"<repo>/art/brigand/build_commanders.py", encoding="utf-8").read(),
#        {"KIT": r"<repo>/art/tools/char_kit.py", "BODY": r"<repo>/art/chars/hero_body.py",
#         "PAL": r"<repo>/art/chars/T_Char_Palette_D.png", "OUT": r"<repo>/art/brigand"})
# Without OUT it only builds. Result (collection COMMANDERS_game):
#   SK_BossKuno     Captain Kuno, the heavy one: breastplate over mail, huge fur mantle, long red cloak, horned helm
#   SK_BossVok      Vok the Burner, the quick one: bare head, scorched leather apron, red scarf, no armour
#   SK_BossJira     Jíra the Marksman, the far one: long hooded cloak to the ankles, masked face, quiver of red arrows
#   SK_BossBorivoj  Sergeant Bořivoj, the wall: wide-brimmed iron hat, quilted red gambeson, tall shield on the left arm
#   SM_Kuno_Greataxe, SM_Vok_Torch (left hand; the hatchet is SM_Brigand2_Axe), SM_Jira_Longbow (L 0.95, SAG 0.2:
#   string top/bottom [0, ±0.96, 0.2] in the data); Bořivoj carries SM_Brigand2_Spear.
import math
import os
import bmesh
import bpy
from mathutils import Matrix, Vector

exec(open(KIT, encoding="utf-8").read(), globals())
exec(open(BODY, encoding="utf-8").read(), globals())
exec(open(os.path.join(os.path.dirname(os.path.dirname(BODY)), "brigand", "brigand_parts.py"), encoding="utf-8").read(), globals())
preview_material(PAL, 7)
COL = "COMMANDERS_game"
RESULT = {}
X = Vector((1.0, 0.0, 0.0))
Y = Vector((0.0, 1.0, 0.0))
SHOULDERS = {"spine_03": 0.8, "clavicle_l": 0.1, "clavicle_r": 0.1}


def fur_mantle(K, r=(0.3, 0.25), z=1.2, tufts=12, scale=1.0):
    rx, ry = r[0] * scale, r[1] * scale
    K.loft([((0, 0.02, z), rx, ry), ((0, 0.015, z + 0.06), rx * 1.03, ry * 1.03), ((0, 0.005, z + 0.12), rx * 0.83, ry * 0.84),
            ((0, 0.0, z + 0.17), 0.16, 0.145)], HAIR, SHOULDERS, n=20, e=2.2, caps=("flat", "flat"))
    for k in range(tufts):
        a = 2 * math.pi * (k + 0.5) / tufts
        K.ellipsoid((math.cos(a) * rx * 0.97, math.sin(a) * ry * 0.97 + 0.02, z), (0.055 * scale, 0.05 * scale, 0.045), HAIR,
                    SHOULDERS, n=6, m=3)


# ===================================================================== Captain Kuno (heavy)
ob = new_skinned("SK_BossKuno", COL)
bm = bmesh.new()
K = Kit(ob, bm)
legs(K, LEATHER_DARK, knee=STEEL, shin=STEEL, boot=STEEL_DARK, cuff=LEATHER, thigh_plate=STEEL_DARK, boot_top=0.16)
arms(K, MAIL, forearm=STEEL_DARK, glove=STEEL_DARK, elbow=STEEL, bracer=STEEL, slim=1.14)
tunic(K, MAIL, MAIL, top=0.95, length=0.42, flare=0.08, torn=False, inner=MAIL)
torso(K, MAIL, chest=1.2, waist=1.24)
# breastplate over the mail (front and sides), a brass rim at the top
K.loft([((0, -0.012, 0.98), 0.248, 0.2), ((0, -0.03, 1.12), 0.272, 0.225), ((0, -0.02, 1.25), 0.25, 0.205)], STEEL, torso_weights,
       n=16, arc=(-170.0, -10.0), thick=0.02, e=2.4)
K.loft([((0, -0.02, 1.24), 0.252, 0.207), ((0, -0.02, 1.27), 0.25, 0.205)], GOLD_DARK, torso_weights, n=16, arc=(-170.0, -10.0),
       thick=0.02, e=2.4)
# torn red surcoat panels front and back below the plate
for sgn in (-1.0, 1.0):
    def f(u, v, sg=sgn):
        z = 0.99 - 0.5 * v + ragged(v, u * 1.3 + sg, depth=0.05, teeth=3.5)
        return (-sg * u * (0.17 + 0.07 * v), sg * ((0.23 + 0.05 * v ** 0.6) - 0.025 * u * u), z)
    K.sheet(f, 8, 7, 0.014, ROLE, skirt_weights(0.97, 0.45, 0.7), cell_in=ROLE_DARK, cell_fn=lambda u, v: ROLE_DARK if v > 0.9 else None)
belt(K, LEATHER_DARK, GOLD, z=0.99, r=(0.262, 0.214))
pouch(K, 0.18, z=0.93)
# big rounded pauldrons over the fur
for s in (1.0, -1.0):
    L = "l" if s > 0 else "r"
    K.ellipsoid((s * 0.31, 0.0, 1.27), (0.13, 0.135, 0.1), STEEL_DARK, {"upperarm_" + L: 0.7, "clavicle_" + L: 0.3}, n=12, m=5,
                z_range=(-0.1, 1.0))
fur_mantle(K, scale=1.12)
cloak(K, ROLE_DARK, inner=VOID, width=1.1, length=1.0, hem=ROLE_DARK)
face(K, beard=HAIR, hair=None, scale=1.1)
hood(K, MAIL, lining=MAIL, point=0.0, opening=50.0, scale=1.1)
# conical helm with a brass band, nasal and two short horns
K.loft([((0, 0.01, 1.6), 0.15, 0.164), ((0, 0.01, 1.68), 0.142, 0.157), ((0, 0.02, 1.77), 0.1, 0.112), ((0, 0.03, 1.85), 0.022, 0.026)],
       STEEL, HW, n=16, e=2.1, caps=("flat", "round"), cap_k=0.5)
K.loft([((0, 0.01, 1.595), 0.154, 0.168), ((0, 0.01, 1.632), 0.152, 0.166)], GOLD, HW, n=16, caps=("flat", "flat"))
K.box((0, -0.17, 1.55), (0.03, 0.018, 0.11), STEEL_DARK, HW, bevel=0.004)
for s in (1.0, -1.0):
    p0 = Vector((s * 0.13, 0.02, 1.7))
    K.loft([(p0, 0.035, 0.035), (p0 + Vector((s * 0.09, 0.0, 0.07)), 0.025, 0.025), (p0 + Vector((s * 0.11, 0.0, 0.16)), 0.006, 0.006)],
           IVORY, HW, n=8, caps=("flat", "round"))
RESULT["kuno"] = finish(ob, bm)
bm.free()

# ===================================================================== Vok the Burner (quick, no armour)
ob = new_skinned("SK_BossVok", COL)
bm = bmesh.new()
K = Kit(ob, bm)
legs(K, LEATHER_DARK, boot=LEATHER, cuff=LEATHER_DARK, slim=0.9, boot_top=0.2)
arms(K, ROLE_DARK, forearm=SKIN, glove=LEATHER_DARK, bracer=LEATHER, cuff=None, slim=0.9)
tunic(K, ROLE_DARK, VOID, length=0.34, flare=0.04, inner=ROLE_DARK)
torso(K, ROLE_DARK, chest=0.92, waist=0.92)
# scorched leather apron, long in front, black burns along the hem
K.sheet(lambda u, v: (-u * (0.15 + 0.03 * v), -(0.175 + 0.07 * v) + 0.02 * u * u, 1.24 - 0.62 * v + ragged(v, u, 0.04, 3.0)), 6, 10, 0.012,
        LEATHER_DARK, lambda co: torso_weights(co) if co.z > 0.98 else skirt_weights(0.95, 0.6, 0.6)(co), cell_in=LEATHER_DARK,
        cell_fn=lambda u, v: VOID if (v > 0.82 or (0.4 < v < 0.5 and u > 0.3)) else None)
belt(K, LEATHER, STEEL_DARK, z=0.97, r=(0.19, 0.15))
for x in (0.15, -0.15):   # oil flasks on the belt
    K.ellipsoid((x, -0.1, 0.9), (0.04, 0.04, 0.06), IVORY, {"pelvis": 1.0}, n=8, m=4)
    K.loft([((x, -0.1, 0.95), 0.015, 0.015), ((x, -0.1, 0.99), 0.012, 0.012)], LEATHER_DARK, {"pelvis": 1.0}, n=6, caps=("flat", "flat"))
# red scarf with two tails flying back
collar(K, ROLE, r=(0.14, 0.13))
for s in (1.0, -1.0):
    K.loft([((s * 0.05, 0.13, 1.33), 0.04, 0.012), ((s * 0.07, 0.2, 1.2), 0.035, 0.01), ((s * 0.09, 0.24, 1.05), 0.03, 0.008)], ROLE,
           lambda co: {"spine_03": 1.0}, n=6, caps=("flat", "flat"), frame=frame_for((0, 0.2, -1), ref=(1, 0, 0)))
face(K, beard=HAIR, hair=None)
# bald head with a ring of hair and a soot smear
K.ellipsoid((0, 0.02, 1.52), (0.112, 0.124, 0.06), HAIR, HW, n=12, m=4, z_range=(-1.0, 0.25))
RESULT["vok"] = finish(ob, bm)
bm.free()

# ===================================================================== Jíra the Marksman (far, tall, cloaked)
ob = new_skinned("SK_BossJira", COL)
bm = bmesh.new()
K = Kit(ob, bm)
legs(K, LEATHER_DARK, shin=LINEN, boot=LEATHER_DARK, cuff=LEATHER, slim=0.9, boot_top=0.24)
arms(K, LEATHER_DARK, forearm=LEATHER_DARK, glove=LEATHER, bracer=ROLE, bracer_sides=(1.0,), slim=0.9)
tunic(K, LEATHER, LEATHER_DARK, length=0.42, flare=0.04, torn=False, inner=LEATHER)
torso(K, LEATHER, chest=0.94, waist=0.94)
belt(K, LEATHER_DARK, STEEL_DARK, z=0.97, r=(0.19, 0.15))
# quiver on the back, red fletching sticking up over the right shoulder
qa = Vector((0.1, 0.19, 0.95))
qb = Vector((-0.12, 0.2, 1.42))
qd = (qb - qa).normalized()
fq = frame_for(qd, ref=(0, 1, 0))
QW = lambda co: {"spine_03": 1.0} if co.z > 1.15 else {"spine_02": 1.0}
K.loft([(qa, 0.065, 0.055, fq), (qb, 0.07, 0.06, fq)], LEATHER_DARK, QW, n=10, caps=("round", "flat"), cap_k=0.4)
K.loft([(qb - qd * 0.03, 0.075, 0.064, fq), (qb, 0.075, 0.064, fq)], ROLE_DARK, QW, n=10, caps=("flat", "flat"))
for k in range(7):
    a = 2 * math.pi * k / 7
    off = Vector((math.cos(a) * 0.035, math.sin(a) * 0.03, 0.0))
    p0 = qb + off
    K.loft([(p0, 0.006, 0.006, fq), (p0 + qd * 0.07, 0.006, 0.006, fq)], WOOD, QW, n=4, caps=("flat", "flat"))
    K.box(p0 + qd * 0.11, (0.012, 0.03, 0.075), ROLE, QW)
cloak(K, ROLE_DARK, inner=VOID, width=1.0, length=1.28, hem=ROLE_DARK, folds=4.0)
collar(K, ROLE_DARK, r=(0.15, 0.135))
face(K, beard=None, hair=None)
K.loft([((0, -0.035, 1.43), 0.095, 0.11), ((0, -0.04, 1.5), 0.1, 0.112)], VOID, HW, n=12, arc=(-160.0, -20.0), thick=0.012)   # mask
hood(K, ROLE_DARK, point=0.14, opening=52.0)
RESULT["jira"] = finish(ob, bm)
bm.free()

# ===================================================================== Sergeant Bořivoj (wall: hat, gambeson, shield)
ob = new_skinned("SK_BossBorivoj", COL)
bm = bmesh.new()
K = Kit(ob, bm)
legs(K, LEATHER_DARK, knee=STEEL_DARK, shin=STEEL_DARK, boot=LEATHER_DARK, cuff=LEATHER, boot_top=0.18)
arms(K, ROLE, forearm=ROLE, glove=LEATHER_DARK, elbow=STEEL_DARK, bracer=LEATHER, slim=1.16)
tunic(K, MAIL, MAIL, top=0.95, length=0.36, flare=0.08, torn=False, inner=MAIL)
torso(K, ROLE, chest=1.2, waist=1.22)
for z in (1.02, 1.1, 1.18):   # quilting
    K.loft([((0, -0.012, z - 0.006), 0.262, 0.204), ((0, -0.012, z + 0.006), 0.262, 0.204)], ROLE_DARK, torso_weights, n=16, e=2.5,
           caps=("flat", "flat"))
belt(K, LEATHER_DARK, GOLD, z=0.975, r=(0.255, 0.205))
pouch(K, -0.18)
hood(K, MAIL, lining=MAIL, point=0.0, opening=55.0)      # mail coif under the hat
face(K, beard=HAIR, hair=None, scale=1.08)
kettle_hat(K, dome=STEEL_DARK, brim=STEEL, z=1.64, r=(0.3, 0.315))
# tall shield on the left forearm (as the tank's: long axis 40 degrees off the forearm)
E = Vector((0.512, 0, 1.038))
Wr = Vector((0.689, 0, 0.861))
a0 = (Wr - E).normalized()
n = Vector((0.7071, 0, 0.7071))
PHI = math.radians(40.0)
a = a0 * math.cos(PHI) + Y * math.sin(PHI)
b = -a0 * math.sin(PHI) + Y * math.cos(PHI)
C = E + a0 * 0.14 + n * 0.12
SH_H, SH_TOP, SH_W = 0.95, -0.47, 0.3


def sh(u, v):
    hw = SH_W * (1.0 - 0.18 * max(0.0, v - 0.75) / 0.25)
    x = -u * hw
    return C + b * x + a * (SH_TOP + SH_H * v) + n * (-0.5 * x * x)


def sh_cells(u, v):
    if abs(u) > 0.9 or v < 0.05 or v > 0.95:
        return STEEL_DARK
    if abs(u) < 0.12 or abs(v - 0.42) < 0.05:
        return IVORY     # pale cross
    return None


K.sheet(sh, 16, 18, 0.035, ROLE_PAINT, {"lowerarm_l": 1.0}, cell_in=WOOD, cell_fn=sh_cells)
K.ellipsoid(C + a * (SH_TOP + SH_H * 0.42) + n * 0.006, (0.075, 0.075, 0.045), STEEL, {"lowerarm_l": 1.0}, n=10, m=4,
            frame=Matrix((a, b, n)).transposed(), z_range=(0.0, 1.0))
RESULT["borivoj"] = finish(ob, bm)
bm.free()

# ===================================================================== weapons (grip at the origin, along +Z)
I3 = Matrix.Identity(3)
ga = new_skinned("SM_Kuno_Greataxe", COL, armature=None)
wb = bmesh.new()
W = Kit(ga, wb)
W.loft([((0, 0, -0.45), 0.026, 0.026), ((0, 0, 1.12), 0.024, 0.024)], WOOD, {}, n=8, caps=("round", "round"), cap_k=0.4, frame=I3)
for z0, z1 in ((-0.12, 0.04), (0.3, 0.42)):
    W.loft([((0, 0, z0), 0.03, 0.03), ((0, 0, z1), 0.03, 0.03)], LEATHER_DARK, {}, n=8, caps=("flat", "flat"), frame=I3)
W.box((0, 0, 0.98), (0.075, 0.065, 0.16), STEEL_DARK, {}, bevel=0.01)
for sx in (1.0, -1.0):   # double bearded blade
    W.sheet(lambda u, v, sx=sx: (sx * (0.04 + 0.26 * v), 0.0, 0.98 + u * (0.06 + 0.17 * v ** 1.5) - 0.05 * v * v), 4, 6, 0.024, STEEL, {},
            cell_fn=lambda u, v: STEEL_LIGHT if v > 0.82 else None)
W.loft([((0, 0, 1.06), 0.02, 0.02), ((0, 0, 1.22), 0.004, 0.004)], STEEL, {}, n=6, caps=("flat", "flat"), frame=I3)   # spike
RESULT["greataxe"] = finish(ga, wb, ao=False)
wb.free()

tc = new_skinned("SM_Vok_Torch", COL, armature=None)
wb = bmesh.new()
W = Kit(tc, wb)
W.loft([((0, 0, -0.12), 0.022, 0.022), ((0, 0, 0.5), 0.026, 0.026)], WOOD, {}, n=8, caps=("round", "flat"), frame=I3)
W.loft([((0, 0, 0.44), 0.04, 0.04), ((0, 0, 0.54), 0.048, 0.048), ((0, 0, 0.6), 0.038, 0.038)], LINEN, {}, n=8, caps=("flat", "flat"),
       frame=I3)
# flame: two nested twisted cones (bright gold inside, light red outside)
W.loft([((0, 0, 0.58), 0.075, 0.07), ((0.01, 0, 0.7), 0.06, 0.055), ((-0.01, 0.01, 0.82), 0.03, 0.028), ((0.02, 0, 0.92), 0.004, 0.004)],
       ROLE_LIGHT, {}, n=8, caps=("flat", "round"), frame=I3)
W.loft([((0, -0.03, 0.6), 0.05, 0.04), ((0, -0.04, 0.72), 0.035, 0.03), ((0.01, -0.045, 0.82), 0.004, 0.004)], GOLD, {}, n=8,
       caps=("flat", "round"), frame=I3)
RESULT["torch"] = finish(tc, wb, ao=False)
wb.free()

L_BOW = 0.95
SAG = 0.2
bw = new_skinned("SM_Jira_Longbow", COL, armature=None)
wb = bmesh.new()
W = Kit(bw, wb)


def bow_pt(z):
    t = abs(z) / L_BOW
    return Vector((0, -SAG * t * t, z))


rings = []
for i in range(13):
    z = -L_BOW + 2 * L_BOW * i / 12
    th = 0.028 - 0.012 * abs(z) / L_BOW
    rings.append((bow_pt(z), th * 0.85, th * 1.15))
W.loft(rings, WOOD, {}, n=8, caps=("round", "round"), cap_k=0.5)
W.loft([((0, 0, -0.1), 0.033, 0.036), ((0, 0, 0.1), 0.033, 0.036)], ROLE, {}, n=8, caps=("flat", "flat"), frame=I3)
for sz in (1, -1):
    a_ = bow_pt(sz * (L_BOW - 0.06))
    b_ = bow_pt(sz * (L_BOW + 0.01))
    W.loft([(a_, 0.015, 0.015), (b_, 0.009, 0.009)], STEEL_DARK, {}, n=6, caps=("flat", "round"))
RESULT["longbow"] = finish(bw, wb, ao=False)
wb.free()

# ===================================================================== export (with OUT set)
if "OUT" in globals():
    arm = bpy.data.objects["Armature"]
    for nm in ("SK_BossKuno", "SK_BossVok", "SK_BossJira", "SK_BossBorivoj"):
        export_glb([arm, bpy.data.objects[nm]], os.path.join(OUT, nm + ".glb"))     # the skeleton must be in the selection
    for nm in ("SM_Kuno_Greataxe", "SM_Vok_Torch", "SM_Jira_Longbow"):
        export_glb([bpy.data.objects[nm]], os.path.join(OUT, nm + ".glb"), animations=False)
