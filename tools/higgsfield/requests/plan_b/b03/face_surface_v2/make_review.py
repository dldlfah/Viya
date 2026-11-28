"""Assemble unretouched render/source comparisons and verify preservation."""
import hashlib
import json
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[5]
PREV=HERE.parent/'face_surface_v1'
OUT=HERE/'review'
FONT=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',17)

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()

def panel(canvas,path,xy,caption,crop=None,size=(512,640)):
    im=Image.open(path).convert('RGBA')
    if crop:
        im=im.crop(crop)
        ratio=min(size[0]/im.width,size[1]/im.height)
        im=im.resize((round(im.width*ratio),round(im.height*ratio)),Image.Resampling.NEAREST)
    else:im.thumbnail(size,Image.Resampling.LANCZOS)
    canvas.paste(im,(xy[0],xy[1]+30),im)
    ImageDraw.Draw(canvas).text(xy,caption,font=FONT,fill='black')

def main():
    author=json.loads((PREV/'surface_authoring.json').read_text())
    for r in author['references']:assert sha(ROOT/r['path'])==r['sha256']
    build=json.loads((HERE/'build_result.json').read_text())
    reopen=json.loads((HERE/'reopen_result.json').read_text())
    assert sha(PREV/'viya_face_surface.blend')==build['input_sha256']
    assert sha(HERE/'viya_face_surface_transfer.blend')==build['output_sha256']==reopen['output_sha256']
    before=Image.open(OUT/'color_three_quarter.png').convert('RGBA')
    after=Image.open(OUT/'color_three_quarter_reopened.png').convert('RGBA')
    assert before.size==after.size and before.tobytes()==after.tobytes()
    for name in ['eye_screen_left.png','eye_screen_right.png']:
        assert sha(HERE/'textures'/name)==sha(PREV/'textures'/name)
    for obj,maps in build['after_active_texture_hashes'].items():
        for name,h in maps.items():assert sha(HERE/'textures'/name)==h
    c=Image.new('RGB',(1536,700),(218,216,212))
    for i,(path,label) in enumerate([(PREV/'review/color_front.png','Previous: authored curve brows/lashes'),(HERE/'trial01_disconnected_brow/color_front.png','Rejected: disconnected hidden continuation'),(OUT/'color_front.png','Current: source RGB + joined continuation')]):
        panel(c,path,(i*512+8,8),label)
    ImageDraw.Draw(c).text((10,675),'Same mesh, controls, UV, camera and iris maps. Material-only revision; no face approval.',font=FONT,fill='black')
    c.save(OUT/'before_after.png')
    c=Image.new('RGB',(1024,600),(242,239,233))
    src=ROOT/'assets/characters/plan_b_viya/candidate_03/references/front.png'
    im=Image.open(src).crop((680,120,860,290)).resize((360,340),Image.Resampling.NEAREST);c.paste(im,(10,45))
    ImageDraw.Draw(c).text((10,8),'Original source: unchanged 2x crop',font=FONT,fill='black')
    panel(c,OUT/'color_front.png',(430,8),'Current: face crop / hair not authored',crop=(118,236,398,478),size=(560,484))
    ImageDraw.Draw(c).text((10,560),'Different projections. Source not warped. Remaining expression differences are not passed.',font=FONT,fill='black')
    c.save(OUT/'source_vs_transfer.png')
    c=Image.new('RGB',(1536,1040),(218,216,212))
    views=['front','three_quarter','three_quarter_opposite','screen_left_profile','screen_right_profile','game_high_angle']
    for i,v in enumerate(views):panel(c,OUT/('color_'+v+'.png'),((i%3)*512+8,(i//3)*500+5),v,size=(384,460))
    ImageDraw.Draw(c).text((10,1010),'Head-only studio comparison. No rig, game, device or producer acceptance.',font=FONT,fill='black');c.save(OUT/'surface_views.png')
    c=Image.new('RGB',(1536,700),(218,216,212))
    for i,v in enumerate(['front','three_quarter','three_quarter_opposite']):panel(c,OUT/('unlit_'+v+'.png'),(i*512+8,8),'Unlit / '+v)
    c.save(OUT/'unlit_views.png')
    # Annotated coordinates are a separate overlay. Raw source is retained beside it.
    crop=(700,137,835,196);raw=Image.open(src).convert('RGB').crop(crop).resize((810,354),Image.Resampling.NEAREST)
    overlay=raw.copy();d=ImageDraw.Draw(overlay);reg=json.loads((HERE/'feature_registration.json').read_text())
    for color,features in [('#00aaff',reg['brows']),('#ff9900',reg['lashes'])]:
        for f in features:
            points=[((x-crop[0])*6,(y-crop[1])*6) for x,y in f['source_points']]
            d.line(points,fill=color,width=2)
            for x,y in points:d.ellipse((x-3,y-3,x+3,y+3),outline=color,width=1)
    c=Image.new('RGB',(830,825),(242,239,233));c.paste(raw,(10,35));c.paste(overlay,(10,425));d=ImageDraw.Draw(c)
    d.text((10,8),'Actual source pixels / 6x nearest-neighbor crop',font=FONT,fill='black')
    d.text((10,395),'Blue: visible brow trace. Orange: upper lash trace. Separate overlay.',font=FONT,fill='black')
    d.text((10,790),'Hair-occluded brow extensions are authored; no hidden anatomy measured.',font=FONT,fill='black');c.save(OUT/'source_traces.png')
    result={'four_source_hashes_match':True,'input_blend_sha256_unchanged':True,'all_geometry_controls_and_uv_equal':reopen['all_geometry_controls_uv_equal'],'active_packed_png_hashes_match_disk':True,'eye_pngs_byte_identical':True,'reopened_decoded_rgba_identical':True,'decoded_changed_bytes':0,'scope':'Technical preservation only; no likeness/rig/game/device acceptance.'}
    (HERE/'preservation_result.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result))

if __name__=='__main__':main()
