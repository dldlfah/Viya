#!/usr/bin/env python3
"""Review-only comparison of extra GAME075 output; never connects game assets."""
import csv, json, math, subprocess
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFont

R = Path(__file__).resolve().parents[2]
D = R/'tools/higgsfield/requests/game075/evidence/candidate_03'
P = D/'review_rgba'; O = D/'review'

def main():
    cfg = json.loads((R/'data/viya_motion.json').read_text())['directions']['sw']
    rows = cfg['run']; old = [Image.open(R/x['texture'][6:]).convert('RGBA') for x in rows]
    files = sorted((P/'frames').glob('*.png')); new = [Image.open(x).convert('RGBA') for x in files]
    assert len(new) == 15
    # Search by lower-body alpha silhouette rather than infer anatomical feet
    # from overlapping painted boots. This is only a visual diagnostic.
    lower_old=np.array([np.asarray(x)[165:248,:,3]>128 for x in old])
    lower_new=np.array([np.asarray(x)[165:248,:,3]>128 for x in new])
    cost=np.zeros((len(old),len(new)))
    for i,a in enumerate(lower_old):
        for j,b in enumerate(lower_new):
            union=np.logical_or(a,b).sum();intersection=np.logical_and(a,b).sum()
            cost[i,j]=1-intersection/max(union,1)
    ends=np.cumsum([z['duration_ms']for z in rows]);phase=(np.arange(2040)+.5)/2040
    oi=np.minimum(np.searchsorted(ends,(phase+cfg['phase_origin'])%1*660),len(old)-1)
    def metrics(origin):
        ni=np.floor((phase+origin)%1*15).astype(int)
        return {'origin':origin,'mean_lower_body_IoU':float(1-cost[oi,ni].mean())}
    best=max((metrics(i/2040)for i in range(2040)),key=lambda x:x['mean_lower_body_IoU'])
    muzzles=[]
    for im in new:
        a=np.asarray(im);yy,xx=np.where(a[60:135,:55,3]>=192);left=xx.min()
        muzzles.append([float(left+.5),float(60+yy[xx==left].mean()+.5)])
    with (O/'review_muzzles.csv').open('w',newline='') as f:
        w=csv.writer(f,lineterminator='\n');w.writerow(['frame','source_frame','x','y'])
        for i,p in enumerate(muzzles):w.writerow([i,29+i,*p])
    report={'status':'REVIEW_ONLY_NOT_ACTIVE','trial_source_window':[29,44],'trial_source_ms':625,'trial_nominal_ms':660,'fixed_registration':{'scale':.2997601918465228,'translation':[3,-33.33333333333333],'root':[100,248]},'phase_search':best,'phase_search_note':'Lower-body silhouette IoU(y165:248) search over2040 phase offsets. Numeric diagnostic only; anatomical phase and gait adoption NOT established. No pose/registration is changed per frame.','game_connection':'NOT_RUN','producer_final':'NOT_VERIFIED'}
    (O/'comparison_analysis.json').write_text(json.dumps(report,indent=2)+'\n')
    sheet=Image.new('RGB',(1200,825),(60,60,60));draw=ImageDraw.Draw(sheet)
    for i,im in enumerate(new):
        x=i%6*200;y=i//6*275;sheet.paste(im,(x,y+22),im);draw.text((x+4,y+4),str(i),fill='white')
        p=muzzles[i];draw.ellipse((x+p[0]-2,y+22+p[1]-2,x+p[0]+2,y+22+p[1]+2),fill='cyan')
    sheet.save(O/'muzzle_review.png')
    font=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',16)
    def sample(t):
        ph=(235*t/155)%1;ii=int(np.searchsorted(ends,(ph+cfg['phase_origin'])%1*660));jj=int((ph+best['origin'])%1*15)
        return old[min(ii,16)],new[jj],ph
    def paint(canvas,im,x,y,s):
        tx=x-100*s;ty=y-248*s
        pic=im.convert('RGBa').transform(canvas.size,Image.Transform.AFFINE,(1/s,0,-tx/s,0,1/s,-ty/s),Image.Resampling.BICUBIC).convert('RGBA');canvas.paste(pic,(0,0),pic)
    cmd=['ffmpeg','-v','error','-y','-f','rawvideo','-pixel_format','rgb24','-video_size','960x600','-framerate','60','-i','-','-c:v','libx264','-preset','fast','-crf','20','-pix_fmt','yuv420p','-an','-movflags','+faststart',str(O/'extra_candidate_comparison.mp4')]
    proc=subprocess.Popen(cmd,stdin=subprocess.PIPE)
    for tick in range(240):
        t=tick/60;o,n,ph=sample(t);sw=n if int(t/.44)%2 else o
        canvas=Image.new('RGB',(960,600),(60,60,60));draw=ImageDraw.Draw(canvas)
        draw.text((20,12),'GAME075 EXTRA CANDIDATE03 - ART REVIEW, NOT ENGINE CAPTURE',font=font,fill='white')
        draw.text((20,40),f'phase={ph:.3f}; silhouette best phase only; physical contact NOT validated',font=font,fill='white')
        for x,im,label in [(190,o,'Approved SW17'),(480,n,'Extra aimed candidate'),(770,sw,'Same-phase switch')]:
            draw.text((x-95,82),label,font=font,fill='white');paint(canvas,im,x,355,1);paint(canvas,im,x,550,.345)
            draw.line((x-8,355,x+8,355),fill='white');draw.line((x-5,550,x+5,550),fill='white')
        draw.text((20,400),'Bottom row: actual 69 x 85.56 display; same root(100,248).',font=font,fill='white')
        draw.text((20,427),'Trial source29..43; native625ms; nominal660ms. Pose differences remain.',font=font,fill='white')
        draw.text((20,454),'Review plate only. No game assets/selection/code changed.',font=font,fill='white')
        proc.stdin.write(canvas.tobytes())
        if tick==32:canvas.save(O/'comparison_preview.png')
    proc.stdin.close();assert proc.wait()==0
    print(json.dumps(report))

if __name__=='__main__': main()
