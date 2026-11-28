#!/usr/bin/env python3
"""Add only delivered SW moving fire; preserve all35 current clips."""
from pathlib import Path
import csv, hashlib, json, math, os, re
from PIL import Image
from build_viya_game065 import EXT_RESOURCE, ANIMATION

ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'assets/characters/pilot_32/game070_sw_run/viya_game070_frames.tres'
DEST=ROOT/'assets/characters/pilot_32/game075_sw_run_fire_candidate03'
RESOURCE='res://assets/characters/pilot_32/game075_sw_run_fire_candidate03/viya_game075_frames.tres'

def build():
    meta=json.loads((DEST/'provenance/clip_metadata.json').read_text())
    hashes=json.loads((DEST/'manifest.json').read_text())['frame_hashes']
    timing=list(csv.DictReader((DEST/'provenance/frame_timing.csv').open(newline='')))
    frames=meta['frames'];assert len(frames)==len(timing)==len(hashes)==15
    assert meta['canvas']==[200,248] and meta['pivot']==[100,248] and meta['display']==[69,85.56]
    assert math.isfinite(meta['run_fire_phase_origin']) and 0<=meta['run_fire_phase_origin']<1
    total=0.
    for i,(row,t,h) in enumerate(zip(frames,timing,hashes)):
        f=DEST/'frames'/t['filename']
        assert row['index']==i==int(t['frame']) and row['texture']=='res://'+f.relative_to(ROOT).as_posix()
        assert row['region']==[0,0,200,248] and h['file']=='frames/'+f.name
        assert hashlib.sha256(f.read_bytes()).hexdigest()==h['sha256']
        assert len(row['muzzle'])==2 and all(math.isfinite(v) and 0<=v<=lim for v,lim in zip(row['muzzle'],[200,248]))
        ms=float(t['duration_ms']);assert math.isfinite(ms) and ms>0 and abs(float(t['start_ms'])-total)<1e-6
        assert abs(ms-row['duration_ms'])<1e-6
        total+=ms
        im=Image.open(f);assert im.mode=='RGBA' and im.size==(200,248)
        assert im.getpixel((0,0))[3]==im.getpixel((199,247))[3]==0
    assert abs(total-660)<1e-6
    # Godot stores frame weights as float32. Binary microsecond ticks retain
    # the measured PTS intervals exactly instead of rounding weights near1.
    ticks=[round(float(t['source_duration_ms'])*1000) for t in timing]
    assert all(v>0 for v in ticks)
    fps=sum(ticks)/65536/(total/1000)
    assert all(abs(tick/sum(ticks)*total-float(t['duration_ms']))<1e-8 for tick,t in zip(ticks,timing))
    source=SOURCE.read_text();old={m['name']:m[0] for m in ANIMATION.finditer(source)}
    assert len(old)==35 and sum(v.count('ExtResource(') for v in old.values())==348 and 'run_fire_sw' not in old
    def relocate(m):
        path=os.path.relpath((SOURCE.parent/m['path']).resolve(),DEST).replace(os.sep,'/')
        assert (DEST/path).resolve().is_file()
        return m[0].replace('path="'+m['path']+'"','path="'+path+'"',1)
    text=EXT_RESOURCE.sub(relocate,source)
    text=re.sub(r'load_steps=\d+','load_steps=364',text,count=1)
    declarations='\n'.join(f'[ext_resource type="Texture2D" path="frames/{t["filename"]}" id="game075_fire_sw_{i:03d}"]' for i,t in enumerate(timing))
    text=text.replace('[resource]',declarations+'\n\n[resource]',1)
    match=re.search(r'^animations\s*=\s*\[(?P<body>.*)\]\s*\Z',text,re.M|re.S);assert match
    rows=',\n'.join('{"duration": '+format(ticks[i]/65536,'.17g')+', "texture": ExtResource("game075_fire_sw_'+f'{i:03d}'+'")}' for i,t in enumerate(timing))
    added='{\n"frames": ['+rows+'],\n"loop": true,\n"name": &"run_fire_sw",\n"speed": '+format(fps,'.17g')+'\n}'
    text=text[:match.end('body')]+', '+added+text[match.end('body'):]
    current={m['name']:m[0] for m in ANIMATION.finditer(text)}
    assert len(current)==36 and all(current[k]==v for k,v in old.items())
    assert sum(v.count('ExtResource(') for v in current.values())==363
    template=(SOURCE.parent/'frames/viya_run_sw_000.png.import').read_text()
    for t in timing:
        f=DEST/'frames'/t['filename'];path='res://'+f.relative_to(ROOT).as_posix()
        cache='res://.godot/imported/'+f.name+'-'+hashlib.md5(path.encode()).hexdigest()+'.ctex'
        ini=re.sub(r'^uid=.*\n','',template,flags=re.M)
        ini=re.sub(r'res://\.godot/imported/[^"\n]+',cache,ini)
        ini=re.sub(r'source_file="[^"]+"','source_file="'+path+'"',ini)
        ini=ini.replace('process/fix_alpha_border=true','process/fix_alpha_border=false')
        if not f.with_suffix('.png.import').exists():f.with_suffix('.png.import').write_text(ini)
    (DEST/'provenance/.gdignore').touch()
    (DEST/'viya_game075_frames.tres').write_text(text)
    motion=ROOT/'data/viya_motion.json';data=json.loads(motion.read_text())
    data['resource']=RESOURCE;data['directions']['sw']['run_fire']=frames
    data['directions']['sw']['run_fire_phase_origin']=meta['run_fire_phase_origin']
    motion.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
    slots=ROOT/'data/presentation_slots.json';data=json.loads(slots.read_text());data['viya_battle']=RESOURCE
    slots.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
    record={'source_resource':'res://'+SOURCE.relative_to(ROOT).as_posix(),'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'resource':RESOURCE,'preserved_clips':35,'preserved_frames':348,'added_clip':'run_fire_sw','added_frames':15,'total_clips':36,'total_frames':363,'nominal_cycle_ms':total,'phase_origin':meta['run_fire_phase_origin'],'status':'BUILT_NOT_RUNTIME_PROOF'}
    (DEST/'integration_manifest.json').write_text(json.dumps(record,indent=2)+'\n')
    print(json.dumps(record))

def prepare_delivery():
    import shutil
    evidence=ROOT/'tools/higgsfield/requests/game075/evidence/candidate_03'
    trial=evidence/'review_rgba'
    (DEST/'frames').mkdir(parents=True,exist_ok=True)
    (DEST/'provenance').mkdir(exist_ok=True)
    for source in sorted((trial/'frames').glob('*.png')):
        shutil.copyfile(source,DEST/'frames'/source.name)
    for name in ['frame_timing.csv','source_registration.json']:
        shutil.copyfile(trial/'provenance'/name,DEST/'provenance'/name)
    shutil.copyfile(evidence/'review/review_muzzles.csv',DEST/'provenance/muzzle_coordinates.csv')
    registration=json.loads((DEST/'provenance/source_registration.json').read_text())
    registration.update(status='USER_ACCEPTED_FOR_APPLICATION_WITH_KNOWN_LIMITS',producer_instruction='적용해',producer_final_art='NOT_VERIFIED')
    (DEST/'provenance/source_registration.json').write_text(json.dumps(registration,ensure_ascii=False,indent=2)+'\n')
    timing=list(csv.DictReader((DEST/'provenance/frame_timing.csv').open()))
    muzzles=list(csv.DictReader((DEST/'provenance/muzzle_coordinates.csv').open()))
    comparison=json.loads((evidence/'review/comparison_analysis.json').read_text())
    origin=comparison['phase_search']['origin']
    frames=[{'index':i,'texture':'res://'+(DEST/'frames'/t['filename']).relative_to(ROOT).as_posix(),'region':[0,0,200,248],'muzzle':[float(m['x']),float(m['y'])],'duration_ms':float(t['duration_ms'])}for i,(t,m)in enumerate(zip(timing,muzzles))]
    assert len(frames)==15 and all(int(t['source_frame'])==29+i for i,t in enumerate(timing))
    hashes=[{'file':'frames/'+t['filename'],'sha256':hashlib.sha256((DEST/'frames'/t['filename']).read_bytes()).hexdigest()}for t in timing]
    meta={'direction':'sw','animation':'run_fire_sw','canvas':[200,248],'pivot':[100,248],'display':[69,85.56],'source_cycle_ms':625,'nominal_cycle_ms':660,'stride_world':155,'base_speed':235,'run_fire_phase_origin':origin,'frames':frames,'status':'USER_ACCEPTED_APPLICATION_WITH_VISUAL_LIMITS','producer_instruction':'적용해','producer_final_art':'NOT_VERIFIED','phase_note':'Independent full-cycle lower-body silhouette fit, not anatomical contact proof. Known body/foot transition differences accepted for application.'}
    (DEST/'provenance/clip_metadata.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2)+'\n')
    comparison.update(method='Full-cycle lower-body silhouette IoU over2040 offsets, independently fitted from rendered paint. No old phase value copied.',run_fire_phase_origin=origin,foot_contact_phase='NOT_VERIFIED',accepted_limitations=['Body/boot pose differences during run/fire switch','Repeated-support pattern inherited from approved SW17','Exact weapon details and final art remain producer review'],producer_instruction='적용해')
    (DEST/'provenance/phase_alignment.json').write_text(json.dumps(comparison,ensure_ascii=False,indent=2)+'\n')
    manifest={'status':meta['status'],'frame_hashes':hashes,'source_video':'tools/higgsfield/requests/game075/evidence/candidate_03/candidate_03.mp4','source_sha256':'23af11250f8d25f504404d7c8f5743a0303e92a10e9b5dc24a2b966245165bf1','source_frames':list(range(29,44)),'next_boundary_excluded':44,'source_cycle_ms':625,'nominal_cycle_ms':660,'model':'seedance_2_5','mode':'video_edit','job_id':'ec7c9a20-e1a8-467d-b861-c46d2a5bed05','integration_extra_generations':0,'integration_extra_credits':0,'total_generation_credits':89,'producer_application_accepted':True,'producer_final_art':'NOT_VERIFIED'}
    (DEST/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')

if __name__=='__main__':
    prepare_delivery()
    build()
