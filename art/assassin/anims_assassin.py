# Animace asasína (A_Assassin_*), stejná kostra jako rytíř. Spouští se v Blenderu po build_assassin.py:
# exec(open(r"<repo>/art/assassin/anims_assassin.py", encoding="utf-8").read(), {})
# Dýka v každé ruce (úchop jako ostatní zbraně, čepel = osa Z kosti ruky); hand_* rotace X natočí čepel dopředu
# (při Úderu ze stínu čepel nahoře míří vzhůru a dopředu, pak se sekne dolů hrotem napřed).
# Konvence (ověřeno 30.10.2026): thigh X kladná = stehno dopředu, calf X záporná = ohyb kolene,
# spine_02 X kladná = předklon, Y = otočení trupu (kladná = pravé rameno dopředu), pelvis.loc Y = výška pánve.
# Zásah a smrt bere asasín z rytíře (A_Knight_Hit, A_Knight_Death).
import bpy

arm = bpy.data.objects["Armature"]


def _curves(action):
    return [fc for l in action.layers for s in l.strips for cb in s.channelbags for fc in cb.fcurves]


def make_action(name, keys):
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
    arm.animation_data.action = None
    return act


def merged(*poses):
    out = {}
    for p in poses:
        out.update(p)
    return out


def copy_with_override(src, name, override):
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


def crouch(k):
    """Pokrčené nohy, k = 1 běžný postoj, víc = hlubší (pánev klesne, chodidla zůstanou na zemi)."""
    return {"thigh_l": (0.5 * k, 0, 0), "thigh_r": (0.5 * k, 0, 0), "calf_l": (-0.9 * k, 0, 0), "calf_r": (-0.9 * k, 0, 0),
            "foot_l": (0.4 * k, 0, 0), "foot_r": (0.4 * k, 0, 0), "pelvis.loc": (0, -0.073 * k * k, 0)}


READY = {"upperarm_r": (0.35, 0, 0.5), "lowerarm_r": (1.0, 0, 0), "upperarm_l": (0.35, 0, -0.5), "lowerarm_l": (1.0, 0, 0),
         "spine_02": (0.15, 0, 0), "head": (-0.12, 0, 0)}
BASE = merged(crouch(1.0), READY)

# --- klid: přikrčený, dýky nízko před tělem, dýchá a rozhlíží se
idle = {}
for f, k, look in ((1, 0.0, 0.0), (25, 1.0, 0.25), (49, 0.0, 0.0)):
    idle[f] = merged(BASE, {"spine_03": (0.03 * k, 0, 0), "head": (-0.12, look, 0), "lowerarm_r": (1.0 - 0.06 * k, 0, 0),
                            "lowerarm_l": (1.0 - 0.06 * k, 0, 0)})
make_action("A_Assassin_Idle", idle)

# --- chůze: nohy z rytíře, předklon, dýky nízko
copy_with_override("A_Knight_Walk", "A_Assassin_Walk", lambda f: merged(READY, {"spine_02": (0.2, 0, 0)}))

# --- útok: nápřah pravou, rychlé bodnutí v 6. snímku (dýka dopředu), návrat
COCK = {"upperarm_r": (0.1, 0, 0.45), "lowerarm_r": (1.9, 0, 0), "spine_02": (0.15, -0.3, 0), "hand_r": (-0.8, 0, 0)}
STAB = {"upperarm_r": (1.45, 0, 0.35), "lowerarm_r": (0.15, 0, 0), "spine_02": (0.25, 0.35, 0), "hand_r": (-1.4, 0, 0),
        "upperarm_l": (0.2, 0, -0.6), "thigh_r": (0.8, 0, 0), "calf_r": (-0.8, 0, 0)}
make_action("A_Assassin_Attack", {
    1: BASE,
    3: merged(BASE, COCK),
    6: merged(BASE, STAB),
    9: merged(BASE, STAB),
    16: BASE,
})

# --- Úder ze stínu: hluboký přikrčení, obě dýky nad hlavu, prudké bodnutí shora oběma, návrat
RAISE = merged(crouch(1.4), {"upperarm_r": (2.4, 0, 0.3), "lowerarm_r": (1.2, 0, 0), "upperarm_l": (2.4, 0, -0.3),
                             "lowerarm_l": (1.2, 0, 0), "hand_r": (-2.2, 0, 0), "hand_l": (-2.2, 0, 0),
                             "spine_02": (-0.1, 0, 0), "head": (-0.2, 0, 0)})
SLAM = merged(crouch(1.6), {"upperarm_r": (1.2, 0, 0.3), "lowerarm_r": (0.3, 0, 0), "upperarm_l": (1.2, 0, -0.3),
                            "lowerarm_l": (0.3, 0, 0), "hand_r": (-1.6, 0, 0), "hand_l": (-1.6, 0, 0),
                            "spine_02": (0.5, 0, 0), "head": (-0.35, 0, 0)})
make_action("A_Assassin_Strike", {
    1: BASE,
    4: RAISE,
    7: SLAM,
    11: SLAM,
    20: BASE,
})

RESULT = {a.name: list(a.frame_range) for a in bpy.data.actions if a.name.startswith("A_Assassin")}
