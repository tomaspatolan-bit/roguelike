# Cavalier: the order's heavy knight on a horse, built from the game knight SK_Knight (same skeleton, palette, style).
# Run in Blender (Knight.blend) after build_horse.py:
# exec(open(r"<repo>/art/cavalier/build_cavalier.py", encoding="utf-8").read(), {"KIT": r"<repo>/art/tools/hero_kit.py"})
# Result: SK_Cavalier (collection CAVALIER_game), lance SM_Cavalier_Lance (right hand).
# Silhouette: heavier pauldrons, plume and cloak stay, a shield with the order's lozenge on the left forearm,
# sheathed sword at the hip. The shield is built in the riding pose (forearm forward) and converted to the skeleton's rest pose.
import math
import bpy
import bmesh
from mathutils import Vector, Matrix, Euler

exec(open(KIT, encoding="utf-8").read(), globals())

# arm pose in the saddle (same as in anims_cavalier.py)
RIDE_ARMS = {"upperarm_r": (0.3, 0.0, 0.55), "lowerarm_r": (1.3, 0.0, 0.0),
             "upperarm_l": (0.3, 0.0, -0.55), "lowerarm_l": (1.3, 0.0, 0.0)}

ob = new_object_from("SK_Knight", "SK_Cavalier", "CAVALIER_game")
bm = bmesh.new()
bm.from_mesh(ob.data)
B = Builder(ob, bm)
gi = {g.name: g.index for g in ob.vertex_groups}
name_of = {v: k for k, v in gi.items()}

for p in islands(bm):
    bone = name_of.get(p["bone"], "")
    c = p["center"]
    if bone in ("upperarm_l", "upperarm_r") and p["n"] == 74:
        for v in p["verts"]:
            v.co = c + (v.co - c) * 1.12                          # heavier pauldrons
    elif bone == "spine_02" and p["cell"] == ROLE_DARK and c.y < -0.19:
        B.set_cell(p["verts"], NAVY_DARK)                        # chest emblem: navy field of the order

# --- shield: built in the riding pose (world coordinates), then converted to the forearm rest pose
arm = bpy.data.objects["Armature"]
for pb in arm.pose.bones:
    pb.rotation_mode = "XYZ"
    pb.rotation_euler = (0, 0, 0)
    pb.location = (0, 0, 0)
for k, v in RIDE_ARMS.items():
    arm.pose.bones[k].rotation_euler = v
bpy.context.view_layer.update()
pb = arm.pose.bones["lowerarm_l"]
W = arm.matrix_world
D = (W @ pb.matrix) @ (W @ arm.data.bones["lowerarm_l"].matrix_local).inverted()
elbow = W @ pb.head
wrist = W @ pb.tail
fdir = (wrist - elbow).normalized()
n = Vector((1, 0, 0))                     # the shield faces out to the left
up = Vector((0, 0, 1))
side = up.cross(n).normalized()           # forward/back in the shield plane
C = elbow + fdir * 0.14 + n * 0.11 + up * 0.02
OUT = [(-0.21, 0.24), (0.21, 0.24), (0.2, 0.02), (0.12, -0.17), (0.0, -0.3), (-0.12, -0.17), (-0.2, 0.02)]
W_SH = {"lowerarm_l": 1.0}


def shield_part(scale, off, cell):
    pts = [C + n * off + side * (a * scale) + up * (b * scale) for a, b in OUT]
    vs = B.prism(pts, 0.035, n, cell, W_SH)
    return vs


def lozenge(size, off, cell):
    pts = [C + n * off + up * (0.03 + size), C + n * off + side * size + up * 0.03,
           C + n * off + up * (0.03 - size), C + n * off - side * size + up * 0.03]
    return B.prism(pts, 0.012, n, cell, W_SH)


parts = []
parts += shield_part(1.06, -0.008, GOLD)        # gold edge
parts += shield_part(1.0, 0.004, ROLE)          # field in the cavalier's colour
parts += lozenge(0.13, 0.026, NAVY)
parts += lozenge(0.065, 0.033, GOLD)
Dinv = D.inverted()
for v in set(parts):
    v.co = Dinv @ v.co
for pb2 in arm.pose.bones:
    pb2.rotation_euler = (0, 0, 0)
bpy.context.view_layer.update()

bm.normal_update()
bm.to_mesh(ob.data)
bm.free()
ob.data.update()

# --- lance (right hand): grip at the origin, tip along +Z, steel point, conical hand guard, pennon
lance = new_weapon("SM_Cavalier_Lance", "CAVALIER_game")
wl = bmesh.new()
WL = Builder(lance, wl)
W0 = {}
WL.cylinder((0, 0, -0.9), (0, 0, -0.85), 0.04, STEEL, W0, segs=8)
WL.cylinder((0, 0, -0.85), (0, 0, 2.1), 0.036, LEATHER, W0, r1=0.022, segs=8)
WL.cylinder((0, 0, -0.09), (0, 0, 0.09), 0.04, NAVY_DARK, W0, segs=8)
WL.cylinder((0, 0, 0.12), (0, 0, 0.34), 0.045, STEEL, W0, r1=0.14, segs=12)      # hand guard
WL.cylinder((0, 0, 0.34), (0, 0, 0.36), 0.142, GOLD, W0, segs=12)
WL.cylinder((0, 0, 2.08), (0, 0, 2.12), 0.03, GOLD, W0, segs=8)
WL.cylinder((0, 0, 2.12), (0, 0, 2.45), 0.03, STEEL, W0, r1=0.003, segs=8)
WL.prism([(0, 0.0, 2.04), (0, 0.42, 1.99), (0, 0.27, 1.92), (0, 0.42, 1.85), (0, 0.0, 1.8)], 0.008, (1, 0, 0), ROLE, W0)
WL.prism([(0, 0.0, 2.04), (0, 0.07, 2.035), (0, 0.07, 1.805), (0, 0.0, 1.8)], 0.012, (1, 0, 0), NAVY, W0)
wl.normal_update()
wl.to_mesh(lance.data)
wl.free()

RESULT = {"tris": sum(len(p.vertices) - 2 for p in ob.data.polygons),
          "lance_tris": sum(len(p.vertices) - 2 for p in lance.data.polygons),
          "unweighted": sum(1 for v in ob.data.vertices if not v.groups)}
