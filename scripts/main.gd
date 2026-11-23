extends Node
const RunState = preload("res://scripts/combat/run_state.gd")
const BattleView = preload("res://scripts/combat/battle_view.gd")
const MoveInput = preload("res://scripts/ui/move_input.gd")
const FeedbackPanel = preload("res://scripts/ui/feedback_panel.gd")
const SkillPreview = preload("res://scripts/ui/skill_preview.gd")
const GoldProgress = preload("res://scripts/progression/gold_progress.gd")
const RunStore = preload("res://scripts/progression/run_store.gd")

var simulation = RunState.new()
var new_run_ruleset: String = "weapons_v1" # New sorties; resumed saves retain theirs.
var view
var movement
var root_ui: Control
var health: ProgressBar
var experience: ProgressBar
var status_text: Label
var stats_text: Label
var level_text: Label
var overlay: ColorRect
var dialog: PanelContainer
var dialog_body: VBoxContainer
var start_button: Button
var resume_button: Button
var magic_button: Button
var mana_bar: ProgressBar
var mana_text: Label
var feedback_panel
var feedback_overlay_label: Label
var result_summary_label: Label
var _magic_touch_id: int = -1
var _magic_ui_ticket: int = -1
var choice_buttons: Array[Button] = []
var attack_slots: Array[Label] = []
var passive_slots: Array[Label] = []
var volume: float = 0.7
var last_phase: int = -1
var last_ticket: int = -1
var _slot_revision: int = -1
var gold_progress = GoldProgress.new()
var gold_error: Error = OK
var settings_path: String = "user://viya_settings.cfg"
var show_damage: bool = true
var show_xp: bool = true
var simple_attacks: bool = false
var settings_message: Label
var settings_error: Error = OK
var run_store = RunStore.new()
var battle_save_error: Error = OK
var _saved_checkpoint: int = 0
var stage_text: Label

func _ready() -> void:
	_load_settings()
	gold_error = gold_progress.load_progress()
	battle_save_error = run_store.load_saved(simulation)
	_recover_dungeon_admission()
	_build_interface()
	for key in ["show_damage", "show_xp", "simple_attacks"]:
		view.set(key, get(key))
	stage_text = _label("", 16)
	root_ui.add_child(stage_text)
	root_ui.move_child(stage_text, view.get_index() + 1)
	stage_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_text.position = Vector2(28, 92)
	stage_text.size.x = 1200
	_show_menu("ready")
	if battle_save_error == OK and not run_store.pending.is_empty() and not _has_saved_battle():
		_resume_saved_run()
	get_tree().auto_accept_quit = false
	get_tree().quit_on_go_back = false
	_update_hud()

func _recover_dungeon_admission() -> void:
	if gold_error!=OK or battle_save_error!=OK or gold_progress.dungeon.initial.is_empty():return
	var initial: Dictionary=RunStore.Snapshot.upgrade_legacy(gold_progress.dungeon.initial,simulation)
	if not RunStore.Snapshot.valid(initial,simulation):
		battle_save_error=ERR_FILE_CORRUPT
		return
	if not run_store.pending.is_empty():
		if run_store.pending.run.run_id==initial.run.run_id:return
		if run_store.pending.run.phase in [1,2,4]:
			battle_save_error=ERR_FILE_CORRUPT
			return
	# Durable admission includes its starting snapshot. Recover ONLY the missing
	# first write, never roll a damaged/newer checkpoint back to the initial state.
	battle_save_error=run_store.write_snapshot(initial)

func _physics_process(delta: float) -> void:
	simulation.step(delta, movement.direction())
	_sync_phase_ui()
	if simulation.has_active_run() and simulation.checkpoint_index > _saved_checkpoint and battle_save_error == OK:
		_ensure_battle_saved()
	_update_hud()
	view.queue_redraw()

func _sync_phase_ui() -> void:
	var changed: bool = simulation.phase != last_phase
	if changed:
		if simulation.phase != RunState.Phase.RUNNING:
			_magic_touch_id = -1
		movement.set_enabled(simulation.phase == RunState.Phase.RUNNING)
		last_phase = simulation.phase
		if simulation.phase == RunState.Phase.DEFEAT:
			_show_menu("defeat")
		elif simulation.phase == RunState.Phase.CLEARED:
			_show_menu("cleared")
	if simulation.phase == RunState.Phase.CHOOSING:
		if changed or last_ticket != simulation.growth.ticket:
			_show_levelup()

func _input(event: InputEvent) -> void:
	if not is_instance_valid(magic_button) or not is_instance_valid(overlay):
		return
	# Native second-finger handling avoids relying on touch-to-mouse emulation.
	if event is InputEventScreenTouch:
		if event.index == _magic_touch_id:
			if not event.pressed or event.canceled:
				_magic_touch_id = -1
			get_viewport().set_input_as_handled()
			return
		if overlay.visible or not magic_button.get_global_rect().has_point(event.position):
			return
		if event.pressed and not event.canceled and _magic_touch_id == -1:
			_magic_touch_id = event.index
			_cast_magic(_magic_ui_ticket)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == _magic_touch_id:
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.device == InputEvent.DEVICE_ID_EMULATION:
		if not overlay.visible and magic_button.get_global_rect().has_point(event.position):
			# Touch was handled above; do not cast again from its synthetic mouse click.
			get_viewport().set_input_as_handled()

func _cast_magic(expected_ticket: int = -1) -> void:
	if overlay.visible:
		return
	var ticket: int = _magic_ui_ticket if expected_ticket < 0 else expected_ticket
	simulation.cast_ultimate(ticket)
	_update_magic_hud()
	_update_feedback_hud()
	view.queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F:
		_cast_magic()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if simulation.phase in [RunState.Phase.RUNNING, RunState.Phase.CHOOSING]:
			pause_game()
		elif simulation.phase == RunState.Phase.PAUSED:
			resume_game()
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_instance_valid(overlay) and has_method("_handle_mobile_back"):
		if call("_handle_mobile_back"):
			return
	if what in [NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_WM_GO_BACK_REQUEST] and is_instance_valid(overlay):
		if simulation.phase == RunState.Phase.READY or _ensure_battle_saved():
			get_tree().quit()
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_magic_touch_id = -1
		if is_instance_valid(movement):
			movement.clear_input()
		if is_instance_valid(overlay):
			pause_game()
			_ensure_battle_saved()

func begin_run() -> void:
	if simulation.phase == RunState.Phase.READY and not run_store.pending.is_empty() and (_has_saved_battle() or not simulation.result_summary().ended):
		_resume_saved_run()
		return
	if not _can_start_rewarded_run():
		return
	_magic_touch_id = -1
	var previous_stage: int = simulation.stage
	simulation.stage = gold_progress.next_stage
	if not simulation.start(0, simulation.growth.character_id, gold_progress.talent_levels, str(simulation.stage_catalog.for_stage(simulation.stage).map_id), new_run_ruleset):
		simulation.stage = previous_stage
		push_error("Invalid character skill catalog; run not started")
		return
	movement.clear_input()
	movement.set_enabled(true)
	overlay.hide()
	last_phase = simulation.phase
	last_ticket = -1
	_update_hud()
	_ensure_battle_saved()

func pause_game() -> void:
	if simulation.phase not in [RunState.Phase.RUNNING, RunState.Phase.CHOOSING]:
		return
	_magic_touch_id = -1
	simulation.set_paused(true)
	movement.set_enabled(false)
	last_phase = simulation.phase
	_show_menu("paused")
	_update_hud()
	_ensure_battle_saved()

func resume_game() -> void:
	if simulation.phase != RunState.Phase.PAUSED or battle_save_error != OK:
		return
	movement.clear_input()
	simulation.set_paused(false)
	movement.set_enabled(simulation.phase == RunState.Phase.RUNNING)
	last_phase = -1
	if simulation.phase == RunState.Phase.CHOOSING:
		_sync_phase_ui() # Restore the same ticket/candidates, never reroll on pause.
	else:
		overlay.hide()
	_update_hud()

func _label(text: String, font_size: int = 20) -> Label:
	var item := Label.new()
	item.text = text
	item.add_theme_font_size_override("font_size", font_size)
	item.add_theme_color_override("font_color", Color("e6dccb"))
	return item

func _button(text: String, action: Callable) -> Button:
	var item := Button.new()
	item.text = text
	item.custom_minimum_size.y = 56
	item.add_theme_font_size_override("font_size", 22)
	item.pressed.connect(action)
	return item

func _panel(parent: Node) -> PanelContainer:
	var item := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color("20212a")
	box.border_color = Color("8b7551")
	box.set_border_width_all(1)
	box.set_corner_radius_all(7)
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	item.add_theme_stylebox_override("panel", box)
	parent.add_child(item)
	return item

func _build_interface() -> void:
	root_ui = Control.new()
	add_child(root_ui)
	root_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Noto Sans CJK KR", "Malgun Gothic", "Apple SD Gothic Neo", "sans-serif"])
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 20
	root_ui.theme = theme
	view = BattleView.new()
	root_ui.add_child(view)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.offset_top = 88
	view.offset_bottom = -174
	view.simulation = simulation
	movement = MoveInput.new()
	root_ui.add_child(movement)
	movement.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var top := _panel(root_ui)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 16
	top.offset_top = 12
	top.offset_right = -16
	top.offset_bottom = 82
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 20)
	top.add_child(top_row)
	top_row.add_child(_label("VIYA / 반응 04", 24))
	var growth_column := VBoxContainer.new()
	growth_column.custom_minimum_size.x = 245
	top_row.add_child(growth_column)
	level_text = _label("Lv.1  EXP 0 / 30", 18)
	growth_column.add_child(level_text)
	experience = ProgressBar.new()
	experience.custom_minimum_size = Vector2(245, 12)
	experience.show_percentage = false
	growth_column.add_child(experience)
	stats_text = _label("", 19)
	stats_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(stats_text)
	top_row.add_child(_button("환경설정 II", pause_game))
	var tip := _label("임시 전투 · 왼쪽 이동 / 오른쪽 마법 터치 (PC: F) · 모든 스킬명·효과는 임시", 17)
	root_ui.add_child(tip)
	tip.position = Vector2(24, 94)
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bottom := _panel(root_ui)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 16
	bottom.offset_right = -16
	bottom.offset_top = -160
	bottom.offset_bottom = -12
	var bottom_row := HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 16)
	bottom.add_child(bottom_row)
	feedback_panel = FeedbackPanel.new()
	bottom_row.add_child(feedback_panel)
	var identity := VBoxContainer.new()
	identity.custom_minimum_size.x = 190
	bottom_row.add_child(identity)
	identity.add_child(_label("비야 · 전투 대역", 22))
	health = ProgressBar.new()
	health.custom_minimum_size = Vector2(185, 20)
	health.show_percentage = false
	identity.add_child(health)
	status_text = _label("HP 100 / 100", 18)
	identity.add_child(status_text)
	mana_bar = ProgressBar.new()
	mana_bar.custom_minimum_size = Vector2(185, 12)
	mana_bar.show_percentage = false
	identity.add_child(mana_bar)
	mana_text = _label("MP 0 / 0", 15)
	identity.add_child(mana_text)
	var slots := VBoxContainer.new()
	slots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_row.add_child(slots)
	_add_slots(slots, "공격", attack_slots)
	_add_slots(slots, "패시브", passive_slots)
	slots.add_child(_label("각 4칸은 임시 장착 한도 / 후보 종류 수와 별개", 13))
	var support := VBoxContainer.new()
	bottom_row.add_child(support)
	support.add_child(_label("공격 지원 [--] [--]", 15))
	support.add_child(_label("패시브 지원 [--] [--]", 15))
	support.add_child(_label("자리만 확보 · 효과 없음", 13))
	magic_button = Button.new()
	magic_button.text = "[임시] 고유 마법\n출격 대기"
	magic_button.custom_minimum_size = Vector2(170, 108)
	magic_button.disabled = true
	magic_button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	magic_button.focus_mode = Control.FOCUS_NONE
	magic_button.add_theme_font_size_override("font_size", 17)
	magic_button.pressed.connect(_cast_magic)
	bottom_row.add_child(magic_button)
	overlay = ColorRect.new()
	root_ui.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.02, 0.025, 0.035, 0.88)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var center := CenterContainer.new()
	overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialog = _panel(center)
	dialog.custom_minimum_size.x = 540
	dialog_body = VBoxContainer.new()
	dialog_body.add_theme_constant_override("separation", 14)
	dialog.add_child(dialog_body)

func _add_slots(parent: VBoxContainer, title: String, target: Array[Label]) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	var heading := _label(title, 17)
	heading.custom_minimum_size.x = 65
	row.add_child(heading)
	for index in range(4):
		var slot := _label("--", 14)
		slot.custom_minimum_size = Vector2(84, 42)
		slot.clip_text = true
		slot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(slot)
		target.append(slot)

func _clear_dialog() -> void:
	settings_message = null
	choice_buttons.clear()
	feedback_overlay_label = null
	result_summary_label = null
	for child in dialog_body.get_children():
		dialog_body.remove_child(child)
		child.queue_free()

func _show_levelup() -> void:
	if not _ensure_battle_saved():
		return
	_clear_dialog()
	dialog.custom_minimum_size.x = 1010
	last_ticket = simulation.growth.ticket
	movement.set_enabled(false)
	dialog_body.add_child(_label("레벨업 · 원하는 강화 하나를 선택", 28))
	_add_feedback_banner()
	dialog_body.add_child(_label("전투 정지 / 남은 선택 %d회 / 이름·효과·강화 상한은 임시" % simulation.growth.pending, 18))
	if not simulation.growth.pacing.focus(simulation.growth).is_empty():dialog_body.add_child(_label("보유 공격 강화 우선 후보 · Lv.5에서 공격 진화",16))
	var choices: Array[String] = simulation.growth.offer
	if choices.is_empty():
		dialog_body.add_child(_label("현재 장착 구성에서 더 강화할 후보가 없습니다.\n임시 처리: 추가 스킬·보상 없이 전투를 계속합니다.", 20))
		var done := _button("성장 완료 · 계속", _finish_exhausted.bind(last_ticket))
		dialog_body.add_child(done)
		choice_buttons.append(done)
	else:
		if choices.size() < 3:
			dialog_body.add_child(_label("강화 가능한 후보가 %d종 남아 모두 표시합니다." % choices.size(), 18))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		dialog_body.add_child(row)
		for id in choices:
			var entry: Dictionary = simulation.growth.definition(id)
			var rank: int = simulation.growth.skill_level(id)
			var kind: String = {"attack": "공통 공격", "character": "캐릭터 전용",
				"passive": "공통 패시브", "ultimate": "필살기 강화"}[entry["kind"]]
			var description: String = str(entry.levels[rank].change) if entry.has("levels") else str(entry.description)
			var text := "%s · %s\n\n%s\nLv.%d → Lv.%d\n\n%s\n\n[시제품 효과]" % [kind,
				"신규" if rank == 0 else "강화", entry["name"], rank, rank + 1, description]
			var preview: Dictionary = SkillPreview.build(simulation, id)
			text += "\n\n선택 시 변화\n" + SkillPreview.describe(preview)
			var card := _button(text, _choose_skill.bind(id, last_ticket))
			card.set_meta("skill_preview", preview.duplicate(true))
			card.custom_minimum_size = Vector2(310, 255)
			card.add_theme_font_size_override("font_size", 17)
			card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(card)
			choice_buttons.append(card)
	dialog_body.add_child(_button("환경설정 / 일시정지", pause_game))
	overlay.show()

func _choose_skill(id: String, ticket: int) -> void:
	if battle_save_error != OK or not simulation.select_skill(id, ticket):
		return
	if not _ensure_battle_saved():
		return
	for button in choice_buttons:
		button.disabled = true
	movement.clear_input()
	last_phase = -1
	_update_hud()
	if simulation.phase == RunState.Phase.RUNNING:
		overlay.hide()
	# Next offer is rebuilt on the next physics tick, never inside a pressed signal.
	_sync_movement()

func _finish_exhausted(ticket: int) -> void:
	if simulation.acknowledge_exhausted(ticket):
		if not _ensure_battle_saved():
			return
		for button in choice_buttons:
			button.disabled = true
		overlay.hide()
		movement.clear_input()
		last_phase = -1
		_sync_movement()

func _sync_movement() -> void:
	movement.set_enabled(simulation.phase == RunState.Phase.RUNNING)

func _show_menu(kind: String) -> void:
	_clear_dialog()
	dialog.custom_minimum_size.x = 620
	if kind == "ready":
		dialog_body.add_child(_label("VIYA | 전투·성장 시제품", 30))
		dialog_body.add_child(_label("처치 → 경험치 수집 → 무작위 3선택 → 강화", 19))
		dialog_body.add_child(_label("6분 생존 + 보스 처치 / 2·4분 자동 저장\n5분 보스 등장 / 18종 후보·3선택 / 오른쪽 마법 또는 F", 17))
		start_button = _button("출격", begin_run)
		dialog_body.add_child(start_button)
		_add_gold_status()
		if _has_saved_battle():
			start_button.text = "이어하기"
			var saved: Dictionary = run_store.pending.run
			dialog_body.add_child(_label("저장된 스테이지 %d · %.1f초 · 체크포인트 %d/2" % [saved.stage, saved.elapsed, saved.checkpoint_index], 18))
			dialog_body.add_child(_button("저장 전투 포기", _abandon_saved_run))
		if battle_save_error != OK:
			start_button.disabled = true
			dialog_body.add_child(_label("전투 저장 파일 오류 · %s" % error_string(battle_save_error), 17))
			dialog_body.add_child(_button("전투 불러오기 재시도", _retry_battle_load))
			dialog_body.add_child(_button("손상된 전투 저장 삭제", _ask_discard_save))
	elif kind == "paused":
		dialog_body.add_child(_label("일시정지 / 환경설정", 30))
		dialog_body.add_child(_label("선택·마력·반응 시간이 그대로 보존됩니다.", 18))
		_add_feedback_banner()
		dialog_body.add_child(_label("전체 음량 (저장 · 임시 전투 효과음)", 17))
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = volume
		slider.custom_minimum_size.y = 36
		slider.value_changed.connect(_set_volume)
		dialog_body.add_child(slider)
		_add_display_settings()
		resume_button = _button("계속하기", resume_game)
		resume_button.disabled = battle_save_error != OK
		dialog_body.add_child(resume_button)
		dialog_body.add_child(_button("새 전투 시작", begin_run))
		dialog_body.add_child(_button("저장 후 출격 대기로", _park_battle))
		_add_battle_save_error()
	else:
		_persist_battle()
		dialog_body.add_child(_label("전투 종료", 30))
		var summary: Dictionary = simulation.result_summary()
		result_summary_label = _label("Lv.%d / 생존 %.1f초 / 처치 %d\n발사 %d회 / 고유 마법 %d회" % [
			summary["level"], summary["elapsed"], summary["kills"],
			summary["shots"], summary["magic_casts"]], 22)
		dialog_body.add_child(result_summary_label)
		if kind == "cleared":
			gold_error = gold_progress.settle(summary) if battle_save_error == OK else battle_save_error
			result_summary_label.text += "\n기본 보상 %d + 획득 금화 %d = 총 %d 금화\n보유 금화 %d" % [summary["gold_bonus"], summary["gold_collected"], summary["gold_reward"], gold_progress.total]
			if gold_error != OK:
				dialog_body.add_child(_label("금화 저장 실패 · %s" % error_string(gold_error), 18))
				dialog_body.add_child(_button("금화 저장 재시도", _retry_gold_save))
		else:
			if simulation.run_mode=="gold_slime":
				gold_error=gold_progress.finish_dungeon(summary) if battle_save_error==OK else battle_save_error
				if gold_error!=OK:
					dialog_body.add_child(_label("던전 종료 저장 실패 · %s" % error_string(gold_error),18))
					dialog_body.add_child(_button("계정 저장 재시도",_retry_gold_save))
			result_summary_label.text += "\n획득 금화 %d · 클리어 보상 미지급\n보유 금화 %d" % [summary["gold_collected"], gold_progress.total]
		_add_feedback_banner()
		start_button = _button("다시 출격", begin_run)
		if kind == "cleared":
			start_button.text = "다음 스테이지"
			start_button.disabled = gold_error != OK
		start_button.disabled = start_button.disabled or battle_save_error != OK
		dialog_body.add_child(start_button)
		_add_battle_save_error()
	overlay.show()

func _update_hud() -> void:
	health.max_value = simulation.max_hp
	health.value = simulation.hp
	var seconds := int(simulation.elapsed)
	stats_text.text = "S%d %02d:%02d | 처치 %d | 금화 %d" % [simulation.stage, int(seconds / 60.0), seconds % 60, simulation.kills, simulation.gold_collected]
	stats_text.tooltip_text = "보유 금화 %d · 스테이지 금화 %d\n%.0f초 생존 및 보스 처치 시 클리어" % [gold_progress.total, simulation.gold_collected, simulation.stage_duration]
	if is_instance_valid(stage_text) and not simulation.stage_rules.is_empty():
		var remaining: int = maxi(0, int(ceil(simulation.stage_duration - simulation.elapsed)))
		var target: String = "보스 등장까지 %d초" % maxi(0, int(ceil(float(simulation.stage_rules.boss_at) - simulation.elapsed)))
		if simulation._boss_spawned:
			target = "보스 처치 완료 · 생존 유지" if simulation._boss_defeated else "보스 처치"
		stage_text.text = "스테이지 %d · 남은 시간 %02d:%02d · %s · 체크포인트 %d/2" % [simulation.stage, remaining / 60, remaining % 60, target, simulation.checkpoint_index]
	status_text.text = "HP %d / %d%s" % [simulation.hp, simulation.max_hp, " · 피격" if simulation.hurt_clock > 0.0 else ""]
	level_text.text = "Lv.%d  EXP %.1f / %.0f" % [simulation.growth.level, simulation.growth.xp, simulation.growth.threshold()]
	if simulation._slow_left > 0.0:
		status_text.text += " · 둔화 %.1f초" % simulation._slow_left
	experience.max_value = simulation.growth.threshold()
	experience.value = simulation.growth.xp
	if _slot_revision != simulation.growth.revision:
		_slot_revision = simulation.growth.revision
		_update_slots(attack_slots, "attack")
		_update_slots(passive_slots, "passive")
	_update_magic_hud()
	_update_feedback_hud()

func _update_slots(labels: Array[Label], row: String) -> void:
	var entries: Array[Dictionary] = simulation.growth.row_entries(row)
	for i in range(labels.size()):
		labels[i].text = "--"
		labels[i].tooltip_text = ""
		if i < entries.size():
			labels[i].text = "[임시]\n%s Lv.%d" % [str(entries[i]["name"]).trim_prefix("[임시] "), simulation.growth.skill_level(entries[i]["id"])]
			if simulation.growth.ruleset == "weapons_v1" and simulation.growth.skill_level(entries[i].id) == 5 and entries[i].kind != "passive":
				labels[i].text += " 진화"
			labels[i].tooltip_text = "%s\n%s" % [entries[i]["name"], entries[i]["description"]]
			if entries[i].has("levels"):
				labels[i].tooltip_text = "%s\n%s" % [entries[i].name,entries[i].levels[simulation.growth.skill_level(entries[i].id)-1].change]

func _update_magic_hud() -> void:
	var magic = simulation.magic
	_magic_ui_ticket = magic.ticket
	var running: bool = simulation.phase == RunState.Phase.RUNNING
	var reason: String = magic.unavailable_reason(running)
	magic_button.disabled = not reason.is_empty()
	mana_bar.max_value = magic.maximum_mana()
	mana_bar.value = magic.mana
	mana_text.text = "MP %.1f / %.0f" % [magic.mana, mana_bar.max_value]
	var state_label: String = "터치 / F"
	match reason:
		"inactive":
			state_label = "전투 중에만 사용"
		"unconfigured":
			state_label = "마법 설정 없음"
		"cooldown":
			state_label = "재사용 %.1f초" % magic.cooldown_left
		"mana":
			state_label = "마력 부족"
	magic_button.text = "%s\n강화 Lv.%d · MP %.1f\n%s" % [
		str(magic.config.get("name", "[임시] 고유 마법")),
		int(simulation.stats["ultimate"]), magic.effective_cost(), state_label]
	var info: Dictionary = magic.profile(int(simulation.stats["ultimate"]))
	magic_button.tooltip_text = "임시 효과 · 기본 피해 %.0f / 반경 %.0f / 소모 MP %.1f / 초당 MP 회복 %.2f" % [
		float(info.get("damage", 0.0)), float(info.get("radius", 0.0)),
		float(info.get("mana_cost", 0.0)), float(info.get("mana_regen", 0.0))]
	if float(info.get("cooldown", 0.0)) > 0.0:
		magic_button.tooltip_text += " / 재사용 %.1f초" % float(info.cooldown)

func _set_volume(value: float) -> void:
	volume = clampf(value, 0.0, 1.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(0, volume == 0.0)
	_save_settings()

func _load_settings() -> void:
	volume = 0.7
	show_damage = true
	show_xp = true
	simple_attacks = false
	var config := ConfigFile.new()
	if config.load(settings_path) == OK:
		var saved_volume: Variant = config.get_value("audio", "master", 0.7)
		if (saved_volume is float or saved_volume is int) and is_finite(float(saved_volume)):
			volume = clampf(float(saved_volume), 0.0, 1.0)
		for key in ["show_damage", "show_xp", "simple_attacks"]:
			var saved: Variant = config.get_value("display", key, key != "simple_attacks")
			set(key, saved if saved is bool else key != "simple_attacks")
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(0, volume == 0.0)

func _save_settings() -> void:
	var config := ConfigFile.new()
	settings_error = config.load(settings_path)
	if settings_error not in [OK, ERR_FILE_NOT_FOUND]:
		_update_settings_message()
		return
	config.set_value("audio", "master", volume)
	for key in ["show_damage", "show_xp", "simple_attacks"]:
		config.set_value("display", key, get(key))
	settings_error = config.save(settings_path + ".tmp")
	if settings_error == OK:
		settings_error = DirAccess.rename_absolute(ProjectSettings.globalize_path(settings_path + ".tmp"), ProjectSettings.globalize_path(settings_path))
	_update_settings_message()

func _add_display_settings() -> void:
	for entry in [["show_damage", "피해 숫자 표시"], ["show_xp", "XP 획득 문구 표시"], ["simple_attacks", "공격 장식 간소화"]]:
		var toggle := CheckBox.new()
		toggle.name = str(entry[0])
		toggle.text = str(entry[1])
		toggle.custom_minimum_size.y = 44
		toggle.button_pressed = bool(get(entry[0]))
		toggle.toggled.connect(_set_display_option.bind(str(entry[0])))
		dialog_body.add_child(toggle)
	settings_message = _label("", 16)
	dialog_body.add_child(settings_message)
	_update_settings_message()

func _set_display_option(value: bool, key: String) -> void:
	if key not in ["show_damage", "show_xp", "simple_attacks"]:
		return
	set(key, value)
	view.set(key, value)
	view.queue_redraw()
	_save_settings()

func _update_settings_message() -> void:
	if is_instance_valid(settings_message):
		settings_message.text = "설정은 변경 시 자동 저장됩니다." if settings_error == OK else "설정 저장 실패 · %s" % error_string(settings_error)

func _add_gold_status() -> void:
	dialog_body.add_child(_label("보유 금화 %d · 다음 스테이지 %d" % [gold_progress.total, gold_progress.next_stage], 19))
	if gold_error != OK:
		start_button.disabled = true
		dialog_body.add_child(_label("금화 파일 불러오기 실패 · %s" % error_string(gold_error), 17))
		dialog_body.add_child(_button("금화 불러오기 재시도", _retry_gold_load))

func _retry_gold_load() -> void:
	if simulation.phase != RunState.Phase.READY:
		return
	gold_error = gold_progress.load_progress()
	_recover_dungeon_admission()
	_show_menu("ready")
	if gold_error == OK and not run_store.pending.is_empty() and not _has_saved_battle():
		_resume_saved_run()

func _retry_gold_save() -> void:
	if simulation.phase not in [RunState.Phase.CLEARED,RunState.Phase.DEFEAT,RunState.Phase.ABANDONED]:return
	_show_menu({RunState.Phase.CLEARED:"cleared",RunState.Phase.DEFEAT:"defeat",RunState.Phase.ABANDONED:"abandoned"}[simulation.phase])

func _can_start_rewarded_run() -> bool:
	if not gold_progress.loaded or battle_save_error != OK or not gold_progress.dungeon.initial.is_empty() or ((simulation.phase == RunState.Phase.CLEARED or simulation.run_mode=="gold_slime") and gold_error != OK):
		return false
	return true

func _has_saved_battle() -> bool:
	return not run_store.pending.is_empty() and run_store.pending.run.phase in [RunState.Phase.RUNNING, RunState.Phase.PAUSED, RunState.Phase.CHOOSING]

func _persist_battle() -> bool:
	if simulation.has_active_run() or simulation.phase in [RunState.Phase.CLEARED, RunState.Phase.DEFEAT, RunState.Phase.ABANDONED]:
		battle_save_error = run_store.save_current(simulation)
		if battle_save_error == OK:
			_saved_checkpoint = simulation.checkpoint_index
	return battle_save_error == OK

func _ensure_battle_saved() -> bool:
	if _persist_battle():
		return true
	if simulation.has_active_run():
		simulation.set_paused(true)
		movement.set_enabled(false)
		last_phase = simulation.phase
		_show_menu("paused")
	return false

func _retry_battle_save() -> void:
	if simulation.phase not in [RunState.Phase.PAUSED, RunState.Phase.DEFEAT, RunState.Phase.ABANDONED, RunState.Phase.CLEARED]:
		return
	if not _ensure_battle_saved():
		return
	var kind: String = {RunState.Phase.CLEARED: "cleared", RunState.Phase.DEFEAT: "defeat", RunState.Phase.ABANDONED: "abandoned"}.get(simulation.phase, "paused")
	_show_menu(kind)

func _add_battle_save_error() -> void:
	if battle_save_error != OK:
		dialog_body.add_child(_label("전투 저장 실패 · %s" % error_string(battle_save_error), 17))
		dialog_body.add_child(_button("전투 저장 재시도", _retry_battle_save))

func _retry_battle_load() -> void:
	if simulation.phase == RunState.Phase.READY:
		battle_save_error = run_store.load_saved(simulation)
		_recover_dungeon_admission()
		_show_menu("ready")
		if battle_save_error == OK and not run_store.pending.is_empty() and not _has_saved_battle():
			_resume_saved_run()

func _resume_saved_run() -> void:
	if simulation.phase != RunState.Phase.READY or run_store.pending.is_empty() or not gold_progress.loaded:
		return
	var saved: Dictionary = run_store.pending.run
	if saved.get("run_mode","campaign")=="gold_slime":
		if not gold_progress.dungeon_allows(saved):
			battle_save_error=ERR_FILE_CORRUPT
			_show_menu("ready")
			return
	var paid: bool = saved.phase == RunState.Phase.CLEARED and saved.run_id == gold_progress.last_run and saved.stage + 1 == gold_progress.next_stage
	if saved.get("run_mode","campaign")=="campaign" and ((saved.stage != gold_progress.next_stage and not paid) or (saved.run_id == gold_progress.last_run and not paid)):
		battle_save_error = ERR_FILE_CORRUPT
		_show_menu("ready")
		return
	if not RunStore.Snapshot.restore(run_store.pending, simulation):
		battle_save_error = ERR_FILE_CORRUPT
		_show_menu("ready")
		return
	_slot_revision = -1
	last_ticket = -1
	last_phase = -1
	movement.clear_input()
	movement.set_enabled(false)
	if simulation.phase == RunState.Phase.PAUSED:
		_ensure_battle_saved()
		_show_menu("paused")
	else:
		_sync_phase_ui()
	_update_hud()
	view.queue_redraw()

func _park_battle() -> void:
	if simulation.phase != RunState.Phase.PAUSED or not _ensure_battle_saved():
		return
	if simulation.park_saved_run():
		last_phase = simulation.phase
		_show_menu("ready")

func _abandon_saved_run() -> void:
	_resume_saved_run()
	if simulation.phase == RunState.Phase.PAUSED:
		pause_game()

func _ask_discard_save() -> void:
	if simulation.phase != RunState.Phase.READY:
		return
	_clear_dialog()
	dialog_body.add_child(_label("저장된 전투를 삭제할까요?", 24))
	dialog_body.add_child(_label("이번 전투의 진행과 획득 금화가 사라집니다. 보유 금화는 유지됩니다.", 18))
	dialog_body.add_child(_button("취소", _show_menu.bind("ready")))
	dialog_body.add_child(_button("확인 · 저장 삭제", _discard_saved_run))

func _discard_saved_run() -> void:
	if simulation.phase == RunState.Phase.READY:
		if not gold_progress.dungeon.initial.is_empty():
			var entry: Dictionary=gold_progress.dungeon.initial.run
			gold_error=gold_progress.finish_dungeon({"run_mode":"gold_slime","outcome":"abandoned","run_id":entry.run_id,"dungeon_day":entry.dungeon_day,"stage":entry.stage,"gold_reward":0})
			if gold_error!=OK:
				_show_menu("ready")
				return
		battle_save_error = run_store.discard()
		_show_menu("ready")


func _add_feedback_banner() -> void:
	feedback_overlay_label = _label("", 18)
	feedback_overlay_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog_body.add_child(feedback_overlay_label)

func _update_feedback_hud() -> void:
	var data: Dictionary = simulation.feedback.snapshot(simulation.hp, simulation.max_hp)
	var context: String = ""
	match simulation.phase:
		RunState.Phase.READY:
			context = "출격 대기"
		RunState.Phase.PAUSED:
			context = "정지 · 반응 보존"
		RunState.Phase.CHOOSING:
			context = "선택 · 반응 보존"
	if is_instance_valid(feedback_panel):
		feedback_panel.present(data, context)
	if is_instance_valid(feedback_overlay_label):
		feedback_overlay_label.text = "비야 상태: %s%s" % [data["label"],
			" / 저체력 경고 유지" if bool(data["low_hp"]) else ""]
		feedback_overlay_label.add_theme_color_override("font_color", Color(str(data["accent"])))
