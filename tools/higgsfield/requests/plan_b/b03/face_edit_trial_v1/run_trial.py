"""B-03-02: actual local face-geometry and mouth-UV editing capability trial.

blender -b --python run_trial.py -- build
blender -b --python run_trial.py -- verify

Candidate03 is linked solely as an unapproved diagnostic specimen. Rejected01/02
are never loaded. This does not accept the specimen as production VIYA.
"""
import array
import hashlib
import json
import math
import sys
from pathlib import Path
import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[5]
SOURCE = ROOT / "assets/characters/plan_b_viya/candidate_03/review/viya_body_review.blend"
RAW = ROOT / "assets/characters/plan_b_viya/candidate_03/source/viya_body_raw.glb"
FRONT = ROOT / "assets/characters/plan_b_viya/candidate_03/references/front.png"
OUT = HERE / "review"
SPECIMEN = HERE / "face_edit_trial.blend"
SOURCE_RAW_SHA = "6a26853df3fd3fa2d0f3e85715d7ef8e3d28f4ed383b6eedb36d1802cdc6903e"
SOURCE_FRONT_SHA = "28131fc01dbff28b3a5475ee2f73fcb37e5f9d7e81ab26477e9a1ce092b2b11b"
CROP = (665, 115, 875, 290)


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def floats(values):
    a = array.array("f", values)
    return hashlib.sha256(a.tobytes()).hexdigest()


def snapshot(obj):
    m = obj.data
    return {
        "vertices": len(m.vertices), "polygons": len(m.polygons),
        "base_positions": floats(c for v in m.vertices for c in v.co),
        "basis_shape": floats(c for p in m.shape_keys.key_blocks["Basis"].data for c in p.co),
        "edited_shape": floats(c for p in m.shape_keys.key_blocks["TEST_NoseProjection_3mm"].data for c in p.co),
        "original_uv": floats(c for p in m.uv_layers["UVMap"].data for c in p.uv),
        "trial_uv": floats(c for p in m.uv_layers["MouthReferenceTrialUV"].data for c in p.uv),
        "blend_weights": floats(c for p in m.color_attributes["MouthTrialWeight"].data for c in p.color),
        "source_texture_pixels": floats(bpy.data.materials["FaceTrial_TextureOnly"].node_tree.nodes["OriginalTexture"].image.pixels[:]),
        "crop_pixels": floats(bpy.data.materials["FaceTrial_TextureOnly"].node_tree.nodes["ReferenceCrop"].image.pixels[:]),
        "shape_value": m.shape_keys.key_blocks["TEST_NoseProjection_3mm"].value,
        "uv_switch": bpy.data.materials["FaceTrial_TextureOnly"].node_tree.nodes["UV_trial_enabled"].outputs[0].default_value,
    }


def camera_front(scene):
    center = Vector((0, -.18, 1.575))
    scene.camera.location = (0, -3, 1.575)
    scene.camera.rotation_euler = (center - scene.camera.location).to_track_quat("-Z", "Y").to_euler()


def camera_oblique(scene):
    center = Vector((0, -.18, 1.575))
    scene.camera.location = (2.0, -3, 1.575)
    scene.camera.rotation_euler = (center - scene.camera.location).to_track_quat("-Z", "Y").to_euler()


def render(scene, name):
    scene.render.filepath = str(OUT / (name + ".png"))
    bpy.ops.render.render(write_still=True)


def build():
    assert sha(RAW) == SOURCE_RAW_SHA
    assert sha(FRONT) == SOURCE_FRONT_SHA
    assert (HERE / "source_face_crop.png").exists(), "Prepare exact source crop before Blender build"
    OUT.mkdir(exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    with bpy.data.libraries.load(str(SOURCE), link=True) as (_, target):
        target.objects = ["Mesh_0"]
    linked = target.objects[0]
    bpy.context.scene.collection.objects.link(linked)
    bpy.context.view_layer.update()
    world = linked.matrix_world.copy()
    obj = linked.copy()
    obj.data = linked.data.copy()
    obj.name = "DIAGNOSTIC_ONLY_FaceEditTrial"
    obj.parent = None
    obj.matrix_world = world
    bpy.context.scene.collection.objects.link(obj)
    source_material = obj.data.materials[0]
    source_image = next(n.image for n in source_material.node_tree.nodes if n.type == "TEX_IMAGE" and n.image)
    bpy.data.objects.remove(linked, do_unlink=True)
    obj["diagnostic_only_not_approved_or_game_asset"] = True
    obj["unapproved_specimen"] = "candidate03; no rejected candidate loaded"
    m = obj.data
    original_uv_hash = floats(c for p in m.uv_layers["UVMap"].data for c in p.uv)
    basis_hash = floats(c for v in m.vertices for c in v.co)
    obj.shape_key_add(name="Basis")
    edited = obj.shape_key_add(name="TEST_NoseProjection_3mm")
    inverse = world.inverted().to_3x3()
    changed = []
    for v, point in zip(m.vertices, edited.data):
        p = world @ v.co
        r2 = ((p.x + .004) / .020) ** 2 + ((p.z - 1.572) / .024) ** 2
        if p.y < -.200 and r2 < 1:
            dy = -.003 * (1 - r2) ** 2
            point.co += inverse @ Vector((0, dy, 0))
            changed.append({"vertex": v.index, "delta_world_m": [0, dy, 0]})
    assert len(changed) > 10
    edited.value = 0
    uv = m.uv_layers.new(name="MouthReferenceTrialUV")
    weights = m.color_attributes.new(name="MouthTrialWeight", type="FLOAT_COLOR", domain="POINT")
    weighted_vertices = 0
    for v in m.vertices:
        p = world @ v.co
        r2 = (p.x / .031) ** 2 + ((p.z - 1.551) / .024) ** 2
        w = 0.0
        if p.y < -.190 and r2 < 1:
            t = min(1, max(0, (1 - r2) / .45))
            w = t * t * (3 - 2 * t)
        weights.data[v.index].color = (w, w, w, 1)
        weighted_vertices += w > 0
    for loop in m.loops:
        p = world @ m.vertices[loop.vertex_index].co
        sx = 770 + (p.x + .004) * 1250
        sy = 178 - (p.z - 1.590) * 1420
        uv.data[loop.index].uv = ((sx - CROP[0]) / (CROP[2] - CROP[0]), 1 - (sy - CROP[1]) / (CROP[3] - CROP[1]))
    m.uv_layers.active_index = 0
    mat = bpy.data.materials.new("FaceTrial_TextureOnly")
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    original = nt.nodes.new("ShaderNodeTexImage"); original.name = "OriginalTexture"; original.image = source_image
    original_uv = nt.nodes.new("ShaderNodeUVMap"); original_uv.uv_map = "UVMap"
    nt.links.new(original_uv.outputs["UV"], original.inputs["Vector"])
    crop = nt.nodes.new("ShaderNodeTexImage"); crop.name = "ReferenceCrop"
    crop.image = bpy.data.images.load(str(HERE / "source_face_crop.png")); crop.image.pack()
    crop.extension = "EXTEND"
    new_uv = nt.nodes.new("ShaderNodeUVMap"); new_uv.uv_map = "MouthReferenceTrialUV"
    nt.links.new(new_uv.outputs["UV"], crop.inputs["Vector"])
    attr = nt.nodes.new("ShaderNodeVertexColor"); attr.layer_name = "MouthTrialWeight"
    toggle = nt.nodes.new("ShaderNodeValue"); toggle.name = "UV_trial_enabled"; toggle.outputs[0].default_value = 0
    mult = nt.nodes.new("ShaderNodeMath"); mult.operation = "MULTIPLY"
    nt.links.new(attr.outputs["Color"], mult.inputs[0]); nt.links.new(toggle.outputs[0], mult.inputs[1])
    mix = nt.nodes.new("ShaderNodeMixRGB"); mix.blend_type = "MIX"
    nt.links.new(mult.outputs[0], mix.inputs[0]); nt.links.new(original.outputs["Color"], mix.inputs[1]); nt.links.new(crop.outputs["Color"], mix.inputs[2])
    emission = nt.nodes.new("ShaderNodeEmission"); output = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(mix.outputs[0], emission.inputs["Color"]); nt.links.new(emission.outputs[0], output.inputs["Surface"])
    m.materials.clear(); m.materials.append(mat)
    clay = bpy.data.materials.new("FaceTrial_Clay")
    clay.use_nodes = True
    bs = clay.node_tree.nodes.get("Principled BSDF")
    bs.inputs["Base Color"].default_value = (.35, .38, .42, 1); bs.inputs["Roughness"].default_value = .9
    clay.use_fake_user = True
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"; scene.cycles.samples = 16; scene.cycles.seed = 7; scene.cycles.use_denoising = False
    scene.render.resolution_x = 384; scene.render.resolution_y = 384; scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"; scene.render.image_settings.color_mode = "RGBA"
    scene.render.film_transparent = True; scene.view_settings.view_transform = "Standard"
    scene.world = bpy.data.worlds.new("Trial_World"); scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = .25
    for name, position, power in [("Key", (1, -3, 3), 150), ("Fill", (-2, -1, 2), 80)]:
        light = bpy.data.lights.new(name, "AREA"); light.energy = power; light.size = 2
        lo = bpy.data.objects.new(name, light); scene.collection.objects.link(lo); lo.location = position
        lo.rotation_euler = (Vector((0, -.18, 1.575)) - lo.location).to_track_quat("-Z", "Y").to_euler()
    camera = bpy.data.cameras.new("Trial_Camera"); camera.type = "ORTHO"; camera.ortho_scale = .30
    scene.camera = bpy.data.objects.new("Trial_Camera", camera); scene.collection.objects.link(scene.camera)
    camera_front(scene)
    for name, shape, texture in [("texture_before", 0, 0), ("geometry_only", 1, 0), ("uv_only", 0, 1), ("texture_combined", 1, 1)]:
        edited.value = shape; toggle.outputs[0].default_value = texture
        render(scene, name)
    camera_oblique(scene)
    for name, shape, texture in [("oblique_before", 0, 0), ("oblique_combined", 1, 1)]:
        edited.value = shape; toggle.outputs[0].default_value = texture
        render(scene, name)
    m.materials[0] = clay
    for name, shape in [("clay_before", 0), ("clay_geometry", 1)]:
        edited.value = shape; render(scene, name)
    m.materials[0] = mat; edited.value = 1; toggle.outputs[0].default_value = 1; camera_front(scene)
    assert basis_hash == floats(c for v in m.vertices for c in v.co)
    assert original_uv_hash == floats(c for p in m.uv_layers["UVMap"].data for c in p.uv)
    expected = snapshot(obj)
    library = source_image.library
    library.filepath = bpy.path.relpath(str(SOURCE), start=str(HERE))
    crop.image.filepath = "//source_face_crop.png"
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(SPECIMEN), compress=True)
    report = {
        "stage": "B-03-02 local capability trial; not accepted VIYA",
        "blender_version": bpy.app.version_string,
        "inputs": {"raw_glb_sha256": sha(RAW), "linked_review_blend_sha256": sha(SOURCE), "front_sha256": sha(FRONT), "source_face_crop_xyxy": CROP, "crop_sha256": sha(HERE / "source_face_crop.png")},
        "source_scope": "candidate03 diagnostic only, not adopted. Rejected01/02 not loaded.",
        "geometry_edit": {"kind": "reversible local shape key", "changed_vertices": len(changed), "maximum_delta_world_m": max(abs(x["delta_world_m"][1]) for x in changed), "delta_records": changed},
        "uv_edit": {"kind": "independent mouth projection UV layer + smooth local material blend, source pixels unchanged", "weighted_vertices": weighted_vertices, "projection": {"source_x": "770 + (world_x + .004)*1250", "source_y": "178 - (world_z - 1.590)*1420"}, "projection_scope": "manual test registration only, not calibrated anatomy or producer-approved face"},
        "checks": {"original_basis_unchanged": True, "original_uv_unchanged": True, "topology_unchanged": True, "rigs": 0, "paid_submissions": 0, "spent_credits": 0},
        "expected_reopen_snapshot": expected,
        "limits": ["Local nose/mouth editing capability only", "No eye repaint, full face reconstruction, retopology, rig or animation acceptance", "Front projection may stretch in side/high-angle views; source face/hair remain simplified", "Original texture is library-linked to the tracked unapproved03 review file; keep dependency", "No game import or device verification"],
    }
    (HERE / "build_result.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print("B0302_BUILD_COMPLETE", json.dumps({"vertices_edited": len(changed), "weighted_vertices": weighted_vertices, "blend_bytes": SPECIMEN.stat().st_size}))


def verify():
    report = json.loads((HERE / "build_result.json").read_text())
    assert sha(SOURCE) == report["inputs"]["linked_review_blend_sha256"]
    assert sha(RAW) == SOURCE_RAW_SHA and sha(FRONT) == SOURCE_FRONT_SHA
    bpy.ops.wm.open_mainfile(filepath=str(SPECIMEN))
    obj = bpy.data.objects["DIAGNOSTIC_ONLY_FaceEditTrial"]
    actual = snapshot(obj)
    expected = report["expected_reopen_snapshot"]
    assert actual == expected, {k: [expected.get(k), actual.get(k)] for k in set(actual) | set(expected) if actual.get(k) != expected.get(k)}
    basis = obj.data.shape_keys.key_blocks["Basis"]
    edited = obj.data.shape_keys.key_blocks["TEST_NoseProjection_3mm"]
    measured = {}
    for i, (a, b) in enumerate(zip(basis.data, edited.data)):
        delta = obj.matrix_world.to_3x3() @ (b.co - a.co)
        if delta.length > 1e-8:
            measured[i] = list(delta)
    planned = {p["vertex"]: p["delta_world_m"] for p in report["geometry_edit"]["delta_records"]}
    assert set(measured) == set(planned), "Shape edit affected unexpected vertices"
    assert max(abs(measured[i][j] - planned[i][j]) for i in measured for j in range(3)) < 1e-7
    assert not any(o.type == "ARMATURE" for o in bpy.context.scene.objects)
    render(bpy.context.scene, "texture_reopened")
    result = {"snapshot_equal": True, "verified_fields": sorted(actual), "shape_changed_vertices": len(measured), "unexpected_shape_changes": 0, "source_hashes_unchanged": True, "no_armatures": True, "blend_sha256": sha(SPECIMEN), "scope": "file persistence/local edit only; visual quality and game/device approval not granted"}
    (HERE / "reopen_result.json").write_text(json.dumps(result, indent=2) + "\n")
    print("B0302_REOPEN_COMPLETE", json.dumps(result))


if __name__ == "__main__":
    mode = sys.argv[sys.argv.index("--") + 1]
    {"build": build, "verify": verify}[mode]()
