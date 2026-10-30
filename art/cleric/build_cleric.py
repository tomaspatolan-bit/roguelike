# Kněz (Cleric): bitevní kněz řádu, staví se z herního rytíře SK_Knight (stejná kostra, paleta, styl).
# Spuštění v Blenderu (Knight.blend): exec(open(r"<repo>/art/cleric/build_cleric.py", encoding="utf-8").read(), {"KIT": r"<repo>/art/tools/hero_kit.py"})
# Výsledek: SK_Cleric (kolekce CLERIC_game) a zbraň SM_Cleric_Mace.
# Barvy: barva hrdiny (ROLE, u kněze slonovinová) na dlouhém šatu a plášti (ve hře je hrdina vidět hlavně zezadu),
# navy řádu (sloupce NAVY) na štóle a znaku, zlato na koruně, kříži a lemech.
import math
import bmesh
from mathutils import Vector, Euler

exec(open(KIT, encoding="utf-8").read(), globals())

ob = new_object_from("SK_Knight", "SK_Cleric", "CLERIC_game")
bm = bmesh.new()
bm.from_mesh(ob.data)
B = Builder(ob, bm)
gi = {g.name: g.index for g in ob.vertex_groups}
name_of = {v: k for k, v in gi.items()}

isl = islands(bm)
to_delete = []
for p in isl:
    bone = name_of.get(p["bone"], "")
    c, s = p["center"], p["size"]
    # pryč: pochva s mečem, chochol a jeho objímka
    if bone == "weapon_scabbard":
        to_delete += p["verts"]
    elif bone == "head" and p["cell"] == CRIMSON:
        to_delete += p["verts"]
    elif bone == "head" and p["cell"] == GOLD and p["n"] == 18 and c.z > 1.74:
        to_delete += p["verts"]
    # užší silueta: menší nárameníky
    elif bone.startswith("upperarm") and p["n"] == 74:
        side = 1 if c.x > 0 else -1
        for v in p["verts"]:
            v.co = c + (v.co - c) * 0.8 + Vector((-0.025 * side, 0, -0.01))
    # zlatý pruh na hledí (kříž s průduchy)
    elif bone == "head" and p["n"] == 8 and p["cell"] == STEEL and c.y < -0.15 and s.z > 0.2:
        B.set_cell(p["verts"], GOLD)
    # dlouhý šat (přední a zadní díl tuniky): prodloužit pod kolena, mírně rozšířit
    elif bone == "pelvis" and p["n"] == 126:
        for v in p["verts"]:
            if v.co.z < 0.66:
                t = (0.66 - v.co.z) / 0.08
                v.co.z -= 0.30
                v.co.x *= 1.14
        def robe_w(v):
            if v.co.z > 0.62:
                return {"pelvis": 1.0}
            k = min(1.0, (0.62 - v.co.z) / 0.3) * 0.55
            if abs(v.co.x) < 0.04:
                return {"pelvis": 1.0 - k, "thigh_l": k / 2, "thigh_r": k / 2}
            return {"pelvis": 1.0 - k, ("thigh_l" if v.co.x > 0 else "thigh_r"): k}
        B.set_weights(p["verts"], robe_w)
    # plášť zůstává v barvě hrdiny (ve hře je hrdina vidět hlavně zezadu); znak na hrudi v navy barvě řádu
    elif bone == "spine_02" and p["cell"] == ROLE_DARK and c.y < -0.19:
        B.set_cell(p["verts"], NAVY_DARK)
    elif bone == "spine_02" and p["cell"] == GOLD and p["n"] == 10:
        to_delete += p["verts"]   # puklice znaku, místo ní kříž
B.delete(to_delete)

# --- kříž na hrudi
W_CHEST = {"spine_02": 1.0}
B.box((0, -0.216, 1.065), (0.024, 0.008, 0.12), GOLD, W_CHEST)
B.box((0, -0.216, 1.085), (0.08, 0.008, 0.022), GOLD, W_CHEST)
B.box((0, -0.221, 1.085), (0.016, 0.006, 0.016), CRIMSON, W_CHEST)   # rubín uprostřed kříže

# --- štóla: dva navy pruhy přes šat se zlatými konci; pás leží přesně na přední ploše šatu (paprsek na šat)
from mathutils.bvhtree import BVHTree
rf = [f for f in bm.faces if f.calc_center_median().y < -0.12 and 0.2 < f.calc_center_median().z < 1.3
      and cell_of(f.loops[0][B.uvl].uv) in (ROLE, ROLE_DARK)]
rv = list({v for f in rf for v in f.verts})
ri = {v: i for i, v in enumerate(rv)}
robe_tree = BVHTree.FromPolygons([v.co.copy() for v in rv], [[ri[v] for v in f.verts] for f in rf])
def on_robe(x, z):
    hit = robe_tree.ray_cast(Vector((x, -1.0, z)), Vector((0, 1, 0)))
    return (hit[0].y if hit[0] is not None else -0.2) - 0.005
def stole_w(v):
    if v.co.z > 1.0:
        return {"spine_02": 1.0}
    if v.co.z > 0.62:
        return {"pelvis": 1.0}
    k = min(1.0, (0.62 - v.co.z) / 0.3) * 0.5
    return {"pelvis": 1.0 - k, ("thigh_l" if v.co.x > 0 else "thigh_r"): k}
def strip(xc, zs, width, depth, cell):
    rows = []
    for z in zs:
        xm = xc * (1.0 + max(0.0, 0.62 - z) * 0.45)          # šat se dole rozšiřuje, pás s ním
        y = on_robe(xm, z)
        rows.append([B.bm.verts.new((xm - width / 2, y, z)), B.bm.verts.new((xm + width / 2, y, z)),
                     B.bm.verts.new((xm + width / 2, y + depth, z)), B.bm.verts.new((xm - width / 2, y + depth, z))])
    vs = [v for r in rows for v in r]
    for r0, r1 in zip(rows, rows[1:]):
        for i in range(4):
            j = (i + 1) % 4
            B.bm.faces.new((r0[i], r0[j], r1[j], r1[i]))
    B.bm.faces.new(rows[0])
    B.bm.faces.new(list(reversed(rows[-1])))
    return B._finish(vs, cell, stole_w)
for sx in (1, -1):
    x = 0.105 * sx
    strip(x, [1.22, 1.10, 0.98, 0.86, 0.74, 0.62, 0.52, 0.42, 0.34], 0.048, 0.008, NAVY)
    strip(x, [0.345, 0.305], 0.062, 0.012, GOLD)

# --- velký navy kříž na zádech pláště (znak řádu, ve hře vidět zezadu); leží na plášti a ohýbá se s ním
cf = [f for f in bm.faces if f.calc_center_median().y > 0.15 and 0.35 < f.calc_center_median().z < 1.35
      and cell_of(f.loops[0][B.uvl].uv) in (ROLE, ROLE_DARK) and any(name_of.get(g, "").startswith("cape") for g in f.verts[0][B.dl].keys())]
cv = list({v for f in cf for v in f.verts})
ci = {v: i for i, v in enumerate(cv)}
cape_tree = BVHTree.FromPolygons([v.co.copy() for v in cv], [[ci[v] for v in f.verts] for f in cf])
def cape_point(x, z):
    hit = cape_tree.ray_cast(Vector((x, 1.0, z)), Vector((0, -1, 0)))
    if hit[0] is None:
        return None, None
    f = cf[hit[2]]
    near = min(f.verts, key=lambda v: (v.co - hit[0]).length)
    return hit[0] + Vector((0, 0.006, 0)), {name_of[g]: w for g, w in near[B.dl].items()}
def cape_bar(x0, x1, z0, z1, steps):
    rows = []
    for k in range(steps + 1):
        z = z0 + (z1 - z0) * k / steps if z1 != z0 else z0
        xa, xb = x0, x1
        pa, wa = cape_point(xa, z)
        pb, wb = cape_point(xb, z)
        if pa is None or pb is None:
            continue
        rows.append((pa, pb, wa))
    return rows
def cape_quad_strip(rows, cell):
    vs = []
    prev = None
    for pa, pb, w in rows:
        a = B.bm.verts.new(pa)
        b = B.bm.verts.new(pb)
        B.set_weights([a, b], w)
        vs += [a, b]
        if prev is not None:
            f = B.bm.faces.new((prev[0], a, b, prev[1]))
            f.normal_update()
            if f.normal.y < 0:   # líc ven ze zad pláště
                f.normal_flip()
        prev = (a, b)
    for f in {f for v in vs for f in v.link_faces}:
        for l in f.loops:
            l[B.uvl].uv = cell_uv(cell)
    return vs
# svislé rameno kříže (pás po výšce pláště) a příčné rameno
cape_quad_strip(cape_bar(-0.045, 0.045, 1.22, 0.55, 8), NAVY)
cross_rows = []
for k in range(7):
    x = -0.17 + 0.34 * k / 6
    pa, w = cape_point(x, 1.05)
    pb, _ = cape_point(x, 0.96)
    if pa is not None and pb is not None:
        cross_rows.append((pa, pb, w))
cape_quad_strip(cross_rows, NAVY)

# --- koruna na přilbě: zlaté zuby nad zlatým pruhem a kříž na temeni
W_HEAD = {"head": 1.0}
for i in range(8):
    a = 2 * math.pi * i / 8 + math.pi / 8
    r = 0.163
    pos = Vector((math.cos(a) * r, math.sin(a) * r, 1.648))
    rot = Euler((0, 0, a + math.pi / 2))
    B.box(pos, (0.034, 0.014, 0.05), GOLD, W_HEAD, rot=rot, taper=(0.25, 1.0))
B.box((0, 0, 1.80), (0.024, 0.024, 0.11), GOLD, W_HEAD)
B.box((0, 0, 1.815), (0.075, 0.022, 0.022), GOLD, W_HEAD)
B.cylinder((0, 0, 1.745), (0, 0, 1.765), 0.03, GOLD, W_HEAD, segs=8)

# --- výbava na opasku: kniha modliteb (pravý bok), medailon (levý bok)
W_HIP_R = {"pelvis": 0.75, "thigh_r": 0.25}
W_HIP_L = {"pelvis": 0.75, "thigh_l": 0.25}
B.box((-0.255, -0.03, 0.885), (0.055, 0.11, 0.13), LEATHER, W_HIP_R)
B.box((-0.257, -0.03, 0.885), (0.058, 0.02, 0.135), GOLD, W_HIP_R)
B.box((-0.25, -0.03, 0.958), (0.012, 0.02, 0.03), LEATHER, W_HIP_R)
B.box((0.25, -0.07, 0.935), (0.008, 0.008, 0.06), GOLD, W_HIP_L)
B.cylinder((0.247, -0.07, 0.875), (0.257, -0.07, 0.875), 0.034, GOLD, W_HIP_L, segs=10)
B.box((0.262, -0.07, 0.875), (0.004, 0.012, 0.04), NAVY_DARK, W_HIP_L)

bm.normal_update()
bm.to_mesh(ob.data)
bm.free()
ob.data.update()

# --- palcát (samostatný objekt; úchop v počátku, míří po +Z)
mace = new_weapon("SM_Cleric_Mace", "CLERIC_game")
mb = bmesh.new()
MB = Builder(mace, mb)
W0 = {}
MB.cylinder((0, 0, -0.10), (0, 0, 0.46), 0.018, LEATHER, W0, segs=8)          # násada s omotávkou
MB.cylinder((0, 0, -0.13), (0, 0, -0.10), 0.03, GOLD, W0, r1=0.022, segs=8)    # hlavice rukojeti
MB.cylinder((0, 0, 0.12), (0, 0, 0.46), 0.021, STEEL_DARK, W0, segs=8)       # kovová násada
MB.cylinder((0, 0, 0.44), (0, 0, 0.475), 0.036, GOLD, W0, segs=8)            # zlatý prstenec
MB.cylinder((0, 0, 0.475), (0, 0, 0.69), 0.055, STEEL, W0, r1=0.048, segs=8)  # jádro hlavice
for i in range(6):                                                            # šest břitů
    a = 2 * math.pi * i / 6
    d = Vector((math.cos(a), math.sin(a), 0))
    pts = [Vector((0, 0, 0.475)) + d * 0.04, Vector((0, 0, 0.51)) + d * 0.11,
           Vector((0, 0, 0.65)) + d * 0.11, Vector((0, 0, 0.70)) + d * 0.04]
    MB.prism(pts, 0.02, Vector((-math.sin(a), math.cos(a), 0)), STEEL, W0)
    MB.box(Vector((0, 0, 0.58)) + d * 0.111, (0.012, 0.012, 0.03), GOLD, W0, rot=Euler((0, 0, a)))   # zlaté nýty
MB.cylinder((0, 0, 0.69), (0, 0, 0.725), 0.036, GOLD, W0, r1=0.02, segs=8)    # zlatá špička
MB.box((0, 0, 0.77), (0.016, 0.016, 0.08), GOLD, W0)                         # kříž na vrcholu
MB.box((0, 0, 0.78), (0.058, 0.016, 0.016), GOLD, W0)
mb.normal_update()
mb.to_mesh(mace.data)
mb.free()

RESULT = {"tris": sum(len(p.vertices) - 2 for p in ob.data.polygons), "mace_tris": sum(len(p.vertices) - 2 for p in mace.data.polygons)}
