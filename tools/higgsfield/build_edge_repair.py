"""Reproduce the validated Higgsfield edge repair in a separate QA directory.
Canonical game art and the approved derivative are read-only. Explicit masks cover
reviewed white background remnants; generated colours repair only adjacent edges.
"""
from pathlib import Path
import argparse,hashlib,json
import numpy as np
from PIL import Image,ImageDraw
from scipy.ndimage import maximum_filter,minimum_filter,label,find_objects

CROP=(43,13,369,480)
PLACED=(170,244)
OFFSET=(15,4)
CANVAS=(200,248)
GAP_ROIS={'gun_gap':(108,111,144,145),'inner_legs':(70,145,130,212),'hair_upper':(18,28,95,88),'hair_lower':(18,88,82,140)}

def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def rgba(path):return Image.open(path).convert('RGBA')
def place_native(im):
    if im.size!=(400,496):
        im=im.convert('RGBa').resize((400,496),Image.Resampling.LANCZOS).convert('RGBA')
    part=im.crop(CROP).convert('RGBa').resize(PLACED,Image.Resampling.LANCZOS).convert('RGBA')
    result=Image.new('RGBA',CANVAS);result.alpha_composite(part,OFFSET)
    a=np.array(result);a[a[:,:,3]==0]=0
    return Image.fromarray(a)

def repair(rawim,baseim,generated):
    raw=np.array(rawim);base=np.array(baseim);gen=np.array(generated)
    alpha=raw[:,:,3];rgb=raw[:,:,:3].astype(float);brgb=base[:,:,:3].astype(float);grgb=gen[:,:,:3].astype(float)
    yy,xx=np.indices(alpha.shape)
    original_band=maximum_filter((alpha<16).astype(np.uint8),size=7,mode='constant',cval=0).astype(bool)
    # Only clear, neutral-white pixels may lose alpha. No warm skin/ivory/gold colour-keying.
    white=(alpha>16)&(rgb.min(2)>=200)&(np.ptp(rgb,axis=2)<=35)
    seed=(alpha>16)&(rgb.min(2)>=220)&(np.ptp(rgb,axis=2)<=25)
    alpha_mask=np.zeros(alpha.shape,bool);manual_hair_mask=np.zeros(alpha.shape,bool);component_records=[]
    for roi_name,(x0,y0,x1,y1) in GAP_ROIS.items():
        roi=(xx>=x0)&(xx<x1)&(yy>=y0)&(yy<y1)
        labels,n=label(white&roi,np.ones((3,3),dtype=np.uint8))
        for k,sl in enumerate(find_objects(labels),1):
            component=labels==k
            area=int(component.sum());seeds=int((component&seed).sum())
            if area<3 or not seeds:continue
            overlap=component&(gen[:,:,3]<16)
            # Manual review: neutral-white islands behind the brown hair, outside face/outfit.
            # Native-frame review confirms both open gaps and enclosed white background islands.
            reviewed_hair=roi_name.startswith('hair_')
            selected=component if reviewed_hair else overlap
            if reviewed_hair:manual_hair_mask|=selected
            alpha_mask|=selected
            component_records.append({'region':roi_name,'bbox':[sl[1].start,sl[0].start,sl[1].stop,sl[0].stop],'white_component_pixels':area,'strict_white_seed_pixels':seeds,'generated_background_overlap_pixels':int(overlap.sum()),'selected_pixels':int(selected.sum()),'manual_reviewed_hair_background':reviewed_hair})
    # Exact geometry outside the approved small holes; alpha can only decrease.
    result=base.copy();result[:,:,3]=alpha
    result[alpha_mask,3]=np.minimum(alpha[alpha_mask],gen[alpha_mask,3])
    result[manual_hair_mask,3]=0
    repair_band=maximum_filter(alpha_mask.astype(np.uint8),size=7,mode='constant',cval=0).astype(bool)
    allowed=original_band|repair_band
    crown=yy<28
    face_ivory=(xx>=100)&(yy>=28)&(yy<105)
    usual_bright=(brgb.min(2)>=135)&(np.ptp(brgb,axis=2)<=75)
    strict_crown_white=(brgb.min(2)>=205)&(np.ptp(brgb,axis=2)<=25)
    # Cover only one-pixel mixed-matte neighbours of known strict-white crown pixels.
    crown_mixed_halo=usual_bright&maximum_filter(strict_crown_white.astype(np.uint8),size=3,mode='constant',cval=0).astype(bool)
    crown_selected=strict_crown_white|crown_mixed_halo
    targets=(alpha>=4)&allowed&~face_ivory&np.where(crown,crown_selected,usual_bright)
    solid=(alpha>=250)&(minimum_filter(alpha,size=5,mode='constant',cval=0)>=240)&(gen[:,:,3]>=230)
    donors=[];no_donor=0
    for y,x in zip(*np.where(targets)):
        choices=[];old_luma=brgb[y,x].mean()
        for dy in range(-8,9):
            for dx in range(-8,9):
                sy,sx=y+dy,x+dx
                if sx<0 or sy<0 or sx>=CANVAS[0] or sy>=CANVAS[1] or not solid[sy,sx]:continue
                original_material=rgb[sy,sx];generated_material=grgb[sy,sx]
                if original_material.mean()>155 or generated_material.mean()>155:continue
                if old_luma-original_material.mean()<35 or old_luma-generated_material.mean()<35:continue
                colour_distance=float(np.sqrt(np.mean((generated_material-original_material)**2)))
                if colour_distance>45:continue
                score=dx*dx+dy*dy+colour_distance*0.08
                choices.append((score,sy,sx))
        if not choices:
            no_donor+=1;continue
        _,sy,sx=min(choices)
        result[y,x,:3]=gen[sy,sx,:3]
        donors.append({'pixel':[int(x),int(y)],'donor':[int(sx),int(sy)],'old_rgb':base[y,x,:3].tolist(),'generated_rgb':gen[sy,sx,:3].tolist()})
    # Explicit source lock: no content changes outside original edge / approved hole band.
    result[~allowed,:3]=raw[~allowed,:3]
    # Alpha-zero RGB in repaired holes is hidden and canonicalized; elsewhere keep cache padding.
    result[alpha_mask&(result[:,:,3]==0),:3]=0
    rgb_mask=np.any(result[:,:,:3]!=base[:,:,:3],axis=2)
    def bright_metrics(im):
        c=im[:,:,:3].astype(int);vis=im[:,:,3]>=16
        strict=vis&(c.min(2)>=220)&(np.ptp(c,axis=2)<=25)
        return {'strict_white_on_original_edge':int((strict&original_band).sum()),'strict_white_in_gap_rois':int((strict&(((xx>=108)&(xx<144)&(yy>=111)&(yy<145))|((xx>=70)&(xx<130)&(yy>=145)&(yy<212)))).sum()),'strict_white_on_crown':int((strict&crown&original_band).sum())}
    stats={'alpha_changed_pixels':int((result[:,:,3]!=alpha).sum()),'alpha_increased_pixels':int((result[:,:,3]>alpha).sum()),'alpha_changed_outside_mask':int(((result[:,:,3]!=alpha)&~alpha_mask).sum()),'alpha_mask_pixels':int(alpha_mask.sum()),'manual_hair_alpha_pixels':int(manual_hair_mask.sum()),'changed_visible_rgb_vs_current_cache':int((rgb_mask&(alpha>0)).sum()),'changed_rgb_outside_allowed_band':int((rgb_mask&~allowed).sum()),'raw_rgb_exact_outside_allowed_band':bool(np.array_equal(result[~allowed,:3],raw[~allowed,:3])),'face_ivory_visible_rgb_changes':int((rgb_mask&face_ivory&(alpha>0)).sum()),'crown_mixed_matte_rgb_changes':int((rgb_mask&crown&~strict_crown_white&(alpha>0)).sum()),'crown_unselected_rgb_changes':int((rgb_mask&crown&~crown_selected&(alpha>0)).sum()),'target_pixels':int(targets.sum()),'targets_without_safe_donor':no_donor,'raw':bright_metrics(raw),'current_cache':bright_metrics(base),'trial':bright_metrics(result),'alpha_components':component_records,'donors':donors}
    assert stats['alpha_increased_pixels']==0 and stats['alpha_changed_outside_mask']==0
    assert stats['changed_rgb_outside_allowed_band']==0 and stats['raw_rgb_exact_outside_allowed_band']
    assert stats['face_ivory_visible_rgb_changes']==0 and stats['crown_unselected_rgb_changes']==0
    return Image.fromarray(result),alpha_mask,rgb_mask,stats

def draw_compare(path,raw,base,generated,trial,alpha_mask,rgb_mask):
    labels=['RAW','CURRENT CACHE','GENERATED REGISTERED','FRAME-LOCKED REPAIR']
    sheet=Image.new('RGB',(1760,660),(53,60,65));draw=ImageDraw.Draw(sheet)
    for j,(im,txt) in enumerate(zip([raw,base,generated,trial],labels)):
        draw.text((j*440+18,10),txt,fill='white')
        big=im.resize((400,496),Image.Resampling.NEAREST);sheet.paste(big,(j*440+20,40),big)
        small=im.convert('RGBa').resize((69,86),Image.Resampling.LANCZOS).convert('RGBA');sheet.paste(small,(j*440+185,548),small)
    draw.text((20,640),f'Alpha exceptions: {int(alpha_mask.sum())} px. RGB changed: {int(rgb_mask.sum())} px. Original pose, face, clothing and frame registration retained.',fill='white')
    sheet.save(path)

def main():
    p=argparse.ArgumentParser()
    p.add_argument('--repo',type=Path,default=Path(__file__).resolve().parents[2])
    p.add_argument('--out',type=Path)
    p.add_argument('--indices',default='all')
    args=p.parse_args()
    root=args.repo.resolve();repo=root/'assets/characters/pilot_32'
    repair_root=repo/'edge_repair';native=repair_root/'native';generated=repair_root/'generated'
    baseline=repair_root/'baseline'
    out=args.out.resolve() if args.out else root/'.local_validation/higgsfield_rebuild'
    if out==repair_root or repair_root in out.parents:
        raise ValueError('Use a separate QA output directory; validated artwork is not overwritten')
    manifest=json.loads((repair_root/'manifest.json').read_text())
    validated={Path(row['source']).name:row for row in manifest['frames']}
    for part in ['frames','alpha_masks','rgb_masks','registered','comparisons','reports']:
        (out/part).mkdir(parents=True,exist_ok=True)
    indices=list(range(11)) if args.indices=='all' else [int(x) for x in args.indices.split(',')]
    rows=[]
    for index in indices:
        name=f'viya_run_e_{index:02d}.png';expected=validated[name]
        for path,key in [(repo/'frames'/name,'source_sha256'),(baseline/name,'baseline_sha256'),(native/name,'native_source_sha256'),(generated/name,'generated_sha256')]:
            if digest(path)!=expected[key]:raise ValueError(f'Input hash mismatch: {path}')
        raw=rgba(repo/'frames'/name);base=rgba(baseline/name);n=rgba(native/name);g=rgba(generated/name)
        assert n.size==(400,496) and raw.size==CANVAS and base.size==CANVAS
        reproduced=place_native(n)
        assert np.array_equal(np.array(reproduced),np.array(raw)),f'Native/runtime mismatch {name}'
        registered=place_native(g)
        result,amask,rmask,stats=repair(raw,base,registered)
        result.save(out/'frames'/name)
        if digest(out/'frames'/name)!=expected['approved_output_sha256']:
            raise ValueError(f'Reproduced PNG differs from validated output: {name}')
        Image.fromarray(amask.astype(np.uint8)*255).save(out/'alpha_masks'/name)
        Image.fromarray(rmask.astype(np.uint8)*255).save(out/'rgb_masks'/name)
        registered.save(out/'registered'/name)
        draw_compare(out/'comparisons'/name,raw,base,registered,result,amask,rmask)
        row={'name':name,'raw_sha256':digest(repo/'frames'/name),'base_cache_sha256':digest(baseline/name),'native_sha256':digest(native/name),'generated_sha256':digest(generated/name),'generated_size':list(g.size),'generated_alpha_range':list(g.getchannel('A').getextrema()),'output_sha256':digest(out/'frames'/name),'alpha_repair_mask_path':str(out/'alpha_masks'/name),'alpha_repair_mask_sha256':digest(out/'alpha_masks'/name),'rgb_edit_mask_path':str(out/'rgb_masks'/name),'rgb_edit_mask_sha256':digest(out/'rgb_masks'/name),'registered_donor_path':str(out/'registered'/name),'registered_donor_sha256':digest(out/'registered'/name),'stats':stats}
        (out/'reports'/(Path(name).stem+'.json')).write_text(json.dumps(row,indent=2))
        rows.append({**row,'stats':{k:v for k,v in stats.items() if k!='donors'}})
        print(json.dumps({'frame':name,**{k:v for k,v in stats.items() if k not in ['donors','alpha_components']}},indent=2))
    report={'schema':1,'purpose':'Narrow original-frame RGB repair with explicit white-background alpha exceptions; generated pose/body never substituted','registration':{'native_canvas':[400,496],'crop':CROP,'placed_size':PLACED,'offset':OFFSET,'canvas':CANVAS,'resample':'Pillow RGBa premultiplied Lanczos'},'alpha_rule':{'original_alpha_gt':16,'min_rgb_gte':200,'rgb_range_lte':35,'component_connectivity':8,'component_min_pixels':3,'component_seed_min_rgb_gte':220,'component_seed_rgb_range_lte':25,'registered_generation_alpha_lt':16,'generated_alpha_overlap_required_regions':['gun_gap','inner_legs'],'manual_reviewed_alpha_zero_regions':['hair_upper','hair_lower'],'manual_hair_review_basis':'Native original and generated reference enlarged comparison; clear original background in brown-hair gaps; source RGB threshold and component seeds unchanged; face, arm, ivory and warm hair pixels excluded','rois':GAP_ROIS,'operation':'decrease to min(original alpha, registered generated alpha); no increases. Manually reviewed hair neutral-white components in the two narrow behind-hair ROIs are set to alpha0, including generated-hair overlap. Face/outfit excluded.'},'rgb_rule':{'band':'Chebyshev radius3 around original alpha<16 or approved alpha mask','base':'immutable GAME062 edge_repair/baseline','crown_y_lt':28,'crown_min_rgb_gte':205,'crown_rgb_range_lte':25,'crown_mixed_halo':'One-pixel Chebyshev neighbours of strict-white pixels, still minRGB>=135/range<=75 and local material/luma safety gates' ,'face_ivory_exclusion':{'x_gte':100,'y_gte':28,'y_lt':105},'usual_target_min_rgb_gte':135,'usual_target_rgb_range_lte':75,'donor_max_radius':8,'original_donor_alpha_5x5_min':240,'original_donor_alpha_min':250,'generated_donor_alpha_min':230,'original_and_generated_material_luma_max':155,'minimum_luma_drop':35,'maximum_material_rgb_rms_delta':45},'frames':rows}
    (out/'manifest.json').write_text(json.dumps(report,indent=2))

if __name__=='__main__':main()
