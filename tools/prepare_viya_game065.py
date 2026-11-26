#!/usr/bin/env python3
"""Prepare GAME065 RGBA from the preserved RGB master; no anatomical edits.

Uses a verified clear left-edge key, same-frame metal foreground constraints,
external flare exclusion, weak detached background removal, and ONE clip-wide
transform. No anatomy is drawn, copied, assembled or warped.
Source sampling is an input, not an automatic claim of gait compatibility.
"""
from pathlib import Path
import argparse, hashlib, json
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy.ndimage import distance_transform_edt, median_filter, label, binary_dilation, binary_propagation

FOREGROUND_REGIONS={}

def chroma_matte(im,source_frame):
 rgb=np.asarray(im.convert('RGB'),dtype=np.float32)
 h,w=rgb.shape[:2]
 assert (w,h)==(720,1280), 'This measured matte is for the inspected 720x1280 master only'
 yy,xx=np.indices((h,w))
 rr,gg,bb=rgb[...,0],rgb[...,1],rgb[...,2]
 warm=(xx>=690)&(yy>=320)&(yy<500)&(((rr>145)&(gg>130)&(bb<150)&(rr-bb>40))|((rr>220)&(gg>190)&(bb<240)&(rr-bb>20)))
 effect_labels,effect_count=label(warm,np.ones((3,3)))
 effects=np.zeros((h,w),dtype=bool)
 for component in range(1,effect_count+1):
  region=effect_labels==component
  if region.sum()>=40 and region[:,-1].any():effects|=region
 white_hot=(xx>=690)&(yy>=320)&(yy<500)&(rr>235)&(gg>215)&(bb>170)
 effects=binary_propagation(effects,mask=(warm|white_hot))
 effect_guard=binary_dilation(effects,iterations=1)
 # Same-frame observed metal is foreground, including pink highlights lit
 # by the unwanted flare. Protect it only from FX deletion; ordinary chroma
 # still determines alpha. No pixel/part from another frame is inserted.
 polygon=FOREGROUND_REGIONS.get(str(source_frame))
 if polygon:
  support=Image.new('1',(w,h))
  ImageDraw.Draw(support).polygon([tuple(point) for point in polygon],fill=1)
  effect_guard&=~np.asarray(support,dtype=bool)
 left=median_filter(np.median(rgb[:,:16],axis=1),size=(15,1))
 assert (rgb[:,:16,1]-np.maximum(rgb[:,:16,0],rgb[:,:16,2])).min()>20, 'Left background sample overlaps foreground'
 # The raised muzzle reaches the right-edge sampling strip. It is NOT a
 # background reference, especially on flash rows. The inspected left strip
 # stays entirely green; use it across this uniform-background source.
 right=left.copy()
 blend=np.linspace(0,1,w,dtype=np.float32)[None,:,None]
 bg=left[:,None,:]*(1-blend)+right[:,None,:]*blend
 dominance=rgb[...,1]-np.maximum(rgb[...,0],rgb[...,2])
 bg_dominance=bg[...,1]-np.maximum(bg[...,0],bg[...,2])
 rough=dominance<0.50*bg_dominance
 inside=distance_transform_edt(rough)
 # Exclude green-contaminated/neutral fringe colors from the opaque reference.
 neutral_weapon=(xx>=540)&(yy>=320)&(yy<500)&(dominance<12)&(inside>3)
 core=(((dominance<-12)&(inside>4))|neutral_weapon)&(~effect_guard)
 distance,indices=distance_transform_edt(~core,return_indices=True)
 nearest=rgb[indices[0],indices[1]]
 v=nearest-bg
 alpha=np.sum((rgb-bg)*v,axis=-1)/np.maximum(np.sum(v*v,axis=-1),1)
 alpha=np.clip(alpha,0,1)
 alpha[core]=1
 alpha[effect_guard]=0
 background=(np.linalg.norm(rgb-bg,axis=-1)<8)|((distance>30)&(dominance>0.5*bg_dominance))
 background|=(dominance>0.85*bg_dominance)&(alpha<0.18)
 # VIYA's reference palette contains no green paint. This also removes
 # darker green inside loose hair loops that differs from the flat edge key.
 background|=dominance>20
 alpha[background]=0
 alpha[(dominance>0.50*bg_dominance)&(alpha<0.25)]=0
 alpha[alpha<0.07]=0
 components,count=label(alpha>0,np.ones((3,3)))
 if count:
  sizes=np.bincount(components.ravel());main=np.argmax(sizes[1:])+1
  for component in range(1,count+1):
   region=components==component
   ry,rx=np.where(region)
   small_external=(rx.min()>=690 and ry.min()>=320 and ry.max()<500 and region.sum()<40)
   if component!=main and (alpha[region].max()<0.38 or small_external):alpha[region]=0
 partial=(alpha>0)&(alpha<0.999)
 out=rgb.copy()
 # Reconstruct mixed-edge color from nearby uncontaminated opaque paint.
 out[partial]=nearest[partial]
 # Chroma cleanup only at the new video's alpha boundary, not on source artwork.
 boundary=(alpha>0)&(inside<10)
 neutral_green=.80*out[...,0]+.20*out[...,2]
 out[...,1][boundary]=np.minimum(out[...,1][boundary],neutral_green[boundary])
 out[alpha==0]=0
 rgba=np.dstack((np.clip(out,0,255),alpha*255)).round().astype(np.uint8)
 return Image.fromarray(rgba),{'estimated_key_rgb':np.median(bg.reshape(-1,3),axis=0).tolist(),'excluded_external_effect_pixels':int(effect_guard.sum()),'foreground_preservation_polygon':polygon}

def registered(im,factor):
 s,tx,ty=SCALE*factor,TX*factor,TY*factor
 out=im.convert('RGBa').transform((200*factor,248*factor),Image.Transform.AFFINE,
   (1/s,0,-tx/s,0,1/s,-ty/s),Image.Resampling.BICUBIC,fillcolor=(0,0,0,0)).convert('RGBA')
 # Clamp rare green overshoot introduced by unpremultiplying resampled edges.
 a=np.asarray(out).copy();g=a[...,1].astype(float)
 edge=(a[...,3]>0)&(a[...,3]<250)&(g>np.maximum(a[...,0],a[...,2]).astype(float)+10)
 a[...,1][edge]=(.8*a[...,0][edge]+.2*a[...,2][edge]).round().astype(np.uint8)
 a[a[...,3]==0]=0
 return Image.fromarray(a)

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--decoded',type=Path,required=True)
    p.add_argument('--source-map',type=Path,required=True)
    p.add_argument('--out',type=Path,required=True)
    p.add_argument('--scale',type=float,default=242/922)
    p.add_argument('--tx',type=float,default=100-334*242/922)
    p.add_argument('--ty',type=float,default=4-192*242/922)
    a=p.parse_args()
    mapping=json.loads(a.source_map.read_text())
    indices=mapping['source_frames']
    assert indices and len(indices)==len(set(indices))
    global SCALE,TX,TY,FOREGROUND_REGIONS
    SCALE,TX,TY=a.scale,a.tx,a.ty
    FOREGROUND_REGIONS=mapping.get('foreground_preservation_regions',{})
    env={'chroma_matte':chroma_matte,'registered':registered}
    source=Path(__file__)
    for d in ('frames_200x248','frames_400x496','rgba_native','previews'):(a.out/d).mkdir(parents=True,exist_ok=True)
    frames=[];checks=[]
    for i,src in enumerate(indices):
        rgba,bg=env['chroma_matte'](Image.open(a.decoded/f'frame_{src+1:03d}.png'),src)
        rgba.save(a.out/'rgba_native'/f'frame_{src:03d}.png')
        im=env['registered'](rgba,1);large=env['registered'](rgba,2)
        name=f'viya_run_fire_e_{i:03d}.png';path=a.out/'frames_200x248'/name
        im.save(path);large.save(a.out/'frames_400x496'/name)
        arr=np.asarray(im).astype(int);alpha=arr[...,3]
        checks.append({'index':i,'source_frame':src,'filename':name,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'native_bbox':rgba.getchannel('A').getbbox(),'bbox':im.getchannel('A').getbbox(),'alpha_range':[int(alpha.min()),int(alpha.max())],'partial_alpha_pixels':int(((alpha>0)&(alpha<255)).sum()),'border_alpha_max':int(max(alpha[0].max(),alpha[-1].max(),alpha[:,0].max(),alpha[:,-1].max())),'green_excess_pixels':int(((arr[...,1]-np.maximum(arr[...,0],arr[...,2])>30)&(alpha>20)).sum()),'matte_details':bg})
        frames.append(im)
    font=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',14)
    sheet=Image.new('RGB',(8*200,((len(frames)+7)//8)*276),(31,37,47));draw=ImageDraw.Draw(sheet)
    for i,im in enumerate(frames):
        x=i%8*200;y=i//8*276
        sheet.paste(im,(x,y+28),im);draw.text((x+5,y+5),f'{i:02d} / source {indices[i]:02d}',font=font,fill=(235,238,243))
    sheet.save(a.out/'previews/contact_sheet.jpg',quality=94)
    sample=sorted(set([0,len(frames)//6,len(frames)//3,len(frames)//2,2*len(frames)//3,5*len(frames)//6,len(frames)-1]))
    sheet=Image.new('RGB',(len(sample)*200,3*276));draw=ImageDraw.Draw(sheet)
    for row,bg in enumerate([(18,22,30),(119,119,119),(238,238,238)]):
        for col,i in enumerate(sample):
            x=col*200;y=row*276;sheet.paste(bg,(x,y,x+200,y+276));sheet.paste(frames[i],(x,y+28),frames[i]);draw.text((x+5,y+5),f'{i:02d}',font=font,fill=(235,238,243) if row<2 else (25,25,25))
    sheet.save(a.out/'previews/alpha_review.jpg',quality=94)
    meta={'status':'PREPARED_FOR_REVIEW_NOT_APPROVED','source_sampling':mapping,'registration':{'scale':a.scale,'translation':[a.tx,a.ty],'canvas':[200,248],'pivot':[100,248],'fixed_transform':True},'alpha_method_source':str(source),'bitmap_checks':checks,'summary':{'count':len(frames),'unique':len({c['sha256'] for c in checks}),'max_border_alpha':max(c['border_alpha_max'] for c in checks),'total_green_excess_pixels':sum(c['green_excess_pixels'] for c in checks)}}
    (a.out/'frame_preparation.json').write_text(json.dumps(meta,indent=2)+'\n')
    print(json.dumps(meta['summary']))

if __name__=='__main__':main()
