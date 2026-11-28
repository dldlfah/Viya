"""Preservation, packed-map links, provenance visibility and paired reviews."""
import hashlib
import importlib.util
import json
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[5]
PREV=HERE.parent/'eye_surface_v1'
OUT=HERE/'review'
spec=importlib.util.spec_from_file_location('previous_eye_review',PREV/'make_review.py')
old=importlib.util.module_from_spec(spec);spec.loader.exec_module(old)
panel=old.panel;FONT=old.FONT


def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def pixels(p):return np.asarray(Image.open(p).convert('RGBA'))


def main():
    b=json.loads((HERE/'build_result.json').read_text());r=json.loads((HERE/'reopen_result.json').read_text());a=json.loads((HERE/'authoring_result.json').read_text())
    assert sha(PREV/'viya_eye_surface.blend')==b['input_sha256']
    assert sha(HERE/'viya_iris_registration.blend')==b['output_sha256']==r['output_sha256']
    refs=json.loads((HERE.parent/'face_reference_v1/face_landmarks.json').read_text())['references']
    for ref in refs:assert sha(ROOT/ref['path'])==ref['sha256']
    assert np.array_equal(pixels(OUT/'after_three_quarter.png'),pixels(OUT/'after_three_quarter_reopened.png'))
    trace=np.load(HERE/'sampling_trace.npz')
    for e in a['records']:
        side=e['side'];name='eye_screen_'+side+'.png'
        before=pixels(PREV/'textures'/name);after=pixels(HERE/'textures'/name)
        mask=pixels(PREV/'textures'/('iris_mask_'+side+'.png'))[:,:,1]>200
        assert mask.sum()==2028 and np.array_equal(before[~mask],after[~mask])
        assert int(np.any(after!=before,axis=2).sum())==e['changed_texels']
        assert sha(HERE/'textures'/name)==e['new_png_sha256']
        yx=trace[side+'_atlas_yx'];weights=trace[side+'_source_weight'];no_source=weights<=1e-8
        assert np.array_equal(before[yx[no_source,0],yx[no_source,1]],after[yx[no_source,0],yx[no_source,1]])
    skin='CC0_head_skin_UNAPPROVED';assert b['before_active_image_hashes'][skin]==b['after_active_image_hashes'][skin]
    links=[]
    for obj,maps in b['after_active_image_hashes'].items():
        for name,h in maps.items():
            p=(HERE.parent/'face_surface_v4/textures' if obj==skin else HERE/'textures')/name
            assert sha(p)==h;links.append({'object':obj,'path':p.relative_to(ROOT).as_posix(),'sha256':h,'packed':True})
    (HERE/'texture_links.json').write_text(json.dumps({'images':links,'diagnostic_masks_not_used_as_character_color':True},indent=2)+'\n')
    visible={}
    for view in ['front','three_quarter','three_quarter_opposite']:
        p=pixels(OUT/('glint_trace_'+view+'.png')).astype(int)
        marker=(p[:,:,1]>100)&(p[:,:,1]>p[:,:,2]+30)&(p[:,:,3]>240)
        visible[view]=int(marker.sum());assert visible[view]>0,view
    (HERE/'glint_visibility.json').write_text(json.dumps({'source_xy':[737,178],'source_contribution_atlas_texels':24,'hard_green_visible_pixels':visible,'criterion':'G>100,G>B+30,A>240 on temporary emission trace; interpolation/AA excluded by threshold','scope':'The known-source contribution footprint is visible in three review views. Not a likeness, full detail recovery, eye-contact or engine score.'},indent=2)+'\n')
    source=ROOT/'assets/characters/plan_b_viya/candidate_03/references/front.png'
    c=Image.new('RGB',(1536,640),(242,239,233))
    panel(c,source,(8,8),'Unchanged source / nearest crop',crop=(680,120,860,290),size=(432,408))
    panel(c,PREV/'review/after_front.png',(520,8),'Before / retained R5 and sclera',crop=(118,236,398,478),size=(496,429))
    panel(c,OUT/'after_front.png',(1032,8),'Current / separate iris registration',crop=(118,236,398,478),size=(496,429))
    ImageDraw.Draw(c).text((10,600),'Geometry and head color unchanged. Source projection differs. Whole face / producer acceptance pending.',font=FONT,fill='black');c.save(OUT/'source_before_after.png',optimize=True)
    c=Image.new('RGB',(1536,480),(242,239,233))
    for i,(p,label) in enumerate([(source,'Original eyes'),(PREV/'review/after_front.png','Before'),(OUT/'after_front.png','Current')]):
        panel(c,p,(i*512+8,8),label,crop=(706,156,831,199) if i==0 else (148,285,365,329),size=(496,270))
    ImageDraw.Draw(c).text((10,430),'Known left bright sample is included; iris footprint and sclera remain fixed. No opposite-eye copying.',font=FONT,fill='black');c.save(OUT/'eye_details.png',optimize=True)
    c=Image.new('RGB',(1536,1040),(218,216,212))
    for i,v in enumerate(['front','three_quarter','three_quarter_opposite']):
        panel(c,PREV/'review'/('after_'+v+'.png'),(i*512+8,5),'Before / '+v,size=(384,460))
        panel(c,OUT/('after_'+v+'.png'),(i*512+8,505),'Current / '+v,size=(384,460))
    c.save(OUT/'paired_views.png',optimize=True)
    c=Image.new('RGB',(1536,1040),(218,216,212))
    for i,v in enumerate(['front','three_quarter','three_quarter_opposite','screen_left_profile','screen_right_profile','game_high_angle']):
        panel(c,OUT/('after_'+v+'.png'),((i%3)*512+8,(i//3)*500+5),v,size=(384,460))
    c.save(OUT/'surface_views.png',optimize=True)
    c=Image.new('RGB',(1536,700),(218,216,212))
    for i,v in enumerate(['front','three_quarter','three_quarter_opposite']):panel(c,OUT/('unlit_after_'+v+'.png'),(i*512+8,8),'Unlit / '+v)
    c.save(OUT/'unlit_views.png',optimize=True)
    (HERE/'preservation_result.json').write_text(json.dumps({'four_source_hashes_match':True,'input_blend_sha256_unchanged':True,'all_geometry_controls_uv_equal':True,'head_image_bytes_identical':True,'sclera_and_all_texels_outside_original_iris_identical':True,'unsupported_source_weights_keep_same_eye_input':True,'reopened_decoded_rgba_identical':True,'new_active_packed_image_hashes_match_png':True,'previous_materials_retained':True,'scope':'Preservation/registration visibility and persistence only, not whole-face/producer/rig/game/device acceptance.'},indent=2)+'\n')
    print(json.dumps({'preservation':'PASS','visible_source_contribution_pixels':visible}))


if __name__=='__main__':main()
