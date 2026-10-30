# Animace koně (A_Horse_*) na kostře Armature_Horse. Spouští se v Blenderu po build_horse.py:
# exec(open(r"<repo>/art/cavalier/anims_horse.py", encoding="utf-8").read(), {})
# Konvence kostry (ověřeno 30.10.2026): upperleg_* rotace X kladná = noha dozadu (záporná = vykročí dopředu),
# lowerleg_f X kladná = ohyb předního kolene, lowerleg_b X záporná = ohyb hlezna, neck X kladná = hlava dolů,
# tail Z = švihnutí do strany, root Y = převalení na bok (kladné doleva), root.loc ve světových osách.
# Klid a klus jsou smyčky; cval (Nájezd) smyčka; zásah a smrt jednorázové. 24 fps.
import bpy

arm = bpy.data.objects["Armature_Horse"]
LEGS = [f"{p}_{fb}_{s}" for p in ("upperleg", "lowerleg", "hoof") for fb in ("f", "b") for s in ("l", "r")]


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
    chans = {"root.loc"} | {b.name for b in arm.pose.bones}    # vždy všechny kosti (export se vzorkováním)
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


def leg(fb, s, up, low=0.0, hoof=0.0):
    return {f"upperleg_{fb}_{s}": (up, 0, 0), f"lowerleg_{fb}_{s}": (low, 0, 0), f"hoof_{fb}_{s}": (hoof, 0, 0)}


def merged(*poses):
    out = {}
    for p in poses:
        out.update(p)
    return out


# --- klid: dýchání, hlava pomalu kývá, ocas švihá
idle = {}
for f, k, t in ((1, 0.0, 0.0), (21, 0.6, 1.0), (41, 1.0, -0.6), (61, 0.0, 0.0)):
    idle[f] = {"spine": (0.02 * k, 0, 0), "neck": (0.06 * k - 0.03, 0, 0.04 * t), "head": (-0.04 * k, 0, 0),
               "tail": (0.05 * k, 0, 0.25 * t), "root.loc": (0, 0, 0.008 * k)}
make_action("A_Horse_Idle", idle)

# --- klus (chůze ve hře): diagonální dvojice, 16 snímků na krok
FLEX_F, FLEX_B = 0.95, -0.75
def trot(a_up, a_low, b_up, b_low, bob, nod):
    p = {}
    for fb, s, up, lowk in (("f", "l", a_up, a_low), ("b", "r", a_up, a_low), ("f", "r", b_up, b_low), ("b", "l", b_up, b_low)):
        p.update(leg(fb, s, up, lowk * (FLEX_F if fb == "f" else FLEX_B), -0.3 * lowk if fb == "f" else 0.3 * lowk))
    p["root.loc"] = (0, 0, bob)
    p["neck"] = (nod, 0, 0)
    p["tail"] = (-0.1, 0, 0)
    return p
make_action("A_Horse_Walk", {
    1: trot(-0.35, 0.0, 0.35, 0.1, -0.02, 0.05),
    5: trot(0.0, 0.0, 0.0, 1.0, 0.025, -0.04),
    9: trot(0.35, 0.1, -0.35, 0.0, -0.02, 0.05),
    13: trot(0.0, 1.0, 0.0, 0.0, 0.025, -0.04),
    17: trot(-0.35, 0.0, 0.35, 0.1, -0.02, 0.05),
}, cyclic=True)

# --- cval (Nájezd): 12 snímků, sebrání, odraz zadních, natažení předních, dopad
def gal(fu, fl, bu, bl, bob, pitch, nod, lead=0.12):
    p = {}
    for s, d in (("l", lead), ("r", -lead)):
        p.update(leg("f", s, fu + d, fl * FLEX_F))
        p.update(leg("b", s, bu + d, bl * FLEX_B))
    p["root.loc"] = (0, 0, bob)
    p["pelvis"] = (pitch, 0, 0)
    p["neck"] = (nod, 0, 0)
    p["tail"] = (-0.45, 0, 0)
    return p
make_action("A_Horse_Gallop", {
    1: gal(0.35, 0.3, -0.45, 0.2, -0.02, 0.0, -0.1),
    4: gal(-0.55, 0.35, 0.55, 0.0, 0.07, 0.06, 0.05),
    7: gal(0.0, 0.0, 0.0, 1.0, 0.0, -0.05, 0.18),
    10: gal(0.45, 0.9, -0.5, 0.6, 0.1, 0.0, -0.05),
    13: gal(0.35, 0.3, -0.45, 0.2, -0.02, 0.0, -0.1),
}, cyclic=True)

# --- zásah: hlava vzhůru, kůň uhne
make_action("A_Horse_Hit", {
    1: {},
    4: {"neck": (-0.35, 0, 0.1), "head": (-0.2, 0, 0), "root": (0, 0.06, 0), "root.loc": (0.04, 0.03, 0),
        "upperleg_f_l": (-0.2, 0, 0), "lowerleg_f_l": (0.5, 0, 0)},
    12: {},
})

# --- smrt: přední nohy podklesnou, kůň se převalí na bok a zůstane ležet
make_action("A_Horse_Death", {
    1: {},
    8: merged(leg("f", "l", 0.45, 1.3), leg("f", "r", 0.45, 1.3), {"neck": (-0.3, 0, 0), "root.loc": (0, 0, -0.25),
              "root": (0, 0.1, 0), "tail": (0.2, 0, 0)}),
    18: merged(leg("f", "l", 0.3, 1.0), leg("f", "r", 0.3, 1.0), leg("b", "l", -0.3, -0.9), leg("b", "r", -0.3, -0.9),
               {"neck": (0.1, 0, 0.2), "root": (0, 0.75, 0), "root.loc": (-0.35, 0, -0.1)}),
    30: merged(leg("f", "l", -0.25, 0.3), leg("f", "r", -0.4, 0.5), leg("b", "l", 0.15, -0.3), leg("b", "r", 0.3, -0.5),
               {"neck": (0.25, 0, 0.35), "head": (0.2, 0, 0), "root": (0, 1.45, 0), "root.loc": (-0.86, 0, 0.17), "tail": (0, 0, 0.3)}),
    36: merged(leg("f", "l", -0.25, 0.3), leg("f", "r", -0.4, 0.5), leg("b", "l", 0.15, -0.3), leg("b", "r", 0.3, -0.5),
               {"neck": (0.27, 0, 0.35), "head": (0.2, 0, 0), "root": (0, 1.45, 0), "root.loc": (-0.86, 0, 0.17), "tail": (0, 0, 0.3)}),
})

RESULT = {a.name: list(a.frame_range) for a in bpy.data.actions if a.name.startswith("A_Horse")}
