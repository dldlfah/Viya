#!/usr/bin/env python3
"""Build a GAME065 run_fire_e derivative from inspected PNGs and actual timing.

Does not generate/edit images or change the active game configuration. The
GAME064 resource and its 244 frames remain unchanged. Run only after the real
GAME065 output has been selected and its timing/phase table has been prepared.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import io
import json
import math
from pathlib import Path
import re
import struct

try:
    from PIL import Image as PillowImage
except ImportError:
    PillowImage = None

ROOT = Path(__file__).resolve().parents[1]
PILOT = ROOT / 'assets/characters/pilot_32'
SOURCE = PILOT / 'game064_e_run/viya_game064_frames.tres'
DERIVED = PILOT / 'game065_e_run_fire'
TIMING = DERIVED / 'provenance/frame_timing.csv'
OUTPUT = DERIVED / 'viya_game065_frames.tres'
REQUIRED_COLUMNS = (
    'frame', 'filename', 'source_frame', 'source_time_ms', 'start_ms',
    'duration_ms', 'normalized_phase', 'reference_source_frame',
)
EXT_RESOURCE = re.compile(
    r'^\[ext_resource type="Texture2D" path="(?P<path>[^"]+)" '
    r'id="(?P<id>[^"]+)"\]$', re.M)
ANIMATION = re.compile(
    r'\{\n"frames": \[(?P<frames>.*?)\],\n"loop": (?P<loop>true|false),'
    r'\n"name": &"(?P<name>[^"]+)",\n"speed": (?P<speed>[0-9.eE+-]+)\n\}', re.S)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def finite_number(value: str, label: str, *, positive: bool = False) -> float:
    try:
        number = float(value)
    except (TypeError, ValueError) as error:
        raise ValueError(f'{label}: expected a number, got {value!r}') from error
    require(math.isfinite(number), f'{label}: must be finite')
    require(number > 0 if positive else number >= 0,
            f'{label}: must be {"positive" if positive else "nonnegative"}')
    return number


def integer(value: str, label: str) -> int:
    number = finite_number(value, label)
    require(number.is_integer(), f'{label}: must be an integer')
    return int(number)


def png_metadata(path: Path) -> dict:
    data = path.read_bytes()
    require(len(data) >= 33 and data[:8] == b'\x89PNG\r\n\x1a\n'
            and data[8:16] == b'\x00\x00\x00\rIHDR', f'{path}: invalid PNG header')
    width, height, depth, color_type, compression, filtering, interlace = struct.unpack(
        '>IIBBBBB', data[16:29])
    require((width, height) == (200, 248), f'{path}: expected 200x248 canvas')
    require(color_type == 6 and depth == 8, f'{path}: expected true 8-bit RGBA PNG')
    require(compression == 0 and filtering == 0 and interlace in (0, 1),
            f'{path}: unsupported PNG header')
    result = {'sha256': hashlib.sha256(data).hexdigest()}
    if PillowImage is not None:
        with PillowImage.open(io.BytesIO(data)) as image:
            image.verify()
        with PillowImage.open(io.BytesIO(data)) as image:
            image.load()
            require(image.format == 'PNG' and image.mode == 'RGBA'
                    and image.size == (200, 248), f'{path}: decoded image is not 200x248 RGBA')
            result['pixel_sha256'] = hashlib.sha256(image.tobytes()).hexdigest()
            result['alpha_range'] = list(image.getchannel('A').getextrema())
    return result


def load_frames() -> tuple[list[dict], float, float]:
    with TIMING.open(encoding='utf-8-sig', newline='') as stream:
        reader = csv.DictReader(stream)
        fields = reader.fieldnames or []
        require(len(fields) == len(set(fields)), 'CSV contains duplicate column names')
        require(set(REQUIRED_COLUMNS).issubset(fields),
                'CSV must contain: ' + ', '.join(REQUIRED_COLUMNS))
        rows = list(reader)
    require(bool(rows), 'CSV contains no frames')
    entries = []
    elapsed = 0.0
    for index, row in enumerate(rows):
        label = f'frame {index}'
        require(None not in row, f'{label}: unexpected extra CSV values')
        require(integer(row['frame'], label + '.frame') == index,
                'CSV frame indices must be contiguous and ordered from 0')
        filename = row['filename']
        require(isinstance(filename, str)
                and re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_.-]*\.png', filename) is not None,
                f'{label}: filename must be a plain PNG basename')
        start = finite_number(row['start_ms'], label + '.start_ms')
        duration = finite_number(row['duration_ms'], label + '.duration_ms', positive=True)
        phase = finite_number(row['normalized_phase'], label + '.normalized_phase')
        require(phase < 1, f'{label}: normalized_phase must be in [0,1)')
        require(math.isclose(start, elapsed, rel_tol=1e-9, abs_tol=1e-6),
                f'{label}: start_ms {start} is not contiguous with {elapsed}')
        path = DERIVED / 'frames' / filename
        require(path.is_file(), f'{label}: missing {path}')
        entry = {
            'index': index, 'path': path.relative_to(DERIVED).as_posix(),
            'source_frame': integer(row['source_frame'], label + '.source_frame'),
            'source_time_ms': finite_number(row['source_time_ms'], label + '.source_time_ms'),
            'start_ms': start, 'duration_ms': duration, 'normalized_phase': phase,
            'reference_source_frame': finite_number(row['reference_source_frame'],
                                                    label + '.reference_source_frame'),
            **png_metadata(path),
        }
        entries.append(entry)
        elapsed += duration
        require(math.isfinite(elapsed), 'Cumulative duration is not finite')
    total_ms = math.fsum(entry['duration_ms'] for entry in entries)
    require(math.isfinite(total_ms) and total_ms > 0, 'Cycle duration must be finite and positive')
    require(len({entry['path'] for entry in entries}) == len(entries), 'Duplicate frame filename')
    require(len({entry['sha256'] for entry in entries}) == len(entries), 'Duplicate PNG bytes')
    if PillowImage is not None:
        require(len({entry['pixel_sha256'] for entry in entries}) == len(entries),
                'Duplicate decoded frame pixels, including a possible copied closing frame')
    fps = len(entries) * 1000 / total_ms
    require(math.isfinite(fps) and fps > 0, 'Animation FPS must be finite and positive')
    for entry in entries:
        require(math.isclose(entry['normalized_phase'], entry['start_ms'] / total_ms,
                             rel_tol=1e-9, abs_tol=1e-9),
                f'frame {entry["index"]}: normalized_phase does not match start_ms/cycle_ms')
        entry['relative_duration'] = entry['duration_ms'] * fps / 1000
        require(math.isfinite(entry['relative_duration']) and entry['relative_duration'] > 0,
                f'frame {entry["index"]}: invalid relative duration')
    return entries, total_ms, fps


def build_resource(source: str, entries: list[dict], fps: float) -> tuple[str, dict]:
    old_animations = list(ANIMATION.finditer(source))
    by_name = {match['name']: match for match in old_animations}
    require(len(old_animations) == len(by_name) == 32 and 'run_e' in by_name,
            'Preserved GAME064 resource must have 32 unique animations including run_e')
    require('run_fire_e' not in by_name, 'Preserved source unexpectedly already has run_fire_e')
    old_counts = {name: len(re.findall(r'ExtResource\("[^"]+"\)', match['frames']))
                  for name, match in by_name.items()}
    require(sum(old_counts.values()) == 244, 'Preserved GAME064 resource must contain 244 frames')
    old_textures = list(EXT_RESOURCE.finditer(source))
    old_ids = {match['id'] for match in old_textures}
    require(len(old_textures) == len(old_ids) == 244,
            'Preserved resource must contain 244 unique texture declarations')
    east_ids = set(re.findall(r'ExtResource\("([^"]+)"\)', by_name['run_e']['frames']))
    require(east_ids.issubset(old_ids) and len(east_ids) == old_counts['run_e'],
            'Preserved E run texture references must be distinct and declared')

    def relocate(match: re.Match) -> str:
        old_path = match['path']
        new_path = old_path
        if match['id'] in east_ids:
            require(old_path.startswith('frames/'), 'Expected GAME064 E frame in its frames folder')
            new_path = '../game064_e_run/' + old_path
        old_target = (SOURCE.parent / old_path).resolve()
        new_target = (DERIVED / new_path).resolve()
        require(old_target == new_target and old_target.is_file(),
                f'Preserved texture reference changed or is missing: {old_path}')
        return match[0].replace('path="' + old_path + '"', 'path="' + new_path + '"', 1)

    text = EXT_RESOURCE.sub(relocate, source)
    require(text.count('load_steps=245') == 1, 'Unexpected GAME064 load_steps header')
    text = text.replace('load_steps=245', f'load_steps={245 + len(entries)}', 1)
    require(text.count('[resource]') == 1, 'Expected exactly one resource section')
    new_ids = [f'game065_fire_e_{entry["index"]:03d}' for entry in entries]
    require(old_ids.isdisjoint(new_ids), 'New texture IDs collide with preserved resource')
    definitions = '\n'.join(
        f'[ext_resource type="Texture2D" path="{entry["path"]}" id="{texture_id}"]'
        for entry, texture_id in zip(entries, new_ids))
    text = text.replace('[resource]', definitions + '\n\n[resource]', 1)
    animation_array = re.search(r'^animations\s*=\s*\[(?P<body>.*)\]\s*\Z', text, re.M | re.S)
    require(animation_array is not None, 'Expected final SpriteFrames animations array')
    frames = ',\n'.join(
        '{"duration": ' + format(entry['relative_duration'], '.17g')
        + ', "texture": ExtResource("' + texture_id + '")}'
        for entry, texture_id in zip(entries, new_ids))
    added = ('{\n"frames": [' + frames + '],\n"loop": true,\n'
             '"name": &"run_fire_e",\n"speed": ' + format(fps, '.17g') + '\n}')
    text = (text[:animation_array.end('body')] + ', ' + added
            + text[animation_array.end('body'):])
    new_animations = {match['name']: match for match in ANIMATION.finditer(text)}
    require(len(new_animations) == 33 and 'run_fire_e' in new_animations,
            'Derived resource did not contain exactly 33 animations')
    require(all(new_animations[name][0] == match[0] for name, match in by_name.items()),
            'An existing animation body or its timing changed')
    return text, old_counts


def build(source_job: str, model: str) -> dict:
    require(bool(source_job.strip()) and bool(model.strip()), 'Source job and model are required')
    entries, total_ms, fps = load_frames()
    source_bytes = SOURCE.read_bytes()
    text, preserved_counts = build_resource(source_bytes.decode('utf-8'), entries, fps)
    output_bytes = text.encode('utf-8')
    manifest = {
        'schema': 1, 'scope': 'GAME065 E moving-fire only; existing 244 frames and 32 animations preserved',
        'resource': 'res://' + OUTPUT.relative_to(ROOT).as_posix(),
        'resource_sha256': hashlib.sha256(output_bytes).hexdigest(),
        'preserved_resource': 'res://' + SOURCE.relative_to(ROOT).as_posix(),
        'preserved_resource_sha256': hashlib.sha256(source_bytes).hexdigest(),
        'preserved_animation_frame_counts': preserved_counts,
        'timing_csv_sha256': hashlib.sha256(TIMING.read_bytes()).hexdigest(),
        'source_job_id': source_job, 'model': model, 'added_animation': 'run_fire_e',
        'canvas': [200, 248], 'pivot': [100, 248], 'pivot_normalized': [0.5, 1],
        'display_size': [69, 85.56], 'nominal_cycle_ms': total_ms, 'fps': fps,
        'frames': entries, 'new_frame_count': len(entries), 'animation_count': 33,
        'active_frame_count': 244 + len(entries), 'unchanged_frame_count': 244,
        'stride_world': 155, 'speed_world_per_second': 235,
        'distance_driven_cycle_ms_at_base_speed': 1000 * 155 / 235,
        'timing_note': 'Actual CSV durations and normalized phases retained; runtime gait remains distance/155. Reference source-frame correspondence is supplied by the inspected production output, not inferred by this builder.',
        'image_validation': {
            'method': 'Pillow decoded PNG/RGBA validation and pixel uniqueness' if PillowImage is not None
                      else 'PNG IHDR validation only; Pillow unavailable, full decode not verified',
            'decoded_pixel_uniqueness_checked': PillowImage is not None,
        },
        'originals_rewritten_by_builder': False, 'pngs_modified_by_builder': False,
        'game_config_modified_by_builder': False, 'new_generation_by_builder': False,
        'game_integration': 'This builder only packages the resource. The executed integration status is recorded separately in docs/validation/GAME065_INTEGRATION_REPORT.json.',
        'game_integration_report': 'docs/validation/GAME065_INTEGRATION_REPORT.json',
        'art_approval': 'Final user visual approval is separate from technical QA and game integration.',
    }
    manifest_bytes = (json.dumps(manifest, ensure_ascii=False, indent=2, allow_nan=False) + '\n').encode('utf-8')
    # Nothing is written until every input and preservation check has passed.
    for path, data in ((OUTPUT, output_bytes), (DERIVED / 'manifest.json', manifest_bytes)):
        temporary = path.with_name(path.name + '.tmp')
        temporary.write_bytes(data)
        temporary.replace(path)
    require(SOURCE.read_bytes() == source_bytes, 'Preserved resource changed during this build')
    return manifest


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-job', required=True, help='Actual selected Higgsfield output job ID')
    parser.add_argument('--model', required=True, help='Actual selected model ID, not an assumed default')
    args = parser.parse_args()
    try:
        result = build(args.source_job, args.model)
    except (OSError, ValueError, csv.Error, OverflowError) as error:
        parser.exit(1, f'GAME065 build failed: {error}\n')
    print(json.dumps({'frames': result['new_frame_count'], 'animations': result['animation_count'],
                      'resource_frames': result['active_frame_count'], 'resource': result['resource'],
                      'cycle_ms': result['nominal_cycle_ms']}, ensure_ascii=False))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
