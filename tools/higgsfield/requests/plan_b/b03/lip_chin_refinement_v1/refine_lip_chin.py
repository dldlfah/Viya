"""Independent local lip/chin controls on the current registered-iris model."""
import copy
import csv
import importlib.util
import json
import math
import sys
from pathlib import Path
import bpy
from mathutils import Vector

HERE=Path(__file__).resolve().parent
INPUT=HERE.parent/'eye_surface_v2/viya_iris_registration.blend'
OUTPUT=HERE/'viya_lip_chin_refinement.blend'
OUT=HERE/'review'
PARAM=json.loads((HERE/'parameters.json').read_text());KEYS=PARAM['new_keys']
spec=importlib.util.spec_from_file_location('current_iris_model',HERE.parent/'eye_surface_v2/build_iris_model.py')
current=importlib.util.module_from_spec(spec);spec.loader.exec_module(current)
shape=current.shape;sha=current.sha
shape.prior.prior.prior.REVIEW=OUT
shape.prior.prior.prior.prior.previous.original.utils.OUT=OUT


def clean_snapshot(s):
    s=copy.deepcopy(s)
    for o in s.values():
        for name in KEYS:o['keys'].pop(name,None)
        o.pop('evaluated_control_positions',None)
    return s


def smooth(a,b,x):
    t=max(0,min(1,(x-a)/(b-a)));return t*t*(3-2*t)


def gauss(x,sigma):return math.exp(-.5*(x/sigma)**2)


def switches(a,b):
    for o in shape.meshes():
        for name,value in zip(KEYS,(a,b)):
            if name in o.data.shape_keys.key_blocks:o.data.shape_keys.key_blocks[name].value=value


def deltas(p):
    l=PARAM['lip'];c=PARAM['chin'];x=abs(p.x)
    gate=(1-smooth(*l['x_gate'],x))*smooth(*l['lower_z_gate'],p.z)*(1-smooth(*l['upper_z_gate'],p.z))*smooth(*l['front_gate'],-p.y)
    w=gauss(p.x,l['sigma_x'])*gauss(p.z-l['center_z'],l['sigma_z'])*gate
    arc=(l['center_arch_rise_m']*gauss(p.x,l['arch_sigma_x'])-l['corner_drop_m']*smooth(*l['corner_gate_x'],x))
    arc_weight=gauss(p.z-l['center_z'],.008)*gate
    lip=Vector((0,l['depth_reduction_m']*w,-(p.z-l['center_z'])*l['vertical_contraction']*w+arc*arc_weight))
    gate=(1-smooth(*c['x_gate'],x))*smooth(*c['lower_z_gate'],p.z)*(1-smooth(*c['upper_z_gate'],p.z))*smooth(*c['front_gate'],-p.y)
    width=gauss(p.x,c['width_sigma_x'])*gauss(p.z-c['center_z'],c['sigma_z'])*gate
    tip=gauss(p.x,c['tip_sigma_x'])*gauss(p.z-c['tip_center_z'],c['tip_sigma_z'])*gate
    bulge=gauss(p.x,c['bulge_sigma_x'])*gauss(p.z-c['bulge_center_z'],c['bulge_sigma_z'])*gate
    chin=Vector((-p.x*c['width_fraction']*width,-c['tip_forward_m']*tip+c['bulge_retract_m']*bulge,-c['tip_lower_m']*tip))
    if lip.length<1e-8:lip=Vector()
    if chin.length<1e-8:chin=Vector()
    assert (lip+chin).length<=PARAM['maximum_authored_combined_displacement_m']
    return lip,chin


def metrics(o,ps):
    ids={v.value:i for i,v in enumerate(o.data.attributes['source_vertex_index'].data)}
    selected=json.loads((HERE.parent/'head_refinement_v3/loop_selection.json').read_text())['mouth']
    r={}
    for name in ['outer_lip','opening']:
        q=[ps[ids[i]] for i in selected[name]['source_indices']]
        r[name]={'width_m':max(p.x for p in q)-min(p.x for p in q),'height_m':max(p.z for p in q)-min(p.z for p in q),'front_y_m':min(p.y for p in q)}
    samples=[]
    for z in [.030,.036,.042,.048,.060,.064,.068]:
        q=[(i,p) for i,p in enumerate(ps) if abs(p.x)<.005 and abs(p.z-z)<.0025 and p.y<-.035]
        if q:
            i,p=min(q,key=lambda x:x[1].y);samples.append({'sample_z':z,'local_index':i,'point':list(p)})
    r['near_midline_front_control_samples']=samples
    return r


def audit_protected(before,after):
    skin=next(o for o in shape.meshes() if 'head_skin' in o.name)
    regions={
        'upper_face_z_ge_075':[i for i,p in enumerate(before[skin.name]) if p.z>=.075],
        'outer_skin_abs_x_ge_050':[i for i,p in enumerate(before[skin.name]) if abs(p.x)>=.050],
        'low_neck_z_le_018':[i for i,p in enumerate(before[skin.name]) if p.z<=.018],
        'back_or_inner_y_ge_minus035':[i for i,p in enumerate(before[skin.name]) if p.y>=-.035]
    }
    result={}
    for name,ids in regions.items():
        maximum=max(((after[skin.name][i]-before[skin.name][i]).length for i in ids),default=0)
        assert maximum==0,(name,maximum)
        result[name]={'control_vertices':len(ids),'maximum_displacement_m':maximum}
    for o in shape.meshes():
        if o!=skin:
            assert all(a==b for a,b in zip(before[o.name],after[o.name]))
            result[o.name]={'all_helper_vertices_unchanged':True}
    return result


def build():
    assert sha(INPUT)==PARAM['input_sha256'];bpy.ops.wm.open_mainfile(filepath=str(INPUT))
    baseline=shape.snapshot();images=current.previous.hashes()
    before={o.name:shape.points(o) for o in shape.meshes()}
    skin=next(o for o in shape.meshes() if 'head_skin' in o.name)
    basis=skin.data.shape_keys.key_blocks[0];records=[]
    keys=[]
    for name in KEYS:
        k=skin.shape_key_add(name=name);k.relative_key=basis
        for a,b in zip(basis.data,k.data):b.co=a.co
        keys.append(k)
    for i,p in enumerate(before[skin.name]):
        lip,chin=deltas(p)
        if lip.length==0 and chin.length==0:continue
        keys[0].data[i].co+=lip;keys[1].data[i].co+=chin
        records.append({'local_index':i,'source_index':skin.data.attributes['source_vertex_index'].data[i].value,'requested_lip_delta':list(lip),'requested_chin_delta':list(chin)})
    switches(*PARAM['key_values'])
    assert clean_snapshot(shape.snapshot())==clean_snapshot(baseline)
    stats=shape.prior.prior.prior.prior.audit(before)
    for x in stats.values():
        assert x['new_flipped_fan_triangles']==x['degenerate_fan_triangles']==x['nonfinite_coordinates']==0,x
    after={o.name:shape.points(o) for o in shape.meshes()}
    protected=audit_protected(before,after)
    assert current.previous.hashes()==images
    OUT.mkdir(exist_ok=True)
    for view in ['front','three_quarter','three_quarter_opposite','screen_left_profile','screen_right_profile','game_high_angle']:
        shape.render(view,'after_'+view)
    switches(0,0);shape.render('front','before_front');switches(*PARAM['key_values'])
    mats={o.name:o.data.materials[0] for o in shape.meshes()}
    for o in shape.meshes():
        m=bpy.data.materials.new('LipChin_Clay_'+o.name);m.use_nodes=True
        bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(.55,.55,.55,1);bs.inputs['Roughness'].default_value=.8
        o.data.materials[0]=m
    for tag,values in [('before',(0,0)),('after',PARAM['key_values'])]:
        switches(*values)
        for view in ['front','screen_left_profile','screen_right_profile']:shape.render(view,'clay_'+tag+'_'+view)
    for o in shape.meshes():o.data.materials[0]=mats[o.name]
    switches(*PARAM['key_values'])
    assert current.previous.hashes()==images
    shape.prior.prior.prior.prior.previous.original.utils.set_view('three_quarter')
    bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT),compress=True)
    r={'input_sha256':sha(INPUT),'output_sha256':sha(OUTPUT),'parameters':PARAM,'baseline_snapshot':baseline,'saved_snapshot':shape.snapshot(),'old_controls_topology_uv_preserved':True,'active_packed_image_hashes':images,'image_bytes_unchanged':True,'before_metrics':metrics(skin,before[skin.name]),'after_metrics':metrics(skin,after[skin.name]),'local_change_audit':stats,'protected_regions':protected,'requested_support_vertices':len(records),'paid_submissions':0,'spent_credits':0,'game_integration':False,'scope':'Local control change/audit only, not full self-intersection, likeness, producer/rig/game/device acceptance.'}
    (HERE/'build_result.json').write_text(json.dumps(r,indent=2)+'\n')
    with (HERE/'vertex_changes.csv').open('w',newline='') as f:
        w=csv.writer(f,lineterminator='\n');w.writerow(['source_index','local_index','before_x','before_y','before_z','after_x','after_y','after_z','delta_x','delta_y','delta_z','lip_dx','lip_dy','lip_dz','chin_dx','chin_dy','chin_dz'])
        for row in records:
            i=row['local_index'];a=before[skin.name][i];b=after[skin.name][i]
            w.writerow([row['source_index'],i,*a,*b,*(b-a),*row['requested_lip_delta'],*row['requested_chin_delta']])
    print('LIP_CHIN_BUILT',json.dumps(stats))


def verify():
    r=json.loads((HERE/'build_result.json').read_text());assert sha(INPUT)==r['input_sha256'] and sha(OUTPUT)==r['output_sha256']
    bpy.ops.wm.open_mainfile(filepath=str(OUTPUT))
    assert shape.snapshot()==r['saved_snapshot']
    assert clean_snapshot(shape.snapshot())==clean_snapshot(r['baseline_snapshot'])
    assert current.previous.hashes()==r['active_packed_image_hashes']
    switches(0,0);before={o.name:shape.points(o) for o in shape.meshes()}
    switches(*PARAM['key_values']);after={o.name:shape.points(o) for o in shape.meshes()}
    assert shape.prior.prior.prior.prior.audit(before)==r['local_change_audit']
    assert audit_protected(before,after)==r['protected_regions']
    skin=next(o for o in shape.meshes() if 'head_skin' in o.name)
    with (HERE/'vertex_changes.csv').open() as f:rows=list(csv.DictReader(f))
    for row in rows:
        i=int(row['local_index']);a=before[skin.name][i];b=after[skin.name][i]
        for name,p in [('before',a),('after',b),('delta',b-a)]:
            assert all(abs(float(row[name+'_'+axis])-p[j])<1e-12 for j,axis in enumerate('xyz'))
    assert not bpy.data.libraries and not any(o.type=='ARMATURE' for o in bpy.context.scene.objects)
    assert all(i.packed_file for i in bpy.data.images if i.source=='FILE' and i.users)
    shape.render('three_quarter','after_three_quarter_reopened')
    (HERE/'reopen_result.json').write_text(json.dumps({'output_sha256':sha(OUTPUT),'old_controls_topology_uv_equal':True,'new_keys_preserved':True,'active_packed_images_equal':True,'geometry_audit_and_protected_regions_equal':True,'csv_reopened_coordinates_equal':True,'external_blend_dependencies':0,'armature_objects':0,'scope':'Persistence/control audit only, not likeness/contact/rig/game/device or producer approval.'},indent=2)+'\n');print('LIP_CHIN_REOPENED')


if __name__=='__main__':
    {'build':build,'verify':verify}[sys.argv[sys.argv.index('--')+1]]()
