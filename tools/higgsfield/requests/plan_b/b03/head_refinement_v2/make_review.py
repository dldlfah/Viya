"""Unwarped before/after boards, exact reference/persistence checks, checksums."""
import hashlib
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[5]
PREV=HERE.parent/"head_refinement_v1/review"
OUT=HERE/"review"
FONT=ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",19)


def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()


def paste(canvas,path,xy,size=None):
    im=Image.open(path).convert("RGBA")
    if size:im.thumbnail(size,Image.Resampling.LANCZOS)
    canvas.paste(im,xy,im)


def main():
    refs=json.loads((HERE.parent/"face_reference_v1/face_landmarks.json").read_text())["references"]
    for r in refs:assert sha(ROOT/r["path"])==r["sha256"]
    a=Image.open(OUT/"after_three_quarter.png").convert("RGBA")
    b=Image.open(OUT/"after_three_quarter_reopened.png").convert("RGBA")
    assert a.size==b.size and a.tobytes()==b.tobytes()
    canvas=Image.new("RGB",(1024,700),(213,213,213));d=ImageDraw.Draw(canvas)
    for x,label,path in [(0,"Before: previous editable study",PREV/"combined_front.png"),(512,"Current: contour / depth / mouth / jaw",OUT/"after_front.png")]:
        d.text((x+8,8),label,font=FONT,fill="black");paste(canvas,path,(x,35))
    d.text((10,675),"B-03-03 remains in progress. Not a producer-approved VIYA face.",font=FONT,fill="black")
    canvas.save(OUT/"front_comparison.png")
    canvas=Image.new("RGB",(1536,1040),(213,213,213));d=ImageDraw.Draw(canvas)
    for col,view in enumerate(["screen_left_profile","screen_right_profile","three_quarter"]):
        for row,(tag,base,prefix) in enumerate([("Before",PREV,"combined"),("Current",OUT,"after")]):
            x,y=col*512,row*500
            d.text((x+8,y+6),tag+": "+view,font=FONT,fill="black")
            paste(canvas,base/(prefix+"_"+view+".png"),(x+64,y+30),(384,470))
    d.text((10,1010),"Identical cameras and clay lighting. No retouching or silhouette warping.",font=FONT,fill="black")
    canvas.save(OUT/"multiview_comparison.png")
    canvas=Image.new("RGB",(1560,1150),(242,239,233));d=ImageDraw.Draw(canvas)
    paste(canvas,HERE.parent/"face_reference_v1/review/face_reference_board.png",(0,0))
    for col,view in enumerate(["front","screen_right_profile","screen_left_profile"]):
        d.text((col*510+10,530),"Current clay: "+view,font=FONT,fill="black")
        paste(canvas,OUT/("after_"+view+".png"),(col*510,560),(490,550))
    d.text((10,1120),"Uncalibrated drawings; no overlay fitting or numerical likeness claim.",font=FONT,fill="black")
    canvas.save(OUT/"reference_comparison.png")
    report={"four_original_reference_hashes_match":True,"decoded_reopened_rgba_identical":True,"changed_decoded_bytes":0,"input_blend_sha256_matches":sha(HERE.parent/"head_refinement_v1/viya_head_refinement.blend")==json.loads((HERE/"build_result.json").read_text())["input_sha256"],"scope":"Preservation/reopening only, not face likeness or eye-surface-contact/rig/runtime acceptance"}
    assert report["input_blend_sha256_matches"]
    (HERE/"pixel_preservation_result.json").write_text(json.dumps(report,indent=2)+"\n")
    files=[p for p in sorted(HERE.rglob("*")) if p.is_file() and p.name!="CHECKSUMS.sha256" and "__pycache__" not in p.parts]
    (HERE/"CHECKSUMS.sha256").write_text("\n".join(f"{sha(p)}  {p.relative_to(HERE).as_posix()}" for p in files)+"\n")
    print(json.dumps({**report,"checksummed_files":len(files)}))


if __name__=="__main__":main()
