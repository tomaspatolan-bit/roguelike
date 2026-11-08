# Style pilot 2.0s (08.11.2026): the tank in the smooth look, built from the game knight SK_Knight (same skeleton,
# palette and animations; SK_Knight itself stays as it was, the other classes are built from it).
# Run in Blender (Knight.blend):
#   exec(open(r"<repo>/art/knight/smooth_knight.py", encoding="utf-8").read(),
#        {"KIT": r"<repo>/art/tools/hero_kit.py", "SMOOTH": r"<repo>/art/tools/smooth_kit.py", "OUT": r"<repo>/art/knight"})
# Result: SK_Knight_Smooth and SM_Knight_Sword (collection KNIGHT_smooth); with OUT set also the GLBs.
# What changes against SK_Knight:
#  - armour and metal have chamfered edges (12 mm chamfer on edges sharper than 50°) and weighted normals: edges catch the light,
#    big faces stay flat, the knight reads as a solid toy, not as sharp boxes;
#  - the tabard and the mail skirt follow the thighs (soft weights, they flare a little at the hem),
#    the cloak bows away from the back;
#  - head ×1.1 and fists ×1.15 (read better from the battle camera);
#  - a real sword (blade with a fuller, crossguard, wrapped grip, pommel) gripped in the fist instead of
#    the placeholder boxes that stuck out along the fingers.
import bpy
import bmesh
from mathutils import Vector

exec(open(KIT, encoding="utf-8").read(), globals())
exec(open(SMOOTH, encoding="utf-8").read(), globals())
COL = "KNIGHT_smooth"

ob = new_object_from("SK_Knight", "SK_Knight_Smooth", COL)
arm = bpy.data.objects["Armature"]
bm = bmesh.new()
bm.from_mesh(ob.data)
B = Builder(ob, bm)
name_of = {g.index: g.name for g in ob.vertex_groups}

round_verts = set()      # fists and boots: rounded much more than the rest
for p in islands(bm):
    bone = name_of.get(p["bone"], "")
    vs = p["verts"]
    if bone in ("hand_l", "hand_r", "foot_l", "foot_r", "ball_l", "ball_r"):
        round_verts.update(vs)
    if bone == "head":
        scale_part(vs, arm.data.bones["head"].head_local, 1.1)
    elif bone in ("hand_l", "hand_r"):
        scale_part(vs, arm.data.bones[bone].head_local, 1.15)
    elif bone == "pelvis" and p["cell"] == ROLE:
        side = 1.0 if p["center"].y > 0 else -1.0
        for v in vs:
            v.co.y -= side * 0.9 * v.co.x * v.co.x            # the tabard wraps around the body
            edge = smoothstep(0.13, 0.225, abs(v.co.x))
            v.co.z += 0.05 * edge * smoothstep(0.75, 0.58, v.co.z)   # rounded lower corners
        soften_cloth(B, vs, 0.9, 0.58, "pelvis", "thigh_l", "thigh_r", max_leg=0.65, flare=0.08)
    elif bone == "pelvis" and p["cell"] == CHAIN:
        soften_cloth(B, vs, 0.86, 0.68, "pelvis", "thigh_l", "thigh_r", max_leg=0.35, flare=0.04)
    elif bone.startswith("cape"):
        for v in vs:
            bow = 1.0 - min(1.0, (v.co.x / 0.36) ** 2)
            v.co.y += 0.05 * bow * smoothstep(1.3, 0.55, v.co.z)

n_round = bevel_hard(bm, {STEEL, STEEL_DARK, GOLD, LEATHER, CHAIN}, width=0.022, segments=2, angle_deg=20.0, only=round_verts)
n_hard = bevel_hard(bm, {STEEL, STEEL_DARK, GOLD, CHAIN}, width=0.012, segments=1, angle_deg=50.0)
n_soft = bevel_hard(bm, {ROLE, ROLE_DARK, NAVY, NAVY_DARK, LEATHER, CRIMSON}, width=0.006, segments=1, angle_deg=60.0)
bm.normal_update()
bm.to_mesh(ob.data)
bm.free()
ob.data.update()
weighted_normals(ob)

# --- the sword: grip at the origin, blade along +Z (like the other weapons; the game puts it across the fist)
sw = new_weapon("SM_Knight_Sword", COL)
wb = bmesh.new()
W = Builder(sw, wb)
W.cylinder((0, 0, -0.1), (0, 0, 0.1), 0.019, LEATHER, {}, segs=8)                    # wrapped grip
for z in (-0.06, 0.0, 0.06):
    W.cylinder((0, 0, z - 0.006), (0, 0, z + 0.006), 0.022, NAVY_DARK, {}, segs=8)    # wrap bands
W.cylinder((0, 0, -0.16), (0, 0, -0.1), 0.034, GOLD, {}, r1=0.026, segs=8)            # pommel
W.box((0, 0, 0.125), (0.24, 0.04, 0.035), GOLD, {}, taper=(0.9, 1.0))                 # crossguard
W.box((0, 0, 0.15), (0.06, 0.03, 0.03), STEEL_DARK, {})                               # ricasso block
W.box((0, 0, 0.55), (0.055, 0.014, 0.78), STEEL, {}, taper=(0.35, 0.5))               # blade (tapers to the point)
W.box((0, 0, 0.47), (0.014, 0.018, 0.55), STEEL_DARK, {}, taper=(0.5, 1.0))           # fuller
bevel_hard(wb, {STEEL, STEEL_DARK, GOLD}, width=0.004, segments=1, angle_deg=30.0)
wb.normal_update()
wb.to_mesh(sw.data)
wb.free()
weighted_normals(sw)

RESULT = {"tris": sum(len(p.vertices) - 2 for p in ob.data.polygons), "hard_edges": n_hard, "soft_edges": n_soft,
          "sword_tris": sum(len(p.vertices) - 2 for p in sw.data.polygons),
          "unweighted": sum(1 for v in ob.data.vertices if not v.groups)}

if globals().get("OUT"):
    import os
    bpy.context.window.scene = bpy.data.scenes["Scene"]
    export_glb([arm, ob], os.path.join(OUT, "SK_Knight_Smooth.glb"))
    export_glb([sw], os.path.join(OUT, "SM_Knight_Sword.glb"), animations=False)
    RESULT["exported"] = True
