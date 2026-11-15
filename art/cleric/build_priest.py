# Priest, Father Jan (visual prototype, 15.11.2026): built from scratch with art/tools/char_kit.py and
# art/chars/hero_body.py on the knight skeleton (Armature in Knight.blend; the animations A_Cleric_* stay).
# Run in Blender with Knight.blend open:
#   exec(open(r"<repo>/art/cleric/build_priest.py", encoding="utf-8").read(),
#        {"KIT": r"<repo>/art/tools/char_kit.py", "BODY": r"<repo>/art/chars/hero_body.py", "PAL": r"<repo>/art/chars/T_Char_Palette_D.png"})
# Result: SK_Priest and SM_Priest_Staff in the collection PRIEST_game (export with char_kit.export_glb).
# Design (style guide): a narrow bell from above. The class colour ivory carries the long robe, the hooded mantle over the
# shoulders and the sleeves; the order's navy is the stole down the front and the mantle's lining; gold on the cross,
# the belt and the staff. A small steel breastplate under the stole. Open bearded face under the hood.
import math
import bmesh
import bpy
from mathutils import Matrix, Vector

exec(open(KIT, encoding="utf-8").read(), globals())
exec(open(BODY, encoding="utf-8").read(), globals())
preview_material(PAL, 3)
COL = "PRIEST_game"

ob = new_skinned("SK_Priest", COL)
bm = bmesh.new()
K = Kit(ob, bm)

# ------------------------------------------------------------------ legs (shoes under the robe), arms in wide sleeves
legs(K, LINEN, boot=LEATHER_DARK, cuff=None, slim=0.9)
arms(K, ROLE, forearm=ROLE, glove=SKIN, cuff=ROLE_LIGHT)
for s in (1.0, -1.0):   # wide bell sleeves hanging from the forearm
    L = "l" if s > 0 else "r"
    S, E, W, d, fa = arm_frame(s)
    K.loft([(E + d * 0.03, 0.068, 0.068, fa), (W - d * 0.04, 0.094, 0.10, fa), (W + d * 0.0, 0.098, 0.106, fa)], ROLE,
           {"lowerarm_" + L: 1.0}, n=10, e=2.0, caps=("flat", "flat"))

# ------------------------------------------------------------------ robe: hips to the ankles, widening (the bell)


def robe_hem(u, v):
    return GOLD if v > 0.94 else None


robe_w = robe_weights(0.92, 0.5, 0.12)
K.loft([((0, 0, 1.0), 0.196, 0.152), ((0, 0, 0.86), 0.222, 0.172), ((0, 0.005, 0.55), 0.262, 0.214),
        ((0, 0.01, 0.25), 0.29, 0.244), ((0, 0.012, 0.075), 0.302, 0.256)], ROLE, robe_w, n=18, e=2.3, caps=("flat", "flat"))
K.loft([((0, 0.012, 0.09), 0.304, 0.258), ((0, 0.012, 0.06), 0.306, 0.26)], GOLD, robe_w, n=18, e=2.3, caps=("flat", "flat"))
torso(K, ROLE, chest=0.95)

# small steel breastplate under the stole
K.loft([((0, -0.03, 1.08), 0.165, 0.16), ((0, -0.04, 1.17), 0.2, 0.18), ((0, -0.03, 1.25), 0.18, 0.16)], STEEL, torso_weights,
       n=10, arc=(-150.0, -30.0), thick=0.015, e=2.4)

# stole: two navy bands from the neck down the front to below the knees, gold crosses at the ends
for s in (1.0, -1.0):
    def stole(u, v, s=s):
        x = s * (0.055 + 0.02 * v) + u * 0.032
        z = 1.3 - 0.86 * v
        y = -(0.166 + 0.05 * smoothstep(0.0, 0.25, v) - 0.04 * smoothstep(0.25, 0.4, v) + 0.085 * smoothstep(0.35, 1.0, v)) - 0.008
        return (x, y, z)
    K.sheet(stole, 2, 12, 0.008, NAVY, lambda co: {"spine_03": 1.0} if co.z > 1.1 else robe_w(co) if co.z < 0.95 else torso_weights(co),
            cell_fn=lambda u, v: GOLD if v > 0.92 else None)
belt(K, LEATHER, GOLD, z=0.985, r=(0.205, 0.162))
# rope cord hanging from the belt on the left
K.loft([((0.13, -0.13, 0.96), 0.014, 0.014), ((0.15, -0.16, 0.78), 0.013, 0.013), ((0.16, -0.17, 0.62), 0.012, 0.012)], LINEN,
       {"pelvis": 0.6, "thigh_l": 0.4}, n=6, caps=("flat", "round"))

# ------------------------------------------------------------------ mantle over the shoulders with the hood
MW = lambda co: {"spine_03": 0.75, "clavicle_l": 0.125, "clavicle_r": 0.125} if co.z > 1.16 else torso_weights(co)
K.loft([((0, 0.0, 1.36), 0.15, 0.13), ((0, 0.0, 1.31), 0.24, 0.19), ((0, 0.01, 1.25), 0.33, 0.24), ((0, 0.02, 1.14), 0.35, 0.26)],
       ROLE_LIGHT, MW, n=18, e=2.2, caps=("flat", "flat"))
K.loft([((0, 0.02, 1.15), 0.352, 0.262), ((0, 0.02, 1.125), 0.354, 0.264)], NAVY, MW, n=18, e=2.2, caps=("flat", "flat"))
# gold cross on the chest of the mantle
K.box((0, -0.262, 1.2), (0.024, 0.016, 0.11), GOLD, {"spine_03": 1.0}, bevel=0.004)
K.box((0, -0.262, 1.215), (0.075, 0.016, 0.024), GOLD, {"spine_03": 1.0}, bevel=0.004)

# head: bearded face, hood down on the shoulders behind the head (the face stays readable), a skullcap
face(K, beard=LINEN, hair=None)
hood_back = K.loft([((0, 0.06, 1.33), 0.15, 0.10), ((0, 0.11, 1.40), 0.13, 0.085), ((0, 0.14, 1.47), 0.08, 0.05)], ROLE_LIGHT,
                   {"spine_03": 0.5, "neck_01": 0.5}, n=12, e=2.1, caps=("flat", "round"), cap_k=0.8)
cap = K.loft([((0, 0.008, 1.612), 0.093, 0.107), ((0, 0.008, 1.645), 0.08, 0.094), ((0, 0.008, 1.672), 0.046, 0.056)], NAVY, {"head": 1.0},
             n=14, e=2.2, caps=("flat", "round"), cap_k=0.5)
scale_about(cap, (0, 0, 1.37), 1.08)

RESULT = finish(ob, bm)
bm.free()

# ------------------------------------------------------------------ staff (grip at the origin, along +Z; as the old SM_Cleric_Staff)
st = new_skinned("SM_Priest_Staff", COL, armature=None)
sb = bmesh.new()
S = Kit(st, sb)
S.loft([((0, 0, -0.62), 0.022, 0.022), ((0, 0, -0.58), 0.028, 0.028)], GOLD, {}, n=8, caps=("round", "flat"), frame=Matrix.Identity(3))
S.loft([((0, 0, -0.58), 0.024, 0.024), ((0, 0, 0.94), 0.021, 0.021)], WOOD, {}, n=8, caps=("flat", "flat"), frame=Matrix.Identity(3))
S.loft([((0, 0, -0.11), 0.027, 0.027), ((0, 0, 0.12), 0.027, 0.027)], NAVY, {}, n=8, caps=("flat", "flat"), frame=Matrix.Identity(3))
for z in (-0.14, 0.14, 0.58):
    S.loft([((0, 0, z), 0.03, 0.03), ((0, 0, z + 0.03), 0.03, 0.03)], GOLD, {}, n=8, caps=("flat", "flat"), frame=Matrix.Identity(3))
S.loft([((0, 0, 0.94), 0.026, 0.026), ((0, 0, 1.0), 0.034, 0.034)], GOLD, {}, n=8, caps=("flat", "flat"), frame=Matrix.Identity(3))
# head: a gold ring perpendicular to the shaft with a cross inside, a crimson stone in the middle
fy = frame_for((0, 1, 0))
ring_c = Vector((0, 0, 1.14))
for i in range(12):
    a0 = 2 * math.pi * i / 12
    a1 = 2 * math.pi * (i + 1) / 12
    p0 = ring_c + Vector((math.cos(a0) * 0.12, 0, math.sin(a0) * 0.12))
    p1 = ring_c + Vector((math.cos(a1) * 0.12, 0, math.sin(a1) * 0.12))
    S.loft([(p0, 0.018, 0.018), (p1, 0.018, 0.018)], GOLD, {}, n=6, caps=("flat", "flat"))
S.box(ring_c, (0.026, 0.03, 0.23), GOLD, {}, bevel=0.006)
S.box(ring_c + Vector((0, 0, 0.03)), (0.2, 0.03, 0.026), GOLD, {}, bevel=0.006)
S.ellipsoid(ring_c + Vector((0, 0, 0.03)), (0.03, 0.03, 0.03), CRIMSON, {}, n=8, m=4)
RESULT["staff"] = finish(st, sb, ao=False)
sb.free()
