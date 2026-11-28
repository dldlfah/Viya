"""Rebuild B-03-01 inspection boards from unchanged user references.

This is source inspection: rectangular crops, integer nearest-neighbour enlargement,
labels and landmarks only. No generation, retouching, mirroring or face restoration.
"""
from pathlib import Path
import csv
import hashlib
import json
from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[5]
OUT = HERE / "review"
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"


def font(size):
    return ImageFont.truetype(FONT, size)


def main():
    data = json.loads((HERE / "face_landmarks.json").read_text())
    OUT.mkdir(exist_ok=True)
    sources = []
    for ref in data["references"]:
        path = ROOT / ref["path"]
        assert hashlib.sha256(path.read_bytes()).hexdigest() == ref["sha256"], path
        im = Image.open(path).convert("RGB")
        assert list(im.size) == ref["size_px"]
        crop = im.crop(ref["inspection_crop_xyxy"])
        enlarged = crop.resize((crop.width * 2, crop.height * 2), Image.Resampling.NEAREST)
        sources.append((ref, enlarged))

    board = Image.new("RGB", (1560, 485), "#f5f2ed")
    d = ImageDraw.Draw(board)
    d.text((20, 12), "B-03-01 | USER REFERENCES | UNCHANGED PIXELS, 2x NEAREST CROPS", fill="#222222", font=font(22))
    for i, (ref, crop) in enumerate(sources):
        x = 15 + i * 390
        d.text((x, 52), ref["display_label"], fill="#222222", font=font(20))
        board.paste(crop, (x, 85))
        d.text((x, 435), ref["short_role"], fill="#222222", font=font(16))
    d.text((20, 465), "Not generated artwork. No alignment, rotation, colour edits or inferred hidden features. Back has no visible face.", fill="#333333", font=font(16))
    board.save(OUT / "face_reference_board.png", optimize=True)

    annotated = Image.new("RGB", (1260, 570), "#f5f2ed")
    d = ImageDraw.Draw(annotated)
    d.text((20, 12), "B-03-01 | MANUAL 2D LANDMARKS | approximate source-pixel observations", fill="#222222", font=font(22))
    rows = []
    for i, (ref, crop) in enumerate(sources[:3]):
        x, y = 20 + i * 420, 85
        d.text((x, 53), ref["display_label"], fill="#222222", font=font(20))
        annotated.paste(crop, (x, y))
        bx, by, _, _ = ref["inspection_crop_xyxy"]
        for p in ref["landmarks"]:
            px, py = p["xy"]
            dx, dy = x + (px - bx) * 2, y + (py - by) * 2
            d.line((dx - 5, dy, dx + 5, dy), fill="#00ffff", width=2)
            d.line((dx, dy - 5, dx, dy + 5), fill="#00ffff", width=2)
            lx, ly = p.get("label_offset", [7, -18])
            tx, ty = dx + lx, dy + ly
            box = d.textbbox((tx, ty), p["id"], font=font(16))
            d.rectangle((box[0] - 2, box[1] - 1, box[2] + 2, box[3] + 1), fill="#14232b")
            d.text((tx, ty), p["id"], fill="#ffffff", font=font(16))
            rows.append([ref["id"], p["id"], p["name"], px, py, p["uncertainty_px"], "manual approximate; not 3D fit/acceptance tolerance"])
        for j, line in enumerate(ref["legend"]):
            d.text((x, 440 + 24 * j), line, fill="#222222", font=font(15))
    d.text((20, 545), "No calibrated camera. Different poses/styles: do not compare raw pixel distances as skull dimensions.", fill="#333333", font=font(18))
    annotated.save(OUT / "face_landmark_board.png", optimize=True)
    with (HERE / "face_landmarks.csv").open("w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["reference", "id", "feature", "source_x_px", "source_y_px", "estimated_manual_uncertainty_px", "scope"])
        writer.writerows(rows)

    outputs = [HERE / "README.md", HERE / ".gdignore", HERE / "face_landmarks.json", HERE / "face_landmarks.csv", HERE / "conflict_matrix.csv", HERE / "build_review.py", OUT / "face_reference_board.png", OUT / "face_landmark_board.png"]
    (HERE / "CHECKSUMS.sha256").write_text("".join(f"{hashlib.sha256(p.read_bytes()).hexdigest()}  {p.relative_to(HERE).as_posix()}\n" for p in outputs))
    print(json.dumps({"source_hashes_verified": 4, "manual_landmarks": len(rows), "boards": 2, "paid_submissions": 0, "source_assets_modified": 0}))


if __name__ == "__main__":
    main()
