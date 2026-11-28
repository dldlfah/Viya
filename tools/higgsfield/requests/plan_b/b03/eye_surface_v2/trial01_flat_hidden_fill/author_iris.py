"""Separate visible-iris transfers; unchanged spherical footprint and sclera."""
import hashlib
import json
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[5]
PREV = HERE.parent / 'eye_surface_v1'
PARAM = json.loads((HERE / 'registration.json').read_text())
SOURCE = ROOT / 'assets/characters/plan_b_viya/candidate_03/references/front.png'
TEX = HERE / 'textures'
OUT = HERE / 'review'
FONT = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 15)


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def main():
    assert sha(SOURCE) == PARAM['source_front_sha256']
    im = np.asarray(Image.open(SOURCE).convert('RGB'), float)
    uv = json.loads((HERE.parent / 'face_surface_v1/uv_preparation.json').read_text())['uv_methods']
    TEX.mkdir(exist_ok=True); OUT.mkdir(exist_ok=True)
    regions = Image.new('RGB', (1100, 930), '#eeeae5')
    atlas_board = Image.new('RGB', (1100, 600), '#eeeae5')
    records, traces = [], {}
    for i, eye in enumerate(PARAM['eyes']):
        side = eye['side']; name = 'eye_screen_' + side + '.png'
        before = np.asarray(Image.open(PREV / 'textures' / name).convert('RGB'))
        assert before.shape == (256, 256, 3)
        native_mask = Image.new('L', (im.shape[1], im.shape[0]), 0)
        ImageDraw.Draw(native_mask).polygon([tuple(p) for p in eye['visible_polygon_px']], fill=255)
        valid = np.asarray(native_mask) > 0
        u = (np.arange(256) + .5) / 256
        lon, lat = np.meshgrid((u-.5)*2*np.pi, ((1-u)-.5)*np.pi)
        rx, _, rz = uv[eye['object']]['radius']
        sx = np.sin(lon)*np.cos(lat)*rx/PARAM['iris_radius_working_m']
        sy = np.sin(lat)*rz/PARAM['iris_radius_working_m']
        rr = np.sqrt(sx*sx+sy*sy)
        iris = (rr < 1) & (np.cos(lon) > 0)
        assert int(iris.sum()) == 2028
        xx = eye['center_px'][0] + sx[iris]*eye['right_axis_px'][0] + sy[iris]*eye['up_axis_px'][0]
        yy = eye['center_px'][1] + sx[iris]*eye['right_axis_px'][1] + sy[iris]*eye['up_axis_px'][1]
        x0, y0 = np.floor(xx).astype(int), np.floor(yy).astype(int)
        dx, dy = xx-x0, yy-y0
        total = np.zeros(len(xx)); rgb = np.zeros((len(xx), 3)); used = np.zeros(valid.shape, bool)
        special = np.zeros(len(xx))
        for ox, oy, weight in [(0,0,(1-dx)*(1-dy)),(1,0,dx*(1-dy)),(0,1,(1-dx)*dy),(1,1,dx*dy)]:
            x, y = x0+ox, y0+oy
            w = weight*valid[y,x]
            rgb += im[y,x]*w[:,None]; total += w
            used[y[w > 1e-8], x[w > 1e-8]] = True
            if 'required_visible_sample_px' in eye:
                px, py = eye['required_visible_sample_px']
                special += w*((x == px) & (y == py))
        assert not np.any(used & ~valid)
        x1,y1,x2,y2 = eye['unobserved_fill_sample_xyxy']
        fill = np.median(im[y1:y2,x1:x2], axis=(0,1))
        color = rgb + fill[None,:]*(1-total[:,None])
        # Preserve the original footprint/edge formula. This is material color only.
        edge_weight = np.clip((rr[iris]-.88)/.12,0,1)*PARAM['existing_limbal_edge_mix_max']
        color = color*(1-edge_weight[:,None]) + np.asarray([74,27,24])*edge_weight[:,None]
        after = before.copy(); after[iris] = np.rint(np.clip(color,0,255)).astype(np.uint8)
        assert np.array_equal(after[~iris], before[~iris])
        if 'required_visible_sample_px' in eye:
            assert special.max() > .25 and int((special > 0).sum()) >= 1
        Image.fromarray(after).save(TEX / name)
        # Provenance masks are never installed as character color images.
        mask = np.zeros((256,256,3), np.uint8)
        mask[iris] = np.stack([np.rint((1-total)*255), np.rint(total*255), np.zeros(len(total))],axis=1).astype(np.uint8)
        Image.fromarray(mask).save(TEX / ('source_support_' + side + '.png'))
        traces[side+'_atlas_yx'] = np.argwhere(iris).astype(np.int16)
        traces[side+'_source_xy'] = np.stack([xx,yy],axis=1).astype(np.float32)
        traces[side+'_source_weight'] = total.astype(np.float32)
        traces[side+'_required_sample_weight'] = special.astype(np.float32)
        native_mask.save(TEX / ('native_selection_' + side + '.png'))
        xoff = i*550+10; crop = eye['inspection_crop_xyxy']
        raw = Image.open(SOURCE).convert('RGB').crop(crop).resize((462,434), Image.Resampling.NEAREST)
        regions.paste(raw,(xoff,35)); overlay=raw.copy(); draw=ImageDraw.Draw(overlay)
        points=[((x-crop[0])*14,(y-crop[1])*14) for x,y in eye['visible_polygon_px']]
        draw.line(points+[points[0]],fill='#00aaff',width=2)
        cx,cy=eye['center_px']; draw.ellipse(((cx-crop[0])*14-3,(cy-crop[1])*14-3,(cx-crop[0])*14+3,(cy-crop[1])*14+3),outline='#ffbb00',width=2)
        regions.paste(overlay,(xoff,480))
        ImageDraw.Draw(regions).text((xoff,8), side+' / original pixels; below: selection overlay', font=FONT,fill='black')
        for j, data in enumerate([before,after]):
            # Explicit nearest enlargement; the map contains resampled source detail.
            tile=Image.fromarray(data).crop((100,85,156,171)).resize((224,344),Image.Resampling.NEAREST)
            atlas_board.paste(tile,(xoff+j*255,50))
            ImageDraw.Draw(atlas_board).text((xoff+j*255,15),side+(' / before' if j==0 else ' / current'),font=FONT,fill='black')
        records.append({'side':side,'object':eye['object'],'old_png_sha256':sha(PREV/'textures'/name),'new_png_sha256':sha(TEX/name),'iris_texels':int(iris.sum()),'changed_texels':int(np.any(after!=before,axis=2).sum()),'changed_outside_iris':0,'selected_native_pixels':int(valid.sum()),'contributing_native_pixels':int(used.sum()),'source_supported_texels':int((total>.999).sum()),'partially_supported_texels':int(((total>1e-8)&(total<=.999)).sum()),'authored_only_texels':int((total<=1e-8).sum()),'mean_source_weight_inside_iris':float(total.mean()),'authored_unobserved_fill_rgb':fill.tolist(),'excluded_native_pixels_contributing':0,'required_sample_output_texels':int((special>0).sum()),'required_sample_maximum_bilinear_weight':float(special.max()),'new_source_detail_recovered':False})
    regions.save(OUT/'source_registration.png',optimize=True)
    ImageDraw.Draw(atlas_board).text((10,440),'Only existing 2,028 iris texels per eye can change. Sclera/geometry/UV unchanged.',font=FONT,fill='black')
    ImageDraw.Draw(atlas_board).text((10,470),'Occluded/unsupported areas use recorded same-eye dark fill, not recovered source detail.',font=FONT,fill='black')
    atlas_board.save(OUT/'atlas_before_after.png',optimize=True)
    np.savez_compressed(HERE/'sampling_trace.npz',**traces)
    (HERE/'authoring_result.json').write_text(json.dumps({'input_blend_sha256':PARAM['input_sha256'],'source_front_sha256':sha(SOURCE),'records':records,'scope':'Separate per-eye visible painted-iris sampling, recorded authored continuation and original footprint. No geometry/UV/head/sclera change, mirroring, opposite-eye copying, service generation or detail recovery.','paid_submissions':0,'spent_credits':0},indent=2)+'\n')
    print(json.dumps(records))


if __name__ == '__main__':
    main()
