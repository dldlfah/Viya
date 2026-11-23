extends Node
## Presentation observer + shared bounded voices. No gameplay state or save fields.
const Bank=preload("res://scripts/combat/combat_audio_bank.gd")
const MAX_VOICES := 6
const MAX_PER_BATCH := 3
var enabled:bool=true # QA comparison; master volume is the player setting.
var suspended:bool=false
var voices:Array[Dictionary]=[]
var before:Dictionary={}
var run_id:String=""
var phase:int=-1
var clock:float=-1
var next_allowed:Dictionary={}
var played:Dictionary={}
var rejected:int=0

func _ready() -> void:
	for kind in Bank.SPECS:Bank.stream(kind)
	for index in range(MAX_VOICES):
		var player:=AudioStreamPlayer.new()
		player.name="CombatVoice%d" % index
		player.bus="Master"
		player.max_polyphony=1
		add_child(player)
		voices.append({"player":player,"priority":-1,"kind":"","at":-1.0})

func _notification(what:int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]:
		suspended=true
		stop_all()
	elif what in [NOTIFICATION_APPLICATION_FOCUS_IN,NOTIFICATION_APPLICATION_RESUMED]:
		suspended=false

func _exit_tree() -> void:
	stop_all()
	before.clear()

func stop_all() -> void:
	for voice in voices:
		voice.player.stop()
		voice.player.stream=null
		voice.priority=-1
		voice.kind=""

func guard(state, foreground:bool=true) -> void:
	if state.run_id!=run_id or state.elapsed<clock:
		stop_all()
		next_allowed.clear()
		before.clear()
		run_id=state.run_id
		phase=-1
	if int(state.phase)!=phase:
		stop_all()
		phase=int(state.phase)
	clock=state.elapsed
	if not enabled or suspended or AudioServer.is_bus_mute(0) or state.phase in [state.Phase.READY,state.Phase.PAUSED,state.Phase.ABANDONED] or (state.phase==state.Phase.RUNNING and not foreground):stop_all()

func prepare(state, foreground:bool=true) -> void:
	guard(state,foreground)
	var events:Dictionary={}
	for event in state.cues.events:
		if event.kind not in ["hit","xp","item"]:continue
		var key:String="%s:%d" % [event.kind,event.id]
		if not events.has(key):events[key]=[]
		events[key].append({"ref":event,"amount":float(event.amount)})
	before={"run":state.run_id,"phase":int(state.phase),"shots":state.shots,"casts":state.magic.casts,
		"level":state.growth.level,"received":state.cues.received_serial,"gold":state.gold_collected,"events":events}

func grew(event:Dictionary) -> bool:
	var key:String="%s:%d" % [event.kind,event.id]
	for old in before.events.get(key,[]):
		if is_same(old.ref,event):return float(event.amount)>float(old.amount)
	return true

func finish(state, was_running:bool, foreground:bool=true) -> void:
	var captured:Dictionary=before
	guard(state,foreground)
	if captured.is_empty() or captured.run!=state.run_id:return
	before=captured
	var requests:Array[String]=[]
	if was_running and int(captured.phase)==state.Phase.RUNNING:
		if state.phase==state.Phase.CLEARED:requests.append("clear")
		elif state.phase==state.Phase.DEFEAT:requests.append("defeat")
		elif state.phase==state.Phase.CHOOSING and state.growth.level>int(captured.level):requests.append("level")
		elif state.phase==state.Phase.RUNNING and foreground:
			if state.cues.received_serial>int(captured.received):requests.append("hurt")
			if state.magic.casts>int(captured.casts):requests.append("magic")
			if state.shots>int(captured.shots):requests.append("fire")
			if state.gold_collected>int(captured.gold):requests.append("pickup")
			for event in state.cues.events:
				if event.kind not in ["hit","xp","item"] or not grew(event):continue
				var kind:String="hit" if event.kind=="hit" else "pickup"
				if not requests.has(kind):requests.append(kind)
	requests.sort_custom(func(a,b):return Bank.SPECS[a].priority>Bank.SPECS[b].priority)
	var count:=0
	for kind in requests:
		if count>=MAX_PER_BATCH:break
		if _play(kind,state.elapsed):count+=1
	# Every observation is consumed, including muted, paused or rejected sounds.
	before.clear()

func _play(kind:String, at:float) -> bool:
	if not enabled or suspended or AudioServer.is_bus_mute(0) or not Bank.SPECS.has(kind) or not is_finite(at) or at<float(next_allowed.get(kind,-1)):
		rejected+=1
		return false
	var spec:Dictionary=Bank.SPECS[kind]
	var available:Dictionary={}
	for voice in voices:
		if not voice.player.playing:
			available=voice
			break
		if int(voice.priority)<=int(spec.priority) and (available.is_empty() or int(voice.priority)<int(available.priority) or (voice.priority==available.priority and voice.at<available.at)):
			available=voice
	if available.is_empty():
		rejected+=1
		return false
	available.player.stop()
	available.player.stream=Bank.stream(kind)
	available.player.volume_db=float(spec.db)
	available.player.play()
	available.merge({"priority":int(spec.priority),"kind":kind,"at":at},true)
	next_allowed[kind]=at+float(spec.gap)
	played[kind]=int(played.get(kind,0))+1
	return true

func active_count() -> int:
	return voices.filter(func(voice):return voice.player.playing).size()
