#!/usr/bin/env python3
"""Art-only S17 / S aimed18 comparison at shared distance phase, not game capture."""
from pathlib import Path
import bisect,csv,json,subprocess
from PIL import Image,ImageDraw,ImageFont


def main():
    root=Path(__file__).resolve().parents[2]
    delivery=root/'assets/characters/pilot_32/game069_s_run_fire'
    baseline=root/'assets/characters/pilot_32/game068_s_run'
    prov=delivery/'provenance'
    old=[Image.open(f).convert('RGBA') for f in sorted((baseline/'frames').glob('*.png'))]
    new=[Image.open(f).convert('RGBA') for f in sorted((delivery/'frames').glob('*.png'))]
    times=[list(csv.DictReader((p/'provenance/frame_timing.csv').open())) for p in [baseline,delivery]]
    starts=[[float(row['phase']) for row in rows] for rows in times]
    origins=[json.loads((p/'provenance/clip_metadata.json').read_text())['phase_origin'] for p in [baseline,delivery]]
    tmp=root/'.local_validation/GAME069/art_preview';tmp.mkdir(parents=True,exist_ok=True)
    font=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',14)
    for i in range(240):
        t=i/60;g=(t*235/155)%1
        oi,ni=[max(0,bisect.bisect_right(s,(g+o)%1)-1) for s,o in zip(starts,origins)]
        im=Image.new('RGB',(1000,520),(48,48,48));d=ImageDraw.Draw(im)
        d.text((15,8),'ART REVIEW ONLY - not main.tscn / not FPS evidence',font=font,fill='white')
        for pic,x,txt in [(old[oi],20,f'Current S17 carry / {oi}'),(new[ni],300,f'GAME069 S aimed18 / {ni}')]:
            d.text((x,38),txt,font=font,fill='white')
            large=pic.resize((260,322),Image.Resampling.LANCZOS);im.paste(large,(x,65),large)
        d.text((615,50),'69 x 85.56 target (86px raster)',font=font,fill='white')
        for pic,x,txt in [(old[oi],640,'S17'),(new[ni],760,'aimed18')]:
            small=pic.resize((69,86),Image.Resampling.LANCZOS);im.paste(small,(x,90),small);d.text((x,190),txt,font=font,fill='white')
        aimed=int(t/.33)%2==1;switch=new[ni] if aimed else old[oi]
        small=switch.resize((69,86),Image.Resampling.LANCZOS);im.paste(small,(700,280),small)
        d.text((615,246),f'Same-phase switch: {"AIM" if aimed else "CARRY"}',font=font,fill='white')
        d.text((15,408),f't={t:.3f}s | global distance phase={g:.4f} | speed235 / stride155',font=font,fill='white')
        d.text((15,436),'Independent opposite-foot stance alignment; painted toe positions differ.',font=font,fill='white')
        d.text((15,463),'Upper-body carry/aim silhouette changes visibly. Actual game transitions remain unverified.',font=font,fill='white')
        d.text((15,490),'Fixed registration; native consecutive source frames only; no endpoint copy / pose interpolation.',font=font,fill='white')
        im.save(tmp/f'{i:04d}.png')
    subprocess.run(['ffmpeg','-v','error','-y','-framerate','60','-i',str(tmp/'%04d.png'),'-c:v','libx264','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',str(prov/'art_review.mp4')],check=True)
    Image.open(tmp/'0000.png').save(prov/'comparison_at_phase0.png')
    Image.open(tmp/'0120.png').save(prov/'comparison_at_2s.png')
    anchors=json.loads((prov/'phase_alignment.json').read_text())['anchors']
    sheet=Image.new('RGB',(800,570),'#444444');d=ImageDraw.Draw(sheet)
    for row,a in enumerate(anchors):
        oi=a['current_s17_frame'];ni=a['new_frame']
        for col,(pic,txt) in enumerate([(old[oi],f'S17 frame{oi}'),(new[ni],f'aimed18 frame{ni}')]):
            x=col*200;y=row*285;sheet.paste(pic,(x,y+28),pic);d.text((x+3,y+8),txt,fill='white')
        d.text((410,row*285+50),a['stance'],fill='white')
        d.text((410,row*285+80),'Compare support/recovery order, not pixel alignment.',fill='white')
    sheet.save(prov/'opposite_stance_comparison.png')
    print(prov/'art_review.mp4')


if __name__=='__main__':main()
