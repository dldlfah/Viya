"""Render composites and actual control-loop plots. No artwork retouching."""
import csv
import hashlib
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[5]
PREV=HERE.parent/"head_refinement_v2/review"
OUT=HERE/"review"
FONT=ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",19)


def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()


def paste(canvas,path,xy,size=None,crop=None):
    im=Image.open(path).convert("RGBA")
    if crop:im=im.crop(crop).resize((crop[2]*2-crop[0]*2,crop[3]*2-crop[1]*2),Image.Resampling.NEAREST)
    if size:im.thumbnail(size,Image.Resampling.LANCZOS)
    canvas.paste(im,xy,im)


def main():
    refs=json.loads((HERE.parent/"face_reference_v1/face_landmarks.json").read_text())["references"]
    for r in refs:assert sha(ROOT/r["path"])==r["sha256"]
    a=Image.open(OUT/"after_three_quarter.png").convert("RGBA");b=Image.open(OUT/"after_three_quarter_reopened.png").convert("RGBA")
    assert a.size==b.size and a.tobytes()==b.tobytes()
    assert sha(HERE.parent/"head_refinement_v2/viya_head_contours.blend")==json.loads((HERE/"build_result.json").read_text())["input_sha256"]
    canvas=Image.new("RGB",(1024,700),(213,213,213));d=ImageDraw.Draw(canvas)
    for x,label,path in [(0,"Before: v2",PREV/"after_front.png"),(512,"Current: lid rim / mouth corners",OUT/"after_front.png")]:
        d.text((x+8,8),label,font=FONT,fill="black");paste(canvas,path,(x,35))
    d.text((10,675),"Base-form self-review only. Face color/likeness and producer acceptance pending.",font=FONT,fill="black")
    canvas.save(OUT/"front_comparison.png")
    canvas=Image.new("RGB",(1024,450),(213,213,213));d=ImageDraw.Draw(canvas)
    for x,base,tag in [(0,PREV,"Before"),(512,OUT,"Current")]:
        d.text((x+8,8),tag+": 2x nearest crops",font=FONT,fill="black")
        paste(canvas,base/"after_front.png",(x,45),crop=(132,265,380,338))
        paste(canvas,base/"after_front.png",(x+125,225),crop=(192,368,320,424))
    d.text((10,415),"Actual rendered pixels; no face alignment, enhancement or warp.",font=FONT,fill="black")
    canvas.save(OUT/"feature_comparison.png")
    canvas=Image.new("RGB",(1920,1030),(213,213,213));d=ImageDraw.Draw(canvas)
    views=["screen_left_profile","screen_right_profile","three_quarter","three_quarter_opposite","game_high_angle"]
    for col,view in enumerate(views):
        for row in [0,1]:
            x,y=col*384,row*500
            source=(PREV/("after_"+view+".png")) if row==0 and col<3 else OUT/(("before_" if row==0 else "after_")+view+".png")
            d.text((x+4,y+5),("Before " if row==0 else "Current ")+view.replace("screen_", ""),font=FONT,fill="black")
            paste(canvas,source,(x,y+30),(384,470))
    d.text((10,1005),"Last view: head-only55-degree diagnostic, not actual game-size/device verification.",font=FONT,fill="black")
    canvas.save(OUT/"multiview_comparison.png")
    canvas=Image.new("RGB",(1560,1150),(242,239,233));d=ImageDraw.Draw(canvas)
    paste(canvas,HERE.parent/"face_reference_v1/review/face_reference_board.png",(0,0))
    for col,view in enumerate(["front","screen_right_profile","screen_left_profile"]):
        d.text((col*510+10,530),"Current clay: "+view,font=FONT,fill="black")
        paste(canvas,OUT/("after_"+view+".png"),(col*510,560),(490,550))
    d.text((10,1120),"Uncalibrated original drawings. No3D fitting from source pixel lengths or likeness score.",font=FONT,fill="black")
    canvas.save(OUT/"reference_comparison.png")

    rows=list(csv.DictReader((HERE/"feature_samples.csv").open()))
    assert len(rows)==602 and sum(r["locked"]=="True" for r in rows)==56
    assert all(float(r["displacement_m"])==0 for r in rows if r["locked"]=="True")
    fig,axs=plt.subplots(1,2,figsize=(12,5.5))
    for ax,state in zip(axs,["before","after"]):
        for name,color in [("aperture","black"),("outer_rim","tab:blue"),("inner_rim","tab:orange")]:
            q=[r for r in rows if r["region"]=="eye_right" and r["loop"]==name];q=q+[q[0]]
            ax.plot([float(r[state+"_x"])*1000 for r in q],[float(r[state+"_z"])*1000 for r in q],color=color,label=name)
        ax.set_title(state+": actual selected28-vertex loops");ax.set_xlabel("working X / mm");ax.set_ylabel("working Z / mm");ax.set_aspect("equal");ax.legend()
    fig.tight_layout();fig.savefig(OUT/"lid_loop_measurements.png",dpi=130);plt.close(fig)
    report={"four_original_references_unchanged":True,"input_blend_unchanged":True,"reopened_decoded_rgba_identical":True,"decoded_changed_bytes":0,"feature_samples":602,"locked_aperture_vertices":56,"locked_aperture_displacement_m":0,"scope":"Preservation/control samples only, not rig/runtime or producer face acceptance"}
    (HERE/"preservation_result.json").write_text(json.dumps(report,indent=2)+"\n")
    files=[p for p in sorted(HERE.rglob("*")) if p.is_file() and p.name!="CHECKSUMS.sha256" and "__pycache__" not in p.parts]
    (HERE/"CHECKSUMS.sha256").write_text("\n".join(f"{sha(p)}  {p.relative_to(HERE).as_posix()}" for p in files)+"\n")
    print(json.dumps({**report,"checksummed_files":len(files)}))


if __name__=="__main__":main()
