#!/usr/bin/env python3
"""Display accepted SW timing/registration and S17 comparison; not a game run."""
from pathlib import Path
import csv,json,math
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[2];D=ROOT/'assets/characters/pilot_32/game070_sw_run';P=D/'provenance'
def main():
 cfg=json.loads((ROOT/'data/viya_motion.json').read_text());meta=json.loads((P/'clip_metadata.json').read_text())
 cfg['directions']['sw']={'phase_origin':meta['phase_origin'],'run':meta['frames']}
 sf=list(csv.DictReader((ROOT/'assets/characters/pilot_32/game068_s_run/provenance/foot_landmarks.csv').open()));wf=list(csv.DictReader((P/'foot_landmarks.csv').open()))
 pairs=[];sheet=Image.new('RGB',(800,8*280),(60,60,60));draw=ImageDraw.Draw(sheet)
 def sample(direction,phase):
  row=cfg['directions'][direction];target=(phase+row['phase_origin'])%1*660;at=0
  for i,f in enumerate(row['run']):
   at+=f['duration_ms']
   if target<at:return i,f
  return len(row['run'])-1,row['run'][-1]
 for j,phase in enumerate([0,.125,.25,.375,.5,.625,.75,.875]):
  si,s=sample('s',phase);wi,w=sample('sw',phase);y=j*280
  draw.text((5,y+3),f'global phase {phase:.3f} / S{si} - SW{wi}',fill='white')
  for x,f in [(0,s),(200,w)]:
   im=Image.open(ROOT/f['texture'][6:]);sheet.paste(im,(x,y+24),im)
   small=im.resize((69,86),Image.Resampling.LANCZOS);sheet.paste(small,(450+x//2,y+85),small)
  sfoot=[[float(sf[si][k+'_tip_x']),float(sf[si][k+'_tip_y'])] for k in ['screen_left','screen_right']]
  wfoot=[[float(wf[wi][k+'_toe_x']),float(wf[wi][k+'_toe_y'])] for k in ['near','far']]
  pairs.append(dict(global_phase=phase,s_frame=si,sw_frame=wi,s_projected_toes=sfoot,sw_projected_toes=wfoot,projected_pair_distance_canvas_px=[math.dist(a,b) for a,b in zip(sfoot,wfoot)],note='Different camera projections; distances are screen-space differences, not world foot-slip.'))
 sheet.save(P/'s_sw_same_phase.png');(P/'s_sw_comparison.json').write_text(json.dumps(pairs,indent=2)+'\n')
 images=[Image.open(f) for f in sorted((D/'frames').glob('*.png'))]
 seam=Image.new('RGB',(800,275),(65,65,65));draw=ImageDraw.Draw(seam)
 for x,i in enumerate([15,16,0,1]):seam.paste(images[i],(x*200,23),images[i]);draw.text((x*200+5,3),f'frame{i} source{i+34}',fill='white')
 seam.save(P/'last_first.png')
 # A timing-accurate local animation at24fps source output rescaled only in
 # playback to nominal660ms. This is a processed-art preview, not main.tscn.
 frames=[]
 for tick in range(160):
  phase=(tick/60/.660)%1;_,row=sample('sw',(phase-meta['phase_origin'])%1)
  im=Image.open(ROOT/row['texture'][6:]);canvas=Image.new('RGB',(400,300),(85,85,85));canvas.paste(im,(30,20),im);canvas.paste(im.resize((69,86),Image.Resampling.LANCZOS),(285,170),im.resize((69,86),Image.Resampling.LANCZOS));frames.append(canvas)
 frames[0].save(P/'loop_preview.gif',save_all=True,append_images=frames[1:],duration=[17,17,16]*53+[17],loop=0,optimize=True)
 print('Created same-phase, projected-foot difference, seam and art-only loop previews')
if __name__=='__main__':main()
