# Pomocné funkce pro stavbu hrdinů v Blenderu (spouští se v Blenderu přes exec, viz build_*.py).
# Hrdina = jedna síť s paletovými UV (střed buňky v řádku 0) a tuhými vahami na kosti kostry Armature.
# Paleta (art/knight/T_Knight_Palette_D.png, 16 sloupců × 8 řádků; řádek = role, viz knight_palette.gdshader):
STEEL, STEEL_DARK, GOLD, ROLE, ROLE_DARK, CRIMSON, LEATHER, CHAIN, VOID, NAVY, NAVY_DARK = range(11)

import bpy, bmesh, math
from mathutils import Vector, Matrix
from collections import Counter


def cell_uv(c):
    """UV středu buňky sloupce c v řádku 0 (shader řádek posune podle role)."""
    return Vector(((c + 0.5) / 16.0, 7.5 / 8.0))


def cell_of(uv):
    return int(uv[0] * 16)


def islands(bm):
    """Souvislé díly sítě: [{verts, center, lo, hi, bone, cell, n}]."""
    bm.verts.ensure_lookup_table()
    uvl = bm.loops.layers.uv.active
    dl = bm.verts.layers.deform.active
    seen = set()
    out = []
    for v in bm.verts:
        if v.index in seen:
            continue
        stack = [v]
        isl = []
        seen.add(v.index)
        while stack:
            a = stack.pop()
            isl.append(a)
            for e in a.link_edges:
                b = e.other_vert(a)
                if b.index not in seen:
                    seen.add(b.index)
                    stack.append(b)
        bones = Counter()
        for a in isl:
            d = a[dl]
            if d:
                bones[max(d.items(), key=lambda kv: kv[1])[0]] += 1
        cells = Counter()
        for a in isl:
            for l in a.link_loops:
                cells[cell_of(l[uvl].uv)] += 1
        lo = Vector([min(a.co[i] for a in isl) for i in range(3)])
        hi = Vector([max(a.co[i] for a in isl) for i in range(3)])
        c = Vector((0, 0, 0))
        for a in isl:
            c += a.co
        c /= len(isl)
        out.append({"verts": isl, "center": c, "lo": lo, "hi": hi, "size": hi - lo,
                    "bone": bones.most_common(1)[0][0] if bones else None,
                    "cell": cells.most_common(1)[0][0] if cells else None, "n": len(isl)})
    return out


class Builder:
    """Přidává díly do bmesh hrdiny se správnými UV a vahami."""

    def __init__(self, obj, bm):
        self.obj = obj
        self.bm = bm
        self.uvl = bm.loops.layers.uv.verify()
        self.dl = bm.verts.layers.deform.verify()

    def group(self, name):
        g = self.obj.vertex_groups.get(name)
        if g is None:
            g = self.obj.vertex_groups.new(name=name)
        return g.index

    def bone_name(self, gi):
        return self.obj.vertex_groups[gi].name

    def set_weights(self, verts, weights):
        """weights: {kost: váha} nebo funkce v -> {kost: váha}."""
        for v in verts:
            w = weights(v) if callable(weights) else weights
            d = v[self.dl]
            d.clear()
            for b, x in w.items():
                if x > 0.0:
                    d[self.group(b)] = x

    def set_cell(self, verts, cell, only_from=None):
        uv = cell_uv(cell)
        vs = set(verts)
        for f in {f for v in verts for f in v.link_faces}:
            if not all(v in vs for v in f.verts):
                continue
            for l in f.loops:
                if only_from is None or cell_of(l[self.uvl].uv) == only_from:
                    l[self.uvl].uv = uv

    def delete(self, verts):
        bmesh.ops.delete(self.bm, geom=list(set(verts)), context="VERTS")

    def _finish(self, geom_verts, cell, weights):
        faces = {f for v in geom_verts for f in v.link_faces}
        # uzavřený díl: normály ven (kontrola kvality 30.10.2026 našla obrácené pásy štóly)
        bmesh.ops.recalc_face_normals(self.bm, faces=list(faces))
        uv = cell_uv(cell)
        for f in faces:
            for l in f.loops:
                l[self.uvl].uv = uv
            f.smooth = False
        self.set_weights(geom_verts, weights)
        return geom_verts

    def box(self, center, size, cell, weights, rot=None, taper=None):
        """Kvádr. rot = Euler (rad) nebo Matrix; taper = (sx, sy) zúžení horní stěny."""
        res = bmesh.ops.create_cube(self.bm, size=1.0)
        vs = res["verts"]
        for v in vs:
            co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
            if taper is not None and v.co.z > 0:
                co.x *= taper[0]
                co.y *= taper[1]
            if rot is not None:
                m = rot if isinstance(rot, Matrix) else rot.to_matrix()
                co = m @ co
            v.co = Vector(center) + co
        return self._finish(vs, cell, weights)

    def cylinder(self, p0, p1, r0, cell, weights, r1=None, segs=8, caps=True):
        """Válec (nebo komolý kužel) z bodu p0 do p1."""
        p0, p1 = Vector(p0), Vector(p1)
        r1 = r0 if r1 is None else r1
        axis = (p1 - p0)
        q = axis.normalized().to_track_quat("Z", "Y")
        m = q.to_matrix()
        ring0, ring1 = [], []
        for i in range(segs):
            a = 2 * math.pi * i / segs
            d = m @ Vector((math.cos(a), math.sin(a), 0))
            ring0.append(self.bm.verts.new(p0 + d * r0))
            ring1.append(self.bm.verts.new(p1 + d * r1))
        for i in range(segs):
            j = (i + 1) % segs
            self.bm.faces.new((ring0[i], ring0[j], ring1[j], ring1[i]))
        if caps:
            self.bm.faces.new(list(reversed(ring0)))
            self.bm.faces.new(ring1)
        return self._finish(ring0 + ring1, cell, weights)

    def prism(self, pts, depth, normal, cell, weights):
        """Plochý hranol z obrysu pts (body v rovině) vytažený o depth po normal."""
        n = Vector(normal).normalized() * depth / 2
        front = [self.bm.verts.new(Vector(p) - n) for p in pts]
        back = [self.bm.verts.new(Vector(p) + n) for p in pts]
        k = len(pts)
        self.bm.faces.new(front)
        self.bm.faces.new(list(reversed(back)))
        for i in range(k):
            j = (i + 1) % k
            self.bm.faces.new((front[i], back[i], back[j], front[j]))
        return self._finish(front + back, cell, weights)


def new_object_from(src_name, name, collection):
    """Kopie skinned sítě (stejná kostra a modifikátor) do kolekce."""
    src = bpy.data.objects[src_name]
    old = bpy.data.objects.get(name)
    if old is not None:
        me_old = old.data
        bpy.data.objects.remove(old)
        if me_old.users == 0:
            bpy.data.meshes.remove(me_old)
    ob = src.copy()
    ob.data = src.data.copy()
    ob.name = name
    ob.data.name = name
    col = bpy.data.collections.get(collection)
    if col is None:
        col = bpy.data.collections.new(collection)
        bpy.context.scene.collection.children.link(col)
    for c in ob.users_collection:
        c.objects.unlink(ob)
    col.objects.link(ob)
    return ob


def new_weapon(name, collection):
    """Prázdná síť zbraně (vlastní objekt, úchop v počátku, zbraň míří po +Z = v Godotu po ose Y kosti ruky)."""
    old = bpy.data.objects.get(name)
    if old is not None:
        me_old = old.data
        bpy.data.objects.remove(old)
        if me_old.users == 0:
            bpy.data.meshes.remove(me_old)
    me = bpy.data.meshes.new(name)
    ob = bpy.data.objects.new(name, me)
    col = bpy.data.collections.get(collection)
    if col is None:
        col = bpy.data.collections.new(collection)
        bpy.context.scene.collection.children.link(col)
    col.objects.link(ob)
    me.uv_layers.new(name="UVMap")
    ob.data.materials.append(bpy.data.materials["M_Knight"])
    return ob
