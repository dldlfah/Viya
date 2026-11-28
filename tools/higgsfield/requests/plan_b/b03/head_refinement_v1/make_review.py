"""Assemble unwarped render/reference comparisons and validate preserved bytes."""
from pathlib import Path
import hashlib
import json
from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[5]
REVIEW = HERE / "review"
FONT = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 19)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def panel(canvas, path, xy, size=None):
    im = Image.open(path).convert("RGBA")
    if size:
        im.thumbnail(size, Image.Resampling.LANCZOS)
    canvas.paste(im, xy, im)


def main():
    refs = json.loads((HERE.parent / "face_reference_v1/face_landmarks.json").read_text())["references"]
    for r in refs:
        assert sha(ROOT / r["path"]) == r["sha256"]
    a = Image.open(REVIEW / "combined_three_quarter.png").convert("RGBA")
    b = Image.open(REVIEW / "combined_three_quarter_reopened.png").convert("RGBA")
    assert a.size == b.size and a.tobytes() == b.tobytes()

    image = Image.new("RGB", (1536, 700), (213, 213, 213))
    d = ImageDraw.Draw(image)
    for x, label, path in [
        (0, "Before", REVIEW / "before_front.png"),
        (512, "First edit: insufficient eyelid change", HERE / "initial_trial/review/combined_front.png"),
        (1024, "Revised eyelids + nose + lips", REVIEW / "combined_front.png"),
    ]:
        d.text((x + 10, 8), label, font=FONT, fill="black")
        panel(image, path, (x, 35))
    d.text((10, 675), "Local form study. Reference-form gate NOT PASSED. No texture / rig / game adoption.", font=FONT, fill="black")
    image.save(REVIEW / "front_comparison.png")

    views = ["front", "screen_left_profile", "screen_right_profile", "three_quarter", "game_high_angle"]
    image = Image.new("RGB", (1920, 1040), (213, 213, 213))
    d = ImageDraw.Draw(image)
    for col, view in enumerate(views):
        for row, tag in enumerate(["before", "combined"]):
            x, y = col * 384, row * 500
            d.text((x + 5, y + 5), tag + " / " + view.replace("screen_", ""), font=FONT, fill="black")
            panel(image, REVIEW / f"{tag}_{view}.png", (x, y + 30), (384, 470))
    d.text((10, 1010), "Identical cameras/light. High angle is a head-only diagnostic, not actual game-size or full-body verification.", font=FONT, fill="black")
    image.save(REVIEW / "multiview_comparison.png")

    image = Image.new("RGB", (1560, 1150), (242, 239, 233))
    d = ImageDraw.Draw(image)
    panel(image, HERE.parent / "face_reference_v1/review/face_reference_board.png", (0, 0))
    for col, (view, label) in enumerate([
        ("front", "Working clay: FRONT"),
        ("screen_right_profile", "Working clay: facing RIGHT"),
        ("screen_left_profile", "Working clay: facing LEFT"),
    ]):
        x = col * 510
        d.text((x + 10, 530), label, font=FONT, fill="black")
        panel(image, REVIEW / f"combined_{view}.png", (x, 560), (490, 550))
    d.text((10, 1120), "Not an aligned overlay or likeness score. Source pixels unchanged; uncalibrated drawn views differ.", font=FONT, fill="black")
    image.save(REVIEW / "reference_vs_refinement.png")

    pixel_report = {
        "four_original_reference_hashes_match": True,
        "reopened_render_decoded_rgba_equal": True,
        "changed_rgba_bytes_after_reopen": 0,
        "image_size": list(a.size),
        "images_are_review_composites_not_new_art": True,
        "scope": "Preservation/persistence only. Not likeness, eyelid contact, animation or game acceptance.",
    }
    (HERE / "pixel_preservation_result.json").write_text(json.dumps(pixel_report, indent=2) + "\n")
    lines = []
    for p in sorted(HERE.rglob("*")):
        if p.is_file() and p.name != "CHECKSUMS.sha256" and "__pycache__" not in p.parts:
            lines.append(f"{sha(p)}  {p.relative_to(HERE).as_posix()}")
    (HERE / "CHECKSUMS.sha256").write_text("\n".join(lines) + "\n")
    print(json.dumps({**pixel_report, "checksummed_files": len(lines)}))


if __name__ == "__main__":
    main()
