#!/usr/bin/env python3
"""Replace only run_sw with the delivered17 native frames; never edit artwork."""
from pathlib import Path
import csv
import hashlib
import json
import math
import os
import re
from PIL import Image
from build_viya_game065 import ANIMATION, EXT_RESOURCE

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'assets/characters/pilot_32/game069_s_run_fire/viya_game069_frames.tres'
DEST = ROOT / 'assets/characters/pilot_32/game070_sw_run'
RESOURCE = 'res://assets/characters/pilot_32/game070_sw_run/viya_game070_frames.tres'


def build():
    meta = json.loads((DEST / 'provenance/clip_metadata.json').read_text())
    manifest = json.loads((DEST / 'manifest.json').read_text())
    timing = list(csv.DictReader((DEST / 'provenance/frame_timing.csv').open(newline='')))
    frames = meta['frames']
    assert len(frames) == len(timing) == len(manifest['frame_checks']) == 17
    assert meta['canvas'] == [200, 248] and meta['pivot'] == [100, 248] and meta['display'] == [69, 85.56]
    assert math.isfinite(meta['phase_origin']) and 0 <= meta['phase_origin'] < 1
    elapsed = 0.0
    for i, (row, t, h) in enumerate(zip(frames, timing, manifest['frame_checks'])):
        f = DEST / 'frames' / t['filename']
        assert row['index'] == int(t['frame']) == i and int(t['source_frame']) == 34+i
        assert row['texture'] == 'res://' + f.relative_to(ROOT).as_posix()
        assert row['region'] == [0, 0, 200, 248] and h['filename'] == f.name
        assert hashlib.sha256(f.read_bytes()).hexdigest() == h['sha256']
        assert len(row['muzzle']) == 2 and all(math.isfinite(v) and 0 <= v <= limit for v, limit in zip(row['muzzle'], [200, 248]))
        ms = float(t['duration_ms'])
        assert math.isfinite(ms) and ms > 0 and abs(float(t['start_ms'])-elapsed) < 1e-6
        assert abs(row['duration_ms']-ms) < 1e-6
        elapsed += ms
        image = Image.open(f)
        assert image.mode == 'RGBA' and image.size == (200, 248)
        assert all(image.getpixel(p)[3] == 0 for p in [(0, 0), (199, 0), (0, 247), (199, 247)])
    assert abs(elapsed-660) < 1e-6
    # Exact binary weights preserve the PTS ratios in Godot's float32 storage.
    ticks = [round(float(t['source_duration_ms'])*1000) for t in timing]
    assert all(t > 0 for t in ticks)
    speed = sum(ticks)/65536/(elapsed/1000)
    assert all(abs(t/sum(ticks)*elapsed-float(row['duration_ms'])) < 1e-8 for t, row in zip(ticks, timing))
    source = SOURCE.read_text()
    old = {m['name']: m[0] for m in ANIMATION.finditer(source)}
    assert len(old) == 35 and sum(v.count('ExtResource(') for v in old.values()) == 342
    removed = re.findall(r'ExtResource\("([^"]+)"\)', old['run_sw'])
    assert len(removed) == 11 and all(not any('ExtResource("'+key+'")' in block for name, block in old.items() if name != 'run_sw') for key in removed)

    def relocate(match):
        if match['id'] in removed:
            return ''
        path = os.path.relpath((SOURCE.parent / match['path']).resolve(), DEST).replace(os.sep, '/')
        assert (DEST / path).resolve().is_file()
        return match[0].replace('path="'+match['path']+'"', 'path="'+path+'"', 1)

    text = EXT_RESOURCE.sub(relocate, source)
    declarations = '\n'.join(f'[ext_resource type="Texture2D" path="frames/{t["filename"]}" id="game070_sw_{i:03d}"]' for i, t in enumerate(timing))
    text = text.replace('[resource]', declarations+'\n\n[resource]', 1)
    entries = ',\n'.join('{"duration": '+format(ticks[i]/65536, '.17g')+', "texture": ExtResource("game070_sw_'+f'{i:03d}'+'")}' for i in range(len(ticks)))
    replacement = '{\n"frames": ['+entries+'],\n"loop": true,\n"name": &"run_sw",\n"speed": '+format(speed, '.17g')+'\n}'
    text = ANIMATION.sub(lambda m: replacement if m['name'] == 'run_sw' else m[0], text)
    text = re.sub(r'load_steps=\d+', 'load_steps=349', text, count=1)
    current = {m['name']: m[0] for m in ANIMATION.finditer(text)}
    assert len(current) == 35 and all(current[k] == v for k, v in old.items() if k != 'run_sw')
    assert sum(v.count('ExtResource(') for v in current.values()) == 348
    assert len(EXT_RESOURCE.findall(text)) == 348
    template = (SOURCE.parent / 'frames/viya_run_fire_s_000.png.import').read_text()
    for t in timing:
        f = DEST / 'frames' / t['filename']
        path = 'res://' + f.relative_to(ROOT).as_posix()
        cache = 'res://.godot/imported/'+f.name+'-'+hashlib.md5(path.encode()).hexdigest()+'.ctex'
        ini = re.sub(r'^uid=.*\n', '', template, flags=re.M)
        ini = re.sub(r'res://\.godot/imported/[^"\n]+', cache, ini)
        ini = re.sub(r'source_file="[^"]+"', 'source_file="'+path+'"', ini)
        ini = ini.replace('process/fix_alpha_border=true', 'process/fix_alpha_border=false')
        if not f.with_suffix('.png.import').exists():
            f.with_suffix('.png.import').write_text(ini)
    (DEST / 'provenance/.gdignore').touch()
    (DEST / 'viya_game070_frames.tres').write_text(text)
    path = ROOT / 'data/viya_motion.json'
    motion = json.loads(path.read_text())
    motion['resource'] = RESOURCE
    motion['directions']['sw']['run'] = frames
    motion['directions']['sw']['phase_origin'] = meta['phase_origin']
    path.write_text(json.dumps(motion, ensure_ascii=False, indent=2)+'\n')
    path = ROOT / 'data/presentation_slots.json'
    slots = json.loads(path.read_text())
    slots['viya_battle'] = RESOURCE
    path.write_text(json.dumps(slots, ensure_ascii=False, indent=2)+'\n')
    record = {'source_resource': 'res://'+SOURCE.relative_to(ROOT).as_posix(), 'source_sha256': hashlib.sha256(SOURCE.read_bytes()).hexdigest(), 'resource': RESOURCE, 'replaced_clip': 'run_sw', 'old_frames': 11, 'new_frames': 17, 'preserved_clips': 34, 'preserved_frames': 331, 'total_clips': 35, 'total_frames': 348, 'nominal_cycle_ms': elapsed, 'phase_origin': meta['phase_origin'], 'status': 'BUILT_NOT_RUNTIME_PROOF'}
    (DEST / 'integration_manifest.json').write_text(json.dumps(record, indent=2)+'\n')
    print(json.dumps(record))


if __name__ == '__main__':
    build()
