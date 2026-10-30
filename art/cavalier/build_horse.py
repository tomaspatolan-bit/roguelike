# Válečný kůň jezdce: vlastní kostra Armature_Horse a síť SK_Horse (paleta jako hrdinové, tuhé váhy).
# Spuštění v Blenderu (Knight.blend): exec(open(r"<repo>/art/cavalier/build_horse.py", encoding="utf-8").read(), {"KIT": r"<repo>/art/tools/hero_kit.py"})
# Kůň kouká po −Y (jako rytíř), levá strana = +X, kopyta v z = 0, kohoutek ~1,55 m, délka trupu ~2,3 m.
# Výbava: čabraka v barvě jezdce (sloupce 3–4, řádek role) s navy lemem a kosočtvercem řádu, ocelová maska
# se zlatým hřebenem, kožené sedlo na navy podsedlové dece. Srst sloupec 11, hříva, ocas a kopyta sloupec 12.
# Kost `saddle` (nedeformuje) je místo, kam hra posadí jezdce (BoneAttachment3D).
import math
import bpy
import bmesh
from mathutils import Vector, Euler

exec(open(KIT, encoding="utf-8").read(), globals())
COAT, MANE = 11, 12
COL = "HORSE_game"

# --- kostra
BONES = [
    # jméno, hlava, ocas, rodič, deformuje
    ("root", (0, 0, 0), (0, 0.3, 0), None, False),
    ("pelvis", (0, 0.45, 1.2), (0, 0.1, 1.22), "root", True),
    ("spine", (0, 0.1, 1.22), (0, -0.4, 1.28), "pelvis", True),
    ("saddle", (0, -0.05, 1.5), (0, -0.05, 1.7), "spine", False),
    ("neck", (0, -0.45, 1.36), (0, -0.78, 1.78), "spine", True),
    ("head", (0, -0.78, 1.78), (0, -1.1, 1.45), "neck", True),
    ("tail", (0, 0.62, 1.34), (0, 0.8, 0.85), "pelvis", True),
]
for sfx, s in (("l", 1), ("r", -1)):
    x = 0.17 * s
    BONES += [
        ("upperleg_f_" + sfx, (x, -0.42, 1.05), (x, -0.44, 0.55), "spine", True),
        ("lowerleg_f_" + sfx, (x, -0.44, 0.55), (x, -0.43, 0.1), "upperleg_f_" + sfx, True),
        ("hoof_f_" + sfx, (x, -0.43, 0.1), (x, -0.47, 0.0), "lowerleg_f_" + sfx, True),
        ("upperleg_b_" + sfx, (x, 0.45, 1.1), (x, 0.56, 0.6), "pelvis", True),
        ("lowerleg_b_" + sfx, (x, 0.56, 0.6), (x, 0.5, 0.1), "upperleg_b_" + sfx, True),
        ("hoof_b_" + sfx, (x, 0.5, 0.1), (x, 0.46, 0.0), "lowerleg_b_" + sfx, True),
    ]

col = bpy.data.collections.get(COL)
if col is None:
    col = bpy.data.collections.new(COL)
    bpy.context.scene.collection.children.link(col)
for n in ("SK_Horse", "Armature_Horse"):
    o = bpy.data.objects.get(n)
    if o is not None:
        d = o.data
        bpy.data.objects.remove(o)
        if d is not None and d.users == 0:
            (bpy.data.meshes if n == "SK_Horse" else bpy.data.armatures).remove(d)

ad = bpy.data.armatures.new("Armature_Horse")
arm = bpy.data.objects.new("Armature_Horse", ad)
col.objects.link(arm)
prev_active = bpy.context.view_layer.objects.active
for o in bpy.context.view_layer.objects:
    o.select_set(False)
arm.select_set(True)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="EDIT")
eb = ad.edit_bones
for name, h, t, parent, deform in BONES:
    b = eb.new(name)
    b.head = h
    b.tail = t
    b.roll = 0.0
    b.use_deform = deform
    if parent:
        b.parent = eb[parent]
        b.use_connect = False
bpy.ops.object.mode_set(mode="OBJECT")

# --- síť
me = bpy.data.meshes.new("SK_Horse")
ob = bpy.data.objects.new("SK_Horse", me)
col.objects.link(ob)
me.uv_layers.new(name="UVMap")
me.materials.append(bpy.data.materials["M_Knight"])
ob.parent = arm
mod = ob.modifiers.new("Armature", "ARMATURE")
mod.object = arm

bm = bmesh.new()
B = Builder(ob, bm)


def body_w(v):
    """Trup: vzadu pánev, vpředu páteř, mezi nimi plynule."""
    k = min(1.0, max(0.0, (v.co.y - (-0.05)) / 0.35))
    return {"pelvis": k, "spine": 1.0 - k}


# trup, záď, hruď
B.cylinder((0, 0.55, 1.2), (0, -0.5, 1.24), 0.3, COAT, body_w, segs=12)
B.cylinder((0, 0.66, 1.21), (0, 0.42, 1.22), 0.29, COAT, {"pelvis": 1.0}, r1=0.3, segs=12)
B.cylinder((0, -0.42, 1.23), (0, -0.62, 1.32), 0.29, COAT, {"spine": 1.0}, r1=0.24, segs=12)
# krk, hlava, uši, hříva
B.cylinder((0, -0.45, 1.36), (0, -0.8, 1.8), 0.21, COAT, {"neck": 1.0}, r1=0.13, segs=10)
B.cylinder((0, -0.76, 1.83), (0, -1.12, 1.46), 0.125, COAT, {"head": 1.0}, r1=0.075, segs=10)
for s in (1, -1):
    B.box((0.06 * s, -0.78, 1.95), (0.035, 0.03, 0.1), COAT, {"head": 1.0}, rot=Euler((0.3, 0.25 * s, 0)), taper=(0.4, 0.5))
    B.box((0.075 * s, -0.95, 1.69), (0.02, 0.04, 0.03), VOID, {"head": 1.0})   # oko
neck_dir = (Vector((0, -0.8, 1.8)) - Vector((0, -0.45, 1.36))).normalized()
neck_rot = neck_dir.to_track_quat("Z", "Y").to_euler()
neck_up = Vector((0, -neck_dir.z, neck_dir.y)) if neck_dir.y > 0 else Vector((0, neck_dir.z, -neck_dir.y))
B.box(Vector((0, -0.45, 1.36)) + neck_dir * 0.32 + neck_up * 0.16, (0.05, 0.07, 0.5), MANE, {"neck": 1.0}, rot=neck_rot)
B.box((0, -0.82, 1.94), (0.05, 0.1, 0.06), MANE, {"head": 1.0})            # čupřina
# ocas
B.cylinder((0, 0.62, 1.34), (0, 0.8, 0.85), 0.065, MANE, {"tail": 1.0}, r1=0.035, segs=6)

# nohy: stehno/předloktí, holeň, kopyto (tuhé)
for sfx, s in (("l", 1), ("r", -1)):
    x = 0.17 * s
    for fb, y0, y1, y2 in (("f", -0.42, -0.44, -0.43), ("b", 0.45, 0.56, 0.5)):
        B.cylinder((x, y0, 1.08), (x, y1, 0.55), 0.09, COAT, {"upperleg_%s_%s" % (fb, sfx): 1.0}, r1=0.06, segs=8)
        B.cylinder((x, y1, 0.57), (x, y2, 0.1), 0.05, COAT, {"lowerleg_%s_%s" % (fb, sfx): 1.0}, r1=0.045, segs=8)
        B.cylinder((x, y2, 0.11), (x, y2 - 0.02, 0.0), 0.06, MANE, {"hoof_%s_%s" % (fb, sfx): 1.0}, r1=0.07, segs=8)

# --- čabraka (barva jezdce): pokrývka přes záď a přes hruď, sukně po bocích s navy lemem, kosočtverec řádu.
# Pod sedlem mezera (tam je vidět srst a noha jezdce).
B.cylinder((0, 0.71, 1.22), (0, 0.11, 1.22), 0.345, ROLE, body_w, segs=14)
B.cylinder((0, -0.19, 1.24), (0, -0.67, 1.27), 0.335, ROLE, {"spine": 1.0}, r1=0.3, segs=14)
for s in (1, -1):
    x = 0.34 * s
    for (y0, y1), wts in (((0.71, 0.12), body_w), ((-0.2, -0.64), {"spine": 1.0})):
        zt = 1.22
        B.prism([(x, y0, zt), (x, y1, zt), (x, y1, 0.86), (x, y0, 0.86)], 0.03, (1, 0, 0), ROLE, wts)
        B.prism([(x * 1.02, y0 + 0.01 * (1 if y0 > y1 else -1), 0.87), (x * 1.02, y1 - 0.01 * (1 if y0 > y1 else -1), 0.87),
                 (x * 1.02, y1 - 0.01 * (1 if y0 > y1 else -1), 0.81), (x * 1.02, y0 + 0.01 * (1 if y0 > y1 else -1), 0.81)],
                0.03, (1, 0, 0), NAVY, wts)
    B.box((0.36 * s, 0.42, 1.04), (0.012, 0.24, 0.24), NAVY, {"pelvis": 1.0}, rot=Euler((math.pi / 4, 0, 0)))
    B.box((0.367 * s, 0.42, 1.04), (0.012, 0.13, 0.13), GOLD, {"pelvis": 1.0}, rot=Euler((math.pi / 4, 0, 0)))
B.box((0, -0.64, 0.98), (0.56, 0.03, 0.3), ROLE, {"spine": 1.0})          # náprsník
B.box((0, -0.645, 0.84), (0.57, 0.035, 0.06), NAVY, {"spine": 1.0})
B.box((0, 0.7, 1.0), (0.6, 0.03, 0.34), ROLE, {"pelvis": 1.0})           # zadní díl
B.box((0, 0.705, 0.84), (0.61, 0.035, 0.06), NAVY, {"pelvis": 1.0})
# sedlo na navy dece
B.cylinder((0, 0.12, 1.22), (0, -0.2, 1.24), 0.325, NAVY, body_w, segs=14)          # deka a podbřišník
B.box((0, -0.05, 1.58), (0.34, 0.42, 0.07), LEATHER, {"spine": 1.0})
B.box((0, 0.14, 1.65), (0.3, 0.05, 0.13), LEATHER, {"spine": 1.0})
B.box((0, -0.25, 1.64), (0.16, 0.05, 0.11), GOLD, {"spine": 1.0})
# ocelová maska (chanfron) se zlatým hřebenem
head_d = (Vector((0, -1.12, 1.46)) - Vector((0, -0.76, 1.83))).normalized()
up_n = Vector((0, head_d.z, -head_d.y))
if up_n.z < 0:
    up_n = -up_n
mid = (Vector((0, -0.76, 1.83)) + Vector((0, -1.12, 1.46))) / 2
rot = head_d.to_track_quat("Z", "Y").to_matrix()
B.box(mid + up_n * 0.095 + head_d * 0.03, (0.17, 0.02, 0.4), STEEL, {"head": 1.0}, rot=rot)
B.box(mid + up_n * 0.108 + head_d * 0.03, (0.03, 0.02, 0.4), GOLD, {"head": 1.0}, rot=rot)

bm.normal_update()
bm.to_mesh(me)
bm.free()
me.update()

bpy.context.view_layer.objects.active = prev_active
RESULT = {"tris": sum(len(p.vertices) - 2 for p in me.polygons), "bones": len(ad.bones),
          "unweighted": sum(1 for v in me.vertices if not v.groups)}
