# Brigand: the common enemy, built from the game knight SK_Knight (same skeleton, palette, animations).
# Run in Blender (Knight.blend): exec(open(r"<repo>/art/brigand/build_brigand.py", encoding="utf-8").read(), {"KIT": r"<repo>/art/tools/hero_kit.py", "OUT": r"<repo>/art/brigand"})
# Result: SK_Brigand (collection BRIGAND_game), weapons SM_Brigand_Axe and SM_Brigand_Spear; with OUT set it also exports the GLBs.
# Silhouette (reads as "not a knight" at a glance): no plate, no cloak, no great helm. Open face with a beard under a cloth hood
# with a short shoulder cape, an iron kettle hat with a wide brim, quilted gambeson, leather bracers and boots, crossbelt and pouch.
# Colours come from palette row 6 (brigands: dull iron, brass, rust cloth, undyed wool) or row 7 (commanders: black and blood red).
# The skin is palette column 13 (same in every row).
import os
import bpy
import bmesh
from mathutils import Vector, Euler

exec(open(KIT, encoding="utf-8").read(), globals())
SKIN = 13
WOOD = 11

ob = new_object_from("SK_Knight", "SK_Brigand", "BRIGAND_game")
bm = bmesh.new()
bm.from_mesh(ob.data)
B = Builder(ob, bm)
gi = {g.name: g.index for g in ob.vertex_groups}
name_of = {v: k for k, v in gi.items()}

to_delete = []
for p in islands(bm):
    bone = name_of.get(p["bone"], "")
    c, s, cell, n = p["center"], p["size"], p["cell"], p["n"]
    vs = p["verts"]
    if bone == "weapon_scabbard" or bone.startswith("cape") or bone == "head":
        to_delete += vs                                           # sword, cloak and the whole great helm go
    elif bone == "spine_02" and (cell in (GOLD, NAVY) or (n == 8 and c.y < -0.15) or (n <= 14 and c.y < -0.19)):
        to_delete += vs                                           # tabard emblem and chest ridge
    elif bone in ("upperarm_l", "upperarm_r"):
        if n == 74 and s.x > 0.2:
            to_delete += vs                                       # pauldron plates
        elif n == 74:
            B.set_cell(vs, NAVY)                                  # quilted sleeve
            for v in vs:
                v.co = c + (v.co - c) * 0.8 + Vector((-0.03 if c.x > 0 else 0.03, 0, -0.01))
        elif n == 22:
            to_delete += vs                                       # gold roundel
        else:
            B.set_cell(vs, LEATHER)
    elif bone in ("lowerarm_l", "lowerarm_r"):
        if n == 62:
            to_delete += vs                                       # elbow cop
        elif abs(c.x) > 0.7:
            B.set_cell(vs, LEATHER)                               # bracer
        else:
            B.set_cell(vs, NAVY)
    elif bone in ("hand_l", "hand_r"):
        B.set_cell(vs, LEATHER if cell == STEEL else NAVY_DARK)   # gloves
    elif bone == "spine_02":
        B.set_cell(vs, NAVY)                                      # gambeson
    elif bone == "spine_03":
        B.set_cell(vs, NAVY if cell == STEEL else LEATHER)
    elif bone == "spine_01":
        B.set_cell(vs, NAVY_DARK)
    elif bone == "pelvis":
        if n == 126:
            B.set_cell(vs, ROLE_DARK)                             # tunic skirt
            for v in vs:
                v.co.x *= 0.95
                if v.co.z < 0.66:
                    v.co.z += 0.04
        elif cell == STEEL:
            B.set_cell(vs, NAVY_DARK)
        elif cell == STEEL_DARK:
            B.set_cell(vs, LEATHER)
    elif bone in ("thigh_l", "thigh_r"):
        B.set_cell(vs, NAVY_DARK)                                 # trousers
    elif bone in ("calf_l", "calf_r"):
        if n == 8:
            to_delete += vs                                       # greave ridge
        elif n == 62:
            B.set_cell(vs, NAVY_DARK)
        else:
            B.set_cell(vs, LEATHER)                               # boots
    elif bone in ("foot_l", "foot_r", "ball_l", "ball_r"):
        if cell == STEEL:
            B.set_cell(vs, LEATHER)
B.delete(to_delete)

W_HEAD = {"head": 1.0}
# --- head: neck, face with a beard, cloth hood with a short shoulder cape
B.cylinder((0, 0.0, 1.34), (0, 0.0, 1.44), 0.08, SKIN, W_HEAD, segs=8)
B.cylinder((0, 0.0, 1.40), (0, 0.0, 1.64), 0.155, ROLE, W_HEAD, r1=0.15, segs=12)           # hood (its top hides under the hat)
B.box((0, -0.135, 1.535), (0.17, 0.06, 0.17), SKIN, W_HEAD)                                 # face in the hood opening
B.box((0, -0.163, 1.565), (0.13, 0.012, 0.03), SKIN, W_HEAD)                                # brow
for x in (-0.038, 0.038):
    B.box((x, -0.168, 1.545), (0.028, 0.01, 0.018), VOID, W_HEAD)                           # eyes
B.box((0, -0.168, 1.505), (0.03, 0.02, 0.04), SKIN, W_HEAD)                                 # nose
B.box((0, -0.16, 1.465), (0.16, 0.05, 0.07), LEATHER, W_HEAD, taper=(1.0, 1.0))             # beard
B.box((0, -0.17, 1.43), (0.1, 0.04, 0.05), LEATHER, W_HEAD, taper=(1.4, 1.0))
W_SH = {"spine_03": 1.0}
B.cylinder((0, 0.01, 1.43), (0, 0.01, 1.24), 0.17, ROLE, W_SH, r1=0.3, segs=12)            # hood's shoulder cape
B.cylinder((0, 0.01, 1.25), (0, 0.01, 1.22), 0.302, ROLE_DARK, W_SH, r1=0.31, segs=12)
# --- iron kettle hat: dome and a wide brim (the brigand's mark from above)
B.cylinder((0, 0.0, 1.63), (0, 0.0, 1.78), 0.168, STEEL, W_HEAD, r1=0.07, segs=12)
B.cylinder((0, 0.0, 1.61), (0, 0.0, 1.635), 0.29, STEEL_DARK, W_HEAD, r1=0.27, segs=14)
B.cylinder((0, 0.0, 1.635), (0, 0.0, 1.655), 0.172, LEATHER, W_HEAD, segs=12)              # hat band
# --- quilting stripes on the gambeson front, crossbelt, belt pouch
for z in (1.05, 1.15, 1.25):
    B.box((0, -0.176, z), (0.36, 0.012, 0.012), NAVY_DARK, {"spine_02": 1.0})
B.box((0.02, -0.19, 1.14), (0.07, 0.025, 0.62), LEATHER, {"spine_02": 1.0}, rot=Euler((0, -0.62, 0)))
B.box((0.02, 0.19, 1.14), (0.07, 0.025, 0.62), LEATHER, {"spine_02": 1.0}, rot=Euler((0, 0.62, 0)))
B.box((-0.2, -0.16, 1.32), (0.05, 0.03, 0.04), GOLD, {"spine_02": 1.0})                    # buckle on the shoulder
B.box((0.22, -0.12, 0.88), (0.11, 0.07, 0.12), LEATHER, {"pelvis": 0.8, "thigh_l": 0.2})    # pouch
B.box((0.22, -0.158, 0.92), (0.11, 0.012, 0.05), NAVY_DARK, {"pelvis": 0.8, "thigh_l": 0.2})

bm.normal_update()
bm.to_mesh(ob.data)
bm.free()
ob.data.update()


def build_weapon(name, parts):
    w = new_weapon(name, "BRIGAND_game")
    wb = bmesh.new()
    WB = Builder(w, wb)
    parts(WB)
    wb.normal_update()
    wb.to_mesh(w.data)
    wb.free()
    return w


def axe(W):
    W.cylinder((0, 0, -0.16), (0, 0, 0.62), 0.019, WOOD, {}, segs=8)                       # haft
    W.cylinder((0, 0, -0.18), (0, 0, -0.16), 0.024, STEEL_DARK, {}, segs=8)
    W.box((0, 0, 0.0), (0.045, 0.045, 0.16), LEATHER, {})                                    # grip wrap
    W.box((0, 0, 0.56), (0.05, 0.05, 0.09), STEEL_DARK, {})                                  # eye
    W.prism([(0.02, 0, 0.6), (0.2, 0, 0.7), (0.23, 0, 0.6), (0.2, 0, 0.44), (0.02, 0, 0.52)], 0.018, (0, 1, 0), STEEL, {})  # bearded blade
    W.box((-0.05, 0, 0.56), (0.06, 0.03, 0.04), STEEL_DARK, {})                              # poll


def spear(W):
    W.cylinder((0, 0, -0.9), (0, 0, 1.5), 0.02, WOOD, {}, segs=8)
    W.cylinder((0, 0, 1.48), (0, 0, 1.56), 0.026, STEEL_DARK, {}, segs=8)                    # socket
    W.box((0, 0, 1.68), (0.06, 0.016, 0.24), STEEL, {}, taper=(0.08, 0.6))                   # leaf head
    W.box((0, 0, 1.47), (0.05, 0.05, 0.03), LEATHER, {})                                     # binding
    W.box((0, 0, 1.42), (0.012, 0.004, 0.12), ROLE, {})                                      # rag pennon
    W.box((0, 0.0, -0.92), (0.03, 0.03, 0.04), STEEL_DARK, {})                               # butt


axe_ob = build_weapon("SM_Brigand_Axe", axe)
spear_ob = build_weapon("SM_Brigand_Spear", spear)

RESULT = {"tris": sum(len(p.vertices) - 2 for p in ob.data.polygons),
          "axe_tris": sum(len(p.vertices) - 2 for p in axe_ob.data.polygons),
          "spear_tris": sum(len(p.vertices) - 2 for p in spear_ob.data.polygons),
          "unweighted": sum(1 for v in ob.data.vertices if not v.groups)}


# --- export (graphics rules 8, 11, 16: no materials, all actions, weapons alone)
def _select_only(objs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.hide_set(False)
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]


if globals().get("OUT"):
    win = bpy.context.window
    win.scene = bpy.data.scenes["Scene"]
    arm = bpy.data.objects["Armature"]
    _select_only([arm, ob])
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "SK_Brigand.glb"), use_selection=True,
                              export_materials="NONE", export_animation_mode="ACTIONS",
                              export_force_sampling=True, export_yup=True)
    for w in (axe_ob, spear_ob):
        _select_only([w])
        bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, w.name + ".glb"), use_selection=True,
                                  export_materials="NONE", export_animations=False, export_yup=True)
    RESULT["exported"] = sorted(f for f in os.listdir(OUT) if f.endswith(".glb"))
