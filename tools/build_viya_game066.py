#!/usr/bin/env python3
"""Build GAME066 SE gait derivative from the vetted 18 RGBA files.
Only run_se is replaced; no other SpriteFrames animation, frame or original bitmap is modified.
"""
from pathlib import Path
import re, json, hashlib, csv, shutil
ROOT=Path(__file__).resolve().parent.parent
OLD=ROOT/'assets/characters/pilot_32/game065_e_run_fire/viya_game065_frames.tres'
NEW=ROOT/'assets/characters/pilot_32/game066_se_run'
TRES=NEW/'viya_game066_frames.tres'
FRAME_DIR=NEW/'frames'
META=NEW/'provenance/source_registration.json'
GAME_PATH='res://assets/characters/pilot_32/game066_se_run/'
def build():
 # Provenance CSV is runtime-readable data, not Godot translation input.
 (NEW/"provenance"/".gdignore").touch()
 m=json.loads(META.read_text())
 assert m['status'] == 'TECHNICAL_REVIEWED_GAME066'
 entries=m['frame_checks'];assert len(entries)==18
 for item in entries:
  f=FRAME_DIR/item['filename']
  assert f.is_file() and hashlib.sha256(f.read_bytes()).hexdigest()==item['sha256']
  assert item['border_alpha_max']==0
 s=OLD.read_text()
 assert s.count('"name": &"run_se"')==1 and s.count('"name": &"run_fire_e"')==1
 # Remove only eleven unused old run-se external references.
 lines=s.splitlines(keepends=True)
 lines=[line for line in lines if not ('[ext_resource ' in line and re.search(r'id="\d+_run_se_\d+"',line))]
 s=''.join(lines)
 s=s.replace('path="frames/viya_run_fire_e_','path="../game065_e_run_fire/frames/viya_run_fire_e_')
 assert 'path="../game065_e_run_fire/frames/viya_run_fire_e_000.png"' in s
 # The new resource is sibling to GAME065, so other ../ paths remain valid.
 new_ext=''.join(f'[ext_resource type="Texture2D" path="frames/viya_run_se_{i:03d}.png" id="game066_run_se_{i:03d}"]\n' for i in range(18))
 s=s.replace('[resource]\n',new_ext+'\n[resource]\n',1)
 run_start=s.index('}, {\n"frames":',s.index('"name": &"idle_se"'))
 run_end=s.index('}, {\n"frames":',s.index('"name": &"run_se"'))
 new_frames=',\n'.join(f'{{"duration": 1.0, "texture": ExtResource("game066_run_se_{i:03d}")}}' for i in range(18))
 run_section='}, {\n"frames": ['+new_frames+'],\n"loop": true,\n"name": &"run_se",\n"speed": '+str(18/.660)+'\n'
 s=s[:run_start]+run_section+s[run_end:]
 s=re.sub(r'load_steps=\d+', 'load_steps=299',s,count=1)
 assert s.count('"name": &"run_se"')==1 and s.count('"name": &"run_fire_e"')==1
 assert s.count('[ext_resource type="Texture2D"')==298, s.count('[ext_resource type="Texture2D"')
 TRES.write_text(s)
 motion_path=ROOT/'data/viya_motion.json'
 motion=json.loads(motion_path.read_text())
 assert len(motion['directions']['se']['run']) in (11,18) and motion['directions']['se']['phase_origin'] == 3/11
 # Source video was exported by run_se at phase0 and the original 3/11 offset is retained.
 motion['resource']=GAME_PATH+'viya_game066_frames.tres'
 motion['directions']['se']['run']=[dict(index=i,region=[0,0,200,248],muzzle=item['muzzle'],texture=GAME_PATH+'frames/'+item['filename']) for i,item in enumerate(entries)]
 if 'GAME066 SE run18' not in motion['notice']:motion['notice']+=' GAME066 SE run18 by source frames36..53, unchanged E47/fire47, fixed root(100,248), phase origin retained.'
 motion_path.write_text(json.dumps(motion,ensure_ascii=False,indent=2)+'\n')
 slots_path=ROOT/'data/presentation_slots.json'
 slots=json.loads(slots_path.read_text()); assert slots['viya_battle'].endswith(('/game065_e_run_fire/viya_game065_frames.tres','/game066_se_run/viya_game066_frames.tres'))
 slots['viya_battle']=GAME_PATH+'viya_game066_frames.tres'
 slots_path.write_text(json.dumps(slots,ensure_ascii=False,indent=2)+'\n')
 manifest=dict(task='GAME066',status='TECHNICAL_REVIEWED_AWAITING_ENGINE_VALIDATION',resource=GAME_PATH+'viya_game066_frames.tres',
     source='game065_e_run_fire/viya_game065_frames.tres',source_sha256=hashlib.sha256(OLD.read_bytes()).hexdigest(),
     replaced_animation='run_se',new_frames=18,old_frames=11,animation_count=33,expected_total_frames=298,
     registration={'canvas':[200,248],'pivot':[100,248],'display':[69,85.56],'scale':m['scale'],'translation':m['translation'],'global_fixed':True},
     timing={'source_frame_window':[36,54],'source_fps':24,'source_cycle_ms':750,'game_cycle_ms':660,'actual_distance_cycle_ms':155/235*1000,'frame_ms':660/18,'phase_origin_retained':3/11},
     future_art_approval=False,preservation=['GAME065 E run/fire','GAME064 E run','ARTFIX001','208 original PNG','all other 32 animations','save22','7 RNG','weapons and spawns'])
 (NEW/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
 print(json.dumps({'source_sha':manifest['source_sha256'],'new':str(TRES),'frames':18,'animations':s.count('"name": &')}))
if __name__=='__main__': build()
