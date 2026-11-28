"""Exact-source comparison boards and a source-window audit; no asset edit."""
import csv
import hashlib
import json
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[5]
OUT = HERE / 'review'
PREV = HERE.parent / 'eye_surface_v1'
FONT = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 16)
SMALL = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 13)
BG = (237, 234, 229)


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def tile(canvas, p, xy, size, crop=None, nearest=False):
    im = Image.open(p).convert('RGBA')
    if crop:
        im = im.crop(crop)
    if nearest:
        im = im.resize(size, Image.Resampling.NEAREST)
    else:
        im.thumbnail(size, Image.Resampling.LANCZOS)
    bg = Image.new('RGBA', im.size, (*BG, 255))
    bg.alpha_composite(im)
    canvas.paste(bg.convert('RGB'), xy)


def main():
    refs = json.loads((HERE.parent / 'face_reference_v1/face_landmarks.json').read_text())['references']
    rr = json.loads((HERE / 'render_result.json').read_text())
    assert sha(PREV / 'viya_eye_surface.blend') == rr['input_sha256_before_and_after']
    for ref in refs:
        assert sha(ROOT / ref['path']) == ref['sha256']
    for view in rr['cameras']:
        a = np.asarray(Image.open(OUT / ('color_' + view + '.png')).convert('RGBA'))
        b = np.asarray(Image.open(PREV / 'review' / ('after_' + view + '.png')).convert('RGBA'))
        assert np.array_equal(a, b), view
    by_id = {r['id']: r for r in refs}
    crops = {'front': (118, 236, 398, 478), 'screen_right_profile': (200, 230, 466, 480), 'screen_left_profile': (46, 230, 312, 480)}
    views = list(crops)
    c = Image.new('RGB', (1260, 880), BG)
    d = ImageDraw.Draw(c)
    for i, view in enumerate(views):
        x = i * 420 + 10
        d.text((x, 10), 'SOURCE / ' + view, font=FONT, fill='black')
        tile(c, ROOT / by_id[view]['path'], (x, 45), (360, 340), by_id[view]['inspection_crop_xyxy'], True)
        d.text((x, 415), 'CURRENT / same existing head', font=FONT, fill='black')
        tile(c, OUT / ('color_' + view + '.png'), (x, 450), (390, 360), crops[view])
    d.text((10, 840), 'Uncalibrated drawings / different projection and hair occlusion. No warp, mirroring or numeric likeness score.', font=SMALL, fill='black')
    c.save(OUT / 'front_profiles.png', optimize=True)
    c = Image.new('RGB', (1260, 840), BG)
    d = ImageDraw.Draw(c)
    for i, view in enumerate(views):
        x = i * 420 + 10
        d.text((x, 10), 'COLOR / ' + view, font=FONT, fill='black')
        tile(c, OUT / ('color_' + view + '.png'), (x, 45), (390, 350), crops[view])
        d.text((x, 415), 'CLAY / same geometry', font=FONT, fill='black')
        tile(c, OUT / ('clay_' + view + '.png'), (x, 450), (390, 350), crops[view])
    c.save(OUT / 'shape_color.png', optimize=True)

    source = ROOT / by_id['front']['path']
    im = Image.open(source).convert('RGB')
    c = Image.new('RGB', (1000, 620), BG)
    d = ImageDraw.Draw(c)
    windows = []
    for i, (side, box, center) in enumerate([('screen_left', (702, 158, 755, 200), (727, 182)), ('screen_right', (781, 150, 834, 192), (809, 174))]):
        xoff, yoff = i * 500, 45
        raw = im.crop(box).resize((424, 336), Image.Resampling.NEAREST)
        c.paste(raw, (xoff, yoff))
        x, y = center
        roi = [x - 6, y - 6, x + 7, y + 7]
        d.rectangle(((roi[0]-box[0])*8+xoff, (roi[1]-box[1])*8+yoff, (roi[2]-box[0])*8+xoff, (roi[3]-box[1])*8+yoff), outline='#0088ff', width=2)
        d.text((xoff+5, 10), side + ' / old source window', font=FONT, fill='black')
        tile(c, PREV / 'textures' / ('eye_' + side + '.png'), (xoff+80, 410), (160, 160), (100, 85, 156, 171), True)
        windows.append({'side': side, 'center_px': list(center), 'nominal_source_window_xyxy': roi, 'bake_sampling_half_span_px': 5.5})
    point = [737, 178]
    rgb = list(im.getpixel(tuple(point)))
    assert not (windows[0]['nominal_source_window_xyxy'][0] <= point[0] < windows[0]['nominal_source_window_xyxy'][2])
    px, py = (point[0]-702)*8, (point[1]-158)*8+45
    d.ellipse((px-5, py-5, px+5, py+5), outline='#ffbf00', width=2)
    d.text((10, 585), 'Gold: visible bright source sample (737,178) outside old left window. No new detail was recovered.', font=SMALL, fill='black')
    c.save(OUT / 'iris_sampling.png', optimize=True)
    (HERE / 'iris_sampling_audit.json').write_text(json.dumps({'source_sha256': sha(source), 'authoring_script': 'tools/higgsfield/requests/plan_b/b03/face_surface_v1/bake_surface.py::eye_texture', 'windows': windows, 'screen_left_visible_bright_sample': {'xy': point, 'rgb': rgb, 'outside_original_left_sampling_window': True}, 'confirmed_mechanism': 'The existing small left source sampling window excludes a visible bright eye detail. Copying the atlas unchanged preserved this omission.', 'limitations': 'This does not calibrate the complete iris anatomy/pupil center or explain every likeness difference. Hair occlusion/painted reflection and hidden iris need separate handling. No shifted window adopted in this diagnostic.'}, indent=2) + '\n')

    # Head-only studio reduction. Body, production projection and S20+ raster are absent.
    source_size = [512, 640]
    assumed_height_m, character_height_px, ortho = 1.72, 85.56, .335
    ratio = (character_height_px / assumed_height_m) / (source_size[1] / ortho)
    size = [max(1, round(v * ratio)) for v in source_size]
    c = Image.new('RGB', (1160, 590), BG)
    d = ImageDraw.Draw(c)
    for i, view in enumerate(['front', 'three_quarter', 'game_high_angle']):
        x = i * 380 + 10
        small = Image.open(OUT / ('color_' + view + '.png')).convert('RGBA').resize(tuple(size), Image.Resampling.LANCZOS)
        surface = Image.new('RGBA', (69, 86), (*BG, 255))
        surface.alpha_composite(small, ((69-size[0])//2, 4))
        c.paste(surface.convert('RGB'), (x+100, 60))
        c.paste(surface.convert('RGB').resize((276, 344), Image.Resampling.NEAREST), (x+40, 180))
        d.text((x, 10), view, font=FONT, fill='black')
        d.text((x+40, 155), '4x nearest of head-only estimate', font=SMALL, fill='black')
    d.text((10, 550), '85.56px / assumed1.72m body; studio ortho.335m -> 13x17 full head viewport. Not actual game/mobile output.', font=SMALL, fill='black')
    c.save(OUT / 'display_estimate.png', optimize=True)
    (HERE / 'comparison_registration.json').write_text(json.dumps({'source_crops': {v: by_id[v]['inspection_crop_xyxy'] for v in views}, 'render_crops': crops, 'source_display': '2x nearest, unchanged180x170 crops', 'render_display': 'Aspect-preserving rectangular crop thumbnails; no feature warp/rotation/mirroring', 'display_estimate': {'assumed_character_height_m': assumed_height_m, 'comparison_character_height_px': character_height_px, 'studio_ortho_scale_m': ortho, 'source_render_size': source_size, 'continuous_uniform_scale': ratio, 'rounded_viewport_px': size, 'actual_game_body_camera_raster_not_verified': True}}, indent=2) + '\n')
    (HERE / 'preservation_result.json').write_text(json.dumps({'four_source_hashes_match': True, 'input_blend_sha256_unchanged': True, 'geometry_controls_uv_images_restored_in_read_only_session': True, 'six_fresh_color_renders_match_previous_decoded_rgba': True, 'model_or_texture_written': False, 'game_or_asset_changes': False, 'scope': 'Diagnostic repeatability and no-edit preservation; not art/producer/game acceptance.'}, indent=2) + '\n')
    findings = json.loads((HERE / 'findings.json').read_text())['findings']
    with (HERE / 'findings.csv').open('w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=list(findings[0]), lineterminator='\n')
        writer.writeheader()
        writer.writerows(findings)
    print('FACE_GATE_BOARDS_BUILT')


if __name__ == '__main__':
    main()
