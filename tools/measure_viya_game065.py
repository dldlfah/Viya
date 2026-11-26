#!/usr/bin/env python3
"""Measure the inspected GAME065 barrel tips and write its verified phase table.

The same-source-phase correspondence must already have been visually reviewed.
This does not infer gait equivalence or generate/edit any image pixels.
"""
from pathlib import Path
import argparse,csv,hashlib,json
import numpy as np
from PIL import Image,ImageDraw

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--prepared',type=Path,required=True)
    p.add_argument('--reference-timing',type=Path,required=True)
    p.add_argument('--out',type=Path,required=True)
    a=p.parse_args()
    prep=json.loads((a.prepared/'frame_preparation.json').read_text())
    mapping=prep['source_sampling']
    if not mapping.get('visually_verified'):raise ValueError('Gait correspondence has not been reviewed')
    rows=list(csv.DictReader(a.reference_timing.open()))
    sources=[int(r['source_frame']) for r in rows]
    if sources!=mapping['source_frames']:raise ValueError('Reviewed phase correspondence does not match reference timing')
    total=sum(float(r['duration_ms']) for r in rows)
    a.out.mkdir(parents=True,exist_ok=True)
    columns=['frame','filename','source_frame','source_time_ms','start_ms','duration_ms','normalized_phase','reference_source_frame','classification']
    with (a.out/'frame_timing.csv').open('w',newline='') as stream:
        writer=csv.DictWriter(stream,fieldnames=columns,lineterminator='\n');writer.writeheader()
        for r in rows:
            record={key:r[key] for key in ['frame','source_frame','source_time_ms','start_ms','duration_ms','classification']}
            record.update(filename=f"viya_run_fire_e_{int(r['frame']):03d}.png",normalized_phase=format(float(r['start_ms'])/total,'.16g'),reference_source_frame=r['source_frame'])
            writer.writerow(record)
    s=prep['registration']['scale'];tx,ty=prep['registration']['translation']
    landmarks=[];sheet=Image.new('RGB',(6*220,((len(rows)+5)//6)*150),(25,30,40));draw=ImageDraw.Draw(sheet)
    for i,r in enumerate(rows):
        src=int(r['source_frame'])
        image=Image.open(a.prepared/'rgba_native'/f'frame_{src:03d}.png').convert('RGBA')
        rgba=np.asarray(image);yy,xx=np.indices(rgba.shape[:2]);mask=(rgba[:,:,3]>180)&(xx>=640)&(yy>=320)&(yy<500)
        ys,xs=np.where(mask)
        if not xs.size:raise ValueError(f'No measured muzzle material in source{src}')
        right=int(xs.max());tip=mask&(xx>=right-2)&(xx<=right)
        cx=right+.5;cy=float(np.average(yy[tip]+.5,weights=rgba[:,:,3][tip]))
        landmarks.append({'index':i,'source_frame':src,'native_muzzle':[cx,cy],'muzzle':[round(cx*s+tx,4),round(cy*s+ty,4)]})
        crop=image.crop((610,320,720,450));bg=Image.new('RGBA',crop.size,(31,37,47,255));bg.alpha_composite(crop)
        crop=bg.convert('RGB').resize((220,130),Image.Resampling.BICUBIC);d=ImageDraw.Draw(crop);px=(cx-610)*2;py=cy-320
        d.line((px-5,py,px+5,py),fill=(80,255,210),width=1);d.line((px,py-5,px,py+5),fill=(80,255,210),width=1)
        x=i%6*220;y=i//6*150;sheet.paste(crop,(x,y+20));draw.text((x+4,y+2),f'{i:02d} / source{src:02d}',fill='white')
    record={'status':'MEASURED_REQUIRES_VISUAL_REVIEW','method':'Rightmost opaque metal core(alpha>180) in the inspected native muzzle ROI, with alpha-weighted center over its last3columns. No old run muzzle coordinates are reused.','registration':prep['registration'],'reference_timing_sha256':hashlib.sha256(a.reference_timing.read_bytes()).hexdigest(),'frames':landmarks}
    (a.out/'muzzle_landmarks.json').write_text(json.dumps(record,indent=2)+'\n')
    sheet.save(a.out/'muzzle_landmarks.jpg',quality=95)
    print(json.dumps({'frames':len(rows),'cycle_ms':total,'muzzle_x':[min(r['muzzle'][0] for r in landmarks),max(r['muzzle'][0] for r in landmarks)],'muzzle_y':[min(r['muzzle'][1] for r in landmarks),max(r['muzzle'][1] for r in landmarks)]}))

if __name__=='__main__':main()
