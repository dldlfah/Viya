"""Diagnose and replace eye color maps on the unchanged R5 working model."""
import hashlib
import importlib.util
import json
import sys
from pathlib import Path
import bpy

HERE=Path(__file__).resolve().parent
INPUT=HERE.parent/'eye_refinement_v1/viya_eye_refinement.blend'
OUTPUT=HERE/'viya_eye_surface.blend'
OUT=HERE/'review'
PARAM=json.loads((HERE/'parameters.json').read_text())
spec=importlib.util.spec_from_file_location('current_eye_shape',HERE.parent/'eye_refinement_v1/refine_eyes.py')
shape=importlib.util.module_from_spec(spec);spec.loader.exec_module(shape)
shape.prior.prior.prior.REVIEW=OUT;shape.prior.prior.prior.prior.previous.original.utils.OUT=OUT

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def load():
    assert sha(INPUT)==PARAM['input_sha256'];bpy.ops.wm.open_mainfile(filepath=str(INPUT));return shape.snapshot()
def hashes():return shape.prior.image_hashes()
def render(view,name):shape.render(view,name)
def flat(name,color):
    m=bpy.data.materials.new(name);m.use_nodes=True;m.node_tree.nodes.clear();em=m.node_tree.nodes.new('ShaderNodeEmission');em.inputs['Color'].default_value=(*color,1);out=m.node_tree.nodes.new('ShaderNodeOutputMaterial');m.node_tree.links.new(em.outputs[0],out.inputs['Surface']);return m

def diagnose():
    before=load();images=hashes();mats={o.name:o.data.materials[0] for o in shape.meshes()};OUT.mkdir(exist_ok=True)
    for o in shape.meshes():
        color=(.35,.35,.35) if 'head_skin' in o.name else ((0,1,0) if 'helper-l-eye' in o.name else (0,0,1))
        o.data.materials[0]=flat('EyeSurface_ID_'+o.name,color)
    for view in ['front','three_quarter','three_quarter_opposite']:render(view,'label_'+view)
    for o in shape.meshes():o.data.materials[0]=mats[o.name]
    assert shape.snapshot()==before and hashes()==images
    (HERE/'label_pass_result.json').write_text(json.dumps({'input_sha256':sha(INPUT),'label_colors':{'head':'gray','screen_right_helper':'green','screen_left_helper':'blue'},'geometry_controls_uv_and_active_images_restored':True,'model_not_saved':True,'scope':'Diagnostic visible object ownership with antialias margins, not physical eye contact/self-intersection.'},indent=2)+'\n');print('EYE_LABELS_RENDERED')

def diagnose_iris():
    before=load();images=hashes();mats={o.name:o.data.materials[0] for o in shape.meshes()};OUT.mkdir(exist_ok=True)
    for o in shape.meshes():
        if 'head_skin' in o.name:o.data.materials[0]=flat('EyeIris_ID_head',(.35,.35,.35));continue
        side='right' if 'helper-l-eye' in o.name else 'left'
        m=flat('EyeIris_ID_'+side,(0,0,1));nodes=m.node_tree.nodes;links=m.node_tree.links
        uv=nodes.new('ShaderNodeUVMap');uv.uv_map='VIYA_face_surface_uv';tex=nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(HERE/'textures'/('iris_mask_'+side+'.png')));tex.interpolation='Linear'
        links.new(uv.outputs['UV'],tex.inputs['Vector']);em=next(n for n in nodes if n.type=='EMISSION');links.new(tex.outputs['Color'],em.inputs['Color']);o.data.materials[0]=m
    for view in ['front','three_quarter','three_quarter_opposite']:render(view,'iris_label_'+view)
    for o in shape.meshes():o.data.materials[0]=mats[o.name]
    assert shape.snapshot()==before and hashes()==images
    (HERE/'iris_label_result.json').write_text(json.dumps({'input_sha256':sha(INPUT),'label_colors':{'head':'gray','original_iris_uv_region':'green','sclera':'blue'},'original_iris_region_mask':True,'geometry_uv_and_active_images_restored':True,'model_not_saved':True,'scope':'Visible mask ownership includingAA; not calibrated source exposure matching.'},indent=2)+'\n');print('IRIS_LABELS_RENDERED')

def build():
    baseline=load();before_images=hashes();records=[]
    for o in shape.meshes():
        if 'head_skin' in o.name:continue
        old=o.data.materials[0];old.use_fake_user=True;mat=old.copy();mat.name='B0304_ScleraTone_'+o.name
        filename='eye_screen_right.png' if 'helper-l-eye' in o.name else 'eye_screen_left.png'
        image=bpy.data.images.load(str(HERE/'textures'/filename));image.colorspace_settings.name='sRGB';image.pack()
        for n in mat.node_tree.nodes:
            if n.type=='TEX_IMAGE':n.image=image
        o.data.materials[0]=mat;records.append({'object':o.name,'old_material_retained':old.name,'new_material':mat.name,'image':filename})
    assert shape.snapshot()==baseline
    after_images=hashes();skin=next(o for o in shape.meshes() if 'head_skin' in o.name);assert before_images[skin.name]==after_images[skin.name]
    OUT.mkdir(exist_ok=True)
    for v in ['front','three_quarter','three_quarter_opposite','screen_left_profile','screen_right_profile','game_high_angle']:render(v,'after_'+v)
    mats={o.name:o.data.materials[0] for o in shape.meshes()}
    for o in shape.meshes():
        m=o.data.materials[0].copy();m.name='EyeSurface_Unlit_'+o.name;nodes=m.node_tree.nodes;links=m.node_tree.links
        out=next(n for n in nodes if n.type=='OUTPUT_MATERIAL');em=next(n for n in nodes if n.type=='EMISSION')
        for link in list(out.inputs['Surface'].links):links.remove(link)
        links.new(em.outputs[0],out.inputs['Surface']);o.data.materials[0]=m
    for v in ['front','three_quarter','three_quarter_opposite']:render(v,'unlit_after_'+v)
    for o in shape.meshes():o.data.materials[0]=mats[o.name]
    shape.prior.prior.prior.prior.previous.original.utils.set_view('three_quarter')
    bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT),compress=True)
    r={'input_sha256':sha(INPUT),'output_sha256':sha(OUTPUT),'snapshot':baseline,'all_geometry_controls_and_uv_unchanged':True,'before_active_image_hashes':before_images,'after_active_image_hashes':after_images,'eye_materials':records,'head_image_unchanged':True,'paid_submissions':0,'spent_credits':0,'game_integration':False}
    (HERE/'build_result.json').write_text(json.dumps(r,indent=2)+'\n');print('EYE_SURFACE_BUILT')

def verify():
    r=json.loads((HERE/'build_result.json').read_text());assert sha(INPUT)==r['input_sha256'] and sha(OUTPUT)==r['output_sha256'];bpy.ops.wm.open_mainfile(filepath=str(OUTPUT))
    assert shape.snapshot()==r['snapshot'] and hashes()==r['after_active_image_hashes']
    assert all(x['old_material_retained'] in bpy.data.materials for x in r['eye_materials'])
    assert not bpy.data.libraries and not any(o.type=='ARMATURE' for o in bpy.context.scene.objects)
    assert all(i.packed_file for i in bpy.data.images if i.source=='FILE' and i.users)
    render('three_quarter','after_three_quarter_reopened')
    (HERE/'reopen_result.json').write_text(json.dumps({'output_sha256':sha(OUTPUT),'all_geometry_controls_and_uv_equal':True,'active_packed_images_equal':True,'previous_materials_retained':True,'head_image_unchanged':True,'external_blend_dependencies':0,'rig_objects':0,'scope':'File/material persistence only; not source likeness, producer, rig/game/device acceptance.'},indent=2)+'\n');print('EYE_SURFACE_REOPENED')

if __name__=='__main__':{'diagnose':diagnose,'diagnose_iris':diagnose_iris,'build':build,'verify':verify}[sys.argv[sys.argv.index('--')+1]]()
