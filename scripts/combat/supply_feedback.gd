extends RefCounted
## Replaceable upright glyphs and committed pickup receipts; no gameplay or RNG.
const COLORS := {"hp":Color("f58c9c"),"mp":Color("7abcf3"),"magnet":Color("f3ce79"),"purge":Color("cea2fa"),"chest":Color("f4cd77")}

static func number(value:float) -> String:
	if value>0 and value<.001:return "<0.001"
	return String.num(value,3).trim_suffix(".0")

static func text(receipt:Dictionary) -> String:
	match str(receipt.get("kind","")):
		"chest":return "강화 상자 · %d종 +1" % receipt.upgrades.size() if not receipt.upgrades.is_empty() else "강화 가능한 보유 스킬 없음"
		"hp":return "HP +%d" % int(receipt.hp) if receipt.hp>0 else "HP 가득 참"
		"mp":return "MP +%s" % number(float(receipt.mp)) if receipt.mp>0 else "MP 가득 참"
		"magnet":
			var parts:PackedStringArray=[]
			if receipt.xp>0:parts.append("+%s XP" % number(float(receipt.xp)))
			if receipt.gold>0:parts.append("+%d 금화" % int(receipt.gold))
			return "전체 자석 · "+(" / ".join(parts) if not parts.is_empty() else "회수할 XP·금화 없음")
		"purge":
			return "제거 %d · %s보스 제외" % [int(receipt.kills),"탄환 %d · " % int(receipt.bullets) if receipt.bullets>0 else ""]
	return ""

static func color(kind:String) -> Color:
	return COLORS.get(kind,Color("f5dfa6"))

static func radius(compact:bool) -> float:
	return 14.0 if compact else 17.0

static func bounds(at:Vector2,compact:bool) -> Rect2:
	var r:float=radius(compact)+3
	return Rect2(at-Vector2.ONE*r,Vector2.ONE*r*2)

static func draw_item(canvas,at:Vector2,kind:String,compact:bool) -> void:
	if not COLORS.has(kind):return
	var r:float=radius(compact)
	var tint:Color=color(kind)
	canvas.draw_circle(at+Vector2(0,2),r+2,Color(0,0,0,.65))
	canvas.draw_circle(at,r,Color("171b23"))
	canvas.draw_arc(at,r,0,TAU,24,tint,2,true)
	var scale:float=r/17.0
	match kind:
		"chest":
			canvas.draw_rect(Rect2(at+Vector2(-11,-7)*scale,Vector2(22,16)*scale),Color("86572f"))
			canvas.draw_rect(Rect2(at+Vector2(-11,-7)*scale,Vector2(22,16)*scale),tint,false,2)
			canvas.draw_line(at+Vector2(-10,-1)*scale,at+Vector2(10,-1)*scale,tint,2,true)
			canvas.draw_rect(Rect2(at+Vector2(-2,-3)*scale,Vector2(4,7)*scale),tint)
		"hp":
			canvas.draw_line(at+Vector2(-9,0)*scale,at+Vector2(9,0)*scale,tint,4,true)
			canvas.draw_line(at+Vector2(0,-9)*scale,at+Vector2(0,9)*scale,tint,4,true)
		"mp":
			canvas.draw_colored_polygon(PackedVector2Array([at+Vector2(0,-11)*scale,at+Vector2(8,3)*scale,at+Vector2(5,9)*scale,at+Vector2(-5,9)*scale,at+Vector2(-8,3)*scale]),tint)
			canvas.draw_line(at+Vector2(-3,3)*scale,at+Vector2(-1,6)*scale,Color("e8f7ff"),2,true)
		"magnet":
			canvas.draw_arc(at,8*scale,0,PI,14,tint,4,true)
			canvas.draw_line(at+Vector2(-8,0)*scale,at+Vector2(-8,-8)*scale,tint,4,true)
			canvas.draw_line(at+Vector2(8,0)*scale,at+Vector2(8,-8)*scale,tint,4,true)
			canvas.draw_line(at+Vector2(-8,-9)*scale,at+Vector2(-8,-5)*scale,Color("fff1cc"),4,true)
			canvas.draw_line(at+Vector2(8,-9)*scale,at+Vector2(8,-5)*scale,Color("fff1cc"),4,true)
		"purge":
			canvas.draw_line(at-Vector2(7,7)*scale,at+Vector2(7,7)*scale,tint,3,true)
			canvas.draw_line(at+Vector2(-7,7)*scale,at+Vector2(7,-7)*scale,tint,3,true)
			for axis in [Vector2.UP,Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT]:
				canvas.draw_line(at+axis*10*scale,at+axis*13*scale,tint,2,true)
