# The cavalier's warhorse (visual prototype, 15.11.2026): a new mesh SK_Horse2 built with art/tools/char_kit.py on the
# existing horse skeleton Armature_Horse (same bones and A_Horse_* animations; build_horse.py created the skeleton).
# Run in Blender with Knight.blend open:
#   exec(open(r"<repo>/art/cavalier/build_horse2.py", encoding="utf-8").read(),
#        {"KIT": r"<repo>/art/tools/char_kit.py", "BODY": r"<repo>/art/chars/hero_body.py", "PAL": r"<repo>/art/chars/T_Char_Palette_D.png"})
# The horse faces -Y, left side = +X, hooves at z = 0, withers ~1.5 m. Bones: pelvis (rump), spine (barrel, chest, saddle),
# neck, head, tail, upperleg/lowerleg/hoof _f_/_b_ _l/_r. The `saddle` bone (non-deforming) seats the rider in the game.
# Design (style guide): a bay horse with volume (barrel, chest, rump, muscled legs with joints, a real head and neck), dark
# mane and tail. The ochre caparison over the rump and the chest carries the cavalier's colour, so the rider and the horse
# read as one unit from above; navy hem and the order's lozenge, painted chanfron with a gold crest, an ochre crinet, leather saddle on a
# navy blanket.
import math
import bmesh
import bpy
from mathutils import Matrix, Vector

exec(open(KIT, encoding="utf-8").read(), globals())
exec(open(BODY, encoding="utf-8").read(), globals())
preview_material(PAL, 4)
COL = "HORSE2_game"
COAT, COAT_DARK, MANE, HOOF = LEATHER, LEATHER_DARK, HAIR, VOID

ob = new_skinned("SK_Horse2", COL, armature="Armature_Horse")
bm = bmesh.new()
K = Kit(ob, bm)
FY = frame_for((0, -1, 0))      # ring x = width (X), ring y = height (Z)


def body_w(co):
    k = smoothstep(-0.15, 0.3, co.y)
    return {"pelvis": k, "spine": 1.0 - k}


# ------------------------------------------------------------------ barrel, rump, chest (one loft from the tail to the chest)
body = [((0, 0.76, 1.24), 0.12, 0.13), ((0, 0.7, 1.26), 0.22, 0.25), ((0, 0.55, 1.26), 0.28, 0.3), ((0, 0.3, 1.22), 0.29, 0.31),
        ((0, 0.0, 1.2), 0.28, 0.32), ((0, -0.3, 1.22), 0.29, 0.32), ((0, -0.52, 1.28), 0.26, 0.3), ((0, -0.66, 1.32), 0.17, 0.22)]
K.loft([(Vector(p), rx, ry, FY) for p, rx, ry in body], COAT, body_w, n=16, e=2.15, caps=("round", "round"), cap_k=0.5)

# ------------------------------------------------------------------ neck, head, ears, eyes, mane, forelock
N0, N1 = Vector((0, -0.5, 1.38)), Vector((0, -0.8, 1.84))
nd = (N1 - N0).normalized()
fn_ = frame_for(nd, ref=(1, 0, 0))


def neck_w(co):
    t = smoothstep(1.4, 1.55, co.z)
    return {"spine": 1.0 - t, "neck": t}


K.loft([(N0 - nd * 0.1, 0.19, 0.28, fn_), (N0 + nd * 0.15, 0.165, 0.24, fn_), (N0 + nd * 0.35, 0.13, 0.19, fn_), (N1, 0.1, 0.14, fn_)],
       COAT, neck_w, n=12, e=2.1, caps=("flat", "flat"))
H0, H1 = Vector((0, -0.77, 1.88)), Vector((0, -1.12, 1.47))
hd = (H1 - H0).normalized()
fh = frame_for(hd, ref=(1, 0, 0))
K.loft([(H0 - hd * 0.04, 0.085, 0.1, fh), (H0 + hd * 0.1, 0.09, 0.115, fh), (H0 + hd * 0.32, 0.068, 0.088, fh), (H1, 0.062, 0.075, fh)],
       COAT, {"head": 1.0}, n=12, e=2.1, caps=("round", "round"), cap_k=0.5)
K.ellipsoid(H1 - hd * 0.02, (0.064, 0.075, 0.06), COAT_DARK, {"head": 1.0}, n=10, m=4, frame=fh)   # muzzle
for s in (1.0, -1.0):
    K.ellipsoid((s * 0.05, -0.76, 1.99), (0.026, 0.02, 0.06), COAT, {"head": 1.0}, n=8, m=4,
                frame=Matrix.Rotation(s * 0.25, 3, "Y") @ Matrix.Rotation(-0.25, 3, "X"))
    K.ellipsoid((s * 0.078, -0.9, 1.73), (0.012, 0.022, 0.018), VOID, {"head": 1.0}, n=6, m=3)
up_n = Vector((0, -nd.z, nd.y))
if up_n.z < 0:
    up_n = -up_n
K.loft([(N0 + nd * 0.05 + up_n * 0.2, 0.03, 0.05, fn_), (N0 + nd * 0.3 + up_n * 0.15, 0.035, 0.06, fn_),
        (N1 + up_n * 0.11, 0.03, 0.05, fn_), (N1 + nd * 0.08 + up_n * 0.07, 0.02, 0.03, fn_)], MANE, neck_w, n=8,
       caps=("round", "round"), cap_k=0.6)
K.ellipsoid((0, -0.83, 1.93), (0.035, 0.05, 0.03), MANE, {"head": 1.0}, n=8, m=4)

# ------------------------------------------------------------------ tail
ft = frame_for((0, 0.25, -1.0))
K.loft([((0, 0.74, 1.36), 0.05, 0.05, ft), ((0, 0.8, 1.2), 0.07, 0.065, ft), ((0, 0.84, 0.98), 0.075, 0.06, ft),
        ((0, 0.85, 0.78), 0.04, 0.035, ft)], MANE, {"tail": 1.0}, n=8, caps=("round", "round"), cap_k=0.6)

# ------------------------------------------------------------------ legs: forearm/gaskin, knee/hock, cannon, fetlock, hoof
for s, L in ((1.0, "l"), (-1.0, "r")):
    x = 0.17 * s
    for fb, y0, y1, y2, top in (("f", -0.42, -0.44, -0.43, 1.08), ("b", 0.45, 0.56, 0.5, 1.12)):
        up, lo, ho = "upperleg_%s_%s" % (fb, L), "lowerleg_%s_%s" % (fb, L), "hoof_%s_%s" % (fb, L)
        thick = 1.3 if fb == "b" else 1.15
        K.loft([((x, y0, top), 0.1 * thick, 0.13 * thick), ((x, (y0 + y1) / 2, 0.8), 0.075 * thick, 0.09 * thick), ((x, y1, 0.58), 0.05, 0.06)],
               COAT, {up: 1.0}, n=10, caps=("flat", "flat"))
        K.ellipsoid((x, y1, 0.56), (0.055, 0.065, 0.06), COAT, {up: 0.5, lo: 0.5}, n=8, m=4)
        K.loft([((x, y1, 0.55), 0.042, 0.048), ((x, (y1 + y2) / 2, 0.32), 0.036, 0.042), ((x, y2, 0.14), 0.04, 0.046)], COAT, {lo: 1.0},
               n=8, caps=("flat", "flat"))
        K.ellipsoid((x, y2, 0.13), (0.05, 0.056, 0.05), COAT_DARK, {lo: 0.5, ho: 0.5}, n=8, m=4)
        K.loft([((x, y2 - 0.01, 0.09), 0.05, 0.052), ((x, y2 - 0.02, 0.0), 0.066, 0.072)], HOOF, {ho: 1.0}, n=10, caps=("flat", "flat"))

# ------------------------------------------------------------------ caparison: a cloth shell over the rump and over the chest


def drape(y0, y1, r_top, drop, weight_fn, front):
    """Cloth over the barrel from y0 to y1: u = around (left bottom -> over the back -> right bottom), v = along.
    The sides fall straight down to the height `drop`."""
    def f(u, v):
        y = y0 + (y1 - y0) * v
        a = u * math.radians(100.0)
        rx = r_top[0] + 0.03
        rz = r_top[1] + 0.03
        cz = 1.22 + (0.06 if front and v > 0.6 else 0.0) * (v - 0.6) / 0.4
        if abs(u) <= 0.82:
            px, pz = math.sin(a) * rx, cz + math.cos(a) * rz
        else:
            a0 = math.radians(82.0) * (1 if u > 0 else -1)
            t = (abs(u) - 0.82) / 0.18
            px = math.sin(a0) * rx + (0.07 * t * t + 0.016 * math.sin(v * math.pi * 5.0) * t) * (1 if u > 0 else -1)
            pz = cz + math.cos(a0) * rz - t * (cz + math.cos(a0) * rz - drop)
        return (px, y, pz)
    return f


def rump_w(co):
    t = smoothstep(1.0, 0.65, co.z) * 0.6
    s = 1.0 if co.x > 0 else 0.0
    return {"pelvis": 1.0 - t, "upperleg_b_l": t * s, "upperleg_b_r": t * (1.0 - s)}


def chest_w(co):
    t = smoothstep(1.0, 0.65, co.z) * 0.5
    s = 1.0 if co.x > 0 else 0.0
    return {"spine": 1.0 - t, "upperleg_f_l": t * s, "upperleg_f_r": t * (1.0 - s)}


def cap_cells(u, v):
    return NAVY if abs(u) > 0.96 else None


K.sheet(drape(0.12, 0.74, (0.29, 0.31), 0.72, rump_w, False), 18, 8, 0.016, ROLE, rump_w, cell_in=ROLE_DARK, cell_fn=cap_cells)
K.sheet(drape(-0.22, -0.66, (0.29, 0.32), 0.74, chest_w, True), 18, 6, 0.016, ROLE, chest_w, cell_in=ROLE_DARK, cell_fn=cap_cells)
# breast cloth: closes the chest drape at the front, from shoulder to shoulder, down to the forearms
def breast(u, v):
    a = u * math.radians(78.0)
    y = -0.6 - math.cos(a) * 0.17
    return (math.sin(a) * 0.34, y - 0.02 * v, 1.42 - 0.68 * v + 0.03 * math.cos(u * 6.0) * v)


K.sheet(breast, 12, 6, 0.016, ROLE, chest_w, cell_in=ROLE_DARK, cell_fn=lambda u, v: NAVY if v > 0.9 else None)


# crinet: an ochre cloth over the top of the neck, from the withers to behind the ears, with a navy hem
def crinet(u, v):
    p = N0 - nd * 0.04 + nd * (0.5 * v)
    a = u * math.radians(125.0)
    rx = 0.205 - 0.08 * v
    rz = 0.295 - 0.125 * v
    return p + Vector((math.sin(a) * rx, 0, 0)) + up_n * (math.cos(a) * rz)


K.sheet(crinet, 10, 6, 0.014, ROLE, neck_w, cell_in=ROLE_DARK, cell_fn=lambda u, v: NAVY if abs(u) > 0.88 else None)
# the order's lozenge on both sides of the rump
for s in (1.0, -1.0):
    R = Matrix.Rotation(math.radians(45.0), 3, "X")
    K.box((s * 0.335, 0.42, 0.98), (0.016, 0.2, 0.2), NAVY, rump_w, rot=R)
    K.box((s * 0.343, 0.42, 0.98), (0.016, 0.1, 0.1), GOLD, rump_w, rot=R)

# ------------------------------------------------------------------ saddle on a navy blanket, girth
K.loft([((0, 0.14, 1.22), 0.305, 0.335), ((0, -0.24, 1.24), 0.305, 0.335)], NAVY, body_w, n=16, arc=(-10.0, 190.0), thick=0.014, e=2.15,
       frame=FY)
SW_ = {"spine": 1.0}
K.loft([((0, 0.14, 1.58), 0.17, 0.05), ((0, -0.05, 1.555), 0.17, 0.04), ((0, -0.24, 1.58), 0.15, 0.05)], LEATHER, SW_, n=12, e=2.4,
       caps=("flat", "flat"), frame=FY)
K.loft([((0, 0.15, 1.58), 0.15, 0.03), ((0, 0.19, 1.67), 0.13, 0.02)], LEATHER, SW_, n=10, e=2.4, caps=("flat", "round"))      # cantle
K.loft([((0, -0.25, 1.58), 0.09, 0.03), ((0, -0.27, 1.66), 0.07, 0.025)], GOLD, SW_, n=10, e=2.4, caps=("flat", "round"))       # pommel

# ------------------------------------------------------------------ chanfron painted in the class colour with a gold crest, bridle
K.loft([(H0 + hd * 0.02, 0.1, 0.118, fh), (H0 + hd * 0.2, 0.094, 0.11, fh), (H0 + hd * 0.4, 0.078, 0.094, fh)], ROLE_PAINT, {"head": 1.0},
       n=8, arc=(35.0, 145.0), thick=0.012, e=2.1)
K.loft([(H0 + hd * 0.04, 0.012, 0.13, fh), (H0 + hd * 0.38, 0.012, 0.1, fh)], GOLD, {"head": 1.0}, n=6, arc=(80.0, 100.0), thick=0.01)
K.loft([(H0 + hd * 0.45, 0.074, 0.088, fh), (H0 + hd * 0.48, 0.074, 0.088, fh)], LEATHER_DARK, {"head": 1.0}, n=12, e=2.1,
       caps=("flat", "flat"))

RESULT = finish(ob, bm, ao_dist=0.45)
bm.free()
