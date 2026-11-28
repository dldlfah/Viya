"""Make a labeled review figure from existing Blender renders, without repainting.

This is a static comparison figure, not a game screenshot or a generation input.
Run from repository root: python compare_candidates.py
"""
from PIL import Image, ImageDraw, ImageFont
from pathlib import Path
import json

base = Path('assets/characters/plan_b_viya')
out = base / 'candidate_02' / 'review'
font_path = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
font = ImageFont.truetype(font_path, 22)
small = ImageFont.truetype(font_path, 17)
columns = [('front.png', 'Front'), ('back.png', 'Rear'),
           ('game_high_angle.png', '55-degree view'),
           ('skin_stress_side.png', 'Skin stress (diagnostic)')]
cell_w, cell_h = 300, 395
sheet = Image.new('RGB', (4 * cell_w, 2 * cell_h + 85), (38, 40, 44))
draw = ImageDraw.Draw(sheet)
draw.text((16, 12), 'B-03: candidate 01 vs supplied front/rear candidate 02', font=font, fill='white')
draw.text((16, 43), 'Same camera and texture-only shader. No color correction. Not game capture.', font=small, fill=(205, 208, 214))
for row, candidate in enumerate(('candidate_01', 'candidate_02')):
    for col, (filename, label) in enumerate(columns):
        src = Image.open(base / candidate / 'review' / filename).convert('RGBA')
        # Uniform whole-canvas resampling for a labeled figure, no alpha-bound fitting.
        src.thumbnail((cell_w - 12, cell_h - 40), Image.Resampling.LANCZOS)
        x, y = col * cell_w, 80 + row * cell_h
        tile = Image.new('RGBA', (cell_w, cell_h - 32), (110, 110, 110, 255))
        tile.alpha_composite(src, ((cell_w - src.width) // 2, 0))
        sheet.paste(tile.convert('RGB'), (x, y + 32))
        draw.text((x + 8, y + 5), candidate[-2:] + ' / ' + label, font=small, fill='white')
sheet.save(out / 'candidate_01_vs_02.jpg', quality=94, subsampling=0)

# The same render on black/white/gray helps inspect source texture and silhouette.
src = Image.open(out / 'front.png').convert('RGBA')
src.thumbnail((384, 480), Image.Resampling.LANCZOS)
backgrounds = Image.new('RGB', (3 * 384, 510), '#444444')
bdraw = ImageDraw.Draw(backgrounds)
for col, color in enumerate(((0, 0, 0), (255, 255, 255), (128, 128, 128))):
    tile = Image.new('RGBA', (384, 480), color + (255,))
    tile.alpha_composite(src, ((384 - src.width) // 2, 0))
    backgrounds.paste(tile.convert('RGB'), (col * 384, 30))
    bdraw.text((col * 384 + 12, 5), ('Black', 'White', 'Gray')[col], font=small, fill='white')
backgrounds.save(out / 'background_review.jpg', quality=94, subsampling=0)

summary = {}
for candidate in ('candidate_01', 'candidate_02'):
    report = json.loads((base / candidate / 'review' / 'structure_report.json').read_text())
    summary[candidate] = {
        'meshes': len(report['mesh_objects']),
        'triangles': sum(m['triangles'] for m in report['mesh_objects']),
        'bones': sum(a['bone_count'] for a in report['armatures']),
        'unweighted_vertices': report['unweighted_vertices'],
        'raw_sha256': report['raw_glb_sha256'],
        'texture_images': report['images'],
    }
(out / 'comparison_metrics.json').write_text(json.dumps(summary, indent=2) + '\n')
print(json.dumps(summary))
