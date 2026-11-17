extends Node
const RunState = preload("res://scripts/combat/run_state.gd")
const BattleView = preload("res://scripts/combat/battle_view.gd")
const MoveInput = preload("res://scripts/ui/move_input.gd")
const FeedbackPanel = preload("res://scripts/ui/feedback_panel.gd")
const SkillPreview = preload("res://scripts/ui/skill_preview.gd")

var simulation = RunState.new()
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

func _ready() -> void:
	_load_settings()
	_build_interface()
	_show_menu("ready")
	_update_hud()

func _physics_process(delta: float) -> void:
	simulation.step(delta, movement.direction())
	_sync_phase_ui()
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
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_magic_touch_id = -1
		if is_instance_valid(movement):
			movement.clear_input()
		if is_instance_valid(overlay):
			pause_game()

func begin_run() -> void:
	_magic_touch_id = -1
	if not simulation.start():
		push_error("Invalid character skill catalog; run not started")
		return
	movement.clear_input()
	movement.set_enabled(true)
	overlay.hide()
	last_phase = simulation.phase
	last_ticket = -1
	_update_hud()

func pause_game() -> void:
	if simulation.phase not in [RunState.Phase.RUNNING, RunState.Phase.CHOOSING]:
		return
	_magic_touch_id = -1
	simulation.set_paused(true)
	movement.set_enabled(false)
	last_phase = simulation.phase
	_show_menu("paused")
	_update_hud()

func resume_game() -> void:
	if simulation.phase != RunState.Phase.PAUSED:
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
	choice_buttons.clear()
	feedback_overlay_label = null
	result_summary_label = null
	for child in dialog_body.get_children():
		dialog_body.remove_child(child)
		child.queue_free()

func _show_levelup() -> void:
	_clear_dialog()
	dialog.custom_minimum_size.x = 1010
	last_ticket = simulation.growth.ticket
	movement.set_enabled(false)
	dialog_body.add_child(_label("레벨업 · 원하는 강화 하나를 선택", 28))
	_add_feedback_banner()
	dialog_body.add_child(_label("전투 정지 / 남은 선택 %d회 / 이름·효과·강화 상한은 임시" % simulation.growth.pending, 18))
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
			var text := "%s · %s\n\n%s\nLv.%d → Lv.%d\n\n%s\n\n[시제품 효과]" % [kind,
				"신규" if rank == 0 else "강화", entry["name"], rank, rank + 1, entry["description"]]
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
	if not simulation.select_skill(id, ticket):
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
		dialog_body.add_child(_label("18종 후보 / 임시 장착 공격4·패시브4 / 요구 경험치 3배\n고유 마법: 오른쪽 버튼 또는 F / 서포터 효과는 미구현", 17))
		start_button = _button("출격", begin_run)
		dialog_body.add_child(start_button)
	elif kind == "paused":
		dialog_body.add_child(_label("일시정지 / 환경설정", 30))
		dialog_body.add_child(_label("선택·마력·반응 시간이 그대로 보존됩니다.", 18))
		_add_feedback_banner()
		dialog_body.add_child(_label("전체 음량 (저장 · 전투 음원은 미탑재)", 17))
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = volume
		slider.custom_minimum_size.y = 36
		slider.value_changed.connect(_set_volume)
		dialog_body.add_child(slider)
		resume_button = _button("계속하기", resume_game)
		dialog_body.add_child(resume_button)
		dialog_body.add_child(_button("새 전투 시작", begin_run))
	else:
		dialog_body.add_child(_label("전투 종료", 30))
		var summary: Dictionary = simulation.result_summary()
		result_summary_label = _label("Lv.%d / 생존 %.1f초 / 처치 %d\n발사 %d회 / 고유 마법 %d회" % [
			summary["level"], summary["elapsed"], summary["kills"],
			summary["shots"], summary["magic_casts"]], 22)
		dialog_body.add_child(result_summary_label)
		_add_feedback_banner()
		start_button = _button("다시 출격", begin_run)
		dialog_body.add_child(start_button)
	overlay.show()

func _update_hud() -> void:
	health.max_value = simulation.max_hp
	health.value = simulation.hp
	var seconds := int(simulation.elapsed)
	stats_text.text = "%02d:%02d | 처치 %d | 적 %d/%d" % [int(seconds / 60.0), seconds % 60, simulation.kills, simulation.enemies.size(), RunState.MAX_ENEMIES]
	status_text.text = "HP %d / %d%s" % [simulation.hp, simulation.max_hp, " · 피격" if simulation.hurt_clock > 0.0 else ""]
	level_text.text = "Lv.%d  EXP %.1f / %.0f" % [simulation.growth.level, simulation.growth.xp, simulation.growth.threshold()]
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
			labels[i].tooltip_text = "%s\n%s" % [entries[i]["name"], entries[i]["description"]]

func _update_magic_hud() -> void:
	var magic = simulation.magic
	_magic_ui_ticket = magic.ticket
	var running: bool = simulation.phase == RunState.Phase.RUNNING
	var reason: String = magic.unavailable_reason(running)
	magic_button.disabled = not reason.is_empty()
	mana_bar.max_value = float(magic.config.get("max_mana", 100.0))
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
	magic_button.text = "%s\n강화 Lv.%d · MP %.0f\n%s" % [
		str(magic.config.get("name", "[임시] 고유 마법")),
		int(simulation.stats["ultimate"]), float(magic.config.get("mana_cost", 0.0)), state_label]
	var info: Dictionary = magic.profile(int(simulation.stats["ultimate"]))
	magic_button.tooltip_text = "임시 효과 · 기본 피해 %.0f / 반경 %.0f / 쿨다운 %.1f초" % [
		float(info.get("damage", 0.0)), float(info.get("radius", 0.0)), float(info.get("cooldown", 0.0))]

func _set_volume(value: float) -> void:
	volume = clampf(value, 0.0, 1.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(0, volume == 0.0)
	var config := ConfigFile.new()
	config.set_value("audio", "master", volume)
	var result := config.save("user://viya_settings.cfg")
	if result != OK:
		push_warning("Could not save Viya settings: %d" % result)

func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load("user://viya_settings.cfg") == OK:
		volume = clampf(float(config.get_value("audio", "master", 0.7)), 0.0, 1.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(0, volume == 0.0)


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
