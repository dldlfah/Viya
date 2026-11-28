#!/usr/bin/env python3
"""Replay the approved SW17 at its current distance clock; no generated poses."""
import argparse, csv, hashlib, io, json, subprocess, urllib.request
from pathlib import Path
from PIL import Image, ImageDraw

BASE = 'https://raw.githubusercontent.com/dldlfah/Viya/dff3fc802958a75d9770b9ea9e2ad66b1fc558e0/'

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--root', type=Path)
    ap.add_argument('--out', type=Path, required=True)
    a = ap.parse_args(); a.out.mkdir(parents=True, exist_ok=True)
    def read(path):
        return (a.root / path).read_bytes() if a.root else urllib.request.urlopen(BASE + path).read()
    cfg = json.loads(read('data/viya_motion.json'))['directions']['sw']
    rows = cfg['run']; assert len(rows) == 17
    scale, tx, ty = 2.4, 60.0, 80.0
    plates, sources = [], []
    sheet = Image.new('RGB', (1200, 825), (55, 55, 55)); draw = ImageDraw.Draw(sheet)
    for i, row in enumerate(rows):
        path = row['texture'][6:]; raw = read(path); im = Image.open(io.BytesIO(raw)).convert('RGBA')
        assert im.size == (200, 248)
        paint = im.convert('RGBa').transform((600, 800), Image.Transform.AFFINE,
            (1/scale, 0, -tx/scale, 0, 1/scale, -ty/scale), Image.Resampling.BICUBIC).convert('RGBA')
        plate = Image.new('RGB', (600, 800), (0, 255, 0)); plate.paste(paint, (0, 0), paint); plates.append(plate)
        x, y = i % 6 * 200, i // 6 * 275; sheet.paste(im, (x, y+20), im); draw.text((x+3, y+3), str(i), fill='white')
        sources.append({'index': i, 'path': path, 'sha256': hashlib.sha256(raw).hexdigest(), 'duration_ms': row['duration_ms']})
    sheet.save(a.out/'sw17_source_review.jpg', quality=90)
    cmd = ['ffmpeg', '-v', 'error', '-y', '-f', 'rawvideo', '-pixel_format', 'rgb24', '-video_size', '600x800', '-framerate', '60', '-i', '-', '-c:v', 'libx264', '-preset', 'fast', '-crf', '18', '-pix_fmt', 'yuv420p', '-an', '-movflags', '+faststart', str(a.out/'sw17_native_speed_input.mp4')]
    proc = subprocess.Popen(cmd, stdin=subprocess.PIPE); timing = []
    for tick in range(240):
        t = tick/60; phase = (235*t/155) % 1; at = (phase+cfg['phase_origin']) % 1 * 660
        end = 0; index = len(rows)-1
        for i, row in enumerate(rows):
            end += row['duration_ms']
            if at < end: index = i; break
        proc.stdin.write(plates[index].tobytes())
        timing.append({'video_frame': tick, 'time_ms': t*1000, 'global_distance_phase': phase, 'sw17_frame': index})
        if tick == 0: plates[index].save(a.out/'input_first_frame.png')
    proc.stdin.close(); assert proc.wait() == 0
    with (a.out/'input_timing.csv').open('w', newline='') as f:
        w = csv.DictWriter(f, fieldnames=timing[0], lineterminator='\n'); w.writeheader(); w.writerows(timing)
    info = {'source_commit': 'dff3fc802958a75d9770b9ea9e2ad66b1fc558e0', 'source': 'approved active SW17; known repeated-support motif preserved', 'input_canvas': [600,800], 'duration_seconds': 4, 'fps': 60, 'frames': 240, 'audio': False, 'scale': scale, 'translation': [tx,ty], 'root': [100*scale+tx,248*scale+ty], 'distance_cycle_ms': 155/235*1000, 'phase_origin': cfg['phase_origin'], 'sources': sources, 'pose_synthesis': False, 'per_frame_registration': False, 'slow_motion': False, 'video_sha256': hashlib.sha256((a.out/'sw17_native_speed_input.mp4').read_bytes()).hexdigest()}
    (a.out/'input_preparation.json').write_text(json.dumps(info, indent=2)+'\n'); print(json.dumps(info))

if __name__ == '__main__': main()
