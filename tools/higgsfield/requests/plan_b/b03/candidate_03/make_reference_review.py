"""Create a static source-vs-fresh-model review; never load rejected candidates."""
from PIL import Image, ImageDraw, ImageFont
from pathlib import Path

root = Path('assets/characters/plan_b_viya/candidate_03')
font = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 22)
small = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 16)
columns = [
    ('front.png', 'front.png', 'Front'),
    ('screen_right_profile.png', 'left.png', 'Profile facing right'),
    ('back.png', 'back.png', 'Rear'),
    ('screen_left_profile.png', 'right.png', 'Profile facing left'),
]
cw, ch = 300, 395
sheet = Image.new('RGB', (4 * cw, 2 * ch + 85), (38, 40, 44))
draw = ImageDraw.Draw(sheet)
draw.text((14, 10), 'B-03: all four supplied originals / one fresh 3D model', font=font, fill='white')
draw.text((14, 42), 'Reference poses differ. Static review; no game capture or rejected model reuse.', font=small, fill='#dddddd')
for row in range(2):
    for col, (reference, render, label) in enumerate(columns):
        src = Image.open(root / ('references' if row == 0 else 'review') / (reference if row == 0 else render)).convert('RGBA')
        src.thumbnail((cw - 10, ch - 37), Image.Resampling.LANCZOS)
        tile = Image.new('RGBA', (cw, ch - 30), (115, 115, 115, 255))
        tile.alpha_composite(src, ((cw - src.width) // 2, 0))
        x, y = col * cw, 80 + row * ch
        sheet.paste(tile.convert('RGB'), (x, y + 30))
        draw.text((x + 7, y + 5), ('Original / ' if row == 0 else 'Fresh 03 / ') + label, font=small, fill='white')
sheet.save(root / 'review' / 'four_sources_vs_fresh_model.jpg', quality=94, subsampling=0)

src = Image.open(root / 'review/front.png').convert('RGBA')
src.thumbnail((384, 480), Image.Resampling.LANCZOS)
sheet = Image.new('RGB', (1152, 510), '#444444')
draw = ImageDraw.Draw(sheet)
for i, color in enumerate(((0, 0, 0), (255, 255, 255), (128, 128, 128))):
    tile = Image.new('RGBA', (384, 480), color + (255,))
    tile.alpha_composite(src, ((384 - src.width) // 2, 0))
    sheet.paste(tile.convert('RGB'), (i * 384, 30))
    draw.text((i * 384 + 12, 4), ('Black', 'White', 'Gray')[i], font=small, fill='white')
sheet.save(root / 'review' / 'background_review.jpg', quality=94, subsampling=0)
print('Fresh model and all original sources composed without repainting or rejected assets')
