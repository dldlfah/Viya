"""Install the derived iris-only maps on the unchanged current R5 model."""
import importlib.util
import json
import sys
from pathlib import Path
import bpy

HERE=Path(__file__).resolve().parent
INPUT=HERE.parent/'eye_surface_v1/viya_eye_surface.blend'
OUTPUT=HERE/'viya_iris_registration.blend'
OUT=HERE/'review'
PARAM=json.loads((HERE/'registration.json').read_text())
spec=importlib.util.spec_from_file_location('previous_eye_surface',HERE.parent/'eye_surface_v1/tune_eye_surface.py')
previous=importlib.util.module_from_spec(spec);spec.loader.exec_module(previous)
shape=previous.shape
shape.prior.prior.prior.REVIEW=OUT
shape.prior.prior.prior.prior.previous.original.utils.OUT=OUT
sha=previous.sha


def build():
    assert sha(INPUT)==PARAM['input_sha256']
    bpy.ops.wm.open_mainfile(filepath=str(INPUT))
    baseline=shape.snapshot();before=previous.hashes();records=[]
    author=json.loads((HERE/'authoring_result.json').read_text())
    for record in author['records']:
        assert record['changed_outside_iris']==0
        o=bpy.data.objects[record['object']]
        old=o.data.materials[0];old.use_fake_user=True
        mat=old.copy();mat.name='B0304_IrisRegistered_'+o.name
        filename='eye_screen_'+record['side']+'.png'
        assert sha(HERE/'textures'/filename)==record['new_png_sha256']
        image=bpy.data.images.load(str(HERE/'textures'/filename));image.colorspace_settings.name='sRGB';image.pack()
        for n in mat.node_tree.nodes:
            if n.type=='TEX_IMAGE':n.image=image
        o.data.materials[0]=mat
        records.append({'object':o.name,'old_material_retained':old.name,'new_material':mat.name,'image':filename})
    assert shape.snapshot()==baseline
    after=previous.hashes();skin=next(o for o in shape.meshes() if 'head_skin' in o.name)
    assert before[skin.name]==after[skin.name]
    OUT.mkdir(exist_ok=True)
    for v in ['front','three_quarter','three_quarter_opposite','screen_left_profile','screen_right_profile','game_high_angle']:
        shape.render(v,'after_'+v)
    mats={o.name:o.data.materials[0] for o in shape.meshes()}
    for o in shape.meshes():
        m=o.data.materials[0].copy();m.name='IrisReview_Unlit_'+o.name
        out=next(n for n in m.node_tree.nodes if n.type=='OUTPUT_MATERIAL')
        em=next(n for n in m.node_tree.nodes if n.type=='EMISSION')
        for link in list(out.inputs['Surface'].links):m.node_tree.links.remove(link)
        m.node_tree.links.new(em.outputs[0],out.inputs['Surface']);o.data.materials[0]=m
    for v in ['front','three_quarter','three_quarter_opposite']:
        shape.render(v,'unlit_after_'+v)
    for o in shape.meshes():o.data.materials[0]=mats[o.name]
    assert shape.snapshot()==baseline and previous.hashes()==after
    shape.prior.prior.prior.prior.previous.original.utils.set_view('three_quarter')
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT),compress=True)
    r={'input_sha256':sha(INPUT),'output_sha256':sha(OUTPUT),'snapshot':baseline,'all_geometry_controls_uv_unchanged':True,'before_active_image_hashes':before,'after_active_image_hashes':after,'eye_materials':records,'head_image_unchanged':True,'iris_footprint_and_sclera_unchanged':True,'paid_submissions':0,'spent_credits':0,'game_integration':False}
    (HERE/'build_result.json').write_text(json.dumps(r,indent=2)+'\n');print('IRIS_MODEL_BUILT')


def verify():
    r=json.loads((HERE/'build_result.json').read_text())
    assert sha(INPUT)==r['input_sha256'] and sha(OUTPUT)==r['output_sha256']
    bpy.ops.wm.open_mainfile(filepath=str(OUTPUT))
    assert shape.snapshot()==r['snapshot'] and previous.hashes()==r['after_active_image_hashes']
    assert all(x['old_material_retained'] in bpy.data.materials for x in r['eye_materials'])
    assert all(i.packed_file for i in bpy.data.images if i.source=='FILE' and i.users)
    assert not bpy.data.libraries and not any(o.type=='ARMATURE' for o in bpy.context.scene.objects)
    shape.render('three_quarter','after_three_quarter_reopened')
    (HERE/'reopen_result.json').write_text(json.dumps({'output_sha256':sha(OUTPUT),'all_geometry_controls_uv_equal':True,'active_packed_image_bytes_equal':True,'old_materials_retained':True,'external_blend_dependencies':0,'armature_objects':0,'scope':'Persistence only, not source likeness/contact/rig/game/device or producer acceptance.'},indent=2)+'\n');print('IRIS_MODEL_REOPENED')


def diagnose():
    r=json.loads((HERE/'build_result.json').read_text())
    assert sha(OUTPUT)==r['output_sha256']
    bpy.ops.wm.open_mainfile(filepath=str(OUTPUT))
    baseline=shape.snapshot();images=previous.hashes();mats={o.name:o.data.materials[0] for o in shape.meshes()}
    for o in shape.meshes():
        if 'head_skin' in o.name:
            o.data.materials[0]=previous.flat('IrisTraceHead',(.35,.35,.35));continue
        side='right' if 'helper-l-eye' in o.name else 'left'
        m=previous.flat('IrisTrace_'+side,(0,0,1));nodes=m.node_tree.nodes;links=m.node_tree.links
        uv=nodes.new('ShaderNodeUVMap');uv.uv_map='VIYA_face_surface_uv'
        tex=nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(HERE/'textures'/('glint_trace_'+side+'.png')));tex.interpolation='Linear'
        em=next(n for n in nodes if n.type=='EMISSION')
        links.new(uv.outputs['UV'],tex.inputs['Vector']);links.new(tex.outputs['Color'],em.inputs['Color']);o.data.materials[0]=m
    for view in ['front','three_quarter','three_quarter_opposite']:
        shape.render(view,'glint_trace_'+view)
    for o in shape.meshes():o.data.materials[0]=mats[o.name]
    assert shape.snapshot()==baseline and previous.hashes()==images and sha(OUTPUT)==r['output_sha256']
    (HERE/'glint_trace_result.json').write_text(json.dumps({'input_sha256':sha(OUTPUT),'green':'Atlas texels with >0.1 contribution from left source(737,178)','blue':'Other eye surface','head':'gray','geometry_uv_images_restored':True,'model_saved':False,'scope':'Visibility of source-contribution footprint only; not a likeness or physical contact score.'},indent=2)+'\n');print('GLINT_TRACE_RENDERED')


if __name__=='__main__':
    {'build':build,'verify':verify,'diagnose':diagnose}[sys.argv[sys.argv.index('--')+1]]()
