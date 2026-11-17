extends Node
const RunState = preload("res://scripts/combat/run_state.gd")
const BattleView = preload("res://scripts/combat/battle_view.gd")
const MoveInput = preload("res://scripts/ui/move_input.gd")

var simulation = RunState.new()
var view
var movement
var root_ui: Control
var health: ProgressBar
var status_text: Label
var stats_text: Label
var overlay: ColorRect
var dialog_body: VBoxContainer
var start_button: Button
var resume_button: Button
var volume: float = 0.7
var last_phase: int = -1

func _ready() -> void:
	_load_settings()
	_build_interface()
	_show_menu("ready")
	_update_hud()

func _physics_process(delta: float) -> void:
	simulation.step(delta, movement.direction())
	if simulation.phase != last_phase:
		movement.set_enabled(simulation.phase == RunState.Phase.RUNNING)
		if simulation.phase == RunState.Phase.DEFEAT:
			_show_menu("defeat")
		last_phase = simulation.phase
	_update_hud()
	view.queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if simulation.phase == RunState.Phase.RUNNING:
			pause_game()
		elif simulation.phase == RunState.Phase.PAUSED:
			resume_game()
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if is_instance_valid(movement):
			movement.clear_input()
		if simulation.phase == RunState.Phase.RUNNING and is_instance_valid(overlay):
			pause_game()

func begin_run() -> void:
	simulation.start()
	movement.clear_input()
	movement.set_enabled(true)
	overlay.hide()
	last_phase = simulation.phase

func pause_game() -> void:
	if simulation.phase != RunState.Phase.RUNNING:
		return
	simulation.set_paused(true)
	movement.set_enabled(false)
	_show_menu("paused")

func resume_game() -> void:
	if simulation.phase != RunState.Phase.PAUSED:
		return
	movement.clear_input()
	simulation.set_paused(false)
	movement.set_enabled(true)
	overlay.hide()

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
	# System fallback; no copyrighted font file is bundled.
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Noto Sans CJK KR", "Malgun Gothic", "Apple SD Gothic Neo", "sans-serif"])
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 20
	root_ui.theme = theme
	view = BattleView.new()
	root_ui.add_child(view)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.offset_top = 78
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
	top.offset_bottom = 72
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 24)
	top.add_child(top_row)
	top_row.add_child(_label("VIYA  /  전투 기반 01", 25))
	stats_text = _label("00:00  |  처치 0  |  적 0 / 80", 21)
	stats_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(stats_text)
	var settings := _button("환경설정  II", pause_game)
	top_row.add_child(settings)
	var tip := _label("임시 전투 표현 · WASD/방향키 또는 왼쪽 전장 드래그로 이동 · 자동사격", 17)
	root_ui.add_child(tip)
	tip.position = Vector2(24, 87)
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bottom := _panel(root_ui)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 16
	bottom.offset_right = -16
	bottom.offset_top = -160
	bottom.offset_bottom = -12
	var bottom_row := HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 20)
	bottom.add_child(bottom_row)
	var identity := VBoxContainer.new()
	identity.custom_minimum_size.x = 195
	bottom_row.add_child(identity)
	identity.add_child(_label("비야 · 전투 대역", 23))
	health = ProgressBar.new()
	health.custom_minimum_size = Vector2(190, 25)
	health.max_value = 100
	health.show_percentage = false
	identity.add_child(health)
	status_text = _label("HP 100 / 100", 19)
	identity.add_child(status_text)
	identity.add_child(_label("승인 원화 보존 · 모델 보류", 14))
	var slots := VBoxContainer.new()
	slots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_row.add_child(slots)
	_add_slots(slots, "공격 스킬", true)
	_add_slots(slots, "패시브", false)
	slots.add_child(_label("레벨업 선택·강화: 다음 제작 단위", 14))
	var support := VBoxContainer.new()
	support.custom_minimum_size.x = 150
	bottom_row.add_child(support)
	support.add_child(_label("공격 지원   [ -- ] [ -- ]", 17))
	support.add_child(_label("패시브 지원 [ -- ] [ -- ]", 17))
	support.add_child(_label("자리만 확보 · 효과 없음", 14))
	var magic := Button.new()
	magic.text = "고유 마법\n연결 예정"
	magic.custom_minimum_size = Vector2(136, 112)
	magic.disabled = true
	bottom_row.add_child(magic)
	overlay = ColorRect.new()
	root_ui.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.02, 0.025, 0.035, 0.88)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var center := CenterContainer.new()
	overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dialog := _panel(center)
	dialog.custom_minimum_size.x = 540
	dialog_body = VBoxContainer.new()
	dialog_body.add_theme_constant_override("separation", 14)
	dialog.add_child(dialog_body)

func _add_slots(parent: VBoxContainer, title: String, attack: bool) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var title_label := _label(title, 18)
	title_label.custom_minimum_size.x = 100
	row.add_child(title_label)
	for index in range(4):
		var slot := Label.new()
		slot.text = "소총 1" if attack and index == 0 else "--"
		slot.custom_minimum_size = Vector2(64, 38)
		slot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slot.add_theme_font_size_override("font_size", 17)
		row.add_child(slot)

func _show_menu(kind: String) -> void:
	for child in dialog_body.get_children():
		dialog_body.remove_child(child)
		child.queue_free()
	if kind == "ready":
		dialog_body.add_child(_label("VIYA  |  전투 기반 시제품", 30))
		dialog_body.add_child(_label("이동 → 자동사격 → 피격 → 사망 → 재시작", 19))
		dialog_body.add_child(_label("캐릭터·적·전장은 임시 도형입니다.\n서포터 효과, 레벨업, 마법은 아직 연결되지 않았습니다.", 17))
		start_button = _button("출격", begin_run)
		dialog_body.add_child(start_button)
	elif kind == "paused":
		dialog_body.add_child(_label("일시정지 / 환경설정", 30))
		dialog_body.add_child(_label("전투·탄환·생성·피격 타이머가 멈춥니다.", 18))
		dialog_body.add_child(_label("전체 음량 (설정 저장 · 전투 음원은 미탑재)", 17))
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
		dialog_body.add_child(_label("생존 %.1f초   /   처치 %d   /   발사 %d" % [simulation.elapsed, simulation.kills, simulation.shots], 22))
		dialog_body.add_child(_label("이번 단계는 재시작 가능한 기본 생존 루프입니다.", 17))
		start_button = _button("다시 출격", begin_run)
		dialog_body.add_child(start_button)
	overlay.show()

func _update_hud() -> void:
	health.value = simulation.hp
	var seconds := int(simulation.elapsed)
	stats_text.text = "%02d:%02d  |  처치 %d  |  적 %d / %d" % [int(seconds / 60.0), seconds % 60, simulation.kills, simulation.enemies.size(), RunState.MAX_ENEMIES]
	status_text.text = "HP %d / 100%s" % [simulation.hp, " · 피격" if simulation.hurt_clock > 0.0 else ""]

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
