"""Source-led sclera/lower-edge tone, retaining every original iris pixel."""
import hashlib
import json
from pathlib import Path
import numpy as np
from PIL import Image

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[5]
PARAM=json.loads((HERE/'parameters.json').read_text())
SOURCE=ROOT/'assets/characters/plan_b_viya/candidate_03/references/front.png'
OLD=HERE.parent/'face_surface_v4/textures'

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def smooth(x):
    t=np.clip(x,0,1);return t*t*(3-2*t)

def sample(im,box,bright=False):
    x0,y0,x1,y1=box;q=im[y0:y1,x0:x1].reshape(-1,3)
    if bright:q=q[(q[:,0]>220)&(q[:,1]>170)&(q[:,2]>165)]
    assert len(q)>=4
    return np.median(q,axis=0),{'box':box,'selected_native_pixels':len(q),'selection':'R>220,G>170,B>165 inside the manually observed bright patch' if bright else 'all pixels in the observed lower-edge patch','median_rgb':np.median(q,axis=0).tolist(),'scope':'Observed painted colors; no calibrated illumination or exact physical sclera albedo.'}

def main():
    assert sha(SOURCE)==PARAM['source_front_sha256'];im=np.asarray(Image.open(SOURCE).convert('RGB'),float)
    uv=json.loads((HERE.parent/'face_surface_v1/uv_preparation.json').read_text())['uv_methods']
    tex=HERE/'textures';tex.mkdir(exist_ok=True);records=[]
    for side,obj,lower_box in [('left','CC0_helper-r-eye_UNAPPROVED',[721,190,725,193]),('right','CC0_helper-l-eye_UNAPPROVED',[806,180,812,184])]:
        name='eye_screen_'+side+'.png';before=np.asarray(Image.open(OLD/name).convert('RGB'));size=before.shape[0];assert before.shape==(256,256,3)
        base,source_base=sample(im,PARAM['source_sclera_patches']['screen_'+side+'_inner'],True)
        lower,source_lower=sample(im,lower_box)
        u=(np.arange(size)+.5)/size;v=1-(np.arange(size)+.5)/size;uu,vv=np.meshgrid(u,v);lon=(uu-.5)*2*np.pi;lat=(vv-.5)*np.pi
        rx,_,rz=uv[obj]['radius'];sx=np.sin(lon)*np.cos(lat)*rx/PARAM['iris_radius_working_m'];sy=np.sin(lat)*rz/PARAM['iris_radius_working_m'];rr=np.sqrt(sx*sx+sy*sy)
        iris=(rr<1)&(np.cos(lon)>0)
        # Only the exact original sclera-background color outside the protected iris can change.
        edit=(~iris)&np.all(before==PARAM['old_sclera_rgb'],axis=2)
        tone=np.tile(base,(size,size,1));amount=.18*smooth((-sy-.45)/.95)*np.maximum(np.cos(lon),0)**3
        tone=tone*(1-amount[:,:,None])+lower*amount[:,:,None]
        after=before.copy();after[edit]=np.rint(np.clip(tone[edit],0,255)).astype(np.uint8)
        assert np.array_equal(after[iris],before[iris]) and np.array_equal(after[~edit],before[~edit])
        Image.fromarray(after).save(tex/name)
        # Green iris / blue sclera; diagnostic only, never installed as the final color map.
        mask=np.zeros((size,size,3),np.uint8);mask[iris]=[0,255,0];mask[~iris]=[0,0,255]
        Image.fromarray(mask).save(tex/('iris_mask_'+side+'.png'))
        records.append({'side':side,'object':obj,'original_png_sha256':sha(OLD/name),'new_png_sha256':sha(tex/name),'source_base':source_base,'source_lower_edge':source_lower,'authored_lower_edge_mix_max':.18,'iris_pixels_protected':int(iris.sum()),'changed_pixels':int(np.any(before!=after,axis=2).sum()),'iris_bytes_identical':True,'iris_uv_placement_radius_and_boundary_unchanged':True,'all_pixels_outside_edit_mask_identical':True,'new_source_detail_recovered':False})
    report={'input_sha256':PARAM['input_sha256'],'source_front_sha256':sha(SOURCE),'records':records,'head_texture_unchanged':True,'source_reference_images_unchanged':True,'no_geometry_uv_or_raster_bake':True,'no_old_R4_raster_used':True,'ambiguous_outer_patch_not_used_as_sclera_albedo':True,'scope':'Source-led local color authoring only; not reference likeness, eye contact or engine acceptance.','paid_submissions':0,'spent_credits':0}
    (HERE/'paint_result.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps([{k:r[k] for k in ['side','changed_pixels','iris_pixels_protected','iris_bytes_identical']} for r in records]))

if __name__=='__main__':main()
