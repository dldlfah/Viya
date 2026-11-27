#!/usr/bin/env python3
"""Prepare a measured GAME070 RGB-video cycle; never modifies game resources.

No pose synthesis, temporal interpolation, endpoint insertion or per-frame
registration. A human selects a complete source cycle and supplies landmarks.
"""
from pathlib import Path
import argparse, csv, hashlib, json, subprocess
import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import distance_transform_edt


def matte(image):
    rgb = np.asarray(image.convert('RGB'), dtype=np.float32)
    h, w = rgb.shape[:2]
    border = np.concatenate([rgb[:12].reshape(-1, 3), rgb[-12:].reshape(-1, 3),
                             rgb[:, :12].reshape(-1, 3), rgb[:, -12:].reshape(-1, 3)])
    bg = np.median(border, axis=0)
    # Candidate04 has an inspected uniform olive-green RGB plate. Key the
    # green-minus-red axis, preserving the warm costume and black boot paint.
    dominance = rgb[...,1] - np.maximum(rgb[...,0],rgb[...,2])
    key_dom = float(bg[1]-max(bg[0],bg[2]))
    assert key_dom > 30, 'Requires inspected olive green plate'
    rough = dominance < 8
    interior = distance_transform_edt(rough)
    core = rough & (interior > 3)
    distance, nearest_indices = distance_transform_edt(~core, return_indices=True)
    nearest = rgb[nearest_indices[0], nearest_indices[1]]
    vector = nearest-bg
    alpha = np.clip(np.sum((rgb-bg)*vector,axis=-1) /
                    np.maximum(np.sum(vector*vector,axis=-1),1),0,1)
    alpha[core] = 1
    background = (np.linalg.norm(rgb-bg,axis=-1)<12) | (dominance>key_dom*.6)
    alpha[background] = 0
    alpha[alpha<.07] = 0
    partial = (alpha>0)&(alpha<.999)
    clean = rgb.copy()
    clean[partial] = nearest[partial]
    edge = (alpha>0)&(interior<8)
    clean[...,1][edge] = np.minimum(clean[...,1][edge],
                                   .8*clean[...,0][edge]+.2*clean[...,2][edge])
    clean[alpha==0] = 0
    rgba = np.dstack([np.clip(clean,0,255),alpha*255]).round().astype(np.uint8)
    return Image.fromarray(rgba), {'background_rgb': bg.tolist(), 'green_dominance_cutoff': key_dom*.6,
                                  'opaque_core_pixels': int(core.sum())}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--video', type=Path, required=True)
    p.add_argument('--out', type=Path, required=True)
    p.add_argument('--decoded-dir', type=Path, help='Scratch cache outside a delivered asset folder')
    p.add_argument('--start', type=int, required=True)
    p.add_argument('--end', type=int, required=True, help='exclusive next-cycle boundary')
    p.add_argument('--scale', type=float, required=True)
    p.add_argument('--tx', type=float, required=True)
    p.add_argument('--ty', type=float, required=True)
    p.add_argument('--landmarks', type=Path)
    a = p.parse_args()
    assert a.end > a.start >= 0 and a.scale > 0
    a.out.mkdir(parents=True, exist_ok=True)
    decoded = a.decoded_dir or a.out/'decoded'; decoded.mkdir(parents=True,exist_ok=True)
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', str(a.video),
                    '-fps_mode', 'passthrough', str(decoded/'%04d.png')], check=True)
    probe = json.loads(subprocess.check_output(['ffprobe', '-v', 'error',
                       '-select_streams', 'v:0', '-show_frames', '-show_streams',
                       '-of', 'json', str(a.video)]))
    sources = sorted(decoded.glob('*.png'))
    assert a.end < len(sources), 'Next-cycle endpoint must exist for inspection'
    selected = list(range(a.start, a.end))
    timing = probe['frames']
    duration = float(timing[a.end]['best_effort_timestamp_time']) - float(timing[a.start]['best_effort_timestamp_time'])
    provenance = a.out/'provenance'; provenance.mkdir(exist_ok=True)
    (provenance/'.gdignore').touch()
    frames = a.out/'frames'; frames.mkdir(exist_ok=True)
    rows = []; checks = []; prepared = []; nominal_start = 0.
    landmarks = json.loads(a.landmarks.read_text()) if a.landmarks else {}
    for i, source_index in enumerate(selected):
        rgba, key = matte(Image.open(sources[source_index]))
        s = a.scale
        im = rgba.convert('RGBa').transform((200, 248), Image.Transform.AFFINE,
             (1/s, 0, -a.tx/s, 0, 1/s, -a.ty/s), Image.Resampling.BICUBIC,
             fillcolor=(0,0,0,0)).convert('RGBA')
        arr = np.asarray(im).copy(); arr[arr[...,3] == 0] = 0; im = Image.fromarray(arr)
        filename = f'viya_run_sw_{i:03d}.png'; path = frames/filename; im.save(path)
        native_ms = 1000*(float(timing[source_index+1]['best_effort_timestamp_time']) - float(timing[source_index]['best_effort_timestamp_time']))
        ms = native_ms / duration * .660
        row = dict(frame=i, filename=filename, source_frame=source_index,
                   source_pts_ms=1000*float(timing[source_index]['best_effort_timestamp_time']),
                   source_duration_ms=native_ms, duration_ms=ms,
                   base_speed_duration_ms=ms*(155/235)/.660, start_ms=nominal_start,
                   phase=nominal_start/660)
        nominal_start += ms
        rows.append(row); prepared.append(im)
        border_alpha = np.concatenate([arr[0,:,3], arr[-1,:,3], arr[:,0,3], arr[:,-1,3]])
        checks.append(dict(index=i, source_frame=source_index, filename=filename,
             sha256=hashlib.sha256(path.read_bytes()).hexdigest(), bbox=im.getbbox(),
             border_alpha_max=int(border_alpha.max()), partial_alpha_pixels=int(((arr[...,3]>0)&(arr[...,3]<255)).sum()),
             key=key, landmarks=landmarks.get(str(i))))
    with (provenance/'frame_timing.csv').open('w', newline='') as f:
        writer=csv.DictWriter(f, fieldnames=rows[0], lineterminator="\n"); writer.writeheader(); writer.writerows(rows)
    sheet = Image.new('RGB', (1200, ((len(prepared)+5)//6)*275), (55,55,55))
    draw = ImageDraw.Draw(sheet)
    for i, im in enumerate(prepared):
        x=i%6*200; y=i//6*275; sheet.paste(im,(x,y+22),im); draw.text((x+4,y+4),f'{i} / src {selected[i]}',fill='white')
    sheet.save(provenance/'contact_sheet.png')
    meta = dict(status='PREPARED_NOT_APPROVED', source_sha256=hashlib.sha256(a.video.read_bytes()).hexdigest(),
        source_window=[a.start,a.end], source_cycle_ms=duration*1000, nominal_cycle_ms=nominal_start,
        registration=dict(scale=a.scale, translation=[a.tx,a.ty], canvas=[200,248], pivot=[100,248],
                          fixed_for_entire_clip=True, per_frame_bbox_alignment=False),
        alpha_method='Inspected olive green-minus-max(red,blue) key, opaque-core nearest-paint edge unmix; no pose or temporal synthesis.',
        source_video_stream=probe['streams'][0], frame_checks=checks)
    (provenance/'source_registration.json').write_text(json.dumps(meta, indent=2)+'\n')
    print(json.dumps({'frames':len(checks), 'unique':len({c['sha256'] for c in checks}),
         'nominal_cycle_ms':nominal_start, 'border_alpha_max':max(c['border_alpha_max'] for c in checks)}))


if __name__ == '__main__':
    main()
