#!/usr/bin/env python3
"""Measure delivered GAME075 paint and independent projected stance alignment."""
from pathlib import Path
import csv,hashlib,json,math,re
import numpy as np
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[2]
D=ROOT/'assets/characters/pilot_32/game075_sw_run_fire';P=D/'provenance'
def save(name,data): (P/name).write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
def main():
 files=sorted((D/'frames').glob('*.png'));images=[Image.open(f).convert('RGBA') for f in files]
 timing=list(csv.DictReader((P/'frame_timing.csv').open()));reg=json.loads((P/'source_registration.json').read_text());n=len(files)
 assert n==15==len(timing) and [int(t['source_frame']) for t in timing]==list(range(30,45))
 assert all(i.size==(200,248) for i in images)
 seeds=[[[67,232],[152,198]],[[66,235],[153,188]],[[67,236],[153,182]],[[76,232],[141,182]],[[88,226],[142,190]],[[130,204],[105,216]],[[132,200],[112,222]],[[133,197],[101,233]],[[136,192],[96,237]],[[138,186],[92,241]],[[138,181],[91,243]],[[132,181],[100,239]],[[115,198],[112,233]],[[109,194],[124,226]],[[89,214],[137,217]]]
 muzzles=[];feet=[];frames=[]
 for i,(f,im,t) in enumerate(zip(files,images,timing)):
  a=np.array(im);yy,xx=np.where(a[70:135,0:45,3]>=192);assert len(xx)
  left=int(xx.min());m=[left+.5,70+float(yy[xx==left].mean())+.5];muzzles.append(m)
  pair=[]
  for sx,sy in seeds[i]:
   x0=max(0,sx-8);y0=max(0,sy-8);x1=min(200,sx+9);y1=min(248,sy+9)
   fy,fx=np.where(a[y0:y1,x0:x1,3]>=192);assert len(fx),(i,sx,sy)
   lower=fy>=np.quantile(fy,.97);pair.append([float(fx[lower].mean()+x0),float(fy[lower].mean()+y0)])
  feet.append(pair)
  frames.append({'index':i,'texture':'res://'+str(f.relative_to(ROOT)),'region':[0,0,200,248],'muzzle':m,'duration_ms':float(t['duration_ms'])})
 with (P/'muzzle_coordinates.csv').open('w',newline='') as f:
  w=csv.writer(f,lineterminator='\n');w.writerow(['frame','filename','source_frame','x','y','method'])
  for i,m in enumerate(muzzles):w.writerow([i,files[i].name,i+30,*m,'independent leftmost opaque barrel end in inspected ROI x0:45 y70:135'])
 with (P/'foot_landmarks.csv').open('w',newline='') as f:
  w=csv.writer(f,lineterminator='\n');w.writerow(['frame','source_frame','near_tip_x','near_tip_y','far_tip_x','far_tip_y','state','measurement'])
  for i,pair in enumerate(feet):
   state='near_support_far_recovery' if i<=3 else ('near_toeoff_far_advances' if i<=5 else ('far_support_near_recovery' if i<=11 else 'far_toeoff_near_advances_flight'))
   w.writerow([i,i+30,*pair[0],*pair[1],state,'lower opaque edge in manually reviewed per-boot ROI; anatomical/occlusion uncertainty not quantified; no world floor reconstruction'])
 olddir=ROOT/'assets/characters/pilot_32/game070_sw_run/provenance'
 oldtiming=list(csv.DictReader((olddir/'frame_timing.csv').open()));oldfeet=list(csv.DictReader((olddir/'foot_landmarks.csv').open()))
 old_origin=json.loads((ROOT/'data/viya_motion.json').read_text())['directions']['sw']['phase_origin']
 anchors=[]
 for ni,oi,label in [(2,3,'near boot extended / far recovery'),(10,8,'far boot extended / near recovery')]:
  phase=lambda t:(float(t['start_ms'])+float(t['duration_ms'])*.5)/660
  new_phase=phase(timing[ni]);old_phase=phase(oldtiming[oi]);candidate=(new_phase-old_phase+old_origin)%1
  anchors.append({'new_frame':ni,'new_source_frame':30+ni,'old_sw_frame':oi,'stance':label,'new_mid_phase':new_phase,'old_mid_phase':old_phase,'origin_from_anchor':candidate,'new_tips':feet[ni],'old_tips':[[float(oldfeet[oi][k+'_toe_x']),float(oldfeet[oi][k+'_toe_y'])] for k in ['near','far']]})
 candidates=np.array([a['origin_from_anchor'] for a in anchors]);origin=float(np.angle(np.mean(np.exp(2j*np.pi*candidates)))/(2*np.pi)%1)
 residual=max(abs((candidates-origin+.5)%1-.5))
 alignment={'method':'Circular mean of two directly reviewed opposite projected boot-extension/recovery stances, using interval midpoints. Independent of the existing SW number.','formula':'new_origin = new_local - old_local + old_origin (mod1)','baseline_origin':old_origin,'run_fire_phase_origin':origin,'anchors':anchors,'maximum_anchor_residual_cycles':float(residual),'maximum_anchor_residual_nominal_ms':float(residual*660),'anatomical_note':'Near/far track projected painted legs, not reconstructed anatomical/world-floor contacts. Painted edge samples have unquantified anatomical/recovery/occlusion correspondence uncertainty.','baseline_ambiguity':'Existing approved SW17 contains an additional near-support motif and another late opposite-leg pose at15. Frame8 was chosen for the corresponding recovery silhouette. One phase offset cannot make all old/new poses or foot positions equal.','limitations':['Exact physical foot contact/zero-slip not proven','Same distance phase does not remove painted foot/body position differences','Actual run/fire and S/SW transitions require production main.tscn review']}
 save('phase_alignment.json',alignment)
 ticks=[int(t['source_duration_ticks']) for t in timing];unit=math.gcd(*ticks);speed=sum(t/unit for t in ticks)/.660
 meta={'direction':'sw','animation':'run_fire_sw','canvas':[200,248],'pivot':[100,248],'display':[69,85.56],'nominal_cycle_ms':660,'source_cycle_ms':reg['source_cycle_ms'],'distance_cycle_ms':155/235*1000,'stride_world':155,'base_speed':235,'run_fire_phase_origin':origin,'frames':frames,'recommended_spriteframes':{'binary_frame_weights':[t/unit for t in ticks],'duration_unit_source_ticks':unit,'speed':speed,'loop':True},'integration':'OPTIONAL_ADDITIONAL_CLIP_ONLY; preserve current35clips348frames; no active slot or game code changed','status':'MEASURED_REVIEW_CANDIDATE_TRANSITION_NOT_FINAL','producer_final_art':'NOT_VERIFIED','game_connection':'NOT_RUN'}
 save('clip_metadata.json',meta)
 sheet=Image.new('RGB',(1200,825),(55,55,55));d=ImageDraw.Draw(sheet)
 for i,im in enumerate(images):
  x=i%6*200;y=i//6*275;sheet.paste(im,(x,y+22),im);d.text((x+3,y+3),f'{i} src{i+30}',fill='white')
  for pt,c in [(muzzles[i],'cyan'),(feet[i][0],'red'),(feet[i][1],'blue')]:d.ellipse((x+pt[0]-2,y+22+pt[1]-2,x+pt[0]+2,y+22+pt[1]+2),fill=c)
 sheet.save(P/'landmark_review.png')
 alpha=Image.new('RGB',(1200,825));d=ImageDraw.Draw(alpha)
 for j,bg in enumerate([(0,0,0),(128,128,128),(255,255,255)]):
  d.rectangle((0,j*275,1200,(j+1)*275),fill=bg)
  for k,i in enumerate([0,2,5,8,10,14]):alpha.paste(images[i],(k*200,j*275+20),images[i])
 alpha.save(P/'alpha_black_gray_white.png')
 arrays=np.array([np.asarray(i) for i in images]).astype(float);dist=lambda a:[float(np.abs(x-y).mean()) for x,y in zip(a,np.roll(a,-1,axis=0))]
 qa={'bitmap':'PASS','frames':n,'distinct_pixel_hashes':len({hashlib.sha256(i.tobytes()).hexdigest() for i in images}),'canvas':[200,248],'border_alpha_max':max(int(np.max(np.r_[a[0,:,3],a[-1,:,3],a[:,0,3],a[:,-1,3]])) for a in arrays),'source_cycle_ms':reg['source_cycle_ms'],'nominal_cycle_ms':sum(float(t['duration_ms']) for t in timing),'base_distance_cycle_ms':sum(float(t['base_speed_duration_ms']) for t in timing),'timing_from':'Exact integer PTS ticks/time_base; no synthesized pose or duplicated endpoint','body_cyclic_MAE':dist(arrays),'boots_cyclic_MAE':dist(arrays[:,145:248,35:165]),'pose_review':'All97raw frames and selected15full-body frames directly inspected. Hash/MAE are diagnostics, not gait proof.','alpha_review':'Black/gray/white, muzzle, hair, costume and boots directly inspected; green spill removed locally.','transition_visual':'RESIDUAL_REQUIRES_PRODUCER_AND_MAIN_SCENE_REVIEW','game_runtime':'NOT_RUN','windows_mobile':'NOT_VERIFIED','producer_final_art':'NOT_VERIFIED'}
 assert qa['distinct_pixel_hashes']==15 and qa['border_alpha_max']==0 and abs(qa['nominal_cycle_ms']-660)<1e-8
 save('technical_qa.json',qa)
 reg['status']='MEASURED_REVIEW_CANDIDATE_NOT_ACTIVE';reg['registration']['source_root']=[(100-reg['registration']['translation'][0])/reg['registration']['scale'],(248-reg['registration']['translation'][1])/reg['registration']['scale']];save('source_registration.json',reg)
 manifest={'status':meta['status'],'source_video':'tools/higgsfield/requests/game075/evidence/candidate_02.mp4','source_sha256':reg['source_sha256'],'source_frames':list(range(30,45)),'excluded_next_boundary':45,'source_cycle_ms':reg['source_cycle_ms'],'frame_hashes':[{'file':'frames/'+f.name,'sha256':hashlib.sha256(f.read_bytes()).hexdigest()} for f in files],'model':'seedance_2_5','mode':'video_edit','job_id':'18014a92-2bf2-4c77-ab40-19d288002022','input_generation_job_id':'7fa6e18e-a5ca-4607-b854-9099a8c30faf','paid_submissions':2,'net_credits':59,'remaining_unit_budget':1,'active_resource_unchanged':'res://assets/characters/pilot_32/game070_sw_run/viya_game070_frames.tres','current_game_clips':35,'current_game_frames':348,'prospective_after_production_clips':36,'prospective_after_production_frames':363}
 (D/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
 # Lossless proposed import presets. Normal Godot import/pixel equality remains
 # a production-session check; no engine run is claimed here.
 template=(ROOT/'assets/characters/pilot_32/game070_sw_run/frames/viya_run_sw_000.png.import').read_text()
 for f in files:
  path='res://'+str(f.relative_to(ROOT));cache='res://.godot/imported/'+f.name+'-'+hashlib.md5(path.encode()).hexdigest()+'.ctex'
  text=re.sub(r'^uid=.*\n','',template,flags=re.M);text=re.sub(r'res://\.godot/imported/[^"\n]+',cache,text);text=re.sub(r'source_file="[^"]+"','source_file="'+path+'"',text);text=text.replace('process/fix_alpha_border=true','process/fix_alpha_border=false');f.with_suffix('.png.import').write_text(text)
 print(json.dumps({'frames':n,'source_cycle_ms':reg['source_cycle_ms'],'phase_origin':origin,'max_anchor_residual_ms':float(residual*660),'muzzles':muzzles,'seam_body_MAE':qa['body_cyclic_MAE'][-1]}))
if __name__=='__main__':main()
