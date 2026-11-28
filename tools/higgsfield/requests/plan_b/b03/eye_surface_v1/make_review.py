"""Reproducible color-only comparisons, source checks and visible iris diagnostics."""
import hashlib
import importlib.util
import json
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[5]
PREV = HERE.parent / 'eye_refinement_v1'
OUT = HERE / 'review'
spec = importlib.util.spec_from_file_location('eye_review_utilities', PREV / 'make_review.py')
old = importlib.util.module_from_spec(spec)
spec.loader.exec_module(old)
panel, FONT = old.panel, old.FONT


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def pixels(p):
    return np.asarray(Image.open(p).convert('RGBA'))


def main():
    build = json.loads((HERE / 'build_result.json').read_text())
    reopen = json.loads((HERE / 'reopen_result.json').read_text())
    paint = json.loads((HERE / 'paint_result.json').read_text())
    refs = json.loads((HERE.parent / 'face_surface_v1/surface_authoring.json').read_text())['references']
    for r in refs:
        assert sha(ROOT / r['path']) == r['sha256']
    assert sha(PREV / 'viya_eye_refinement.blend') == build['input_sha256']
    assert sha(HERE / 'viya_eye_surface.blend') == build['output_sha256'] == reopen['output_sha256']
    assert np.array_equal(pixels(OUT / 'after_three_quarter.png'), pixels(OUT / 'after_three_quarter_reopened.png'))
    skin = 'CC0_head_skin_UNAPPROVED'
    assert build['before_active_image_hashes'][skin] == build['after_active_image_hashes'][skin]
    links = []
    for obj, images in build['after_active_image_hashes'].items():
        for name, digest in images.items():
            p = (HERE.parent / 'face_surface_v4/textures' if obj == skin else HERE / 'textures') / name
            assert sha(p) == digest
            links.append({'object': obj, 'path': p.relative_to(ROOT).as_posix(), 'sha256': digest, 'packed': True})
    for r in paint['records']:
        name = 'eye_screen_' + r['side'] + '.png'
        a = pixels(HERE.parent / 'face_surface_v4/textures' / name)
        b = pixels(HERE / 'textures' / name)
        mask = pixels(HERE / 'textures' / ('iris_mask_' + r['side'] + '.png'))[:, :, 1] > 200
        assert int(mask.sum()) == r['iris_pixels_protected']
        assert np.array_equal(a[mask], b[mask])
        assert int(np.any(a != b, axis=2).sum()) == r['changed_pixels']
    (HERE / 'texture_links.json').write_text(json.dumps({'images': links, 'scope': 'Head retained, two derived eye maps; diagnostic masks are not final color maps.'}, indent=2) + '\n')

    exposure, edges = {}, {}
    for view in ['front', 'three_quarter', 'three_quarter_opposite']:
        labels = pixels(OUT / ('label_' + view + '.png')).astype(int)
        iris = pixels(OUT / ('iris_label_' + view + '.png')).astype(int)
        old_render = pixels(PREV / 'review' / ('after_' + view + '.png')).astype(int)
        helper = (labels[:, :, 3] > 240) & ((labels[:, :, 1] > labels[:, :, 0] + 100) | (labels[:, :, 2] > labels[:, :, 0] + 100))
        visible_iris = (iris[:, :, 3] > 240) & (iris[:, :, 1] > 200) & (iris[:, :, 2] < 40) & helper
        exposure[view] = {}
        for side, channel in [('screen_left', 2), ('screen_right', 1)]:
            own = helper & (labels[:, :, channel] > 200)
            n, total = int((visible_iris & own).sum()), int(own.sum())
            exposure[view][side] = {'hard_labeled_helper_pixels': total, 'hard_labeled_iris_pixels': n, 'iris_fraction': n / total if total else None}
        band = np.zeros(helper.shape, bool)
        for x in np.where(helper.any(axis=0))[0]:
            y = np.where(helper[:, x])[0].max()
            band[max(0, y - 1):min(helper.shape[0], y + 2), x] = True
        bright = band & (old_render[:, :, :3].mean(axis=2) > 210) & (old_render[:, :, 3] > 240)
        edges[view] = {'hard_labeled_helper_pixels': int(helper.sum()), 'bright_lower_band_samples': int(bright.sum()), 'samples_owned_by_eye_helper': int((bright & helper).sum())}
    (HERE / 'visible_edge_diagnosis.json').write_text(json.dumps({'views': edges, 'rule': 'Per helper-column bottom +/-1px; RGB mean>210, alpha>240; hard ID excludes antialias margins.', 'scope': 'Conservative sparse ownership samples only, not all boundary/contact or intersection proof.'}, indent=2) + '\n')
    (HERE / 'iris_exposure.json').write_text(json.dumps({'views': exposure, 'geometry_uv_and_iris_region_unchanged': True, 'scope': 'Hard-label render counts exclude mixed/AA pixels. Not calibrated source exposure, likeness or physical eye-contact acceptance. Bilinear color mixing with the changed sclera can change rendered boundary contrast.'}, indent=2) + '\n')

    source = ROOT / 'assets/characters/plan_b_viya/candidate_03/references/front.png'
    c = Image.new('RGB', (1536, 640), (242, 239, 233))
    panel(c, source, (8, 8), 'Unchanged source / nearest crop', crop=(680, 120, 860, 290), size=(432, 408))
    panel(c, PREV / 'review/after_front.png', (520, 8), 'Before: R5 / old eye color', crop=(118, 236, 398, 478), size=(496, 429))
    panel(c, OUT / 'after_front.png', (1032, 8), 'Current: same R5 / derived sclera color', crop=(118, 236, 398, 478), size=(496, 429))
    ImageDraw.Draw(c).text((10, 600), 'Source projection differs. Hair unmade. No producer approval or likeness score.', font=FONT, fill='black')
    c.save(OUT / 'source_before_after.png')
    c = Image.new('RGB', (1536, 1040), (218, 216, 212))
    for i, view in enumerate(['front', 'three_quarter', 'three_quarter_opposite']):
        panel(c, PREV / 'review' / ('after_' + view + '.png'), (i * 512 + 8, 5), 'Before / ' + view, size=(384, 460))
        panel(c, OUT / ('after_' + view + '.png'), (i * 512 + 8, 505), 'Current / ' + view, size=(384, 460))
    ImageDraw.Draw(c).text((10, 1010), 'Same geometry, UV, camera, head image and shader mix. Only two eye color images changed.', font=FONT, fill='black')
    c.save(OUT / 'paired_views.png')
    c = Image.new('RGB', (1536, 1040), (218, 216, 212))
    views = ['front', 'three_quarter', 'three_quarter_opposite', 'screen_left_profile', 'screen_right_profile', 'game_high_angle']
    for i, view in enumerate(views):
        panel(c, OUT / ('after_' + view + '.png'), ((i % 3) * 512 + 8, (i // 3) * 500 + 5), view, size=(384, 460))
    c.save(OUT / 'surface_views.png')
    c = Image.new('RGB', (1536, 480), (242, 239, 233))
    for i, (path, label) in enumerate([(source, 'Source pixels'), (PREV / 'review/after_front.png', 'Before'), (OUT / 'after_front.png', 'Current')]):
        panel(c, path, (i * 512 + 8, 8), label, crop=(706, 156, 831, 199) if i == 0 else (148, 285, 365, 329), size=(496, 270))
    ImageDraw.Draw(c).text((10, 430), 'Original 2,028 iris texels per eye protected. Source not aligned, mirrored or upscaled for detail recovery.', font=FONT, fill='black')
    c.save(OUT / 'eye_details.png')
    c = Image.new('RGB', (1536, 700), (218, 216, 212))
    for i, view in enumerate(['front', 'three_quarter', 'three_quarter_opposite']):
        panel(c, OUT / ('unlit_after_' + view + '.png'), (i * 512 + 8, 8), 'All three materials unlit / ' + view)
    c.save(OUT / 'unlit_views.png')
    c = Image.new('RGB', (1024, 760), (242, 239, 233))
    crop = (706, 158, 832, 199)
    raw = Image.open(source).convert('RGB').crop(crop).resize((1008, 328), Image.Resampling.NEAREST)
    c.paste(raw, (8, 40)); annotated = raw.copy(); d = ImageDraw.Draw(annotated)
    for r in paint['records']:
        for key, color in [('source_base', '#00aaff'), ('source_lower_edge', '#ff9900')]:
            x0, y0, x1, y1 = r[key]['box']
            d.rectangle(((x0-crop[0])*8, (y0-crop[1])*8, (x1-crop[0])*8, (y1-crop[1])*8), outline=color, width=2)
    c.paste(annotated, (8, 400)); d = ImageDraw.Draw(c)
    d.text((8, 10), 'Native source crop / 8x nearest-neighbor', font=FONT, fill='black')
    d.text((8, 375), 'Blue: bright patch; orange: lower edge. Ambiguous outer shadow not used as sclera base.', font=FONT, fill='black')
    d.text((8, 735), 'Observed painted color, not physically calibrated albedo. Lower-edge blend is authored.', font=FONT, fill='black')
    c.save(OUT / 'source_patches.png')
    result = {'four_source_hashes_match': True, 'input_blend_sha256_unchanged': True, 'all_geometry_controls_uv_equal': True, 'head_image_bytes_identical': True, 'original_iris_texels_per_eye': 2028, 'iris_texels_identical': True, 'reopened_decoded_rgba_identical': True, 'previous_eye_materials_retained': True, 'scope': 'Preservation and persistence only; not likeness/producer/rig/game/device approval.'}
    (HERE / 'preservation_result.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result))


if __name__ == '__main__':
    main()
