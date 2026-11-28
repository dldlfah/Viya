"""Single-composite brow joins and local source mouth RGB on existing UV.

This is surface material authoring. Source images and evaluated geometry are immutable.
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
PREV=HERE.parent/'face_surface_v2'
V1=HERE.parent/'face_surface_v1'
EXCHANGE=ROOT/'.local_validation/PLAN_B03_04_MOUTH'
REG=json.loads((HERE/'feature_registration.json').read_text())
spec=importlib.util.spec_from_file_location('previous_feature_bake',PREV/'bake_transfer.py')
old=importlib.util.module_from_spec(spec);spec.loader.exec_module(old)
base=old.base

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def smooth(x):
    x=np.clip(x,0,1);return x*x*(3-2*x)

def source_field(xz,target,source,band,im,scale_override=None,offset=12,span=110):
    d,t,signed,length=old.nearest_frame(xz,target)
    point,normal,source_length=old.source_frame(source,t)
    scale=scale_override or source_length/length
    near=d*scale<band
    rgb=np.tile([243.,199.,190.],(len(xz),1))
    rgb[near]=old.sample_rgb(im,point[near]+normal[near]*(signed[near]*scale)[:,None])
    alpha=np.clip((210-rgb.mean(1)-offset)/span,0,1)*smooth((band-d*scale)/.8)
    return rgb,alpha,t,{'target_curve_length_working_m':float(length),'source_curve_length_px':float(source_length),'source_px_per_working_m':float(scale)}

def brow_field(face,xz,front,brow,im):
    source=np.asarray(brow['source_points']);s=brow['placement_m_per_source_px'];c=brow['target_center'];iris=brow['source_iris']
    target=np.stack([c[0]+(source[:,0]-iris[0])*s,np.zeros(len(source)),c[1]+(iris[1]-source[:,1])*s],1)
    rgb,observed,t,record=source_field(xz,target,source,brow['source_half_band_px'],im,1/s)
    cfg=REG['brow_compositing'];edge=cfg['endpoint_crossfade_fraction']
    mix=smooth(t/edge)*smooth((1-t)/edge)
    authored_curve=base.curve(brow['inferred_target_points'])
    distance,ta,_,_=old.nearest_frame(xz,authored_curve)
    left='left' in brow['id'];tail=ta if left else 1-ta
    width=cfg['left_half_width_working_m' if left else 'right_half_width_working_m']*(.12+.88*tail**.45)
    taper=cfg['width_taper_endpoint_fraction']
    width*=smooth(ta/taper)*smooth((1-ta)/taper)
    authored=np.clip((width-distance)/.00042,0,1)*cfg['authored_opacity']*smooth(ta/.035)*smooth((1-ta)/.035)
    # Use actual observed stroke color for the hypothetical extension, without copying anatomy.
    points,_,_=old.source_frame(source,np.linspace(.15,.85,40));samples=old.sample_rgb(im,points)
    dark=samples[samples.mean(1)<150];assert len(dark)>5
    extension_rgb=np.median(dark,axis=0)
    a=observed*mix;b=authored*(1-mix);alpha=a+b
    ink=(rgb*a[:,None]+extension_rgb*b[:,None])/np.maximum(alpha[:,None],1e-12)
    base.blend(face,ink,alpha*front)
    return {'id':brow['id'],**record,'single_composite_no_stacked_ink':True,'authored_extension_rgb_from_visible_source':extension_rgb.tolist(),'extension_shape_is_authored':True,'painted_surface_samples':int((alpha*front>.02).sum())}

def paint(atlas,hits,features,palette,im):
    valid=hits>0;ps=atlas[valid];colors=np.tile(palette['skin'],(len(ps),1)).astype(float)
    front=np.clip((-ps[:,1]-.02)/.045,0,1)
    for side in [-1,1]:
        cheek=np.exp(-.5*((ps[:,0]-side*.043)/.018)**2-.5*((ps[:,2]-.088)/.016)**2)*front
        base.blend(colors,palette['blush'],.16*cheek)
    mask=(abs(ps[:,0])<.072)&(ps[:,1]<-.035)&(ps[:,2]>.045)&(ps[:,2]<.158)
    face=colors[mask].copy();q=ps[mask];xz=q[:,[0,2]];front=np.clip((-q[:,1]-.035)/.025,0,1);records=[]
    for side in ['eye_left','eye_right']:
        upper,lower=base.split_paths(features[side]);du=base.distance(xz,base.curve(upper));dl=base.distance(xz,base.curve(lower))
        base.blend(face,palette['eye_wash'],.22*np.exp(-.5*(du/.0033)**2)*front)
        base.blend(face,palette['lower_lid'],.75*np.clip((.00055-dl)/.00032,0,1)*front)
    for brow in REG['brows']:records.append(brow_field(face,xz,front,brow,im))
    # Preserve previous lash authoring. Pixels outside the brow/mouth mask are restored exactly below.
    for lash in REG['lashes']:
        upper,_=base.split_paths(features[lash['target_loop']])
        old.transfer(face,xz,base.curve(upper),lash['source_points'],lash['source_half_band_px'],im,front)
    m=REG['mouth'];top,bottom=base.split_paths(features[m['target_loop']]);mids=[]
    for p in top:mids.append((p+bottom[np.argmin(abs(bottom[:,0]-p[0]))])/2)
    target=base.curve(mids)
    rgb,alpha,t,record=source_field(xz,target,m['source_points'],m['source_half_band_px'],im,offset=m['darkness_offset'],span=m['darkness_range'])
    alpha*=smooth(t/.035)*smooth((1-t)/.035)*front
    base.blend(face,rgb,alpha)
    records.append({'id':'mouth_line',**record,'target_is_actual_lip_midpoint_curve':True,'painted_surface_samples':int((alpha>.02).sum())})
    colors[mask]=face;output=np.tile(np.asarray(palette['skin'],np.uint8),(atlas.shape[0],atlas.shape[1],1));output[valid]=np.clip(colors,0,255).astype(np.uint8)
    dist,indices=distance_transform_edt(~valid,return_indices=True);gutter=(~valid)&(dist<=16)
    output[gutter]=output[indices[0][gutter],indices[1][gutter]]
    return output,records

def main():
    data=json.loads((EXCHANGE/'bake_mesh.json').read_text());fp=old.mesh_fingerprints(data)
    cache=ROOT/'.local_validation/PLAN_B03_04/uv_raster.npz';prior_mesh=ROOT/'.local_validation/PLAN_B03_04/bake_mesh.json'
    reuse=cache.exists() and prior_mesh.exists() and fp==old.mesh_fingerprints(json.loads(prior_mesh.read_text()))
    if reuse:
        a=np.load(cache);atlas=a['positions'];hits=a['hits']
    else:atlas,hits,_=base.raster(data['objects']['CC0_head_skin_UNAPPROVED'],2048)
    src=ROOT/'assets/characters/plan_b_viya/candidate_03/references/front.png';assert sha(src)==REG['source_front_sha256']
    im=np.asarray(Image.open(src).convert('RGB'),float);palette=json.loads((V1/'surface_authoring.json').read_text())['authored_palette']
    out,records=paint(atlas,hits,data['features'],palette,im)
    out=np.array(Image.fromarray(out).resize((1024,1024),Image.Resampling.LANCZOS),copy=True)
    original=np.asarray(Image.open(PREV/'textures/head_color_transfer.png').convert('RGB'))
    valid=hits>0
    brow=valid&(abs(atlas[:,:,0])>.008)&(abs(atlas[:,:,0])<.069)&(atlas[:,:,1]<-.03)&(atlas[:,:,2]>.1215)&(atlas[:,:,2]<.138)
    mouth=valid&(abs(atlas[:,:,0])<.028)&(atlas[:,:,1]<-.045)&(atlas[:,:,2]>.055)&(atlas[:,:,2]<.075)
    masks={name:binary_dilation(region.reshape(1024,2,1024,2).any(axis=(1,3)),iterations=8) for name,region in [('brow',brow),('mouth',mouth)]}
    allowed=masks['brow']|masks['mouth']
    # This is an explicit material edit mask: retain every other pixel from the input atlas.
    out[~allowed]=original[~allowed]
    tex=HERE/'textures';tex.mkdir(exist_ok=True);Image.fromarray(out).save(tex/'head_color_expression.png')
    for name in ['eye_screen_left.png','eye_screen_right.png']:shutil.copy2(PREV/'textures'/name,tex/name)
    changed=np.any(out!=original,axis=2)
    eye=valid&(abs(atlas[:,:,0])>.005)&(abs(atlas[:,:,0])<.08)&(atlas[:,:,1]<-.035)&(atlas[:,:,2]>.094)&(atlas[:,:,2]<.1205)
    eye=binary_dilation(eye.reshape(1024,2,1024,2).any(axis=(1,3)),iterations=2)
    eye_changed=int((changed&eye).sum());assert eye_changed==0,'Unintended eye/lash edit'
    report={'input_sha256':REG['input_sha256'],'front_source_sha256':sha(src),'surface_fingerprints':fp,'matched_prior_raster_reused':reuse,'no_uv_reunwrap':True,'no_geometry_changes':True,'feature_transfers':records,'head_png_sha256':sha(tex/'head_color_expression.png'),'changed_head_pixels':int(changed.sum()),'changed_brow_pixels':int((changed&masks['brow']).sum()),'changed_mouth_pixels':int((changed&masks['mouth']).sum()),'changed_pixels_outside_allowed_feature_band':int((changed&~allowed).sum()),'all_other_head_pixels_byte_identical':True,'iris_png_hashes_unchanged':all(sha(tex/n)==sha(PREV/'textures'/n) for n in ['eye_screen_left.png','eye_screen_right.png']),'paid_submissions':0,'spent_credits':0,'scope':'Material edit mask and persistence only, not likeness acceptance.'}
    report['protected_eye_lash_neighborhood_changed_pixels']=eye_changed
    delta=np.array([809-727,174-182]);theta=np.arctan2(delta[1],delta[0]);mouth_points=np.array(REG['mouth']['source_points'])
    rotation=np.array([[np.cos(-theta),-np.sin(-theta)],[np.sin(-theta),np.cos(-theta)]]);de_axis=(mouth_points-mouth_points.mean(0))@rotation.T
    report['source_axis_diagnostic']={'source_iris_centers_px':[[727,182],[809,174]],'eye_axis_angle_degrees':float(np.degrees(theta)),'raw_mouth_endpoint_dy_px':float(mouth_points[-1,1]-mouth_points[0,1]),'endpoint_dy_in_eye_axis_coordinates_px':float(de_axis[-1,1]-de_axis[0,1]),'coordinate_rotation_only_no_source_image_warp':True,'not_calibrated3d_head_roll_or_anatomical_asymmetry_measurement':True}
    (HERE/'transfer_result.json').write_text(json.dumps(report,indent=2)+'\n')
    Image.fromarray(np.repeat(changed[:,:,None]*255,3,axis=2).astype(np.uint8)).save(EXCHANGE/'head_changed_pixels.png')
    print(json.dumps({k:report[k] for k in ['matched_prior_raster_reused','changed_head_pixels','changed_brow_pixels','changed_mouth_pixels','changed_pixels_outside_allowed_feature_band']}))

if __name__=='__main__':main()
