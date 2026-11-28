"""Continue the existing head with reversible contour/cavity controls, no new mesh."""
import array
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
    if not helper:
        crease=gaussian(dx,p.z-e["crease_center_z"],.025,e["crease_sigma_z"])*smoothstep(.058,.073,-p.y)*smoothstep(.008,.020,abs(p.x))
        dy=max(-e["crease_max_displacement"],min(e["crease_max_displacement"],(e["crease_plane_y"]-p.y)*e["crease_fraction"]))
        result.y+=dy*crease
    return result


def adjacency(o):
    links=[set() for _ in o.data.vertices]
    for f in o.data.polygons:
        for a,b in zip(f.vertices,list(f.vertices[1:])+[f.vertices[0]]):
            links[a].add(b);links[b].add(a)
    return links


def nose_deltas(o,points):
    n=PARAM["nose"];links=adjacency(o);smoothed=[p.copy() for p in points]
    weights=[gaussian(abs(p.x)-n["wing_center_x"],p.z-n["wing_center_z"],n["sigma_x"],n["sigma_z"])*smoothstep(.070,.086,-p.y) for p in points]
    for _ in range(n["smooth_iterations"]):
        updated=[]
        for i,p in enumerate(smoothed):
            if not links[i]:updated.append(p.copy());continue
            avg=sum((smoothed[j] for j in links[i]),Vector())/len(links[i])
            # Preserve side-to-side topology and overall nose silhouette; soften local cavities.
            updated.append(p+Vector((0,(avg.y-p.y)*weights[i]*n["smooth_fraction"],(avg.z-p.z)*weights[i]*n["smooth_fraction"]*.35)))
        smoothed=updated
    result=[]
    for p,q,w in zip(points,smoothed,weights):
        result.append(q-p+Vector((-p.x*n["width_fraction"]*w,n["wing_depth_reduction"]*w,0)))
    return result


def build_geometry():
    assert sha(INPUT)==INPUT_SHA
    bpy.ops.wm.open_mainfile(filepath=str(INPUT))
    baseline=snapshot();old_points={o.name:list(previous.points(o)) for o in meshes()}
    for o in meshes():
        skin="head_skin" in o.name;ps=old_points[o.name];ns=nose_deltas(o,ps) if skin else None
        basis=o.data.shape_keys.key_blocks[0]
        for name in KEYS:
            key=o.shape_key_add(name=name);key.relative_key=basis
            for a,b in zip(basis.data,key.data):b.co=a.co
        for i,p in enumerate(ps):
            deltas=[eye_delta(p,helper=not skin),Vector(),Vector(),Vector()]
            if skin:
                deltas[1]=ns[i]
                mouth=PARAM["mouth"];w=gaussian(p.x,p.z-mouth["center_z"],mouth["sigma_x"],mouth["sigma_z"])*smoothstep(.055,.078,-p.y)
                curve=mouth["center_rise"]*math.exp(-.5*(p.x/.009)**2)-mouth["corner_drop"]*(1-math.exp(-.5*(p.x/.016)**2))
                deltas[2]=Vector((0,mouth["depth_reduction"]*w,(-(p.z-mouth["center_z"])*mouth["vertical_contraction"]+curve)*w))
                jaw=PARAM["jaw"];w=math.exp(-.5*((p.z-jaw["center_z"])/jaw["sigma_z"])**2)*smoothstep(.005,.045,-p.y)
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
    report={"input_sha256":INPUT_SHA,"output_sha256":sha(OUTPUT),"parameters":PARAM,"old_controls_uv_topology_preserved":True,"baseline_snapshot":baseline,"saved_snapshot":snapshot(),"local_change_audit":stats,"scope":"Local control geometry/persistence; no self-intersection, deformed-eye, likeness, rig or runtime PASS","new_source_assets":0,"paid_submissions":0,"spent_credits":0,"game_integration":False}
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
