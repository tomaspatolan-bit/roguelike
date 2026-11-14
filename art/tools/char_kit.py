# Character kit 2 (visual prototype, phase 2, 14.11.2026): builds a hero from smooth parts instead of boxes.
# Run in Blender via exec (see art/tank/build_tank.py). Needs Knight.blend (the Armature skeleton, UE5 bone names).
# A hero = one mesh, palette v2 UVs (cell centre in row 0, art/chars/T_Char_Palette_*.png, 32 columns x 16 rows),
# weights to the skeleton, baked occlusion in the vertex colours (the character shader multiplies the colour by it).
# Parts:
#   loft(rings, ...)      tube through cross-sections (super-ellipses): limbs, torso, helmet; arc = a plate (part of the tube)
#   ellipsoid(...)        pauldrons, knees, fists
#   sheet(fn, ...)        cloth with thickness from a function (u, v) -> point: cloak, surcoat, shield
#   box(...)              bevelled box: buckles, guards
# Coordinates as in Knight.blend: 1 = 1 m, the character faces -Y, its left side is +X, feet at z = 0.
import math
import bmesh
import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

PAL_COLS = 32
PAL_ROWS = 16
(STEEL, STEEL_DARK, STEEL_LIGHT, GOLD, GOLD_DARK, ROLE, ROLE_DARK, ROLE_LIGHT, ROLE_PAINT, LEATHER, LEATHER_DARK,
 WOOD, MAIL, VOID, LINEN, SKIN, CRIMSON, NAVY, IVORY, HAIR) = range(20)


def cell_uv(c):
    return Vector(((c + 0.5) / PAL_COLS, 1.0 - 0.5 / PAL_ROWS))


def smoothstep(a, b, x):
    if a == b:
        return 0.0 if x < a else 1.0
    t = min(1.0, max(0.0, (x - a) / (b - a)))
    return t * t * (3.0 - 2.0 * t)


def frame_for(direction, ref=(1.0, 0.0, 0.0)):
    """Ring frame for a tube going along direction: columns = ring x axis, ring y axis, tangent."""
    z = Vector(direction).normalized()
    x = Vector(ref) - z * Vector(ref).dot(z)
    if x.length < 1e-5:
        x = Vector((0.0, 1.0, 0.0)) - z * z.y
    x.normalize()
    y = z.cross(x)
    return Matrix((x, y, z)).transposed()


def _super(a, e):
    c, s = math.cos(a), math.sin(a)
    p = 2.0 / e
    return math.copysign(abs(c) ** p, c), math.copysign(abs(s) ** p, s)


class Kit:
    def __init__(self, obj, bm):
        self.obj = obj
        self.bm = bm
        self.uvl = bm.loops.layers.uv.verify()
        self.dl = bm.verts.layers.deform.verify()

    # ---------------------------------------------------------------- basics
    def group(self, name):
        g = self.obj.vertex_groups.get(name)
        if g is None:
            g = self.obj.vertex_groups.new(name=name)
        return g.index

    def weigh(self, verts, weights):
        """weights: {bone: w} or a function(co) -> {bone: w}; normalised."""
        for v in verts:
            w = weights(v.co) if callable(weights) else weights
            tot = sum(x for x in w.values() if x > 0.0)
            d = v[self.dl]
            d.clear()
            for b, x in w.items():
                if x > 1e-4:
                    d[self.group(b)] = x / tot

    def paint(self, faces, cell):
        uv = cell_uv(cell)
        for f in faces:
            for l in f.loops:
                l[self.uvl].uv = uv

    def _done(self, verts, faces, cell, weights, smooth=True):
        bmesh.ops.recalc_face_normals(self.bm, faces=faces)
        self.paint(faces, cell)
        for f in faces:
            f.smooth = smooth
        self.weigh(verts, weights)
        return {"verts": verts, "faces": faces}

    # ---------------------------------------------------------------- loft
    def loft(self, rings, cell, weights, n=12, e=2.0, caps=("round", "round"), cap_k=0.6, arc=None, thick=0.012,
             frame=None, origin=None):
        """Tube through rings [(p, rx, ry) or (p, rx, ry, frame)]. The frame of a ring defaults to `frame`, otherwise
        it follows the path (ring x axis = world X where it can). arc = (a0, a1) in degrees makes a plate of that
        part of the tube with thickness `thick` (angle 0 = ring x axis, 90 = ring y axis).
        origin + frame: the rings are given in that local frame (rotated parts, e.g. a pauldron rim)."""
        pts = [Vector(r[0]) for r in rings]
        if origin is not None:
            pts = [Vector(origin) + frame @ p for p in pts]
        frames = []
        for i, r in enumerate(rings):
            if len(r) > 3 and r[3] is not None:
                frames.append(r[3])
            elif origin is not None:
                frames.append(frame)
            elif frame is not None:
                frames.append(frame)
            else:
                a = pts[max(i - 1, 0)]
                b = pts[min(i + 1, len(pts) - 1)]
                frames.append(frame_for(b - a))
        full = arc is None
        if full:
            angs = [2.0 * math.pi * k / n for k in range(n)]
        else:
            a0, a1 = math.radians(arc[0]), math.radians(arc[1])
            angs = [a0 + (a1 - a0) * k / n for k in range(n + 1)]

        def make_ring(i, shrink=0.0, scale=1.0, shift=Vector((0, 0, 0))):
            out = []
            rx = max(rings[i][1] * scale - shrink, 0.002)
            ry = max(rings[i][2] * scale - shrink, 0.002)
            for a in angs:
                cx, sy = _super(a, e)
                out.append(self.bm.verts.new(pts[i] + shift + frames[i] @ Vector((cx * rx, sy * ry, 0.0))))
            return out

        verts, faces = [], []
        outer = [make_ring(i) for i in range(len(rings))]
        for r in outer:
            verts += r
        m = len(angs)
        span = m if full else m - 1
        for i in range(len(outer) - 1):
            for k in range(span):
                j = (k + 1) % m
                faces.append(self.bm.faces.new((outer[i][k], outer[i][j], outer[i + 1][j], outer[i + 1][k])))
        if full:
            for end, kind in ((0, caps[0]), (len(rings) - 1, caps[1])):
                sign = -1.0 if end == 0 else 1.0
                tangent = frames[end] @ Vector((0.0, 0.0, 1.0)) * sign
                last = outer[end]
                if kind == "round":
                    h = cap_k * min(rings[end][1], rings[end][2])
                    for sc, off in ((0.8, 0.5), (0.45, 0.88)):
                        nxt = make_ring(end, scale=sc, shift=tangent * h * off)
                        verts += nxt
                        for k in range(m):
                            j = (k + 1) % m
                            faces.append(self.bm.faces.new((last[k], last[j], nxt[j], nxt[k])))
                        last = nxt
                    c = self.bm.verts.new(pts[end] + tangent * h)
                    verts.append(c)
                    for k in range(m):
                        faces.append(self.bm.faces.new((last[k], last[(k + 1) % m], c)))
                elif kind == "flat":
                    faces.append(self.bm.faces.new(last))
        else:
            inner = [make_ring(i, shrink=thick) for i in range(len(rings))]
            for r in inner:
                verts += r
            for i in range(len(inner) - 1):
                for k in range(span):
                    faces.append(self.bm.faces.new((inner[i][k + 1], inner[i][k], inner[i + 1][k], inner[i + 1][k + 1])))
            for i in range(len(outer) - 1):   # the two straight edges
                faces.append(self.bm.faces.new((outer[i][0], outer[i + 1][0], inner[i + 1][0], inner[i][0])))
                faces.append(self.bm.faces.new((outer[i][-1], inner[i][-1], inner[i + 1][-1], outer[i + 1][-1])))
            for i in (0, len(outer) - 1):     # the two curved edges
                for k in range(span):
                    faces.append(self.bm.faces.new((outer[i][k], inner[i][k], inner[i][k + 1], outer[i][k + 1])))
        return self._done(verts, faces, cell, weights)

    # ---------------------------------------------------------------- ellipsoid
    def ellipsoid(self, center, radii, cell, weights, n=12, m=6, frame=None, z_range=(-1.0, 1.0)):
        """Ellipsoid (radii along the frame axes). z_range cuts it between two heights (-1..1), flat cut faces."""
        fr = frame if frame is not None else Matrix.Identity(3)
        c = Vector(center)
        lat0 = math.asin(max(-1.0, z_range[0]))
        lat1 = math.asin(min(1.0, z_range[1]))
        rows = []
        verts, faces = [], []
        for i in range(m + 1):
            lat = lat0 + (lat1 - lat0) * i / m
            cz, r = math.sin(lat), math.cos(lat)
            if r < 1e-4:
                v = self.bm.verts.new(c + fr @ Vector((0.0, 0.0, cz * radii[2])))
                rows.append([v])
                verts.append(v)
            else:
                row = []
                for k in range(n):
                    a = 2.0 * math.pi * k / n
                    row.append(self.bm.verts.new(c + fr @ Vector((math.cos(a) * r * radii[0], math.sin(a) * r * radii[1], cz * radii[2]))))
                rows.append(row)
                verts += row
        for i in range(m):
            a, b = rows[i], rows[i + 1]
            for k in range(n):
                j = (k + 1) % n
                if len(a) == 1 and len(b) == 1:
                    continue
                if len(a) == 1:
                    faces.append(self.bm.faces.new((a[0], b[j], b[k])))
                elif len(b) == 1:
                    faces.append(self.bm.faces.new((a[k], a[j], b[0])))
                else:
                    faces.append(self.bm.faces.new((a[k], a[j], b[j], b[k])))
        if len(rows[0]) > 1:
            faces.append(self.bm.faces.new(rows[0]))
        if len(rows[-1]) > 1:
            faces.append(self.bm.faces.new(rows[-1]))
        return self._done(verts, faces, cell, weights)

    # ---------------------------------------------------------------- sheet
    def sheet(self, fn, nu, nv, thick, cell_out, weights, cell_in=None, cell_fn=None, shape=None):
        """Cloth or plate with thickness: fn(u, v) -> point of the outer face, u in -1..1, v in 0..1.
        The inner face is offset against the outer normal. cell_fn(u, v) -> cell overrides cell_out per face
        (u, v = face centre). The outer normal follows from the order of u and v: n = du x dv."""
        def grid(offset):
            g = []
            for j in range(nv + 1):
                row = []
                for i in range(nu + 1):
                    u = -1.0 + 2.0 * i / nu
                    v = j / nv
                    p = Vector(fn(u, v))
                    if offset != 0.0:
                        du = Vector(fn(min(u + 0.01, 1.0), v)) - Vector(fn(max(u - 0.01, -1.0), v))
                        dv = Vector(fn(u, min(v + 0.01, 1.0))) - Vector(fn(u, max(v - 0.01, 0.0)))
                        nrm = du.cross(dv)
                        if nrm.length > 1e-9:
                            p -= nrm.normalized() * offset
                    row.append(self.bm.verts.new(p))
                g.append(row)
            return g
        out = grid(0.0)
        inn = grid(thick)
        verts = [v for row in out for v in row] + [v for row in inn for v in row]
        f_out, f_in, f_edge = [], [], []
        for j in range(nv):
            for i in range(nu):
                f = self.bm.faces.new((out[j][i], out[j][i + 1], out[j + 1][i + 1], out[j + 1][i]))
                f_out.append((f, -1.0 + 2.0 * (i + 0.5) / nu, (j + 0.5) / nv))
                f_in.append(self.bm.faces.new((inn[j][i + 1], inn[j][i], inn[j + 1][i], inn[j + 1][i + 1])))
        for i in range(nu):
            f_edge.append(self.bm.faces.new((out[0][i + 1], out[0][i], inn[0][i], inn[0][i + 1])))
            f_edge.append(self.bm.faces.new((out[nv][i], out[nv][i + 1], inn[nv][i + 1], inn[nv][i])))
        for j in range(nv):
            f_edge.append(self.bm.faces.new((out[j][0], out[j + 1][0], inn[j + 1][0], inn[j][0])))
            f_edge.append(self.bm.faces.new((out[j + 1][nu], out[j][nu], inn[j][nu], inn[j + 1][nu])))
        faces = [t[0] for t in f_out] + f_in + f_edge
        res = self._done(verts, faces, cell_out, weights)
        if cell_in is not None:
            self.paint(f_in, cell_in)
        if cell_fn is not None:
            for f, u, v in f_out:
                c = cell_fn(u, v)
                if c is not None:
                    self.paint([f], c)
        return res

    # ---------------------------------------------------------------- box
    def box(self, center, size, cell, weights, rot=None, bevel=0.0):
        res = bmesh.ops.create_cube(self.bm, size=1.0)
        vs = res["verts"]
        for v in vs:
            co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
            if rot is not None:
                co = rot @ co
            v.co = Vector(center) + co
        faces = list({f for v in vs for f in v.link_faces})
        if bevel > 0.0:
            edges = list({e for f in faces for e in f.edges})
            r = bmesh.ops.bevel(self.bm, geom=edges, offset=bevel, offset_type="OFFSET", segments=2, profile=0.5,
                                affect="EDGES", clamp_overlap=True)
            vs = list({v for f in r["faces"] for v in f.verts} | {v for v in vs if v.is_valid})
            faces = list({f for v in vs for f in v.link_faces})
        return self._done(vs, faces, cell, weights)


def scale_about(part, pivot, k):
    p = Vector(pivot)
    for v in part["verts"]:
        v.co = p + (v.co - p) * k


def new_skinned(name, collection, armature="Armature", material="M_Char"):
    """Empty mesh object bound to the skeleton (Armature modifier and parent), in its own collection."""
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
        bpy.data.scenes["Scene"].collection.children.link(col)
    col.objects.link(ob)
    me.uv_layers.new(name="UVMap")
    if armature:
        arm = bpy.data.objects[armature]
        ob.parent = arm
        mod = ob.modifiers.new("Armature", "ARMATURE")
        mod.object = arm
    mat = bpy.data.materials.get(material)
    if mat is not None:
        me.materials.append(mat)
    return ob


def finish(ob, bm, sharp_deg=48.0, ao=True, ao_dist=0.32, ao_strength=0.75, ao_min=0.42, ao_rays=28):
    """Writes the bmesh to the object: smooth shading with sharp edges above sharp_deg, occlusion baked to the
    vertex colours (rays over the hemisphere of every vertex against the whole mesh in the rest pose)."""
    bm.normal_update()
    bm.to_mesh(ob.data)
    me = ob.data
    me.update()
    for p in me.polygons:
        p.use_smooth = True
    try:
        me.set_sharp_from_angle(angle=math.radians(sharp_deg))
    except Exception:
        pass
    if ao:
        bm2 = bmesh.new()
        bm2.from_mesh(me)
        bm2.normal_update()
        tree = BVHTree.FromBMesh(bm2)
        dirs = []
        golden = math.pi * (3.0 - math.sqrt(5.0))
        for i in range(ao_rays):          # points on the upper hemisphere, cosine-ish spread
            z = 1.0 - (i + 0.5) / ao_rays * 0.92
            r = math.sqrt(max(0.0, 1.0 - z * z))
            dirs.append(Vector((math.cos(i * golden) * r, math.sin(i * golden) * r, z)))
        vals = []
        for v in bm2.verts:
            n = v.normal if v.normal.length > 0.1 else Vector((0, 0, 1))
            fr = frame_for(n)
            o = v.co + n * 0.006
            hit = 0.0
            for d in dirs:
                w = fr @ d
                loc, _, _, dist = tree.ray_cast(o, w, ao_dist)
                if loc is not None:
                    hit += 1.0 - 0.5 * dist / ao_dist
            vals.append(max(ao_min, 1.0 - ao_strength * hit / ao_rays))
        bm2.free()
        attr = me.color_attributes.get("Col")
        if attr is None:
            attr = me.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
        for l in me.loops:
            a = vals[l.vertex_index]
            attr.data[l.index].color = (a, a, a, 1.0)
        me.color_attributes.active_color = attr
        try:
            me.color_attributes.render_color_index = list(me.color_attributes).index(attr)
        except Exception:
            pass
    return {"tris": sum(len(p.vertices) - 2 for p in me.polygons), "verts": len(me.vertices),
            "unweighted": sum(1 for v in me.vertices if not v.groups)}


def export_glb(objs, path, animations=True):
    """GLB without materials (UVs and vertex colours stay), all actions sampled, as the other characters.
    The window must already show the scene "Scene" (set bpy.context.window.scene in an earlier call): switching the
    scene and exporting under a context override in one go crashed Blender 5.2."""
    import logging
    vl = bpy.context.view_layer
    for o in vl.objects:
        o.select_set(False)
    for o in objs:
        o.hide_set(False)
        o.select_set(True)
    vl.objects.active = objs[0]
    kw = dict(filepath=path, use_selection=True, export_materials="NONE", export_yup=True)
    props = bpy.ops.export_scene.gltf.get_rna_type().properties
    for key, val in (("export_vertex_color", "ACTIVE"), ("export_all_vertex_colors", False),
                     ("export_active_vertex_color_when_no_material", True)):
        if key in props:
            kw[key] = val
    if animations:
        kw.update(export_animation_mode="ACTIONS", export_force_sampling=True)
    else:
        kw.update(export_animations=False)
    logging.disable(logging.WARNING)      # the exporter warns for every horse bone in every action
    try:
        bpy.ops.export_scene.gltf(**kw)
    finally:
        logging.disable(logging.NOTSET)
