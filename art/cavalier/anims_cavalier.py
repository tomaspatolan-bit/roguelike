# Animace jezdce v sedle (A_Cavalier_*) na kostře rytíře. Spouští se v Blenderu po build_cavalier.py:
# exec(open(r"<repo>/art/cavalier/anims_cavalier.py", encoding="utf-8").read(), {})
# Jezdec sedí na koni: hra ho připne na kost `saddle` koně (počátek jezdce = RIDER_OFFSET od počátku koně).
# Pózy kopí jsou dohledané numericky (kopí = osa Z kosti ruky): svisle v klidu, sklopené dopředu a dolů
# při bodnutí, vodorovně pod paží při Nájezdu (zápěstí hand_r natočí kopí podél předloktí).
# Smrt jezdce = ragdoll (spadne z koně); zásah jen trupem, nohy zůstávají v sedle.
import bpy

arm = bpy.data.objects["Armature"]
RIDER_OFFSET = (0.0, -0.05, 0.855)      # Blender, od počátku koně (sedlo); ve hře v datech `rider_offset`


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


SEAT = {"thigh_l": (0.953, -0.852, 0.109), "calf_l": (-1.047, 0.0, 0.0),
        "thigh_r": (0.953, 0.852, -0.109), "calf_r": (-1.047, 0.0, 0.0),
        "cape_01": (-0.1, 0.0, 0.0), "cape_02": (-0.15, 0.0, 0.0), "cape_03": (-1.2, 0.0, 0.0)}   # plášť leží na zádi
SHIELD = {"upperarm_l": (0.3, 0.0, -0.55), "lowerarm_l": (1.3, 0.0, 0.0)}                    # štít a otěže
HOLD = {"upperarm_r": (0.3, 0.0, 0.55), "lowerarm_r": (1.3, 0.0, 0.0)}                       # kopí svisle
WINDUP = {"spine_02": (0.0, 0.2, 0.0), "upperarm_r": (0.2, 0.0, 1.2), "lowerarm_r": (1.5, 0.0, 0.0), "hand_r": (-1.25, 2.75, 0.0)}
THRUST = {"spine_02": (0.15, -0.15, 0.0), "upperarm_r": (0.68, 0.0, 1.43), "lowerarm_r": (0.79, 0.0, 0.0), "hand_r": (-1.25, 2.75, 0.0)}
COUCH = {"spine_02": (0.18, 0.0, 0.0), "spine_03": (0.1, 0.0, 0.0), "upperarm_r": (0.18, 0.0, 1.5), "lowerarm_r": (1.3, 0.0, 0.0),
         "hand_r": (-1.26, -0.91, 0.0), "head": (-0.15, 0.0, 0.0)}
BASE = merged(SEAT, SHIELD, HOLD)

# --- v sedle (klid i jízda; houpání dodá kůň)
ride = {}
for f, k in ((1, 0.0), (25, 1.0), (49, 0.0)):
    ride[f] = merged(BASE, {"spine_02": (0.03 * k, 0, 0), "head": (-0.03 * k, 0, 0), "lowerarm_r": (1.3 - 0.04 * k, 0, 0)})
make_action("A_Cavalier_Ride", ride)

# --- bodnutí kopím: nápřah, bodnutí v 8. snímku, návrat
make_action("A_Cavalier_Attack", {
    1: BASE,
    5: merged(BASE, WINDUP),
    8: merged(BASE, THRUST),
    12: merged(BASE, THRUST),
    20: BASE,
})

# --- Nájezd: kopí sklopené pod paží, jezdec se předkloní
make_action("A_Cavalier_Charge", {
    1: BASE,
    5: merged(BASE, COUCH),
    26: merged(BASE, COUCH),
    32: BASE,
})

# --- zásah: trup ucukne dozadu, nohy v sedle
make_action("A_Cavalier_Hit", {
    1: BASE,
    4: merged(BASE, {"spine_02": (-0.2, 0.1, 0.05), "head": (-0.15, 0, 0), "upperarm_l": (0.6, 0, -0.5)}),
    12: BASE,
})

RESULT = {a.name: list(a.frame_range) for a in bpy.data.actions if a.name.startswith("A_Cavalier")}
