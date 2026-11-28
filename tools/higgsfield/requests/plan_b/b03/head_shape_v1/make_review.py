"""Make factual comparison boards and verify independently reopened renders."""
from pathlib import Path
from PIL import Image,ImageChops,ImageDraw,ImageFont
import hashlib,json

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[5]
TOPO=HERE/"cc0_topology_trial"
FONT="/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"


def tile(path,size=(256,320)):
    im=Image.open(path).convert("RGBA")
    bg=Image.new("RGBA",im.size,"#d8d8d8");bg.alpha_composite(im)
    return bg.convert("RGB").resize(size,Image.Resampling.LANCZOS)


def main():
    checks={}
    for name,p in [("procedural",HERE),("cc0_topology",TOPO)]:
        a=Image.open(p/"review/three_quarter.png").convert("RGBA")
        b=Image.open(p/"review/three_quarter_reopened.png").convert("RGBA")
        assert a.tobytes()==b.tobytes(),name
        checks[name]={"reopened_render_pixels_identical":True}
    (HERE/"pixel_persistence.json").write_text(json.dumps(checks,indent=2)+"\n")
    font=ImageFont.truetype(FONT,16);small=ImageFont.truetype(FONT,15)
    out=Image.new("RGB",(1024,380),"#d8d8d8");d=ImageDraw.Draw(out)
    items=[("Procedural form: not accepted",HERE/"review/front.png"),("CC0 adult basis + nose target",TOPO/"review/base_front.png"),("Reference-proportion study",TOPO/"review/front.png"),("Same study: profile",TOPO/"review/screen_left_profile.png")]
    for i,(label,path) in enumerate(items):
        out.paste(tile(path),(i*256,35));d.text((i*256+5,9),label,fill="black",font=font)
    d.text((8,360),"Different construction routes, same review camera/lighting. No face/producer acceptance. Not an animation.",font=small,fill="black")
    out.save(HERE/"review/construction_routes.png",optimize=True)
    views=[("Front","front"),("Facing right","screen_right_profile"),("Facing left","screen_left_profile"),("Three-quarter","three_quarter"),("Back","back"),("Game 55 degrees","game_high_angle")]
    out=Image.new("RGB",(1536,380),"#d8d8d8");d=ImageDraw.Draw(out)
    for i,(label,name) in enumerate(views):
        out.paste(tile(TOPO/"review"/(name+".png")),(i*256,35));d.text((i*256+6,9),label,fill="black",font=font)
    d.text((8,360),"One editable head/eye study. Hair, original face painting, rig, body and runtime are not delivered.",font=small,fill="black")
    out.save(HERE/"review/topology_views.png",optimize=True)
    source=ROOT/"assets/characters/plan_b_viya/candidate_03/references"
    out=Image.new("RGB",(1140,815),"#eeeae5");d=ImageDraw.Draw(out)
    definitions=[("Front","front",(680,120,860,290),(80,210,432,530)),("Facing right","screen_right_profile",(725,155,905,325),(165,215,495,540)),("Facing left","screen_left_profile",(625,145,805,315),(20,215,350,540))]
    for i,(label,name,src_crop,render_crop) in enumerate(definitions):
        x=10+i*380;d.text((x,12),"REFERENCE: "+label,font=font,fill="black")
        a=Image.open(source/(name+".png")).convert("RGB").crop(src_crop).resize((360,340),Image.Resampling.NEAREST)
        out.paste(a,(x,45));d.text((x,405),"UNAPPROVED TOPOLOGY STUDY",font=font,fill="black")
        raw=Image.open(TOPO/"review"/(name+".png")).convert("RGBA").crop(render_crop)
        bg=Image.new("RGBA",raw.size,"#d8d8d8");bg.alpha_composite(raw)
        bg=bg.convert("RGB");bg.thumbnail((360,340),Image.Resampling.LANCZOS)
        out.paste(bg,(x+(360-bg.width)//2,440))
    d.text((10,790),"Source drawings/cameras are not calibrated. Independent rectangular crops and uniform display scale; no pose warp or mirroring.",font=small,fill="black")
    out.save(HERE/"review/reference_vs_study.png",optimize=True)
    (HERE/"comparison_registration.json").write_text(json.dumps({"scope":"Inspection only, no automatic likeness score; all scale/crop differences remain visible","source_crop_scale":"2x nearest, exact180x170 source crops","render_display":"one uniform thumbnail scale inside360x340; no per-feature warp","views":[{"view":a,"source_crop_xyxy":list(c),"render_crop_xyxy":list(e)} for a,_,c,e in definitions]},indent=2)+"\n")
    (HERE/"CHECKSUMS.sha256").write_text("".join(f"{hashlib.sha256(p.read_bytes()).hexdigest()}  {p.relative_to(HERE).as_posix()}\n" for p in sorted(HERE.rglob("*")) if p.is_file() and p.name!="CHECKSUMS.sha256" and "__pycache__" not in p.parts))
    print(json.dumps({"reopened_renders_equal":2,"comparison_boards":3}))


if __name__=="__main__":main()
