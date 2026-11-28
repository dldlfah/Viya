"""Local source eyelid/nose overlays; no geometry or full-face image projection."""
import hashlib
import importlib.util
import json
import shutil
from pathlib import Path
import numpy as np
from PIL import Image
from scipy.ndimage import binary_dilation,distance_transform_edt

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[5]
PREV=HERE.parent/'face_surface_v3'
EXCHANGE=ROOT/'.local_validation/PLAN_B03_04_DETAIL'
REG=json.loads((HERE/'feature_registration.json').read_text())
spec=importlib.util.spec_from_file_location('previous_expression_bake',PREV/'bake_expression.py')
old=importlib.util.module_from_spec(spec);spec.loader.exec_module(old)
base=old.base

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def over(rgb,alpha,color,weight):
    a=np.clip(weight,0,1)
    rgb[:]=np.asarray(color)/255*a[:,None]+rgb*(1-a[:,None])
    alpha[:]=a+alpha*(1-a)

def trim_curve(line,lo=.15,hi=.85):
    q=np.asarray(line);length=np.linalg.norm(np.diff(q[:,[0,2]],axis=0),axis=1);t=np.r_[0,np.cumsum(length)];t/=t[-1]
    return q[(t>=lo)&(t<=hi)]

def sample_curve(xz,target,feature,im):
    color,alpha,t,record=old.source_field(xz,target,feature['source_points'],feature['source_half_band_px'],im,offset=REG['mask']['shadow_darkness_offset'],span=REG['mask']['shadow_darkness_range'])
    alpha*=old.smooth(t/.09)*old.smooth((1-t)/.09)
    return color,alpha,record

def downsample(field):
    return np.stack([np.asarray(Image.fromarray(field[:,:,i]).resize((1024,1024),Image.Resampling.LANCZOS)) for i in range(4)],axis=2)

def main():
    data=json.loads((EXCHANGE/'bake_mesh.json').read_text());fp=old.old.mesh_fingerprints(data)
    cache=ROOT/'.local_validation/PLAN_B03_04/uv_raster.npz';prior_mesh=ROOT/'.local_validation/PLAN_B03_04/bake_mesh.json'
    reuse=cache.exists() and prior_mesh.exists() and fp==old.old.mesh_fingerprints(json.loads(prior_mesh.read_text()))
    if reuse:
        raster=np.load(cache);atlas=raster['positions'];hits=raster['hits']
    else:atlas,hits,_=base.raster(data['objects']['CC0_head_skin_UNAPPROVED'],2048)
    src=ROOT/'assets/characters/plan_b_viya/candidate_03/references/front.png';assert sha(src)==REG['source_front_sha256']
    im=np.asarray(Image.open(src).convert('RGB'),float)
    valid=hits>0;ps=atlas[valid]
    roi=(abs(ps[:,0])<.074)&(ps[:,1]<-.035)&(ps[:,2]>.076)&(ps[:,2]<.129)
    q=ps[roi];xz=q[:,[0,2]];rgb=np.zeros((len(q),3),np.float32);alpha=np.zeros(len(q),np.float32);front=np.clip((-q[:,1]-.035)/.025,0,1);records=[]
    upper_protect=np.zeros(len(ps),bool)
    for f in REG['lower_lids']:
        upper,lower=base.split_paths(data['features'][f['target_loop']]);upper=base.curve(upper);lower=base.curve(lower)
        distance,t,signed,_=old.old.nearest_frame(xz,lower)
        du=base.distance(xz,upper)
        color,a,record=sample_curve(xz,lower,f,im)
        # Lower-line normal is positive above; only skin below the aperture is painted.
        outside=old.smooth((.00005-signed)/.00035)
        a*=outside*front*REG['mask']['lower_lid_opacity']*(du>REG['mask']['upper_lash_protection_working_m'])
        over(rgb,alpha,color,a)
        records.append({'id':f['id'],**record,'outside_aperture_only':True,'painted_surface_samples':int((a>.02).sum())})
        # Protect the existing upper-lash ribbon in the final native atlas.
        p=(abs(ps[:,0])<.076)&(ps[:,1]<-.035)&(ps[:,2]>.09)&(ps[:,2]<.122)
        upper_protect[p]|=base.distance(ps[p][:,[0,2]],upper)<REG['mask']['upper_lash_protection_working_m']
    for f in REG['upper_creases']:
        upper,_=base.split_paths(data['features'][f['target_loop']]);upper=base.curve(upper)
        target=trim_curve(upper).copy();target[:,2]+=f['target_vertical_offset_working_m']
        color,a,record=sample_curve(xz,target,f,im)
        a*=front*REG['mask']['crease_opacity']*(base.distance(xz,upper)>.0021)
        over(rgb,alpha,color,a);records.append({'id':f['id'],**record,'painted_surface_samples':int((a>.02).sum()),'target_offset_is_authored':True})
    for f in REG['nose_marks']:
        desired=np.asarray(f['target_xz_working_m']);distance=((xz-desired)**2).sum(1)
        candidates=(abs(q[:,0])<.018)&(q[:,2]>.078)&(q[:,2]<.095)&(q[:,1]<-.07)
        index=np.argmin(np.where(candidates,distance,np.inf));anchor=q[index]
        delta=xz-anchor[[0,2]];s=f['working_m_per_source_px'];center=np.asarray(f['source_center_px'])
        xy=center+np.stack([delta[:,0]/s,-delta[:,1]/s],axis=1)
        box=f['source_crop'];inside=(xy[:,0]>box[0])&(xy[:,0]<box[2]-1)&(xy[:,1]>box[1])&(xy[:,1]<box[3]-1)&(abs(q[:,1]-anchor[1])<.006)
        color=np.tile([243.,199.,190.],(len(q),1));color[inside]=old.old.sample_rgb(im,xy[inside])
        crop=im[box[1]:box[3],box[0]:box[2]];border=np.vstack([crop[0],crop[-1],crop[:,0],crop[:,-1]])
        background=np.median(border,axis=0)
        a=np.clip((background.mean()-color.mean(1)-5)/65,0,1)*inside*front*REG['mask']['nose_opacity']
        edge=np.minimum.reduce([xy[:,0]-box[0],box[2]-1-xy[:,0],xy[:,1]-box[1],box[3]-1-xy[:,1]])
        a*=old.smooth(edge/.8)
        over(rgb,alpha,color,a);records.append({'id':f['id'],'source_patch_size_px':[box[2]-box[0],box[3]-box[1]],'source_background_rgb':background.tolist(),'actual_surface_anchor_working_m':anchor.tolist(),'anchor_placement_is_authored_not_calibrated':True,'painted_surface_samples':int((a>.02).sum())})
    field=np.zeros((*valid.shape,4),np.float32);samples=np.zeros((len(ps),4),np.float32);samples[roi,:3]=rgb;samples[roi,3]=alpha;field[valid]=samples
    dist,indices=distance_transform_edt(~valid,return_indices=True);gutter=(~valid)&(dist<=16)
    field[gutter]=field[indices[0][gutter],indices[1][gutter]]
    native=downsample(field);a=np.clip(native[:,:,3],0,1);a[a<REG['mask']['native_alpha_cutoff']]=0
    premult=np.minimum(np.maximum(native[:,:,:3],0),a[:,:,None])
    original=np.asarray(Image.open(PREV/'textures/head_color_expression.png').convert('RGB'))
    # Explicit protection for existing brows/mouth/upper lashes, including filter support.
    protected_upper=np.zeros(valid.shape,bool);protected_upper[valid]=upper_protect
    protected_upper=binary_dilation(protected_upper.reshape(1024,2,1024,2).any(axis=(1,3)),iterations=1)
    mouth=valid&(abs(atlas[:,:,0])<.03)&(atlas[:,:,1]<-.035)&(atlas[:,:,2]>.055)&(atlas[:,:,2]<.075)
    protected_mouth=binary_dilation(mouth.reshape(1024,2,1024,2).any(axis=(1,3)),iterations=3)
    brow=valid&(abs(atlas[:,:,0])<.073)&(atlas[:,:,1]<-.035)&(atlas[:,:,2]>.122)&(atlas[:,:,2]<.14)
    protected_brow=brow.reshape(1024,2,1024,2).any(axis=(1,3))&(original.mean(2)<185)
    protected_brow=binary_dilation(protected_brow,iterations=2)
    protect=protected_upper|protected_mouth|protected_brow
    a[protect]=0;premult[protect]=0;premult[a==0]=0
    out=np.rint(np.clip(original/255*(1-a[:,:,None])+premult,0,1)*255).astype(np.uint8)
    changed=np.any(out!=original,axis=2);assert not (changed&protect).any() and not (changed&(a==0)).any()
    tex=HERE/'textures';tex.mkdir(exist_ok=True);Image.fromarray(out).save(tex/'head_color_details.png')
    overlay=np.zeros((*a.shape,4),np.uint8);overlay[:,:,:3]=np.rint(np.clip(premult/np.maximum(a[:,:,None],1e-12),0,1)*255).astype(np.uint8);overlay[:,:,3]=np.rint(a*255).astype(np.uint8)
    Image.fromarray(overlay).save(tex/'feature_overlay.png')
    for name in ['eye_screen_left.png','eye_screen_right.png']:shutil.copy2(PREV/'textures'/name,tex/name)
    report={'input_sha256':REG['input_sha256'],'front_source_sha256':sha(src),'surface_fingerprints':fp,'matched_prior_raster_reused':reuse,'no_uv_reunwrap':True,'no_geometry_changes':True,'feature_transfers':records,'head_png_sha256':sha(tex/'head_color_details.png'),'changed_head_pixels':int(changed.sum()),'pixels_changed_outside_overlay':int((changed&(a==0)).sum()),'protected_upper_lash_pixels_changed':int((changed&protected_upper).sum()),'protected_brow_pixels_changed':int((changed&protected_brow).sum()),'protected_mouth_pixels_changed':int((changed&protected_mouth).sum()),'all_other_head_pixels_byte_identical':True,'overlay_premultiplied_supersampling':True,'iris_png_hashes_unchanged':all(sha(tex/n)==sha(PREV/'textures'/n) for n in ['eye_screen_left.png','eye_screen_right.png']),'paid_submissions':0,'spent_credits':0,'scope':'Technical local overlay preservation only; no likeness/rig/game/device approval.'}
    (HERE/'transfer_result.json').write_text(json.dumps(report,indent=2)+'\n')
    Image.fromarray(np.repeat(changed[:,:,None]*255,3,axis=2).astype(np.uint8)).save(EXCHANGE/'head_changed_pixels.png')
    print(json.dumps({k:report[k] for k in ['changed_head_pixels','pixels_changed_outside_overlay','protected_upper_lash_pixels_changed','protected_brow_pixels_changed','protected_mouth_pixels_changed']}))

if __name__=='__main__':main()
