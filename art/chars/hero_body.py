# Shared body parts of the heroes (visual prototype, 15.11.2026): the proportions and joints of the tank
# (art/tank/build_tank.py) as functions, so every class has the same body and differs in clothes, armour and colour.
# Exec after art/tools/char_kit.py (needs Kit, the cell constants, frame_for, smoothstep).
# Coordinates as in Knight.blend: 1 = 1 m, the hero faces -Y, his left side is +X, feet at z = 0.
import math
import bpy
from mathutils import Matrix, Vector

SHOULDER = 0.30
ELBOW = 0.512, 1.038
WRIST = 0.689, 0.861


def preview_material(pal_path, row=0):
    """M_Char: palette colour x baked occlusion, for previews in Blender (the game uses its own shader).
    row = palette row of the class (the game shifts the UV by rows the same way)."""
    mat = bpy.data.materials.get("M_Char")
    if mat is None:
        mat = bpy.data.materials.new("M_Char")
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    tex = nt.nodes.new("ShaderNodeTexImage")
    col = nt.nodes.new("ShaderNodeVertexColor")
    mul = nt.nodes.new("ShaderNodeMixRGB")
    mul.blend_type = "MULTIPLY"
    mul.inputs[0].default_value = 1.0
    img = bpy.data.images.get("T_Char_Palette_D")
    if img is None:
        img = bpy.data.images.load(pal_path)
        img.name = "T_Char_Palette_D"
    else:
        img.filepath = pal_path
        img.reload()
    tex.image = img
    tex.interpolation = "Closest"
    col.layer_name = "Col"
    uvn = nt.nodes.new("ShaderNodeUVMap")
    add = nt.nodes.new("ShaderNodeVectorMath")
    add.operation = "ADD"
    add.inputs[1].default_value = (0.0, -row / 16.0, 0.0)
    nt.links.new(uvn.outputs["UV"], add.inputs[0])
    nt.links.new(add.outputs["Vector"], tex.inputs["Vector"])
    nt.links.new(tex.outputs["Color"], mul.inputs[1])
    nt.links.new(col.outputs["Color"], mul.inputs[2])
    nt.links.new(mul.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.6
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return mat


# ------------------------------------------------------------------ weights

def leg_share(co):
    return smoothstep(-0.1, 0.1, co.x)


def skirt_weights(top, bottom, max_leg):
    """Cloth hanging from the hips: pelvis at the top, more and more the nearer thigh towards the hem."""
    def w(co):
        t = smoothstep(top, bottom, co.z) * max_leg
        s = leg_share(co)
        return {"pelvis": 1.0 - t, "thigh_l": t * s, "thigh_r": t * (1.0 - s)}
    return w


def robe_weights(top, knee, ankle):
    """A long robe: pelvis above, the thighs to the knee, the calves below (each side on its own leg, the middle shared)."""
    def w(co):
        t = smoothstep(top, knee, co.z) * 0.7
        c = smoothstep(knee, ankle, co.z) * 0.45
        s = leg_share(co)
        return {"pelvis": max(0.0, 1.0 - t - c), "thigh_l": t * s, "thigh_r": t * (1.0 - s),
                "calf_l": c * s, "calf_r": c * (1.0 - s)}
    return w


def torso_weights(co):
    a = smoothstep(1.0, 1.1, co.z)
    b = smoothstep(1.12, 1.22, co.z)
    return {"spine_01": 1.0 - a, "spine_02": a * (1.0 - b), "spine_03": b}


def cloak_weights(co):
    a = smoothstep(1.30, 1.16, co.z)
    b = smoothstep(1.06, 0.94, co.z)
    c = smoothstep(0.78, 0.66, co.z)
    return {"spine_03": 1.0 - a, "cape_01": a * (1.0 - b), "cape_02": b * (1.0 - c), "cape_03": c}


# ------------------------------------------------------------------ legs

def legs(K, hose, knee=None, shin=None, boot=STEEL_DARK, cuff=STEEL_LIGHT, thigh_plate=None, slim=1.0, boot_top=0.155):
    """Thighs in `hose`; optional thigh plate (cell), knee cop (cell), shin (cell, else the hose continues);
    shoes in `boot` with a cuff (`cuff`, None = none). slim < 1 makes the legs thinner (assassin, archer)."""
    for s, L in ((1.0, "l"), (-1.0, "r")):
        hx = s * 0.115
        thigh, calf, foot, ball = "thigh_" + L, "calf_" + L, "foot_" + L, "ball_" + L
        k = slim
        K.loft([((s * 0.108, 0, 0.90), 0.100 * k, 0.108 * k), ((hx, 0, 0.68), 0.094 * k, 0.100 * k), ((hx, 0, 0.49), 0.078 * k, 0.082 * k)],
               hose, {thigh: 1.0}, n=10, caps=("flat", "flat"))
        if thigh_plate is not None:
            arc = (-150.0, 25.0) if s > 0 else (155.0, 330.0)
            K.loft([((hx, 0, 0.81), 0.114 * k, 0.122 * k), ((hx, 0, 0.56), 0.097 * k, 0.103 * k)], thigh_plate, {thigh: 1.0}, n=7, arc=arc,
                   thick=0.014, e=2.2)
        if knee is not None:
            K.ellipsoid((hx, -0.04, 0.49), (0.074 * k, 0.07 * k, 0.08), knee, {calf: 0.6, thigh: 0.4}, n=10, m=5)
        K.loft([((hx, 0, 0.47), 0.080 * k, 0.086 * k), ((hx, 0.012, 0.31), 0.077 * k, 0.092 * k), ((hx, 0.004, 0.13), 0.060 * k, 0.066 * k)],
               shin if shin is not None else hose, {calf: 1.0}, n=10, e=2.3, caps=("flat", "flat"))
        fr = frame_for((0, -1, 0))
        K.loft([((hx, 0.085, 0.060), 0.056, 0.052, fr), ((hx, 0.0, 0.072), 0.066, 0.068, fr),
                ((hx, -0.115, 0.055), 0.070, 0.052, fr), ((hx, -0.215, 0.044), 0.056, 0.038, fr)],
               boot, lambda co, f=foot, b=ball: {f: 1.0 - smoothstep(-0.10, -0.16, co.y), b: smoothstep(-0.10, -0.16, co.y)},
               n=10, e=2.4, cap_k=0.7)
        if cuff is not None:
            K.loft([((hx, 0.0, 0.105), 0.070 * k, 0.074 * k), ((hx, 0.0, boot_top), 0.066 * k, 0.071 * k)], cuff, {calf: 1.0}, n=10, e=2.3,
                   caps=("flat", "flat"))


# ------------------------------------------------------------------ arms

def arm_frame(s):
    S = Vector((s * SHOULDER, 0, 1.25))
    E = Vector((s * ELBOW[0], 0, ELBOW[1]))
    W = Vector((s * WRIST[0], 0, WRIST[1]))
    d = (W - S).normalized()
    return S, E, W, d, frame_for(d, ref=(0, 1, 0))


def arms(K, sleeve, forearm=None, glove=LEATHER_DARK, elbow=None, bracer=None, cuff=None, slim=1.0, sides=(1.0, -1.0),
         bracer_sides=(1.0, -1.0)):
    """Upper arm in `sleeve`; forearm in `forearm` (else the sleeve), optional elbow cop, bracer (cell, sides in
    bracer_sides), glove cuff; fist in `glove`."""
    for s in sides:
        L = "l" if s > 0 else "r"
        S, E, W, d, fa = arm_frame(s)
        upper, lower, hand = "upperarm_" + L, "lowerarm_" + L, "hand_" + L
        k = slim
        K.loft([(S + d * 0.02, 0.068 * k, 0.068 * k, fa), (E, 0.060 * k, 0.060 * k, fa)], sleeve, {upper: 1.0}, n=8, caps=("flat", "flat"))
        if elbow is not None:
            K.ellipsoid(E, (0.072 * k, 0.072 * k, 0.072 * k), elbow, {lower: 0.6, upper: 0.4}, n=8, m=5)
        else:
            K.ellipsoid(E, (0.061 * k, 0.061 * k, 0.061 * k), sleeve, {lower: 0.6, upper: 0.4}, n=8, m=4)
        wrist_end = W - d * 0.07 if cuff is not None else W + d * 0.02    # without a cuff the forearm reaches the fist
        K.loft([(E + d * 0.02, 0.062 * k, 0.062 * k, fa), (wrist_end, 0.054 * k, 0.054 * k, fa)], forearm if forearm is not None else sleeve,
               {lower: 1.0}, n=8, e=2.2, caps=("flat", "flat"))
        if bracer is not None and s in bracer_sides:
            K.loft([(E + d * 0.06, 0.068 * k, 0.068 * k, fa), (W - d * 0.03, 0.062 * k, 0.062 * k, fa)], bracer, {lower: 1.0}, n=8, e=2.4,
                   caps=("flat", "flat"))
        if cuff is not None:
            K.loft([(W - d * 0.085, 0.074 * k, 0.074 * k, fa), (W + d * 0.005, 0.058 * k, 0.058 * k, fa)], cuff, {lower: 1.0}, n=8, e=2.2,
                   caps=("flat", "flat"))
        K.ellipsoid(W + d * 0.075, (0.058, 0.064, 0.078), glove, {hand: 1.0}, n=8, m=5, frame=fa)


def shoulder_cap(K, s, cell, size=(0.13, 0.14, 0.095), tilt=24.0, rim=None, z=1.288):
    """A rounded shoulder piece (pauldron, padded roll, capelet bulge)."""
    L = "l" if s > 0 else "r"
    th = math.radians(tilt) * s
    fp = Matrix(((math.cos(th), 0, -math.sin(th)), (0, 1, 0), (math.sin(th), 0, math.cos(th)))).transposed()
    pc = Vector((s * 0.318, 0, z))
    pw = {"clavicle_" + L: 0.5, "upperarm_" + L: 0.5}
    K.ellipsoid(pc, size, cell, pw, n=12, m=5, frame=fp, z_range=(-0.4, 1.0))
    if rim is not None:
        K.loft([((0, 0, -0.054), size[0], size[1]), ((0, 0, -0.026), size[0] * 1.02, size[1] * 1.02)], rim, pw, n=12, caps=("flat", "flat"),
               frame=fp, origin=pc)


# ------------------------------------------------------------------ head

def face(K, beard=HAIR, hair=None, skin=SKIN, scale=1.08):
    """An open face: head, nose, beard (cell or None), hair cap (cell or None). Simple shapes: from the battle camera a
    face is a few pixels, so it is a colour, not a likeness (style guide)."""
    parts = []
    HW = {"head": 1.0}
    parts.append(K.loft([((0, -0.005, 1.37), 0.062, 0.070), ((0, -0.01, 1.45), 0.092, 0.104), ((0, -0.005, 1.53), 0.098, 0.112),
                         ((0, 0.0, 1.60), 0.090, 0.104), ((0, 0.005, 1.655), 0.062, 0.074)], skin, HW, n=14, e=2.1,
                        caps=("flat", "round"), cap_k=0.45))
    parts.append(K.ellipsoid((0, -0.115, 1.51), (0.018, 0.026, 0.03), skin, HW, n=8, m=4))
    for s in (1.0, -1.0):   # eyes as dark marks
        parts.append(K.ellipsoid((s * 0.038, -0.1, 1.545), (0.013, 0.008, 0.009), VOID, HW, n=6, m=3))
    if beard is not None:
        parts.append(K.loft([((0, -0.04, 1.50), 0.096, 0.08), ((0, -0.05, 1.44), 0.092, 0.08), ((0, -0.06, 1.39), 0.06, 0.052),
                             ((0, -0.075, 1.35), 0.026, 0.024)], beard, HW, n=10, arc=(15.0, 165.0), thick=0.03, e=2.2))   # path goes down: front = 90°
    if hair is not None:
        parts.append(K.loft([((0, 0.01, 1.53), 0.103, 0.118), ((0, 0.01, 1.60), 0.096, 0.112), ((0, 0.01, 1.66), 0.066, 0.078)], hair, HW,
                            n=14, e=2.2, caps=("flat", "round"), cap_k=0.5))
    for p in parts:
        scale_about(p, (0, 0, 1.37), scale)
    return parts


def hood(K, cell, lining=VOID, open_face=True, point=0.0, scale=1.08, weights=None, opening=55.0):
    """A hood over the head (cell): a shell open at the front (half-angle `opening` degrees) so the face shows, the
    inside in `lining`; optional point at the back (m). open_face=False closes it with a dark face (assassin's mask)."""
    HW = weights or {"head": 1.0}
    parts = []
    rings = [((0, 0.0, 1.36), 0.124, 0.134), ((0, 0.0, 1.45), 0.13, 0.142), ((0, 0.01, 1.54), 0.126, 0.14),
             ((0, 0.02, 1.62), 0.11, 0.124), ((0, 0.04 + point * 0.5, 1.69), 0.064, 0.08), ((0, 0.06 + point, 1.72), 0.02, 0.03)]
    if open_face:
        # path goes up: the front (-Y) is at ring angle -90
        h = parts.append(K.loft(rings, cell, HW, n=16, e=2.1, arc=(-90.0 + opening, 270.0 - opening), thick=0.016))
        parts.append(K.loft(rings[-2:], cell, HW, n=12, e=2.1, caps=("flat", "round"), cap_k=0.8))
    else:
        parts.append(K.loft(rings, cell, HW, n=16, e=2.1, caps=("flat", "round"), cap_k=0.6))
        fy = frame_for((0, -1, 0))
        parts.append(K.loft([((0, -0.118, 1.5), 0.07, 0.07, fy), ((0, -0.132, 1.5), 0.078, 0.086, fy)], lining, HW, n=14, e=2.2,
                            caps=("flat", "flat")))
    for p in parts:
        scale_about(p, (0, 0, 1.37), scale)
    return parts


def collar(K, cell, r=(0.15, 0.135), z0=1.27, z1=1.36):
    """Mantle collar / hood shoulders around the neck."""
    K.loft([((0, 0, z0), r[0] * 1.35, r[1] * 1.35), ((0, 0, (z0 + z1) / 2), r[0] * 1.05, r[1] * 1.05), ((0, 0, z1), r[0] * 0.72, r[1] * 0.75)],
           cell, {"spine_03": 0.6, "neck_01": 0.4}, n=16, e=2.2, caps=("flat", "flat"))


def belt(K, cell=LEATHER, buckle=GOLD, z=0.965, r=(0.197, 0.153)):
    K.loft([((0, 0, z - 0.028), r[0], r[1]), ((0, 0, z + 0.028), r[0], r[1])], cell, {"pelvis": 1.0}, n=14, e=2.4, caps=("flat", "flat"))
    if buckle is not None:
        K.box((0, -r[1] - 0.004, z), (0.06, 0.02, 0.056), buckle, {"pelvis": 1.0}, bevel=0.007)


def torso(K, cell, chest=1.0, waist=1.0, top_round=0.25, n=16):
    """The upper body (tunic or surcoat), hips to shoulders."""
    K.loft([((0, 0, 0.975), 0.190 * waist, 0.148 * waist), ((0, 0, 1.06), 0.202 * waist, 0.157 * waist),
            ((0, -0.012, 1.16), 0.228 * chest, 0.178 * chest), ((0, -0.006, 1.25), 0.216 * chest, 0.166 * chest),
            ((0, 0, 1.31), 0.170, 0.132)], cell, torso_weights, n=n, e=2.5, caps=("flat", "round"), cap_k=top_round)


def cloak(K, cell, inner=ROLE_DARK, width=1.0, length=0.93, hem=ROLE_DARK, nu=12, nv=10, folds=3.0, side=0.0):
    """A cloak hanging from the shoulders down the back (side shifts it: > 0 more over the left shoulder)."""
    def f(u, v):
        w = (0.23 + 0.125 * v) * width
        fold = 0.030 * math.cos(u * folds * math.pi) * smoothstep(0.0, 0.5, v)
        wrap = -0.07 * u * u * (1.0 - 0.6 * v)
        return (u * w + side * (1.0 - v), 0.178 + 0.115 * v + fold + wrap, 1.345 - length * v - 0.05 * u * u * (1.0 - v))
    K.sheet(f, nu, nv, 0.016, cell, cloak_weights, cell_in=inner, cell_fn=lambda u, v: hem if v > 0.9 else None)
