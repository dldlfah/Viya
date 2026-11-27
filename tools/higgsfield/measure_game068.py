#!/usr/bin/env python3
"""Measure GAME068 S paint and landmark phase; does not modify game data."""
from pathlib import Path
import argparse, csv, hashlib, json
import numpy as np
from PIL import Image, ImageDraw


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--delivery',type=Path,required=True)
    a=p.parse_args();root=Path(__file__).resolve().parents[2]
    folder=a.delivery;prov=folder/'provenance'
    meta=json.loads((prov/'source_registration.json').read_text())
    files=sorted((folder/'frames').glob('*.png'))
    images=[Image.open(f).convert('RGBA') for f in files]
    arrays=np.array([np.asarray(im) for im in images])
    timing=list(csv.DictReader((prov/'frame_timing.csv').open()))
    n=len(files);assert n==17==len(timing)==len(meta['frame_checks'])
    assert all(im.size==(200,248) for im in images)
    assert all(float(t['duration_ms'])>0 for t in timing)
    assert abs(sum(float(t['duration_ms']) for t in timing)-660)<1e-6
    assert abs(sum(float(t['base_speed_duration_ms']) for t in timing)-155/235*1000)<1e-6
    assert len({hashlib.sha256(im.tobytes()).hexdigest() for im in images})==n
    assert not any(np.max(np.concatenate([im[0,:,3],im[-1,:,3],im[:,0,3],im[:,-1,3]])) for im in arrays)
    # The full17frame sheet was inspected first: the rightmost opaque paint in
    # this restricted region is the down-right barrel tip, never cloth/hair.
    muzzles=[];feet=[]
    for i,arr in enumerate(arrays):
        yy,xx=np.where(arr[125:165,135:170,3]>=192);assert len(xx)
        right=int(xx.max());my=125+float(yy[xx==right].mean())+.5;point=[135+right+.5,my]
        muzzles.append(point);meta['frame_checks'][i]['muzzle']=point
        pair=[]
        # Independently sampled boot tips, screen-left/right in the frontal S
        # camera. These 2D points are NOT measured world-space floor contacts.
        for x0,x1 in [(75,103),(109,132)]:
            fy,fx=np.where(arr[175:247,x0:x1,3]>=192)
            ids=fy>=np.quantile(fy,.98)
            pair.append([float(fx[ids].mean()+x0),float(fy[ids].mean()+175)])
        feet.append(pair)
    with (prov/'muzzle_coordinates.csv').open('w',newline='') as f:
        w=csv.writer(f,lineterminator="\n");w.writerow(['frame','filename','x','y','measurement'])
        for i,xy in enumerate(muzzles):w.writerow([i,files[i].name,*xy,'rightmost_opaque_barrel_tip_in_visually_inspected_ROI_135_125_170_165'])
    with (prov/'foot_landmarks.csv').open('w',newline='') as f:
        w=csv.writer(f,lineterminator="\n");w.writerow(['frame','source_frame','screen_left_tip_x','screen_left_tip_y','screen_right_tip_x','screen_right_tip_y','state'])
        for i,pair in enumerate(feet):
            state='left_support_right_recovery' if i<=5 else ('left_toe_off_right_advances' if i<=8 else ('right_support_left_recovery' if i<=13 else 'right_toe_off_left_advances'))
            w.writerow([i,timing[i]['source_frame'],*pair[0],*pair[1],state])
    old_origin=float(json.loads((root/'data/viya_motion.json').read_text())['directions']['s']['phase_origin'])
    # Direct visual stance anchors: legacy S00 has screen-left boot extended
    # and right knee folded; S05 reverses them. New3/source37 and11/source45
    # are the corresponding deep-support extrema. Fit their circular offset.
    anchors=[{'new_frame':3,'new_source_frame':37,'old_s_frame':0,'stance':'screen_left_support_right_recovery'},
             {'new_frame':11,'new_source_frame':45,'old_s_frame':5,'stance':'screen_right_support_left_recovery'}]
    candidates=[]
    for anchor in anchors:
        new_phase=float(timing[anchor['new_frame']]['phase']);old_phase=anchor['old_s_frame']/11
        candidate=(new_phase-old_phase+old_origin)%1;candidates.append(candidate)
        anchor.update(new_local_phase=new_phase,old_local_phase=old_phase,recommended_origin_from_anchor=candidate,boot_tips=feet[anchor['new_frame']])
    origin=float(np.angle(np.mean(np.exp(2j*np.pi*np.array(candidates))))/(2*np.pi)%1)
    alignment={'method':'Two visually confirmed opposite boot-support/recovery stance anchors; circular least-squares phase offset from legacy S00/S05. New per-frame boot-tip coordinates are measured independently.',
        'baseline_origin':old_origin,'recommended_phase_origin':origin,'anchors':anchors,
        'formula':'new_local=global+new_origin;old_local=global+old_origin;origin=new_local-old_local+old_origin(mod1)',
        'maximum_anchor_residual_cycles':float(max(abs((x-origin+.5)%1-.5) for x in candidates)),
        'anatomical_note':'screen-left/right are frontal-camera landmark labels. No 3D skeleton or floor was reconstructed.',
        'se_comparison':'Use existing SE18 origin and render both at common global distance phase. Its painted foot locations and legacy phase are not a physical-contact ground truth.',
        'limitation':'2D stance correspondence only; different foot extents and camera projection remain. Actual main.tscn transitions and zero-slip/final art approval are not verified.'}
    (prov/'phase_alignment.json').write_text(json.dumps(alignment,indent=2)+'\n')
    frame_rows=[{'index':i,'texture':'res://'+str((folder/'frames'/f.name).resolve().relative_to(root)),
        'region':[0,0,200,248],'muzzle':muzzles[i],'duration_ms':float(timing[i]['duration_ms'])} for i,f in enumerate(files)]
    clip={'direction':'s','animation':'run_s','canvas':[200,248],'pivot':[100,248],'display':[69,85.56],
        'nominal_cycle_ms':660,'distance_cycle_ms':155/235*1000,'stride_world':155,'base_speed':235,
        'phase_origin':origin,'frames':frame_rows,'replace_only':'Existing run_s11; preserve other33clips/307frames.',
        'state':'ART_DELIVERY_ONLY_NOT_ACTIVE_GAME_RESOURCE'}
    (prov/'clip_metadata.json').write_text(json.dumps(clip,indent=2)+'\n')
    sheet=Image.new('RGB',(1200,3*275),(55,55,55));d=ImageDraw.Draw(sheet)
    for i,pic in enumerate(images):
        x=i%6*200;y=i//6*275;sheet.paste(pic,(x,y+22),pic);d.text((x+3,y+3),f'{i} src{timing[i]["source_frame"]}',fill='white')
        for point,color in [(muzzles[i],(0,255,255)),(feet[i][0],(255,80,80)),(feet[i][1],(90,140,255))]:
            px,py=x+point[0],y+22+point[1];d.line((px-3,py,px+3,py),fill=color);d.line((px,py-3,px,py+3),fill=color)
    sheet.save(prov/'landmark_review.png')
    whole=arrays.astype(float);boots=whole[:,160:248,70:140];torso=whole[:,30:150,55:150]
    distances=lambda data:[float(np.abs(x-y).mean()) for x,y in zip(data,np.roll(data,-1,axis=0))]
    q={'bitmap_status':'PASS','frames':n,'unique_pixel_hashes':n,'border_alpha_max':0,'muzzle_count':len(muzzles),
       'boot_adjacent_cyclic_MAE':distances(boots),'body_adjacent_cyclic_MAE':distances(whole),
       'torso_adjacent_cyclic_MAE':distances(torso),'recommended_phase_origin':origin,
       'note':'Pixel differences are diagnostics, not proof of distinct valid gait. All17poses/97source frames were directly inspected.',
       'engine_integration':'NOT_RUN','producer_final_art':'NOT_VERIFIED'}
    meta['status']='MEASURED_ART_DELIVERY_ONLY'
    (prov/'source_registration.json').write_text(json.dumps(meta,indent=2)+'\n')
    (prov/'technical_qa.json').write_text(json.dumps(q,indent=2)+'\n')
    print(json.dumps({'frames':n,'phase_origin':origin,'muzzles':muzzles,'foot_anchors':anchors,'seam_body_MAE':q['body_adjacent_cyclic_MAE'][-1],'internal_body_MAE_median':float(np.median(q['body_adjacent_cyclic_MAE'][:-1]))}))


if __name__=='__main__':main()
