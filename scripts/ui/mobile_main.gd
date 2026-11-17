extends "res://scripts/main.gd"
## GAME-004B presentation adapter. All combat/growth/magic/feedback state stays
## in the existing main and simulation scripts. No new artwork or balance rules.
const HudLayout = preload("res://scripts/ui/hud_layout.gd")
const ResponsiveFeedback = preload("res://scripts/ui/responsive_feedback_panel.gd")
var layout_data: Dictionary = {}
var safe_area_override := Rect2() # Logical-coordinate test injection, empty in production.
var slot_buttons: Array[Button] = []
var detail_return_button: Button
var _header: PanelContainer
var _header_row: HBoxContainer
var _brand: Label
var _growth_column: VBoxContainer
var _settings_button: Button
var _resources: VBoxContainer
var _identity_title: Label
var _skills: VBoxContainer
var _support: Label
var _modal_host: Control
var _scroll: ScrollContainer
var _choice_grid: GridContainer
var _modal_kind: String = "ready"
var _detail_open := false
var _layout_queued := false

func _ready() -> void:
	super._ready()
	root_ui.resized.connect(_queue_layout)
	get_viewport().size_changed.connect(_queue_layout)
	_apply_layout()

func _build_interface() -> void:
	root_ui = Control.new()
	root_ui.name = "MobileHUD"
	add_child(root_ui)
	root_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Noto Sans CJK KR", "Malgun Gothic", "Apple SD Gothic Neo", "sans-serif"])
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 18
	root_ui.theme = theme
	view = BattleView.new()
	root_ui.add_child(view)
	view.simulation = simulation
	movement = MoveInput.new()
	root_ui.add_child(movement)
	movement.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_header = _panel(root_ui)
	_header_row = HBoxContainer.new()
	_header_row.add_theme_constant_override("separation", 12)
	_header.add_child(_header_row)
	_brand = _label("VIYA / 04B", 21)
	_header_row.add_child(_brand)
	_growth_column = VBoxContainer.new()
	_growth_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_row.add_child(_growth_column)
	level_text = _label("Lv.1  EXP 0 / 30", 17)
	level_text.clip_text = true
	_growth_column.add_child(level_text)
	experience = ProgressBar.new()
	experience.custom_minimum_size.y = 12
	experience.show_percentage = false
	_growth_column.add_child(experience)
	stats_text = _label("", 16)
	stats_text.clip_text = true
	_header_row.add_child(stats_text)
	_settings_button = _button("환경설정 II", pause_game)
	_settings_button.custom_minimum_size = Vector2(120, 44)
	_settings_button.add_theme_font_size_override("font_size", 16)
	_header_row.add_child(_settings_button)
	feedback_panel = ResponsiveFeedback.new()
	root_ui.add_child(feedback_panel)
	_resources = VBoxContainer.new()
	_resources.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_resources.add_theme_constant_override("separation", 3)
	root_ui.add_child(_resources)
	_identity_title = _label("비야 · 전투 대역", 19)
	_resources.add_child(_identity_title)
	status_text = _label("HP 100 / 100", 17)
	status_text.clip_text = true
	_resources.add_child(status_text)
	health = ProgressBar.new()
	health.custom_minimum_size.y = 15
	health.show_percentage = false
	health.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_resources.add_child(health)
	mana_text = _label("MP 0 / 0", 15)
	mana_text.clip_text = true
	_resources.add_child(mana_text)
	mana_bar = ProgressBar.new()
	mana_bar.custom_minimum_size.y = 10
	mana_bar.show_percentage = false
	mana_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_resources.add_child(mana_bar)
	_skills = VBoxContainer.new()
	_skills.add_theme_constant_override("separation", 4)
	root_ui.add_child(_skills)
	_add_slots(_skills, "공격", attack_slots)
	_add_slots(_skills, "패시브", passive_slots)
	_support = _label("공격 지원 [--] [--]   /   패시브 지원 [--] [--] · 효과 없음", 12)
	_support.clip_text = true
	_support.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ui.add_child(_support)
	magic_button = Button.new()
	magic_button.text = "[임시] 고유 마법\n출격 대기"
	magic_button.disabled = true
	magic_button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	magic_button.focus_mode = Control.FOCUS_NONE
	magic_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	magic_button.add_theme_font_size_override("font_size", 16)
	magic_button.pressed.connect(_cast_magic)
	root_ui.add_child(magic_button)
	overlay = ColorRect.new()
	root_ui.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.02, 0.025, 0.035, 0.88)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal_host = Control.new()
	_modal_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(_modal_host)
	dialog = _panel(_modal_host)
	dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.follow_focus = true
	dialog.add_child(_scroll)
	dialog_body = VBoxContainer.new()
	dialog_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dialog_body.add_theme_constant_override("separation", 10)
	_scroll.add_child(dialog_body)
	_apply_layout()

func _add_slots(parent: VBoxContainer, title: String, target: Array[Label]) -> void:
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)
	var heading := _label(title, 14)
	heading.custom_minimum_size.x = 48
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(heading)
	var row_id := "attack" if title == "공격" else "passive"
	for index in range(4):
		var button := Button.new()
		button.name = "%s_%d_details" % [row_id, index]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 38)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_open_owned_detail.bind(row_id, index))
		row.add_child(button)
		var label := _label("--", 14)
		label.clip_text = true
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(label)
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		label.offset_left = 4
		label.offset_right = -4
		target.append(label)
		slot_buttons.append(button)

func _safe_rect() -> Rect2:
	var full := Rect2(Vector2.ZERO, root_ui.size)
	if safe_area_override.has_area():
		return full.intersection(safe_area_override)
	if OS.get_name() in ["Android", "iOS"] and DisplayServer.get_name() != "headless":
		var physical := Rect2(DisplayServer.get_display_safe_area())
		# Screen pixels -> root_ui coordinates, including viewport stretch/letterbox.
		var converted: Rect2 = root_ui.get_screen_transform().affine_inverse() * physical
		var clipped := full.intersection(converted)
		if clipped.has_area():
			return clipped
	return full

func _queue_layout() -> void:
	if _layout_queued:
		return
	_layout_queued = true
	call_deferred("_apply_layout")

func _place(control: Control, rect: Rect2) -> void:
	control.position = rect.position
	control.size = rect.size

func _apply_layout() -> void:
	_layout_queued = false
	if not is_instance_valid(root_ui) or not is_instance_valid(_modal_host):
		return
	var new_layout: Dictionary = HudLayout.build(root_ui.size, _safe_rect())
	if new_layout != layout_data:
		# A layout change cancels input ownership, not XP, offers or cooldowns.
		movement.clear_input()
		_magic_touch_id = -1
		simulation.magic.invalidate_requests()
	layout_data = new_layout
	var compact: bool = layout_data["compact"]
	feedback_panel.fit_compact(compact)
	_identity_title.visible = not compact
	_brand.visible = not compact
	stats_text.custom_minimum_size.x = 185.0 if compact else 245.0
	_settings_button.custom_minimum_size = Vector2(116, 36 if compact else 44)
	_header_row.add_theme_constant_override("separation", 6 if compact else 12)
	var style: StyleBoxFlat = _header.get_theme_stylebox("panel") as StyleBoxFlat
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	_place(_header, layout_data["top"])
	_place(view, layout_data["battle"])
	_place(feedback_panel, layout_data["feedback"])
	_place(_resources, layout_data["resources"])
	_place(_skills, layout_data["skills"])
	_place(_support, layout_data["support"])
	_place(magic_button, layout_data["magic"])
	var local_to_move: Transform2D = movement.get_global_transform_with_canvas().affine_inverse() * root_ui.get_global_transform_with_canvas()
	movement.set_interaction_rect(local_to_move * layout_data["move"])
	_fit_dialog()
	_update_magic_hud()

func _clear_dialog() -> void:
	_choice_grid = null
	detail_return_button = null
	super._clear_dialog()

func _show_menu(kind: String) -> void:
	_modal_kind = kind
	_detail_open = false
	super._show_menu(kind)
	_scroll.scroll_vertical = 0
	_fit_dialog()

func _show_levelup() -> void:
	_modal_kind = "choosing"
	_detail_open = false
	super._show_levelup()
	_scroll.scroll_vertical = 0
	if not choice_buttons.is_empty() and choice_buttons[0].get_parent() is HBoxContainer:
		var old_row: HBoxContainer = choice_buttons[0].get_parent() as HBoxContainer
		var index := old_row.get_index()
		_choice_grid = GridContainer.new()
		_choice_grid.name = "ResponsiveChoiceGrid"
		_choice_grid.add_theme_constant_override("h_separation", 10)
		_choice_grid.add_theme_constant_override("v_separation", 10)
		dialog_body.add_child(_choice_grid)
		dialog_body.move_child(_choice_grid, index)
		for button in choice_buttons:
			button.reparent(_choice_grid)
		dialog_body.remove_child(old_row)
		old_row.queue_free()
	_fit_dialog()

func _fit_dialog() -> void:
	if layout_data.is_empty() or not is_instance_valid(dialog):
		return
	dialog.custom_minimum_size = Vector2.ZERO
	_place(_modal_host, layout_data["modal"])
	for child in dialog_body.get_children():
		if child is Label:
			child.custom_minimum_size.x = 0.0
			child.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if child.get_theme_font_size("font_size") > 24:
				child.add_theme_font_size_override("font_size", 24)
	if is_instance_valid(_choice_grid):
		_choice_grid.columns = int(layout_data["card_columns"])
		for button in choice_buttons:
			button.custom_minimum_size = Vector2(0, 228 if _choice_grid.columns == 3 else 192)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			button.add_theme_font_size_override("font_size", 16)

func _update_slots(labels: Array[Label], row: String) -> void:
	super._update_slots(labels, row)
	for label in labels:
		var button: Button = label.get_parent() as Button
		button.disabled = label.text == "--"
		button.tooltip_text = label.tooltip_text

func _open_owned_detail(row: String, index: int) -> void:
	if overlay.visible:
		return
	var entries: Array[Dictionary] = simulation.growth.row_entries(row)
	if index < 0 or index >= entries.size():
		return
	_open_skill_detail(str(entries[index]["id"]))

func _open_skill_detail(id: String) -> void:
	if _detail_open or simulation.phase not in [RunState.Phase.RUNNING, RunState.Phase.CHOOSING]:
		return
	var entry: Dictionary = simulation.growth.definition(id)
	if entry.is_empty() or simulation.growth.skill_level(id) <= 0:
		return
	_detail_open = true
	_modal_kind = "detail"
	_magic_touch_id = -1
	movement.set_enabled(false)
	simulation.set_paused(true)
	last_phase = simulation.phase
	_clear_dialog()
	_scroll.scroll_vertical = 0
	dialog_body.add_child(_label(str(entry["name"]), 24))
	dialog_body.add_child(_label("보유 Lv.%d / 시험 상한 Lv.%d" % [simulation.growth.skill_level(id), int(entry["max_level"])], 19))
	dialog_body.add_child(_label(str(entry["description"]), 21))
	dialog_body.add_child(_label("읽기 전용 · 이름과 효과는 임시입니다.\n이 창에서는 스킬 획득·강화·마법 발동이 일어나지 않습니다.\n닫으면 이전 전투 또는 같은 레벨업 선택창으로 돌아갑니다.", 17))
	detail_return_button = _button("닫기 · 이전 화면으로", _close_skill_detail)
	dialog_body.add_child(detail_return_button)
	overlay.show()
	_fit_dialog()
	_update_hud()

func _close_skill_detail() -> void:
	if not _detail_open or simulation.phase != RunState.Phase.PAUSED:
		return
	_detail_open = false
	super.resume_game()

func begin_run() -> void:
	_detail_open = false
	super.begin_run()
	_scroll.scroll_vertical = 0

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and is_instance_valid(movement) and event.index == movement.touch_id:
		return # A held movement finger cannot turn into a magic finger over the button.
	super._input(event)

func _unhandled_key_input(event: InputEvent) -> void:
	if _detail_open and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_close_skill_detail()
		get_viewport().set_input_as_handled()
		return
	super._unhandled_key_input(event)

func pause_game() -> void:
	# The inherited _notification handles focus/input release. Intercept only a
	# paused detail: explicit Continue is required after an app interruption.
	if _detail_open and simulation.phase == RunState.Phase.PAUSED:
		_detail_open = false
		_magic_touch_id = -1
		movement.set_enabled(false)
		_show_menu("paused")
		_update_hud()
		return
	super.pause_game()
