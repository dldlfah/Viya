extends Button
## Drawing only; existing guarded pressed callbacks own all game actions.
const CombatSkin=preload("res://scripts/ui/combat_skin.gd")
var skin=CombatSkin.new()
var glyph_id: String=""
var glyph_texture: Texture2D
var rank: int=0
var ultimate: bool=false
var compact: bool=false

func _draw() -> void:
	if ultimate:
		var radius:float=19 if compact else 35
		var center:=Vector2(27 if compact else 45,size.y*.5)
		var color:=Color("df6b72",.45 if disabled else 1)
		draw_circle(center,radius+3,Color("2b151d"))
		CombatSkin.rune(self,center,radius,color,not compact)
		draw_arc(center,radius+4,0,TAU,40,CombatSkin.GOLD,1,true)
		return
	if glyph_id.is_empty():return
	var width:float=18 if compact else 29
	var texture:Texture2D=glyph_texture if glyph_texture else skin.glyph(glyph_id)
	if texture and not glyph_texture:draw_texture_rect(texture,Rect2(Vector2(7,(size.y-width)*.5),Vector2.ONE*width),false)
	if not compact:
		for index in range(5):
			var p:=Vector2(size.x*.5-15+index*7,size.y-5)
			var color:=CombatSkin.LIGHT if index<rank else Color("504536")
			draw_colored_polygon(PackedVector2Array([p+Vector2(0,-2),p+Vector2(2,0),p+Vector2(0,2),p-Vector2(2,0)]),color)
	if rank>=5:draw_rect(Rect2(Vector2.ONE*2,size-Vector2.ONE*4),Color("e0b868"),false,1)
