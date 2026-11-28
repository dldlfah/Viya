"""B-03-03: CC0 anatomical control-topology route after procedural form failure.

Only head/neck skin and eye helper geometry is instantiated. No body, clothing,
rig, addon code or rejected generated character is loaded. Assets are CC0;
this parser and adaptation logic are independently written for this project.
"""
from pathlib import Path
import array
import gzip
import hashlib
import importlib.util
import json
import math
import sys
import bpy
import bmesh
from mathutils import Vector

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[6]
OUT=HERE/"review"
SOURCE=HERE/"source"
spec=importlib.util.spec_from_file_location("head_form_utils",HERE.parent/"build_head.py")
utils=importlib.util.module_from_spec(spec);spec.loader.exec_module(utils)
utils.OUT=OUT
BASE_SHA="8e761e6624b8f54536409135d1636da63b32486a90d4897f84e121d144f6fb4c"
MORPH_SHA="e9d6212373ac5f1e2c596fa145e363385f4d169c3c6c88ede3bab93b681af041"
ADAPT=json.loads((HERE/"adaptation_parameters.json").read_text())


def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def parse_source():
    assert sha(SOURCE/"mpfb_hm08_base.obj")==BASE_SHA
    assert sha(SOURCE/"adult_female_young.target.gz")==MORPH_SHA
    vertices=[];uvs=[];polygons=[];groups=[]
    for line in (SOURCE/"mpfb_hm08_base.obj").read_text().splitlines():
        if line.startswith("v "):vertices.append(Vector(tuple(map(float,line.split()[1:4]))))
        elif line.startswith("vt "):uvs.append(tuple(map(float,line.split()[1:3])))
        elif line.startswith("g "):groups=line.split()[1:]
        elif line.startswith("f "):
            pairs=[s.split("/") for s in line.split()[1:]]
            polygons.append({"v":[int(s[0])-1 for s in pairs],"uv":[int(s[1])-1 for s in pairs],"groups":groups})
    deltas={}
    for line in gzip.decompress((SOURCE/"adult_female_young.target.gz").read_bytes()).decode().splitlines():
        r=line.split()
        if len(r)==4 and not r[0].startswith("#"):deltas[int(r[0])]=Vector(tuple(map(float,r[1:])))
    morphed=[v+deltas.get(i,Vector()) for i,v in enumerate(vertices)]
    regional=gzip.decompress((SOURCE/"nose-scale-horiz-decr.target.gz").read_bytes()).decode()
    for line in regional.splitlines():
        r=line.split()
        if len(r)==4 and not r[0].startswith("#"):
            morphed[int(r[0])]+=Vector(tuple(map(float,r[1:])))*ADAPT["nose_width_target_weight"]
    eye_centers=[]
    for group in ["helper-l-eye","helper-r-eye"]:
        ids={i for p in polygons if group in p["groups"] for i in p["v"]}
        eye_centers.append(sum((morphed[i] for i in ids),Vector())/len(ids))
    return vertices,morphed,uvs,polygons,eye_centers


def world_point(p,eye_height):
    return Vector((p.x*.1,-(p.z-.5)*.1,(p.y-eye_height)*.1+.110))


def adapt(p,group,eye_center_x):
    # A small, explicit first adaptation: preserve proper facial loops.
    q=p.copy();q.x*=ADAPT["head_x_scale"]
    if q.z<.110:q.z=.110+(q.z-.110)*ADAPT["lower_face_z_scale"]
    if group=="skin":
        front=min(1,max(0,(-q.y-.015)/.035))
        w=math.exp(-.5*((abs(q.x)-eye_center_x*.90)/.024)**2-.5*((q.z-.110)/.023)**2)*front
        q.x+=(1 if q.x>=0 else -1)*ADAPT["eye_outward_shift_m"]*w
        central=math.exp(-.5*(q.x/.026)**2-.5*((q.z-.080)/.026)**2)*front
        q.z+=ADAPT["central_feature_lift_m"]*central
        dz=q.z-ADAPT["mouth_closure_center_z_m"]
        mask=math.exp(-.5*(q.x/.026)**2-.5*(dz/.010)**2)*front
        q.z-=math.copysign(min(ADAPT["mouth_closure_max_m"],abs(dz)*ADAPT["mouth_closure_fraction"]),dz)*mask
    else:
        side=1 if q.x>=0 else -1
        center=side*eye_center_x*.90
        q.x=center+side*ADAPT["eye_outward_shift_m"]+(q.x-center)*ADAPT["eye_helper_x_scale"]
    return q


def make_part(name,group,faces,base,morphed,uvs,eye_height,eye_center_x,mat):
    chosen=[p for p in faces if (("body" in p["groups"] and all(base[i].y>5.8 for i in p["v"])) if group=="skin" else name in p["groups"])]
    ids=sorted({i for p in chosen for i in p["v"]});mapping={n:i for i,n in enumerate(ids)}
    points=[world_point(morphed[i],eye_height) for i in ids]
    mesh=bpy.data.meshes.new("CC0_"+name+"_control")
    mesh.from_pydata(points,[],[[mapping[i] for i in p["v"]] for p in chosen]);mesh.update()
    bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(mesh);bm.free()
    obj=bpy.data.objects.new("CC0_"+name+"_UNAPPROVED",mesh);bpy.context.scene.collection.objects.link(obj)
    mesh.materials.append(mat)
    for p in mesh.polygons:p.use_smooth=True
    layer=mesh.uv_layers.new(name="CC0_original_head_uv")
    for poly,record in zip(mesh.polygons,chosen):
        for loop,uv_id in zip(poly.loop_indices,record["uv"]):layer.data[loop].uv=uvs[uv_id]
    idx=mesh.attributes.new("source_vertex_index","INT","POINT")
    for i,original in enumerate(ids):idx.data[i].value=original
    obj.shape_key_add(name="CC0_adult_form_basis")
    key=obj.shape_key_add(name="VIYA_reference_proportion_STUDY")
    for original,target in zip(points,key.data):target.co=adapt(original,group,eye_center_x)
    key.value=1
    sub=obj.modifiers.new("Preview_subdivision_only","SUBSURF");sub.levels=1;sub.render_levels=1
    obj["scope"]="CC0 anatomical topology trial; VIYA likeness/production adoption pending"
    return obj,len(chosen),len(ids)


def snap():
    r={}
    for o in sorted([o for o in bpy.context.scene.objects if o.type=="MESH"],key=lambda o:o.name):
        m=o.data
        r[o.name]={"vertices":len(m.vertices),"faces":len(m.polygons),"basis_sha":utils.digest_floats(c for p in m.shape_keys.key_blocks[0].data for c in p.co),"adapted_sha":utils.digest_floats(c for p in m.shape_keys.key_blocks[1].data for c in p.co),"uv_sha":utils.digest_floats(c for p in m.uv_layers[0].data for c in p.uv),"topology_sha":hashlib.sha256(array.array("I",[i for p in m.polygons for i in p.vertices]).tobytes()).hexdigest(),"adapted_value":m.shape_keys.key_blocks[1].value}
    return r


def scene_setup():
    s=bpy.context.scene;s.render.engine="CYCLES";s.cycles.samples=32;s.cycles.seed=13;s.cycles.use_denoising=False
    s.render.resolution_x=512;s.render.resolution_y=640;s.render.resolution_percentage=100
    s.render.image_settings.file_format="PNG";s.render.image_settings.color_mode="RGBA";s.render.film_transparent=True;s.view_settings.view_transform="Standard"
    s.world=bpy.data.worlds.new("TopologyTrial_World");s.world.use_nodes=True;s.world.node_tree.nodes["Background"].inputs["Strength"].default_value=.15
    for name,pos,power,size in [("Key",(.4,-.6,.6),5,.5),("Fill",(-.5,-.3,.35),2,.5),("Rim",(.2,.5,.4),3,.4)]:
        d=bpy.data.lights.new(name,"AREA");d.energy=power;d.size=size;o=bpy.data.objects.new(name,d);s.collection.objects.link(o);o.location=pos;o.rotation_euler=(Vector((0,0,.11))-o.location).to_track_quat("-Z","Y").to_euler()
    c=bpy.data.cameras.new("FixedTopologyCamera");c.type="ORTHO";c.ortho_scale=.335;s.camera=bpy.data.objects.new("FixedTopologyCamera",c);s.collection.objects.link(s.camera)


def build():
    OUT.mkdir(exist_ok=True)
    base,morphed,uvs,polys,centers=parse_source();ey=(centers[0].y+centers[1].y)/2;ex=(abs(centers[0].x)+abs(centers[1].x))*.05
    bpy.ops.wm.read_factory_settings(use_empty=True)
    mat=utils.clay_material();parts=[]
    for name,group in [("head_skin","skin"),("helper-l-eye","eye"),("helper-r-eye","eye")]:parts.append(make_part(name,group,polys,base,morphed,uvs,ey,ex,mat))
    scene_setup()
    for o,_,_ in parts:o.data.shape_keys.key_blocks[1].value=0
    for v in ["front","screen_left_profile"]:utils.render(v,"base_"+v)
    for o,_,_ in parts:o.data.shape_keys.key_blocks[1].value=1
    for v in ["front","screen_right_profile","screen_left_profile","three_quarter","back","game_high_angle"]:utils.render(v)
    utils.set_view("three_quarter");bpy.context.preferences.filepaths.save_version=0
    path=HERE/"cc0_head_topology_study.blend";bpy.ops.wm.save_as_mainfile(filepath=str(path),compress=True)
    report={"source_repository":"makehumancommunity/mpfb2","base_blob_sha":"d26635e9326e3cca30778fd7b9c00062b03cce09","base_sha256":sha(SOURCE/"mpfb_hm08_base.obj"),"target_blob_sha":"32634e46613fef3e3b56e52c366ba0322a3c084b","target_sha256":sha(SOURCE/"adult_female_young.target.gz"),"original_target_path":"src/mpfb/data/targets/macrodetails/caucasian-female-young.target.gz","nose_target_blob_sha":"7939ffc1026cf8853b295d71f3a8722ede7ceb01","nose_target_sha256":sha(SOURCE/"nose-scale-horiz-decr.target.gz"),"asset_license":"CC0-1.0; official MPFB asset license retained","addon_code_imported":False,"full_body_instantiated":False,"head_selection":"Only body-group faces all of whose original source Y coordinates exceed5.8; eyes from helper-l/r-eye","construction":"Existing CC0 anatomical face loops, adult-form target, explicit working proportion shape key. No generated VIYA candidate used.","eye_source_height":ey,"eye_source_halfwidth_m":ex,"adaptation":ADAPT,"snapshot":snap(),"producer_approval":False,"paid_submissions":0,"spent_credits":0,"limitations":["Generic licensed topology is not the approved VIYA face","Reference-proportion trial only; eyelid/eye fit and nose/lip/jaw likeness require review","Hair/painted features, rig/deformation and body/weapon not authored","Full side/face approval and runtime/mobile performance not granted"]}
    (HERE/"build_result.json").write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n")
    print("CC0_HEAD_BUILD_COMPLETE",json.dumps({"parts":len(parts),"vertices":sum(p[2] for p in parts),"faces":sum(p[1] for p in parts),"blend_bytes":path.stat().st_size}))


def verify():
    report=json.loads((HERE/"build_result.json").read_text());path=HERE/"cc0_head_topology_study.blend"
    refs=json.loads((HERE.parent.parent/"face_reference_v1/face_landmarks.json").read_text())["references"]
    for r in refs:assert sha(ROOT/r["path"])==r["sha256"]
    assert sha(SOURCE/"mpfb_hm08_base.obj")==BASE_SHA and sha(SOURCE/"adult_female_young.target.gz")==MORPH_SHA
    bpy.ops.wm.open_mainfile(filepath=str(path));assert snap()==report["snapshot"]
    assert not bpy.data.libraries and not any(o.type=="ARMATURE" for o in bpy.context.scene.objects)
    integrity={}
    for o in bpy.context.scene.objects:
        if o.type!="MESH":continue
        assert all(math.isfinite(x) for v in o.data.shape_keys.key_blocks[1].data for x in v.co)
        bm=bmesh.new();bm.from_mesh(o.data)
        integrity[o.name]={"control_vertices":len(bm.verts),"control_faces":len(bm.faces),"boundary_edges":sum(e.is_boundary for e in bm.edges),"zero_area_faces":sum(f.calc_area()<1e-12 for f in bm.faces)}
        assert integrity[o.name]["zero_area_faces"]==0
        bm.free()
    utils.render("three_quarter","three_quarter_reopened")
    (HERE/"reopen_result.json").write_text(json.dumps({"geometry_uv_topology_shape_keys_equal":True,"four_reference_hashes_verified":True,"external_library_dependencies":0,"mesh_integrity":integrity,"blend_sha256":sha(path),"scope":"Persistence/control-mesh integrity only, not accepted VIYA face or deformation/runtime test"},indent=2)+"\n")


if __name__=="__main__":
    {"build":build,"verify":verify}[sys.argv[sys.argv.index("--")+1]]()
