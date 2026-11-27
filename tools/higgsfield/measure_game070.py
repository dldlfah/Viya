#!/usr/bin/env python3
"""Measure the producer-accepted GAME070 native motif without repairing its gait."""
from pathlib import Path
import csv,hashlib,json
import numpy as np
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[2]
D=ROOT/'assets/characters/pilot_32/game070_sw_run';P=D/'provenance'
def write(name,obj): (P/name).write_text(json.dumps(obj,ensure_ascii=False,indent=2)+'\n')
def main():
 reg=json.loads((P/'source_registration.json').read_text());timing=list(csv.DictReader((P/'frame_timing.csv').open()))
 files=sorted((D/'frames').glob('*.png'));images=[Image.open(f).convert('RGBA') for f in files]
 # Manually inspected projected toe tips, not reconstructed ground-plane contacts.
 # Near leg is the forward screen-left boot in source34; follow that same leg
 # through recovery rather than renaming legs by their changing screen x.
 feet=[[[44,233],[113,194]],[[42,233],[126,178]],[[43,233],[128,180]],[[43,234],[128,180]],[[44,236],[125,182]],[[54,228],[115,191]],[[81,225],[109,195]],[[91,211],[78,219]],[[92,207],[77,224]],[[67,232],[90,183]],[[67,244],[98,180]],[[66,245],[101,178]],[[69,244],[103,180]],[[65,233],[95,182]],[[90,229],[68,195]],[[59,207],[91,224]],[[55,217],[110,216]]]
 muzzles=[];rows=[]
 for i,(im,t) in enumerate(zip(images,timing)):
  arr=np.array(im);yy,xx=np.where(arr[135:170,15:48,3]>=192)
  left=int(xx.min());point=[15+left+.5,135+float(yy[xx==left].mean())+.5];muzzles.append(point)
  rows.append({'index':i,'texture':'res://'+str(files[i].relative_to(ROOT)),'region':[0,0,200,248],'muzzle':point,'duration_ms':float(t['duration_ms'])})
 with (P/'muzzle_coordinates.csv').open('w',newline='') as f:
  w=csv.writer(f,lineterminator="\n");w.writerow(['frame','source_frame','x','y','method'])
  for i,p in enumerate(muzzles):w.writerow([i,34+i,*p,'leftmost opaque barrel end in inspected ROI x15:48 y135:170'])
 with (P/'foot_landmarks.csv').open('w',newline='') as f:
  w=csv.writer(f,lineterminator="\n");w.writerow(['frame','source_frame','near_toe_x','near_toe_y','far_toe_x','far_toe_y','observation'])
  for i,p in enumerate(feet):w.writerow([i,i+34,*p[0],*p[1],'near_support' if i<6 else ('near_support_repeats_known_defect' if 9<=i<=13 else ('far_support' if i==15 else 'transition'))])
 old=json.loads((ROOT/'data/viya_motion.json').read_text())['directions']['s']['phase_origin']
 anchors=[]
 for ni,si,stance in [(3,3,'near_support / S screen-left support'),(15,11,'far_support / S screen-right support')]:
  local=float(timing[ni]['phase']);srows=list(csv.DictReader((ROOT/'assets/characters/pilot_32/game068_s_run/provenance/frame_timing.csv').open()))
  sp=float(srows[si]['phase']);origin=(local-sp+old)%1
  anchors.append(dict(sw_frame=ni,source_frame=34+ni,s_frame=si,stance=stance,sw_local=local,s_local=sp,origin_from_anchor=origin,sw_toe_tips=feet[ni]))
 candidates=np.array([x['origin_from_anchor'] for x in anchors]);origin=float(np.angle(np.mean(np.exp(2j*np.pi*candidates)))/(2*np.pi)%1)
 residual=float(max(abs((candidates-origin+.5)%1-.5)))
 write('phase_alignment.json',dict(method='Circular mean of two directly inspected opposite projected boot-support anchors. No 3D skeleton or physical contact inference.',s_origin=old,phase_origin=origin,anchors=anchors,maximum_anchor_residual_cycles=residual,maximum_anchor_residual_nominal_ms=residual*660,limitation='Accepted raw motif contains a second near-leg support. One phase offset cannot align both support events exactly; numerical phase continuity is not pose continuity or zero-slip proof.'))
 write('clip_metadata.json',dict(direction='sw',animation='run_sw',canvas=[200,248],pivot=[100,248],display=[69,85.56],nominal_cycle_ms=660,distance_cycle_ms=155/235*1000,stride_world=155,base_speed=235,phase_origin=origin,frames=rows,replace_only='run_sw11; other34clips331frames preserved',producer_decision='User: 이대로 적용해; accept candidate04 with disclosed gait defects',final_in_game_art='Not yet reviewed by producer'))
 sheet=Image.new('RGB',(1200,825),(55,55,55));draw=ImageDraw.Draw(sheet)
 for i,im in enumerate(images):
  x=i%6*200;y=i//6*275;sheet.paste(im,(x,y+22),im);draw.text((x+3,y+3),f'{i} src{i+34}',fill='white')
  for p,c in [(muzzles[i],'cyan'),(feet[i][0],'red'),(feet[i][1],'blue')]:draw.ellipse((x+p[0]-2,y+22+p[1]-2,x+p[0]+2,y+22+p[1]+2),fill=c)
 sheet.save(P/'landmark_review.png')
 alpha=Image.new('RGB',(1200,3*275));draw=ImageDraw.Draw(alpha)
 for j,bg in enumerate([(0,0,0),(128,128,128),(255,255,255)]):
  draw.rectangle((0,j*275,1200,(j+1)*275),fill=bg)
  for k,i in enumerate([0,3,7,10,15,16]):alpha.paste(images[i],(k*200,j*275+20),images[i])
 alpha.save(P/'alpha_black_gray_white.png')
 reg['status']='PRODUCER_ACCEPTED_WITH_KNOWN_GAIT_LIMITATIONS';write('source_registration.json',reg)
 manifest={'source_video':'tools/higgsfield/requests/game070/evidence/packet_9927fcd/candidate_04.mp4','source_sha256':reg['source_sha256'],'source_frames':list(range(34,51)),'excluded_next_boundary':51,'frame_checks':reg['frame_checks'],'producer_acceptance':'이대로 적용해','gait_limitations':['Extra near-leg support persists','Single phase offset leaves opposite-support mismatch'],'new_paid_submissions':0,'new_credits':0,'generation_job':'da27204a-f0a6-47ce-9831-a4b5481b8d36','generation_net_credits':28,'GAME070_cumulative_net_credits':84}
 (D/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
 print(json.dumps({'frames':len(images),'phase_origin':origin,'anchor_residual_ms':residual*660,'muzzles':muzzles}))
if __name__=='__main__':main()
