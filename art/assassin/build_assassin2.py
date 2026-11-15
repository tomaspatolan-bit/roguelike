# Assassin, Krystof (visual prototype, 15.11.2026): built from scratch with art/tools/char_kit.py and
# art/chars/hero_body.py on the knight skeleton (the animations A_Assassin_* stay).
# Run in Blender with Knight.blend open:
#   exec(open(r"<repo>/art/assassin/build_assassin2.py", encoding="utf-8").read(),
#        {"KIT": r"<repo>/art/tools/char_kit.py", "BODY": r"<repo>/art/chars/hero_body.py", "PAL": r"<repo>/art/chars/T_Char_Palette_D.png"})
# Result: SK_Assassin2 and SM_Assassin2_Dagger (both hands) in the collection ASSASSIN2_game.
# Design (style guide): small and compact, a pointed hood, a short capelet thrown over the left shoulder (asymmetry),
# one steel spaulder on the right. Muted violet carries the hood, capelet, tunic and sleeves; dark leather on the legs
# and forearms, a crimson sash, a scarf over the lower face. Elegant rather than grim: a light violet lining, gold buckles.
import math
import bmesh
import bpy
from mathutils import Matrix, Vector

exec(open(KIT, encoding="utf-8").read(), globals())
exec(open(BODY, encoding="utf-8").read(), globals())
preview_material(PAL, 5)
COL = "ASSASSIN2_game"

ob = new_skinned("SK_Assassin2", COL)
bm = bmesh.new()
K = Kit(ob, bm)

# ------------------------------------------------------------------ legs and arms: slim, leather
legs(K, ROLE_DARK, boot=LEATHER_DARK, cuff=LEATHER, slim=0.86, boot_top=0.36)
arms(K, ROLE, forearm=ROLE_DARK, glove=VOID, bracer=LEATHER, bracer_sides=(-1.0,), slim=0.88)

# ------------------------------------------------------------------ tunic with long front and back flaps, sash


def flap_hem(u, v):
    return ROLE_LIGHT if v > 0.92 else None


for sgn in (-1.0, 1.0):
    K.sheet(lambda u, v, sg=sgn: (-sg * u * (0.1 + 0.03 * v), sg * ((0.148 + 0.04 * v ** 0.6) - 0.02 * u * u), 0.94 - 0.42 * v),
            5, 7, 0.012, ROLE, skirt_weights(0.93, 0.6, 0.75), cell_in=ROLE_DARK, cell_fn=flap_hem)
K.loft([((0, 0, 0.985), 0.18, 0.138), ((0, 0, 0.86), 0.19, 0.145), ((0, 0, 0.78), 0.196, 0.15)], ROLE_DARK,
       skirt_weights(0.92, 0.78, 0.5), n=14, e=2.4, caps=("flat", "flat"))
torso(K, ROLE, chest=0.9, waist=0.92)
# crimson sash, knot on the left with two tails
K.loft([((0, 0, 0.94), 0.19, 0.147), ((0, 0, 1.01), 0.186, 0.144)], CRIMSON, {"pelvis": 1.0}, n=14, e=2.4, caps=("flat", "flat"))
for k, (dx, dz) in enumerate(((0.0, 0.0), (0.03, -0.02))):
    K.loft([((0.17 + dx, -0.06, 0.96), 0.03, 0.01), ((0.19 + dx, -0.07, 0.86 + dz), 0.028, 0.009), ((0.2 + dx, -0.06, 0.76 + dz), 0.024, 0.008)],
           CRIMSON, {"pelvis": 0.5, "thigh_l": 0.5}, n=6, caps=("flat", "flat"), frame=frame_for((0, -1, 0)))
# leather baldric with gold buckle across the chest (left shoulder to right hip)
K.loft([((0.15, -0.15, 1.3), 0.028, 0.012), ((0.0, -0.195, 1.15), 0.028, 0.012), ((-0.16, -0.16, 0.99), 0.028, 0.012)], LEATHER,
       torso_weights, n=6, caps=("flat", "flat"), frame=frame_for((0, 1, 0)))
K.box((0.0, -0.205, 1.15), (0.04, 0.014, 0.04), GOLD, torso_weights, bevel=0.005)
# crossed dagger sheaths on the back at the waist
for s in (1.0, -1.0):
    fs = frame_for((s * 0.8, 0.0, -0.6), ref=(0, 1, 0))
    K.loft([((-s * 0.11, 0.17, 1.02), 0.022, 0.012, fs), ((s * 0.08, 0.17, 0.88), 0.016, 0.009, fs)], LEATHER_DARK,
           {"pelvis": 1.0}, n=6, caps=("flat", "round"))
    K.box((-s * 0.13, 0.17, 1.04), (0.03, 0.03, 0.05), GOLD, {"pelvis": 1.0}, bevel=0.005)

# ------------------------------------------------------------------ right spaulder (steel), capelet over the left shoulder
shoulder_cap(K, -1.0, ROLE_PAINT, size=(0.11, 0.12, 0.08), rim=STEEL)


def capelet_w(co):
    t = smoothstep(1.3, 1.02, co.z)
    side = smoothstep(0.0, 0.2, co.x)
    return {"spine_03": 1.0 - 0.6 * t * side, "upperarm_l": 0.45 * t * side, "spine_02": 0.15 * t * side}


# a half cape thrown over the left shoulder: a shell around the neck covering the left side and the back, longer on the
# left. The path goes down, so the front (-Y) is at ring angle 90, the left (+X) at 0, the back at -90.
K.loft([((0.0, 0.0, 1.37), 0.15, 0.13), ((0.02, 0.0, 1.32), 0.25, 0.2), ((0.04, 0.012, 1.25), 0.31, 0.235),
        ((0.06, 0.02, 1.15), 0.33, 0.25), ((0.08, 0.025, 1.04), 0.335, 0.255)], ROLE, capelet_w, n=16, e=2.2,
       arc=(-135.0, 105.0), thick=0.016)
K.loft([((0.08, 0.025, 1.05), 0.336, 0.256), ((0.08, 0.025, 1.025), 0.338, 0.258)], ROLE_LIGHT, capelet_w, n=16, e=2.2,
       arc=(-135.0, 105.0), thick=0.016)
collar(K, ROLE_DARK, r=(0.13, 0.12), z0=1.29, z1=1.37)

# ------------------------------------------------------------------ head: face, scarf over the mouth, pointed hood
face(K, beard=None, hair=None)
scarf = K.loft([((0, -0.02, 1.36), 0.09, 0.096), ((0, -0.03, 1.43), 0.098, 0.104), ((0, -0.03, 1.5), 0.1, 0.108)], VOID,
               {"head": 0.7, "neck_01": 0.3}, n=14, e=2.1, caps=("flat", "flat"))
scale_about(scarf, (0, 0, 1.37), 1.08)
hood(K, ROLE, lining=VOID, point=0.12, opening=48.0)

RESULT = finish(ob, bm)
bm.free()

# ------------------------------------------------------------------ dagger (grip at the origin, blade along +Z; both hands)
dg = new_skinned("SM_Assassin2_Dagger", COL, armature=None)
db = bmesh.new()
D = Kit(dg, db)
I3 = Matrix.Identity(3)
D.ellipsoid((0, 0, -0.085), (0.024, 0.024, 0.024), GOLD, {}, n=8, m=4)
D.loft([((0, 0, -0.07), 0.019, 0.019), ((0, 0, 0.055), 0.017, 0.017)], LEATHER_DARK, {}, n=8, caps=("flat", "flat"), frame=I3)
D.box((0, 0, 0.068), (0.11, 0.03, 0.024), GOLD, {}, bevel=0.008)
D.loft([((0, 0, 0.08), 0.03, 0.008), ((0, 0, 0.3), 0.022, 0.006), ((0, 0, 0.37), 0.003, 0.002)], STEEL_LIGHT, {}, n=8, e=1.25,
       caps=("flat", "flat"), frame=I3)
D.box((0, 0, 0.2), (0.008, 0.018, 0.2), STEEL_DARK, {})
RESULT["dagger"] = finish(dg, db, ao=False)
db.free()
