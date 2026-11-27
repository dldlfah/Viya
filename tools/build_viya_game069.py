#!/usr/bin/env python3
"""Add only delivered S moving fire; preserve all34 current clips."""
from pathlib import Path
import csv, hashlib, json, math, os, re
from PIL import Image
from build_viya_game065 import EXT_RESOURCE, ANIMATION

ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'assets/characters/pilot_32/game068_s_run/viya_game068_frames.tres'
DEST=ROOT/'assets/characters/pilot_32/game069_s_run_fire'
RESOURCE='res://assets/characters/pilot_32/game069_s_run_fire/viya_game069_frames.tres'

def build():
    meta=json.loads((DEST/'provenance/clip_metadata.json').read_text())
    hashes=json.loads((DEST/'manifest.json').read_text())['frame_hashes']
    timing=list(csv.DictReader((DEST/'provenance/frame_timing.csv').open(newline='')))
    frames=meta['frames'];assert len(frames)==len(timing)==len(hashes)==18
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
    assert len(old)==34 and sum(v.count('ExtResource(') for v in old.values())==324 and 'run_fire_s' not in old
    def relocate(m):
        path=os.path.relpath((SOURCE.parent/m['path']).resolve(),DEST).replace(os.sep,'/')
        assert (DEST/path).resolve().is_file()
        return m[0].replace('path="'+m['path']+'"','path="'+path+'"',1)
    text=EXT_RESOURCE.sub(relocate,source)
    text=re.sub(r'load_steps=\d+','load_steps=343',text,count=1)
    declarations='\n'.join(f'[ext_resource type="Texture2D" path="frames/{t["filename"]}" id="game069_fire_s_{i:03d}"]' for i,t in enumerate(timing))
    text=text.replace('[resource]',declarations+'\n\n[resource]',1)
    match=re.search(r'^animations\s*=\s*\[(?P<body>.*)\]\s*\Z',text,re.M|re.S);assert match
    rows=',\n'.join('{"duration": '+format(ticks[i]/65536,'.17g')+', "texture": ExtResource("game069_fire_s_'+f'{i:03d}'+'")}' for i,t in enumerate(timing))
    added='{\n"frames": ['+rows+'],\n"loop": true,\n"name": &"run_fire_s",\n"speed": '+format(fps,'.17g')+'\n}'
    text=text[:match.end('body')]+', '+added+text[match.end('body'):]
    current={m['name']:m[0] for m in ANIMATION.finditer(text)}
    assert len(current)==35 and all(current[k]==v for k,v in old.items())
    assert sum(v.count('ExtResource(') for v in current.values())==342
    template=(SOURCE.parent/'frames/viya_run_s_000.png.import').read_text()
    for t in timing:
        f=DEST/'frames'/t['filename'];path='res://'+f.relative_to(ROOT).as_posix()
        cache='res://.godot/imported/'+f.name+'-'+hashlib.md5(path.encode()).hexdigest()+'.ctex'
        ini=re.sub(r'^uid=.*\n','',template,flags=re.M)
        ini=re.sub(r'res://\.godot/imported/[^"\n]+',cache,ini)
        ini=re.sub(r'source_file="[^"]+"','source_file="'+path+'"',ini)
        ini=ini.replace('process/fix_alpha_border=true','process/fix_alpha_border=false')
        if not f.with_suffix('.png.import').exists():f.with_suffix('.png.import').write_text(ini)
    (DEST/'provenance/.gdignore').touch()
    (DEST/'viya_game069_frames.tres').write_text(text)
    motion=ROOT/'data/viya_motion.json';data=json.loads(motion.read_text())
    data['resource']=RESOURCE;data['directions']['s']['run_fire']=frames
    data['directions']['s']['run_fire_phase_origin']=meta['run_fire_phase_origin']
    motion.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
    slots=ROOT/'data/presentation_slots.json';data=json.loads(slots.read_text());data['viya_battle']=RESOURCE
    slots.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
    record={'source_resource':'res://'+SOURCE.relative_to(ROOT).as_posix(),'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'resource':RESOURCE,'preserved_clips':34,'preserved_frames':324,'added_clip':'run_fire_s','added_frames':18,'total_clips':35,'total_frames':342,'nominal_cycle_ms':total,'phase_origin':meta['run_fire_phase_origin'],'status':'BUILT_NOT_RUNTIME_PROOF'}
    (DEST/'integration_manifest.json').write_text(json.dumps(record,indent=2)+'\n')
    print(json.dumps(record))

if __name__=='__main__':build()
