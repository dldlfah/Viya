#!/usr/bin/env python3
"""Reproduce GAME069's inspected 2D landmarks and art-only review sheets.

The muzzle bore component and boot-tip ROIs were visually checked on all 18
frames. These are projected painting landmarks, not reconstructed 3D contacts.
"""
from pathlib import Path
import csv, hashlib, json, math
import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import label

ROOT = Path(__file__).resolve().parents[2]
DELIVERY = ROOT/'assets/characters/pilot_32/game069_s_run_fire'
PROV = DELIVERY/'provenance'


def save_json(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2)+'\n')


def save_csv(path, rows):
    with path.open('w', newline='') as f:
        w = csv.DictWriter(f, fieldnames=rows[0], lineterminator='\n')
        w.writeheader(); w.writerows(rows)


def main():
    paths = sorted((DELIVERY/'frames').glob('*.png'))
    assert len(paths) == 18
    ims = [Image.open(p).convert('RGBA') for p in paths]
    times = list(csv.DictReader((PROV/'frame_timing.csv').open()))
    feet = []; muzzles = []; foot_pairs = []
    states = ['right_support_left_recovery']*5 + ['right_toe_off_left_advances']*2 + ['left_support_right_recovery']*7 + ['left_toe_off_right_advances']*3 + ['right_support_left_recovery']
    overlay = Image.new('RGB', (1200,825), '#444444'); draw = ImageDraw.Draw(overlay)
    for i, im in enumerate(ims):
        a = np.array(im)
        tips = []
        for left,right in [(70,100),(100,127)]:
            yy,xx = np.where(a[163:247,left:right,3] > 180)
            selected = yy >= yy.max()-2
            tips.append([float(xx[selected].mean()+left), float(yy[selected].mean()+163)])
        foot_pairs.append(tips)
        # Isolated black bore is distinct from the glove/barrel surrounding it.
        # Frame10 also has a separate upper dark component: its y<71 excludes it.
        luminance = a[:,:,:3].mean(2)
        labs,count = label(luminance[69:80,102:115] < 18)
        choices = []
        for k in range(1,count+1):
            yy,xx = np.where(labs == k)
            if len(xx) >= 2 and yy.mean()+69 >= 71:
                choices.append([float(xx.mean()+102),float(yy.mean()+69)])
        assert len(choices) == 1, (i,choices)
        muzzle = choices[0]
        muzzles.append(dict(frame=i,source_frame=34+i,x=muzzle[0],y=muzzle[1],
            method='visually_confirmed_dark_bore_component_mean_rgb_lt18',uncertainty_px=1.5))
        feet.append(dict(frame=i,source_frame=34+i,screen_left_tip_x=tips[0][0],screen_left_tip_y=tips[0][1],
            screen_right_tip_x=tips[1][0],screen_right_tip_y=tips[1][1],state=states[i]))
        x=i%6*200;y=i//6*275
        overlay.paste(im,(x,y+22),im)
        for point,color in [(muzzle,'cyan'),(tips[0],'yellow'),(tips[1],'magenta')]:
            px,py=x+point[0],y+22+point[1]
            draw.ellipse((px-2,py-2,px+2,py+2),outline=color,width=1)
        draw.text((x+3,y+3),f'{i} / source{34+i}',fill='white')
    save_csv(PROV/'muzzle_coordinates.csv',muzzles)
    save_csv(PROV/'foot_landmarks.csv',feet)
    overlay.save(PROV/'landmark_overlay.png')
    old = json.loads((ROOT/'assets/characters/pilot_32/game068_s_run/provenance/clip_metadata.json').read_text())
    oldtimes = list(csv.DictReader((ROOT/'assets/characters/pilot_32/game068_s_run/provenance/frame_timing.csv').open()))
    anchors=[]
    for new_index,old_index,stance in [(1,11,'screen_right_support_left_recovery'),(10,3,'screen_left_support_right_recovery')]:
        np_,op = float(times[new_index]['phase']),float(oldtimes[old_index]['phase'])
        anchors.append(dict(new_frame=new_index,new_source_frame=34+new_index,current_s17_frame=old_index,
            stance=stance,new_local_phase=np_,current_s17_local_phase=op,
            origin_from_anchor=(np_-op+old['phase_origin'])%1,boot_tips=foot_pairs[new_index]))
    angles = [2*math.pi*a['origin_from_anchor'] for a in anchors]
    origin = (math.atan2(sum(math.sin(a) for a in angles),sum(math.cos(a) for a in angles))/(2*math.pi))%1
    residual = max(abs((a['origin_from_anchor']-origin+.5)%1-.5) for a in anchors)
    phase = dict(method='Circular least-squares offset from two visually matched opposite S17 support/recovery stances.',
        baseline_origin=old['phase_origin'],recommended_phase_origin=origin,anchors=anchors,
        formula='new_local=global+new_origin;old_local=global+old_origin;new_origin=new_local-old_local+old_origin(mod1)',
        maximum_anchor_residual_cycles=residual,
        landmark_method='Mean of lowest three alpha>180 rows, boot ROIs left x70:100/right x100:127,y163:247; visually inspected all frames.',
        limitation='2D projected stance correspondence; not physical floor contact or zero-slip proof. Painted toe positions and silhouettes differ. main.tscn transitions remain unverified.')
    save_json(PROV/'phase_alignment.json',phase)
    frames=[]
    for i,row in enumerate(times):
        frames.append(dict(index=i,texture='res://'+str(paths[i].relative_to(ROOT)),region=[0,0,200,248],
            muzzle=[muzzles[i]['x'],muzzles[i]['y']],duration_ms=float(row['duration_ms'])))
    metadata=dict(direction='s',animation='run_fire_s',optional=True,canvas=[200,248],pivot=[100,248],display=[69,85.56],
        nominal_cycle_ms=660,distance_cycle_ms=155/235*1000,stride_world=155,base_speed=235,
        phase_origin=origin,run_fire_phase_origin=origin,source_cycle_ms=750,
        runtime_status='NOT_CONNECTED_ART_HANDOFF_ONLY',fallback='same global-distance-phase current run_s17 when missing/invalid',frames=frames)
    save_json(PROV/'clip_metadata.json',metadata)
    for name,bg in [('black',(0,0,0)),('white',(255,255,255)),('gray',(128,128,128))]:
        sheet=Image.new('RGB',(1200,825),bg);d=ImageDraw.Draw(sheet)
        for i,im in enumerate(ims):
            x=i%6*200;y=i//6*275;sheet.paste(im,(x,y+22),im)
            d.text((x+3,y+3),str(i),fill='black' if name=='white' else 'white')
        sheet.save(PROV/f'alpha_{name}.jpg',quality=95)
    # Same registered selected frame crops, never a per-frame registration.
    seam=Image.new('RGB',(1000,290),'#444444');d=ImageDraw.Draw(seam)
    for column,index in enumerate([15,16,17,0,1]):
        seam.paste(ims[index],(column*200,28),ims[index]);d.text((column*200+4,7),f'frame{index} / source{34+index}',fill='white')
    seam.save(PROV/'loop_seam.png')
    # Source-vs-matte details preserve aspect ratio, including internal ornaments.
    source=Image.open(ROOT/'.local_validation/GAME069/source_02/0035.png').convert('RGB')
    reg=dict(scale=.273,translation=[-31.04,-8.2])
    registered=source.transform((200,248),Image.Transform.AFFINE,(1/.273,0,31.04/.273,0,1/.273,8.2/.273),Image.Resampling.BICUBIC)
    details=Image.new('RGB',(1000,540),'#444444');d=ImageDraw.Draw(details)
    for column,(pic,txt) in enumerate([(registered,'RGB fixed registration'),(ims[0],'RGBA black'),(ims[0],'RGBA white'),(ims[0],'RGBA gray')]):
        bg=[(60,60,60),(0,0,0),(255,255,255),(128,128,128)][column]
        card=Image.new('RGB',(250,496),bg);large=pic.resize((250,310),Image.Resampling.LANCZOS)
        if large.mode=='RGBA':card.paste(large,(0,0),large)
        else:card.paste(large,(0,0))
        head=pic.crop((40,12,155,105)).resize((230,186),Image.Resampling.LANCZOS)
        if head.mode=='RGBA':card.paste(head,(10,310),head)
        else:card.paste(head,(10,310))
        details.paste(card,(250*column,30));d.text((250*column+4,8),txt,fill='white')
    details.save(PROV/'alpha_source_comparison.jpg',quality=95)
    registration=json.loads((PROV/'source_registration.json').read_text())
    registration['status']='REGISTERED_TECHNICAL_DELIVERY_FINAL_ART_PENDING'
    for i,check in enumerate(registration['frame_checks']):
        check['landmarks']=dict(muzzle=frames[i]['muzzle'],boot_tips=foot_pairs[i])
    save_json(PROV/'source_registration.json',registration)
    changes=[]
    for i in range(len(ims)):
        a=np.asarray(ims[i]).astype(float);b=np.asarray(ims[(i+1)%len(ims)]).astype(float)
        mask=(a[:,:,3]>0)|(b[:,:,3]>0)
        changes.append(float(np.abs(a-b)[mask].mean()))
    qa=dict(status='TECHNICALLY_ADOPTED_FINAL_ART_PENDING',frame_count=18,unique_png_count=len({hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}),
        source_frames=list(range(34,52)),excluded_next_cycle_endpoint=52,source_cycle_ms=750,
        total_nominal_ms=sum(float(t['duration_ms']) for t in times),total_base_speed_ms=sum(float(t['base_speed_duration_ms']) for t in times),
        all_rgba_200x248=all(im.size==(200,248) and im.mode=='RGBA' for im in ims),
        max_border_alpha=max(c['border_alpha_max'] for c in registration['frame_checks']),
        adjacent_rgba_mae_foreground=changes,seam_mae=changes[-1],mae_note='Diagnostic only, not proof of valid gait or character identity.',
        inspected=['all97 ordered native candidate02 frames','all18 selected RGBA frames','opposite-leg stance anchors','last-to-first seam',
            'black/white/gray edges and opaque interior ornaments','independent projected barrel bore and boot tips'],
        observations=['S front high-angle camera retained; shoulder-supported aiming differs from rejected waist carry.',
            'Both legs alternate; pelvis/body height and shoulders evolve while weapon is steadied.',
            'No baked discharge or additional character observed in selected cycle.',
            'Fixed scale/translation only; source frames34..51 consecutive; no generated inbetweens or endpoint copy.'],
        limitations=['Natural perspective shortens the aimed rifle; concealed markings and physical length cannot be verified from pixels.',
            'Fine hair/tiny paint details remain limited by generated video and chroma matte; final art judgment pending.',
            'Loop is visually usable, not pixel-identical at seam. No claim of physical zero-slip.',
            'Aim/carry upper-body silhouette change remains visible in direct switching; no transition frames synthesized.',
            'Actual game integration, engine transition validation, shot/recoil synchronization, Windows/mobile/FPS not performed.'],
        phase_origin=origin,maximum_anchor_residual_cycles=residual)
    save_json(PROV/'qa_report.json',qa)
    print(json.dumps({k:qa[k] for k in ['frame_count','unique_png_count','max_border_alpha','total_nominal_ms','total_base_speed_ms','phase_origin','maximum_anchor_residual_cycles','seam_mae']}))


if __name__=='__main__':main()
