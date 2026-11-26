#!/usr/bin/env python3
"""Rebuild only the GAME064 SpriteFrames derivative, without editing any PNG.

The preserved ARTFIX001 resource supplies the other 197 frames. The delivered
CSV supplies all 47 E frame durations. Existing resources remain byte-identical.
"""
from __future__ import annotations
import csv
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
PILOT = ROOT / 'assets/characters/pilot_32'
DERIVED = PILOT / 'game064_e_run'
SOURCE = PILOT / 'render_cache/viya_render_frames.tres'
OUTPUT = DERIVED / 'viya_game064_frames.tres'


def build() -> dict:
    rows = list(csv.DictReader((DERIVED / 'provenance/frame_timing.csv').open()))
    assert len(rows) == 47 and [int(r['frame']) for r in rows] == list(range(47))
    total_ms = sum(float(r['duration_ms']) for r in rows)
    assert abs(total_ms - 660) < 1e-8
    fps = len(rows) / (total_ms / 1000)
    entries = []
    for row in rows:
        path = DERIVED / 'frames' / row['filename']
        entries.append({'index': int(row['frame']), 'path': path.relative_to(DERIVED).as_posix(),
                        'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                        'source_frame': int(row['source_frame']),
                        'duration_ms': float(row['duration_ms']),
                        'relative_duration': float(row['duration_ms']) * fps / 1000})
    assert len({e['sha256'] for e in entries}) == 47
    text = SOURCE.read_text()
    assert text.count('load_steps=209') == 1
    text = text.replace('load_steps=209', 'load_steps=245', 1)
    text, removed = re.subn(r'^\[ext_resource[^\n]*path="viya_run_e_\d+\.png"[^\n]*\]\n', '', text, flags=re.M)
    assert removed == 11
    text, reused = re.subn(r'path="(viya_[^"]+\.png)"', r'path="../render_cache/\1"', text)
    assert reused == 197
    definitions = '\n'.join(
        f'[ext_resource type="Texture2D" path="{e["path"]}" id="game064_e_{e["index"]:03d}"]'
        for e in entries)
    text = text.replace('[resource]', definitions + '\n\n[resource]', 1)
    pattern = r'"frames": \[(.*?)\],\n"loop": (true|false),\n"name": &"([^"]+)",\n"speed": ([\d.]+)'
    replaced = 0

    def replace_animation(match: re.Match) -> str:
        nonlocal replaced
        if match[3] != 'run_e':
            return match[0]
        replaced += 1
        frames = ',\n'.join(
            '{"duration": %.15f, "texture": ExtResource("game064_e_%03d")}'
            % (e['relative_duration'], e['index']) for e in entries)
        return '"frames": [' + frames + '],\n"loop": true,\n"name": &"run_e",\n"speed": %.15f' % fps

    text = re.sub(pattern, replace_animation, text, flags=re.S)
    assert replaced == 1
    OUTPUT.write_text(text)
    manifest = {
        'schema': 1, 'scope': 'GAME064 E run only; existing 197 frame references unchanged',
        'resource': 'res://' + OUTPUT.relative_to(ROOT).as_posix(),
        'resource_sha256': hashlib.sha256(OUTPUT.read_bytes()).hexdigest(),
        'preserved_resource': 'res://' + SOURCE.relative_to(ROOT).as_posix(),
        'preserved_resource_sha256': hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
        'source_job_id': 'fbf2fd2d-8596-4ca4-87e7-875712a2f7c9',
        'model': 'hf_mult_motion_control', 'canvas': [200, 248], 'pivot': [100, 248],
        'display_size': [69, 85.56], 'nominal_cycle_ms': total_ms,
        'fps': fps, 'frames': entries, 'animation_count': 32, 'active_frame_count': 244,
        'unchanged_frame_count': 197, 'stride_world': 155, 'speed_world_per_second': 235,
        'distance_driven_cycle_ms_at_base_speed': 1000 * 155 / 235,
        'timing_note': 'Relative CSV durations retained. Movement advances phase by distance/155; nominal660ms becomes659.574468ms at235 world/s.',
        'originals_rewritten': False, 'new_generation_during_integration': False,
        'art_approval': 'User requested game integration; final visual approval remains separate.'}
    (DERIVED / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
    return manifest


if __name__ == '__main__':
    result = build()
    print(json.dumps({'frames': len(result['frames']), 'resource': result['resource'],
                      'cycle_ms': result['nominal_cycle_ms']}, ensure_ascii=False))
