#!/usr/bin/env python3
"""Decode native GAME070 video and ordered review sheets; never changes poses."""
from pathlib import Path
import argparse,csv,hashlib,json,subprocess
from PIL import Image,ImageDraw

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--video',type=Path,required=True)
    p.add_argument('--decoded',type=Path,required=True)
    p.add_argument('--review',type=Path,required=True)
    a=p.parse_args();a.decoded.mkdir(parents=True,exist_ok=True);a.review.mkdir(parents=True,exist_ok=True)
    subprocess.run(['ffmpeg','-v','error','-y','-i',str(a.video),'-fps_mode','passthrough',str(a.decoded/'%04d.png')],check=True)
    d=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_frames','-show_streams','-of','json',str(a.video)]))
    frames=[f for f in d['frames'] if f['media_type']=='video'];files=sorted(a.decoded.glob('*.png'))
    assert len(files)==len(frames)
    for start in range(0,len(files),25):
        out=Image.new('RGB',(1000,1350),'#444444');draw=ImageDraw.Draw(out)
        for k,f in enumerate(files[start:start+25]):
            im=Image.open(f).convert('RGB');im.thumbnail((200,248),Image.Resampling.LANCZOS)
            x=k%5*200;y=k//5*270;out.paste(im,(x+(200-im.width)//2,y+22+(248-im.height)//2))
            draw.text((x+3,y+3),f'source{start+k}',fill='white')
        out.save(a.review/f'all_source_{start:03d}.jpg',quality=82)
    rows=[]
    for i,f in enumerate(frames):
        pts=1000*float(f['best_effort_timestamp_time'])
        ms=1000*float(frames[i+1]['best_effort_timestamp_time'])-pts if i+1<len(frames) else 1000*float(f.get('duration_time',1/24))
        rows.append(dict(source_frame=i,source_pts_ms=pts,source_duration_ms=ms))
    with (a.review/'source_timing.csv').open('w',newline='') as f:
        w=csv.DictWriter(f,fieldnames=rows[0],lineterminator='\n');w.writeheader();w.writerows(rows)
    (a.review/'source_probe.json').write_text(json.dumps(dict(source_sha256=hashlib.sha256(a.video.read_bytes()).hexdigest(),streams=d['streams'],frame_count=len(frames),source_index_is_zero_based=True,game_timing='NOT_ASSIGNED_REJECTED'),indent=2)+'\n')
    print(json.dumps(dict(frames=len(frames),sha256=hashlib.sha256(a.video.read_bytes()).hexdigest())))
if __name__=='__main__':main()
