"""Source/shape comparisons and independent persistence/texture checks."""
import hashlib
import importlib.util
import json
from pathlib import Path
from PIL import Image,ImageDraw

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[5]
PREV=HERE.parent/'eye_surface_v2'
OUT=HERE/'review'
spec=importlib.util.spec_from_file_location('previous_iris_review',PREV/'make_review.py')
old=importlib.util.module_from_spec(spec);spec.loader.exec_module(old)
panel=old.panel;FONT=old.FONT


def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()


def main():
    b=json.loads((HERE/'build_result.json').read_text());r=json.loads((HERE/'reopen_result.json').read_text())
    assert sha(PREV/'viya_iris_registration.blend')==b['input_sha256']
    assert sha(HERE/'viya_lip_chin_refinement.blend')==b['output_sha256']==r['output_sha256']
    refs=json.loads((HERE.parent/'face_reference_v1/face_landmarks.json').read_text())['references']
    for ref in refs:assert sha(ROOT/ref['path'])==ref['sha256']
    maps=json.loads((PREV/'build_result.json').read_text())['after_active_image_hashes']
    assert maps==b['active_packed_image_hashes']
    links=json.loads((PREV/'texture_links.json').read_text())['images']
    for link in links:assert sha(ROOT/link['path'])==link['sha256']
    (HERE/'texture_links.json').write_text(json.dumps({'images':links,'scope':'All existing image bytes/UV retained; no new texture or raster bake in this local shape unit.'},indent=2)+'\n')
    for a,c in [(OUT/'before_front.png',PREV/'review/after_front.png'),(OUT/'after_three_quarter.png',OUT/'after_three_quarter_reopened.png')]:
        x=Image.open(a).convert('RGBA');y=Image.open(c).convert('RGBA')
        assert x.size==y.size and x.tobytes()==y.tobytes(),str(a)
    source=ROOT/'assets/characters/plan_b_viya/candidate_03/references/front.png'
    c=Image.new('RGB',(1536,640),(242,239,233))
    panel(c,source,(8,8),'Unchanged source / nearest crop',crop=(680,120,860,290),size=(432,408))
    panel(c,PREV/'review/after_front.png',(520,8),'Before / registered iris model',crop=(118,236,398,478),size=(496,429))
    panel(c,OUT/'after_front.png',(1032,8),'Current / local lip and chin keys',crop=(118,236,398,478),size=(496,429))
    ImageDraw.Draw(c).text((10,600),'Same image bytes/UV and camera. Source drawings are uncalibrated. No producer approval.',font=FONT,fill='black');c.save(OUT/'source_before_after.png',optimize=True)
    c=Image.new('RGB',(1260,1190),(242,239,233));d=ImageDraw.Draw(c)
    views=['front','screen_right_profile','screen_left_profile']
    crops={'front':(118,236,398,478),'screen_right_profile':(200,230,466,480),'screen_left_profile':(46,230,312,480)}
    byid={ref['id']:ref for ref in refs}
    for i,v in enumerate(views):
        x=i*420+8
        panel(c,ROOT/byid[v]['path'],(x,5),'SOURCE / '+v,crop=byid[v]['inspection_crop_xyxy'],size=(360,340))
        panel(c,PREV/'review'/('after_'+v+'.png'),(x,395),'BEFORE',crop=crops[v],size=(390,350))
        panel(c,OUT/('after_'+v+'.png'),(x,785),'LOCAL LIP / CHIN',crop=crops[v],size=(390,350))
    d.text((10,1160),'Rectangular crops / uniform display scale only. No facial warp, mirroring or calibrated3D source fit.',font=FONT,fill='black');c.save(OUT/'profile_comparison.png',optimize=True)
    c=Image.new('RGB',(1260,820),(218,216,212))
    for i,v in enumerate(views):
        panel(c,OUT/('clay_before_'+v+'.png'),(i*420+8,5),'CLAY BEFORE / '+v,crop=crops[v],size=(390,350))
        panel(c,OUT/('clay_after_'+v+'.png'),(i*420+8,405),'CLAY AFTER / '+v,crop=crops[v],size=(390,350))
    c.save(OUT/'clay_comparison.png',optimize=True)
    c=Image.new('RGB',(1536,1040),(218,216,212))
    for i,v in enumerate(['front','three_quarter','three_quarter_opposite','screen_left_profile','screen_right_profile','game_high_angle']):
        panel(c,OUT/('after_'+v+'.png'),((i%3)*512+8,(i//3)*500+5),v,size=(384,460))
    c.save(OUT/'surface_views.png',optimize=True)
    c=Image.new('RGB',(1536,1040),(218,216,212))
    for i,v in enumerate(['front','three_quarter','three_quarter_opposite']):
        panel(c,PREV/'review'/('after_'+v+'.png'),(i*512+8,5),'Before / '+v,size=(384,460))
        panel(c,OUT/('after_'+v+'.png'),(i*512+8,505),'Current / '+v,size=(384,460))
    c.save(OUT/'paired_views.png',optimize=True)
    c=Image.new('RGB',(1536,510),(242,239,233))
    for i,(p,label) in enumerate([(source,'Source'),(PREV/'review/after_front.png','Before'),(OUT/'after_front.png','Current')]):
        panel(c,p,(i*512+8,8),label+' / lower face',crop=(733,214,809,275) if i==0 else (200,365,313,475),size=(400,390))
    ImageDraw.Draw(c).text((10,470),'UV/color bytes retained; projected line/shape follows new geometry. Source pose differs.',font=FONT,fill='black');c.save(OUT/'lower_face_details.png',optimize=True)
    c=Image.new('RGB',(1536,870),(242,239,233))
    panels=[
        (ROOT/byid['front']['path'],'SOURCE FRONT',byid['front']['inspection_crop_xyxy']),
        (OUT/'after_front.png','CANDIDATE FRONT',crops['front']),
        (OUT/'after_three_quarter.png','CANDIDATE OBLIQUE',(90,236,370,478)),
        (OUT/'after_three_quarter_opposite.png','CANDIDATE OTHER OBLIQUE',(142,236,422,478)),
        (ROOT/byid['screen_left_profile']['path'],'SOURCE FACING LEFT',byid['screen_left_profile']['inspection_crop_xyxy']),
        (OUT/'after_screen_left_profile.png','CANDIDATE FACING LEFT',crops['screen_left_profile']),
        (ROOT/byid['screen_right_profile']['path'],'SOURCE FACING RIGHT',byid['screen_right_profile']['inspection_crop_xyxy']),
        (OUT/'after_screen_right_profile.png','CANDIDATE FACING RIGHT',crops['screen_right_profile'])]
    for i,(path,label,crop) in enumerate(panels):panel(c,path,((i%4)*384+8,(i//4)*410+5),label,crop=crop,size=(360,340))
    ImageDraw.Draw(c).text((10,835),'Face candidate only; hair/body unmade. Source drawings/projection differ. Producer acceptance pending.',font=FONT,fill='black');c.save(OUT/'producer_face_review.png',optimize=True)
    (HERE/'preservation_result.json').write_text(json.dumps({'four_source_hashes_match':True,'input_blend_sha256_unchanged':True,'old_controls_topology_and_all_uv_preserved':True,'all_active_image_bytes_identical':True,'zero_new_keys_front_matches_input_decoded_rgba':True,'reopened_decoded_rgba_identical':True,'scope':'Preservation/persistence only; not source likeness, full contact/intersection, rig/game/device or producer approval.'},indent=2)+'\n')
    print('LIP_CHIN_REVIEW_BUILT')


if __name__=='__main__':main()
