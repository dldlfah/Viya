"""Build an independent, editable head form and render fixed-view clay evidence.

blender -b --python build_head.py -- build
blender -b --python build_head.py -- verify
No generated candidate is imported; source references remain unchanged.
"""
import bpy
import bmesh
import math
import json
import hashlib
import array
import sys
from pathlib import Path
from mathutils import Vector

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[5]
OUT = HERE / "review"
PARAMS = json.loads((HERE / "shape_parameters.json").read_text())
F = PARAMS["features"]
CURVES = PARAMS["rings_z_width_frontdepth_backdepth"]
BLEND = HERE / "viya_head_form_study.blend"


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def digest_floats(values):
    return hashlib.sha256(array.array("f", values).tobytes()).hexdigest()


def interpolate(z, column):
    # Shape-preserving cubic Hermite interpolation, not global smoothing.
    xs = [row[0] for row in CURVES]
    ys = [row[column] for row in CURVES]
    if z <= xs[0]: return ys[0]
    if z >= xs[-1]: return ys[-1]
    slopes = [(ys[i + 1] - ys[i]) / (xs[i + 1] - xs[i]) for i in range(len(xs) - 1)]
    tangents = [slopes[0]]
    for i in range(1, len(xs) - 1):
        a, b = slopes[i - 1], slopes[i]
        tangents.append(0 if a * b <= 0 else 2 * a * b / (a + b))
    tangents.append(slopes[-1])
    i = next(j for j in range(len(xs) - 1) if xs[j] <= z <= xs[j + 1])
    h = xs[i + 1] - xs[i]; t = (z - xs[i]) / h
    return (2*t**3 - 3*t**2 + 1)*ys[i] + (t**3 - 2*t**2 + t)*h*tangents[i] + (-2*t**3 + 3*t**2)*ys[i + 1] + (t**3 - t**2)*h*tangents[i + 1]


def gaussian(x, z, cx, cz, sx, sz):
    return math.exp(-.5 * (((x-cx)/sx)**2 + ((z-cz)/sz)**2))


def feature_depth(x, z):
    depth = F["nose_ridge_depth"] * gaussian(x,z,0,F["nose_ridge_z"],.007,.025)
    depth += F["nose_tip_depth"] * gaussian(x,z,0,F["nose_tip_z"],.008,.009)
    for side in (-1,1):
        depth += .0030 * gaussian(x,z,side*.009,.066,.004,.005)
        depth -= F["socket_recess"] * gaussian(x,z,side*F["eye_center_x"],F["eye_center_z"],.018,.010)
        depth += .0016 * gaussian(x,z,side*.039,.128,.023,.006)
        depth += F["cheek_depth"] * gaussian(x,z,side*.046,.083,.017,.018)
    # Lips are volumes on the same mesh. The shallow seam is not a painted line.
    mouth_mask = max(0,1-(x/F["mouth_half_width"])**2)**2
    mouth_line = F["mouth_z"]+.0016*max(0,1-(x/F["mouth_half_width"])**2)
    depth += mouth_mask*F["upper_lip_depth"]*math.exp(-.5*((z-mouth_line-.0018)/.0020)**2)
    depth += mouth_mask*F["lower_lip_depth"]*math.exp(-.5*((z-mouth_line+.0023)/.0025)**2)
    depth -= mouth_mask*.0008*math.exp(-.5*((z-mouth_line)/.0009)**2)
    depth -= .0010 * gaussian(x,z,0,.055,.0035,.005)
    depth += F["chin_depth"] * gaussian(x,z,0,F["chin_z"],.020,.009)
    depth -= .0007 * gaussian(x,z,0,.032,.020,.006)
    return depth


def face_y(x,z):
    width = interpolate(z,1)
    c = math.sqrt(max(0,1-min(1,abs(x)/width)**2))
    return -interpolate(z,2)*c**PARAMS["front_cross_section_power"]-feature_depth(x,z)*c**4


def form_z(z):
    pivot=PARAMS["lower_face_pivot_z"]
    return pivot+(z-pivot)*PARAMS["lower_face_vertical_scale"] if z<pivot else z


def mesh_obj(name, vertices, faces, mat, subdiv=0):
    m = bpy.data.meshes.new(name + "_control")
    m.from_pydata(vertices, [], faces); m.update()
    bm=bmesh.new();bm.from_mesh(m);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(m);bm.free()
    o=bpy.data.objects.new(name,m);bpy.context.scene.collection.objects.link(o)
    m.materials.append(mat)
    for p in m.polygons:p.use_smooth=True
    if subdiv:
        sub=o.modifiers.new("Form_preview_not_animation_topology","SUBSURF");sub.levels=subdiv;sub.render_levels=subdiv
    return o


def clay_material():
    m=bpy.data.materials.new("Single_neutral_clay");m.use_nodes=True
    bs=m.node_tree.nodes.get("Principled BSDF")
    bs.inputs["Base Color"].default_value=(.42,.44,.47,1)
    bs.inputs["Roughness"].default_value=.82
    return m


def make_head(mat):
    n=PARAMS["samples"]["rings"];around=PARAMS["samples"]["around"]
    verts=[];faces=[]
    for i in range(n):
        z=.233*i/(n-1);w=interpolate(z,1);front=interpolate(z,2);back=interpolate(z,3)
        t=min(1,z/PARAMS["jaw_fade_height_m"])
        fade=.5*(1+math.cos(math.pi*t))
        for j in range(around):
            theta=2*math.pi*j/around;c=math.cos(theta);x=w*math.sin(theta)
            if c>=0:y=-front*c**PARAMS["front_cross_section_power"]-feature_depth(x,z)*c**4
            else:y=-back*c
            side_lift=PARAMS["jaw_lift_side_m"]*math.sin(theta)**2*(1-c)
            back_lift=PARAMS["jaw_lift_back_m"]*max(0,-c)**1.2
            verts.append((x,y,form_z(z+fade*(side_lift+back_lift))))
    for i in range(n-1):
        for j in range(around):
            a=i*around+j;b=i*around+(j+1)%around
            faces.append((a,b,b+around,a+around))
    # Explicit underside rings avoid a large warped lower cap pinching the chin.
    original_bottom=list(verts[:around])
    previous=list(range(around))
    for contraction in (.75,.40):
        current=[]
        for x,y,z in original_bottom:
            current.append(len(verts))
            verts.append((x*contraction,.012+(y-.012)*contraction,.055+(z-.055)*contraction))
        for j in range(around):faces.append((previous[j],previous[(j+1)%around],current[(j+1)%around],current[j]))
        previous=current
    center=len(verts);verts.append((0,.012,.055))
    for j in range(around):faces.append((previous[j],previous[(j+1)%around],center))
    faces.append(tuple((n-1)*around+j for j in range(around)))
    o=mesh_obj("VIYA_head_form_UNAPPROVED",verts,faces,mat,PARAMS["samples"]["subdivision_preview"])
    o["origin"]="independent explicit width/profile curves and local anatomical feature controls; no generated source mesh"
    o["scope"]="form study; final likeness, UV and animation topology not approved"
    return o


def eyelid_surface(mat,side):
    # A narrow continuous almond lid ribbon. Not a detached flat eye/iris image.
    verts=[];faces=[];n=64
    for which in (1,-1):
        for row in range(3):
            offset=(row-1)*.0007
            for i in range(n+1):
                t=-1+2*i/n
                x=side*(F["eye_center_x"]+F["eye_half_width"]*t)
                arc=F["eye_upper_arc"] if which==1 else F["eye_lower_arc"]
                z=F["eye_center_z"]+F["eye_outer_lift"]*t+which*arc*(1-t*t)+offset
                y=face_y(x,z)-.0005-.0005*math.sin(math.pi*i/n)
                verts.append((x,y,form_z(z)))
        base=0 if which==1 else 3*(n+1)
        for r in range(2):
            for i in range(n):
                a=base+r*(n+1)+i;faces.append((a,a+1,a+n+2,a+n+1))
    o=mesh_obj(("R" if side<0 else "L")+"_eyelid_form_GUIDE",verts,faces,mat,1)
    o["scope"]="shallow lid form guide, not eye topology/rig or final eyelash design"
    return o


def ear(mat,side):
    # Simplified provisional pinna, based only on partially visible reference.
    vs=[];fs=[];n=40
    for r,(scale,outward) in enumerate([(1,.0),(.83,.0030),(.55,.0008),(.12,-.0015)]):
        for j in range(n):
            t=2*math.pi*j/n
            y=.008+.010*scale*math.sin(t)
            z=.103+.019*scale*math.cos(t)
            x=side*(.0715+outward+.002*math.sin(t))
            vs.append((x,y,form_z(z)))
    for r in range(3):
        for j in range(n):
            a=r*n+j;b=r*n+(j+1)%n;fs.append((a,b,b+n,a+n))
    fs.append(tuple(3*n+j for j in range(n)))
    o=mesh_obj(("R" if side<0 else "L")+"_ear_PROVISIONAL",vs,fs,mat,1)
    o["not_measured"]="hidden details inferred working form; not an approved anatomical reconstruction"
    return o


def neck(mat):
    vs=[];fs=[];n=48
    for z,rx,ry,cy in [(-.018,.026,.023,.018),(-.010,.025,.023,.018),(.045,.024,.025,.017),(.070,.028,.029,.014)]:
        for j in range(n):
            t=2*math.pi*j/n;vs.append((rx*math.sin(t),cy+ry*math.cos(t),z))
    for i in range(3):
        for j in range(n):
            a=i*n+j;b=i*n+(j+1)%n;fs.append((a,b,b+n,a+n))
    return mesh_obj("Neck_connection_GUIDE",vs,fs,mat,1)


def snapshot():
    result={}
    for o in sorted([o for o in bpy.context.scene.objects if o.type=="MESH"],key=lambda o:o.name):
        m=o.data
        result[o.name]={"vertices":len(m.vertices),"polygons":len(m.polygons),"positions_sha256":digest_floats(c for v in m.vertices for c in v.co),"topology_sha256":hashlib.sha256(array.array("I",[i for p in m.polygons for i in p.vertices]).tobytes()).hexdigest(),"modifiers":[[x.type,x.levels,x.render_levels] for x in o.modifiers if x.type=="SUBSURF"]}
    return result


def set_view(name):
    s=bpy.context.scene;c=s.camera;center=Vector((0,0,.104))
    poses={"front":(0,-1,.104),"screen_right_profile":(-1,0,.104),"screen_left_profile":(1,0,.104),"three_quarter":(.72,-1,.104),"back":(0,1,.104),"game_high_angle":(0,-math.cos(math.radians(55)),.104+math.sin(math.radians(55)))}
    c.location=poses[name];c.rotation_euler=(center-c.location).to_track_quat("-Z","Y").to_euler()


def render(name,filename=None):
    set_view(name);s=bpy.context.scene;s.render.filepath=str(OUT/((filename or name)+".png"));bpy.ops.render.render(write_still=True)


def build():
    OUT.mkdir(exist_ok=True)
    refs=json.loads((HERE.parent/"face_reference_v1/face_landmarks.json").read_text())["references"]
    for ref in refs:assert sha(ROOT/ref["path"])==ref["sha256"]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    mat=clay_material();head=make_head(mat)
    for side in (-1,1):eyelid_surface(mat,side);ear(mat,side)
    neck(mat)
    s=bpy.context.scene;s.render.engine="CYCLES";s.cycles.samples=32;s.cycles.seed=13;s.cycles.use_denoising=False
    s.render.resolution_x=512;s.render.resolution_y=640;s.render.resolution_percentage=100
    s.render.image_settings.file_format="PNG";s.render.image_settings.color_mode="RGBA";s.render.film_transparent=True
    s.view_settings.view_transform="Standard"
    s.world=bpy.data.worlds.new("HeadStudy_World");s.world.use_nodes=True;s.world.node_tree.nodes["Background"].inputs["Strength"].default_value=.15
    for name,pos,power,size in [("Key",(.4,-.6,.6),5,.5),("Fill",(-.5,-.3,.35),2,.5),("Rim",(.2,.5,.4),3,.4)]:
        d=bpy.data.lights.new(name,"AREA");d.energy=power;d.size=size;o=bpy.data.objects.new(name,d);s.collection.objects.link(o);o.location=pos;o.rotation_euler=(Vector((0,0,.11))-o.location).to_track_quat("-Z","Y").to_euler()
    c=bpy.data.cameras.new("FixedHeadCamera");c.type="ORTHO";c.ortho_scale=.335
    s.camera=bpy.data.objects.new("FixedHeadCamera",c);s.collection.objects.link(s.camera)
    for name in ["front","screen_right_profile","screen_left_profile","three_quarter","back","game_high_angle"]:render(name)
    set_view("three_quarter")
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND),compress=True)
    report={"blender_version":bpy.app.version_string,"parameters_sha256":sha(HERE/"shape_parameters.json"),"sources":[{"path":r["path"],"sha256":r["sha256"],"role":r["short_role"]} for r in refs],"source_meshes_loaded":[],"independent_construction":True,"snapshot":snapshot(),"bones":0,"animations":0,"painted_face_textures":0,"producer_approval":False,"paid_submissions":0,"spent_credits":0,"limitations":PARAMS["assumptions"]}
    (HERE/"build_result.json").write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n")
    print("B0303_BUILD_COMPLETE",json.dumps({"objects":len(report["snapshot"]),"control_vertices":sum(x["vertices"] for x in report["snapshot"].values()),"blend_bytes":BLEND.stat().st_size}))


def verify():
    report=json.loads((HERE/"build_result.json").read_text())
    for ref in report["sources"]:assert sha(ROOT/ref["path"])==ref["sha256"]
    bpy.ops.wm.open_mainfile(filepath=str(BLEND))
    assert snapshot()==report["snapshot"]
    assert not bpy.data.libraries and not any(o.type=="ARMATURE" for o in bpy.context.scene.objects)
    render("three_quarter","three_quarter_reopened")
    result={"saved_geometry_and_topology_equal":True,"source_refs_unchanged":True,"external_library_dependencies":0,"armatures":0,"blend_sha256":sha(BLEND),"visual_quality":"not decided by hashes; review required"}
    (HERE/"reopen_result.json").write_text(json.dumps(result,indent=2)+"\n")
    print("B0303_REOPEN_COMPLETE",json.dumps(result))


if __name__=="__main__":
    mode=sys.argv[sys.argv.index("--")+1];{"build":build,"verify":verify}[mode]()
