#!/usr/bin/env python3
"""Render art-only GAME075 loop and same-distance-phase transitions, never engine footage."""
from pathlib import Path
import csv,json,math,subprocess
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[2];D=ROOT/'assets/characters/pilot_32/game075_sw_run_fire';P=D/'provenance'
def main():
 meta=json.loads((P/'clip_metadata.json').read_text());cfg=json.loads((ROOT/'data/viya_motion.json').read_text())['directions']['sw']
 old=cfg['run'];new=meta['frames'];oo=cfg['phase_origin'];no=meta['run_fire_phase_origin']
 pictures={r['texture']:Image.open(ROOT/r['texture'][6:]).convert('RGBA') for r in old+new}
 oldfeet=list(csv.DictReader((ROOT/'assets/characters/pilot_32/game070_sw_run/provenance/foot_landmarks.csv').open()));newfeet=list(csv.DictReader((P/'foot_landmarks.csv').open()))
 def sample(rows,origin,phase):
  at=(phase+origin)%1*660;elapsed=0
  for i,r in enumerate(rows):
   elapsed+=r['duration_ms']
   if at<elapsed:return i,r
  return len(rows)-1,rows[-1]
 font=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',16)
 pairs=[];sheet=Image.new('RGB',(1000,8*280),(65,65,65));draw=ImageDraw.Draw(sheet)
 for j,phase in enumerate([0,.125,.25,.375,.5,.625,.75,.875]):
  oi,o=sample(old,oo,phase);ni,n=sample(new,no,phase);y=j*280
  draw.text((8,y+3),f'global phase {phase:.3f} : SW carry{oi} / aimed{ni}',font=font,fill='white')
  for x,r in [(0,o),(210,n)]:im=pictures[r['texture']];sheet.paste(im,(x,y+28),im)
  a=[[float(oldfeet[oi][k+'_toe_x']),float(oldfeet[oi][k+'_toe_y'])] for k in ['near','far']]
  b=[[float(newfeet[ni][k+'_tip_x']),float(newfeet[ni][k+'_tip_y'])] for k in ['near','far']]
  differences=[math.dist(x,z) for x,z in zip(a,b)]
  draw.text((440,y+80),'Foot differences at common phase:',font=font,fill='white')
  draw.text((440,y+108),f'near/far {differences[0]:.1f}/{differences[1]:.1f} canvas px',font=font,fill='white')
  draw.text((440,y+136),f'at game scale {differences[0]*.345:.1f}/{differences[1]*.345:.1f} px',font=font,fill='white')
  swapped=[math.dist(a[0],b[1]),math.dist(a[1],b[0])];best=min([differences,swapped],key=sum)
  draw.text((440,y+164),'Projected paint diagnostic; not world slip.',font=font,fill='white')
  pairs.append({'minimum_unordered_bootset_difference_game_px':[x*.345 for x in best],'global_phase':phase,'old_frame':oi,'new_frame':ni,'old_projected_tips':a,'new_projected_tips':b,'projected_difference_canvas_px':differences,'projected_difference_at_game_scale_px':[x*.345 for x in differences],'note':'Painted pose/recovery differences, not measured world ground-slip. Baseline gait has extra support; identical numeric phase is not identical contact.'})
 sheet.save(P/'sw_same_phase.png');(P/'sw_comparison.json').write_text(json.dumps(pairs,indent=2)+'\n')
 qa=json.loads((P/'technical_qa.json').read_text());qa.update(transition_visual='CANDIDATE_ONLY_WITH_VISIBLE_RESIDUAL; final game adoption not established',maximum_sampled_labelled_boot_difference_game_px=max(max(x['projected_difference_at_game_scale_px']) for x in pairs),maximum_sampled_unordered_bootset_difference_game_px=max(max(x['minimum_unordered_bootset_difference_game_px']) for x in pairs),comparison_note='Near/far labels and distances are2D diagnostics, not measured physical slip. Unordered boot-set comparison also leaves visible differences; producer/main-scene review is required.')
 (P/'technical_qa.json').write_text(json.dumps(qa,ensure_ascii=False,indent=2)+'\n')
 seam=Image.new('RGB',(1000,280),(65,65,65));draw=ImageDraw.Draw(seam)
 for k,i in enumerate([13,14,0,1,2]):
  im=pictures[new[i]['texture']];seam.paste(im,(k*200,28),im);draw.text((k*200+4,4),f'frame{i} source{i+30}',font=font,fill='white')
 seam.save(P/'last_first.png')
 def paint(canvas,im,rootx,rooty,scale):
  if scale==1:canvas.paste(im,(rootx-100,rooty-248),im);return
  tx=rootx-100*scale;ty=rooty-248*scale
  pic=im.convert('RGBa').transform(canvas.size,Image.Transform.AFFINE,(1/scale,0,-tx/scale,0,1/scale,-ty/scale),Image.Resampling.BICUBIC,fillcolor=(0,0,0,0)).convert('RGBA');canvas.paste(pic,(0,0),pic)
 # Source poses held according to measured timing on a60Hz display simulation;
 # no new character poses or endpoint frames are written to delivered assets.
 cmd=['ffmpeg','-v','error','-y','-f','rawvideo','-pixel_format','rgb24','-video_size','960x600','-framerate','60','-i','-','-c:v','libx264','-preset','fast','-crf','20','-pix_fmt','yuv420p','-an','-movflags','+faststart',str(P/'loop_transition_review.mp4')]
 proc=subprocess.Popen(cmd,stdin=subprocess.PIPE);records=[]
 for tick in range(240):
  t=tick/60;phase=(235*t/155)%1;oi,o=sample(old,oo,phase);ni,n=sample(new,no,phase);firing=(int(t/.44)%2)==1;selected=n if firing else o
  canvas=Image.new('RGB',(960,600),(60,60,60));draw=ImageDraw.Draw(canvas)
  draw.text((25,16),'GAME075 ART REVIEW - NOT ENGINE CAPTURE',font=font,fill='white');draw.text((25,42),f't={t:.3f}s / common distance phase={phase:.3f} / switch={"AIM" if firing else "CARRY"}',font=font,fill='white')
  for x,r,label in [(190,o,'SW17 ordinary'),(480,n,'SW15 aimed'),(770,selected,'Same-phase switch')]:
   draw.text((x-85,80),label,font=font,fill='white');paint(canvas,pictures[r['texture']],x,355,1)
   draw.line((x-9,355,x+9,355),fill='white');draw.line((x,348,x,362),fill='white')
   paint(canvas,pictures[r['texture']],x,545,.345);draw.line((x-5,545,x+5,545),fill='#bbbbbb')
  draw.text((25,395),'Bottom row: uniform 0.345 scale = 69 x 85.56; common pivot (100,248).',font=font,fill='white')
  draw.text((25,420),'Source frames30..44 /625ms; nominal660ms; distance cycle659.574468ms.',font=font,fill='white')
  draw.text((25,448),'Foot/body pose differences remain. This preview does not validate gameplay or physical contact.',font=font,fill='white')
  proc.stdin.write(canvas.tobytes());records.append({'frame':tick,'time_ms':t*1000,'global_phase':phase,'old_frame':oi,'new_frame':ni,'switched_clip':'run_fire_sw' if firing else 'run_sw'})
  if tick==16:canvas.save(P/'preview.png')
 proc.stdin.close();assert proc.wait()==0
 with (P/'preview_timing.csv').open('w',newline='') as f:w=csv.DictWriter(f,fieldnames=records[0],lineterminator='\n');w.writeheader();w.writerows(records)
 print(json.dumps({'review_frames':240,'gameplay':'NOT_RUN','new_frames':15,'max_sampled_projected_difference_game_px':max(max(x['projected_difference_at_game_scale_px']) for x in pairs)}))
if __name__=='__main__':main()
