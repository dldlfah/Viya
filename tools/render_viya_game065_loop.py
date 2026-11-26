#!/usr/bin/env python3
"""Render a read-only sprite-loop review from an asset's own timing CSV.

The MP4 uses constant-rate sample-and-hold; source images are never blended
across time. Spatial display scaling does not modify the source PNG files.
Requires Pillow and ffmpeg/ffprobe. This is not a game execution capture.
"""
from pathlib import Path
import argparse
import bisect
import csv
import hashlib
import json
import math
import subprocess

from PIL import Image, ImageDraw, ImageFont


REPO = Path(__file__).resolve().parents[1]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--asset-root', type=Path,
                        default=REPO/'assets/characters/pilot_32/game065_e_run_fire')
    parser.add_argument('--output', type=Path,
                        default=REPO/'docs/validation/GAME065_LOOP.mp4')
    parser.add_argument('--cycles', type=int, default=5)
    parser.add_argument('--fps', type=int, default=240,
                        help='240 retains every frame, including holds below 8.33 ms.')
    parser.add_argument('--display-scale', type=float, default=.345)
    parser.add_argument('--zoom', type=float, default=3.)
    args = parser.parse_args()
    if args.cycles <= 0 or args.fps <= 0 or args.zoom <= 0:
        parser.error('cycles, fps and zoom must be positive')

    timing_path = args.asset_root/'provenance/frame_timing.csv'
    timing_hash = digest(timing_path)
    with timing_path.open(newline='') as handle:
        rows = list(csv.DictReader(handle))
    if not rows:
        parser.error('timing CSV is empty')
    assert [int(row['frame']) for row in rows] == list(range(len(rows)))
    starts = [0.]
    durations = [float(row['duration_ms']) for row in rows]
    for row, duration in zip(rows, durations):
        assert duration > 0
        assert abs(float(row['start_ms'])-starts[-1]) < 1e-7
        starts.append(starts[-1]+duration)
    cycle_ms = starts[-1]
    duration_seconds = args.cycles*cycle_ms/1000.
    frames_float = duration_seconds*args.fps
    frame_count = round(frames_float)
    if abs(frame_count-frames_float) > 1e-7:
        parser.error('fps and cycles must represent the total duration exactly')
    if 1000./args.fps > min(durations):
        parser.error('fps is too low to guarantee every distinct frame in each cycle')

    paths = [args.asset_root/'frames'/row['filename'] for row in rows]
    before_hashes = [digest(path) for path in paths]
    images = [Image.open(path).copy() for path in paths]
    size = images[0].size
    assert all(im.mode == 'RGBA' and im.size == size for im in images)
    scale = args.display_scale*args.zoom
    sprite_width, sprite_height = size[0]*scale, size[1]*scale
    width = int(math.ceil(max(600, sprite_width+140)/2)*2)
    height = int(math.ceil(max(440, sprite_height+160)/2)*2)
    x = (width-sprite_width)/2
    y = 90.
    font_path = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
    try:
        font = ImageFont.truetype(font_path, 17)
        small = ImageFont.truetype(font_path, 13)
    except OSError:
        font = small = ImageFont.load_default()
    layers = []
    for im in images:
        layer = im.convert('RGBa').transform(
            (width,height), Image.Transform.AFFINE,
            (1/scale,0,-x/scale,0,1/scale,-y/scale),
            Image.Resampling.BICUBIC, fillcolor=(0,0,0,0),
        ).convert('RGBA')
        layers.append(layer)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    command = [
        'ffmpeg','-y','-v','error','-f','rawvideo','-pix_fmt','rgb24',
        '-s',f'{width}x{height}','-framerate',str(args.fps),'-i','-',
        '-an','-c:v','libx264','-preset','fast','-crf','18',
        '-pix_fmt','yuv420p','-movflags','+faststart',str(args.output),
    ]
    sampled_order = [[] for _ in range(args.cycles)]
    process = subprocess.Popen(command, stdin=subprocess.PIPE)
    try:
        for sample in range(frame_count):
            time_ms = sample*1000./args.fps
            cycle = min(args.cycles-1, int((time_ms+1e-9)/cycle_ms))
            phase_ms = max(0.,time_ms-cycle*cycle_ms)
            index = min(len(rows)-1, bisect.bisect_right(starts,phase_ms+1e-9)-1)
            if not sampled_order[cycle] or sampled_order[cycle][-1] != index:
                sampled_order[cycle].append(index)
            canvas = Image.new('RGB',(width,height),(128,128,128))
            canvas.paste(layers[index],(0,0),layers[index])
            draw = ImageDraw.Draw(canvas)
            draw.text((24,20),'VIYA / EAST MOVING AIM / LOOP REVIEW',font=font,fill=(24,24,24))
            draw.text((24,49),f'{len(rows)} distinct RGBA frames | {cycle_ms:.0f} ms | {args.zoom:g}x game display',font=small,fill=(35,35,35))
            draw.text((24,height-66),f'Cycle {cycle+1}/{args.cycles} | frame {index:02d}/{len(rows)-1:02d} | source {int(rows[index]["source_frame"]):02d}',font=small,fill=(30,30,30))
            draw.text((24,height-45),f'{args.fps} fps sample-and-hold | no temporal frame blending | {duration_seconds:.2f} s',font=small,fill=(30,30,30))
            draw.text((24,height-24),'Fixed canvas; neutral review background. NOT A GAME CAPTURE.',font=small,fill=(35,35,35))
            process.stdin.write(canvas.tobytes())
    finally:
        process.stdin.close()
    assert process.wait() == 0
    assert all(order == list(range(len(rows))) for order in sampled_order)
    assert before_hashes == [digest(path) for path in paths]
    assert timing_hash == digest(timing_path)
    probe = json.loads(subprocess.run([
        'ffprobe','-v','error','-show_entries',
        'format=duration,size:stream=width,height,avg_frame_rate,nb_frames',
        '-of','json',str(args.output),
    ],check=True,capture_output=True,text=True).stdout)
    stream = probe['streams'][0]
    assert int(stream['nb_frames']) == frame_count
    assert stream['avg_frame_rate'] == f'{args.fps}/1'
    assert abs(float(probe['format']['duration'])-duration_seconds) < 1e-6
    print(json.dumps({
        'output':str(args.output), 'source_asset':str(args.asset_root),
        'timing_csv_sha256':timing_hash, 'sprite_pngs_unchanged':True,
        'timing_csv_unchanged':True, 'cycles':args.cycles,
        'cycle_ms':cycle_ms, 'duration_seconds':duration_seconds,
        'fps':args.fps, 'encoded_frames':frame_count,
        'all_distinct_frames_in_order_each_cycle':True,
        'canvas':list(size), 'display_size':[sprite_width,sprite_height],
        'fixed_image_origin':[x,y], 'temporal_blending':False,
        'sampling':'Constant-rate sample-and-hold from exact CSV cumulative times',
        'max_transition_quantization_ms_exclusive':1000./args.fps,
        'game_execution':False, 'ffprobe':probe,
    },indent=2))


if __name__ == '__main__':
    main()
