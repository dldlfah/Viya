"""Review boards and source/packed-texture/pixel checks for the surface trial."""
import hashlib
import json
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw,ImageFont
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.collections import LineCollection

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[5]
OUT=HERE/"review"
FONT=ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",18)


def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()


def paste(c,path,xy,size=None,crop=None,nearest=False):
    im=Image.open(path).convert("RGBA")
    if crop:im=im.crop(crop)
    if size:im.thumbnail(size,Image.Resampling.NEAREST if nearest else Image.Resampling.LANCZOS)
    c.paste(im,xy,im)


def main():
    r=json.loads((HERE/"surface_authoring.json").read_text())
    for ref in r["references"]:assert sha(ROOT/ref["path"])==ref["sha256"]
    for name,h in r["texture_sha256"].items():assert sha(HERE/"textures"/name)==h
    reopen=json.loads((HERE/"reopen_result.json").read_text());assert reopen["packed_png_hashes_match"]==r["texture_sha256"]
    a=Image.open(OUT/"color_three_quarter.png").convert("RGBA");b=Image.open(OUT/"color_three_quarter_reopened.png").convert("RGBA")
    assert a.size==b.size and a.tobytes()==b.tobytes()
    c=Image.new("RGB",(1024,700),(213,213,213));d=ImageDraw.Draw(c)
    for x,label,path in [(0,"First surface: round-eye defect",HERE/"trial01_round_eyes/review/color_front.png"),(512,"Current: local03 return + surface revision",OUT/"color_front.png")]:
        d.text((x+8,8),label,font=FONT,fill="black");paste(c,path,(x,35))
    d.text((10,675),"Local trial only. Reference-face appearance has NOT passed art self-review.",font=FONT,fill="black")
    c.save(OUT/"first_vs_current.png")
    c=Image.new("RGB",(1024,600),(242,239,233));d=ImageDraw.Draw(c)
    d.text((10,8),"Original front: unchanged 2x source crop",font=FONT,fill="black")
    ref=next(x for x in r["references"] if x["id"]=="front")
    im=Image.open(ROOT/ref["path"]).crop((680,120,860,290)).resize((360,340),Image.Resampling.NEAREST);c.paste(im,(10,45))
    d.text((430,8),"Current surface: face crop, no new hair",font=FONT,fill="black")
    im=Image.open(OUT/"color_front.png").convert("RGBA").crop((118,236,398,478)).resize((560,484),Image.Resampling.NEAREST);c.paste(im,(430,45),im)
    d.text((10,560),"Different projections. No source-face warp/alignment or numerical likeness claim.",font=FONT,fill="black")
    c.save(OUT/"source_vs_surface.png")
    c=Image.new("RGB",(1536,1040),(213,213,213));d=ImageDraw.Draw(c)
    views=["front","three_quarter","three_quarter_opposite","screen_left_profile","screen_right_profile","game_high_angle"]
    for i,v in enumerate(views):
        x,y=(i%3)*512,(i//3)*500;d.text((x+8,y+5),"Current / "+v,font=FONT,fill="black");paste(c,OUT/("color_"+v+".png"),(x+64,y+30),(384,470))
    d.text((10,1010),"Hair/body/weapon unmade. High angle is head-only; no game/device verification.",font=FONT,fill="black")
    c.save(OUT/"surface_views.png")
    c=Image.new("RGB",(1536,700),(213,213,213));d=ImageDraw.Draw(c)
    for i,(label,path) in enumerate([("Preserved03 base",HERE.parent/"head_refinement_v3/review/after_front.png"),("Local03 corrective key",OUT/"clay_feedback_front.png"),("Current surface",OUT/"color_front.png")]):
        d.text((i*512+8,8),label,font=FONT,fill="black");paste(c,path,(i*512,35))
    d.text((10,675),"Original keys/mesh retained; R4_EyeReadability changes the evaluated eye form.",font=FONT,fill="black")
    c.save(OUT/"geometry_and_surface.png")
    c=Image.new("RGB",(1536,700),(213,213,213));d=ImageDraw.Draw(c)
    for i,(v,tag) in enumerate([("front","checker"),("three_quarter","checker"),("front","unlit")]):
        d.text((i*512+8,8),tag+" / "+v,font=FONT,fill="black");paste(c,OUT/(tag+"_"+v+".png"),(i*512,35))
    d.text((10,675),"Checker and unlit paint are diagnostics, not likeness approval or a final engine shader.",font=FONT,fill="black")
    c.save(OUT/"checker_and_unlit.png")
    data=json.loads((ROOT/".local_validation/PLAN_B03_04/bake_mesh.json").read_text());fig,axs=plt.subplots(1,2,figsize=(11,5))
    skin=data["objects"]["CC0_head_skin_UNAPPROVED"]
    for ax,faces,title in [(axs[0],skin["original_control_uv"],"Preserved original UV / control"),(axs[1],skin["triangle_uv"],"Separate head UV / rendered subdivision")]:
        lines=[]
        for face in faces:
            q=list(face)+[face[0]];lines.extend([[a,b] for a,b in zip(q,q[1:])])
        assert np.isfinite(np.asarray(lines)).all()
        ax.add_collection(LineCollection(lines,linewidths=.15,color="navy"));ax.set_xlim(0,1);ax.set_ylim(0,1);ax.set_aspect("equal");ax.set_title(title)
    fig.tight_layout();fig.savefig(OUT/"uv_layout.png",dpi=130);plt.close(fig)
    report={"four_source_hashes_match":True,"disk_texture_hashes_match":True,"packed_png_hashes_match_disk":True,"reopened_decoded_rgba_identical":True,"decoded_changed_bytes":0,"uv_coordinates_finite":True,"scope":"Source/texture/persistence integrity only. No likeness, rig, game or device acceptance."}
    (HERE/"preservation_result.json").write_text(json.dumps(report,indent=2)+"\n")
    files=[p for p in sorted(HERE.rglob("*")) if p.is_file() and p.name!="CHECKSUMS.sha256" and "__pycache__" not in p.parts]
    (HERE/"CHECKSUMS.sha256").write_text("\n".join(f"{sha(p)}  {p.relative_to(HERE).as_posix()}" for p in files)+"\n")
    print(json.dumps({**report,"checksummed_files":len(files)}))


if __name__=="__main__":main()
