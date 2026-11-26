extends RefCounted
## Offline silhouette matte cleanup and coverage-aware reduction. Never modifies source PNGs.
static func clean(source:Image)->Image:
	var image:=source.duplicate();image.convert(Image.FORMAT_RGBA8)
	var bytes:PackedByteArray=image.get_data();var original:PackedByteArray=bytes.duplicate()
	var w:int=image.get_width();var h:int=image.get_height()
	# Only a narrow silhouette band can be matte-contaminated. Reference nearby
	# opaque interior colour instead of darkening the ivory top or metal highlights.
	for y in range(2,h-2):
		for x in range(2,w-2):
			var at:int=(y*w+x)*4
			var r:int=original[at];var g:int=original[at+1];var b:int=original[at+2];var a:int=original[at+3]
			if a<4 or mini(r,mini(g,b))<135 or maxi(r,maxi(g,b))-mini(r,mini(g,b))>75:continue
			var edge:bool=false
			for delta in [Vector2i(-2,0),Vector2i(2,0),Vector2i(0,-2),Vector2i(0,2),Vector2i(-1,-1),Vector2i(1,1),Vector2i(-1,1),Vector2i(1,-1)]:
				if original[((y+delta.y)*w+x+delta.x)*4+3]<16:edge=true;break
			if not edge:continue
			var chosen:int=-1;var best:int=99999
			for dy in range(-4,5):
				for dx in range(-4,5):
					if x+dx<2 or y+dy<2 or x+dx>=w-2 or y+dy>=h-2:continue
					var p:int=((y+dy)*w+x+dx)*4
					if original[p+3]<250:continue
					var solid:bool=true
					for offset in [-w*2,w*2,-2,2,-w*2-2,-w*2+2,w*2-2,w*2+2]:
						if original[p+offset*4+3]<240:solid=false;break
					if not solid:continue
					var score:int=dx*dx+dy*dy
					if score<best:best=score;chosen=p
			if chosen<0:continue
			var old_luma:float=(r+g+b)/3.0;var new_luma:float=(int(original[chosen])+int(original[chosen+1])+int(original[chosen+2]))/3.0
			if old_luma-new_luma<30:continue
			for c in range(3):bytes[at+c]=original[chosen+c]
	return Image.create_from_data(w,h,false,Image.FORMAT_RGBA8,bytes)

static func prepare(source:Image)->Image:
	var image:Image=clean(source)
	# Keep full source resolution and alpha coverage. Only matte-contaminated
	# silhouette RGB and invisible edge padding change; fine interior art stays sharp.
	image.fix_alpha_edges()
	return image
