# Shared brigand parts (15.11.2026, split out 17.11.2026): torn hems, tunic, pouch, shoulder cape, kettle hat.
# Executed by build_brigands2.py and build_commanders.py after char_kit.py and hero_body.py (uses their globals).
import math
from mathutils import Vector

HW = {"head": 1.0}
NECK = {"spine_03": 0.6, "neck_01": 0.4}


def ragged(v, u, depth=0.035, teeth=4.5):
    """Torn hem: the bottom edge goes up and down along u."""
    return depth * abs(math.sin(u * teeth * math.pi + 0.7)) * smoothstep(0.75, 1.0, v)


def tunic(K, cell, hem, top=0.95, length=0.42, flare=0.06, torn=True, inner=None):
    """Front and back panels from the waist down (split at the sides), optional torn hem, plus the hip tube."""
    for sgn in (-1.0, 1.0):
        def f(u, v, sg=sgn):
            z = top - length * v + (ragged(v, u + sg) if torn else 0.0)
            return (-sg * u * (0.14 + flare * v), sg * ((0.155 + 0.06 * v ** 0.6) - 0.02 * u * u), z)
        K.sheet(f, 8, 7, 0.014, cell, skirt_weights(top - 0.02, top - length, 0.75), cell_in=inner or hem,
                cell_fn=lambda u, v: hem if v > 0.9 else None)
    K.loft([((0, 0, top + 0.035), 0.19, 0.146), ((0, 0, top - 0.09), 0.205, 0.156), ((0, 0, top - 0.21), 0.216, 0.163)], cell,
           skirt_weights(top - 0.03, top - 0.21, 0.55), n=14, e=2.4, caps=("flat", "flat"))


def pouch(K, x, cell=LEATHER, z=0.9):
    y = -0.12 if x > 0 else -0.12
    K.ellipsoid((x, y, z), (0.05, 0.035, 0.06), cell, {"pelvis": 1.0}, n=8, m=4)
    K.box((x, y - 0.01, z + 0.045), (0.08, 0.05, 0.02), LEATHER_DARK, {"pelvis": 1.0}, bevel=0.005)


def shoulder_cape(K, cell, hem, length=0.15, torn=True):
    """A short cape around the shoulders under the hood (ragged hem)."""
    def w(co):
        return {"spine_03": 0.7, "clavicle_l": 0.15, "clavicle_r": 0.15} if co.z > 1.2 else torso_weights(co)
    z0 = 1.36
    rings = [((0, 0.0, z0), 0.15, 0.13), ((0, 0.0, z0 - 0.05), 0.25, 0.2), ((0, 0.012, z0 - 0.12), 0.31, 0.23),
             ((0, 0.02, z0 - 0.12 - length * 0.6), 0.325, 0.245)]
    K.loft(rings, cell, w, n=20, e=2.2, caps=("flat", "flat"))
    if torn:   # tatters hanging from the hem
        for k in range(10):
            a = 2 * math.pi * (k + 0.5) / 10
            p = Vector((math.cos(a) * 0.31, math.sin(a) * 0.235 + 0.02, z0 - 0.12 - length * 0.6))
            fr = frame_for((0, 0, -1))
            K.loft([(p, 0.07, 0.014, fr), (p + Vector((0, 0, -0.04 - 0.015 * (k % 3))), 0.03, 0.01, fr)], hem, w, n=6,
                   caps=("flat", "flat"))


def kettle_hat(K, dome=STEEL, brim=STEEL_DARK, z=1.62, r=(0.255, 0.27)):
    """Iron kettle hat: dome and a wide flat brim (the brigand's sign from above)."""
    K.ellipsoid((0, 0.005, z), (0.128, 0.142, 0.13), dome, HW, n=16, m=6, z_range=(0.0, 1.0))
    K.loft([((0, 0.005, z - 0.012), r[0], r[1]), ((0, 0.005, z + 0.006), r[0] * 0.97, r[1] * 0.97)], brim, HW, n=20, e=2.0,
           caps=("flat", "flat"))
    K.loft([((0, 0.005, z - 0.004), 0.132, 0.146), ((0, 0.005, z + 0.03), 0.13, 0.144)], LEATHER_DARK, HW, n=16, caps=("flat", "flat"))
    K.ellipsoid((0, 0.005, z + 0.13), (0.02, 0.02, 0.015), brim, HW, n=8, m=3)
