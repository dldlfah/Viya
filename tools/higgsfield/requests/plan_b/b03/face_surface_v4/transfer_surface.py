"""Export/check the current surface geometry and replace head color only."""
import hashlib
import importlib.util
import json
import sys
from pathlib import Path
import bpy

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[5]
INPUT=HERE.parent/"face_surface_v3/viya_face_expression.blend"
OUTPUT=HERE/"viya_face_details.blend"
OUT=HERE/"review"
EXCHANGE=ROOT/".local_validation/PLAN_B03_04_DETAIL"
REG=json.loads((HERE/"feature_registration.json").read_text())
UV_NAME="VIYA_face_surface_uv"
spec=importlib.util.spec_from_file_location("previous_surface",HERE.parent/"face_surface_v1/texture_head.py")
prior=importlib.util.module_from_spec(spec);spec.loader.exec_module(prior)
prior.prior.REVIEW=OUT;prior.prior.prior.previous.original.utils.OUT=OUT


def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()


def meshes():return prior.meshes()


def render(view,name):prior.render(view,name)


def snapshot():
    s=prior.prior.snapshot()
    for o in meshes():
        s[o.name]["all_uv_layers"]={u.name:prior.digest([v for p in u.data for v in p.uv]) for u in o.data.uv_layers}
        s[o.name]["evaluated_control_positions"]=prior.digest([v for p in prior.prior.points(o) for v in p])
    return s


def load():
    assert sha(INPUT)==REG["input_sha256"];bpy.ops.wm.open_mainfile(filepath=str(INPUT));return snapshot()


def export():
    baseline=load();data={"objects":{},"features":{}};deps=bpy.context.evaluated_depsgraph_get()
    for o in meshes():
        ev=o.evaluated_get(deps);m=ev.to_mesh();m.calc_loop_triangles();uv=m.uv_layers[UV_NAME]
        data["objects"][o.name]={"positions":[list(v.co) for v in m.vertices],"triangles":[list(t.vertices) for t in m.loop_triangles],"triangle_uv":[[list(uv.data[i].uv) for i in t.loops] for t in m.loop_triangles]};ev.to_mesh_clear()
    skin=next(o for o in meshes() if "head_skin" in o.name);ps=prior.prior.points(skin);ids={v.value:i for i,v in enumerate(skin.data.attributes["source_vertex_index"].data)}
    sel=json.loads((HERE.parent/"head_refinement_v3/loop_selection.json").read_text())
    for side,rings in sel["eyes"].items():data["features"][side]=[list(ps[ids[i]]) for i in rings["aperture"]["source_indices"]]
    for name,loop in sel["mouth"].items():data["features"]["mouth_"+name]=[list(ps[ids[i]]) for i in loop["source_indices"]]
    EXCHANGE.mkdir(parents=True,exist_ok=True);(EXCHANGE/"bake_mesh.json").write_text(json.dumps(data))
    (HERE/"source_snapshot.json").write_text(json.dumps({"input_sha256":sha(INPUT),"snapshot":baseline,"no_uv_reunwrap_or_geometry_changes":True},indent=2)+"\n")
    print("SOURCE_EXPORTED_WITHOUT_MODIFICATION")


def image_hashes():
    r={}
    for o in meshes():
        r[o.name]={}
        for n in o.data.materials[0].node_tree.nodes:
            if n.type=="TEX_IMAGE":r[o.name][Path(n.image.filepath).name]=hashlib.sha256(n.image.packed_file.data).hexdigest()
    return r


def build():
    baseline=load();before_images=image_hashes();skin=next(o for o in meshes() if "head_skin" in o.name)
    # Reject the observed failure where a nose patch registered to an internal surface.
    from mathutils import Vector
    from mathutils.bvhtree import BVHTree
    data=json.loads((EXCHANGE/"bake_mesh.json").read_text())["objects"][skin.name]
    bvh=BVHTree.FromPolygons([Vector(v) for v in data["positions"]],data["triangles"],all_triangles=True)
    transfers=json.loads((HERE/"transfer_result.json").read_text())["feature_transfers"];visibility=[]
    for f in transfers:
        if "nose_mark" not in f["id"]:continue
        a=f["actual_surface_anchor_working_m"]
        point,_,_,_=bvh.ray_cast(Vector((a[0],-1,a[2])),Vector((0,1,0)))
        assert point is not None
        gap=abs(point.y-a[1]);assert gap<REG["nose_anchor_method"]["first_hit_negative_y_ray_max_gap_working_m"],(f["id"],gap)
        visibility.append({"id":f["id"],"anchor":a,"front_axis_first_hit":list(point),"depth_gap_working_m":gap})
    rejected=[]
    bad=json.loads((HERE/"trial01_hidden_nose_anchor/transfer_result.json").read_text())["feature_transfers"]
    for f in bad:
        if "nose_mark" not in f["id"]:continue
        a=f["actual_surface_anchor_working_m"]
        point,_,_,_=bvh.ray_cast(Vector((a[0],-1,a[2])),Vector((0,1,0)))
        assert point is not None
        gap=abs(point.y-a[1]);assert gap>REG["nose_anchor_method"]["first_hit_negative_y_ray_max_gap_working_m"]
        rejected.append({"id":f["id"],"depth_gap_working_m":gap,"known_hidden_anchor_rejected":True})
    (HERE/"nose_registration_check.json").write_text(json.dumps({"results":visibility,"known_failure_counterexamples":rejected,"first_visible_front_axis_surface":True,"scope":"Frontal-Y point registration only; not all cameras or full self-intersection."},indent=2)+"\n")
    old=skin.data.materials[0];old.use_fake_user=True;mat=old.copy();mat.name="B0304_ReferenceDetails"
    image=bpy.data.images.load(str(HERE/"textures/head_color_details.png"));image.colorspace_settings.name="sRGB";image.pack()
    for n in mat.node_tree.nodes:
        if n.type=="TEX_IMAGE":n.image=image
    skin.data.materials[0]=mat
    assert snapshot()==baseline
    after_images=image_hashes()
    for o in meshes():
        if o!=skin:assert after_images[o.name]==before_images[o.name]
    OUT.mkdir(exist_ok=True)
    for view in ["front","screen_left_profile","screen_right_profile","three_quarter","three_quarter_opposite","game_high_angle"]:render(view,"color_"+view)
    unlit=mat.copy();unlit.name="B0304_ReferenceDetails_Unlit";nodes=unlit.node_tree.nodes;links=unlit.node_tree.links
    em=next(n for n in nodes if n.type=="EMISSION");out=next(n for n in nodes if n.type=="OUTPUT_MATERIAL")
    for l in list(out.inputs["Surface"].links):links.remove(l)
    links.new(em.outputs[0],out.inputs["Surface"]);skin.data.materials[0]=unlit
    for view in ["front","three_quarter","three_quarter_opposite"]:render(view,"unlit_"+view)
    skin.data.materials[0]=mat
    prior.prior.prior.previous.original.utils.set_view("three_quarter")
    bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT),compress=True)
    (HERE/"build_result.json").write_text(json.dumps({"input_sha256":sha(INPUT),"output_sha256":sha(OUTPUT),"all_geometry_shape_keys_uv_equal":True,"snapshot":baseline,"before_active_texture_hashes":before_images,"after_active_texture_hashes":after_images,"baseline_head_material_retained":old.name,"new_material":mat.name,"new_head_png_sha256":sha(HERE/"textures/head_color_details.png"),"paid_submissions":0,"spent_credits":0,"game_integration":False},indent=2)+"\n")
    print("TRANSFER_BUILT")


def verify():
    r=json.loads((HERE/"build_result.json").read_text());assert sha(INPUT)==r["input_sha256"] and sha(OUTPUT)==r["output_sha256"]
    bpy.ops.wm.open_mainfile(filepath=str(OUTPUT));assert snapshot()==r["snapshot"] and image_hashes()==r["after_active_texture_hashes"]
    assert r["baseline_head_material_retained"] in bpy.data.materials and not bpy.data.libraries
    assert all(i.packed_file for i in bpy.data.images if i.source=="FILE" and i.users)
    assert not any(o.type=="ARMATURE" for o in bpy.context.scene.objects)
    render("three_quarter","color_three_quarter_reopened")
    (HERE/"reopen_result.json").write_text(json.dumps({"output_sha256":sha(OUTPUT),"all_geometry_controls_uv_equal":True,"active_packed_image_hashes_equal":True,"baseline_head_material_retained":True,"external_blend_dependencies":0,"input_unchanged":True,"scope":"Persistence/material-only change, not producer likeness or rig/runtime acceptance"},indent=2)+"\n")
    print("TRANSFER_REOPENED")


if __name__=="__main__":
    {"export":export,"build":build,"verify":verify}[sys.argv[sys.argv.index("--")+1]]()
