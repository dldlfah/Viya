#!/usr/bin/env python3
"""Measure delivered GAME067 pixels and compare SE boot phase; no game writes.

Phase matching is a 2D painted-boot comparison, not physical ground contact.
Muzzle extraction is valid only after visual confirmation that the rightmost
solid foreground in the stated upper-right region is the original barrel tip.
"""
from pathlib import Path
import argparse, csv, hashlib, json
import numpy as np
from PIL import Image, ImageDraw


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--delivery',type=Path,required=True)
    a=p.parse_args()
    root=Path(__file__).resolve().parents[2]
    folder=a.delivery; prov=folder/'provenance'
    meta=json.loads((prov/'source_registration.json').read_text())
    files=sorted((folder/'frames').glob('*.png'))
    images=[Image.open(f).convert('RGBA') for f in files]
    arrays=np.array([np.asarray(im) for im in images])
    n=len(files)
    assert n==len(meta['frame_checks']) and n>2
    assert len({hashlib.sha256(f.read_bytes()).hexdigest() for f in files})==n
    assert all(im.size==(200,248) for im in images)
    assert not any(np.max(np.concatenate([im[0,:,3],im[-1,:,3],im[:,0,3],im[:,-1,3]])) for im in arrays)
    timing=list(csv.DictReader((prov/'frame_timing.csv').open()))
    assert len(timing)==n and all(float(r['duration_ms'])>0 for r in timing)
    assert abs(sum(float(r['duration_ms']) for r in timing)-660)<1e-6
    assert abs(sum(float(r['base_speed_duration_ms']) for r in timing)-155/235*1000)<1e-6
    muzzle=[]
    for i,arr in enumerate(arrays):
        # Independently measured from the new registered paint, not old E/SE data.
        region=arr[40:120,155:199,3]>=192
        yy,xx=np.where(region)
        assert len(xx)>0
        xmax=int(xx.max()); rows=yy[xx==xmax]
        point=[155+xmax+.5,40+float(np.mean(rows))+.5]
        assert 155<point[0]<199 and 40<point[1]<120
        muzzle.append(point)
        meta['frame_checks'][i]['muzzle']=point
    with (prov/'muzzle_coordinates.csv').open('w',newline='') as f:
        w=csv.writer(f);w.writerow(['frame','filename','x','y','measurement'])
        for i,point in enumerate(muzzle):w.writerow([i,files[i].name,*point,'rightmost_opaque_barrel_tip_in_inspected_ROI'])
    basefiles=sorted((root/'assets/characters/pilot_32/game066_se_run/frames').glob('*.png'))
    base=np.array([np.asarray(Image.open(f).convert('RGBA')) for f in basefiles])
    assert len(base)==18
    # Fixed crop isolates lower boots from intentionally changed rifle/arms.
    aa=arrays[:,155:248,70:150].astype(np.float32)
    bb=base[:,155:248,70:150].astype(np.float32)
    errors=np.array([[np.abs(x-y).mean() for y in bb] for x in aa])
    phases=np.array([float(r['phase']) for r in timing])
    grid=np.arange(720)/720
    scores=np.array([np.mean(errors[np.arange(n),np.floor(((phases+delta)%1)*18).astype(int)]) for delta in grid])
    ties=np.where(np.isclose(scores,scores.min(),atol=1e-6))[0]
    delta=float(grid[ties[len(ties)//2]])
    baseline_origin=float(json.loads((root/'data/viya_motion.json').read_text())['directions']['se']['phase_origin'])
    origin=(baseline_origin-delta)%1
    mapped=np.floor(((phases+delta)%1)*18).astype(int)
    alignment=dict(method='Minimum mean absolute registered RGBA difference in boots crop [70,155,150,248],720 circular offsets; visually inspect anchors.',
       baseline_origin=baseline_origin, measured_baseline_phase_at_new_clip_start=delta,
       recommended_run_fire_phase_origin=origin,
       formula='local_run=global+baseline_origin;local_fire=global+fire_origin;fire_origin=baseline_origin-measured_delta(mod1)',
       mean_boot_crop_error=float(scores.min()), tied_offset_grid_indices=ties.tolist(),
       mapped_reference_indices=mapped.tolist(), nearest_reference_indices=errors.argmin(axis=1).tolist(),
       limitation='2D visual correspondence and numerical phase recommendation; not a skeleton/3D ground solution or zero-slip guarantee.')
    (prov/'phase_alignment.json').write_text(json.dumps(alignment,indent=2)+'\n')
    frames=[dict(index=i,texture='res://'+str((folder/'frames'/files[i].name).resolve().relative_to(root)),
                 region=[0,0,200,248],muzzle=muzzle[i],duration_ms=float(timing[i]['duration_ms'])) for i in range(n)]
    clip=dict(direction='se',animation='run_fire_se',optional=True,canvas=[200,248],pivot=[100,248],display=[69,85.56],
       nominal_cycle_ms=660,distance_cycle_ms=155/235*1000,stride_world=155,base_speed=235,
       run_fire_phase_origin=origin,frames=frames,
       fallback='Existing run_se at the same global distance phase if clip or any metadata is missing/invalid.',
       state='ART_DELIVERY_ONLY_NOT_ACTIVE_GAME_RESOURCE')
    (prov/'clip_metadata.json').write_text(json.dumps(clip,indent=2)+'\n')
    meta['status']='MEASURED_AWAITING_VISUAL_REVIEW'
    (prov/'source_registration.json').write_text(json.dumps(meta,indent=2)+'\n')
    cols=6;tile_h=275;sheet=Image.new('RGB',(1200,((n+5)//6)*tile_h),(48,48,48));d=ImageDraw.Draw(sheet)
    for i,im in enumerate(images):
        x=i%6*200;y=i//6*tile_h;sheet.paste(im,(x,y+22),im);mx,my=muzzle[i]
        d.line((x+mx-4,y+22+my,x+mx+4,y+22+my),fill=(0,255,255))
        d.line((x+mx,y+18+my,x+mx,y+26+my),fill=(0,255,255))
        d.text((x+3,y+3),f'{i} src{timing[i]["source_frame"]}',fill='white')
    sheet.save(prov/'muzzle_review.png')
    anchors=sorted(set([0,n//4,n//2,3*n//4,n-1]))
    compare=Image.new('RGB',(400*len(anchors),275),(50,50,50));d=ImageDraw.Draw(compare)
    for k,i in enumerate(anchors):
        x=400*k;bi=int(mapped[i]);bm=Image.fromarray(base[bi])
        compare.paste(bm,(x,22),bm);compare.paste(images[i],(x+200,22),images[i])
        d.text((x+3,3),f'SE run {bi} | new {i}',fill='white')
    compare.save(prov/'phase_comparison.png')
    delta_adj=[float(np.abs(x-y).mean()) for x,y in zip(aa, np.roll(aa,-1,axis=0))]
    qa=dict(bitmap_status='PASS',frames=n,unique_pixel_hashes=n,border_alpha_max=0,
       nominal_cycle_ms=sum(float(r['duration_ms']) for r in timing),base_speed_cycle_ms=sum(float(r['base_speed_duration_ms']) for r in timing),
       muzzle_count=len(muzzle),muzzle_ROI=[155,40,199,120],boot_adjacent_cyclic_MAE=delta_adj,
       seam_boot_MAE=delta_adj[-1],internal_boot_MAE_median=float(np.median(delta_adj[:-1])),
       recommended_phase_origin=origin,visual_review='REQUIRED_SEPARATELY',
       engine_integration='NOT_RUN',final_producer_approval='NOT_VERIFIED',windows_mobile_FPS='NOT_VERIFIED')
    (prov/'technical_qa.json').write_text(json.dumps(qa,indent=2)+'\n')
    print(json.dumps(qa))


if __name__=='__main__':main()
