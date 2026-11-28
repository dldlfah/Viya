"""Inspect the unchanged Meshy GLB and save an isolated, editable review scene.

Run: blender -b --python inspect_body.py -- RAW_GLB OUTPUT_DIR
No paid services, texture repainting, mesh reconstruction, or game changes.
"""
import bpy
from mathutils import Vector
from pathlib import Path
import sys
import json
import math
import hashlib

raw, out = map(Path, sys.argv[sys.argv.index('--') + 1:])
out.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(raw.resolve()))
source_objects = list(bpy.context.scene.objects)
meshes = [o for o in source_objects if o.type == 'MESH']
armatures = [o for o in source_objects if o.type == 'ARMATURE']
assert meshes, 'No mesh in generated GLB'

def bounds(objects, evaluated=False):
    points = []
    deps = bpy.context.evaluated_depsgraph_get()
    for obj in objects:
        ob = obj.evaluated_get(deps) if evaluated else obj
        points.extend(ob.matrix_world @ Vector(v) for v in ob.bound_box)
    return [min(p[i] for p in points) for i in range(3)], [max(p[i] for p in points) for i in range(3)]

lo, hi = bounds(meshes)
report = {
    'raw_glb_sha256': hashlib.sha256(raw.read_bytes()).hexdigest(),
    'blender_version': bpy.app.version_string,
    'raw_bounds_blender_xyz': {'min': lo, 'max': hi},
    'mesh_objects': [], 'armatures': [], 'images': [],
    'unweighted_vertices': 0, 'actions': [a.name for a in bpy.data.actions],
    'scope': 'Candidate body inspection, not game integration or final design acceptance',
}
for obj in meshes:
    m = obj.data
    m.calc_loop_triangles()
    unweighted = sum(not any(g.weight > 0.0001 for g in v.groups) for v in m.vertices)
    report['unweighted_vertices'] += unweighted
    report['mesh_objects'].append({
        'name': obj.name, 'vertices': len(m.vertices), 'polygons': len(m.polygons),
        'triangles': len(m.loop_triangles), 'uv_layers': [u.name for u in m.uv_layers],
        'materials': [x.name if x else None for x in m.materials],
        'vertex_groups': [g.name for g in obj.vertex_groups],
        'armature_modifiers': [x.object.name if x.object else None for x in obj.modifiers if x.type == 'ARMATURE'],
        'unweighted_vertices': unweighted,
    })
for obj in armatures:
    report['armatures'].append({'name': obj.name, 'bone_count': len(obj.data.bones),
        'bones': [{'name': b.name, 'parent': b.parent.name if b.parent else None,
                   'head_local': list(b.head_local), 'tail_local': list(b.tail_local)} for b in obj.data.bones]})
for im in bpy.data.images:
    if im.name not in ('Render Result', 'Viewer Node'):
        report['images'].append({'name': im.name, 'width': im.size[0], 'height': im.size[1], 'channels': im.channels})

# One common parent transform, never per-frame or per-limb registration.
root = bpy.data.objects.new('candidate_registration', None)
bpy.context.scene.collection.objects.link(root)
for obj in source_objects:
    if obj.parent is None:
        world = obj.matrix_world.copy()
        obj.parent = root
        obj.matrix_world = world
height = hi[2] - lo[2]
assert height > 0.001
scale = 1.72 / height
root.scale = (scale,) * 3
root.location = (-(lo[0] + hi[0]) * scale / 2, -(lo[1] + hi[1]) * scale / 2, -lo[2] * scale)
root['review_only'] = True
root['raw_file'] = raw.name
root['not_final_rig_or_approved_viya'] = True
bpy.context.view_layer.update()
report['registration'] = {'kind': 'One uniform parent transform', 'scale': scale, 'translation': list(root.location),
    'target_height_m': 1.72, 'raw_geometry_edited': False, 'final_scale_one_contract': 'Not finalized; candidate review parent retained'}
report['registered_bounds_blender_xyz'] = dict(zip(('min', 'max'), bounds(meshes)))

# Pack source textures without repainting or replacing them.
bpy.ops.file.pack_all()
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.samples = 12
scene.cycles.use_denoising = True
scene.render.resolution_x = 768
scene.render.resolution_y = 960
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'
scene.render.film_transparent = True
scene.view_settings.view_transform = 'Standard'
scene.world = bpy.data.worlds.new('Review World')
scene.world.use_nodes = True
scene.world.node_tree.nodes['Background'].inputs['Color'].default_value = (0.65, 0.65, 0.65, 1)
scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value = 0.6

def area(name, pos, power, size):
    d = bpy.data.lights.new(name, 'AREA'); d.energy = power; d.shape = 'DISK'; d.size = size
    o = bpy.data.objects.new(name, d); scene.collection.objects.link(o); o.location = pos
    o.rotation_euler = (Vector((0, 0, 0.9)) - o.location).to_track_quat('-Z', 'Y').to_euler()
area('Key', (2, -3, 5), 400, 4)
area('Fill', (-3, -1, 3), 200, 4)
area('Rim', (0, 3, 3), 250, 3)
camera_data = bpy.data.cameras.new('Review Camera')
camera = bpy.data.objects.new('Review Camera', camera_data)
scene.collection.objects.link(camera); scene.camera = camera
camera_data.type = 'ORTHO'; camera_data.ortho_scale = 2.15

def render(name, position, center=(0, 0, 0.86)):
    camera.location = position
    camera.rotation_euler = (Vector(center) - camera.location).to_track_quat('-Z', 'Y').to_euler()
    scene.render.filepath = str((out / (name + '.png')).resolve())
    bpy.ops.render.render(write_still=True)

for name, pos in [('front', (0, -5, 0.86)), ('back', (0, 5, 0.86)),
                  ('left', (-5, 0, 0.86)), ('right', (5, 0, 0.86)),
                  ('game_high_angle', (0, -5 * math.cos(math.radians(55)), 0.86 + 5 * math.sin(math.radians(55))))]:
    render(name, pos)

# Stress poses expose the supplied skin's behavior; never delivered as authored actions.
stress = {}
for arm in armatures:
    selected = []
    for b in arm.pose.bones:
        n = b.name.lower().replace('_', '').replace('-', '')
        if any(x in n for x in ('leftupleg', 'rightupleg', 'leftleg', 'rightleg', 'leftarm', 'rightarm', 'leftforearm', 'rightforearm')):
            b.rotation_mode = 'XYZ'
            amount = 0.45 if 'left' in n else -0.35
            b.rotation_euler.x = amount
            selected.append(b.name)
    stress[arm.name] = selected
if any(stress.values()):
    bpy.context.view_layer.update()
    report['stress_pose_bounds'] = dict(zip(('min', 'max'), bounds(meshes, evaluated=True)))
    render('skin_stress_front', (0, -5, 0.86))
    render('skin_stress_side', (-5, 0, 0.86))
    for arm in armatures:
        for b in arm.pose.bones:
            b.rotation_euler = (0, 0, 0)
report['stress_test_bones'] = stress
bpy.context.view_layer.update()
camera.location = (0, -5, 0.86)
camera.rotation_euler = (Vector((0, 0, 0.86)) - camera.location).to_track_quat('-Z', 'Y').to_euler()
bpy.ops.wm.save_as_mainfile(filepath=str((out / 'viya_body_review.blend').resolve()))
(out / 'structure_report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
print('CANDIDATE_INSPECTION_COMPLETE', json.dumps({'meshes': len(meshes), 'armatures': len(armatures),
    'triangles': sum(m['triangles'] for m in report['mesh_objects']), 'unweighted_vertices': report['unweighted_vertices']}))
