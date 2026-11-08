# The cavalier's warhorse: own skeleton Armature_Horse and mesh SK_Horse (palette like the heroes, rigid weights;
# the caparison skirt has soft weights to the upper legs since the style pilot 2.0s).
# Run in Blender (Knight.blend): exec(open(r"<repo>/art/cavalier/build_horse.py", encoding="utf-8").read(), {"KIT": r"<repo>/art/tools/hero_kit.py"})
# The horse faces −Y (like the knight), left side = +X, hooves at z = 0, withers ~1.55 m, body length ~2.3 m.
# Barding: caparison in the cavalier's colour (columns 3–4, role row) with navy trim and the order's lozenge, steel chanfron
# with a gold crest, leather saddle on a navy saddle blanket. Coat column 11, mane, tail and hooves column 12.
# The `saddle` bone (non-deforming) is where the game seats the rider (BoneAttachment3D).
import math
import bpy
import bmesh
from mathutils import Vector, Euler

exec(open(KIT, encoding="utf-8").read(), globals())
COAT, MANE = 11, 12
COL = "HORSE_game"

# --- kostra
BONES = [
    # name, head, tail, parent, deforms
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

# --- mesh
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
    """Body: pelvis at the back, spine at the front, smoothly in between."""
    k = min(1.0, max(0.0, (v.co.y - (-0.05)) / 0.35))
    return {"pelvis": k, "spine": 1.0 - k}


# body, rump, chest
B.cylinder((0, 0.55, 1.2), (0, -0.5, 1.24), 0.3, COAT, body_w, segs=12)
B.cylinder((0, 0.66, 1.21), (0, 0.42, 1.22), 0.29, COAT, {"pelvis": 1.0}, r1=0.3, segs=12)
B.cylinder((0, -0.42, 1.23), (0, -0.62, 1.32), 0.29, COAT, {"spine": 1.0}, r1=0.24, segs=12)
# neck, head, ears, mane
B.cylinder((0, -0.45, 1.36), (0, -0.8, 1.8), 0.21, COAT, {"neck": 1.0}, r1=0.13, segs=10)
B.cylinder((0, -0.76, 1.83), (0, -1.12, 1.46), 0.125, COAT, {"head": 1.0}, r1=0.075, segs=10)
for s in (1, -1):
    B.box((0.06 * s, -0.78, 1.95), (0.035, 0.03, 0.1), COAT, {"head": 1.0}, rot=Euler((0.3, 0.25 * s, 0)), taper=(0.4, 0.5))
    B.box((0.075 * s, -0.95, 1.69), (0.02, 0.04, 0.03), VOID, {"head": 1.0})   # oko
neck_dir = (Vector((0, -0.8, 1.8)) - Vector((0, -0.45, 1.36))).normalized()
neck_rot = neck_dir.to_track_quat("Z", "Y").to_euler()
neck_up = Vector((0, -neck_dir.z, neck_dir.y)) if neck_dir.y > 0 else Vector((0, neck_dir.z, -neck_dir.y))
B.box(Vector((0, -0.45, 1.36)) + neck_dir * 0.32 + neck_up * 0.16, (0.05, 0.07, 0.5), MANE, {"neck": 1.0}, rot=neck_rot)
B.box((0, -0.82, 1.94), (0.05, 0.1, 0.06), MANE, {"head": 1.0})            # forelock
# ocas
B.cylinder((0, 0.62, 1.34), (0, 0.8, 0.85), 0.065, MANE, {"tail": 1.0}, r1=0.035, segs=6)

# legs: thigh/forearm, cannon, hoof (rigid)
for sfx, s in (("l", 1), ("r", -1)):
    x = 0.17 * s
    for fb, y0, y1, y2 in (("f", -0.42, -0.44, -0.43), ("b", 0.45, 0.56, 0.5)):
        B.cylinder((x, y0, 1.08), (x, y1, 0.55), 0.09, COAT, {"upperleg_%s_%s" % (fb, sfx): 1.0}, r1=0.06, segs=8)
        B.cylinder((x, y1, 0.57), (x, y2, 0.1), 0.05, COAT, {"lowerleg_%s_%s" % (fb, sfx): 1.0}, r1=0.045, segs=8)
        B.cylinder((x, y2, 0.11), (x, y2 - 0.02, 0.0), 0.06, MANE, {"hoof_%s_%s" % (fb, sfx): 1.0}, r1=0.07, segs=8)

# --- caparison (cavalier colour), smooth since the style pilot 2.0s (08.11.2026): a cover over the rump and the chest
# and a draped skirt around each of them (one continuous cloth shell, smooth shading, navy hem; the cover stays inside
# the skirt so the two never cut through each other). The skirt's lower part
# follows the upper legs (soft weights), so it sways with the stride instead of moving like a board.
# A gap under the saddle (the coat and the rider's leg show there). The order's lozenge on the rear skirt.
B.cylinder((0, 0.7, 1.22), (0, 0.11, 1.22), 0.33, ROLE, body_w, segs=20)
B.cylinder((0, -0.19, 1.24), (0, -0.66, 1.27), 0.32, ROLE, {"spine": 1.0}, r1=0.285, segs=20)


SKIRT_EDGES = set()   # hem and cut ends of the skirts (stay flat-shaded)


def skirt_path(y_side, y_mid, rx, ry, back):
    """Hem outline seen from above: straight along the side, a half-ellipse around the rump (back) or the chest."""
    s = 1.0 if back else -1.0
    pts = [(rx, y_side + (y_mid - y_side) * k / 3.0) for k in range(3)]
    for k in range(13):
        a = math.pi * k / 12.0
        pts.append((rx * math.cos(a), y_mid + s * ry * math.sin(a)))
    pts += [(-rx, y_mid + (y_side - y_mid) * k / 3.0) for k in range(1, 4)]
    return pts


def skirt(path, y_mid, rows, body, legs, cell_band):
    """Cloth shell: outer and inner surface along `path`, rows = [(z, cell, radial scale)] from the top to the hem
    (the top rows lie on the upper flank, so the skirt continues the cover round over the body)."""
    z_top, z_bot = rows[0][0], rows[-1][0]
    outer, inner = [], []
    for z, _c, flare in rows:
        ro, ri = [], []
        for (x, y) in path:
            d = Vector((x, y - y_mid, 0.0))
            p = Vector((0.0, y_mid, z)) + d * flare
            n = d.normalized() if d.length > 1e-6 else Vector((1.0, 0.0, 0.0))
            ro.append(bm.verts.new(p))
            ri.append(bm.verts.new(p - n * 0.022))
        outer.append(ro)
        inner.append(ri)
    faces = []
    edge_set = set()
    m = len(path)
    for r in range(len(rows) - 1):
        cell = rows[r + 1][1]
        for i in range(m - 1):
            faces.append((bm.faces.new((outer[r][i], outer[r + 1][i], outer[r + 1][i + 1], outer[r][i + 1])), cell))
            faces.append((bm.faces.new((inner[r][i + 1], inner[r + 1][i + 1], inner[r + 1][i], inner[r][i])), cell))
        for fe in (bm.faces.new((outer[r][0], inner[r][0], inner[r + 1][0], outer[r + 1][0])),
                   bm.faces.new((outer[r + 1][m - 1], inner[r + 1][m - 1], inner[r][m - 1], outer[r][m - 1]))):
            faces.append((fe, cell))
            edge_set.add(fe)
    for i in range(m - 1):
        fe = bm.faces.new((outer[-1][i], inner[-1][i], inner[-1][i + 1], outer[-1][i + 1]))
        faces.append((fe, cell_band))
        edge_set.add(fe)
    # outer normals point away from the body (flip the whole shell if the winding came out inwards)
    f0 = faces[0][0]
    f0.normal_update()
    probe = f0.calc_center_median() - Vector((0.0, y_mid, f0.calc_center_median().z))
    if f0.normal.dot(probe) < 0.0:
        bmesh.ops.reverse_faces(bm, faces=[f for f, _c in faces])
    edge_faces = edge_set
    SKIRT_EDGES.update(edge_set)
    for f, cell in faces:
        f.smooth = f not in edge_faces   # hem and the cut ends stay flat, so they do not bend the cloth's shading
        for l in f.loops:
            l[B.uvl].uv = cell_uv(cell)
    for ring_o, ring_i in zip(outer, inner):
        for v in ring_o + ring_i:
            t = min(1.0, max(0.0, (1.22 - v.co.z) / (1.22 - z_bot)))   # the legs pull only below the flank
            side = min(1.0, abs(v.co.x) / 0.3)
            w = 0.45 * (t ** 1.5) * (0.5 + 0.5 * side)
            share_l = min(1.0, max(0.0, 0.5 + v.co.x / 0.5))
            wts = {k: x * (1.0 - w) for k, x in (body(v) if callable(body) else body).items()}
            wts[legs[0]] = w * share_l
            wts[legs[1]] = w * (1.0 - share_l)
            B.set_weights([v], wts)


ROWS = [(1.4, ROLE, 0.86), (1.31, ROLE, 0.96), (1.21, ROLE, 1.02), (1.08, ROLE, 1.04), (0.96, ROLE, 1.06),
        (0.87, ROLE, 1.08), (0.81, NAVY, 1.09)]
skirt(skirt_path(0.1, 0.42, 0.352, 0.33, True), 0.42, ROWS, body_w, ("upperleg_b_l", "upperleg_b_r"), NAVY)
skirt(skirt_path(-0.18, -0.4, 0.342, 0.33, False), -0.4, ROWS, {"spine": 1.0}, ("upperleg_f_l", "upperleg_f_r"), NAVY)
for s in (1, -1):
    B.box((0.39 * s, 0.3, 1.03), (0.012, 0.22, 0.22), NAVY, {"pelvis": 1.0}, rot=Euler((math.pi / 4, 0, 0)))
    B.box((0.397 * s, 0.3, 1.03), (0.012, 0.12, 0.12), GOLD, {"pelvis": 1.0}, rot=Euler((math.pi / 4, 0, 0)))
# saddle on a navy blanket
B.cylinder((0, 0.12, 1.22), (0, -0.2, 1.24), 0.325, NAVY, body_w, segs=14)          # blanket and girth
B.box((0, -0.05, 1.58), (0.34, 0.42, 0.07), LEATHER, {"spine": 1.0})
B.box((0, 0.14, 1.65), (0.3, 0.05, 0.13), LEATHER, {"spine": 1.0})
B.box((0, -0.25, 1.64), (0.16, 0.05, 0.11), GOLD, {"spine": 1.0})
# steel mask (chanfron) with a gold crest
head_d = (Vector((0, -1.12, 1.46)) - Vector((0, -0.76, 1.83))).normalized()
up_n = Vector((0, head_d.z, -head_d.y))
if up_n.z < 0:
    up_n = -up_n
mid = (Vector((0, -0.76, 1.83)) + Vector((0, -1.12, 1.46))) / 2
rot = head_d.to_track_quat("Z", "Y").to_matrix()
B.box(mid + up_n * 0.095 + head_d * 0.03, (0.17, 0.02, 0.4), STEEL, {"head": 1.0}, rot=rot)
B.box(mid + up_n * 0.108 + head_d * 0.03, (0.03, 0.02, 0.4), GOLD, {"head": 1.0}, rot=rot)

# smooth shading on the round parts (coat, caparison, blanket); mane, hooves and metal stay faceted
uvl_s = bm.loops.layers.uv.active
for f in bm.faces:
    if cell_of(f.loops[0][uvl_s].uv) in (COAT, ROLE, NAVY) and f not in SKIRT_EDGES:
        f.smooth = True
bm.normal_update()
bm.to_mesh(me)
bm.free()
me.update()

bpy.context.view_layer.objects.active = prev_active
RESULT = {"tris": sum(len(p.vertices) - 2 for p in me.polygons), "bones": len(ad.bones),
          "unweighted": sum(1 for v in me.vertices if not v.groups)}
