"""Exact source/file preservation and unretouched comparison boards."""
import hashlib
import json
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[5]
PREV=HERE.parent/'face_surface_v2'
OUT=HERE/'review'
FONT=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',17)

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def panel(c,path,xy,label,crop=None,size=(512,640)):
    im=Image.open(path).convert('RGBA')
    if crop:
        im=im.crop(crop);r=min(size[0]/im.width,size[1]/im.height)
        im=im.resize((round(im.width*r),round(im.height*r)),Image.Resampling.NEAREST)
    else:im.thumbnail(size,Image.Resampling.LANCZOS)
    c.paste(im,(xy[0],xy[1]+30),im);ImageDraw.Draw(c).text(xy,label,font=FONT,fill='black')

def main():
    author=json.loads((HERE.parent/'face_surface_v1/surface_authoring.json').read_text())
    for r in author['references']:assert sha(ROOT/r['path'])==r['sha256']
    build=json.loads((HERE/'build_result.json').read_text());reopen=json.loads((HERE/'reopen_result.json').read_text())
    assert sha(PREV/'viya_face_surface_transfer.blend')==build['input_sha256']
    assert sha(HERE/'viya_face_expression.blend')==build['output_sha256']==reopen['output_sha256']
    for maps in build['after_active_texture_hashes'].values():
        for name,h in maps.items():assert sha(HERE/'textures'/name)==h
    for name in ['eye_screen_left.png','eye_screen_right.png']:assert sha(HERE/'textures'/name)==sha(PREV/'textures'/name)
    a=Image.open(OUT/'color_three_quarter.png').convert('RGBA');b=Image.open(OUT/'color_three_quarter_reopened.png').convert('RGBA')
    assert a.size==b.size and a.tobytes()==b.tobytes()
    src=ROOT/'assets/characters/plan_b_viya/candidate_03/references/front.png'
    c=Image.new('RGB',(1536,640),(242,239,233))
    panel(c,src,(8,8),'Unchanged source / nearest-neighbor crop',crop=(680,120,860,290),size=(432,408))
    panel(c,PREV/'review/color_front.png',(520,8),'Before / same geometry and camera',crop=(118,236,398,478),size=(496,429))
    panel(c,OUT/'color_front.png',(1032,8),'Current / brow and mouth material',crop=(118,236,398,478),size=(496,429))
    ImageDraw.Draw(c).text((10,600),'Different source projection. No hair authored. No numerical likeness or producer approval claim.',font=FONT,fill='black')
    c.save(OUT/'source_before_after.png')
    c=Image.new('RGB',(1024,700),(218,216,212))
    panel(c,PREV/'review/color_front.png',(8,8),'Before: stacked brow / generic mouth')
    panel(c,OUT/'color_front.png',(520,8),'Current: one composite / source mouth RGB')
    ImageDraw.Draw(c).text((10,675),'Existing geometry, UV, controls, eye and lash pixels retained.',font=FONT,fill='black');c.save(OUT/'before_after.png')
    c=Image.new('RGB',(1536,1040),(218,216,212));views=['front','three_quarter','three_quarter_opposite','screen_left_profile','screen_right_profile','game_high_angle']
    for i,v in enumerate(views):panel(c,OUT/('color_'+v+'.png'),((i%3)*512+8,(i//3)*500+5),v,size=(384,460))
    ImageDraw.Draw(c).text((10,1010),'Head-only studio review. Rig, engine material, game and device unverified.',font=FONT,fill='black');c.save(OUT/'surface_views.png')
    c=Image.new('RGB',(1536,700),(218,216,212))
    for i,v in enumerate(['front','three_quarter','three_quarter_opposite']):panel(c,OUT/('unlit_'+v+'.png'),(i*512+8,8),'Unlit / '+v)
    c.save(OUT/'unlit_views.png')
    c=Image.new('RGB',(1536,540),(242,239,233))
    for i,(path,label) in enumerate([(src,'Source pixels'),(PREV/'review/color_front.png','Before'),(OUT/'color_front.png','Current')]):
        panel(c,path,(i*512+8,8),label+' / brows',crop=(710,140,824,161) if i==0 else (140,255,372,289),size=(496,140))
        panel(c,path,(i*512+8,210),label+' / mouth',crop=(735,210,802,242) if i==0 else (200,377,310,420),size=(496,235))
    ImageDraw.Draw(c).text((10,500),'Crops only, no source warp or face alignment; different projection/resolution.',font=FONT,fill='black');c.save(OUT/'feature_details.png')
    # Preserve raw source beside a distinct annotation overlay.
    crop=(735,210,802,242);raw=Image.open(src).convert('RGB').crop(crop).resize((938,448),Image.Resampling.NEAREST)
    annotation=raw.copy();d=ImageDraw.Draw(annotation);reg=json.loads((HERE/'feature_registration.json').read_text())
    points=[((x-crop[0])*14,(y-crop[1])*14) for x,y in reg['mouth']['source_points']]
    d.line(points,fill='#00aaff',width=2)
    for x,y in points:d.ellipse((x-3,y-3,x+3,y+3),outline='#00aaff',width=1)
    c=Image.new('RGB',(958,1010),(242,239,233));c.paste(raw,(10,35));c.paste(annotation,(10,520));d=ImageDraw.Draw(c)
    d.text((10,8),'Unchanged mouth source / 14x nearest-neighbor crop',font=FONT,fill='black')
    d.text((10,492),'Separate source contour annotation / native source samples',font=FONT,fill='black');c.save(OUT/'mouth_source_trace.png')
    r={'four_source_hashes_match':True,'input_blend_sha256_unchanged':True,'all_geometry_controls_and_uv_equal':reopen['all_geometry_controls_uv_equal'],'active_packed_png_hashes_match_disk':True,'eye_pngs_byte_identical':True,'reopened_decoded_rgba_identical':True,'decoded_changed_bytes':0,'scope':'Preservation and persistence only; not likeness/rig/game/device acceptance.'}
    (HERE/'preservation_result.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r))

if __name__=='__main__':main()
