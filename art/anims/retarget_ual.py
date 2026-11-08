# Library animations test (style pilot 2.0s, 08.11.2026): Quaternius Universal Animation Library 1 and 2 (CC0,
# free Standard version) retargeted onto our knight skeleton (UE5 bone names, A-pose rest).
# Run in Blender with Knight.blend open:
#   exec(open(r"<repo>/art/anims/retarget_ual.py", encoding="utf-8").read(),
#        {"UAL1": r"...\UAL1_Standard.glb", "UAL2": r"...\UAL2_Standard.glb"})
# Creates actions A_Tank_UAL_* on the Armature skeleton and removes everything it imported.
# Method: every mapped bone copies the source bone's world rotation with a fixed offset. The offset makes the bones
# point the same way in a matching pose (the source rest is a T-pose, ours an A-pose, so the source bone is first
# turned to our rest direction by the smallest rotation). Our parents are computed by us, so no depsgraph per bone.
# The pelvis also moves (height difference scaled by pelvis height). Bones the library does not have (cloak,
# scabbard) stay in rest. Both skeletons face -Y.
import bpy
from mathutils import Matrix, Quaternion, Vector

CLIPS = {   # our action: (library action, loop)
    "A_Tank_UAL_Idle": ("Sword_Idle", True),
    "A_Tank_UAL_Idle_Relaxed": ("Idle_Loop", True),
    "A_Tank_UAL_Walk": ("Walk_Loop", True),
    "A_Tank_UAL_Attack": ("Sword_Regular_A", False),
    "A_Tank_UAL_Attack_B": ("Sword_Regular_B", False),
    "A_Tank_UAL_Ability": ("Sword_Block", False),
    "A_Tank_UAL_Hit": ("Hit_Chest", False),
    "A_Tank_UAL_Death": ("Death01", False),
}
NAME_MAP = {"Head": "head"}

tgt = bpy.data.objects["Armature"]
scene = bpy.context.scene
before_objs = set(bpy.data.objects)
before_acts = set(bpy.data.actions)
before_meshes = set(bpy.data.meshes)
win = bpy.context.window_manager.windows[0]
for path in (UAL1, UAL2):
    with bpy.context.temp_override(window=win, scene=win.scene, view_layer=win.view_layer):
        bpy.ops.import_scene.gltf(filepath=path)
imported = [o for o in bpy.data.objects if o not in before_objs]
src = [o for o in imported if o.type == "ARMATURE"][0]   # both libraries share the rig; actions work on either
lib_acts = {a.name.split(".")[0]: a for a in bpy.data.actions if a not in before_acts}


def rot3(m):
    return m.to_3x3().normalized()


# bone pairs, parents first (our skeleton order)
pairs = []
for b in tgt.data.bones:
    sname = next((s for s, t in NAME_MAP.items() if t == b.name), b.name)
    if sname in src.data.bones and b.name != "root":   # root stays (ours points up, theirs along the ground)
        pairs.append((sname, b.name))
Ws = rot3(src.matrix_world)
Wt = rot3(tgt.matrix_world)
offset = {}
for s, t in pairs:
    sb, tb = src.data.bones[s], tgt.data.bones[t]
    rs = Ws @ rot3(sb.matrix_local)
    rt = Wt @ rot3(tb.matrix_local)
    sdir = rs @ Vector((0, 1, 0))
    tdir = rt @ Vector((0, 1, 0))
    align = sdir.rotation_difference(tdir).to_matrix()
    offset[t] = (align @ rs).inverted() @ rt
k_height = tgt.data.bones["pelvis"].head_local.z / max(src.data.bones["pelvis"].head_local.z, 1e-4)
src_pelvis_rest = src.matrix_world @ src.data.bones["pelvis"].head_local

if tgt.animation_data is None:
    tgt.animation_data_create()
if src.animation_data is None:
    src.animation_data_create()
old_action = tgt.animation_data.action
for p in tgt.pose.bones:
    p.rotation_mode = "XYZ"
made = {}
for our_name, (lib_name, loop) in CLIPS.items():
    la = lib_acts.get(lib_name)
    if la is None:
        made[our_name] = "missing " + lib_name
        continue
    src.animation_data.action = la
    try:
        src.animation_data.action_slot = la.slots[0]
    except Exception:
        pass
    old = bpy.data.actions.get(our_name)
    if old is not None:
        bpy.data.actions.remove(old)
    act = bpy.data.actions.new(our_name)
    act.use_fake_user = True
    tgt.animation_data.action = act
    f0, f1 = int(round(la.frame_range[0])), int(round(la.frame_range[1]))
    last_eul = {}
    for f in range(f0, f1 + 1):
        scene.frame_set(f)
        world_rot = {}
        for s, t in pairs:
            spb = src.pose.bones[s]
            r_world = Ws @ rot3(spb.matrix)
            world_rot[t] = r_world @ offset[t]
        for s, t in pairs:
            tb = tgt.data.bones[t]
            pb = tgt.pose.bones[t]
            arm_rot = Wt.inverted() @ world_rot[t]
            if tb.parent is not None:
                parent_arm = Wt.inverted() @ world_rot[tb.parent.name] if tb.parent.name in world_rot else rot3(tb.parent.matrix_local)
                rest_rel = rot3(tb.parent.matrix_local).inverted() @ rot3(tb.matrix_local)
                basis = rest_rel.inverted() @ parent_arm.inverted() @ arm_rot
            else:
                basis = rot3(tb.matrix_local).inverted() @ arm_rot
            # Euler like our own actions (the bones stay in XYZ mode, otherwise the exporter samples our
            # rotation_euler actions as the rest pose); compatible with the previous frame so no flips
            prev = last_eul.get(t)
            eul = basis.to_euler("XYZ", prev) if prev is not None else basis.to_euler("XYZ")
            last_eul[t] = eul
            pb.rotation_euler = eul
            pb.keyframe_insert("rotation_euler", frame=f - f0, group=t)
            if t == "pelvis":
                hs = src.matrix_world @ src.pose.bones[s].head
                d = (hs - src_pelvis_rest) * k_height
                # pelvis location in its rest frame (its parent, root, is not animated by the library)
                pb.location = rot3(tb.matrix_local).inverted() @ (Wt.inverted() @ d)
                pb.keyframe_insert("location", frame=f - f0, group=t)
    made[our_name] = f1 - f0 + 1
tgt.animation_data.action = old_action
for p in tgt.pose.bones:
    p.rotation_mode = "XYZ"
    p.rotation_quaternion = Quaternion()
    p.rotation_euler = (0.0, 0.0, 0.0)
    p.location = Vector()

# clean up everything the import brought
for o in imported:
    bpy.data.objects.remove(o)
for a in list(bpy.data.actions):
    if a not in before_acts and not a.name.startswith("A_Tank_UAL"):
        bpy.data.actions.remove(a)
for m in list(bpy.data.meshes):
    if m not in before_meshes and m.users == 0:
        bpy.data.meshes.remove(m)
for arm in list(bpy.data.armatures):
    if arm.users == 0:
        bpy.data.armatures.remove(arm)
RESULT = {"clips": made, "pairs": len(pairs), "k_height": round(k_height, 3)}
