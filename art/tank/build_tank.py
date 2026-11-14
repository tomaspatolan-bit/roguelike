# Tank, Sir Borek (visual prototype, phase 2, 14.11.2026): built from scratch with art/tools/char_kit.py on the
# knight skeleton (Armature in Knight.blend, same bones and animations as before).
# Run in Blender with Knight.blend open:
#   exec(open(r"<repo>/art/tank/build_tank.py", encoding="utf-8").read(),
#        {"KIT": r"<repo>/art/tools/char_kit.py", "PAL": r"<repo>/art/chars/T_Char_Palette_D.png", "OUT": r"<repo>/art/tank"})
# Result: SK_Tank (one mesh with the shield on the left forearm) and SM_Tank_Sword in the collection TANK_game;
# with OUT set also SK_Tank.glb (with every action of the skeleton) and SM_Tank_Sword.glb.
# Design (style guide): the class colour is carried by big surfaces seen from above and from every side: cloak,
# painted helmet and pauldrons, surcoat with a full skirt, padded sleeves and hose, and the shield.
# painted thigh plates and tassets. Steel is secondary (visor, gorget, elbows, forearms, gauntlets, legs from the knee down).
import math
import bmesh
import bpy
from mathutils import Matrix, Vector

exec(open(KIT, encoding="utf-8").read(), globals())
COL = "TANK_game"

# preview material: palette colour x baked occlusion (the game uses its own shader)
mat = bpy.data.materials.get("M_Char")
if mat is None:
    mat = bpy.data.materials.new("M_Char")
mat.use_nodes = True
nt = mat.node_tree
nt.nodes.clear()
n_out = nt.nodes.new("ShaderNodeOutputMaterial")
n_bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
n_tex = nt.nodes.new("ShaderNodeTexImage")
n_col = nt.nodes.new("ShaderNodeVertexColor")
n_mul = nt.nodes.new("ShaderNodeMixRGB")
n_mul.blend_type = "MULTIPLY"
n_mul.inputs[0].default_value = 1.0
img = bpy.data.images.get("T_Char_Palette_D")
if img is None:
    img = bpy.data.images.load(PAL)
    img.name = "T_Char_Palette_D"
else:
    img.filepath = PAL
    img.reload()
n_tex.image = img
n_tex.interpolation = "Closest"
n_col.layer_name = "Col"
nt.links.new(n_tex.outputs["Color"], n_mul.inputs[1])
nt.links.new(n_col.outputs["Color"], n_mul.inputs[2])
nt.links.new(n_mul.outputs["Color"], n_bsdf.inputs["Base Color"])
n_bsdf.inputs["Roughness"].default_value = 0.6
nt.links.new(n_bsdf.outputs["BSDF"], n_out.inputs["Surface"])

ob = new_skinned("SK_Tank", COL)
bm = bmesh.new()
K = Kit(ob, bm)
X = Vector((1.0, 0.0, 0.0))
Y = Vector((0.0, 1.0, 0.0))
Z = Vector((0.0, 0.0, 1.0))


def leg_share(co):
    return smoothstep(-0.1, 0.1, co.x)


def skirt_weights(top, bottom, max_leg):
    def w(co):
        t = smoothstep(top, bottom, co.z) * max_leg
        s = leg_share(co)
        return {"pelvis": 1.0 - t, "thigh_l": t * s, "thigh_r": t * (1.0 - s)}
    return w


def torso_weights(co):
    a = smoothstep(1.0, 1.1, co.z)
    b = smoothstep(1.12, 1.22, co.z)
    return {"spine_01": 1.0 - a, "spine_02": a * (1.0 - b), "spine_03": b}


# ------------------------------------------------------------------ legs
for s, L in ((1.0, "l"), (-1.0, "r")):
    hx = s * 0.115
    thigh, calf, foot, ball = "thigh_" + L, "calf_" + L, "foot_" + L, "ball_" + L
    K.loft([((s * 0.108, 0, 0.90), 0.100, 0.108), ((hx, 0, 0.68), 0.094, 0.100), ((hx, 0, 0.49), 0.078, 0.082)],
           ROLE_DARK, {thigh: 1.0}, n=10, caps=("flat", "flat"))        # padded hose in the class colour
    arc = (-150.0, 25.0) if s > 0 else (155.0, 330.0)
    K.loft([((hx, 0, 0.81), 0.114, 0.122), ((hx, 0, 0.56), 0.097, 0.103)], ROLE_PAINT, {thigh: 1.0}, n=7, arc=arc, thick=0.014, e=2.2)
    K.ellipsoid((hx, -0.04, 0.49), (0.074, 0.07, 0.08), STEEL_LIGHT, {calf: 0.6, thigh: 0.4}, n=10, m=5)
    K.loft([((hx, 0, 0.47), 0.080, 0.086), ((hx, 0.012, 0.31), 0.077, 0.092), ((hx, 0.004, 0.13), 0.060, 0.066)],
           STEEL, {calf: 1.0}, n=10, e=2.3, caps=("flat", "flat"))
    fr = frame_for((0, -1, 0))
    K.loft([((hx, 0.085, 0.060), 0.056, 0.052, fr), ((hx, 0.0, 0.072), 0.066, 0.068, fr),
            ((hx, -0.115, 0.055), 0.070, 0.052, fr), ((hx, -0.215, 0.044), 0.056, 0.038, fr)],
           STEEL_DARK, lambda co, f=foot, b=ball: {f: 1.0 - smoothstep(-0.10, -0.16, co.y), b: smoothstep(-0.10, -0.16, co.y)},
           n=10, e=2.4, cap_k=0.7)
    K.loft([((hx, 0.0, 0.105), 0.070, 0.074), ((hx, 0.0, 0.155), 0.066, 0.071)], STEEL_LIGHT, {calf: 1.0}, n=10, e=2.3,
           caps=("flat", "flat"))

# ------------------------------------------------------------------ hips, belt, surcoat skirt
K.loft([((0, 0, 0.985), 0.186, 0.142), ((0, 0, 0.86), 0.204, 0.154), ((0, 0, 0.70), 0.226, 0.170)], ROLE,
       skirt_weights(0.92, 0.70, 0.6), n=14, e=2.4, caps=("flat", "flat"))   # the surcoat's skirt, all the way round
K.loft([((0, 0, 0.94), 0.197, 0.153), ((0, 0, 0.995), 0.197, 0.153)], LEATHER, {"pelvis": 1.0}, n=14, e=2.4, caps=("flat", "flat"))
K.box((0, -0.156, 0.968), (0.07, 0.024, 0.062), GOLD, {"pelvis": 1.0}, bevel=0.008)
for s, L in ((1.0, "l"), (-1.0, "r")):
    arc = (-62.0, 12.0) if s > 0 else (168.0, 242.0)
    K.loft([((0, 0, 0.935), 0.214, 0.166), ((0, 0, 0.72), 0.238, 0.184)], ROLE_PAINT, {"pelvis": 0.55, "thigh_" + L: 0.45},
           n=6, arc=arc, thick=0.014, e=2.4)


def hem(u, v):
    return GOLD if v > 0.93 else None


K.sheet(lambda u, v: (-u * (0.125 + 0.04 * v), -(0.150 + 0.055 * v ** 0.6) + 0.02 * u * u, 0.945 - 0.46 * v),
        6, 7, 0.014, ROLE, skirt_weights(0.93, 0.6, 0.7), cell_in=ROLE_DARK, cell_fn=hem)
K.sheet(lambda u, v: (u * (0.125 + 0.04 * v), (0.150 + 0.055 * v ** 0.6) - 0.02 * u * u, 0.945 - 0.46 * v),
        6, 7, 0.014, ROLE, skirt_weights(0.93, 0.6, 0.7), cell_in=ROLE_DARK, cell_fn=hem)

# ------------------------------------------------------------------ torso (surcoat over the breastplate), gorget
K.loft([((0, 0, 0.975), 0.190, 0.148), ((0, 0, 1.06), 0.202, 0.157), ((0, -0.012, 1.16), 0.228, 0.178),
        ((0, -0.006, 1.25), 0.216, 0.166), ((0, 0, 1.31), 0.170, 0.132)], ROLE, torso_weights, n=16, e=2.5,
       caps=("flat", "round"), cap_k=0.25)
K.box((0, -0.187, 1.175), (0.092, 0.016, 0.092), GOLD, {"spine_03": 1.0}, rot=Matrix.Rotation(math.radians(45.0), 3, "Y"), bevel=0.005)
K.loft([((0, 0, 1.285), 0.132, 0.122), ((0, 0, 1.375), 0.096, 0.102)], STEEL, {"spine_03": 0.5, "neck_01": 0.5}, n=12, e=2.2,
       caps=("flat", "flat"))

# ------------------------------------------------------------------ helmet (scaled 1.08 about the head joint)
head = []
HW = {"head": 1.0}
head.append(K.loft([((0, -0.005, 1.37), 0.098, 0.108), ((0, -0.005, 1.45), 0.108, 0.122), ((0, -0.005, 1.53), 0.110, 0.125),
                    ((0, -0.005, 1.60), 0.100, 0.115), ((0, -0.005, 1.655), 0.070, 0.082)], ROLE_PAINT, HW, n=16, e=2.3,
                   caps=("flat", "round"), cap_k=0.45))
head.append(K.loft([((0, -0.005, 1.415), 0.118, 0.150), ((0, -0.005, 1.49), 0.122, 0.158), ((0, -0.005, 1.555), 0.115, 0.140)],
                   STEEL_LIGHT, HW, n=8, arc=(-150.0, -30.0), thick=0.014, e=2.3))
head.append(K.loft([((0, -0.005, 1.503), 0.1225, 0.1565), ((0, -0.005, 1.524), 0.1205, 0.1515)], VOID, HW, n=8,
                   arc=(-140.0, -40.0), thick=0.004, e=2.3))
head.append(K.loft([((0, -0.005, 1.383), 0.105, 0.116), ((0, -0.005, 1.402), 0.106, 0.118)], GOLD, HW, n=14, e=2.3,
                   caps=("flat", "flat")))
fy = frame_for((0, 1, 0))
head.append(K.loft([((0, -0.115, 1.625), 0.016, 0.020, fy), ((0, -0.07, 1.672), 0.022, 0.058, fy), ((0, 0.0, 1.700), 0.024, 0.078, fy),
                    ((0, 0.08, 1.686), 0.024, 0.072, fy), ((0, 0.14, 1.642), 0.022, 0.048, fy), ((0, 0.172, 1.60), 0.016, 0.020, fy)],
                   ROLE_LIGHT, HW, n=8, e=2.6, cap_k=0.6))
for part in head:
    scale_about(part, (0, 0, 1.37), 1.08)

# ------------------------------------------------------------------ arms, pauldrons
for s, L in ((1.0, "l"), (-1.0, "r")):
    S = Vector((s * 0.30, 0, 1.25))
    E = Vector((s * 0.512, 0, 1.038))
    W = Vector((s * 0.689, 0, 0.861))
    d = (W - S).normalized()
    upper, lower, hand, clav = "upperarm_" + L, "lowerarm_" + L, "hand_" + L, "clavicle_" + L
    fa = frame_for(d, ref=(0, 1, 0))
    K.loft([(S + d * 0.02, 0.068, 0.068, fa), (E, 0.060, 0.060, fa)], ROLE_DARK, {upper: 1.0}, n=8, caps=("flat", "flat"))   # padded sleeve
    K.ellipsoid(E, (0.076, 0.076, 0.076), STEEL_LIGHT, {lower: 0.6, upper: 0.4}, n=8, m=5)
    K.loft([(E + d * 0.035, 0.072, 0.072, fa), (W - d * 0.07, 0.061, 0.061, fa)], ROLE_PAINT, {lower: 1.0}, n=8, e=2.2,
           caps=("flat", "flat"))
    K.loft([(W - d * 0.085, 0.080, 0.080, fa), (W + d * 0.005, 0.060, 0.060, fa)], STEEL_LIGHT, {lower: 1.0}, n=8, e=2.2,
           caps=("flat", "flat"))
    K.ellipsoid(W + d * 0.075, (0.062, 0.068, 0.082), STEEL_DARK, {hand: 1.0}, n=8, m=5, frame=fa)
    th = math.radians(24.0) * s
    fp = Matrix(((math.cos(th), 0, -math.sin(th)), (0, 1, 0), (math.sin(th), 0, math.cos(th)))).transposed()
    pc = Vector((s * 0.318, 0, 1.288))
    pw = {clav: 0.5, upper: 0.5}
    K.ellipsoid(pc, (0.150, 0.158, 0.108), ROLE_PAINT, pw, n=12, m=5, frame=fp, z_range=(-0.4, 1.0))
    K.loft([((0, 0, -0.062), 0.150, 0.158), ((0, 0, -0.030), 0.153, 0.161)], STEEL_LIGHT, pw, n=12, caps=("flat", "flat"),
           frame=fp, origin=pc)
    K.ellipsoid(S + d * 0.135, (0.100, 0.104, 0.078), STEEL, {upper: 1.0}, n=10, m=4, frame=fa, z_range=(-0.5, 1.0))

# ------------------------------------------------------------------ cloak


def cloak(u, v):
    w = 0.23 + 0.125 * v
    fold = 0.030 * math.cos(u * 3.0 * math.pi) * smoothstep(0.0, 0.5, v)
    wrap = -0.07 * u * u * (1.0 - 0.6 * v)
    return (u * w, 0.178 + 0.115 * v + fold + wrap, 1.345 - 0.93 * v - 0.05 * u * u * (1.0 - v))


def cloak_weights(co):
    a = smoothstep(1.30, 1.16, co.z)
    b = smoothstep(1.06, 0.94, co.z)
    c = smoothstep(0.78, 0.66, co.z)
    return {"spine_03": 1.0 - a, "cape_01": a * (1.0 - b), "cape_02": b * (1.0 - c), "cape_03": c}


K.sheet(cloak, 12, 10, 0.016, ROLE, cloak_weights, cell_in=ROLE_DARK, cell_fn=lambda u, v: ROLE_DARK if v > 0.9 else None)

# ------------------------------------------------------------------ shield on the left forearm
E = Vector((0.512, 0, 1.038))
W = Vector((0.689, 0, 0.861))
a0 = (W - E).normalized()                # forearm axis, elbow -> hand
n = Vector((0.7071, 0, 0.7071))          # outer side of the forearm in the rest pose
# The long axis is turned 40 degrees from the forearm (about n), as on a strapped shield: with the arm hanging the
# shield stays upright, in the raised guard (forearm level across the body) its top still points up.
PHI = math.radians(40.0)
a = a0 * math.cos(PHI) + Y * math.sin(PHI)       # long axis: top -> point
b = -a0 * math.sin(PHI) + Y * math.cos(PHI)      # across
C = E + a0 * 0.14 + n * 0.115
SH_H, SH_TOP, SH_W = 0.72, -0.37, 0.29


def shield_hw(v):
    if v < 0.5:
        return SH_W
    return max(0.012, SH_W * math.sqrt(max(0.0, 1.0 - ((v - 0.5) / 0.5) ** 2.4)))


def shield(u, v):
    x = -u * shield_hw(v)
    return C + b * x + a * (SH_TOP + SH_H * v) + n * (-0.55 * x * x)


def shield_cells(u, v):
    if abs(u) > 0.9 or v < 0.0625 or v > 0.94:
        return GOLD
    if abs(u) < 0.1:
        return IVORY
    return None


K.sheet(shield, 20, 16, 0.03, ROLE_PAINT, {"lowerarm_l": 1.0}, cell_in=WOOD, cell_fn=shield_cells)
K.ellipsoid(C + a * (SH_TOP + SH_H * 0.36) + n * 0.004, (0.07, 0.07, 0.04), GOLD, {"lowerarm_l": 1.0}, n=10, m=4,
            frame=Matrix((a, b, n)).transposed(), z_range=(0.0, 1.0))

RESULT = finish(ob, bm)
bm.free()

# ------------------------------------------------------------------ sword (grip at the origin, blade along +Z)
sw = new_skinned("SM_Tank_Sword", COL, armature=None)
wb = bmesh.new()
S = Kit(sw, wb)
S.loft([((0, 0, -0.10), 0.021, 0.021), ((0, 0, 0.10), 0.021, 0.021)], LEATHER_DARK, {}, n=8, caps=("flat", "flat"))
S.ellipsoid((0, 0, -0.135), (0.038, 0.038, 0.038), GOLD, {}, n=8, m=4)
S.box((0, 0, 0.118), (0.28, 0.046, 0.042), GOLD, {}, bevel=0.012)
S.loft([((0, 0, 0.14), 0.046, 0.012), ((0, 0, 0.76), 0.038, 0.009), ((0, 0, 0.93), 0.024, 0.006), ((0, 0, 0.99), 0.005, 0.003)],
       STEEL_LIGHT, {}, n=8, e=1.25, caps=("flat", "flat"), frame=Matrix.Identity(3))
S.box((0, 0, 0.45), (0.018, 0.028, 0.56), STEEL_DARK, {})
RESULT["sword"] = finish(sw, wb, ao=False)
wb.free()

if globals().get("OUT"):
    import os
    arm = bpy.data.objects["Armature"]
    export_glb([arm, ob], os.path.join(OUT, "SK_Tank.glb"))
    export_glb([sw], os.path.join(OUT, "SM_Tank_Sword.glb"), animations=False)
    RESULT["exported"] = True
