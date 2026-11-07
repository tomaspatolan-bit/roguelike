# Priest animations (A_Cleric_*), same skeleton as the knight. Run in Blender after build_cleric.py:
# exec(open(r"<repo>/art/cleric/anims_cleric.py", encoding="utf-8").read(), {})
# The priest carries a staff (Tom 30.10.2026) and attacks at range.
# Weapon grip (all new weapons): weapon origin in the fist (hand bone head + 0.08 m along Y),
# weapon axis = hand bone Z axis. With the forearm horizontal and forward the weapon stands vertical (priest's staff).
# The priest takes hit and death from the knight (A_Knight_Hit, A_Knight_Death).
import bpy

arm = bpy.data.objects["Armature"]
FPS = 24

# default hold: staff vertical in front of the body, left hand free
HOLD_R = {"upperarm_r": (0.3, 0.0, 0.55), "lowerarm_r": (1.3, 0.0, 0.0)}
REST_L = {"upperarm_l": (0.0, 0.0, -0.5), "lowerarm_l": (-0.4, 0.0, 0.0)}


def _curves(action):
    return [fc for l in action.layers for s in l.strips for cb in s.channelbags for fc in cb.fcurves]


def make_action(name, keys, cyclic=False):
    """keys: {frame: {bone: (rx, ry, rz)} or {"bone.loc": (x, y, z)}}. Channels missing in a frame = 0."""
    old = bpy.data.actions.get(name)
    if old is not None:
        bpy.data.actions.remove(old)
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    arm.animation_data_create()
    arm.animation_data.action = act
    chans = set()
    for pose in keys.values():
        chans |= set(pose.keys())
    for f in sorted(keys):
        pose = keys[f]
        for ch in chans:
            if ch.endswith(".loc"):
                pb = arm.pose.bones[ch[:-4]]
                pb.location = pose.get(ch, (0.0, 0.0, 0.0))
                pb.keyframe_insert("location", frame=f)
            else:
                pb = arm.pose.bones[ch]
                pb.rotation_mode = "XYZ"
                pb.rotation_euler = pose.get(ch, (0.0, 0.0, 0.0))
                pb.keyframe_insert("rotation_euler", frame=f)
    for fc in _curves(act):
        for kp in fc.keyframe_points:
            kp.interpolation = "BEZIER"
        if cyclic:
            fc.modifiers.new("CYCLES")
    arm.animation_data.action = None
    return act


def merged(*poses):
    out = {}
    for p in poses:
        out.update(p)
    return out


def copy_with_override(src, name, override):
    """Copy of an existing action; bone channels from override are replaced with a constant pose."""
    a = bpy.data.actions[src]
    keys = {}
    frames = sorted({int(kp.co[0]) for fc in _curves(a) for kp in fc.keyframe_points})
    for f in frames:
        pose = {}
        for fc in _curves(a):
            bone = fc.data_path.split('"')[1]
            prop = fc.data_path.split(".")[-1]
            ch = bone + (".loc" if prop == "location" else "")
            v = list(pose.get(ch, (0.0, 0.0, 0.0)))
            v[fc.array_index] = fc.evaluate(f)
            pose[ch] = tuple(v)
        pose.update(override(f) if callable(override) else override)
        keys[f] = pose
    return make_action(name, keys)


# --- idle: staff vertical, slow breathing (like the knight)
idle = {}
for f, k in ((1, 0.0), (31, 1.0), (61, 0.0)):
    idle[f] = merged(HOLD_R, REST_L, {
        "spine_02": (0.03 * k, 0, 0), "spine_03": (0.03 * k, 0, 0), "head": (-0.03 * k, 0, 0),
        "upperarm_l": (0, 0, -0.5 + 0.03 * k), "lowerarm_r": (1.3 - 0.04 * k, 0, 0),
        "cape_01": (-0.03 * k, 0, 0), "cape_02": (-0.05 * k, 0, 0), "pelvis.loc": (0, -0.01 * k, 0)})
make_action("A_Cleric_Idle", idle)

# --- walk: legs and torso from the knight, staff calmly vertical (only slight motion), left hand swings
copy_with_override("A_Knight_Walk", "A_Cleric_Walk", lambda f: {
    "upperarm_r": (0.3 + 0.06 * (1 if f in (1, 25) else -1 if f == 13 else 0), 0, 0.55),
    "lowerarm_r": (1.3, 0, 0)})

# --- ranged attack (staff): pull in, thrust the staff towards the target, the light flies out at frame 7 (the simulation fires at once, the animation is looks)
make_action("A_Cleric_Attack", {
    1: merged(HOLD_R, REST_L),
    4: merged(REST_L, {"upperarm_r": (0.45, 0.0, 0.65), "lowerarm_r": (1.85, 0, 0),
                       "spine_02": (-0.06, 0, -0.18), "head": (-0.05, 0, 0)}),
    7: merged(REST_L, {"upperarm_r": (1.35, 0.0, 0.4), "lowerarm_r": (0.55, 0, 0),
                       "upperarm_l": (0.3, 0, -0.45), "spine_02": (0.14, 0, 0.12), "thigh_l": (-0.25, 0, 0), "calf_l": (-0.15, 0, 0)}),
    10: merged(REST_L, {"upperarm_r": (1.2, 0.0, 0.45), "lowerarm_r": (0.7, 0, 0),
                        "spine_02": (0.1, 0, 0.08), "thigh_l": (-0.2, 0, 0), "calf_l": (-0.12, 0, 0)}),
    16: merged(HOLD_R, REST_L),
})

# --- Blessing: left palm raised over the squad, staff at the chest, head up
BLESS = {"upperarm_l": (-2.1, 0, -0.25), "lowerarm_l": (-0.35, 0, 0),
         "upperarm_r": (0.15, 0, 0.35), "lowerarm_r": (1.3, 0, 0), "head": (-0.25, 0, 0), "spine_02": (-0.12, 0, 0)}
make_action("A_Cleric_Bless", {
    1: merged(HOLD_R, REST_L),
    7: BLESS,
    13: merged(BLESS, {"upperarm_l": (-2.35, 0, -0.2), "head": (-0.3, 0, 0)}),
    19: BLESS,
    26: merged(HOLD_R, REST_L),
})

RESULT = {a.name: list(a.frame_range) for a in bpy.data.actions if a.name.startswith("A_Cleric")}
