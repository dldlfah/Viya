"""Unretouched source/render review and exact source/persistence checks."""
import importlib.util
import json
from pathlib import Path
from PIL import Image,ImageDraw

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[5]
PREV=HERE.parent/'face_surface_v3'
OUT=HERE/'review'
spec=importlib.util.spec_from_file_location('previous_review_utilities',PREV/'make_review.py')
old=importlib.util.module_from_spec(spec);spec.loader.exec_module(old)
panel=old.panel;FONT=old.FONT;sha=old.sha

def main():
    author=json.loads((HERE.parent/'face_surface_v1/surface_authoring.json').read_text())
    for r in author['references']:assert sha(ROOT/r['path'])==r['sha256']
    build=json.loads((HERE/'build_result.json').read_text());reopen=json.loads((HERE/'reopen_result.json').read_text())
    assert sha(PREV/'viya_face_expression.blend')==build['input_sha256']
    assert sha(HERE/'viya_face_details.blend')==build['output_sha256']==reopen['output_sha256']
    for maps in build['after_active_texture_hashes'].values():
        for name,h in maps.items():assert sha(HERE/'textures'/name)==h
    for name in ['eye_screen_left.png','eye_screen_right.png']:assert sha(HERE/'textures'/name)==sha(PREV/'textures'/name)
    a=Image.open(OUT/'color_three_quarter.png').convert('RGBA');b=Image.open(OUT/'color_three_quarter_reopened.png').convert('RGBA')
    assert a.size==b.size and a.tobytes()==b.tobytes()
    src=ROOT/'assets/characters/plan_b_viya/candidate_03/references/front.png'
    c=Image.new('RGB',(1536,640),(242,239,233))
    panel(c,src,(8,8),'Unchanged source / nearest-neighbor crop',crop=(680,120,860,290),size=(432,408))
    panel(c,PREV/'review/color_front.png',(520,8),'Before / same geometry and camera',crop=(118,236,398,478),size=(496,429))
    panel(c,OUT/'color_front.png',(1032,8),'Current / eyelid and nose color details',crop=(118,236,398,478),size=(496,429))
    ImageDraw.Draw(c).text((10,600),'Different source projection. Hair unmade. Source not warped or mirrored; no numerical likeness claim.',font=FONT,fill='black');c.save(OUT/'source_before_after.png')
    c=Image.new('RGB',(1024,700),(218,216,212))
    panel(c,PREV/'review/color_front.png',(8,8),'Before: existing brow/lash/mouth')
    panel(c,OUT/'color_front.png',(520,8),'Current: local crease/shade/nose overlay')
    ImageDraw.Draw(c).text((10,675),'Shape, UV, iris PNGs, brow/mouth and protected upper-lash pixels retained.',font=FONT,fill='black');c.save(OUT/'before_after.png')
    c=Image.new('RGB',(1536,1040),(218,216,212));views=['front','three_quarter','three_quarter_opposite','screen_left_profile','screen_right_profile','game_high_angle']
    for i,v in enumerate(views):panel(c,OUT/('color_'+v+'.png'),((i%3)*512+8,(i//3)*500+5),v,size=(384,460))
    ImageDraw.Draw(c).text((10,1010),'Head-only studio comparison. No rig, engine, game, device or producer acceptance.',font=FONT,fill='black');c.save(OUT/'surface_views.png')
    c=Image.new('RGB',(1536,700),(218,216,212))
    for i,v in enumerate(['front','three_quarter','three_quarter_opposite']):panel(c,OUT/('unlit_'+v+'.png'),(i*512+8,8),'Unlit / '+v)
    c.save(OUT/'unlit_views.png')
    c=Image.new('RGB',(1536,540),(242,239,233))
    for i,(path,label) in enumerate([(src,'Source pixels'),(PREV/'review/color_front.png','Before'),(OUT/'color_front.png','Current')]):
        panel(c,path,(i*512+8,8),label+' / eyes',crop=(706,156,831,199) if i==0 else (148,285,365,329),size=(496,170))
        panel(c,path,(i*512+8,230),label+' / nose',crop=(750,192,790,218) if i==0 else (222,325,291,370),size=(430,235))
    ImageDraw.Draw(c).text((10,500),'Crops only; different source projection/resolution. No facial image alignment.',font=FONT,fill='black');c.save(OUT/'feature_details.png')
    reg=json.loads((HERE/'feature_registration.json').read_text());crop=(700,150,835,218)
    raw=Image.open(src).convert('RGB').crop(crop).resize((810,408),Image.Resampling.NEAREST);overlay=raw.copy();d=ImageDraw.Draw(overlay)
    for color,features in [('#00aaff',reg['lower_lids']),('#ff9900',reg['upper_creases'])]:
        for f in features:
            pts=[((x-crop[0])*6,(y-crop[1])*6) for x,y in f['source_points']];d.line(pts,fill=color,width=2)
            for x,y in pts:d.ellipse((x-3,y-3,x+3,y+3),outline=color,width=1)
    for f in reg['nose_marks']:
        x0,y0,x1,y1=f['source_crop'];d.rectangle(((x0-crop[0])*6,(y0-crop[1])*6,(x1-crop[0])*6,(y1-crop[1])*6),outline='#00aa55',width=2)
    c=Image.new('RGB',(830,930),(242,239,233));c.paste(raw,(10,35));c.paste(overlay,(10,495));d=ImageDraw.Draw(c)
    d.text((10,8),'Unchanged source pixels / 6x nearest-neighbor crop',font=FONT,fill='black')
    d.text((10,463),'Separate overlay: blue lower lids / orange creases / green nose patches',font=FONT,fill='black')
    d.text((10,905),'Source native pixels only. Hidden features not reconstructed.',font=FONT,fill='black');c.save(OUT/'source_traces.png')
    if (HERE/'sensitivity_result.json').exists():
        sensitivity=json.loads((HERE/'sensitivity_result.json').read_text());assert sensitivity['input_sha256']==build['output_sha256']
        c=Image.new('RGB',(1024,1030),(242,239,233))
        entries=[(src,'Source / unchanged pixels',(680,120,860,290)),(OUT/'color_front.png','Head light35% / texture65%',(118,236,398,478)),(OUT/'head_lit15_front.png','Diagnostic: light15% / texture85%',(118,236,398,478)),(OUT/'unlit_front.png','Diagnostic: head texture100%',(118,236,398,478))]
        for i,(path,label,crop) in enumerate(entries):panel(c,path,((i%2)*512+8,(i//2)*500+8),label,crop=crop,size=(496,429))
        ImageDraw.Draw(c).text((10,1000),'Head-only material hypotheses; current saved material unchanged.',font=FONT,fill='black');c.save(OUT/'material_sensitivity.png')
        c=Image.new('RGB',(1536,1040),(242,239,233))
        entries=[(src,'Source / unchanged pixels',(680,120,860,290)),(OUT/'color_front.png','Existing front / roll0',(118,236,398,478)),(OUT/'front_roll_hypothesis.png','Hypothesis: front / roll-5.57',(118,236,398,478)),(OUT/'yaw_minus12_roll_hypothesis.png','Hypothesis: yaw-12 / roll-5.57',(118,236,398,478)),(OUT/'yaw_plus12_roll_hypothesis.png','Hypothesis: yaw+12 / roll-5.57',(118,236,398,478)),(OUT/'pitch_plus8_roll_hypothesis.png','Hypothesis: pitch+8 / roll-5.57',(118,236,398,478))]
        for i,(path,label,crop) in enumerate(entries):panel(c,path,((i%3)*512+8,(i//3)*500+8),label,crop=crop,size=(496,429))
        ImageDraw.Draw(c).text((10,1010),'Fixed crop. No source camera recovery, image alignment, selected game view or shape fit.',font=FONT,fill='black');c.save(OUT/'view_sensitivity.png')
    r={'four_source_hashes_match':True,'input_blend_sha256_unchanged':True,'all_geometry_controls_and_uv_equal':reopen['all_geometry_controls_uv_equal'],'active_packed_png_hashes_match_disk':True,'eye_pngs_byte_identical':True,'reopened_decoded_rgba_identical':True,'decoded_changed_bytes':0,'scope':'Preservation/persistence only; not likeness/rig/game/device acceptance.'}
    (HERE/'preservation_result.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r))

if __name__=='__main__':main()
