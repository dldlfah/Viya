extends RefCounted
## Low-cost replaceable silhouettes, not final character/monster designs.
static func enemy(canvas: CanvasItem, feet: Vector2, variant: String, color: Color, height: float, detailed: bool, motion:Dictionary={}) -> void:
	canvas.draw_set_transform(feet,0,Vector2.ONE*(height/56.0))
	var dark:=color.darkened(.5)
	var stride:float=sin(float(motion.get("move_clock",0))*TAU*2)*4 if motion.get("moving",false) else 0
	if variant=="flier":
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(-30,-36),Vector2(-17,-41),Vector2(-7,-29),Vector2(0,-32),Vector2(7,-29),Vector2(17,-41),Vector2(30,-36),Vector2(16,-18),Vector2(6,-22),Vector2(0,-12),Vector2(-6,-22),Vector2(-16,-18)]),dark)
		canvas.draw_line(Vector2(-27,-35+stride),Vector2(-4,-28),color,2,true)
		canvas.draw_line(Vector2(27,-35+stride),Vector2(4,-28),color,2,true)
		canvas.draw_circle(Vector2(0,-28),6,color)
	elif variant=="fast":
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(-25,-23),Vector2(-11,-35),Vector2(11,-31),Vector2(25,-23),Vector2(11,-14),Vector2(-13,-13)]),dark)
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(12,-29),Vector2(17,-42),Vector2(22,-31),Vector2(33,-25),Vector2(24,-18),Vector2(15,-18)]),color)
		canvas.draw_line(Vector2(-15,-17),Vector2(-20,-2-maxf(0,stride)),color,4,true)
		canvas.draw_line(Vector2(12,-19),Vector2(19,-2-maxf(0,-stride)),color,4,true)
		if detailed:canvas.draw_line(Vector2(-7,-15),Vector2(-8,-2),dark,3,true)
	else:
		canvas.draw_line(Vector2(-6,-19),Vector2(-9,-1-maxf(0,stride)),dark,6,true)
		canvas.draw_line(Vector2(6,-19),Vector2(9,-1-maxf(0,-stride)),dark,6,true)
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(-12,-36),Vector2(10,-36),Vector2(14,-16),Vector2(-13,-16)]),dark)
		canvas.draw_circle(Vector2(0,-45),7,color)
		canvas.draw_line(Vector2(-12,-31),Vector2(-18,-18),color,5,true)
		canvas.draw_line(Vector2(12,-31),Vector2(19,-22),color,5,true)
		if variant=="heavy":
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(-21,-35),Vector2(-5,-32),Vector2(-5,-12),Vector2(-15,-5),Vector2(-24,-16)]),color)
			canvas.draw_line(Vector2(-15,-30),Vector2(-15,-12),dark,3,true)
		elif variant=="ranged":
			canvas.draw_arc(Vector2(17,-25),15,-PI*.5,PI*.5,12,color,2,true)
			canvas.draw_line(Vector2(17,-40),Vector2(17,-10),color,1,true)
		elif detailed:
			canvas.draw_line(Vector2(19,-19),Vector2(26,-43),Color("d0c0a0"),3,true)
			canvas.draw_line(Vector2(15,-25),Vector2(27,-20),Color("8d704b"),3,true)
		if detailed:
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(-8,-48),Vector2(-12,-56),Vector2(-3,-50),Vector2(4,-51),Vector2(12,-55),Vector2(8,-47)]),dark)
			canvas.draw_line(Vector2(-5,-28),Vector2(7,-24),color.lightened(.15),2,true)
			canvas.draw_line(Vector2(-3,-45),Vector2(3,-45),Color("edb680"),1,true)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)

static func hero(canvas: CanvasItem, feet: Vector2, direction: Vector2, hurt: bool, motion:Dictionary={}) -> void:
	# Warm adult-sized human silhouette and readable rifle direction; no portrait
	# or unapproved GEN-005 crop is bound as finished production character art.
	var cloth:=Color("a5384b")
	var stride:float=sin(float(motion.get("move_clock",0))*TAU*2)*4 if motion.get("moving",false) else 0
	canvas.draw_colored_polygon(PackedVector2Array([feet+Vector2(-6,-46),feet+Vector2(-25,-12),feet+Vector2(-33,-3),feet+Vector2(-11,-10),feet+Vector2(1,-4),feet+Vector2(9,-42)]),cloth.darkened(.18))
	canvas.draw_line(feet+Vector2(-5,-18),feet+Vector2(-10,-1-maxf(0,stride)),Color("322d30"),5,true)
	canvas.draw_line(feet+Vector2(6,-18),feet+Vector2(12,-1-maxf(0,-stride)),Color("322d30"),5,true)
	canvas.draw_line(feet+Vector2(-11,-2-maxf(0,stride)),feet+Vector2(-5,-2-maxf(0,stride)),Color("c3a374"),2,true)
	canvas.draw_line(feet+Vector2(10,-2-maxf(0,-stride)),feet+Vector2(16,-2-maxf(0,-stride)),Color("c3a374"),2,true)
	canvas.draw_colored_polygon(PackedVector2Array([feet+Vector2(-9,-42),feet+Vector2(6,-43),feet+Vector2(8,-19),feet+Vector2(-8,-19)]),Color("251e24"))
	canvas.draw_line(feet+Vector2(-6,-36),feet+Vector2(5,-36),Color("e0c8a5"),5,true)
	canvas.draw_circle(feet+Vector2(0,-49),7,Color("fff1db") if hurt else Color("d5b798"))
	canvas.draw_colored_polygon(PackedVector2Array([feet+Vector2(-8,-49),feet+Vector2(-8,-54),feet+Vector2(3,-57),feet+Vector2(9,-49),feet+Vector2(6,-41),feet+Vector2(14,-29),feet+Vector2(-2,-34),feet+Vector2(-16,-24),feet+Vector2(-12,-42)]),Color("39252b"))
	canvas.draw_line(feet+Vector2(-8,-25),feet+Vector2(7,-25),Color("c3a374"),2,true)
	var recoil:float=3*maxf(0,1-float(motion.get("clock",0))/.16) if motion.get("pose","")=="attack" else 0
	var origin:=feet+Vector2(2,-34)-direction*recoil
	canvas.draw_line(origin-direction*7,origin+direction*30,Color("20232a"),6,true)
	canvas.draw_line(origin+direction*5,origin+direction*31,Color("d0b783"),2,true)
	canvas.draw_line(origin+direction*5,origin+direction*14,Color("e86b78"),2,true)
	canvas.draw_line(feet+Vector2(-8,-38),origin+direction*2,Color("d5b798"),4,true)
	canvas.draw_line(feet+Vector2(8,-38),origin+direction*16,Color("d5b798"),4,true)
