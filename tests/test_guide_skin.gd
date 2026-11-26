extends RefCounted
const State=preload("res://scripts/combat/run_state.gd")
const Snapshot=preload("res://scripts/progression/run_snapshot.gd")
const Campaign=preload("res://tests/test_campaign.gd")
const CombatSkin=preload("res://scripts/ui/combat_skin.gd")

static func touch(id:int,at:Vector2,pressed:bool)->InputEventScreenTouch:
	var event:=InputEventScreenTouch.new()
	event.index=id
	event.position=at
	event.pressed=pressed
	return event

static func run(host,verify:Callable)->void:
	var scene=load("res://scenes/main.tscn").instantiate()
	var suffix:String=Crypto.new().generate_random_bytes(8).hex_encode()
	var folder:="user://guide-"+suffix
	DirAccess.make_dir_recursive_absolute(folder)
	scene.run_store.path=folder.path_join("battle.save")
	scene.gold_progress.path=folder.path_join("gold.cfg")
	scene.settings_path=folder.path_join("settings.cfg")
	host.get_tree().root.add_child(scene)
	scene.set_physics_process(false)
	await host.get_tree().process_frame
	Campaign.depart(scene)
	var state=scene.simulation
	verify.call(scene.battle_chrome.mouse_filter==Control.MOUSE_FILTER_IGNORE and scene.slot_buttons.size()==8 and scene.magic_button.ultimate,"Guide chrome keeps8real detail buttons and one existingMPaction,with noninteractive decoration")
	var frozen:Dictionary=Snapshot.capture(state)
	var skin=CombatSkin.new()
	var tile:Texture2D=skin.floor_tile("prologue_wall")
	verify.call(tile!=null and tile.get_size()==Vector2(224,160) and tile==skin.floor_tile("prologue_wall"),"Repeatable modular ground texture is cached,not a stretched battle illustration")
	var icons:=true
	for id in ["gun_rifle","gun_grenade","gun_ricochet","passive_vitality","passive_precision","passive_recovery","gear"]:
		icons=icons and skin.glyph(id)!=null and skin.glyph(id)==skin.glyph(id)
	verify.call(icons and Snapshot.capture(state)==frozen,"Procedural UI glyph/material lookups never change resources,progress or7RNG")
	for size in [Vector2(1280,720),Vector2(960,540),Vector2(853,384),Vector2(1600,720)]:
		scene.root_ui.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		scene.root_ui.size=size
		scene.safe_area_override=Rect2(Vector2(28,6),size-Vector2(56,18))
		scene._apply_layout()
		scene._update_hud()
		await host.get_tree().process_frame
		await host.get_tree().process_frame
		verify.call(scene.layout_data.safe.grow(1).encloses(scene.magic_button.get_rect()) and scene.layout_data.battle.size.y/scene.layout_data.safe.size.y>=.72,"Guide rune button fits while keeping72percent battle space: "+str(size))
		verify.call(not scene.movement.accepts(scene.mission_button.get_global_rect().get_center()) and scene.mission_button.visible,"Mission target is excluded from the native movement capture region: "+str(size))
		verify.call(scene._phase_text.text.contains("06:00") and scene.stats_text.text=="금화 0" and not scene._phase_text.text.contains("08:42"),"Header reads actual6minute clock/earned gold,not guide illustration values: "+str(size))
	var original:Dictionary=Campaign.comparable(state)
	var gold:int=scene.gold_progress.total
	var at:Vector2=scene.mission_button.get_global_rect().get_center()
	scene.movement._input(touch(7,at,true))
	scene._input(touch(7,at,true))
	verify.call(scene._mission_open and scene.movement.touch_id==-1 and state.phase==State.Phase.PAUSED and scene._mission_touch_id==7,"Mission native touch opens a paused read-only modal without capturing movement")
	scene._input(touch(7,at,false))
	var callback:Callable=scene.mission_return_button.get_signal_connection_list("pressed")[0].callable
	frozen=Snapshot.capture(state)
	scene._physics_process(.5)
	verify.call(Snapshot.capture(state)==frozen and scene.gold_progress.total==gold,"Mission pauses actual combat/MP/XP/candidates/rewards without extra simulation")
	verify.call(scene._handle_mobile_back() and not scene._mission_open and state.phase==State.Phase.RUNNING and Campaign.comparable(state)==original,"Mobile Back restores the exact prior battle rather than restarting it")
	scene._open_mission(state.navigation_ticket,scene._menu_revision)
	callback.call()
	verify.call(scene._mission_open and state.phase==State.Phase.PAUSED,"Stale mission close cannot dismiss a newer modal")
	callback=scene.mission_return_button.get_signal_connection_list("pressed")[0].callable
	scene.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	callback.call()
	verify.call(not scene._mission_open and scene.overlay.visible and state.phase==State.Phase.PAUSED and scene._modal_kind=="paused","Interruption invalidates mission callbacks and requires explicitContinue")
	scene.resume_button.pressed.emit()
	verify.call(state.phase==State.Phase.RUNNING and not scene.overlay.visible,"FreshContinue resumes after interrupted mission")
	scene._open_mission(state.navigation_ticket,scene._menu_revision)
	DirAccess.make_dir_absolute(scene.run_store.path+".tmp")
	scene._ensure_battle_saved()
	scene._handle_mobile_back()
	verify.call(scene.battle_save_error!=OK and not scene._mission_open and state.phase==State.Phase.PAUSED and scene._modal_kind=="paused","Save failure during mission returns to recovery UI without resuming combat")
	DirAccess.remove_absolute(scene.run_store.path+".tmp")
	scene._ensure_battle_saved()
	scene._show_menu("paused")
	scene.resume_button.pressed.emit()
	verify.call(state.phase==State.Phase.RUNNING,"Existing save retry and freshContinue recover interrupted mission")
	state.magic.mana=0
	scene._update_magic_hud()
	verify.call(scene.magic_button.disabled and scene.magic_button.text.contains("마력 부족") and scene.magic_button.tooltip_text.contains("초당 MP 회복"),"Rune button reads real mana availability/regeneration without inventing cooldown")
	state.magic.mana=100
	scene._update_magic_hud()
	var casts:int=state.magic.casts
	scene._input(touch(8,scene.magic_button.get_global_rect().get_center(),true))
	scene._input(touch(8,scene.magic_button.get_global_rect().get_center(),true))
	scene._input(touch(8,scene.magic_button.get_global_rect().get_center(),false))
	verify.call(state.magic.casts==casts+1 and state.magic.mana==60,"StyledMPbutton uses the same one-touch40mana guarded action")
	DirAccess.make_dir_absolute(scene.run_store.path+".tmp")
	scene._open_mission(state.navigation_ticket,scene._menu_revision)
	verify.call(scene.battle_save_error!=OK and not scene._mission_open and state.phase==State.Phase.PAUSED,"Failed pause save retains existing recovery screen instead of opening an unsafe mission modal")
	DirAccess.remove_absolute(scene.run_store.path+".tmp")
	verify.call(scene._ensure_battle_saved(),"Existing save retry recovers after blocked mission entry")
	scene.queue_free()
	await host.get_tree().process_frame
	for file in ["battle.save","gold.cfg","settings.cfg"]:DirAccess.remove_absolute(folder.path_join(file))
	DirAccess.remove_absolute(folder)
