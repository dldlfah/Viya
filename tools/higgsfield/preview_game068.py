#!/usr/bin/env python3
"""Art-only S11/S17/SE18 comparison at shared distance phase; no game capture."""
from pathlib import Path
import argparse,bisect,csv,json,subprocess
from PIL import Image,ImageDraw,ImageFont


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--delivery',type=Path,required=True)
    p.add_argument('--output',type=Path,required=True)
    a=p.parse_args();root=Path(__file__).resolve().parents[2]
    old=[Image.open(root/'assets/characters/pilot_32/render_cache'/f'viya_run_s_{i:02d}.png').convert('RGBA') for i in range(11)]
    new=[Image.open(f).convert('RGBA') for f in sorted((a.delivery/'frames').glob('*.png'))]
    se=[Image.open(f).convert('RGBA') for f in sorted((root/'assets/characters/pilot_32/game066_se_run/frames').glob('*.png'))]
    times=list(csv.DictReader((a.delivery/'provenance/frame_timing.csv').open()))
    starts=[float(t['phase']) for t in times]
    phase=json.loads((a.delivery/'provenance/phase_alignment.json').read_text())
    origin=phase['recommended_phase_origin'];old_origin=phase['baseline_origin']
    se_origin=json.loads((root/'data/viya_motion.json').read_text())['directions']['se']['phase_origin']
    tmp=root/'.local_validation/GAME068/art_preview';tmp.mkdir(parents=True,exist_ok=True)
    font=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',14)
    for i in range(240):
        t=i/60;g=(t*235/155)%1
        oi=int(((g+old_origin)%1)*11);ni=max(0,bisect.bisect_right(starts,(g+origin)%1)-1);si=int(((g+se_origin)%1)*18)
        im=Image.new('RGB',(1100,520),(48,48,48));d=ImageDraw.Draw(im)
        d.text((15,8),'ART REVIEW ONLY - not main.tscn / not FPS evidence',font=font,fill='white')
        for pic,x,label in [(old[oi],12,f'Original S11 / {oi}'),(new[ni],280,f'GAME068 S17 / {ni}'),(se[si],548,f'Existing SE18 / {si}')]:
            d.text((x,38),label,font=font,fill='white');scaled=pic.resize((260,322),Image.Resampling.LANCZOS);im.paste(scaled,(x,65),scaled)
        d.text((828,65),'69 x 85.56 target',font=font,fill='white')
        d.text((828,87),'(86px raster)',font=font,fill='white')
        for pic,x,label in [(old[oi],830,'old S'),(new[ni],920,'new S'),(se[si],1010,'SE')]:
            small=pic.resize((69,86),Image.Resampling.LANCZOS);im.paste(small,(x,140),small);d.text((x,240),label,font=font,fill='white')
        switch=new[ni] if int(t/.33)%2==0 else se[si]
        small=switch.resize((69,86),Image.Resampling.LANCZOS);im.paste(small,(925,310),small)
        d.text((838,414),'SE/S same-phase switch',font=font,fill='white')
        d.text((15,438),f't={t:.3f}s | global distance phase={g:.4f} | speed235 / stride155',font=font,fill='white')
        d.text((15,464),'SE uses its existing phase. Painted foot extents differ; physical zero-slip is not established.',font=font,fill='white')
        d.text((15,490),'One fixed registration; native source frames only; no endpoint copy / temporal pose interpolation.',font=font,fill='white')
        im.save(tmp/f'{i:04d}.png')
    subprocess.run(['ffmpeg','-v','error','-y','-framerate','60','-i',str(tmp/'%04d.png'),'-c:v','libx264','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',str(a.output)],check=True)
    Image.open(tmp/'0000.png').save(a.delivery/'provenance/comparison_at_phase0.png')
    Image.open(tmp/'0120.png').save(a.delivery/'provenance/comparison_at_2s.png')
    print(a.output)


if __name__=='__main__':main()
