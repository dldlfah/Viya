"""CPU surface-color bake in the head's own UV chart. Source pictures stay unchanged.

Curves are locally authored material features anchored to the actual mesh loops;
this is not a photograph projected across the complete head or an AI restoration.
"""
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image
from scipy.ndimage import distance_transform_edt

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[5]
EXCHANGE=ROOT/".local_validation/PLAN_B03_04"
TEXTURES=HERE/"textures"
SOURCE=ROOT/"assets/characters/plan_b_viya/candidate_03/references/front.png"


def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()


def raster(obj,size):
    positions=np.asarray(obj["positions"],np.float32)
    atlas=np.full((size,size,3),np.nan,np.float32);hits=np.zeros((size,size),np.uint16)
    areas=[];zero=0
    for ids,uv in zip(obj["triangles"],obj["triangle_uv"]):
        xyz=positions[ids];q=np.asarray(uv,float);q[:,0]*=size;q[:,1]=(1-q[:,1])*size
        a0=q[1]-q[0];b0=q[2]-q[0];det=a0[0]*b0[1]-a0[1]*b0[0]
        if abs(det)<1e-9:zero+=1;continue
        surf=np.linalg.norm(np.cross(xyz[1]-xyz[0],xyz[2]-xyz[0]))/2
        if surf>1e-12:areas.append((abs(det)/2,surf))
        lo=np.maximum(np.floor(q.min(0)).astype(int),0);hi=np.minimum(np.ceil(q.max(0)).astype(int),size-1)
        if np.any(hi<lo):continue
        x,y=np.meshgrid(np.arange(lo[0],hi[0]+1)+.5,np.arange(lo[1],hi[1]+1)+.5)
        p=np.stack([x,y],-1)-q[0]
        b=(p[...,0]*(q[2,1]-q[0,1])-p[...,1]*(q[2,0]-q[0,0]))/det
        c=((q[1,0]-q[0,0])*p[...,1]-(q[1,1]-q[0,1])*p[...,0])/det;a=1-b-c
        inside=(a>=-1e-8)&(b>=-1e-8)&(c>=-1e-8)
        if not inside.any():continue
        block=atlas[lo[1]:hi[1]+1,lo[0]:hi[0]+1];block[inside]=(a[...,None]*xyz[0]+b[...,None]*xyz[1]+c[...,None]*xyz[2])[inside]
        counts=hits[lo[1]:hi[1]+1,lo[0]:hi[0]+1];counts[inside]+=1
    densities=np.sqrt(np.asarray(areas)[:,0]/np.asarray(areas)[:,1])
    return atlas,hits,{"resolution":[size,size],"raster_covered_pixels":int((hits>0).sum()),"multiple_hit_pixels":int((hits>1).sum()),"zero_area_uv_triangles":zero,"texels_per_working_m_p10_median_p90":np.percentile(densities,[10,50,90]).tolist()}


def split_paths(q):
    q=np.asarray(q,float);start=np.argmin(q[:,0]);q=np.roll(q,-start,axis=0);end=np.argmax(q[:,0])
    a=q[:end+1];b=np.vstack([q[end:],q[:1]])[::-1]
    return (a,b) if a[:,2].mean()>b[:,2].mean() else (b,a)


def curve(points,steps=6):
    p=np.asarray(points,float);result=[]
    for i in range(len(p)-1):
        a=p[max(0,i-1)];b=p[i];c=p[i+1];d=p[min(len(p)-1,i+2)]
        for t in np.linspace(0,1,steps,endpoint=False):result.append(.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t**3))
    return np.vstack([result,p[-1]])


def distance(xz,line):
    line=np.asarray(line)[:,[0,2]];best=np.full(len(xz),np.inf,np.float32)
    for a,b in zip(line,line[1:]):
        v=b-a;den=v@v
        if den<1e-15:continue
        t=np.clip(((xz-a)*v).sum(1)/den,0,1)
        best=np.minimum(best,np.linalg.norm(xz-(a+t[:,None]*v),axis=1))
    return best


def distance_parameter(xz,line):
    line=np.asarray(line)[:,[0,2]];best=np.full(len(xz),np.inf,np.float32);where=np.zeros(len(xz))
    for i,(a,b) in enumerate(zip(line,line[1:])):
        v=b-a;den=v@v
        if den<1e-15:continue
        t=np.clip(((xz-a)*v).sum(1)/den,0,1);d=np.linalg.norm(xz-(a+t[:,None]*v),axis=1);use=d<best
        best[use]=d[use];where[use]=(i+t[use])/(len(line)-1)
    return best,where


def blend(colors,color,weight):
    w=np.clip(weight,0,1)[:,None];colors[:]=colors*(1-w)+np.asarray(color)*w


def color_head(atlas,hits,features,palette):
    valid=hits>0;ps=atlas[valid];colors=np.tile(palette["skin"],(len(ps),1)).astype(float)
    # Mild authored skin gradients; no baked camera lighting, cast shadow or hair.
    front=np.clip((-ps[:,1]-.02)/.045,0,1)
    for side in [-1,1]:
        cheek=np.exp(-.5*((ps[:,0]-side*.043)/.018)**2-.5*((ps[:,2]-.088)/.016)**2)*front
        blend(colors,palette["blush"],.16*cheek)
    mask=(abs(ps[:,0])<.072)&(ps[:,1]<-.035)&(ps[:,2]>.045)&(ps[:,2]<.158)
    face=colors[mask].copy();q=ps[mask];xz=q[:,[0,2]];front_mask=np.clip((-q[:,1]-.035)/.025,0,1)
    for side in ["eye_left","eye_right"]:
        upper,lower=split_paths(features[side]);upper=curve(upper);lower=curve(lower)
        du=distance(xz,upper);dl=distance(xz,lower)
        blend(face,palette["eye_wash"],.22*np.exp(-.5*(du/.0033)**2)*front_mask)
        blend(face,palette["liner"],np.clip((.00150-du)/.00055,0,1)*front_mask)
        blend(face,palette["lower_lid"],.75*np.clip((.00055-dl)/.00032,0,1)*front_mask)
    brows=[np.array([[-.058,-.075,.129],[-.048,-.08,.132],[-.036,-.082,.1335],[-.023,-.084,.1295]]),np.array([[.020,-.084,.1285],[.033,-.082,.134],[.047,-.08,.135],[.059,-.075,.132]])]
    for i,b in enumerate(brows):
        d,t=distance_parameter(xz,curve(b));tail=t if i==0 else 1-t;width=.00160*(.30+.70*tail**.6)
        blend(face,palette["brow"],np.clip((width-d)/.0004,0,1)*front_mask)
    top,bottom=split_paths(features["mouth_lip_edge"])
    mids=[]
    for p in top:
        other=bottom[np.argmin(abs(bottom[:,0]-p[0]))];mids.append((p+other)/2)
    mouth=curve(mids);dm=distance(xz,mouth)
    blend(face,palette["lip_tint"],.50*np.exp(-.5*(dm/.0021)**2)*front_mask)
    blend(face,palette["mouth_line"],.95*np.clip((.00090-dm)/.00035,0,1)*front_mask)
    colors[mask]=face
    output=np.tile(np.asarray(palette["skin"],np.uint8),(atlas.shape[0],atlas.shape[1],1));output[valid]=np.clip(colors,0,255).astype(np.uint8)
    #8px nearest-texel gutter prevents empty-atlas bleeding; no new source detail.
    dist,indices=distance_transform_edt(~valid,return_indices=True);gutter=(~valid)&(dist<=16)
    output[gutter]=output[indices[0][gutter],indices[1][gutter]]
    face_pixels=int(((atlas[:,:,1]<-.035)&(abs(atlas[:,:,0])<.065)&(atlas[:,:,2]>.045)&(atlas[:,:,2]<.155)&valid).sum())
    return output,{"face_region_pixels":face_pixels,"gutter_pixels":int(gutter.sum()),"method":"Locally authored surface palette and loop-bound line curves, baked through nonplanar unwrapped head UV. No whole-front photo projection."}


def source_sample(im,x,y):return np.median(im[y-1:y+2,x-1:x+2],axis=(0,1)).tolist()


def eye_texture(im,center,record,size=256):
    u=(np.arange(size)+.5)/size;v=1-(np.arange(size)+.5)/size;uu,vv=np.meshgrid(u,v)
    lon=(uu-.5)*2*np.pi;lat=(vv-.5)*np.pi
    rx,_,rz=record["radius"];iris_radius=.0068
    sx=np.sin(lon)*np.cos(lat)*rx/iris_radius;sy=np.sin(lat)*rz/iris_radius
    rr=np.sqrt(sx*sx+sy*sy);mask=(rr<1)&(np.cos(lon)>0)
    x=np.clip(center[0]+sx*5.5,center[0]-6,center[0]+6);y=np.clip(center[1]-sy*5.5,center[1]-6,center[1]+6)
    x0=np.floor(x).astype(int);y0=np.floor(y).astype(int);tx=(x-x0)[...,None];ty=(y-y0)[...,None]
    sampled=(im[y0,x0]*(1-tx)+im[y0,x0+1]*tx)*(1-ty)+(im[y0+1,x0]*(1-tx)+im[y0+1,x0+1]*tx)*ty
    base=np.tile([247.,226.,211.],(size,size,1));base[mask]=sampled[mask]
    edge=(rr>.88)&mask;w=np.clip((rr-.88)/.12,0,1)[...,None]*.55
    darker=np.asarray([74.,27.,24.]);base[edge]=(base*(1-w)+darker*w)[edge]
    return np.clip(base,0,255).astype(np.uint8)


def main():
    TEXTURES.mkdir(exist_ok=True)
    data=json.loads((EXCHANGE/"bake_mesh.json").read_text());im=np.asarray(Image.open(SOURCE).convert("RGB"),float)
    refs=json.loads((HERE.parent/"face_reference_v1/face_landmarks.json").read_text())["references"]
    for r in refs:assert sha(ROOT/r["path"])==r["sha256"]
    samples={name:{"source_xy":[x,y],"median3x3_rgb":source_sample(im,x,y)} for name,x,y in [("skin",793,211),("brow",815,148),("upper_liner",810,167),("lip_tint",775,230),("lip_line",780,227)]}
    palette={"skin":samples["skin"]["median3x3_rgb"],"brow":samples["brow"]["median3x3_rgb"],"liner":samples["upper_liner"]["median3x3_rgb"],"mouth_line":[124,61,54],"lip_tint":samples["lip_tint"]["median3x3_rgb"],"blush":[236,159,155],"eye_wash":[184,111,104],"lower_lid":[152,76,72]}
    skin=data["objects"]["CC0_head_skin_UNAPPROVED"]
    atlas,hits,uv_stats=raster(skin,2048);colors,paint_stats=color_head(atlas,hits,data["features"],palette)
    Image.fromarray(colors).resize((1024,1024),Image.Resampling.LANCZOS).save(TEXTURES/"head_color.png")
    uv_stats["sampling_resolution"]=uv_stats.pop("resolution");uv_stats["output_resolution"]=[1024,1024]
    uv_stats["output_texels_per_working_m_p10_median_p90"]=[x/2 for x in uv_stats.pop("texels_per_working_m_p10_median_p90")]
    uv_stats["output_covered_pixels"]=int((hits.reshape(1024,2,1024,2).max(axis=(1,3))>0).sum())
    paint_stats["raster_sampling"]="2x surface-color supersampling then1024 output; no source detail restoration or service upscale"
    for key,center,name in [("CC0_helper-l-eye_UNAPPROVED",[809,174],"eye_screen_right.png"),("CC0_helper-r-eye_UNAPPROVED",[727,182],"eye_screen_left.png")]:
        result=eye_texture(im,center,data["objects"][key]["uv_record"]);Image.fromarray(result).save(TEXTURES/name)
    report={"references":[{"id":r["id"],"path":r["path"],"sha256":r["sha256"],"face_crop_size_px":[r["inspection_crop_xyxy"][2]-r["inspection_crop_xyxy"][0],r["inspection_crop_xyxy"][3]-r["inspection_crop_xyxy"][1]]} for r in refs],"visible_front_face_inspection_px":[160,125],"front_iris_source_windows_px":[13,13],"new_source_detail_recovered":False,"source_iris_resampled_into_eye_atlas":True,"service_upscale":False,"source_palette_samples":samples,"authored_palette":palette,"authored_line_method":"Existing mesh-loop anchored eye/mouth curves; separate reference-informed tapered brow curves. The partially hidden brow is an authored assumption. New surface paint, not claimed as unchanged reference pixels.","head_uv_audit":uv_stats,"surface_paint":paint_stats,"texture_sha256":{p.name:sha(p) for p in TEXTURES.glob("*.png")},"texture_sizes":{"head_color.png":[1024,1024],"eye_screen_left.png":[256,256],"eye_screen_right.png":[256,256]},"original_images_unchanged":True,"paid_submissions":0,"spent_credits":0,"status":"Unreviewed local surface-color trial; not accepted VIYA face"}
    (HERE/"surface_authoring.json").write_text(json.dumps(report,indent=2)+"\n")
    np.savez_compressed(EXCHANGE/"uv_raster.npz",positions=atlas,hits=hits)
    print(json.dumps({"uv":uv_stats,"surface":paint_stats}))


if __name__=="__main__":main()
