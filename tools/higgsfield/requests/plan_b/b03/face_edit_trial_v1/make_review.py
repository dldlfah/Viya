"""Inspect source pixels, compare independently reopened render and make boards."""
from pathlib import Path
import hashlib
import json
from PIL import Image, ImageChops, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[5]
R = HERE / "review"
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"


def main():
    src = Image.open(ROOT / "assets/characters/plan_b_viya/candidate_03/references/front.png").convert("RGBA")
    crop = Image.open(HERE / "source_face_crop.png").convert("RGBA")
    assert src.crop((665, 115, 875, 290)).tobytes() == crop.tobytes()
    rows = {}
    for a, b, name in [("texture_combined", "texture_reopened", "reopen_render"), ("texture_before", "uv_only", "uv_only_change"), ("clay_before", "clay_geometry", "geometry_change")]:
        ia = Image.open(R / (a + ".png")).convert("RGBA")
        ib = Image.open(R / (b + ".png")).convert("RGBA")
        diff = ImageChops.difference(ia, ib)
        raw = memoryview(diff.tobytes())
        count = sum(any(raw[i:i + 3]) for i in range(0, len(raw), 4))
        rows[name] = {"equal_pixels": ia.tobytes() == ib.tobytes(), "changed_pixels": count, "bbox_xyxy": diff.convert("RGB").getbbox(), "width": ia.width, "height": ia.height}
    assert rows["reopen_render"]["equal_pixels"]
    assert rows["uv_only_change"]["changed_pixels"] > 0
    assert rows["geometry_change"]["changed_pixels"] > 0
    rows["interpretation"] = "Pixel differences demonstrate a visible operation, not reference likeness. Clay differences include renderer shading effects. Reopen equality checks persistence, not appearance approval."
    (HERE / "pixel_comparison.json").write_text(json.dumps(rows, indent=2) + "\n")
    font = ImageFont.truetype(FONT, 20)
    small = ImageFont.truetype(FONT, 17)
    boards = {
        "method_comparison": [("Before (unapproved03)", "texture_before"), ("Nose geometry only", "geometry_only"), ("Mouth UV only", "uv_only"), ("Combined trial (unapproved)", "texture_combined")],
        "geometry_comparison": [("Clay before", "clay_before"), ("Clay: local nose edit", "clay_geometry"), ("Oblique before", "oblique_before"), ("Oblique: combined trial", "oblique_combined")],
    }
    for name, items in boards.items():
        out = Image.new("RGB", (1536, 450), "#dedede")
        d = ImageDraw.Draw(out)
        for i, (label, image) in enumerate(items):
            im = Image.open(R / (image + ".png")).convert("RGBA")
            bg = Image.new("RGBA", im.size, "#dedede"); bg.alpha_composite(im)
            out.paste(bg.convert("RGB"), (i * 384, 35))
            d.text((i * 384 + 8, 8), label, font=font, fill="black")
        d.text((15, 426), "B-03-02 local editing capability only. Same camera/settings within each pair. Not accepted VIYA; no game/device approval.", font=small, fill="black")
        out.save(R / (name + ".png"), optimize=True)
    (HERE / "CHECKSUMS.sha256").write_text("".join(f"{hashlib.sha256(p.read_bytes()).hexdigest()}  {p.relative_to(HERE).as_posix()}\n" for p in sorted(HERE.rglob("*")) if p.is_file() and p.name != "CHECKSUMS.sha256"))
    print(json.dumps({"source_crop_pixels_unchanged": True, "reopened_render_identical": True, "boards": 2}))


if __name__ == "__main__":
    main()
