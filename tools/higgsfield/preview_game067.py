#!/usr/bin/env python3
"""Render registered art at shared distance phase; this is NOT a game capture."""
from pathlib import Path
import argparse, bisect, csv, json, subprocess
from PIL import Image, ImageDraw, ImageFont


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--delivery',type=Path,required=True)
    p.add_argument('--output',type=Path,required=True)
    a=p.parse_args();root=Path(__file__).resolve().parents[2]
    frames=[Image.open(f).convert('RGBA') for f in sorted((a.delivery/'frames').glob('*.png'))]
    base=[Image.open(f).convert('RGBA') for f in sorted((root/'assets/characters/pilot_32/game066_se_run/frames').glob('*.png'))]
    timing=list(csv.DictReader((a.delivery/'provenance/frame_timing.csv').open()))
    starts=[float(r['phase']) for r in timing]
    phase=json.loads((a.delivery/'provenance/phase_alignment.json').read_text())
    old_origin=phase['baseline_origin'];new_origin=phase['recommended_run_fire_phase_origin']
    temp=root/'.local_validation/GAME067/preview';temp.mkdir(parents=True,exist_ok=True)
    font=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',15)
    for i in range(240):
        t=i/60;g=(t*235/155)%1
        bi=int(((g+old_origin)%1)*18)
        ni=max(0,bisect.bisect_right(starts,(g+new_origin)%1)-1)
        im=Image.new('RGB',(896,496),(44,44,44));d=ImageDraw.Draw(im)
        d.text((20,8),'ART REVIEW ONLY - shared distance phase; not a game capture',font=font,fill='white')
        d.text((30,40),'Current SE18 run',font=font,fill='white')
        d.text((355,40),'GAME067 candidate',font=font,fill='white')
        d.text((704,195),'69 x 85.56',font=font,fill='white')
        d.text((704,215),'same-phase switch',font=font,fill='white')
        for pic,pos in [(base[bi],(30,62)),(frames[ni],(355,62))]:
            resized=pic.resize((300,372),Image.Resampling.LANCZOS);im.paste(resized,pos,resized)
        on=(int(t/.33)%2)==1;small=(frames[ni] if on else base[bi]).resize((69,86),Image.Resampling.LANCZOS)
        im.paste(small,(755,265),small)
        d.text((727,360),'aim ON' if on else 'aim OFF',font=font,fill='white')
        d.text((30,451),f'run {bi} | new {ni} | t={t:.3f}s | speed235 / stride155',font=font,fill='white')
        d.line((20,434,675,434),fill=(90,90,90),width=1)
        im.save(temp/f'{i:04d}.png')
    a.output.parent.mkdir(parents=True,exist_ok=True)
    subprocess.run(['ffmpeg','-v','error','-y','-framerate','60','-i',str(temp/'%04d.png'),
         '-c:v','libx264','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',str(a.output)],check=True)
    print(str(a.output))


if __name__=='__main__':main()
