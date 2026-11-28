"""Local existing-topology lid-rim/gap refinement, no new source mesh or artwork."""
import array
import csv
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
INPUT=HERE.parent/"head_refinement_v2/viya_head_contours.blend"
OUTPUT=HERE/"viya_head_rims.blend"
REVIEW=HERE/"review"
SELECT=json.loads((HERE/"loop_selection.json").read_text())
PARAM=json.loads((HERE/"parameters.json").read_text())
KEYS=["R3_LidRim","R3_MouthCorner"]
spec=importlib.util.spec_from_file_location("previous_contours",HERE.parent/"head_refinement_v2/refine_contours.py")
prior=importlib.util.module_from_spec(spec);spec.loader.exec_module(prior)
prior.previous.original.utils.OUT=REVIEW


def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()


def meshes():return sorted([o for o in bpy.context.scene.objects if o.type=="MESH"],key=lambda o:o.name)


def points(o):return list(prior.previous.points(o))


def digest(values,kind="f"):
    return hashlib.sha256(array.array(kind,values).tobytes()).hexdigest()


def snapshot(exclude_new=False):
    result={}
    for o in meshes():
        m=o.data
        result[o.name]={"vertices":len(m.vertices),"faces":len(m.polygons),"topology":digest([v for f in m.polygons for v in f.vertices],"I"),"source_indices":digest([v.value for v in m.attributes["source_vertex_index"].data],"i"),"uv":digest([v for uv in m.uv_layers[0].data for v in uv.uv]),"keys":{k.name:{"positions":digest([v for p in k.data for v in p.co]),"value":k.value,"relative":k.relative_key.name} for k in m.shape_keys.key_blocks if not exclude_new or k.name not in KEYS}}
    return result


def adjacency(o):
    links=[set() for _ in o.data.vertices]
    for f in o.data.polygons:
        ids=list(f.vertices)
        for a,b in zip(ids,ids[1:]+ids[:1]):links[a].add(b);links[b].add(a)
    return links


def ids_of(r,mapping):return [mapping[i] for i in r["source_indices"]]


def eyelid_deltas(o,ps):
    ids={v.value:i for i,v in enumerate(o.data.attributes["source_vertex_index"].data)}
    links=adjacency(o);delta={};records=[];locked=[]
    for side,rings in SELECT["eyes"].items():
        local={name:ids_of(r,ids) for name,r in rings.items()}
        aperture=local["aperture"];locked+=aperture
        assert len(aperture)==28
        mappings={"aperture":{i:i for i in aperture}}
        for name,r in rings.items():
            loop=local[name]
            assert len(loop)==28 and all(b in links[a] for a,b in zip(loop,loop[1:]+loop[:1])),name
            if name=="aperture":continue
            parent=r["radial_parent"];parent_set=set(local[parent]);mapping={}
            for v in loop:
                neighbors=links[v]&parent_set;assert len(neighbors)==1,(name,v,neighbors)
                mapping[v]=mappings[parent][next(iter(neighbors))]
            assert len(set(mapping.values()))==28
            mappings[name]=mapping;amount=r["toward_aperture_fraction"]
            lengths=[]
            for v,target in mapping.items():
                assert v not in delta;delta[v]=(ps[target]-ps[v])*amount
                lengths.append((ps[v]-ps[target]).length)
            records.append({"side":side,"loop":name,"vertices":len(loop),"radial_map_bijective":True,"mean_distance_to_matched_aperture_before_m":sum(lengths)/28,"mean_distance_after_m":sum(lengths)/28*(1-amount),"fraction_toward_aperture":amount})
    assert not set(locked)&set(delta)
    return delta,records,locked


def mouth_deltas(o,ps):
    ids={v.value:i for i,v in enumerate(o.data.attributes["source_vertex_index"].data)}
    links=adjacency(o);delta={};records=[]
    for name,r in SELECT["mouth"].items():
        loop=ids_of(r,ids);assert len(loop)==38 and all(b in links[a] for a,b in zip(loop,loop[1:]+loop[:1]))
        # Split the actual closed edge loop into upper/lower paths at its X extrema.
        imin=min(range(38),key=lambda i:ps[loop[i]].x);rot=loop[imin:]+loop[:imin]
        imax=max(range(38),key=lambda i:ps[rot[i]].x)
        a,b=rot[:imax+1],list(reversed(rot[imax:]+[rot[0]]))
        assert set(a)|set(b)==set(loop)
        dzs=[]
        for v in loop:
            other=b if v in a[1:-1] else a
            if v in [rot[0],rot[imax]]:mid=ps[v].z
            else:
                partner=min(other,key=lambda w:abs(ps[v].x-ps[w].x))
                mid=(ps[v].z+ps[partner].z)/2
            x=abs(ps[v].x);t=max(0,min(1,(x-PARAM["mouth_corner_support_start_x_m"])/(PARAM["mouth_corner_support_full_x_m"]-PARAM["mouth_corner_support_start_x_m"])))
            lift=PARAM["mouth_corner_lift_m"]*t*t*(3-2*t)
            dz=(mid-ps[v].z)*r["vertical_gap_contraction"]+lift
            assert v not in delta;delta[v]=Vector((0,0,dz));dzs.append(dz)
        records.append({"loop":name,"vertices":38,"gap_contraction_fraction":r["vertical_gap_contraction"],"max_abs_z_delta_m":max(map(abs,dzs))})
    return delta,records


def switches(value):
    for o in meshes():
        for key in KEYS:
            if key in o.data.shape_keys.key_blocks:o.data.shape_keys.key_blocks[key].value=PARAM["new_control_values"][key]*value


def render(view,name):
    if view!="three_quarter_opposite":
        prior.previous.original.utils.render(view,name)
        return
    s=bpy.context.scene;c=s.camera;center=Vector((0,0,.104))
    c.location=(-.72,-1,.104);c.rotation_euler=(center-c.location).to_track_quat("-Z","Y").to_euler()
    s.render.filepath=str(REVIEW/(name+".png"));bpy.ops.render.render(write_still=True)


def build():
    assert sha(INPUT)==SELECT["input_sha256"]
    bpy.ops.wm.open_mainfile(filepath=str(INPUT));baseline=snapshot();old={o.name:points(o) for o in meshes()}
    skin=next(o for o in meshes() if "head_skin" in o.name);ps=old[skin.name]
    lids,lid_report,locked=eyelid_deltas(skin,ps);mouth,mouth_report=mouth_deltas(skin,ps)
    assert not set(lids)&set(mouth)
    basis=skin.data.shape_keys.key_blocks[0]
    for name,changes in zip(KEYS,[lids,mouth]):
        key=skin.shape_key_add(name=name);key.relative_key=basis
        for a,b in zip(basis.data,key.data):b.co=a.co
        for i,d in changes.items():key.data[i].co+=d
        key.value=PARAM["new_control_values"][name]
    assert snapshot(exclude_new=True)==baseline
    after_skin=points(skin)
    assert all((after_skin[i]-ps[i]).length<1e-8 for i in locked)
    stats=prior.audit(old)
    for s in stats.values():assert not s["new_flipped_fan_triangles"] and not s["degenerate_fan_triangles"]
    REVIEW.mkdir(exist_ok=True)
    for view in ["front","screen_left_profile","screen_right_profile","three_quarter"]:render(view,"after_"+view)
    for view in ["three_quarter_opposite","game_high_angle"]:
        switches(0);render(view,"before_"+view)
        switches(1);render(view,"after_"+view)
    prior.previous.original.utils.set_view("three_quarter")
    bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT),compress=True)
    report={"input_sha256":sha(INPUT),"output_sha256":sha(OUTPUT),"parameters":PARAM,"loop_selection_sha256":sha(HERE/"loop_selection.json"),"baseline_snapshot":baseline,"saved_snapshot":snapshot(),"aperture_vertices_locked":len(locked),"aperture_max_displacement_m":0,"lid_radial_measurements":lid_report,"mouth_local_measurements":mouth_report,"local_change_audit":stats,"new_external_assets":0,"paid_submissions":0,"spent_credits":0,"game_integration":False,"scope":"Selected control geometry/persistence only. Not self-intersection/eye-surface-contact/rig/runtime/producer-art acceptance."}
    (HERE/"build_result.json").write_text(json.dumps(report,indent=2)+"\n")
    print("BUILD_COMPLETE",json.dumps({"aperture_locked":len(locked),"stats":stats}))


def verify():
    r=json.loads((HERE/"build_result.json").read_text());assert sha(INPUT)==r["input_sha256"] and sha(OUTPUT)==r["output_sha256"]
    assert sha(HERE/"loop_selection.json")==r["loop_selection_sha256"]
    bpy.ops.wm.open_mainfile(filepath=str(OUTPUT));assert snapshot()==r["saved_snapshot"] and snapshot(True)==r["baseline_snapshot"]
    assert not bpy.data.libraries and not any(o.type=="ARMATURE" for o in bpy.context.scene.objects)
    switches(0);old={o.name:points(o) for o in meshes()};switches(1);assert prior.audit(old)==r["local_change_audit"]
    skin=next(o for o in meshes() if "head_skin" in o.name);after=points(skin)
    mapping={v.value:i for i,v in enumerate(skin.data.attributes["source_vertex_index"].data)}
    with (HERE/"feature_samples.csv").open("w",newline="") as f:
        w=csv.writer(f,lineterminator="\n");w.writerow(["region","loop","source_index","local_index","locked","before_x","before_y","before_z","after_x","after_y","after_z","displacement_m"])
        groups=[(side,name,loop) for side,rings in SELECT["eyes"].items() for name,loop in rings.items()]
        groups +=[("mouth",name,loop) for name,loop in SELECT["mouth"].items()]
        for region,name,loop in groups:
            for source in loop["source_indices"]:
                i=mapping[source];a=old[skin.name][i];b=after[i]
                w.writerow([region,name,source,i,name=="aperture",*[format(v,".10f") for v in a],*[format(v,".10f") for v in b],format((b-a).length,".10f")])
    render("three_quarter","after_three_quarter_reopened")
    (HERE/"reopen_result.json").write_text(json.dumps({"output_sha256":sha(OUTPUT),"all_old_and_new_controls_equal":True,"old_uv_topology_source_indices_equal":True,"deformation_audit_equal":True,"input_unchanged":True,"external_blend_dependencies":0,"scope":"Independent current-file persistence; not artwork acceptance"},indent=2)+"\n")
    print("REOPEN_COMPLETE")


if __name__=="__main__":
    {"build":build,"verify":verify}[sys.argv[sys.argv.index("--")+1]]()
