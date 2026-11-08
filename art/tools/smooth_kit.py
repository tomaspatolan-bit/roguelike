# Smooth pass for heroes and enemies (style pilot 2.0s, 08.11.2026): softer, more "toy" look of the rigid low-poly
# characters without a new model. Run in Blender via exec after hero_kit.py (needs islands, Builder, cell constants).
#   bevel_hard(bm, cells, width, segments, angle)  chamfer the hard edges of armour and metal so they catch the light
#   soften_cloth(bm, verts, ...)                    soft weights of a skirt or tabard to the thighs (it follows the legs)
#   scale_part(verts, pivot, k)                     proportions (bigger head and fists read better from above)
#   weighted_normals(ob)                            smooth shading with flat-looking faces (Weighted Normal, applied)
#   export_glb(ob, path, armature)                  export like the other characters (no materials, all actions)
import math
import bmesh
import bpy
from mathutils import Vector


def _cell_of_face(f, uvl):
    return int(f.loops[0][uvl].uv[0] * 16)


def bevel_hard(bm, cells, width=0.01, segments=2, angle_deg=35.0, only=None):
    """Chamfers edges sharper than angle_deg between faces of the given palette cells (armour, metal).
    only = a set of vertices: just edges between them (e.g. rounding the fists more than the rest)."""
    bm.normal_update()
    uvl = bm.loops.layers.uv.active
    lim = math.radians(angle_deg)
    edges = []
    for e in bm.edges:
        if len(e.link_faces) != 2:
            continue
        if only is not None and not (e.verts[0] in only and e.verts[1] in only):
            continue
        a, b = e.link_faces
        if _cell_of_face(a, uvl) not in cells or _cell_of_face(b, uvl) not in cells:
            continue
        if a.normal.angle(b.normal, 0.0) >= lim:
            edges.append(e)
    if not edges:
        return 0
    bmesh.ops.bevel(bm, geom=edges, offset=width, offset_type="OFFSET", segments=segments, profile=0.5,
                    affect="EDGES", clamp_overlap=True)
    return len(edges)


def smoothstep(a, b, x):
    t = min(1.0, max(0.0, (x - a) / (b - a)))
    return t * t * (3.0 - 2.0 * t)


def soften_cloth(builder, verts, top_z, bottom_z, body, left, right, max_leg=0.65, flare=0.08, centre_y=0.0):
    """Skirt/tabard below top_z gradually follows the legs (left/right bone by x), up to max_leg at bottom_z,
    and flares a little outwards (x and away from centre_y). body = bone the cloth hangs from."""
    for v in verts:
        t = smoothstep(top_z, bottom_z, v.co.z)
        share_l = smoothstep(-0.12, 0.12, v.co.x)
        w = max_leg * t
        wts = {body: 1.0 - w}
        if w > 0.0:
            wts[left] = w * share_l
            wts[right] = w * (1.0 - share_l)
        builder.set_weights([v], wts)
        v.co.x *= 1.0 + flare * t
        v.co.y = centre_y + (v.co.y - centre_y) * (1.0 + flare * 0.6 * t)


def scale_part(verts, pivot, k):
    p = Vector(pivot)
    for v in verts:
        v.co = p + (v.co - p) * k


def weighted_normals(ob):
    """All faces smooth, normals weighted by face area (big faces stay flat, bevels round the edges). Applied."""
    for p in ob.data.polygons:
        p.use_smooth = True
    m = ob.modifiers.new("WN", "WEIGHTED_NORMAL")
    m.mode = "FACE_AREA"
    m.weight = 100
    m.keep_sharp = True
    with bpy.context.temp_override(object=ob, active_object=ob):
        bpy.ops.object.modifier_move_to_index(modifier="WN", index=0)
        bpy.ops.object.modifier_apply(modifier="WN")


def export_glb(objs, path, animations=True):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.hide_set(False)
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    if animations:
        bpy.ops.export_scene.gltf(filepath=path, use_selection=True, export_materials="NONE",
                                  export_animation_mode="ACTIONS", export_force_sampling=True, export_yup=True)
    else:
        bpy.ops.export_scene.gltf(filepath=path, use_selection=True, export_materials="NONE",
                                  export_animations=False, export_yup=True)
