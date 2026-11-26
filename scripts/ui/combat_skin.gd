extends RefCounted
## Replaceable procedural UI/material stand-ins. Not approved production art.
const GOLD := Color("ba9566")
const LIGHT := Color("f1d9a5")
const INK := Color("151317")
var _icons: Dictionary = {}
var _floors: Dictionary = {}

static func plate(fill: Color=INK, edge: Color=GOLD, padding: float=6) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color=fill
	box.border_color=edge
	box.set_border_width_all(1)
	box.set_corner_radius_all(3)
	box.content_margin_left=padding
	box.content_margin_right=padding
	box.content_margin_top=2
	box.content_margin_bottom=2
	return box

static func style_button(button: Button, ultimate: bool=false, compact: bool=false) -> void:
	for mode in ["normal","hover","pressed","disabled","focus"]:
		var edge := GOLD.lightened(.2) if mode in ["hover","focus"] else GOLD
		var fill := Color("2c2023") if mode=="pressed" else INK
		if mode=="disabled":edge=Color("615444")
		var box := plate(fill,edge)
		if ultimate:box.content_margin_left=52 if compact else 88
		button.add_theme_stylebox_override(mode,box)
	button.add_theme_color_override("font_color",LIGHT)
	button.add_theme_color_override("font_disabled_color",Color("9d8b78"))

static func style_bar(bar: ProgressBar, color: Color) -> void:
	bar.add_theme_stylebox_override("background",plate(Color("221d22"),Color("78634f"),0))
	var fill := plate(color,color.lightened(.3),0)
	fill.border_width_bottom=0
	fill.border_width_left=0
	fill.border_width_right=0
	bar.add_theme_stylebox_override("fill",fill)

func glyph(id: String, color: Color=LIGHT) -> Texture2D:
	var key := id+color.to_html()
	if _icons.has(key):return _icons[key]
	var path := "M12 32 L32 10 L52 32 L32 54 Z M32 16 V48 M20 32 H44"
	if id.contains("rifle") or id.contains("scatter") or id.contains("sniper"):
		path="M7 23 H44 V20 H51 V28 H59 M13 24 L6 36 H15 L21 29 H40 M25 29 L22 44 H31 L34 29 M36 29 L39 39 H47 L43 28 M15 20 V16 H24"
	elif id.contains("grenade") or id.contains("rupture"):
		path="M23 20 L39 16 L49 40 Q49 52 33 53 Q17 53 16 41 Z M24 20 L20 12 L32 8 L36 17 M30 10 L45 7 L50 16 M23 31 L43 26 M25 41 L46 35"
	elif id.contains("ricochet") or id.contains("chain"):
		path="M8 46 L27 26 L41 41 L55 13 M41 15 L55 13 L55 28 M9 49 H21"
	elif id.contains("suppress") or id.contains("crossfire") or id.contains("haste"):
		path="M12 49 L35 16 L31 35 L53 12 M10 18 L22 7 M17 25 L29 14 M37 52 L49 40"
	elif id.contains("bow"):
		path="M20 7 Q59 32 20 57 L34 32 Z M7 32 H56 M46 24 L56 32 L46 40"
	elif id.contains("sword") or id.contains("power"):
		path="M16 52 L43 15 L55 7 L50 23 L23 58 M14 38 L34 53 M10 56 L20 62"
	elif id.contains("precision"):
		path="M32 7 V20 M32 44 V57 M7 32 H20 M44 32 H57 M32 15 A17 17 0 1 1 31.9 15 M32 27 A5 5 0 1 1 31.9 27"
	elif id.contains("vitality") or id.contains("defense"):
		path="M12 13 L32 7 L52 13 L48 39 L32 57 L16 39 Z M32 17 V43 M21 30 H43"
	elif id.contains("recovery"):
		path="M23 10 H41 V23 H54 V41 H41 V54 H23 V41 H10 V23 H23 Z"
	elif id.contains("stride"):
		path="M24 9 H43 L38 34 L54 45 V53 H14 V40 L23 34 Z M18 21 H8 M16 29 H4"
	elif id.contains("magnet"):
		path="M12 11 V36 Q12 56 32 56 Q52 56 52 36 V11 H40 V35 Q40 43 32 43 Q24 43 24 35 V11 Z M12 23 H24 M40 23 H52"
	elif id.contains("learning"):
		path="M8 12 L29 15 L32 20 L35 15 L56 12 V48 L35 51 L32 56 L29 51 L8 48 Z M32 20 V52 M14 23 L25 25 M39 25 L50 23"
	elif id=="gear":
		path="M26 6 H38 L40 16 L49 12 L57 22 L49 30 L58 37 L51 48 L41 44 L38 57 H26 L23 46 L13 50 L6 39 L15 32 L7 23 L14 13 L24 17 Z M32 22 A10 10 0 1 1 31.9 22"
	elif id=="coin":path="M32 8 A24 24 0 1 1 31.9 8 M32 17 A15 15 0 1 1 31.9 17 M38 23 H28 L24 32 H37 L34 41 H24"
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64"><path d="%s" fill="none" stroke="#%s" stroke-width="2.8" stroke-linecap="round" stroke-linejoin="round"/></svg>' % [path,color.to_html(false)]
	var image := Image.new()
	if image.load_svg_from_string(svg)!=OK:return null
	var texture := ImageTexture.create_from_image(image)
	_icons[key]=texture
	return texture

func floor_tile(map_id: String) -> Texture2D:
	if _floors.has(map_id):return _floors[map_id]
	var colors := ["49464a","545054","403f44","5b5654","454349"]
	if map_id=="outskirts_trial":colors=["484d43","505448","3d453d","59594c","424b43"]
	elif map_id=="gold_slime":colors=["514b3c","5a5442","474435","615a43","4b4939"]
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="224" height="160"><rect width="224" height="160" fill="#25272a"/>'
	for row in range(5):
		for column in range(-1,5):
			var x := column*56+(28 if row%2 else 0)
			var y := row*32
			var color:String=colors[posmod(posmod(column,4)*3+row*7,colors.size())]
			svg+='<path d="M%d %d l46 -1 5 7 -1 18 -7 5 -44 -1 -3 -11 1 -11 Z" fill="#%s" stroke="#303034" stroke-width="1.2"/><path d="M%d %d l42 -1" stroke="#8b8177" stroke-opacity=".22" stroke-width="1"/>' % [x+5,y+2,color,x+7,y+4]
			svg+='<path d="M%d %d l5 3 -2 6" fill="none" stroke="#303034" stroke-width=".7"/>' % [x+posmod(column*7+row,25)+12,y+12]
	svg+='</svg>'
	var image := Image.new()
	if image.load_svg_from_string(svg)!=OK:return null
	var texture := ImageTexture.create_from_image(image)
	_floors[map_id]=texture
	return texture

static func rune(canvas: CanvasItem, at: Vector2, radius: float, color: Color, detailed: bool=true) -> void:
	canvas.draw_arc(at,radius,0,TAU,48,color,1.5,true)
	canvas.draw_arc(at,radius*.84,0,TAU,40,color,1,true)
	var points := PackedVector2Array()
	for index in range(6):points.append(at+Vector2.from_angle(-PI*.5+TAU*posmod(index*2,5)/5)*radius*.73)
	canvas.draw_polyline(points,color,1.5,true)
	if detailed:
		for index in range(12):
			var direction:=Vector2.from_angle(TAU*index/12)
			canvas.draw_line(at+direction*radius*.91,at+direction*radius*.98,color,1,true)
