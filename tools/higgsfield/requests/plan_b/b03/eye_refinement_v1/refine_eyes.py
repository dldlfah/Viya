"""Local existing-lid expression key, preserving source keys, UV and packed colors."""
import copy
import csv
import importlib.util
import json
import math
import sys
from pathlib import Path
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

HERE=Path(__file__).resolve().parent
INPUT=HERE.parent/'face_surface_v4/viya_face_details.blend'
OUTPUT=HERE/'viya_eye_refinement.blend'
OUT=HERE/'review'
PARAM=json.loads((HERE/'parameters.json').read_text());KEY=PARAM['new_key']
SELECT=json.loads((HERE.parent/'head_refinement_v3/loop_selection.json').read_text())
spec=importlib.util.spec_from_file_location('previous_face_details',HERE.parent/'face_surface_v4/transfer_surface.py')
prior=importlib.util.module_from_spec(spec);spec.loader.exec_module(prior)
prior.prior.prior.REVIEW=OUT;prior.prior.prior.prior.previous.original.utils.OUT=OUT

def snapshot_without_new(s):
    s=copy.deepcopy(s)
    for o in s.values():
        o['keys'].pop(KEY,None);o.pop('evaluated_control_positions',None)
    return s

def points(o):return prior.prior.prior.points(o)
def meshes():return prior.meshes()
def snapshot():return prior.snapshot()
def sha(p):return prior.sha(p)
def render(view,name):prior.render(view,name)

def set_key(value):
    for o in meshes():
        if o.data.shape_keys and KEY in o.data.shape_keys.key_blocks:o.data.shape_keys.key_blocks[KEY].value=value

def eye_bvh(o):
    deps=bpy.context.evaluated_depsgraph_get();ev=o.evaluated_get(deps);m=ev.to_mesh();m.calc_loop_triangles()
    bvh=BVHTree.FromPolygons([v.co.copy() for v in m.vertices],[list(t.vertices) for t in m.loop_triangles],all_triangles=True);ev.to_mesh_clear();return bvh

def eye_front(bvh,p):
    q,_,_,_=bvh.ray_cast(Vector((p.x,-1,p.z)),Vector((0,1,0)))
    return q.y if q is not None else None

def smooth(a,b,x):
    t=max(0,min(1,(x-a)/(b-a)));return t*t*(3-2*t)

def make_deltas(skin,ps):
    ids={v.value:i for i,v in enumerate(skin.data.attributes['source_vertex_index'].data)}
    info={};labels={};delta={};records=[];coverage=[];g=PARAM['spatial_support']
    for side,rings in SELECT['eyes'].items():
        aperture=[ids[i] for i in rings['aperture']['source_indices']]
        outer=max(aperture,key=lambda i:abs(ps[i].x));inner=min(aperture,key=lambda i:abs(ps[i].x))
        helper=next(o for o in meshes() if ('helper-l-eye' in o.name if ps[outer].x>0 else 'helper-r-eye' in o.name))
        info[side]={'inner':abs(ps[inner].x),'outer':abs(ps[outer].x),'aperture':aperture,'bvh':eye_bvh(helper)}
        for name,r in rings.items():
            for source_id in r['source_indices']:labels[ids[source_id]]=(side,name)
    for i,p in enumerate(ps):
        side='eye_right' if p.x>0 else 'eye_left';eye=info[side];x=abs(p.x)
        u=max(0,min(1,(x-eye['inner'])/(eye['outer']-eye['inner'])))
        w=smooth(*g['inner_x_gate'],x)*(1-smooth(*g['outer_x_gate'],x))*smooth(*g['lower_z_gate'],p.z)*(1-smooth(*g['upper_z_gate'],p.z))*smooth(*g['front_depth_gate'],-p.y)
        drop=PARAM['outer_corner_lowering_working_m']*smooth(0,1,u)+PARAM['upper_lid_mid_lowering_working_m']*math.sin(math.pi*u)**1.2*smooth(*g['upper_lid_gate'],p.z)
        d=Vector((0,0,-drop*w))
        if d.length<1e-8:continue
        assert d.length<=PARAM['maximum_authored_displacement_working_m'];delta[i]=d
        records.append({'region':side,'loop':labels.get(i,(side,'spatial_support'))[1],'source_index':skin.data.attributes['source_vertex_index'].data[i].value,'local_index':i,'before':list(p),'after':list(p+d),'delta':list(d)})
    for side,eye in info.items():
        paired=missing=0;max_change=0;gaps=[]
        for i in eye['aperture']:
            p=ps[i];new=p+delta.get(i,Vector());yb=eye_front(eye['bvh'],p);ya=eye_front(eye['bvh'],new)
            if yb is None or ya is None:missing+=1;continue
            paired+=1;before=p.y-yb;after=new.y-ya;max_change=max(max_change,abs(after-before));gaps.append({'source_index':skin.data.attributes['source_vertex_index'].data[i].value,'before_gap_m':before,'after_gap_m':after})
        coverage.append({'side':side,'paired_front_helper_hits':paired,'not_paired_or_outside_helper':missing,'maximum_paired_front_gap_change_m':max_change,'samples':gaps,'scope':'Selected aperture samples only; does not certify contact, full coverage or self-intersection.'})
    return delta,records,coverage


def metrics(skin,ps):
    ids={v.value:i for i,v in enumerate(skin.data.attributes['source_vertex_index'].data)};r={}
    for side,rings in SELECT['eyes'].items():
        q=[ps[ids[i]] for i in rings['aperture']['source_indices']];outer=max(q,key=lambda p:abs(p.x));inner=min(q,key=lambda p:abs(p.x))
        r[side]={'width_m':max(p.x for p in q)-min(p.x for p in q),'height_m':max(p.z for p in q)-min(p.z for p in q),'outer_minus_inner_height_m':outer.z-inner.z,'outer':list(outer),'inner':list(inner)}
    return r

def build():
    assert sha(INPUT)==PARAM['input_sha256'];bpy.ops.wm.open_mainfile(filepath=str(INPUT));baseline=snapshot();image_hashes=prior.image_hashes();before={o.name:points(o) for o in meshes()};skin=next(o for o in meshes() if 'head_skin' in o.name)
    delta,records,coverage=make_deltas(skin,before[skin.name]);basis=skin.data.shape_keys.key_blocks[0];key=skin.shape_key_add(name=KEY);key.relative_key=basis
    for a,b in zip(basis.data,key.data):b.co=a.co
    for i,d in delta.items():key.data[i].co+=d
    key.value=PARAM['key_value'];assert snapshot_without_new(snapshot())==snapshot_without_new(baseline)
    stats=prior.prior.prior.prior.audit(before)
    failures=[];after=points(skin)
    for face in skin.data.polygons:
        ids=list(face.vertices)
        for j in range(1,len(ids)-1):
            tri=[ids[0],ids[j],ids[j+1]];a,b,c=[before[skin.name][i] for i in tri];d,e,f=[after[i] for i in tri]
            n=(b-a).cross(c-a);nn=(e-d).cross(f-d)
            if nn.length<1e-10 or (n.length>1e-10 and nn.length>1e-10 and n.dot(nn)<=0):
                failures.append({'face':face.index,'local_vertex_indices':tri,'source_indices':[skin.data.attributes['source_vertex_index'].data[i].value for i in tri],'before':[list(before[skin.name][i]) for i in tri],'after':[list(after[i]) for i in tri],'normal_dot':n.dot(nn),'after_normal_length':nn.length})
    (HERE/'geometry_audit.json').write_text(json.dumps({'stats':stats,'failing_skin_fans':failures},indent=2)+'\n')
    print('LOCAL_AUDIT',json.dumps(stats),flush=True)
    for r in stats.values():assert r['new_flipped_fan_triangles']==0 and r['degenerate_fan_triangles']==0 and r['nonfinite_coordinates']==0
    assert prior.image_hashes()==image_hashes
    OUT.mkdir(exist_ok=True)
    for view in ['front','three_quarter','three_quarter_opposite','screen_left_profile','screen_right_profile','game_high_angle']:
        render(view,'after_'+view)
    set_key(0);render('front','before_front');set_key(PARAM['key_value'])
    # Neutral material comparison uses the preserved clay material, no new texture authoring.
    mats={o.name:o.data.materials[0] for o in meshes()}
    clay_name=next(o for o in meshes() if 'head_skin' in o.name).get('B0304_original_material')
    assert clay_name in bpy.data.materials
    for o in meshes():o.data.materials[0]=bpy.data.materials[clay_name]
    set_key(0);render('front','clay_before_front');set_key(PARAM['key_value'])
    for view in ['front','three_quarter','three_quarter_opposite']:render(view,'clay_after_'+view)
    for o in meshes():o.data.materials[0]=mats[o.name]
    prior.prior.prior.prior.previous.original.utils.set_view('three_quarter')
    bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT),compress=True)
    report={'input_sha256':sha(INPUT),'output_sha256':sha(OUTPUT),'parameters':PARAM,'baseline_snapshot':baseline,'saved_snapshot':snapshot(),'old_controls_topology_all_uv_unchanged':True,'active_packed_image_hashes':image_hashes,'images_unchanged':True,'before_metrics':metrics(skin,before[skin.name]),'after_metrics':metrics(skin,points(skin)),'local_change_audit':stats,'helper_gap_sample_audit':coverage,'paid_submissions':0,'spent_credits':0,'game_integration':False,'scope':'Local control shape/persistence review; not likeness/producer, full contact/intersection, rig or runtime acceptance.'}
    (HERE/'build_result.json').write_text(json.dumps(report,indent=2)+'\n')
    with (HERE/'feature_samples.csv').open('w',newline='') as f:
        w=csv.writer(f,lineterminator='\n');w.writerow(['region','loop','source_index','local_index','before_x','before_y','before_z','after_x','after_y','after_z','delta_x','delta_y','delta_z'])
        actual=points(skin)
        for r in records:
            i=r['local_index'];a=before[skin.name][i];z=actual[i]
            w.writerow([r['region'],r['loop'],r['source_index'],i,*a,*z,*(z-a)])
    print('LOCAL_EYE_TRIAL_BUILT',json.dumps(stats))

def verify():
    r=json.loads((HERE/'build_result.json').read_text());assert sha(INPUT)==r['input_sha256'] and sha(OUTPUT)==r['output_sha256'];bpy.ops.wm.open_mainfile(filepath=str(OUTPUT))
    assert snapshot()==r['saved_snapshot'] and snapshot_without_new(snapshot())==snapshot_without_new(r['baseline_snapshot']) and prior.image_hashes()==r['active_packed_image_hashes']
    set_key(0);before={o.name:points(o) for o in meshes()};set_key(PARAM['key_value']);assert prior.prior.prior.prior.audit(before)==r['local_change_audit']
    skin=next(o for o in meshes() if 'head_skin' in o.name);after=points(skin);old=before[skin.name]
    assert all(a.x==b.x and a.y==b.y for a,b in zip(old,after))
    nose=[i for i,p in enumerate(old) if abs(p.x)<.016 and .075<p.z<.10]
    mouth=[i for i,p in enumerate(old) if abs(p.x)<.03 and .05<p.z<.08]
    assert all((after[i]-old[i]).length==0 for i in nose+mouth)
    ids={v.value:i for i,v in enumerate(skin.data.attributes['source_vertex_index'].data)};landmarks={}
    for side,rings in SELECT['eyes'].items():
        landmarks[side]=[{'source_index':i,'before':list(old[ids[i]]),'after':list(after[ids[i]])} for i in rings['aperture']['source_indices']]
    (HERE/'aperture_landmarks.json').write_text(json.dumps({'scope':'Existing control-loop3D coordinates, not calibrated source fit or visible-render aperture edges.','eyes':landmarks},indent=2)+'\n')
    (HERE/'protected_regions.json').write_text(json.dumps({'all_skin_x_y_coordinates_unchanged':True,'nose_control_vertices_locked':len(nose),'mouth_control_vertices_locked':len(mouth),'maximum_locked_displacement_m':0,'eye_helper_geometry_unchanged':True},indent=2)+'\n')
    # Export actual reopened evaluated coordinates, including requested support below audit threshold.
    with (HERE/'feature_samples.csv').open() as f:rows=list(csv.DictReader(f))
    above=0
    with (HERE/'feature_samples.csv').open('w',newline='') as f:
        w=csv.writer(f,lineterminator='\n');w.writerow(['region','loop','source_index','local_index','before_x','before_y','before_z','after_x','after_y','after_z','delta_x','delta_y','delta_z'])
        for row in rows:
            i=int(row['local_index']);a=old[i];b=after[i];d=b-a;above+=d.length>1e-8
            w.writerow([row['region'],row['loop'],row['source_index'],i,*a,*b,*d])
    assert above==r['local_change_audit'][skin.name]['changed_vertices']
    (HERE/'csv_verification.json').write_text(json.dumps({'requested_support_samples':len(rows),'measured_changed_above_threshold':above,'audit_threshold_working_m':1e-8,'requested_samples_at_or_below_threshold':len(rows)-above,'coordinates_from_reopened_evaluated_controls':True,'note':'One requested support displacement is at/below audit threshold after floating-point key evaluation; it remains inCSV, not counted as a changed vertex.'},indent=2)+'\n')
    assert not bpy.data.libraries and not any(o.type=='ARMATURE' for o in bpy.context.scene.objects)
    assert all(i.packed_file for i in bpy.data.images if i.source=='FILE' and i.users)
    render('three_quarter','after_three_quarter_reopened')
    (HERE/'reopen_result.json').write_text(json.dumps({'output_sha256':sha(OUTPUT),'old_controls_topology_all_uv_unchanged':True,'new_key_preserved':True,'active_packed_images_identical':True,'local_change_audit_identical':True,'input_unchanged':True,'external_blend_dependencies':0,'rig_objects':0,'scope':'Persistence and selected control geometry only; not visual/rig/game/device approval.'},indent=2)+'\n');print('LOCAL_EYE_TRIAL_REOPENED')

if __name__=='__main__':{'build':build,'verify':verify}[sys.argv[sys.argv.index('--')+1]]()
