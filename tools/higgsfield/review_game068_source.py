#!/usr/bin/env python3
"""Decode every native GAME068 source frame for visual inspection; no pose edits."""
from pathlib import Path
import argparse, hashlib, json, subprocess
from PIL import Image, ImageDraw


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--video', type=Path, required=True)
    p.add_argument('--decoded', type=Path, required=True)
    p.add_argument('--review', type=Path, required=True)
    a = p.parse_args()
    a.decoded.mkdir(parents=True, exist_ok=True)
    a.review.mkdir(parents=True, exist_ok=True)
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', str(a.video),
                    '-fps_mode', 'passthrough', str(a.decoded/'%04d.png')], check=True)
    probe = json.loads(subprocess.check_output(['ffprobe', '-v', 'error',
        '-show_streams', '-show_frames', '-of', 'json', str(a.video)]))
    frames = [f for f in probe['frames'] if f['media_type'] == 'video']
    files = sorted(a.decoded.glob('*.png'))
    assert len(files) == len(frames)
    for start in range(0, len(files), 25):
        sheet = Image.new('RGB', (1000, 5*270), (45, 45, 45))
        d = ImageDraw.Draw(sheet)
        for k, file in enumerate(files[start:start+25]):
            pic = Image.open(file).convert('RGB').resize((200, 248), Image.Resampling.LANCZOS)
            x, y = (k % 5)*200, (k//5)*270
            sheet.paste(pic, (x, y+22))
            d.text((x+4, y+4), f'src {start+k} / {frames[start+k]["best_effort_timestamp_time"]}s', fill='white')
        sheet.save(a.review/f'all_source_{start:03d}.jpg', quality=94)
    record = {'source_sha256': hashlib.sha256(a.video.read_bytes()).hexdigest(),
              'streams': probe['streams'], 'frame_count': len(frames),
              'source_index_is_zero_based': True,
              'decoded_filename_is_one_based': True,
              'timestamps_ms': [1000*float(f['best_effort_timestamp_time']) for f in frames],
              'scope': 'All source frames decoded; visual adoption requires direct inspection.'}
    (a.review/'source_probe.json').write_text(json.dumps(record, indent=2)+'\n')
    print(json.dumps({'frames': len(files), 'streams': len(probe['streams']), 'sha256': record['source_sha256']}))


if __name__ == '__main__':
    main()
