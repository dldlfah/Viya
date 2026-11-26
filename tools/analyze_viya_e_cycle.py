#!/usr/bin/env python3
"""Read-only E-run seam measurements and review sheet; never edits game art."""
from pathlib import Path
import hashlib
import json
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]

def main():
    out = ROOT / '.local_validation/GAME064'
    out.mkdir(parents=True, exist_ok=True)
    config = json.loads((ROOT / 'data/viya_motion.json').read_text())
    source = ROOT / 'assets/characters/pilot_32/render_cache'
    arrays = []
    files = []
    sheet = Image.new('RGB', (1200, 660), '#292830')
    text = ImageDraw.Draw(sheet)
    for i in range(11):
        path = source / f'viya_run_e_{i:02d}.png'
        image = Image.open(path).convert('RGBA')
        assert image.size == (200, 248)
        data = np.array(image, dtype=np.float64) / 255
        arrays.append(data)
        mask = data[:, :, 3] > .9
        y, x = np.where(mask)
        floor = mask[max(0, int(y.max()) - 7):int(y.max()) + 1]
        fy, fx = np.where(floor)
        files.append({'index': i, 'path': path.relative_to(ROOT).as_posix(),
                      'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                      'opaque_bbox': [int(x.min()), int(y.min()), int(x.max()+1), int(y.max()+1)],
                      'lower_opaque_centroid_x': float(fx.mean()),
                      'muzzle': config['directions']['e']['run'][i]['muzzle']})
        px, py = i % 6 * 200, i // 6 * 330
        sheet.paste(image, (px, py + 35), image)
        text.text((px+10, py+8), f'run_e_{i:02d}', fill='white')
        text.line((px, py+283, px+199, py+283), fill='#a88957')
    rows = []
    for i, a in enumerate(arrays):
        j = (i + 1) % len(arrays)
        b = arrays[j]
        ma, mb = a[:, :, 3] > .5, b[:, :, 3] > .5
        pa, pb = a[:, :, :3] * a[:, :, 3:], b[:, :, :3] * b[:, :, 3:]
        union = ma | mb
        rows.append({'from': i, 'to': j,
                     'silhouette_iou': float((ma & mb).sum() / union.sum()),
                     'lower_silhouette_iou': float((ma[145:] & mb[145:]).sum() / union[145:].sum()),
                     'premult_rgb_mae_255': float(np.abs(pa - pb)[union].mean()*255),
                     'muzzle_delta_display_px': float(np.linalg.norm(np.array(files[i]['muzzle'])-np.array(files[j]['muzzle']))*.345),
                     'lower_opaque_centroid_delta_display_px': abs(files[i]['lower_opaque_centroid_x']-files[j]['lower_opaque_centroid_x'])*.345})
    result = {'status': 'BASELINE_ANALYZED_NOT_CORRECTED', 'files': files, 'transitions': rows,
              'display_size': [69, 85.56], 'canvas': [200, 248], 'source_frame_ms': 60,
              'native_cycle_ms': 660, 'distance_cycle_ms_at_235': config['stride_world']/235*1000,
              'interpretation': 'Pixel/silhouette and lower opaque-band metrics identify change, not anatomical foot identity or artistic acceptance. This tool makes a review sheet only; it does not change/crop/reorder/warp game art.'}
    sheet.save(out/'E_CYCLE_BASELINE.png')
    (out/'cycle_metrics.json').write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps({'status': result['status'], 'wrap': rows[-1],
                      'lower_iou_all': [round(r['lower_silhouette_iou'], 3) for r in rows]}))

if __name__ == '__main__':
    main()
