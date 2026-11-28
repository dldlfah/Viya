"""Continue the existing head with reversible contour/cavity controls, no new mesh."""
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

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[5]
INPUT = HERE.parent / "head_refinement_v1/viya_head_refinement.blend"
INPUT_SHA = "80a4c9b43a0acb9f8f865f619d241d61b2efaf50dea209ec9878d2e7266acdf6"
OUTPUT = HERE / "viya_head_contours.blend"
REVIEW = HERE / "review"
PARAM = json.loads((HERE / "parameters.json").read_text())
KEYS = ["R2_EyeContour", "R2_NoseSimplify", "R2_MouthLine", "R2_JawContour"]
spec = importlib.util.spec_from_file_location("previous_refinement", HERE.parent / "head_refinement_v1/refine_head.py")
previous = importlib.util.module_from_spec(spec)
spec.loader.exec_module(previous)
previous.original.utils.OUT = REVIEW


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def digest_floats(values):
    return hashlib.sha256(array.array("f", values).tobytes()).hexdigest()


def meshes():
    return sorted((o for o in bpy.context.scene.objects if o.type == "MESH"), key=lambda o:o.name)


def snapshot(old_only=False):
    result = {}
    for o in meshes():
        m = o.data
        result[o.name] = {
            "vertices": len(m.vertices), "faces":len(m.polygons),
            "topology":hashlib.sha256(array.array("I",[i for f in m.polygons for i in f.vertices]).tobytes()).hexdigest(),
            "uv":digest_floats(v for uv in m.uv_layers[0].data for v in uv.uv),
            "source_indices":hashlib.sha256(array.array("i",[v.value for v in m.attributes["source_vertex_index"].data]).tobytes()).hexdigest(),
            "keys":{k.name:{"positions":digest_floats(v for p in k.data for v in p.co),"value":k.value,"relative":k.relative_key.name} for k in m.shape_keys.key_blocks if not old_only or k.name not in KEYS},
            "modifiers":[{"name":m.name,"type":m.type,"show_viewport":m.show_viewport,"show_render":m.show_render} for m in o.modifiers],
        }
    return result


def gaussian(dx,dz,sx,sz):
    return math.exp(-.5*(dx/sx)**2-.5*(dz/sz)**2)


def smoothstep(a,b,x):
    t=max(0,min(1,(x-a)/(b-a)))
    return t*t*(3-2*t)


def eye_delta(p,helper=False):
    e=PARAM["eye"];side=1 if p.x>=0 else -1
    dx=abs(p.x)-e["center_x"];dz=p.z-e["center_z"]
    weight=math.exp(-((dx/e["radius_x"])**4+(dz/e["radius_z"])**4))
    weight*=1 if helper else smoothstep(.040,.060,-p.y)*smoothstep(.006,.016,abs(p.x))
    result=Vector((side*dx*e["width_fraction"],0,dz*e["height_fraction"]+e["outer_corner_rise"]*math.tanh(dx/.009)))*weight
    return result


def adjacency(o):
    links=[set() for _ in o.data.vertices]
    for f in o.data.polygons:
        for a,b in zip(f.vertices,list(f.vertices[1:])+[f.vertices[0]]):
            links[a].add(b);links[b].add(a)
    return links


def socket_smoothing(o,points):
    e=PARAM["eye"];links=adjacency(o);smoothed=[p.copy() for p in points]
    weights=[gaussian(abs(p.x)-e["center_x"],p.z-e["crease_center_z"],.025,e["crease_sigma_z"])*smoothstep(.058,.073,-p.y)*smoothstep(.008,.020,abs(p.x)) for p in points]
    for _ in range(e["crease_smooth_iterations"]):
        updated=[]
        for i,p in enumerate(smoothed):
            if not links[i]:updated.append(p.copy());continue
            avg=sum((smoothed[j] for j in links[i]),Vector())/len(links[i])
            updated.append(p+Vector((0,(avg.y-p.y)*weights[i]*e["crease_smooth_fraction"],0)))
        smoothed=updated
    return [Vector((0,max(-e["crease_max_displacement"],min(e["crease_max_displacement"],q.y-p.y)),0)) for p,q in zip(points,smoothed)]


def nose_deltas(o,points):
    n=PARAM["nose"];total={}
    registry=json.loads((HERE/"source_registry.json").read_text())
    for r in registry["files"]:
        b=(HERE/"source"/r["file"]).read_bytes()
        assert sha(HERE/"source"/r["file"])==r["sha256"]
        assert hashlib.sha1(b"blob "+str(len(b)).encode()+b"\0"+b).hexdigest()==r["git_blob_sha"]
        weight=n["source_targets"].get(r["file"],0)
        for line in gzip.decompress(b).decode().splitlines():
            a=line.split()
            if len(a)==4 and not a[0].startswith("#"):
                i=int(a[0]);total[i]=total.get(i,Vector())+Vector(tuple(map(float,a[1:])))*weight
    _,morphed,_,_,centers=previous.original.parse_source()
    eye_height=(centers[0].y+centers[1].y)/2;eye_x=(abs(centers[0].x)+abs(centers[1].x))*.05
    result=[]
    for source in o.data.attributes["source_vertex_index"].data:
        i=source.value
        if i not in total:result.append(Vector());continue
        before=previous.original.adapt(previous.original.world_point(morphed[i],eye_height),"skin",eye_x)
        after=previous.original.adapt(previous.original.world_point(morphed[i]+total[i],eye_height),"skin",eye_x)
        result.append(after-before)
    return result


def build_geometry():
    assert sha(INPUT)==INPUT_SHA
    bpy.ops.wm.open_mainfile(filepath=str(INPUT))
    baseline=snapshot();old_points={o.name:list(previous.points(o)) for o in meshes()}
    for o in meshes():
        skin="head_skin" in o.name;ps=old_points[o.name];ns=nose_deltas(o,ps) if skin else None
        smoothing=socket_smoothing(o,ps) if skin else None
        basis=o.data.shape_keys.key_blocks[0]
        for name in KEYS:
            key=o.shape_key_add(name=name);key.relative_key=basis
            for a,b in zip(basis.data,key.data):b.co=a.co
        for i,p in enumerate(ps):
            deltas=[eye_delta(p,helper=not skin),Vector(),Vector(),Vector()]
            if skin:
                deltas[0]+=smoothing[i]
                deltas[1]=ns[i]
                mouth=PARAM["mouth"];w=gaussian(p.x,p.z-mouth["center_z"],mouth["sigma_x"],mouth["sigma_z"])*smoothstep(.055,.078,-p.y)
                curve=mouth["center_rise"]*math.exp(-.5*(p.x/.009)**2)-mouth["corner_drop"]*(1-math.exp(-.5*(p.x/.016)**2))
                deltas[2]=Vector((0,mouth["depth_reduction"]*w,(-(p.z-mouth["center_z"])*mouth["vertical_contraction"]+curve)*w))
                jaw=PARAM["jaw"];w=math.exp(-.5*((p.z-jaw["center_z"])/jaw["sigma_z"])**2)*smoothstep(.005,.045,-p.y)*smoothstep(.005,.020,p.z)
                deltas[3]=Vector((-p.x*jaw["width_fraction"]*w,0,0))
            for name,d in zip(KEYS,deltas):o.data.shape_keys.key_blocks[name].data[i].co+=d
        for name in KEYS:o.data.shape_keys.key_blocks[name].value=1
    assert snapshot(old_only=True)==baseline
    return baseline,old_points


def audit(old_points):
    result={}
    for o in meshes():
        before=old_points[o.name];after=list(previous.points(o));flipped=degenerate=0
        changes=[(i,(a-b).length) for i,(a,b) in enumerate(zip(after,before)) if (a-b).length>1e-8]
        for f in o.data.polygons:
            ids=list(f.vertices)
            for j in range(1,len(ids)-1):
                a,b,c=[before[i] for i in [ids[0],ids[j],ids[j+1]]]
                d,e,f=[after[i] for i in [ids[0],ids[j],ids[j+1]]]
                n=(b-a).cross(c-a);nn=(e-d).cross(f-d)
                degenerate+=nn.length<1e-10
                flipped+=n.length>1e-10 and nn.length>1e-10 and n.dot(nn)<=0
        assert all(math.isfinite(v) for p in after for v in p)
        result[o.name]={"changed_vertices":len(changes),"maximum_displacement_m":max((d for _,d in changes),default=0),"new_flipped_fan_triangles":flipped,"degenerate_fan_triangles":degenerate,"nonfinite_coordinates":0}
    return result


def switches(value):
    for o in meshes():
        for name in KEYS:o.data.shape_keys.key_blocks[name].value=value


def render(view,name):
    previous.original.utils.render(view,name)


def build():
    REVIEW.mkdir(exist_ok=True)
    baseline,old=build_geometry();stats=audit(old)
    for s in stats.values():assert not s["new_flipped_fan_triangles"] and not s["degenerate_fan_triangles"],stats
    for view in ["front","screen_left_profile","screen_right_profile","three_quarter"]:
        switches(1);render(view,"after_"+view)
    switches(1);previous.original.utils.set_view("three_quarter")
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT),compress=True)
    report={"input_sha256":INPUT_SHA,"output_sha256":sha(OUTPUT),"parameters":PARAM,"old_controls_uv_topology_preserved":True,"baseline_snapshot":baseline,"saved_snapshot":snapshot(),"local_change_audit":stats,"scope":"Local control geometry/persistence; no self-intersection, deformed-eye, likeness, rig or runtime PASS","new_source_assets":2,"paid_submissions":0,"spent_credits":0,"game_integration":False}
    (HERE/"build_result.json").write_text(json.dumps(report,indent=2)+"\n")
    print("BUILD_COMPLETE",json.dumps(stats))


def verify():
    r=json.loads((HERE/"build_result.json").read_text());assert sha(INPUT)==r["input_sha256"] and sha(OUTPUT)==r["output_sha256"]
    bpy.ops.wm.open_mainfile(filepath=str(OUTPUT))
    assert snapshot()==r["saved_snapshot"] and snapshot(old_only=True)==r["baseline_snapshot"]
    assert not bpy.data.libraries and not any(o.type=="ARMATURE" for o in bpy.context.scene.objects)
    switches(0);old={o.name:list(previous.points(o)) for o in meshes()};switches(1)
    assert audit(old)==r["local_change_audit"]
    render("three_quarter","after_three_quarter_reopened")
    report={"output_sha256":sha(OUTPUT),"all_old_key_coordinates_values_relatives_and_uv_topology_preserved":True,"all_new_controls_equal_after_reopen":True,"audit_equal":True,"input_unchanged":True,"external_blend_dependencies":0,"scope":"Independent current-file persistence; not artwork acceptance"}
    (HERE/"reopen_result.json").write_text(json.dumps(report,indent=2)+"\n")
    print("REOPEN_COMPLETE")


if __name__=="__main__":
    {"build":build,"verify":verify}[sys.argv[sys.argv.index("--")+1]]()
