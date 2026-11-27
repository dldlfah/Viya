#!/usr/bin/env python3
"""Build the local GAME070 motion-reference packet from reviewed files."""

import argparse
import hashlib
import io
import json
from pathlib import Path
from zipfile import ZIP_STORED, ZipFile, ZipInfo

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
PACKET = ROOT / "tools/higgsfield/requests/game070"
SW_SOURCE = Path("assets/characters/pilot_32/render_cache")
TIMING_VIDEO = "docs/validation/GAME070_S_TIMING_REFERENCE.mp4"
TIMING_REPORT = "docs/validation/GAME070_BASELINE_REPORT.json"
IMAGE_SOURCES = {
    "00": "b29c5ee38d4562d8d5f1eb98c063a34e4ee8d004264fc39d6c19b79b49b8ea7f",
    "08": "b5d2acd28711971488a3d2c9f82927fc921011ac35d2af34ddcb626ddfdac9fd",
}
PORTRAIT_SIZE = (960, 1280)
PORTRAIT_OFFSET = (80, 144)
KEY_GREEN = (28, 223, 28)


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def checked_source(path: Path | str, expected: str) -> bytes:
    data = (ROOT / path).read_bytes()
    if sha256(data) != expected:
        raise ValueError(f"Reviewed source has changed: {path}")
    return data


def sw_reference(data: bytes) -> bytes:
    with Image.open(io.BytesIO(data)) as source:
        if source.size != (200, 248) or source.mode != "RGBA":
            raise ValueError("Expected the original 200×248 RGBA SW reference")
        scaled = source.resize((800, 992), Image.Resampling.NEAREST)
    plate = Image.new("RGB", PORTRAIT_SIZE, KEY_GREEN)
    plate.paste(scaled, PORTRAIT_OFFSET, scaled.getchannel("A"))
    result = io.BytesIO()
    plate.save(result, format="PNG")
    return result.getvalue()


def build(output: Path) -> dict:
    report = json.loads((ROOT / TIMING_REPORT).read_text())
    timing = report["timing_reference"]
    video = checked_source(TIMING_VIDEO, timing["sha256"])
    catalog = json.loads((PACKET / "evidence/model_seedance_2_5.json").read_text())
    model = catalog["structuredContent"]
    options = {item["name"]: item for item in model["parameters"]}
    roles = set(model["medias"][0]["roles"])
    if not {"image_references", "video_references"}.issubset(roles):
        raise ValueError("Archived catalog lacks the proposed media roles")
    if "omni_reference" not in options["mode"]["options"] or "720p" not in options["resolution"]["options"]:
        raise ValueError("Archived catalog lacks the proposed generation settings")
    if "3:4" not in model["aspect_ratios"] or not options["duration"]["min"] <= 4 <= options["duration"]["max"]:
        raise ValueError("Archived catalog lacks the proposed aspect ratio or duration")

    files = {}
    media = []
    for frame, expected in IMAGE_SOURCES.items():
        source_path = SW_SOURCE / f"viya_run_sw_{frame}.png"
        name = f"sw_{frame}_appearance.png"
        files[name] = sw_reference(checked_source(source_path, expected))
        media.append({"file": name, "role": "image_references", "source": source_path.as_posix(), "source_sha256": expected})
    name = "s17_gait_timing.mp4"
    files[name] = video
    media.append({"file": name, "role": "video_references", "source": TIMING_VIDEO, "source_sha256": timing["sha256"]})
    files["prompt.txt"] = (PACKET / "PROMPT_TIMING_EN.txt").read_bytes()
    files["README.md"] = (PACKET / "PACKET_README.md").read_bytes()
    manifest = {
        "task": "GAME070_SW_RUN",
        "kind": "local planning packet",
        "model": model["id"],
        "model_schema_scope": "Checked against the saved catalog. Review current fields and quote in the connected planning session.",
        "settings": {"mode": "omni_reference", "duration": 4, "resolution": "720p", "aspect_ratio": "3:4", "generate_audio": False, "count": 1},
        "media": media,
        "portrait": {"canvas": PORTRAIT_SIZE, "original_scale": 4, "offset": PORTRAIT_OFFSET, "background_rgb": KEY_GREEN},
        "timing": {"source_frames_zero_based": timing["source_frames_zero_based"], "fps": timing["fps"], "frames": timing["output_frames"], "repeats": timing["repeats"]},
        "sha256": {name: sha256(data) for name, data in files.items()},
    }
    files["manifest.json"] = (json.dumps(manifest, ensure_ascii=False, indent=2) + "\n").encode()
    output.parent.mkdir(parents=True, exist_ok=True)
    with ZipFile(output, "w", compression=ZIP_STORED) as archive:
        for name, data in files.items():
            archive.writestr(ZipInfo(name), data)
    return {"packet": str(output), "members": len(files), "sha256": sha256(output.read_bytes())}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(build(args.output), ensure_ascii=False))


if __name__ == "__main__":
    main()
