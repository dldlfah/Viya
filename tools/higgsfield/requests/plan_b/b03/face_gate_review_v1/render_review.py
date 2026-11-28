"""Read-only diagnostic render of the existing R5/surface model; no model save."""
import hashlib
import importlib.util
import json
from pathlib import Path
import bpy

HERE = Path(__file__).resolve().parent
INPUT = HERE.parent / 'eye_surface_v1/viya_eye_surface.blend'
OUT = HERE / 'review'
EXPECTED = '97b8a658207b0f27af355c32c37bfd645f57addaa8230770e657bdb92c4b6c05'
spec = importlib.util.spec_from_file_location('current_eye_surface', HERE.parent / 'eye_surface_v1/tune_eye_surface.py')
current = importlib.util.module_from_spec(spec)
spec.loader.exec_module(current)
shape = current.shape
shape.prior.prior.prior.REVIEW = OUT
shape.prior.prior.prior.prior.previous.original.utils.OUT = OUT


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def main():
    assert sha(INPUT) == EXPECTED
    bpy.ops.wm.open_mainfile(filepath=str(INPUT))
    baseline, images = shape.snapshot(), current.hashes()
    camera = bpy.context.scene.camera
    cam_start = {'location': list(camera.location), 'rotation': list(camera.rotation_euler)}
    views = ['front', 'screen_right_profile', 'screen_left_profile', 'three_quarter', 'three_quarter_opposite', 'game_high_angle']
    cameras = {}
    for view in views:
        shape.render(view, 'color_' + view)
        cameras[view] = {'location': list(camera.location), 'rotation_euler_radians': list(camera.rotation_euler), 'ortho_scale_m': camera.data.ortho_scale, 'resolution': [bpy.context.scene.render.resolution_x, bpy.context.scene.render.resolution_y]}
    materials = {o.name: o.data.materials[0] for o in shape.meshes()}
    for o in shape.meshes():
        m = bpy.data.materials.new('ReadOnly_Clay_' + o.name)
        m.use_nodes = True
        bsdf = m.node_tree.nodes.get('Principled BSDF')
        bsdf.inputs['Base Color'].default_value = (.55, .55, .55, 1)
        bsdf.inputs['Roughness'].default_value = .8
        o.data.materials[0] = m
    for view in ['front', 'screen_right_profile', 'screen_left_profile', 'three_quarter']:
        shape.render(view, 'clay_' + view)
    for o in shape.meshes():
        o.data.materials[0] = materials[o.name]
    camera.location = cam_start['location']
    camera.rotation_euler = cam_start['rotation']
    assert list(camera.location) == cam_start['location']
    assert list(camera.rotation_euler) == cam_start['rotation']
    assert shape.snapshot() == baseline and current.hashes() == images
    assert sha(INPUT) == EXPECTED
    r = {'input_sha256_before_and_after': EXPECTED, 'snapshot': baseline, 'active_image_hashes': images, 'geometry_controls_uv_and_images_restored': True, 'camera_restored': True, 'model_saved': False, 'blender': bpy.app.version_string, 'cameras': cameras, 'engine': bpy.context.scene.render.engine, 'samples': bpy.context.scene.cycles.samples, 'scope': 'Read-only studio diagnostic. No new face/model, rig, final shader, runtime or producer acceptance.'}
    (HERE / 'render_result.json').write_text(json.dumps(r, indent=2) + '\n')
    print('READ_ONLY_FACE_REVIEW_RENDERED')


if __name__ == '__main__':
    main()
