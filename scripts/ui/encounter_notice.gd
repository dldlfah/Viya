extends RefCounted
## Transient observation of actual living special actors; never saved/gameplay state.
const NOTICE_SECONDS := 3.0
var run_id:String=""
var clock:float=-1
var living:Dictionary={}
var current:Dictionary={}
var starts_at:float=-1
var until:float=-1
var sequence:int=0 # Diagnostic only; never used for spawning or rewards.

func _actors(state) -> Dictionary:
	var result:Dictionary={}
	if state.run_mode!="campaign" or not state.has_active_run():return result
	for enemy in state.enemies:
		if enemy.kind in ["elite","boss"] and enemy.hp>0:result[int(enemy.id)]=enemy
	return result

func seed(state) -> void:
	run_id=state.run_id
	clock=state.elapsed
	living=_actors(state)
	current={}
	starts_at=-1
	until=-1

func observe(state, defer_until:float=-1) -> void:
	if run_id!=state.run_id or state.elapsed<clock or not state.has_active_run():
		self.seed(state)
		return
	var now:Dictionary=_actors(state)
	if state.phase==state.Phase.RUNNING:
		var fresh:Array=[]
		for id in now:
			if not living.has(id):fresh.append(now[id])
		fresh.sort_custom(func(a,b):return a.kind=="boss" if a.kind!=b.kind else int(a.id)<int(b.id))
		if not fresh.is_empty():
			var enemy:Dictionary=fresh[0]
			# A newly arriving elite cannot displace an unexpired boss announcement.
			if current.is_empty() or current.kind!="boss" or enemy.kind=="boss" or state.elapsed>=until or not now.has(int(current.id)):
				var name:String=str(state.enemy_definition(str(enemy.get("species",""))).get("name",""))
				var role:String="최종 보스" if enemy.kind=="boss" else "정예"
				current={"id":int(enemy.id),"kind":str(enemy.kind),"text":role+" 등장"+(" · "+name if not name.is_empty() else "")}
				starts_at=maxf(state.elapsed,defer_until)
				until=starts_at+NOTICE_SECONDS
				sequence+=1
	# Consume the entire batch, including actors hidden by a higher-priority cue.
	# Paused/restored actors become the baseline, never a later replay queue.
	living=now
	clock=state.elapsed
	if not current.is_empty() and (not now.has(int(current.id)) or state.elapsed>=until):current={}

func summary(state) -> String:
	if current.is_empty() or run_id!=state.run_id or not state.has_active_run() or state.elapsed>=until:return ""
	return str(current.text)

func visible(state) -> bool:
	return state.phase==state.Phase.RUNNING and state.elapsed>=starts_at and not summary(state).is_empty()

func caption(state, compact:bool) -> String:
	if not visible(state):return ""
	if current.kind=="boss":return "보스 등장 ▸" if compact else "최종 보스 등장 · 임무 ▸"
	return "정예 등장 ▸" if compact else "정예 등장 · 임무 ▸"
