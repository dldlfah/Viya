extends "res://scripts/main.gd"
## GAME-004B presentation adapter. All combat/growth/magic/feedback state stays
## in the existing main and simulation scripts. No new artwork or balance rules.
const HudLayout = preload("res://scripts/ui/hud_layout.gd")
const ResponsiveFeedback = preload("res://scripts/ui/responsive_feedback_panel.gd")
const GrowthOverview = preload("res://scripts/ui/growth_overview.gd")
const AccountTalents = preload("res://scripts/progression/account_talents.gd")
const CombatSkin=preload("res://scripts/ui/combat_skin.gd")
const CombatSlot=preload("res://scripts/ui/combat_slot_button.gd")
var combat_skin=CombatSkin.new()
var battle_chrome
var combat_audio=preload("res://scripts/combat/combat_audio.gd").new()
const SaveNotice=preload("res://scripts/ui/battle_save_notice.gd")
var save_notice=SaveNotice.new()
var encounter_notice=preload("res://scripts/ui/encounter_notice.gd").new()
var _restoring_battle:bool=false
var _saved_context_label:Label
var mission_button:Button
var mission_return_button:Button
var _mission_open:bool=false
var _mission_touch_id:int=-1
var _phase_text:Label
var ui_art = preload("res://scripts/ui/asset_slots.gd").new()
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
var confirm_button: Button
var cancel_button: Button
var leave_button: Button
var lobby_button: Button
var _menu_revision: int = 0
var overview_button: Button
var overview_return_button: Button
var _overview_open := false
var _overview_origin: String = ""
var _final_growth: Dictionary = {}
var talents_button: Button
var talents_return_button: Button
var talent_tabs: Array[Button] = []
var talent_buy_buttons: Array[Button] = []
var talent_buttons_by_id: Dictionary = {}
var talent_content: VBoxContainer
var _talent_grid: GridContainer
var _talents_open := false
var _talent_category := "attack"
var _talent_notice := ""
var stage_launch_button: Button
var stage_back_button: Button
var lobby_settings_button: Button
var stage_buttons: Array[Button] = []
var _selected_stage: int = 1
var boss_bar: ProgressBar
var boss_label: Label
var ailment_text: Label
var dungeon_button: Button
var dungeon_launch_button: Button
var _dungeon_notice: String = ""

func _ready() -> void:
	add_child(combat_audio)
	super._ready()
	save_notice.seed(run_store.pending,battle_save_error)
	# Recover/pay terminal intent first, then start at the lobby with its frozen result.
	if battle_save_error == OK and gold_error == OK and simulation.phase in [RunState.Phase.CLEARED, RunState.Phase.DEFEAT, RunState.Phase.ABANDONED]:
		if simulation.return_to_ready(simulation.navigation_ticket):
			last_phase = simulation.phase
			_show_menu("ready")
	root_ui.resized.connect(_queue_layout)
	get_viewport().size_changed.connect(_queue_layout)
	_apply_layout()

func _physics_process(delta: float) -> void:
	combat_audio.prepare(simulation,not overlay.visible)
	var track_enemies:bool=view.tracks_enemy_motion()
	var motion_region:Rect2=(view.BattleProjection.visible_world(view.camera_center(),view.size) if view.high_angle else Rect2(view.camera_center()-view.size*.5,view.size)).grow(180)
	view.actors.prepare(simulation,track_enemies,motion_region)
	var before:Vector2=simulation.player
	var active:bool=simulation.phase==RunState.Phase.RUNNING and not overlay.visible
	super._physics_process(delta)
	view.advance_camera(delta,simulation.player-before,active and simulation.phase==RunState.Phase.RUNNING and not overlay.visible)
	view.actors.sync(simulation,simulation.player-before,active and simulation.phase==RunState.Phase.RUNNING and not overlay.visible,track_enemies,motion_region)
	combat_audio.finish(simulation,active,not overlay.visible)

func _cast_magic(expected_ticket:int=-1) -> void:
	var active:bool=simulation.phase==RunState.Phase.RUNNING and not overlay.visible
	combat_audio.prepare(simulation,not overlay.visible)
	super._cast_magic(expected_ticket)
	_sync_phase_ui() # Build a resulting modal before its one-shot audio starts.
	combat_audio.finish(simulation,active,not overlay.visible)

func _set_volume(value:float) -> void:
	super._set_volume(value)
	combat_audio.guard(simulation,not overlay.visible)

func _result_payment_text(summary:Dictionary) -> String:
	var data:Dictionary=preload("res://scripts/ui/reward_payment.gd").describe(summary,run_store.pending,gold_progress,battle_save_error,gold_error)
	return "\n"+str(data.get("text",""))

func _saved_battle_text() -> String:
	return SaveNotice.summary(run_store.pending,simulation.map_catalog)+"\n이어하기는 출격 당시 계정 강화를 유지합니다." if battle_save_error==OK else "저장 정보 확인 불가 · 불러오기 오류를 확인하세요"

func _add_account_summary(data:Dictionary,caption:String,note:String) -> Control:
	var box:=VBoxContainer.new()
	box.name="AccountBonusSummary"
	box.set_meta("summary",data)
	box.set_meta("caption",caption+(" · %d/54단계" % int(data.total) if data.available else " · 확인 불가"))
	dialog_body.add_child(box)
	var toggle:=_button(str(box.get_meta("caption"))+" ▸",_toggle_account_summary.bind(simulation.navigation_ticket,_menu_revision))
	toggle.name="Toggle"
	toggle.add_theme_font_size_override("font_size",16)
	toggle.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	toggle.disabled=not data.available
	box.add_child(toggle)
	var brief:=_label(str(data.brief)+"\n"+note,15)
	brief.name="Brief"
	brief.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	brief.mouse_filter=Control.MOUSE_FILTER_IGNORE
	box.add_child(brief)
	var detail:=_label(str(data.detail),16)
	detail.name="Details"
	detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	detail.mouse_filter=Control.MOUSE_FILTER_IGNORE
	detail.visible=false
	box.add_child(detail)
	return box

func _toggle_account_summary(ticket:int,revision:int) -> void:
	if not _menu_matches(ticket,revision):return
	var box:Control=dialog_body.get_node_or_null("AccountBonusSummary")
	if not is_instance_valid(box):return
	var detail:Label=box.get_node("Details")
	detail.visible=not detail.visible
	box.get_node("Toggle").text=str(box.get_meta("caption"))+(" ▾" if detail.visible else " ▸")
	_fit_dialog()

func _refresh_save_context() -> void:
	if not is_instance_valid(_saved_context_label):return
	var valid:bool=battle_save_error==OK and SaveNotice.resumable(run_store.pending) and str(run_store.pending.run.run_id)==simulation.run_id
	_saved_context_label.visible=valid
	_saved_context_label.text="마지막 전투 저장\n"+_saved_battle_text() if valid else ""

func _add_save_context(before_control:Control=null) -> void:
	_saved_context_label=_label("",16)
	_saved_context_label.name="SavedBattleSummary"
	_saved_context_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	dialog_body.add_child(_saved_context_label)
	if is_instance_valid(before_control):dialog_body.move_child(_saved_context_label,dialog_body.get_children().find(before_control))
	_refresh_save_context()

func _persist_battle() -> bool:
	var active:bool=simulation.has_active_run()
	var success:bool=super._persist_battle()
	if active:save_notice.confirmed(run_store.pending,battle_save_error,simulation,not _restoring_battle)
	else:save_notice.until=-1
	_refresh_save_context()
	return success

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
	battle_chrome=preload("res://scripts/ui/battle_chrome.gd").new()
	battle_chrome.hud=self
	root_ui.add_child(battle_chrome)
	battle_chrome.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	movement = MoveInput.new()
	root_ui.add_child(movement)
	movement.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_header = _panel(root_ui)
	_header_row = HBoxContainer.new()
	_header_row.add_theme_constant_override("separation", 12)
	_header.add_child(_header_row)
	_brand = _label("✦", 22)
	_brand.add_theme_color_override("font_color",CombatSkin.GOLD)
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
	_phase_text=_label("출격 대기",22)
	_phase_text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	_phase_text.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_phase_text.add_theme_color_override("font_color",CombatSkin.LIGHT)
	_header_row.add_child(_phase_text)
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
	magic_button = CombatSlot.new()
	magic_button.ultimate=true
	magic_button.text = "[임시] 고유 마법\n출격 대기"
	magic_button.disabled = true
	magic_button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	magic_button.focus_mode = Control.FOCUS_NONE
	magic_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	magic_button.add_theme_font_size_override("font_size", 16)
	magic_button.pressed.connect(_cast_magic)
	root_ui.add_child(magic_button)
	mission_button=Button.new()
	mission_button.focus_mode=Control.FOCUS_NONE
	mission_button.pressed.connect(func():_open_mission(simulation.navigation_ticket,_menu_revision))
	root_ui.add_child(mission_button)
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
	boss_bar = ProgressBar.new()
	boss_bar.show_percentage = false
	boss_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ui.add_child(boss_bar)
	boss_label = _label("", 14)
	boss_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ui.add_child(boss_label)
	ailment_text = _label("", 14)
	ailment_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ailment_text.add_theme_color_override("font_color", Color("edb06e"))
	root_ui.add_child(ailment_text)
	_header.add_theme_stylebox_override("panel",CombatSkin.plate())
	dialog.add_theme_stylebox_override("panel",CombatSkin.plate())
	CombatSkin.style_bar(experience,Color("d9bd82"))
	CombatSkin.style_bar(health,Color("9a3545"))
	CombatSkin.style_bar(mana_bar,Color("744f87"))
	CombatSkin.style_bar(boss_bar,Color("b3484c"))
	root_ui.move_child(battle_chrome,root_ui.get_children().find(overlay))
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
		var button := CombatSlot.new()
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
		view.camera.reset(simulation.run_id)
		_mission_touch_id=-1
		_magic_touch_id = -1
		simulation.magic.invalidate_requests()
	layout_data = new_layout
	var compact: bool = layout_data["compact"]
	feedback_panel.fit_compact(true)
	feedback_panel.reaction_text.add_theme_font_size_override("font_size",11 if compact else 14)
	feedback_panel.danger_text.add_theme_font_size_override("font_size",10)
	feedback_panel.danger_text.custom_minimum_size.y = 12
	feedback_panel.get_node("ReactionColumn").add_theme_constant_override("separation",0)
	feedback_panel.frame_style.content_margin_top = 3
	feedback_panel.frame_style.content_margin_bottom = 3
	status_text.add_theme_font_size_override("font_size",11 if compact else 15)
	mana_text.add_theme_font_size_override("font_size",12 if compact else 15)
	health.custom_minimum_size.y = 8
	mana_bar.custom_minimum_size.y = 6
	_resources.add_theme_constant_override("separation",0 if compact else 3)
	magic_button.add_theme_font_size_override("font_size",12 if compact else 16)
	_identity_title.visible = false
	_settings_button.custom_minimum_size = Vector2(70 if compact else 116, 28 if layout_data.top.size.y < 40 else 40)
	_settings_button.text = "설정" if compact else "환경설정"
	_settings_button.icon=combat_skin.glyph("gear")
	_settings_button.add_theme_constant_override("icon_max_width",18)
	_settings_button.add_theme_font_size_override("font_size",13 if compact else 15)
	stats_text.custom_minimum_size.x = 72 if compact else 130
	stats_text.visible = true
	stats_text.add_theme_font_size_override("font_size",12 if compact else 16)
	stats_text.add_theme_color_override("font_color",CombatSkin.LIGHT)
	_phase_text.add_theme_font_size_override("font_size",14 if compact else 22)
	_phase_text.custom_minimum_size.x=130 if compact else 220
	_growth_column.custom_minimum_size.x=130 if compact else 200
	_brand.visible = not compact
	level_text.add_theme_font_size_override("font_size",12 if compact else 15)
	experience.custom_minimum_size.y = 5
	_growth_column.add_theme_constant_override("separation",0)
	_skills.add_theme_constant_override("separation",3)
	for button in slot_buttons:button.custom_minimum_size.y = 24 if compact else 38
	for row in _skills.get_children():
		var heading:Label=row.get_child(0)
		heading.custom_minimum_size.x = 35 if compact else 48
		heading.add_theme_font_size_override("font_size",11 if compact else 14)
	for label in attack_slots+passive_slots:label.add_theme_font_size_override("font_size",11 if compact else 12)
	_support.add_theme_font_size_override("font_size",10)
	_support.text="지원 2+2 · 빈칸"
	_header_row.add_theme_constant_override("separation", 6 if compact else 12)
	var style: StyleBoxFlat = _header.get_theme_stylebox("panel") as StyleBoxFlat
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	_place(_header, layout_data["top"])
	_place(view, layout_data["battle"])
	simulation.spawn_view_size = view.spawn_guard_size()
	if is_instance_valid(stage_text):
		stage_text.position = _header.position + Vector2(0, 0)
		stage_text.size.x = maxf(1.0, view.size.x - 24.0)
		stage_text.clip_text = true
	if is_instance_valid(boss_bar):
		boss_bar.position = view.position + Vector2(view.size.x*.33,18)
		boss_bar.size = Vector2(minf(360.0, view.size.x * 0.40), 6)
		boss_label.position = view.position + Vector2(view.size.x*.33,0)
		boss_label.size=Vector2(boss_bar.size.x,18)
		boss_label.clip_text=true
		boss_label.add_theme_font_size_override("font_size",11 if compact else 13)
		ailment_text.position = layout_data.resources.position-Vector2(0,19)
	_place(feedback_panel, layout_data["feedback"])
	_place(_resources, layout_data["resources"])
	_place(_skills, layout_data["skills"])
	_place(_support, layout_data["support"])
	_place(magic_button, layout_data["magic"])
	var local_to_move: Transform2D = movement.get_global_transform_with_canvas().affine_inverse() * root_ui.get_global_transform_with_canvas()
	movement.set_interaction_rect(local_to_move * layout_data["move"])
	_place(mission_button,Rect2(view.position+Vector2(8,6),Vector2(82 if compact else 215,28)))
	mission_button.add_theme_font_size_override("font_size",11 if compact else 14)
	CombatSkin.style_button(mission_button)
	CombatSkin.style_button(_settings_button)
	magic_button.compact=compact
	CombatSkin.style_button(magic_button,true,compact)
	_update_slots(attack_slots,"attack")
	_update_slots(passive_slots,"passive")
	_fit_dialog()
	_update_magic_hud()

func _clear_dialog() -> void:
	combat_audio.stop_all()
	_saved_context_label=null
	dungeon_button=null
	dungeon_launch_button=null
	talents_button = null
	talents_return_button = null
	talent_tabs.clear()
	talent_buy_buttons.clear()
	talent_buttons_by_id.clear()
	talent_content = null
	_talent_grid = null
	overview_button = null
	overview_return_button = null
	_menu_revision += 1
	confirm_button = null
	cancel_button = null
	leave_button = null
	lobby_button = null
	_choice_grid = null
	detail_return_button = null
	super._clear_dialog()

func _show_menu(kind: String) -> void:
	_mission_touch_id=-1
	_mission_open=false
	_talents_open = false
	_overview_open = false
	if kind in ["defeat", "abandoned", "cleared"] and _final_growth.is_empty():
		_final_growth = GrowthOverview.capture(simulation)
	_modal_kind = kind
	_detail_open = false
	super._show_menu(kind)
	overlay.color.a = 1.0 if kind == "ready" else 0.88
	var ticket: int = simulation.navigation_ticket
	var revision: int = _menu_revision
	# Keep existing settings/results, but replace every destructive start binding.
	for child in dialog_body.get_children():
		if child is Button and child.pressed.is_connected(begin_run):
			child.pressed.disconnect(begin_run)
			if kind == "paused":
				child.pressed.connect(_request_transition.bind("restart", ticket, revision))
			else:
				child.pressed.connect(_start_from_menu.bind(ticket, revision))
	if kind == "paused":
		dialog_body.add_child(_label(stage_text.text,14))
		if simulation.run_mode=="gold_slime":
			for child in dialog_body.get_children():
				if child is Button and child.pressed.is_connected(_request_transition.bind("restart",ticket,revision)):
					child.text="포기 후 던전 재입장 · 입장 1회 소모"
		if resume_button.pressed.is_connected(resume_game):
			resume_button.pressed.disconnect(resume_game)
		resume_button.pressed.connect(_resume_from_menu.bind(ticket, revision))
		leave_button = _button("전투 포기 · 결과 확인", _request_transition.bind("leave", ticket, revision))
		dialog_body.add_child(leave_button)
	elif kind in ["defeat", "abandoned", "cleared"]:
		var heading: Label = dialog_body.get_child(0) as Label
		heading.text = {"abandoned": "전투 포기", "defeat": "전투 종료 · 패배", "cleared": "스테이지 %d 클리어" % simulation.stage}[kind]
		if simulation.end_reason == "timeout":
			heading.text = "전투 종료 · 시간 초과"
		if kind != "cleared":
			var explanation: String = "직접 전투를 종료했습니다. HP 소진 패배와 구분됩니다." if kind == "abandoned" else "체력이 모두 소진되었습니다."
			if simulation.end_reason == "timeout":
				explanation = "6분 안에 보스를 처치하지 못했습니다. 클리어 보상은 지급되지 않습니다."
			dialog_body.add_child(_label(explanation, 17))
		if simulation.run_mode=="gold_slime":
			heading.text="골드 슬라임 던전 · "+{"cleared":"클리어","defeat":"패배","abandoned":"포기"}[kind]
			start_button.text="던전 입장 화면"
			start_button.disabled=gold_error!=OK or battle_save_error!=OK
			dialog_body.add_child(_label("캠페인 해금 없음 · 오늘 남은 입장 %d/2 · 실패/포기 시 미지급" % gold_progress.dungeon_remaining(),17))
		lobby_button = _button("출격 대기로", _return_to_lobby.bind(ticket, revision))
		lobby_button.disabled = battle_save_error != OK or ((kind == "cleared" or simulation.run_mode=="gold_slime") and gold_error != OK)
		dialog_body.add_child(lobby_button)
		# Keep the existing relevant recovery action visible above a long result.
		var primary_retry:Callable=_retry_battle_save if battle_save_error!=OK else _retry_gold_save
		for child in dialog_body.get_children():
			if child is Button and child.pressed.is_connected(primary_retry):
				dialog_body.move_child(child,1)
				break
	elif kind == "ready":
		var heading: Label = dialog_body.get_child(0) as Label
		heading.text = "VIYA | 최후의 도시 · 메인 로비"
		var account := _label("주력 비야 · 현재 계정 특성 강화 %d/54 · 공격력 %s" % [AccountTalents.IDS.reduce(func(sum, id): return sum + int(gold_progress.talent_levels[id]), 0), AccountTalents.effect_text("attack_power", gold_progress.attack_level)] if gold_progress.loaded and gold_error==OK else "현재 계정 특성 정보 확인 불가", 20)
		dialog_body.add_child(account)
		dialog_body.move_child(account, 1)
		talents_button = _button("계정 특성 · 공격 / 방어 / 회복", _open_talents.bind(ticket, revision))
		dialog_body.add_child(talents_button)
	if kind == "ready":
		_decorate_lobby()
		if _has_saved_battle():_add_account_summary(preload("res://scripts/ui/account_bonus_summary.gd").for_saved(run_store.pending,battle_save_error),"이어하기 · 출격 당시 계정 보너스","현재 계정의 변경 사항은 새 전투부터 적용됩니다.")
	if kind=="paused":
		_add_save_context(resume_button)
		dialog_body.move_child(resume_button,1)
		dialog_body.move_child(_saved_context_label,2)
		_add_account_summary(preload("res://scripts/ui/account_bonus_summary.gd").for_levels(simulation.account_talent_levels),"이번 전투 · 출격 당시 계정 보너스","전투 중 강화·현재 HP/MP와는 별개입니다.")
	_add_growth_access(kind)
	_scroll.scroll_vertical = 0
	_fit_dialog()

func _show_levelup() -> void:
	_overview_open = false
	_modal_kind = "choosing"
	_detail_open = false
	super._show_levelup()
	if battle_save_error != OK:
		return
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
	_add_growth_access("choosing")
	_fit_dialog()

func _fit_dialog() -> void:
	if layout_data.is_empty() or not is_instance_valid(dialog):
		return
	dialog.custom_minimum_size = Vector2.ZERO
	_place(_modal_host, layout_data["modal"])
	if is_instance_valid(_talent_grid):
		_talent_grid.columns = 2 if layout_data.modal.size.x >= 850.0 else 1
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
	super._update_slots(labels,row)
	var compact:bool=layout_data.get("compact",false)
	var entries:Array[Dictionary]=simulation.growth.row_entries(row)
	for index in range(labels.size()):
		var button=labels[index].get_parent()
		button.disabled=index>=entries.size()
		button.tooltip_text=labels[index].tooltip_text
		button.compact=compact
		button.icon=null
		CombatSkin.style_button(button)
		labels[index].offset_left=29 if compact else 42
		labels[index].offset_bottom=0 if compact else -6
		if index<entries.size():
			var entry:Dictionary=entries[index]
			var rank:int=simulation.growth.skill_level(entry.id)
			button.glyph_id=entry.id
			button.rank=rank
			button.glyph_texture=ui_art.texture(entry.id)
			button.icon=button.glyph_texture
			button.icon_alignment=HORIZONTAL_ALIGNMENT_LEFT
			button.add_theme_constant_override("icon_max_width",28)
			var name:String=str(entry.name).trim_prefix("[임시] ")
			labels[index].text=("[임시] %d%s" % [rank," ✦" if rank==5 else ""]) if compact else ("%s\n[임시] Lv.%d%s" % [name,rank," 진화" if rank==5 and row=="attack" else ""])
		else:
			button.glyph_id=""
			button.rank=0
			button.glyph_texture=null
			labels[index].offset_left=4
			labels[index].text="--"
		button.queue_redraw()

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
	var description: String = str(entry.levels[simulation.growth.skill_level(id)-1].change) if entry.has("levels") else str(entry.description)
	dialog_body.add_child(_label(description, 21))
	dialog_body.add_child(_label("읽기 전용 · 이름과 효과는 임시입니다.\n이 창에서는 스킬 획득·강화·마법 발동이 일어나지 않습니다.\n닫으면 이전 전투 또는 같은 레벨업 선택창으로 돌아갑니다.", 17))
	detail_return_button = _button("닫기 · 이전 화면으로", _close_skill_detail.bind(simulation.navigation_ticket, _menu_revision))
	dialog_body.add_child(detail_return_button)
	overlay.show()
	_fit_dialog()
	_update_hud()

func _close_skill_detail(expected_ticket: int, expected_revision: int) -> void:
	if not _detail_open or simulation.phase != RunState.Phase.PAUSED:
		return
	# A delayed close from a previous detail must not resume the current one.
	if not _menu_matches(expected_ticket, expected_revision) or not simulation.transition_action.is_empty():
		return
	_menu_revision += 1
	_detail_open = false
	super.resume_game()

func begin_run() -> void:
	# Internal new-run operation; production menu callbacks validate tickets first.
	if simulation.phase == RunState.Phase.READY and not run_store.pending.is_empty() and (_has_saved_battle() or not simulation.result_summary().ended):
		_resume_saved_run()
		return
	if not _can_start_rewarded_run():
		return
	var previous_stage: int = simulation.stage
	simulation.stage = gold_progress.next_stage
	if not simulation.start(0, simulation.growth.character_id, gold_progress.talent_levels, str(simulation.stage_catalog.for_departure(simulation.stage).map_id), new_run_ruleset, {}, "campaign", -1, -1, -1, new_run_encounter_version if new_run_ruleset=="weapons_v1" else 0, 1):
		simulation.stage = previous_stage
		push_error("Invalid character data; current run retained")
		return
	_after_run_started()

func _after_run_started() -> void:
	save_notice.reset(simulation.run_id)
	encounter_notice.seed(simulation)
	_overview_open = false
	_overview_origin = ""
	_final_growth.clear()
	_menu_revision += 1
	_detail_open = false
	_magic_touch_id = -1
	movement.clear_input()
	movement.set_enabled(true)
	overlay.hide()
	last_phase = simulation.phase
	last_ticket = -1
	_scroll.scroll_vertical = 0
	_update_hud()
	view.queue_redraw()
	_ensure_battle_saved()

func _menu_matches(ticket: int, revision: int) -> bool:
	return overlay.visible and ticket == simulation.navigation_ticket and revision == _menu_revision

func _start_from_menu(ticket: int, revision: int) -> void:
	if not _menu_matches(ticket, revision):
		return
	if simulation.phase not in [RunState.Phase.READY, RunState.Phase.DEFEAT, RunState.Phase.ABANDONED, RunState.Phase.CLEARED]:
		return
	if _has_saved_battle() or (not run_store.pending.is_empty() and not simulation.result_summary().ended):
		begin_run()
	elif simulation.run_mode=="gold_slime" and simulation.phase in [RunState.Phase.DEFEAT,RunState.Phase.ABANDONED,RunState.Phase.CLEARED]:
		if gold_error==OK and simulation.return_to_ready(simulation.navigation_ticket):_open_gold_dungeon()
	else:
		_open_stages()

func _resume_from_menu(ticket: int, revision: int) -> void:
	if _menu_matches(ticket, revision) and simulation.transition_action.is_empty():
		resume_game()

func _request_transition(action: String, ticket: int, revision: int) -> void:
	if not _menu_matches(ticket, revision) or _detail_open or battle_save_error != OK:
		return
	if not simulation.request_transition(action, ticket):
		return
	_detail_open = false
	_magic_touch_id = -1
	movement.set_enabled(false)
	last_phase = simulation.phase
	_show_confirmation()

func _show_confirmation() -> void:
	_clear_dialog()
	_modal_kind = "confirm"
	var ticket: int = simulation.navigation_ticket
	var revision: int = _menu_revision
	var restarting: bool = simulation.transition_action == "restart"
	dialog_body.add_child(_label("새 전투를 시작할까요?" if restarting else "이번 전투를 포기할까요?", 24))
	dialog_body.add_child(_label("확인하기 전에는 현재 레벨·선택지·체력·마력이 유지됩니다.\n확인하면 이번 전투를 이어서 진행할 수 없습니다.", 19))
	cancel_button = _button("취소 · 기존 전투로", _cancel_transition.bind(ticket, revision))
	dialog_body.add_child(cancel_button)
	confirm_button = _button("확인 · 새 전투 시작" if restarting else "확인 · 전투 포기", _confirm_transition.bind(ticket, revision))
	dialog_body.add_child(confirm_button)
	# Opening via a held key must not make the destructive action the default.
	confirm_button.focus_mode = Control.FOCUS_NONE
	_scroll.scroll_vertical = 0
	overlay.show()
	_fit_dialog()
	_update_hud()
	cancel_button.grab_focus()

func _cancel_transition(ticket: int, revision: int) -> void:
	if not _menu_matches(ticket, revision) or not simulation.cancel_transition(ticket):
		return
	_menu_revision += 1
	movement.clear_input()
	_magic_touch_id = -1
	last_phase = -1
	if simulation.phase == RunState.Phase.CHOOSING:
		_sync_phase_ui()
	else:
		overlay.hide()
		movement.set_enabled(true)
	_update_hud()

func _confirm_transition(ticket: int, revision: int) -> void:
	if not _menu_matches(ticket,revision):return
	var reenter: bool=simulation.run_mode=="gold_slime" and simulation.transition_action=="restart"
	if reenter:simulation.transition_action="leave" # No restart can bypass charged admission.
	if not _menu_matches(ticket, revision) or not simulation.confirm_transition(ticket, gold_progress.talent_levels):
		return
	_menu_revision += 1
	_magic_touch_id = -1
	movement.set_enabled(false)
	if simulation.phase == RunState.Phase.RUNNING:
		_after_run_started() # Confirmation already created the new run once.
	else:
		last_phase = simulation.phase
		_show_menu("abandoned")
		_update_hud()
		if reenter and gold_error==OK and battle_save_error==OK and simulation.return_to_ready(simulation.navigation_ticket):_open_gold_dungeon()

func _return_to_lobby(ticket: int, revision: int) -> void:
	if battle_save_error != OK:
		return
	if (simulation.phase == RunState.Phase.CLEARED or simulation.run_mode=="gold_slime") and gold_error != OK:
		return
	if not _menu_matches(ticket, revision) or not simulation.return_to_ready(ticket):
		return
	_magic_touch_id = -1
	movement.set_enabled(false)
	last_phase = simulation.phase
	_show_menu("ready")
	_update_hud()

func resume_game() -> void:
	if _mission_open:
		return # The guarded mission return owns this modal.
	if _overview_open:
		return # Overview owns its guarded return path.
	if not simulation.transition_action.is_empty():
		return # Do not bypass a confirmation via an old Continue callback.
	_menu_revision += 1
	super.resume_game()

func _sync_phase_ui() -> void:
	if simulation.phase == RunState.Phase.ABANDONED and last_phase != simulation.phase:
		last_phase = simulation.phase
		movement.set_enabled(false)
		_magic_touch_id = -1
		_show_menu("abandoned")
		return
	super._sync_phase_ui()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and is_instance_valid(movement) and event.index == movement.touch_id:
		return # A held movement finger cannot turn into a magic finger over the button.
	if event is InputEventScreenTouch:
		if event.index==_mission_touch_id:
			if not event.pressed or event.canceled:_mission_touch_id=-1
			get_viewport().set_input_as_handled()
			return
		if event.pressed and not event.canceled and mission_button.visible and not overlay.visible and mission_button.get_global_rect().has_point(event.position):
			_open_mission(simulation.navigation_ticket,_menu_revision)
			_mission_touch_id=event.index if _mission_open else -1
			get_viewport().set_input_as_handled()
			return
	elif event is InputEventScreenDrag and event.index==_mission_touch_id:
		get_viewport().set_input_as_handled()
		return
	super._input(event)

func _unhandled_key_input(event: InputEvent) -> void:
	if _mission_open and event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
		_close_mission(simulation.navigation_ticket,_menu_revision)
		get_viewport().set_input_as_handled()
		return
	if OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_F8:
		view.high_angle = not view.high_angle
		view.queue_redraw()
		get_viewport().set_input_as_handled()
		return
	if _modal_kind in ["stages", "lobby_settings", "gold_dungeon"] and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_campaign_back(simulation.navigation_ticket, _menu_revision)
		get_viewport().set_input_as_handled()
		return
	if _talents_open and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_close_talents(simulation.navigation_ticket, _menu_revision)
		get_viewport().set_input_as_handled()
		return
	if _modal_kind == "discard_save" and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_cancel_discard_save(simulation.navigation_ticket, _menu_revision)
		get_viewport().set_input_as_handled()
		return
	if _overview_open and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_close_growth_overview(simulation.navigation_ticket, _menu_revision)
		get_viewport().set_input_as_handled()
		return
	if not simulation.transition_action.is_empty() and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_cancel_transition(simulation.navigation_ticket, _menu_revision)
		get_viewport().set_input_as_handled()
		return
	if _detail_open and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_close_skill_detail(simulation.navigation_ticket, _menu_revision)
		get_viewport().set_input_as_handled()
		return
	super._unhandled_key_input(event)

func pause_game() -> void:
	if _mission_open:
		_mission_open=false
		_magic_touch_id=-1
		movement.set_enabled(false)
		_show_menu("paused")
		_update_hud()
		return
	if _talents_open:
		_show_menu("ready") # Interruption invalidates every outstanding purchase callback.
		return
	if _modal_kind == "discard_save":
		_show_menu("ready")
		return
	if _overview_open:
		# Focus loss cancels old overview callbacks. Never auto-resume the run.
		_overview_open = false
		_magic_touch_id = -1
		movement.set_enabled(false)
		var destination: String = "paused" if simulation.phase == RunState.Phase.PAUSED else _overview_origin
		_show_menu(destination)
		_update_hud()
		return
	if simulation.interrupt_transition():
		# Inherited focus notification calls this; never resume on focus regain.
		_magic_touch_id = -1
		movement.set_enabled(false)
		last_phase = simulation.phase
		_show_menu("paused")
		_update_hud()
		return
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

func _open_talents(ticket: int, revision: int) -> void:
	if not _menu_matches(ticket, revision) or simulation.phase != RunState.Phase.READY or _modal_kind != "ready":
		return
	_talent_category = "attack"
	_talent_notice = ""
	_show_talents()

func _show_talents() -> void:
	_clear_dialog()
	_talents_open = true
	_modal_kind = "talents"
	var ticket: int = simulation.navigation_ticket
	var revision: int = _menu_revision
	dialog_body.add_child(_label("계정 공통 특성", 24))
	dialog_body.add_child(_label("보유 골드 %s · 모든 캐릭터의 새 전투에 적용\n이어하기는 출격 당시 특성을 유지합니다." % AccountTalents.gold_text(gold_progress.total), 18))
	dialog_body.add_child(_label("하위 특성 Lv.k는 바로 위 특성 Lv.k 이상이 필요합니다.\n[임시] 표시는 효과 수치를 조정 중인 특성입니다.", 16))
	talents_return_button = _button("메인 로비로", _close_talents.bind(ticket, revision))
	dialog_body.add_child(talents_return_button)
	var tabs := HBoxContainer.new()
	dialog_body.add_child(tabs)
	for category in ["attack", "defense", "recovery"]:
		var tab := _button({"attack": "공격", "defense": "방어", "recovery": "회복"}[category], _select_talent_category.bind(category, ticket, revision))
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.toggle_mode = true
		tab.button_pressed = category == _talent_category
		tabs.add_child(tab)
		talent_tabs.append(tab)
	var panel := _panel(dialog_body)
	panel.name = "TalentArea"
	panel.custom_minimum_size.y = 140
	talent_content = VBoxContainer.new()
	panel.add_child(talent_content)
	_talent_grid = GridContainer.new()
	_talent_grid.add_theme_constant_override("h_separation", 14)
	talent_content.add_child(_talent_grid)
	for chain in AccountTalents.CHAINS[_talent_category]:
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_talent_grid.add_child(column)
		for id in chain:
			_add_talent_node(column, id, ticket, revision)
	if gold_error != OK:
		dialog_body.add_child(_label("계정 저장을 확인할 수 없습니다. 로비에서 다시 불러와 주세요.", 17))
	if not _talent_notice.is_empty():
		dialog_body.add_child(_label(_talent_notice, 17))
	dialog_body.add_child(_button("메인 로비로", _close_talents.bind(ticket, revision)))
	_scroll.scroll_vertical = 0
	overlay.show()
	_fit_dialog()

func _add_talent_node(column: VBoxContainer, id: String, ticket: int, revision: int) -> void:
	var definition: Dictionary = AccountTalents.DEFINITIONS[id]
	var parent: String = definition.get("parent", "")
	if not parent.is_empty():
		column.add_child(_label("↓ %s와 같은 레벨 필요" % AccountTalents.DEFINITIONS[parent].name, 14))
	var panel := _panel(column)
	var body := VBoxContainer.new()
	panel.add_child(body)
	var title := _label("%s\n%s / %s / %s" % [definition.name, AccountTalents.effect_text(id, 1), AccountTalents.effect_text(id, 2), AccountTalents.effect_text(id, 3)], 17)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(title)
	if AccountTalents.DESCRIPTIONS.has(id):
		var detail := _label(AccountTalents.DESCRIPTIONS[id], 14)
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(detail)
	talent_buttons_by_id[id] = []
	var current: int = gold_progress.talent_levels[id]
	for level in range(3):
		var state_text := "강화하기"
		if level < current:
			state_text = "강화 완료"
		elif level > current:
			state_text = "이전 단계 필요"
		elif not AccountTalents.can_purchase(gold_progress.talent_levels, id, level):
			state_text = "%s Lv.%d 필요" % [AccountTalents.DEFINITIONS[parent].name, level + 1]
		elif gold_progress.total < int(AccountTalents.ATTACK_COSTS[level]):
			state_text = "골드 부족"
		var caption := "Lv.%d · %s · %s 골드\n%s" % [level + 1, AccountTalents.effect_text(id, level + 1), AccountTalents.gold_text(AccountTalents.ATTACK_COSTS[level]), state_text]
		var buy := _button(caption, _buy_talent.bind(id, level, ticket, revision))
		buy.add_theme_font_size_override("font_size", 16)
		buy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		buy.disabled = gold_error != OK or not gold_progress.loaded or not AccountTalents.can_purchase(gold_progress.talent_levels, id, level) or gold_progress.total < int(AccountTalents.ATTACK_COSTS[level])
		body.add_child(buy)
		talent_buy_buttons.append(buy)
		talent_buttons_by_id[id].append(buy)

func _select_talent_category(category: String, ticket: int, revision: int) -> void:
	if not _talents_open or not _menu_matches(ticket, revision) or category not in ["attack", "defense", "recovery"]:
		return
	_talent_category = category
	_talent_notice = ""
	_show_talents()

func _buy_talent(id: String, level: int, ticket: int, revision: int) -> void:
	if not _talents_open or not _menu_matches(ticket, revision) or (id not in AccountTalents.IDS or AccountTalents.DEFINITIONS[id].category != _talent_category) or simulation.phase != RunState.Phase.READY or gold_error != OK:
		return
	var error: Error = gold_progress.purchase_talent(id, level)
	if error == OK:
		_talent_notice = "%s %d단계 강화 완료 · 새 전투부터 적용됩니다." % [AccountTalents.DEFINITIONS[id].name, gold_progress.talent_levels[id]]
	else:
		_talent_notice = "강화 저장 실패 · 골드와 강화 단계를 확인해 주세요. (%s)" % error_string(error)
		if error in [ERR_BUSY, ERR_FILE_CORRUPT, ERR_PARSE_ERROR]:
			gold_error = gold_progress.load_progress()
	_show_talents()

func _close_talents(ticket: int, revision: int) -> void:
	if _talents_open and _menu_matches(ticket, revision):
		_show_menu("ready")

func _add_growth_access(origin: String) -> void:
	if origin not in ["paused", "choosing", "defeat", "abandoned", "ready", "cleared"]:
		return
	if origin == "ready" and _final_growth.is_empty():
		return
	var is_final: bool = origin in ["defeat", "abandoned", "ready", "cleared"]
	var data: Dictionary = _final_growth if is_final else GrowthOverview.capture(simulation)
	if data.is_empty():
		return
	dialog_body.add_child(_label(GrowthOverview.compact(data), 16))
	var caption: String = "최종 성장 · 보상 내역" if is_final else "보유 스킬 · 성장 현황"
	overview_button = _button(caption, _open_growth_overview.bind(origin, simulation.navigation_ticket, _menu_revision))
	dialog_body.add_child(overview_button)

func _open_growth_overview(origin: String, ticket: int, revision: int) -> void:
	if _overview_open or _detail_open or not _menu_matches(ticket, revision):
		return
	if origin != _modal_kind or not simulation.transition_action.is_empty():
		return
	if origin not in ["paused", "choosing", "defeat", "abandoned", "ready", "cleared"]:
		return
	var is_final: bool = origin in ["defeat", "abandoned", "ready", "cleared"]
	if is_final and _final_growth.is_empty():
		return
	if origin == "choosing":
		if simulation.phase != RunState.Phase.CHOOSING:
			return
		simulation.set_paused(true)
	elif origin == "paused" and simulation.phase != RunState.Phase.PAUSED:
		return
	# No growth mutations or new authoritative simulation: copy already applied values.
	var data: Dictionary = _final_growth.duplicate(true) if is_final else GrowthOverview.capture(simulation)
	_overview_origin = origin
	_magic_touch_id = -1
	movement.set_enabled(false)
	last_phase = simulation.phase
	_clear_dialog()
	_overview_open = true
	_modal_kind = "overview"
	dialog_body.add_child(_label("최종 성장 현황" if is_final else "현재 성장 현황", 24))
	dialog_body.add_child(_label("읽기 전용 · 모든 스킬명과 수치는 임시입니다. 성장 기록의 영구 보관·장착 변경·강화 기능은 없습니다.", 16))
	overview_return_button = _button("닫기 · 이전 화면으로", _close_growth_overview.bind(simulation.navigation_ticket, _menu_revision))
	dialog_body.add_child(overview_return_button)
	if is_final and simulation.result_summary().ended:
		var payment_label:=_label(_result_payment_text(simulation.result_summary()).trim_prefix("\n"),17)
		payment_label.name="RewardPaymentSummary"
		payment_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
		dialog_body.add_child(payment_label)
	for section in GrowthOverview.sections(data):
		dialog_body.add_child(_label(str(section["title"]), 21))
		dialog_body.add_child(_label(str(section["body"]), 17))
	# A long list also has a bottom close button; both use the same stale-request guard.
	dialog_body.add_child(_button("닫기 · 이전 화면으로", _close_growth_overview.bind(simulation.navigation_ticket, _menu_revision)))
	_scroll.scroll_vertical = 0
	overlay.show()
	_fit_dialog()
	_update_hud()
	overview_return_button.grab_focus()

func _close_growth_overview(ticket: int, revision: int) -> void:
	if not _overview_open or not _menu_matches(ticket, revision):
		return
	if not simulation.transition_action.is_empty():
		return
	var origin: String = _overview_origin
	_overview_open = false
	_menu_revision += 1
	movement.clear_input()
	_magic_touch_id = -1
	if origin == "choosing":
		# Existing resume restores the same candidates/ticket, not a fresh draw.
		resume_game()
	else:
		# Settings stays paused; results/lobby remain terminal/ready.
		_show_menu(origin)
	_update_hud()

func _resume_saved_run() -> void:
	if simulation.phase != RunState.Phase.READY:
		return
	_final_growth.clear()
	_overview_open = false
	_detail_open = false
	save_notice.seed(run_store.pending,battle_save_error)
	_restoring_battle=true
	super._resume_saved_run()
	_restoring_battle=false
	encounter_notice.seed(simulation)
	_apply_layout()

func _abandon_saved_run() -> void:
	if simulation.phase != RunState.Phase.READY or not _has_saved_battle():
		return
	_resume_saved_run()
	if simulation.phase == RunState.Phase.PAUSED:
		_request_transition("leave", simulation.navigation_ticket, _menu_revision)

func _ask_discard_save() -> void:
	if simulation.phase != RunState.Phase.READY:
		return
	_clear_dialog()
	_modal_kind = "discard_save"
	var ticket: int = simulation.navigation_ticket
	var revision: int = _menu_revision
	dialog_body.add_child(_label("저장된 전투를 삭제할까요?", 24))
	dialog_body.add_child(_label("이번 전투의 진행과 획득 금화가 사라집니다. 보유 금화는 유지됩니다.", 18))
	cancel_button = _button("취소", _cancel_discard_save.bind(ticket, revision))
	confirm_button = _button("확인 · 저장 삭제", _confirm_discard_save.bind(ticket, revision))
	dialog_body.add_child(cancel_button)
	dialog_body.add_child(confirm_button)
	confirm_button.focus_mode = Control.FOCUS_NONE
	_fit_dialog()
	cancel_button.grab_focus()

func _cancel_discard_save(ticket: int, revision: int) -> void:
	if _modal_kind == "discard_save" and _menu_matches(ticket, revision):
		_show_menu("ready")

func _confirm_discard_save(ticket: int, revision: int) -> void:
	if _modal_kind == "discard_save" and _menu_matches(ticket, revision):
		_discard_saved_run()

# Campaign menus render data and dispatch existing guarded state transitions.
func _decorate_lobby() -> void:
	for child in dialog_body.get_children():
		if child is Label and (child.text.begins_with("처치 →") or child.text.begins_with("6분 생존")):
			dialog_body.remove_child(child)
			child.queue_free()
	var city = preload("res://scripts/ui/city_preview.gd").new()
	dialog_body.add_child(city)
	for child in dialog_body.get_children():
		if child is Label and child.text.begins_with("보유 금화"):
			dialog_body.move_child(child,mini(2,dialog_body.get_child_count()-1))
	dialog_body.move_child(city, mini(3, dialog_body.get_child_count() - 1))
	var caption := _label("최후의 도시 · 비야 / 임시 배경·캐릭터 대역", 14)
	dialog_body.add_child(caption)
	var menus := GridContainer.new()
	menus.columns = 3 if layout_data.get("card_columns", 3) == 3 else 2
	menus.add_theme_constant_override("h_separation", 8)
	menus.add_theme_constant_override("v_separation", 8)
	dialog_body.add_child(menus)
	for button in [start_button, talents_button]:
		button.reparent(menus)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dungeon_button=_button("골드 슬라임 던전 · %d/2" % gold_progress.dungeon_remaining(),_open_gold_dungeon_guarded.bind(simulation.navigation_ticket,_menu_revision))
	dungeon_button.disabled=gold_error!=OK or battle_save_error!=OK or _has_saved_battle() or not gold_progress.dungeon.initial.is_empty()
	dungeon_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	menus.add_child(dungeon_button)
	for title in ["캐릭터", "뽑기", "도시", "원정"]:
		var button := _button(title + " · 준비 중", func(): pass)
		button.disabled = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		menus.add_child(button)
	var ticket: int = simulation.navigation_ticket
	var revision: int = _menu_revision
	lobby_settings_button = _button("설정", _open_lobby_settings.bind(ticket, revision))
	dialog_body.add_child(lobby_settings_button)

func _open_gold_dungeon_guarded(ticket: int, revision: int) -> void:
	if _modal_kind=="ready" and _menu_matches(ticket,revision):_open_gold_dungeon()

func _open_gold_dungeon() -> void:
	if simulation.phase!=RunState.Phase.READY or _has_saved_battle() or gold_error!=OK or battle_save_error!=OK or not gold_progress.dungeon.initial.is_empty():return
	_clear_dialog()
	_modal_kind="gold_dungeon"
	var ticket: int=simulation.navigation_ticket
	var revision: int=_menu_revision
	dialog_body.add_child(_label("골드 슬라임 던전",28))
	dialog_body.add_child(_label("3분 생존 · 보스 없음 · 1분/2분 자동 저장\n느린 슬라임의 대량 군집을 피해 금화를 모으세요.",19))
	dialog_body.add_child(_label("하루 2회 · 한국시간 자정 초기화 · 남은 입장 %d/2\n처치 시 %d~%d금화 확정 · 클리어 시 획득 금화 전액 지급\n실패/포기는 보상 없음 · 이어하기는 추가 소모 없음\n입장 시 횟수 차감 · 캠페인 진행은 유지됩니다." % [gold_progress.dungeon_remaining(),simulation.dungeon.drop_range(1).x / 2,simulation.dungeon.drop_range(1).y / 2],18))
	if not _dungeon_notice.is_empty():
		var notice:=_label(_dungeon_notice,17)
		notice.name="DungeonAdmissionNotice"
		dialog_body.add_child(notice)
	dungeon_launch_button=_button("입장 · 오늘 %d회 남음" % gold_progress.dungeon_remaining(),_launch_gold_dungeon.bind(ticket,revision))
	dungeon_launch_button.disabled=gold_progress.dungeon_remaining()<=0
	dialog_body.add_child(dungeon_launch_button)
	dialog_body.add_child(_button("메인 로비로",_campaign_back.bind(ticket,revision)))
	# Keep admission/back actions above expandable bonus details.
	dialog_body.move_child(dungeon_launch_button,2)
	dialog_body.move_child(dialog_body.get_child(dialog_body.get_child_count()-1),3)
	var bonuses:=_add_account_summary(preload("res://scripts/ui/account_bonus_summary.gd").for_account(gold_progress,gold_error),"새 출격 · 계정 보너스","입장 시 현재 계정 강화를 적용합니다.")
	dialog_body.move_child(bonuses,4)
	if not _dungeon_notice.is_empty():dialog_body.move_child(dialog_body.get_node("DungeonAdmissionNotice"),2)
	overlay.show()
	_fit_dialog()

func _launch_gold_dungeon(ticket: int, revision: int) -> void:
	if _modal_kind!="gold_dungeon" or not _menu_matches(ticket,revision) or simulation.phase!=RunState.Phase.READY or _has_saved_battle() or not _can_start_rewarded_run() or not gold_progress.dungeon.initial.is_empty() or gold_progress.dungeon_remaining()<=0:return
	var previous: Dictionary=RunStore.Snapshot.capture(simulation)
	var previous_result: Dictionary=simulation.result_summary()
	simulation.stage=gold_progress.next_stage
	var today: int=simulation.dungeon.day_index(int(Time.get_unix_time_from_system()))
	if not simulation.start(0,"viya",gold_progress.talent_levels,"gold_slime","weapons_v1",{},"gold_slime",today,-1,-1,0,1):
		simulation.stage=int(previous.run.stage)
		_dungeon_notice="던전 데이터를 확인할 수 없습니다. 입장 횟수는 사용하지 않았습니다."
		_open_gold_dungeon()
		return
	var initial: Dictionary=RunStore.Snapshot.capture(simulation)
	var admission: Error=gold_progress.admit_dungeon(initial)
	if admission!=OK:
		# No previous active battle is replaceable here. Restore a prior result,
		# including its resources, if admission persistence fails.
		if previous_result.ended:
			previous.run.phase={"cleared":6,"defeat":3,"timeout":3,"abandoned":5}[previous_result.outcome]
			RunStore.Snapshot.restore(previous,simulation)
			simulation.return_to_ready(simulation.navigation_ticket)
		else:
			simulation.phase=RunState.Phase.READY
			simulation._finished_result.clear()
		_dungeon_notice="입장 저장 실패 · 횟수 미사용 (%s)" % error_string(admission)
		if admission==ERR_BUSY:gold_error=gold_progress.load_progress()
		_open_gold_dungeon()
		return
	_dungeon_notice=""
	_after_run_started()

func _open_stages() -> void:
	if simulation.phase in [RunState.Phase.CLEARED,RunState.Phase.DEFEAT,RunState.Phase.ABANDONED]:
		if battle_save_error != OK or (simulation.phase == RunState.Phase.CLEARED and gold_error != OK) or not simulation.return_to_ready(simulation.navigation_ticket):
			return
	_clear_dialog()
	_modal_kind = "stages"
	_selected_stage = gold_progress.next_stage
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_one.json"))
	dialog_body.add_child(_label(data.chapter, 28))
	dialog_body.add_child(_label("출격 S%d · 6분 생존 + 최종 보스 처치 · 2분/4분 자동 저장" % _selected_stage, 17))
	stage_buttons.clear()
	var entries: Array = data.stages.duplicate(true)
	if gold_progress.next_stage > 2:
		entries.append({"number": gold_progress.next_stage, "name": "[시험] 일반 지역 · S%d" % gold_progress.next_stage, "description": "도시 외곽 시험 맵을 사용하는 현재 진행 전투입니다."})
	var ticket: int = simulation.navigation_ticket
	var revision: int = _menu_revision
	for entry in entries:
		var number: int = int(entry.number)
		var state := "선택됨" if number == _selected_stage else ("클리어" if number < _selected_stage else "잠김")
		var rules: Dictionary = simulation.stage_catalog.for_stage(number)
		var button := _button("%s · %s\n%s\n목표: 생존 + 보스 · 기본 %d골드 + 획득 금화" % [entry.name, state, entry.description, int(rules.get("clear_gold", 100))], _select_stage.bind(number, ticket, revision))
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.disabled = number != gold_progress.next_stage
		dialog_body.add_child(button)
		stage_buttons.append(button)
	dialog_body.add_child(_label("지역 후보 · 세부 구성 미확정", 15))
	for region in data.future_regions:
		var button := _button(region + " · 준비 중", func(): pass)
		button.disabled = true
		dialog_body.add_child(button)
	stage_launch_button = _button("선택한 전장으로 출격", _launch_stage.bind(ticket, revision))
	stage_launch_button.disabled = gold_error != OK or battle_save_error != OK
	dialog_body.add_child(stage_launch_button)
	stage_back_button = _button("뒤로 · 메인 로비", _campaign_back.bind(ticket, revision))
	dialog_body.add_child(stage_back_button)
	dialog_body.move_child(stage_launch_button,2)
	dialog_body.move_child(stage_back_button,3)
	var bonuses:=_add_account_summary(preload("res://scripts/ui/account_bonus_summary.gd").for_account(gold_progress,gold_error),"새 출격 · 계정 보너스","출격 시 현재 계정 강화를 적용합니다.")
	dialog_body.move_child(bonuses,4)
	overlay.show()
	_fit_dialog()

func _select_stage(number: int, ticket: int, revision: int) -> void:
	if _modal_kind != "stages" or not _menu_matches(ticket, revision) or number != gold_progress.next_stage:
		return
	_selected_stage = number

func _launch_stage(ticket: int, revision: int) -> void:
	if _modal_kind != "stages" or not _menu_matches(ticket, revision) or _selected_stage != gold_progress.next_stage or _has_saved_battle():
		return
	begin_run()

func _campaign_back(ticket: int, revision: int) -> void:
	if _menu_matches(ticket, revision) and _modal_kind in ["stages", "lobby_settings", "gold_dungeon"]:
		_show_menu("ready")

func _open_lobby_settings(ticket: int, revision: int) -> void:
	if not _menu_matches(ticket, revision) or simulation.phase != RunState.Phase.READY:
		return
	_clear_dialog()
	_modal_kind = "lobby_settings"
	dialog_body.add_child(_label("로비 설정", 26))
	dialog_body.add_child(_label("전체 음량 · 임시 전투 효과음", 17))
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = volume
	slider.custom_minimum_size.y = 40
	slider.value_changed.connect(_set_volume)
	dialog_body.add_child(slider)
	_add_display_settings()
	stage_back_button = _button("뒤로 · 메인 로비", _campaign_back.bind(simulation.navigation_ticket, _menu_revision))
	dialog_body.add_child(stage_back_button)
	overlay.show()
	_fit_dialog()

func _update_feedback_hud() -> void:
	super._update_feedback_hud()
	if not is_instance_valid(feedback_panel):return
	var notice:String=""
	if simulation.phase==RunState.Phase.RUNNING and feedback_panel.state_key=="hurt":notice=view.IncomingFeedback.notice(simulation,view.high_angle,view.project_direction)
	feedback_panel.reaction_text.text=notice if not notice.is_empty() else str(simulation.feedback.PRESENTATION[feedback_panel.state_key].label)

func _update_hud() -> void:
	super._update_hud()
	combat_audio.guard(simulation,not overlay.visible)
	encounter_notice.observe(simulation,save_notice.until if save_notice.visible(simulation,battle_save_error) else -1)
	if not is_instance_valid(boss_bar):
		return
	var bosses: Array = simulation.enemies.filter(func(enemy): return enemy.kind == "boss")
	boss_bar.visible = not bosses.is_empty() and simulation.has_active_run() and not overlay.visible
	boss_label.visible = boss_bar.visible
	if not bosses.is_empty():
		boss_bar.max_value = bosses[0].max_hp
		boss_bar.value = bosses[0].hp
		boss_label.text = "최종 보스 · HP %d / %d" % [bosses[0].hp, bosses[0].max_hp]
		if bosses[0].has("species"):
			boss_label.text = "%s · HP %d / %d" % [simulation.profiles.species(bosses[0].species).name,bosses[0].hp,bosses[0].max_hp]
	if not simulation.stage_rules.is_empty():
		var left: int = maxi(0,int(ceil(simulation.stage_duration-simulation.elapsed)))
		var next := "보스 처치" if simulation._boss_spawned and not simulation._boss_defeated else ("생존 유지" if simulation._boss_defeated else "보스 %d초" % maxi(0,int(ceil(float(simulation.stage_rules.boss_at)-simulation.elapsed))))
		if simulation._elites_spawned < simulation.elite_schedule().size() and not simulation._boss_spawned:
			next = "정예 %d초" % maxi(0,int(ceil(float(simulation.elite_schedule()[simulation._elites_spawned])-simulation.elapsed)))
		stage_text.add_theme_font_size_override("font_size",14)
		stage_text.text = "S%d %s · %02d:%02d · 생존+보스 · %s · 저장 %d/2" % [simulation.stage,simulation.map_space.definition.get("short_name","전장"),left/60,left%60,next,save_notice.count_for(simulation.run_id)]
		stage_text.tooltip_text = simulation.map_space.definition.name
	if simulation.run_mode=="gold_slime":
		var left:=maxi(0,int(ceil(simulation.stage_duration-simulation.elapsed)))
		stage_text.text="골드 슬라임 던전 · %02d:%02d · 생존 · 저장 %d/2" % [left/60,left%60,save_notice.count_for(simulation.run_id)]
		stats_text.text="던전 %02d:%02d | 처치 %d | 금화 %d" % [int(simulation.elapsed)/60,int(simulation.elapsed)%60,simulation.kills,simulation.gold_collected]
		stats_text.tooltip_text="3분 생존 시 획득 금화 정산 · 캠페인 해금 없음"
	if _modal_kind=="gold_dungeon" and is_instance_valid(dungeon_launch_button):
		dungeon_launch_button.text="입장 · 오늘 %d회 남음" % gold_progress.dungeon_remaining()
		dungeon_launch_button.disabled=gold_progress.dungeon_remaining()<=0
	# Fold the verbose mission into existing header hover/read-only pause context.
	stage_text.visible = false
	_header.tooltip_text = stage_text.text
	level_text.tooltip_text = stage_text.text
	if not overlay.visible:
		var remaining:int=maxi(0,int(ceil(simulation.stage_duration-simulation.elapsed)))
		level_text.text += " · %02d:%02d" % [remaining/60,remaining%60]
	ailment_text.visible = not overlay.visible
	ailment_text.text = "둔화 · %.1f초" % simulation._slow_left if simulation._slow_left > 0.0 else ""
	status_text.text = "HP %d / %d" % [simulation.hp, simulation.max_hp]
	level_text.text="Lv.%d Viya · EXP %.0f/%.0f" % [simulation.growth.level,simulation.growth.xp,simulation.growth.threshold()]
	var seconds:int=maxi(0,int(ceil(simulation.stage_duration-simulation.elapsed)))
	var phase:int=simulation.stage_rules.get("waves",[]).find(simulation.wave_profile())+1 if not simulation.stage_rules.is_empty() else 0
	_phase_text.text="%s · %02d:%02d" % ["골드 던전" if simulation.run_mode=="gold_slime" else ("보스전" if simulation._boss_spawned and not simulation._boss_defeated else "공세 %02d" % phase),seconds/60,seconds%60]
	stats_text.text="금화 %s" % str(simulation.gold_collected)
	stats_text.tooltip_text="이번 전투 %d · 계정 보유 %d" % [simulation.gold_collected,gold_progress.total]
	mission_button.visible=simulation.has_active_run() and not overlay.visible
	mission_button.text="임무 ▸" if layout_data.get("compact",false) else ("최후의 성벽 방어 ▸" if simulation.map_id=="prologue_wall" else "전투 임무 ▸")
	mission_button.tooltip_text=stage_text.text
	if encounter_notice.visible(simulation):
		mission_button.text=encounter_notice.caption(simulation,layout_data.get("compact",false))
		mission_button.tooltip_text=encounter_notice.summary(simulation)+"\n"+stage_text.text
	if save_notice.visible(simulation,battle_save_error):
		mission_button.text="저장됨 ▸" if layout_data.get("compact",false) else "전투 저장됨 · 임무 ▸"
		mission_button.tooltip_text=stage_text.text+"\n체크포인트 %d 전투 저장됨 · 임무에서 저장 정보 확인" % save_notice.checkpoint
	battle_chrome.queue_redraw()

func _handle_mobile_back() -> bool:
	if _mission_open:
		_close_mission(simulation.navigation_ticket,_menu_revision)
		return true
	if _modal_kind in ["stages", "lobby_settings"]:
		_campaign_back(simulation.navigation_ticket,_menu_revision)
		return true
	if _talents_open:
		_close_talents(simulation.navigation_ticket,_menu_revision)
		return true
	if not simulation.transition_action.is_empty():
		_cancel_transition(simulation.navigation_ticket,_menu_revision)
		return true
	if _detail_open:
		_close_skill_detail(simulation.navigation_ticket,_menu_revision)
		return true
	if _overview_open:
		_close_growth_overview(simulation.navigation_ticket,_menu_revision)
		return true
	if simulation.phase == RunState.Phase.PAUSED and _modal_kind == "paused":
		resume_game()
		return true
	if simulation.has_active_run():
		pause_game()
		return true
	return false

func _update_magic_hud() -> void:
	super._update_magic_hud()
	magic_button.icon = ui_art.texture("ultimate_button")
	magic_button.add_theme_constant_override("icon_max_width",28)
	var reason:String=simulation.magic.unavailable_reason(simulation.phase==RunState.Phase.RUNNING)
	var hint:String="[임시] 발동" if reason.is_empty() else ("마력 부족" if reason=="mana" else "전투 대기")
	magic_button.tooltip_text += "\n%s · 강화 Lv.%d" % [simulation.magic.config.get("name","[임시] 마법"),int(simulation.stats.ultimate)]
	magic_button.text="%.1f MP\n%s" % [simulation.magic.effective_cost(),hint]
	if not layout_data.is_empty():_place(magic_button,layout_data.magic)
	magic_button.queue_redraw()

func _open_mission(ticket:int,revision:int) -> void:
	if overlay.visible or simulation.phase!=RunState.Phase.RUNNING or ticket!=simulation.navigation_ticket or revision!=_menu_revision:return
	pause_game()
	if battle_save_error!=OK:return
	_clear_dialog()
	_mission_open=true
	_modal_kind="mission"
	dialog_body.add_child(_label("전투 임무 · "+str(simulation.map_space.definition.name),23))
	var duration:int=int(simulation.stage_duration)
	dialog_body.add_child(_label("생존 %.1f / %d초" % [simulation.elapsed,duration],19))
	var arrival:String=encounter_notice.summary(simulation)
	if not arrival.is_empty():dialog_body.add_child(_label(arrival,16))
	if simulation.run_mode=="gold_slime":
		dialog_body.add_child(_label("3분 생존 시 획득 금화 전액 정산 · 캠페인 해금 없음",18))
	else:
		dialog_body.add_child(_label("보스 격파: "+("완료" if simulation._boss_defeated else "진행 중"),19))
		dialog_body.add_child(_label("생존 시간과 보스 처치를 모두 달성하면 클리어합니다.",18))
	dialog_body.add_child(_label("체크포인트 %d/2 · 획득 금화 %d" % [simulation.checkpoint_index,simulation.gold_collected],18))
	_add_save_context()
	mission_return_button=_button("닫기 · 전투로",_close_mission.bind(simulation.navigation_ticket,_menu_revision))
	dialog_body.add_child(mission_return_button)
	overlay.show()
	_fit_dialog()
	_update_hud()

func _close_mission(ticket:int,revision:int) -> void:
	if not _mission_open or simulation.phase!=RunState.Phase.PAUSED or not _menu_matches(ticket,revision) or not simulation.transition_action.is_empty():return
	_mission_open=false
	_mission_touch_id=-1
	if battle_save_error!=OK:
		_show_menu("paused")
		_update_hud()
		return
	_menu_revision+=1
	super.resume_game()
