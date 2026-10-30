# Animace kněze (A_Cleric_*), stejná kostra jako rytíř. Spouští se v Blenderu po build_cleric.py:
# exec(open(r"<repo>/art/cleric/anims_cleric.py", encoding="utf-8").read(), {})
# Úchop zbraně (všechny nové zbraně): počátek zbraně v pěsti (hlava kosti ruky + 0,08 m po ose Y),
# osa zbraně = osa Z kosti ruky. S předloktím vodorovně dopředu tak palcát stojí svisle jako žezlo.
# Zásah a smrt bere kněz z rytíře (A_Knight_Hit, A_Knight_Death).
import bpy

arm = bpy.data.objects["Armature"]
FPS = 24

# výchozí držení: palcát svisle před tělem, levá ruka volně
HOLD_R = {"upperarm_r": (0.3, 0.0, 0.55), "lowerarm_r": (1.3, 0.0, 0.0)}
REST_L = {"upperarm_l": (0.0, 0.0, -0.5), "lowerarm_l": (-0.4, 0.0, 0.0)}


def _curves(action):
    return [fc for l in action.layers for s in l.strips for cb in s.channelbags for fc in cb.fcurves]


def make_action(name, keys, cyclic=False):
    """keys: {snímek: {kost: (rx, ry, rz)} nebo {"kost.loc": (x, y, z)}}. Kanály chybějící ve snímku = 0."""
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
    """Kopie existující akce, kanály kostí z override se nahradí stálou pózou."""
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


# --- klid: palcát svisle, pomalé dýchání (jako rytíř)
idle = {}
for f, k in ((1, 0.0), (31, 1.0), (61, 0.0)):
    idle[f] = merged(HOLD_R, REST_L, {
        "spine_02": (0.03 * k, 0, 0), "spine_03": (0.03 * k, 0, 0), "head": (-0.03 * k, 0, 0),
        "upperarm_l": (0, 0, -0.5 + 0.03 * k), "lowerarm_r": (1.3 - 0.04 * k, 0, 0),
        "cape_01": (-0.03 * k, 0, 0), "cape_02": (-0.05 * k, 0, 0), "pelvis.loc": (0, -0.01 * k, 0)})
make_action("A_Cleric_Idle", idle)

# --- chůze: nohy a trup z rytíře, palcát klidně svisle (jen mírný pohyb), levá ruka se kývá
copy_with_override("A_Knight_Walk", "A_Cleric_Walk", lambda f: {
    "upperarm_r": (0.3 + 0.06 * (1 if f in (1, 25) else -1 if f == 13 else 0), 0, 0.55),
    "lowerarm_r": (1.3, 0, 0)})

# --- útok: šikmý úder palcátem (nápřah přes pravé rameno, zásah 9. snímek, dokončení přes tělo)
make_action("A_Cleric_Attack", {
    1: merged(HOLD_R, REST_L),
    6: merged(REST_L, {"upperarm_r": (1.2, 0.0, -0.75), "lowerarm_r": (1.7, 0, 0),
                       "spine_02": (-0.12, 0, -0.35), "spine_03": (0, 0, -0.15)}),
    9: merged(REST_L, {"upperarm_r": (0.9, 0.0, 0.75), "lowerarm_r": (0.35, 0, 0),
                       "spine_02": (0.3, 0, 0.35), "spine_03": (0, 0, 0.1),
                       "thigh_l": (-0.4, 0, 0), "calf_l": (-0.3, 0, 0)}),
    12: merged(REST_L, {"upperarm_r": (0.45, 0.0, 0.95), "lowerarm_r": (0.45, 0, 0),
                        "spine_02": (0.25, 0, 0.3), "thigh_l": (-0.4, 0, 0), "calf_l": (-0.3, 0, 0)}),
    18: merged(HOLD_R, REST_L),
})

# --- Požehnání: levá dlaň vzhůru nad oddíl, palcát k hrudi, hlava vzhůru
BLESS = {"upperarm_l": (-2.1, 0, -0.25), "lowerarm_l": (-0.35, 0, 0),
         "upperarm_r": (0.1, 0, 0.75), "lowerarm_r": (1.35, 0, 0), "head": (-0.25, 0, 0), "spine_02": (-0.12, 0, 0)}
make_action("A_Cleric_Bless", {
    1: merged(HOLD_R, REST_L),
    7: BLESS,
    13: merged(BLESS, {"upperarm_l": (-2.35, 0, -0.2), "head": (-0.3, 0, 0)}),
    19: BLESS,
    26: merged(HOLD_R, REST_L),
})

RESULT = {a.name: list(a.frame_range) for a in bpy.data.actions if a.name.startswith("A_Cleric")}
