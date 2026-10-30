# Animace lučištníka (A_Archer_*), stejná kostra jako rytíř. Spouští se v Blenderu po build_archer.py:
# exec(open(r"<repo>/art/archer/anims_archer.py", encoding="utf-8").read(), {})
# Luk drží LEVÁ ruka (úchop jako u ostatních zbraní: počátek v pěsti, osa luku = osa Z kosti ruky).
# Pózy střelby jsou dohledané numericky (luk svisle, šíp míří dopředu, pravá ruka na tětivě u brady);
# tětivu kreslí hra (unit_view.gd): když je pravá ruka u roviny luku, vede tětiva přes ni.
# Pravá paže bez velkého natočení kolem osy (rot1): nárameník z několika plátů se při něm rozjede.
# Konvence (ověřeno 30.10.2026): upperarm_l i _r rot0+ = paže dopředu, lowerarm rot0+ = ohyb lokte,
# spine_02 rot1 = otočení trupu (záporné = levé rameno dopředu), rot2 = úklon do strany.
# Zásah a smrt bere lučištník z rytíře (A_Knight_Hit, A_Knight_Death).
import bpy

arm = bpy.data.objects["Armature"]


def _curves(action):
    return [fc for l in action.layers for s in l.strips for cb in s.channelbags for fc in cb.fcurves]


def make_action(name, keys):
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


# --- pózy
HOLD_L = {"upperarm_l": (-0.21, -0.29, -0.78), "lowerarm_l": (1.29, 0.0, 0.0)}    # luk šikmo u levého boku
REST_R = {"upperarm_r": (0.0, 0.0, 0.5), "lowerarm_r": (0.3, 0.0, 0.0)}
HOLD = merged(HOLD_L, REST_R)
TWIST = {"spine_02": (0.0, -0.5, 0.0), "spine_03": (0.0, -0.3, 0.0), "head": (0.0, 0.7, 0.0)}   # levé rameno k cíli
AIM_L = {"upperarm_l": (1.69, -0.79, -0.79), "lowerarm_l": (0.0, 0.29, 0.0)}        # luk svisle, šíp vodorovně
AIM_L_HIGH = {"upperarm_l": (2.16, -0.88, -0.63), "lowerarm_l": (0.0, 0.0, 0.0)}    # salva: šíp 40° vzhůru
DRAW_R = {"upperarm_r": (2.63, 0.0, -0.79), "lowerarm_r": (1.06, 0.0, 0.0)}          # ruka na tětivě u brady
DRAW_R_HIGH = {"upperarm_r": (2.68, 0.6, -0.59), "lowerarm_r": (1.18, -0.3, 0.0)}
REACH_R = {"upperarm_r": (2.0, 0.0, -0.9), "lowerarm_r": (0.7, 0.0, 0.0)}           # ruka jde k tětivě
LOOSE_R = {"upperarm_r": (2.45, 0.0, -1.2), "lowerarm_r": (0.5, 0.0, 0.0)}         # po vypuštění ruka odletí dozadu
LEGS = {"thigh_l": (-0.12, 0.0, 0.0), "thigh_r": (0.1, 0.0, 0.0)}                  # rozkročení do střelby

# --- klid: luk u boku, pomalé dýchání
idle = {}
for f, k in ((1, 0.0), (31, 1.0), (61, 0.0)):
    idle[f] = merged(HOLD, {
        "spine_02": (0.03 * k, 0, 0), "spine_03": (0.03 * k, 0, 0), "head": (-0.03 * k, 0, 0),
        "upperarm_r": (0.0, 0.0, 0.5 - 0.03 * k), "lowerarm_l": (1.29 - 0.05 * k, 0, 0), "pelvis.loc": (0, -0.01 * k, 0)})
make_action("A_Archer_Idle", idle)

# --- chůze: nohy a trup z rytíře, luk klidně u boku, pravá ruka se kývá
SW = {1: 1.0, 7: 0.0, 13: -1.0, 19: 0.0, 25: 1.0}
copy_with_override("A_Knight_Walk", "A_Archer_Walk", lambda f: merged(HOLD_L, {
    "upperarm_r": (0.25 * SW.get(f, 0.0), 0.0, 0.5), "lowerarm_r": (0.3 + 0.1 * abs(SW.get(f, 0.0)), 0.0, 0.0)}))

# --- výstřel: zvednutí luku, natažení, vypuštění v 9. snímku (simulace pouští šíp hned, animace je vzhled), návrat
make_action("A_Archer_Shoot", {
    1: HOLD,
    4: merged(TWIST, AIM_L, REACH_R, LEGS),
    8: merged(TWIST, AIM_L, DRAW_R, LEGS),
    9: merged(TWIST, AIM_L, LOOSE_R, LEGS),
    14: merged(TWIST, AIM_L, LOOSE_R, LEGS, {"upperarm_l": (1.6, -0.79, -0.79)}),
    24: HOLD,
})

# --- Salva: luk vysoko, dva rychlé výstřely do oblouku
make_action("A_Archer_Salvo", {
    1: HOLD,
    5: merged(TWIST, AIM_L_HIGH, REACH_R, LEGS),
    10: merged(TWIST, AIM_L_HIGH, DRAW_R_HIGH, LEGS),
    11: merged(TWIST, AIM_L_HIGH, LOOSE_R, LEGS),
    15: merged(TWIST, AIM_L_HIGH, REACH_R, LEGS),
    19: merged(TWIST, AIM_L_HIGH, DRAW_R_HIGH, LEGS),
    20: merged(TWIST, AIM_L_HIGH, LOOSE_R, LEGS),
    25: merged(TWIST, AIM_L_HIGH, LOOSE_R, LEGS),
    34: HOLD,
})

RESULT = {a.name: list(a.frame_range) for a in bpy.data.actions if a.name.startswith("A_Archer")}
