"""Controlled review of head shading/view hypotheses, without saving model changes."""
import importlib.util
import json
import math
from pathlib import Path
import bpy
from mathutils import Vector,Quaternion

HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('detail_model',HERE/'transfer_surface.py')
model=importlib.util.module_from_spec(spec);spec.loader.exec_module(model)

def main():
    build=json.loads((HERE/'build_result.json').read_text());path=HERE/'viya_face_details.blend'
    assert model.sha(path)==build['output_sha256']
    bpy.ops.wm.open_mainfile(filepath=str(path));before=model.snapshot();images=model.image_hashes()
    scene=bpy.context.scene;camera=scene.camera
    state={'location':camera.location.copy(),'rotation_mode':camera.rotation_mode,'rotation_euler':camera.rotation_euler.copy(),'filepath':scene.render.filepath}
    skin=next(o for o in model.meshes() if 'head_skin' in o.name)
    mix=next(n for n in skin.data.materials[0].node_tree.nodes if n.type=='MIX_SHADER');old_weight=mix.inputs[0].default_value
    records=[]
    settings=[('head_lit15_front',0,0,0,.15),('front_roll_hypothesis',0,0,-5.5722,.35),('yaw_minus12_roll_hypothesis',-12,0,-5.5722,.35),('yaw_plus12_roll_hypothesis',12,0,-5.5722,.35),('pitch_plus8_roll_hypothesis',0,8,-5.5722,.35)]
    for name,yaw,pitch,roll,weight in settings:
        y,p,r=map(math.radians,[yaw,pitch,roll]);camera.location=(math.sin(y)*math.cos(p),-math.cos(y)*math.cos(p),.104+math.sin(p))
        rotation=(Vector((0,0,.104))-camera.location).to_track_quat('-Z','Y')@Quaternion((0,0,1),r)
        camera.rotation_mode='XYZ';camera.rotation_euler=rotation.to_euler();mix.inputs[0].default_value=weight
        scene.render.filepath=str(HERE/'review'/(name+'.png'));bpy.ops.render.render(write_still=True)
        records.append({'name':name,'yaw_pitch_roll_degrees':[yaw,pitch,roll],'head_principled_weight':weight,'eyes_keep_existing_material':True,'camera_location':list(camera.location),'camera_rotation_euler':list(camera.rotation_euler),'camera_ortho_scale':camera.data.ortho_scale})
    camera.location=state['location'];camera.rotation_mode=state['rotation_mode'];camera.rotation_euler=state['rotation_euler'];scene.render.filepath=state['filepath'];mix.inputs[0].default_value=old_weight
    assert model.snapshot()==before and model.image_hashes()==images and model.sha(path)==build['output_sha256']
    assert tuple(camera.location)==tuple(state['location']) and tuple(camera.rotation_euler)==tuple(state['rotation_euler'])
    assert abs(mix.inputs[0].default_value-old_weight)<1e-7
    result={'input_sha256':build['output_sha256'],'hypotheses':records,'geometry_controls_uv_and_images_unchanged':True,'original_camera_and_head_material_restored':True,'no_blend_saved_or_geometry_changes':True,'scope':'Review hypotheses only, not recovered source camera, selected game view, anatomy fit or final engine material. Source iris landmarks have manual uncertainty.'}
    (HERE/'sensitivity_result.json').write_text(json.dumps(result,indent=2)+'\n');print('SENSITIVITY_REVIEW_ONLY')

if __name__=='__main__':main()
