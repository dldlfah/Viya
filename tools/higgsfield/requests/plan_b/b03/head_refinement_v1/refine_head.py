"""B-03-03: reversible local eye/nose/lip form edits on the existing head study.

blender -b --python refine_head.py -- inspect
blender -b --python refine_head.py -- build
blender -b --python refine_head.py -- verify
"""
import array
import gzip
import hashlib
import importlib.util
import json
import math
import sys
from pathlib import Path
import bpy
from mathutils import Vector

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[5]
PARENT=HERE.parent/"head_shape_v1/cc0_topology_trial"
INPUT=PARENT/"cc0_head_topology_study.blend"
OUT=HERE/"review"
BLEND=HERE/"viya_head_refinement.blend"
PARAM=json.loads((HERE/"refinement_parameters.json").read_text())
spec=importlib.util.spec_from_file_location("original_head_builder",PARENT/"build_topology.py")
original=importlib.util.module_from_spec(spec);spec.loader.exec_module(original)
original.utils.OUT=OUT
KEYS=["REFINE_Eyelids","REFINE_Nose","REFINE_Lips"]


def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def digest(values):return hashlib.sha256(array.array("f",values).tobytes()).hexdigest()


def source_snapshot():
    result={}
    for o in bpy.context.scene.objects:
        if o.type!="MESH":continue
        m=o.data
        result[o.name]={"vertices":len(m.vertices),"faces":len(m.polygons),"basis":digest(c for p in m.shape_keys.key_blocks[0].data for c in p.co),"previous_reference":digest(c for p in m.shape_keys.key_blocks[1].data for c in p.co),"uv":digest(c for p in m.uv_layers[0].data for c in p.uv),"source_indices":[x.value for x in m.attributes["source_vertex_index"].data],"topology":hashlib.sha256(array.array("I",[i for p in m.polygons for i in p.vertices]).tobytes()).hexdigest()}
    return result


def full_snapshot():
    r=source_snapshot()
    for o in bpy.context.scene.objects:
        if o.type!="MESH":continue
        r[o.name]["refinements"]={k:{"positions":digest(c for p in o.data.shape_keys.key_blocks[k].data for c in p.co),"value":o.data.shape_keys.key_blocks[k].value,"relative":o.data.shape_keys.key_blocks[k].relative_key.name} for k in KEYS}
    return r


def read_targets():
    registry=json.loads((HERE/"source_registry.json").read_text())
    total={};records=[]
    for asset in registry["assets"]:
        f=HERE/"source"/asset["name"];b=f.read_bytes()
        assert hashlib.sha1(b"blob "+str(len(b)).encode()+b"\0"+b).hexdigest()==asset["git_blob_sha"]
        weight=PARAM["eye_targets"].get(asset["name"],0)
        selected={}
        for l in gzip.decompress(b).decode().splitlines():
            a=l.split()
            if len(a)==4 and not a[0].startswith("#"):
                i=int(a[0]);d=Vector(tuple(map(float,a[1:])));selected[i]=d
                if weight:total[i]=total.get(i,Vector())+d*weight
        records.append({"file":asset["name"],"git_blob_sha":asset["git_blob_sha"],"sha256":sha(f),"weight":weight,"source_vertices":len(selected)})
    return total,records


def load_input():
    expected=json.loads((PARENT/"reopen_result.json").read_text())["blend_sha256"]
    assert sha(INPUT)==expected
    bpy.ops.wm.open_mainfile(filepath=str(INPUT))
    return source_snapshot()


def points(o):
    m=o.data;basis=m.shape_keys.key_blocks[0]
    for i,p in enumerate(basis.data):
        v=p.co.copy()
        for key in list(m.shape_keys.key_blocks)[1:]:
            if key.value:v+=(key.data[i].co-key.relative_key.data[i].co)*key.value
        yield v


def deformation_audit(o):
    m=o.data;before=[p.co.copy() for p in m.shape_keys.key_blocks[1].data];after=list(points(o))
    flipped=0;degenerate=0
    for poly in m.polygons:
        ids=list(poly.vertices)
        for j in range(1,len(ids)-1):
            a,b,c=[before[i] for i in (ids[0],ids[j],ids[j+1])]
            u,v,w=[after[i] for i in (ids[0],ids[j],ids[j+1])]
            n=(b-a).cross(c-a);nn=(v-u).cross(w-u)
            degenerate+=nn.length<1e-10
            flipped+=n.length>1e-10 and nn.length>1e-10 and n.dot(nn)<=0
    changed=[(i,(b-a).length) for i,(a,b) in enumerate(zip(before,after)) if (b-a).length>1e-8]
    return {"changed_vertices":len(changed),"maximum_combined_displacement_m":max((v for _,v in changed),default=0),"flipped_fan_triangles":flipped,"degenerate_fan_triangles":degenerate,"changed_vertex_ids":[i for i,_ in changed]}


def construct(inspect=False):
    baseline=load_input();delta,records=read_targets()
    _,morphed,_,_,centers=original.parse_source()
    eye_height=(centers[0].y+centers[1].y)/2;eye_x=(abs(centers[0].x)+abs(centers[1].x))*.05
    result={}
    for o in [o for o in bpy.context.scene.objects if o.type=="MESH"]:
        m=o.data;group="skin" if "head_skin" in o.name else "eye"
        previous=m.shape_keys.key_blocks[1]
        indices=baseline[o.name]["source_indices"]
        for i,src in enumerate(indices):
            p=original.adapt(original.world_point(morphed[src],eye_height),group,eye_x)
            assert (p-previous.data[i].co).length<1e-6,(o.name,src)
        if inspect:
            result[o.name]={"regional_source_vertices_in_trial":sum(i in delta for i in indices)}
            if group=="skin":
                result[o.name]["midline_front_samples"]=[]
                for z in [.055,.061,.067,.073,.079,.085,.091,.097,.103,.109]:
                    ps=[p.co for p in previous.data if abs(p.co.x)<.006 and abs(p.co.z-z)<.003]
                    if ps:result[o.name]["midline_front_samples"].append({"z":z,"frontmost":list(min(ps,key=lambda p:p.y))})
            continue
        for key_name in KEYS:
            key=o.shape_key_add(name=key_name);key.relative_key=previous
            for a,b in zip(previous.data,key.data):b.co=a.co
        for i,src in enumerate(indices):
            p=previous.data[i].co.copy()
            if src in delta:
                pnew=original.adapt(original.world_point(morphed[src]+delta[src],eye_height),group,eye_x)
                m.shape_keys.key_blocks[KEYS[0]].data[i].co=pnew
            if group!="skin":continue
            front=min(1,max(0,(-p.y-.035)/.035))
            n=PARAM["nose"]
            weight=math.exp(-.5*(p.x/n["sigma_x_m"])**2-.5*((p.z-n["center_z_m"])/n["sigma_z_m"])**2)*front
            if abs(p.x)<.060 and .045<p.z<.145 and p.y<-.035:
                dy=min(n["max_depth_reduction_m"],max(0,n["projection_plane_y_m"]-p.y)*n["depth_fraction"])*weight
                m.shape_keys.key_blocks[KEYS[1]].data[i].co+=Vector((-p.x*n["width_reduction_fraction"]*weight,dy,0))
            l=PARAM["lips"]
            weight=math.exp(-.5*(p.x/l["sigma_x_m"])**2-.5*((p.z-l["center_z_m"])/l["sigma_z_m"])**2)*front
            if abs(p.x)<.055 and .040<p.z<.090 and p.y<-.035:
                m.shape_keys.key_blocks[KEYS[2]].data[i].co+=Vector((0,l["depth_reduction_m"]*weight,-(p.z-l["center_z_m"])*l["vertical_contraction_fraction"]*weight))
        for name in KEYS:m.shape_keys.key_blocks[name].value=1
        result[o.name]=deformation_audit(o)
    assert source_snapshot()==baseline,"Source basis/UV/topology changed"
    return baseline,records,result


def switches(eye,nose,lips):
    for o in bpy.context.scene.objects:
        if o.type=="MESH":
            for name,value in zip(KEYS,(eye,nose,lips)):o.data.shape_keys.key_blocks[name].value=value


def render(view,filename):original.utils.render(view,filename)


def build():
    OUT.mkdir(exist_ok=True)
    baseline,records,audit=construct()
    for result in audit.values():assert result["degenerate_fan_triangles"]==0 and result["flipped_fan_triangles"]==0,result
    for tag,s in [("before",(0,0,0)),("eyes_only",(1,0,0)),("nose_lips_only",(0,1,1)),("combined",(1,1,1))]:
        switches(*s);render("front",tag+"_front")
    for view in ["screen_left_profile","screen_right_profile","three_quarter","game_high_angle"]:
        switches(0,0,0);render(view,"before_"+view)
        switches(1,1,1);render(view,"combined_"+view)
    switches(1,1,1);original.utils.set_view("three_quarter")
    bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(BLEND),compress=True)
    report={"stage":"B-03-03 local refinement, not accepted VIYA","input_blend_sha256":sha(INPUT),"parameters":PARAM,"new_target_assets":records,"source_snapshot":baseline,"refinement_snapshot":full_snapshot(),"combined_deformation_audit":audit,"source_basis_uv_topology_preserved":True,"external_generated_candidates_loaded":False,"paid_submissions":0,"spent_credits":0,"game_integration":False}
    (HERE/"build_result.json").write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n")
    print("REFINEMENT_BUILD_COMPLETE",json.dumps({"blend_bytes":BLEND.stat().st_size,"audit":{name:{k:v for k,v in r.items() if k!="changed_vertex_ids"} for name,r in audit.items()}}))


def verify():
    report=json.loads((HERE/"build_result.json").read_text());assert sha(INPUT)==report["input_blend_sha256"]
    bpy.ops.wm.open_mainfile(filepath=str(BLEND));assert full_snapshot()==report["refinement_snapshot"]
    audit={o.name:deformation_audit(o) for o in bpy.context.scene.objects if o.type=="MESH"}
    assert audit==report["combined_deformation_audit"]
    for x in audit.values():assert not x["degenerate_fan_triangles"] and not x["flipped_fan_triangles"]
    assert not bpy.data.libraries and not any(o.type=="ARMATURE" for o in bpy.context.scene.objects)
    render("three_quarter","combined_three_quarter_reopened")
    (HERE/"reopen_result.json").write_text(json.dumps({"all_snapshots_equal":True,"deformation_audit_equal":True,"input_blend_unchanged":True,"no_external_library":True,"blend_sha256":sha(BLEND),"scope":"Editable shape-key/persistence integrity, not likeness/rig/runtime acceptance"},indent=2)+"\n")


if __name__=="__main__":
    mode=sys.argv[sys.argv.index("--")+1]
    if mode=="inspect":
        _,records,audit=construct(True);print("REGION_INSPECTION",json.dumps({"targets":records,"audit":{name:{k:v for k,v in r.items() if k!="changed_vertex_ids"} for name,r in audit.items()}}))
    else:{"build":build,"verify":verify}[mode]()
