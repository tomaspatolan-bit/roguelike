# Cavalier, Sir Radek (visual prototype, 15.11.2026): the rider, built from scratch with art/tools/char_kit.py and
# art/chars/hero_body.py on the knight skeleton (the animations A_Cavalier_* stay; he rides the horse from build_horse2.py).
# Run in Blender with Knight.blend open:
#   exec(open(r"<repo>/art/cavalier/build_cavalier2.py", encoding="utf-8").read(),
#        {"KIT": r"<repo>/art/tools/char_kit.py", "BODY": r"<repo>/art/chars/hero_body.py", "PAL": r"<repo>/art/chars/T_Char_Palette_D.png"})
# Result: SK_Cavalier2 and SM_Cavalier2_Lance (right hand) in the collection CAVALIER2_game.
# Design (style guide): half plate, a warm ochre surcoat split for riding, ochre painted helmet and pauldrons, a crimson
# plume, a short cloak lying on the horse's rump, a shield in ochre on the left forearm (built in the riding pose like the
# old one), a lance with an ochre pennon. With the ochre caparison of the horse the rider and the horse read as one unit.
import math
import bmesh
import bpy
from mathutils import Matrix, Vector

exec(open(KIT, encoding="utf-8").read(), globals())
exec(open(BODY, encoding="utf-8").read(), globals())
preview_material(PAL, 4)
COL = "CAVALIER2_game"
RIDE_ARMS = {"upperarm_r": (0.3, 0.0, 0.55), "lowerarm_r": (1.3, 0.0, 0.0),
             "upperarm_l": (0.3, 0.0, -0.55), "lowerarm_l": (1.3, 0.0, 0.0)}

ob = new_skinned("SK_Cavalier2", COL)
bm = bmesh.new()
K = Kit(ob, bm)

# ------------------------------------------------------------------ legs in plate, arms
legs(K, MAIL, knee=STEEL_LIGHT, shin=STEEL, boot=STEEL_DARK, cuff=STEEL_LIGHT, thigh_plate=ROLE_PAINT)
arms(K, ROLE_DARK, forearm=STEEL, glove=STEEL_DARK, elbow=STEEL_LIGHT, cuff=STEEL_LIGHT)   # padded sleeves

# ------------------------------------------------------------------ surcoat: torso, split skirt (front and back panels only)


def hem(u, v):
    return GOLD if v > 0.92 else None


for sgn in (-1.0, 1.0):
    K.sheet(lambda u, v, sg=sgn: (-sg * u * (0.135 + 0.03 * v), sg * ((0.152 + 0.06 * v ** 0.6) - 0.02 * u * u), 0.95 - 0.4 * v),
            6, 7, 0.014, ROLE, skirt_weights(0.93, 0.6, 0.75), cell_in=ROLE_DARK, cell_fn=hem)
K.loft([((0, 0, 0.985), 0.186, 0.142), ((0, 0, 0.86), 0.2, 0.152), ((0, 0, 0.76), 0.21, 0.158)], MAIL,
       skirt_weights(0.92, 0.76, 0.55), n=14, e=2.4, caps=("flat", "flat"))
torso(K, ROLE)
belt(K, LEATHER, GOLD)
# navy lozenge of the order on the chest
K.box((0, -0.187, 1.175), (0.11, 0.016, 0.11), NAVY, {"spine_03": 1.0}, rot=Matrix.Rotation(math.radians(45.0), 3, "Y"), bevel=0.005)
K.box((0, -0.192, 1.175), (0.05, 0.016, 0.05), GOLD, {"spine_03": 1.0}, rot=Matrix.Rotation(math.radians(45.0), 3, "Y"), bevel=0.004)
K.loft([((0, 0, 1.285), 0.132, 0.122), ((0, 0, 1.375), 0.096, 0.102)], STEEL, {"spine_03": 0.5, "neck_01": 0.5}, n=12, e=2.2,
       caps=("flat", "flat"))
for s in (1.0, -1.0):
    shoulder_cap(K, s, ROLE_PAINT, size=(0.145, 0.15, 0.1), rim=GOLD)
cloak(K, ROLE_DARK, inner=ROLE, width=0.9, length=0.62, hem=GOLD)

# ------------------------------------------------------------------ helmet: painted bascinet with an open visor slit, plume
head = []
HW = {"head": 1.0}
head.append(K.loft([((0, -0.005, 1.37), 0.1, 0.11), ((0, -0.01, 1.45), 0.11, 0.125), ((0, -0.01, 1.53), 0.112, 0.128),
                    ((0, 0.0, 1.61), 0.098, 0.114), ((0, 0.02, 1.68), 0.05, 0.06)], ROLE_PAINT, HW, n=16, e=2.2,
                   caps=("flat", "round"), cap_k=0.6))
head.append(K.loft([((0, -0.01, 1.41), 0.12, 0.152), ((0, -0.03, 1.47), 0.118, 0.16), ((0, -0.02, 1.53), 0.114, 0.144)],
                   STEEL_LIGHT, HW, n=8, arc=(-150.0, -30.0), thick=0.014, e=2.3))
head.append(K.loft([((0, -0.01, 1.497), 0.1185, 0.1605), ((0, -0.01, 1.517), 0.117, 0.156)], VOID, HW, n=8, arc=(-140.0, -40.0),
                   thick=0.004, e=2.3))
head.append(K.loft([((0, -0.005, 1.385), 0.106, 0.117), ((0, -0.005, 1.403), 0.107, 0.119)], GOLD, HW, n=14, e=2.3,
                   caps=("flat", "flat")))
fp = frame_for((0, 0.55, 0.83))
head.append(K.loft([((0, 0.03, 1.69), 0.02, 0.02, fp), ((0, 0.07, 1.74), 0.035, 0.04, fp), ((0, 0.16, 1.77), 0.04, 0.05, fp),
                    ((0, 0.25, 1.73), 0.032, 0.04, fp), ((0, 0.3, 1.66), 0.012, 0.016, fp)], CRIMSON, HW, n=8, e=2.0, cap_k=0.6))
for part in head:
    scale_about(part, (0, 0, 1.37), 1.08)

# ------------------------------------------------------------------ shield: built in the riding pose, converted to the rest pose
arm = bpy.data.objects["Armature"]
for pb in arm.pose.bones:
    pb.rotation_mode = "XYZ"
    pb.rotation_euler = (0, 0, 0)
    pb.location = (0, 0, 0)
for k, v in RIDE_ARMS.items():
    arm.pose.bones[k].rotation_euler = v
bpy.context.view_layer.update()
pbl = arm.pose.bones["lowerarm_l"]
Wm = arm.matrix_world
Dm = (Wm @ pbl.matrix) @ (Wm @ arm.data.bones["lowerarm_l"].matrix_local).inverted()
elbow = Wm @ pbl.head
wrist = Wm @ pbl.tail
fdir = (wrist - elbow).normalized()
nrm = Vector((1, 0, 0))                    # the shield faces out to the left
up = Vector((0, 0, 1))
side = up.cross(nrm).normalized()
C = elbow + fdir * 0.14 + nrm * 0.12 + up * 0.02
SW, ST, SH = 0.25, 0.27, 0.6


def shield_hw(v):
    if v < 0.45:
        return SW
    return max(0.012, SW * math.sqrt(max(0.0, 1.0 - ((v - 0.45) / 0.55) ** 2.2)))


def shield(u, v):
    x = -u * shield_hw(v)
    return C + side * x + up * (ST - SH * v) + nrm * (-0.5 * x * x)


def shield_cells(u, v):
    if abs(u) > 0.88 or v < 0.06 or v > 0.95:
        return GOLD
    if abs(u) < 0.12 or abs(v - 0.32) < 0.05:
        return NAVY
    return None


before = set(bm.verts)
K.sheet(shield, 16, 14, 0.03, ROLE_PAINT, {"lowerarm_l": 1.0}, cell_in=WOOD, cell_fn=shield_cells)
Dinv = Dm.inverted()
for v in set(bm.verts) - before:
    v.co = Dinv @ v.co
for pb2 in arm.pose.bones:
    pb2.rotation_euler = (0, 0, 0)
bpy.context.view_layer.update()

RESULT = finish(ob, bm)
bm.free()

# ------------------------------------------------------------------ lance (grip at the origin, tip along +Z), ochre pennon
ln = new_skinned("SM_Cavalier2_Lance", COL, armature=None)
lb = bmesh.new()
LK = Kit(ln, lb)
I3 = Matrix.Identity(3)
LK.loft([((0, 0, -0.9), 0.034, 0.034), ((0, 0, 2.1), 0.022, 0.022)], WOOD, {}, n=8, caps=("round", "flat"), frame=I3)
LK.loft([((0, 0, -0.1), 0.04, 0.04), ((0, 0, 0.1), 0.04, 0.04)], LEATHER_DARK, {}, n=8, caps=("flat", "flat"), frame=I3)
LK.loft([((0, 0, 0.12), 0.046, 0.046), ((0, 0, 0.3), 0.13, 0.13), ((0, 0, 0.34), 0.14, 0.14)], STEEL, {}, n=12, caps=("flat", "flat"),
        frame=I3)
LK.loft([((0, 0, 0.34), 0.142, 0.142), ((0, 0, 0.365), 0.142, 0.142)], GOLD, {}, n=12, caps=("flat", "flat"), frame=I3)
LK.loft([((0, 0, 2.08), 0.03, 0.03), ((0, 0, 2.12), 0.03, 0.03)], GOLD, {}, n=8, caps=("flat", "flat"), frame=I3)
LK.loft([((0, 0, 2.12), 0.034, 0.02), ((0, 0, 2.46), 0.003, 0.002)], STEEL_LIGHT, {}, n=8, caps=("flat", "flat"), frame=I3)


def pennon(u, v):
    # u across the height of the cloth, v away from the pole; swallow-tailed end
    h = 0.12 * (1.0 - 0.35 * v)
    z = 1.92 + u * h
    if v > 0.75:
        z -= u * 0.12 * (v - 0.75) / 0.25 * (1 if abs(u) < 0.3 else 0)
    return (0.0, 0.02 + 0.45 * v, z + 0.03 * math.sin(v * 3.0))


LK.sheet(pennon, 4, 8, 0.008, ROLE, {}, cell_fn=lambda u, v: NAVY if v < 0.12 else None)
RESULT["lance"] = finish(ln, lb, ao=False)
lb.free()
