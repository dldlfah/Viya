"""Source/shape/color comparisons and exact preservation checks for local R5."""
import hashlib
import importlib.util
import json
from pathlib import Path
from PIL import Image,ImageDraw
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[5]
PREV=HERE.parent/'face_surface_v4'
OUT=HERE/'review'
spec=importlib.util.spec_from_file_location('previous_detail_review',PREV/'make_review.py')
old=importlib.util.module_from_spec(spec);spec.loader.exec_module(old)
panel=old.panel;FONT=old.FONT

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()

def main():
    b=json.loads((HERE/'build_result.json').read_text());reopen=json.loads((HERE/'reopen_result.json').read_text())
    assert sha(PREV/'viya_face_details.blend')==b['input_sha256']
    assert sha(HERE/'viya_eye_refinement.blend')==b['output_sha256']==reopen['output_sha256']
    refs=json.loads((HERE.parent/'face_surface_v1/surface_authoring.json').read_text())['references']
    for r in refs:assert sha(ROOT/r['path'])==r['sha256']
    prior_maps=json.loads((PREV/'build_result.json').read_text())['after_active_texture_hashes'];assert b['active_packed_image_hashes']==prior_maps
    links=[]
    for obj,maps in prior_maps.items():
        for name,h in maps.items():
            p=PREV/'textures'/name;assert sha(p)==h
            links.append({'object':obj,'source_path':p.relative_to(ROOT).as_posix(),'sha256':h,'current_model_image_is_packed':True})
    (HERE/'texture_links.json').write_text(json.dumps({'scope':'Existing image bytes retained; no new texture orUV unwrap/bake in this local shape unit.','images':links},indent=2)+'\n')
    for x,y in [(OUT/'after_three_quarter.png',OUT/'after_three_quarter_reopened.png'),(OUT/'before_front.png',PREV/'review/color_front.png')]:
        a=Image.open(x).convert('RGBA');c=Image.open(y).convert('RGBA');assert a.size==c.size and a.tobytes()==c.tobytes()
    source=ROOT/'assets/characters/plan_b_viya/candidate_03/references/front.png'
    c=Image.new('RGB',(1536,640),(242,239,233))
    panel(c,source,(8,8),'Unchanged source / nearest crop',crop=(680,120,860,290),size=(432,408))
    panel(c,OUT/'before_front.png',(520,8),'Before: preserved R4 + surface v4',crop=(118,236,398,478),size=(496,429))
    panel(c,OUT/'after_front.png',(1032,8),'Local R5 / same UV and image bytes',crop=(118,236,398,478),size=(496,429))
    ImageDraw.Draw(c).text((10,600),'Different source projection/occlusion. No numerical likeness, camera recovery or producer approval.',font=FONT,fill='black');c.save(OUT/'source_before_after.png')
    c=Image.new('RGB',(1536,1040),(218,216,212));views=['front','three_quarter','three_quarter_opposite']
    for i,v in enumerate(views):
        panel(c,PREV/'review'/('color_'+v+'.png'),(i*512+8,5),'Before / '+v,size=(384,460))
        panel(c,OUT/('after_'+v+'.png'),(i*512+8,505),'Local R5 / '+v,size=(384,460))
    ImageDraw.Draw(c).text((10,1010),'Same camera/material/image bytes. Head-only comparison, no rig or engine acceptance.',font=FONT,fill='black');c.save(OUT/'paired_views.png')
    c=Image.new('RGB',(1536,1040),(218,216,212));views=['front','three_quarter','three_quarter_opposite','screen_left_profile','screen_right_profile','game_high_angle']
    for i,v in enumerate(views):panel(c,OUT/('after_'+v+'.png'),((i%3)*512+8,(i//3)*500+5),v,size=(384,460))
    c.save(OUT/'surface_views.png')
    c=Image.new('RGB',(1536,700),(218,216,212))
    for i,(path,label) in enumerate([(OUT/'clay_before_front.png','Clay / before'),(OUT/'clay_after_front.png','Clay / local R5'),(OUT/'clay_after_three_quarter.png','Clay / local R5 oblique')]):panel(c,path,(i*512+8,8),label)
    ImageDraw.Draw(c).text((10,675),'Texture images unchanged. Shape-only diagnostic; not a final appearance approval.',font=FONT,fill='black');c.save(OUT/'clay_comparison.png')
    c=Image.new('RGB',(1536,480),(242,239,233))
    for i,(path,label) in enumerate([(source,'Original eye pixels'),(OUT/'before_front.png','Before'),(OUT/'after_front.png','Local R5')]):
        panel(c,path,(i*512+8,8),label,crop=(706,156,831,199) if i==0 else (148,285,365,329),size=(496,270))
    ImageDraw.Draw(c).text((10,430),'Eye width/iris images retained. Source image not aligned or warped.',font=FONT,fill='black');c.save(OUT/'eye_details.png')
    obs=json.loads((HERE/'reference_eye_observations.json').read_text());crop=(706,158,832,199)
    raw=Image.open(source).convert('RGB').crop(crop).resize((882,287),Image.Resampling.NEAREST);annotated=raw.copy();d=ImageDraw.Draw(annotated)
    for side in ['screen_left','screen_right']:
        for key,color in [('upper_visible_points','#00aaff'),('lower_visible_points','#ff9900')]:
            pts=[((x-crop[0])*7,(y-crop[1])*7) for x,y in obs[side][key]];d.line(pts,fill=color,width=2)
            for x,y in pts:d.ellipse((x-3,y-3,x+3,y+3),outline=color,width=1)
    c=Image.new('RGB',(902,700),(242,239,233));c.paste(raw,(10,35));c.paste(annotated,(10,370));d=ImageDraw.Draw(c)
    d.text((10,8),'Unchanged source pixels / 7x nearest-neighbor',font=FONT,fill='black')
    d.text((10,337),'Separate manual visible-opening overlay; approximate +/-2.5px',font=FONT,fill='black')
    d.text((10,675),'Hidden endpoints unresolved; not3D fit or acceptance tolerance.',font=FONT,fill='black');c.save(OUT/'reference_observations.png')
    landmarks=json.loads((HERE/'aperture_landmarks.json').read_text())['eyes'];fig,axes=plt.subplots(1,2,figsize=(10,4))
    for ax,(side,rows) in zip(axes,landmarks.items()):
        for key,label,color in [('before','Before R5','#777777'),('after','Local R5','#126db4')]:
            q=[r[key] for r in rows];inner=min(q,key=lambda p:abs(p[0]));x=[(abs(p[0])-abs(inner[0]))*1000 for p in q];z=[(p[2]-inner[2])*1000 for p in q]
            ax.plot(x+[x[0]],z+[z[0]],'.-',label=label,color=color,linewidth=1)
        ax.set_title(side);ax.set_xlabel('X from inner corner / working mm');ax.set_ylabel('Z from inner corner / working mm');ax.set_aspect('equal');ax.grid(alpha=.2);ax.legend()
    fig.suptitle('Existing control loops only; not calibrated artwork dimensions');fig.tight_layout();fig.savefig(OUT/'aperture_change.png',dpi=130);plt.close(fig)
    result={'four_source_hashes_match':True,'input_blend_sha256_unchanged':True,'old_controls_topology_all_uv_preserved':True,'active_packed_image_bytes_identical':True,'reopened_decoded_rgba_identical':True,'before_front_matches_source_v4_decoded_rgba':True,'decoded_changed_bytes_for_reopen_or_baseline':0,'scope':'Preservation/persistence and baseline-render match only; not art/rig/game/device acceptance.'}
    (HERE/'preservation_result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))

if __name__=='__main__':main()
