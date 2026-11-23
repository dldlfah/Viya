extends RefCounted
## Read-only frame planning. Limits decoration/text, never actors, attacks or RNG.
const Ground=preload("res://scripts/combat/battle_projection.gd")
const MERGE_SECONDS := .12
const DENSE_ACTORS := 80
const DENSE_EFFECTS := 16
const DENSE_BULLETS := 40
const LINK_LIMIT := 12

static func visible_effect(effect: Dictionary, area: Rect2) -> bool:
	var reach:float=float(effect.get("radius",0))+40
	if area.grow(reach).has_point(effect.p):return true
	if effect.has("from"):
		return Rect2(effect.from,effect.p-effect.from).abs().grow(20).intersects(area)
	return false

static func merged_events(events: Array) -> Array:
	var result:Array=[]
	# Copy first; frame planning must never reset event lifetimes or amounts.
	for index in range(events.size()-1,-1,-1):
		var event:Dictionary=events[index].duplicate(true)
		if event.kind=="hit":
			var age:float=float(event.duration)-float(event.life)
			var merged:=false
			for recent in result:
				if recent.kind=="hit" and recent.id==event.id and absf(age-(float(recent.duration)-float(recent.life)))<=MERGE_SECONDS:
					recent.amount+=event.amount
					recent.critical=recent.critical or event.critical
					merged=true
					break
			if merged:continue
		result.append(event)
	return result

static func build(view) -> Dictionary:
	var state=view.simulation
	var area:Rect2=Ground.visible_world(view.camera_center(),view.size) if view.high_angle else Rect2(view.camera_center()-view.size*.5,view.size)
	var compact:bool=view.size.x<900 or view.size.y<350
	var actors:=0
	var important:Dictionary={}
	var reserved:Array=[Rect2(view.world_to_screen(state.player)-Vector2(25,64),Vector2(50,86))]
	if not view.boss_guidance.is_empty():
		reserved.append(view.boss_guidance.status_rect.grow(3))
		if view.boss_guidance.marker_rect.has_area():reserved.append(view.boss_guidance.marker_rect.grow(3))
	var hero_art:Dictionary=view.actor_visual().sample
	if not hero_art.is_empty():reserved[0]=reserved[0].merge(view.actor_art.rectangle(hero_art,view.world_to_screen(state.player)))
	for enemy in state.enemies:
		if not area.grow(40).has_point(enemy.p):continue
		actors+=1
		if enemy.kind!="normal":
			important[int(enemy.id)]=true
			var body:=Rect2(view.world_to_screen(enemy.p)-Vector2(26,100),Vector2(52,112))
			var sample:Dictionary=view.actor_visual(enemy).sample
			if not sample.is_empty():body=body.merge(view.actor_art.rectangle(sample,view.world_to_screen(enemy.p)))
			reserved.append(body)
	var effects:Array=[]
	for effect in state.effects:
		if visible_effect(effect,area):effects.append(effect)
	var bullets:=0
	for bullet in state.bullets:
		if area.grow(50).has_point(bullet.p):bullets+=1
	var dense:bool=view.auto_display and (actors>=(DENSE_ACTORS/2 if compact else DENSE_ACTORS) or effects.size()>=DENSE_EFFECTS or bullets>=DENSE_BULLETS)
	var simple:bool=view.simple_attacks or dense
	var planned:Array=[]
	var links:=0
	var skipped:=0
	for index in range(effects.size()-1,-1,-1):
		var effect:Dictionary=effects[index]
		if effect.get("kind","")=="chain" and simple:
			if links>=LINK_LIMIT:
				skipped+=1
				continue
			links+=1
		planned.push_front(effect)
	var cues:Array=merged_events(state.cues.events) if state.cues.enabled else []
	var limit:int=(8 if compact else 12) if dense else (16 if compact else 24)
	var labels:Array=layout_labels(cues,view.world_to_screen,view.size,view.get_theme_default_font(),reserved,important,limit,view.show_damage,view.show_xp)
	var kills:Array=[]
	for event in cues:
		if event.kind=="kill" and area.has_point(event.p) and kills.size()<(4 if simple else 12):kills.append(event)
	return {"dense":dense,"simple":simple,"actors":actors,"bullets":bullets,"effects":planned,"skipped_links":skipped,"labels":labels,"label_limit":limit,"kills":kills,"reserved":reserved,"raw_events":state.cues.events.size(),"merged_events":cues.size()}

static func priority(event: Dictionary, important: Dictionary) -> int:
	if event.kind=="item":return 0
	if event.kind=="hit":return 1 if important.has(int(event.id)) else (2 if event.critical else 4)
	return 3

static func layout_labels(events: Array, project: Callable, viewport: Vector2, font: Font, reserved: Array, important: Dictionary, limit: int, show_damage: bool, show_xp: bool) -> Array:
	var candidates:Array=[]
	for event in events:
		if event.kind=="kill" or (event.kind=="hit" and not show_damage) or (event.kind=="xp" and not show_xp):continue
		if float(event.life)<=0 or not Rect2(Vector2.ZERO,viewport).has_point(project.call(event.p)):continue
		candidates.append(event)
	candidates.sort_custom(func(a,b):return priority(a,important)<priority(b,important) if priority(a,important)!=priority(b,important) else float(a.life)/float(a.duration)>float(b.life)/float(b.duration))
	var result:Array=[]
	var occupied:Array=reserved.duplicate()
	var safe:=Rect2(Vector2(8,8),viewport-Vector2(16,16))
	for event in candidates:
		if result.size()>=limit:break
		var fraction:float=clampf(float(event.life)/float(event.duration),0,1)
		var progress:float=1-fraction
		var text:String
		var color:Color
		var point:Vector2=project.call(event.p)
		var font_size:int=17 if event.kind=="item" else 16
		if event.kind=="item":
			text=str(event.get("label",""))
			color=Color("f5dfa6",fraction)
			point+=Vector2(0,-48-progress*25)
		elif event.kind=="xp":
			text="+%.2f XP" % float(event.amount)
			color=Color("7cd3c1",fraction)
			point+=Vector2(24,-18-progress*22)
		else:
			text=("!%d" if event.critical else "%d") % int(event.amount)
			color=Color("f6d798" if event.critical else "fff1db",fraction)
			point+=Vector2(0,-35-progress*18)
			if important.has(int(event.id)):point.y-=65
		var size:=Vector2(font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x,font.get_height(font_size))+Vector2(6,4)
		for shift in [Vector2.ZERO,Vector2(0,-22),Vector2(0,-44),Vector2(-36,-22),Vector2(36,-22),Vector2(0,-66),Vector2(-36,-44),Vector2(36,-44)]:
			var box:=Rect2(point+shift-Vector2(size.x*.5,font.get_ascent(font_size)+2),size)
			if not safe.encloses(box):continue
			if occupied.any(func(other):return box.grow(2).intersects(other)):continue
			occupied.append(box)
			result.append({"event":event,"text":text,"color":color,"font_size":font_size,"rect":box,"at":box.position+Vector2(3,font.get_ascent(font_size)+2)})
			break
	return result
