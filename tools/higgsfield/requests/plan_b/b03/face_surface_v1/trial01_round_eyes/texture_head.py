"""B-03-04: separate head/eye UV and surface-only authoring on the preserved head."""
import array
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
INPUT=HERE.parent/"head_refinement_v3/viya_head_rims.blend"
INPUT_SHA="aca01d53211b6feb977064dd39217b5358320f0a222f19ffce099e344e14211a"
CHECKPOINT=HERE/"viya_face_uv_checkpoint.blend"
OUTPUT=HERE/"viya_face_surface.blend"
OUT=HERE/"review"
EXCHANGE=ROOT/".local_validation/PLAN_B03_04"
UV_NAME="VIYA_face_surface_uv"
spec=importlib.util.spec_from_file_location("head_source",HERE.parent/"head_refinement_v3/refine_rims.py")
prior=importlib.util.module_from_spec(spec);spec.loader.exec_module(prior)
prior.REVIEW=OUT;prior.prior.previous.original.utils.OUT=OUT


def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()


def digest(values):return hashlib.sha256(array.array("f",values).tobytes()).hexdigest()


def meshes():return prior.meshes()


def render(view,name):prior.render(view,name)


def seams_from_uv(o):
    seen={};result=set();m=o.data;uv=m.uv_layers[0]
    for f in m.polygons:
        ids=list(f.vertices);ls=list(f.loop_indices)
        for j,(a,b) in enumerate(zip(ids,ids[1:]+ids[:1])):
            coords={a:tuple(uv.data[ls[j]].uv),b:tuple(uv.data[ls[(j+1)%len(ls)]].uv)}
            key=tuple(sorted((a,b)));pair=tuple(coords[i] for i in key)
            if key in seen and any(abs(x-y)>1e-6 for u,v in zip(pair,seen[key]) for x,y in zip(u,v)):result.add(key)
            seen[key]=pair
    return result


def unwrap_skin(o):
    seams=seams_from_uv(o);ps=prior.points(o);m=o.data
    temp=bpy.data.meshes.new("Temporary_evaluated_control_for_uv")
    temp.from_pydata(ps,[],[list(f.vertices) for f in m.polygons]);temp.update()
    t=bpy.data.objects.new("Temporary_UV_only",temp);bpy.context.scene.collection.objects.link(t)
    for e in temp.edges:e.use_seam=tuple(sorted(e.vertices)) in seams
    for ob in bpy.context.selected_objects:ob.select_set(False)
    t.select_set(True);bpy.context.view_layer.objects.active=t
    assert "ANGLE_BASED" in bpy.ops.uv.unwrap.get_rna_type().properties["method"].enum_items.keys()
    bpy.ops.object.mode_set(mode="EDIT");bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.unwrap(method="ANGLE_BASED",margin=.008)
    bpy.ops.object.mode_set(mode="OBJECT")
    assert len(temp.loops)==len(m.loops)
    layer=m.uv_layers.new(name=UV_NAME)
    for a,b in zip(temp.uv_layers[0].data,layer.data):b.uv=a.uv
    bpy.data.objects.remove(t,do_unlink=True);bpy.data.meshes.remove(temp)
    return {"method":"ANGLE_BASED on a temporary control mesh in its current evaluated form","retained_original_uv_seam_edges":len(seams),"new_uv_name":UV_NAME}


def unwrap_eye(o):
    ps=prior.points(o);c=sum(ps,Vector())/len(ps)
    r=Vector(tuple(max(abs(p[i]-c[i]) for p in ps) for i in range(3)))
    layer=o.data.uv_layers.new(name=UV_NAME)
    for f in o.data.polygons:
        us=[];vs=[]
        for i in f.vertices:
            p=ps[i]-c;us.append(.5+math.atan2(p.x/r.x,-p.y/r.y)/(2*math.pi));vs.append(.5+math.asin(max(-1,min(1,p.z/r.z)))/math.pi)
        if max(us)-min(us)>.5:us=[u+1 if u<.5 else u for u in us]
        for li,u,v in zip(f.loop_indices,us,vs):layer.data[li].uv=(u,v)
    return {"method":"Ellipsoid longitude/latitude, rear seam; separate eyes, no reflection","center":list(c),"radius":list(r),"new_uv_name":UV_NAME}


def uv_node(nodes):
    n=nodes.new("ShaderNodeUVMap");n.uv_map=UV_NAME;return n


def checker_material():
    mat=bpy.data.materials.new("B0304_UV_Checker");mat.use_nodes=True;n=mat.node_tree.nodes;n.clear();l=mat.node_tree.links
    uv=uv_node(n);tex=n.new("ShaderNodeTexChecker");tex.inputs["Color1"].default_value=(.08,.20,.30,1);tex.inputs["Color2"].default_value=(.65,.85,.90,1);tex.inputs["Scale"].default_value=32
    em=n.new("ShaderNodeEmission");out=n.new("ShaderNodeOutputMaterial");l.new(uv.outputs["UV"],tex.inputs["Vector"]);l.new(tex.outputs["Color"],em.inputs["Color"]);l.new(em.outputs[0],out.inputs["Surface"])
    return mat


def prep():
    assert sha(INPUT)==INPUT_SHA;bpy.ops.wm.open_mainfile(filepath=str(INPUT));baseline=prior.snapshot();records={}
    for o in meshes():
        o["B0304_original_material"]=o.data.materials[0].name
        records[o.name]=unwrap_skin(o) if "head_skin" in o.name else unwrap_eye(o)
        o.data.uv_layers.active=o.data.uv_layers[UV_NAME];o.data.uv_layers[UV_NAME].active_render=True
    assert prior.snapshot()==baseline
    mat=checker_material()
    for o in meshes():o.data.materials.clear();o.data.materials.append(mat)
    OUT.mkdir(exist_ok=True)
    for v in ["front","screen_left_profile","three_quarter","three_quarter_opposite"]:render(v,"checker_"+v)
    prior.prior.previous.original.utils.set_view("three_quarter")
    bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(CHECKPOINT),compress=True)
    data={"objects":{},"features":{}}
    deps=bpy.context.evaluated_depsgraph_get()
    for o in meshes():
        ev=o.evaluated_get(deps);m=ev.to_mesh();m.calc_loop_triangles();uv=m.uv_layers[UV_NAME]
        data["objects"][o.name]={"positions":[list(v.co) for v in m.vertices],"triangles":[list(t.vertices) for t in m.loop_triangles],"triangle_uv":[[list(uv.data[i].uv) for i in t.loops] for t in m.loop_triangles],"original_control_uv":[[list(o.data.uv_layers[0].data[i].uv) for i in f.loop_indices] for f in o.data.polygons],"control_positions":[list(p) for p in prior.points(o)],"control_faces":[list(f.vertices) for f in o.data.polygons],"uv_record":records[o.name]}
        ev.to_mesh_clear()
    skin=next(o for o in meshes() if "head_skin" in o.name);ids={v.value:i for i,v in enumerate(skin.data.attributes["source_vertex_index"].data)};ps=prior.points(skin)
    selection=json.loads((HERE.parent/"head_refinement_v3/loop_selection.json").read_text())
    for side,rings in selection["eyes"].items():data["features"][side]=[list(ps[ids[i]]) for i in rings["aperture"]["source_indices"]]
    for name,loop in selection["mouth"].items():data["features"]["mouth_"+name]=[list(ps[ids[i]]) for i in loop["source_indices"]]
    EXCHANGE.mkdir(exist_ok=True);(EXCHANGE/"bake_mesh.json").write_text(json.dumps(data))
    (HERE/"uv_preparation.json").write_text(json.dumps({"input_sha256":INPUT_SHA,"checkpoint_sha256":sha(CHECKPOINT),"baseline_snapshot":baseline,"uv_methods":records,"old_geometry_controls_original_uv_preserved":True,"original_materials_retained_as_datablocks":True,"scope":"UV preparation/checker, not approved artwork"},indent=2)+"\n")
    print("UV_PREPARED",json.dumps(records))


def painted_material(name,image_path,unlit=False):
    mat=bpy.data.materials.new(name);mat.use_nodes=True;n=mat.node_tree.nodes;n.clear();l=mat.node_tree.links
    uv=uv_node(n);tex=n.new("ShaderNodeTexImage");tex.image=bpy.data.images.load(str(image_path),check_existing=True);tex.image.colorspace_settings.name="sRGB";tex.image.pack();tex.interpolation="Linear";tex.extension="REPEAT"
    l.new(uv.outputs["UV"],tex.inputs["Vector"])
    em=n.new("ShaderNodeEmission");l.new(tex.outputs["Color"],em.inputs["Color"])
    out=n.new("ShaderNodeOutputMaterial")
    if unlit:l.new(em.outputs[0],out.inputs["Surface"])
    else:
        diffuse=n.new("ShaderNodeBsdfPrincipled");diffuse.inputs["Roughness"].default_value=.80;diffuse.inputs["Specular IOR Level"].default_value=.12;l.new(tex.outputs["Color"],diffuse.inputs["Base Color"])
        mix=n.new("ShaderNodeMixShader");mix.inputs[0].default_value=.35;l.new(em.outputs[0],mix.inputs[1]);l.new(diffuse.outputs[0],mix.inputs[2]);l.new(mix.outputs[0],out.inputs["Surface"])
    return mat


def material_snapshot():
    result={}
    for o in meshes():
        layer=o.data.uv_layers[UV_NAME]
        result[o.name]={"new_uv":digest([x for p in layer.data for x in p.uv]),"material":o.data.materials[0].name,"image_nodes":[{"name":node.image.name,"size":list(node.image.size),"colorspace":node.image.colorspace_settings.name,"packed":bool(node.image.packed_file)} for node in o.data.materials[0].node_tree.nodes if node.type=="TEX_IMAGE"]}
    return result


def apply():
    r=json.loads((HERE/"uv_preparation.json").read_text());assert sha(INPUT)==INPUT_SHA
    bpy.ops.wm.open_mainfile(filepath=str(CHECKPOINT));assert prior.snapshot()==r["baseline_snapshot"]
    for o in meshes():
        filename="head_color.png" if "head_skin" in o.name else ("eye_screen_right.png" if "helper-l-eye" in o.name else "eye_screen_left.png")
        mat=painted_material("B0304_"+o.name,HERE/"textures"/filename)
        o.data.materials.clear();o.data.materials.append(mat)
    for v in ["front","screen_left_profile","screen_right_profile","three_quarter","three_quarter_opposite","game_high_angle"]:render(v,"color_"+v)
    lit={o.name:o.data.materials[0] for o in meshes()}
    for o in meshes():
        filename="head_color.png" if "head_skin" in o.name else ("eye_screen_right.png" if "helper-l-eye" in o.name else "eye_screen_left.png")
        o.data.materials[0]=painted_material("B0304_UNLIT_"+o.name,HERE/"textures"/filename,True)
    for v in ["front","three_quarter","three_quarter_opposite"]:render(v,"unlit_"+v)
    for o in meshes():o.data.materials[0]=lit[o.name]
    assert prior.snapshot()==r["baseline_snapshot"]
    prior.prior.previous.original.utils.set_view("three_quarter")
    bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT),compress=True)
    (HERE/"build_result.json").write_text(json.dumps({"input_sha256":INPUT_SHA,"output_sha256":sha(OUTPUT),"baseline_snapshot":r["baseline_snapshot"],"surface_snapshot":material_snapshot(),"all_geometry_controls_and_original_uv_unchanged":True,"packed_images":True,"paid_submissions":0,"spent_credits":0,"game_integration":False},indent=2)+"\n")
    print("SURFACE_BUILD_COMPLETE")


def verify():
    r=json.loads((HERE/"build_result.json").read_text());assert sha(INPUT)==INPUT_SHA and sha(OUTPUT)==r["output_sha256"]
    bpy.ops.wm.open_mainfile(filepath=str(OUTPUT));assert prior.snapshot()==r["baseline_snapshot"] and material_snapshot()==r["surface_snapshot"]
    assert not bpy.data.libraries and not any(o.type=="ARMATURE" for o in bpy.context.scene.objects)
    assert all(i.packed_file for i in bpy.data.images if i.source=="FILE" and i.users)
    render("three_quarter","color_three_quarter_reopened")
    (HERE/"reopen_result.json").write_text(json.dumps({"output_sha256":sha(OUTPUT),"all_geometry_controls_original_uv_equal":True,"new_uv_material_image_metadata_equal":True,"external_blend_dependencies":0,"used_file_images_packed":True,"input_unchanged":True,"scope":"Persistence only, not likeness/producer/runtime acceptance"},indent=2)+"\n")
    print("SURFACE_REOPEN_COMPLETE")


if __name__=="__main__":
    {"prepare":prep,"apply":apply,"verify":verify}[sys.argv[sys.argv.index("--")+1]]()
