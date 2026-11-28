"""Reference RGB line/color transferred in local surface-feature coordinates.

Preserves the existingUV, shape and iris maps. No complete face-plane projection.
"""
import hashlib
import importlib.util
import json
import shutil
from pathlib import Path
import numpy as np
from PIL import Image
from scipy.ndimage import distance_transform_edt,binary_dilation

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[5]
PREV=HERE.parent/"face_surface_v1"
EXCHANGE=ROOT/".local_validation/PLAN_B03_04_FEATURE"
REG=json.loads((HERE/"feature_registration.json").read_text())
spec=importlib.util.spec_from_file_location("base_surface_bake",PREV/"bake_surface.py")
base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)


def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()


def mesh_fingerprints(data):
    return {name:{k:hashlib.sha256(np.asarray(o[k],dtype=np.int32 if k=="triangles" else np.float32).tobytes()).hexdigest() for k in ["positions","triangles","triangle_uv"]} for name,o in data["objects"].items()}


def nearest_frame(xz,line):
    line=np.asarray(line)[:,[0,2]];lengths=np.linalg.norm(np.diff(line,axis=0),axis=1);cum=np.r_[0,np.cumsum(lengths)];total=cum[-1]
    d=np.full(len(xz),np.inf);t_out=np.zeros(len(xz));signed=np.zeros(len(xz))
    for i,(a,b) in enumerate(zip(line,line[1:])):
        v=b-a;den=v@v
        if den<1e-15:continue
        t=np.clip(((xz-a)*v).sum(1)/den,0,1);offset=xz-(a+t[:,None]*v);dd=np.linalg.norm(offset,axis=1);use=dd<d
        d[use]=dd[use];t_out[use]=(cum[i]+t[use]*lengths[i])/total
        signed[use]=(v[0]*offset[use,1]-v[1]*offset[use,0])/lengths[i]
    return d,t_out,signed,total


def source_frame(points,t):
    q=np.asarray(points,float);lengths=np.linalg.norm(np.diff(q,axis=0),axis=1);cum=np.r_[0,np.cumsum(lengths)];s=np.clip(t,0,1)*cum[-1]
    i=np.clip(np.searchsorted(cum,s,side="right")-1,0,len(lengths)-1);local=(s-cum[i])/lengths[i]
    v=q[i+1]-q[i];point=q[i]+local[:,None]*v
    normal=np.stack([v[:,1],-v[:,0]],1)/lengths[i,None]
    return point,normal,cum[-1]


def sample_rgb(im,xy):
    x=np.clip(xy[:,0],0,im.shape[1]-2);y=np.clip(xy[:,1],0,im.shape[0]-2)
    x0=x.astype(int);y0=y.astype(int);a=(x-x0)[:,None];b=(y-y0)[:,None]
    return (im[y0,x0]*(1-a)+im[y0,x0+1]*a)*(1-b)+(im[y0+1,x0]*(1-a)+im[y0+1,x0+1]*a)*b


def transfer(colors,xz,line,source,band,im,front,scale_override=None):
    d,t,signed,target_length=nearest_frame(xz,line);point,normal,source_length=source_frame(source,t)
    scale=scale_override or source_length/target_length
    signed_px=signed*scale;near=d*scale<band
    sampled=np.tile([243.,199.,190.],(len(xz),1));sampled[near]=sample_rgb(im,point[near]+normal[near]*signed_px[near,None])
    m=REG["mask"];dark=np.clip((m["skin_luminance_reference"]-sampled.mean(1)-m["darkness_offset"])/m["darkness_range"],0,1)
    window=np.clip((band-d*scale)/m["source_band_feather_px"],0,1)
    end=np.minimum(np.clip(t/.025,0,1),np.clip((1-t)/.025,0,1))
    weight=dark*window*end*front;base.blend(colors,sampled,weight)
    return {"target_curve_length_working_m":float(target_length),"source_curve_length_px":float(source_length),"source_px_per_working_m":float(scale),"painted_surface_samples":int((weight>.02).sum())}


def paint(atlas,hits,features,palette,im):
    valid=hits>0;ps=atlas[valid];colors=np.tile(palette["skin"],(len(ps),1)).astype(float);front=np.clip((-ps[:,1]-.02)/.045,0,1)
    for side in [-1,1]:
        cheek=np.exp(-.5*((ps[:,0]-side*.043)/.018)**2-.5*((ps[:,2]-.088)/.016)**2)*front;base.blend(colors,palette["blush"],.16*cheek)
    mask=(abs(ps[:,0])<.072)&(ps[:,1]<-.035)&(ps[:,2]>.045)&(ps[:,2]<.158)
    face=colors[mask].copy();q=ps[mask];xz=q[:,[0,2]];front_mask=np.clip((-q[:,1]-.035)/.025,0,1);records=[]
    for side in ["eye_left","eye_right"]:
        upper,lower=base.split_paths(features[side]);upper=base.curve(upper);lower=base.curve(lower)
        du=base.distance(xz,upper);dl=base.distance(xz,lower)
        base.blend(face,palette["eye_wash"],.22*np.exp(-.5*(du/.0033)**2)*front_mask)
        base.blend(face,palette["lower_lid"],.75*np.clip((.00055-dl)/.00032,0,1)*front_mask)
    for brow in REG["brows"]:
        source=np.asarray(brow["source_points"]);scale=brow["placement_m_per_source_px"];center=brow["target_center"];iris=brow["source_iris"]
        target=np.stack([center[0]+(source[:,0]-iris[0])*scale,np.zeros(len(source)),center[1]+(iris[1]-source[:,1])*scale],1)
        # Authored continuous underpaint joins through exact observed endpoints.
        inferred=base.curve(brow["inferred_target_points"]);di,ti,_,_=nearest_frame(xz,inferred)
        tail=ti if "left" in brow["id"] else 1-ti;width=.0016*(.3+.7*tail**.6)
        inferred_weight=np.clip((width-di)/.0004,0,1)*REG["mask"]["inferred_brow_opacity"]*front_mask
        base.blend(face,palette["brow"],inferred_weight)
        record=transfer(face,xz,target,source,brow["source_half_band_px"],im,front_mask,1/scale);records.append({"id":brow["id"],"visible_source_only":True,**record})
    for lash in REG["lashes"]:
        upper,_=base.split_paths(features[lash["target_loop"]]);target=base.curve(upper)
        record=transfer(face,xz,target,lash["source_points"],lash["source_half_band_px"],im,front_mask);records.append({"id":lash["id"],**record})
    # Preserve the prior lower-lid, skin and mouth authoring in this unit.
    top,bottom=base.split_paths(features["mouth_lip_edge"]);mids=[]
    for p in top:mids.append((p+bottom[np.argmin(abs(bottom[:,0]-p[0]))])/2)
    dm=base.distance(xz,base.curve(mids));base.blend(face,palette["lip_tint"],.50*np.exp(-.5*(dm/.0021)**2)*front_mask);base.blend(face,palette["mouth_line"],.95*np.clip((.00090-dm)/.00035,0,1)*front_mask)
    colors[mask]=face;output=np.tile(np.asarray(palette["skin"],np.uint8),(atlas.shape[0],atlas.shape[1],1));output[valid]=np.clip(colors,0,255).astype(np.uint8)
    dist,indices=distance_transform_edt(~valid,return_indices=True);gutter=(~valid)&(dist<=16);output[gutter]=output[indices[0][gutter],indices[1][gutter]]
    return output,records


def main():
    data=json.loads((EXCHANGE/"bake_mesh.json").read_text());fp=mesh_fingerprints(data);old_data_path=ROOT/".local_validation/PLAN_B03_04/bake_mesh.json";cache_path=ROOT/".local_validation/PLAN_B03_04/uv_raster.npz"
    reuse=old_data_path.exists() and cache_path.exists() and fp==mesh_fingerprints(json.loads(old_data_path.read_text()))
    if reuse:
        a=np.load(cache_path);atlas=a["positions"];hits=a["hits"]
    else:atlas,hits,_=base.raster(data["objects"]["CC0_head_skin_UNAPPROVED"],2048)
    assert atlas.shape==(2048,2048,3)
    src=ROOT/"assets/characters/plan_b_viya/candidate_03/references/front.png";assert sha(src)==REG["source_front_sha256"]
    im=np.asarray(Image.open(src).convert("RGB"),float);palette=json.loads((PREV/"surface_authoring.json").read_text())["authored_palette"]
    output,records=paint(atlas,hits,data["features"],palette,im);tex=HERE/"textures";tex.mkdir(exist_ok=True)
    output=np.array(Image.fromarray(output).resize((1024,1024),Image.Resampling.LANCZOS),copy=True)
    for name in ["eye_screen_left.png","eye_screen_right.png"]:shutil.copy2(PREV/"textures"/name,tex/name)
    old=np.asarray(Image.open(PREV/"textures/head_color.png").convert("RGB"));changed=np.any(old!=output,axis=2)
    # Allow only eye/brow surface bands and a12px filtering/gutter neighborhood.
    valid=hits>0;region=valid&(abs(atlas[:,:,0])>.006)&(abs(atlas[:,:,0])<.078)&(atlas[:,:,1]<-.030)&(atlas[:,:,2]>.094)&(atlas[:,:,2]<.154)
    allowed=region.reshape(1024,2,1024,2).any(axis=(1,3));allowed=binary_dilation(allowed,iterations=12)
    raw_unexpected=int((changed&~allowed).sum())
    maximum_outside_delta=int(np.abs(old.astype(int)-output.astype(int))[~allowed].max())
    assert maximum_outside_delta<=1 and raw_unexpected<1000,"Unexpected nonlocal paint change"
    # Preserve all unedited source-atlas pixels exactly, including1-level bake rounding.
    output[~allowed]=old[~allowed]
    Image.fromarray(output).save(tex/"head_color_transfer.png")
    changed=np.any(old!=output,axis=2);unexpected=int((changed&~allowed).sum())
    report={"input_sha256":REG["input_sha256"],"front_source_sha256":sha(src),"surface_fingerprints":fp,"matched_prior_raster_reused":reuse,"no_uv_reunwrap":True,"no_geometry_changes":True,"source_image_unchanged":True,"source_rgb_sampling":"Bilinear along traced local source curves; darkness/proximity/endpoint alpha. No new source detail.","feature_transfers":records,"inferred_brow_opacity":REG["mask"]["inferred_brow_opacity"],"head_png_sha256":sha(tex/"head_color_transfer.png"),"iris_png_hashes_unchanged":all(sha(tex/n)==sha(PREV/"textures"/n) for n in ["eye_screen_left.png","eye_screen_right.png"]),"changed_head_pixels":int(changed.sum()),"pre_restore_nonlocal_rounding_pixels":raw_unexpected,"maximum_nonlocal_rounding_delta":maximum_outside_delta,"outside_band_restored_exactly_from_v1":True,"changed_pixels_outside_allowed_feature_band":unexpected,"paid_submissions":0,"spent_credits":0,"scope":"Material transfer only; not likeness or producer acceptance"}
    (HERE/"transfer_result.json").write_text(json.dumps(report,indent=2)+"\n")
    assert unexpected==0,report
    Image.fromarray(np.repeat(changed[:,:,None]*255,3,axis=2).astype(np.uint8)).save(EXCHANGE/"head_changed_pixels.png")
    print(json.dumps({k:report[k] for k in ["matched_prior_raster_reused","changed_head_pixels","changed_pixels_outside_allowed_feature_band","iris_png_hashes_unchanged"]}))


if __name__=="__main__":main()
