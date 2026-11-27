extends VBoxContainer
## Read-only lobby display of the latest departure profile and account bonuses.
const Talents = preload("res://scripts/progression/account_talents.gd")
const Defense = preload("res://scripts/combat/defense_rules.gd")
const CombatSkin = preload("res://scripts/ui/combat_skin.gd")
const BONUS_COLOR := Color("a9e3bb")

var _table: GridContainer
var _talent_cells: Array[Control] = []
var _other_cells: Array[Control] = []
var _talent_status: Label
var _talent_toggle: Button
var _other_toggle: Button

func setup(state, base: Dictionary, levels: Variant, skin) -> void:
	if base.is_empty():
		add_child(_label("캐릭터 정보를 불러올 수 없습니다."))
		return

	var available := Talents.valid_levels(levels)
	var catalog = state.growth.catalog
	var character_id: String = state.growth.character_id
	var ruleset: String = catalog.weapons.RULESET
	var hero: Dictionary = catalog.hero(character_id, ruleset)
	var intrinsic := Defense.character_stats(character_id)
	var magic: Dictionary = state.magic_configuration(hero, 1, character_id)
	var weapon: Dictionary = catalog.weapons.profile(str(hero.get("starting_attack", "")), 1, {"rate": base.rate})

	add_theme_constant_override("separation", 8)
	var toggles := HBoxContainer.new()
	toggles.add_theme_constant_override("separation", 8)
	add_child(toggles)
	_talent_toggle = _toggle("TalentBonuses", "특성 증가", skin.glyph("learning"), toggles)
	_other_toggle = _toggle("OtherBonuses", "기타 증가", skin.glyph("bonus"), toggles)
	_talent_status = _label("습득한 특성 없음" if available else "계정 특성 정보를 불러올 수 없습니다.")
	_talent_status.name = "TalentStatus"
	_talent_status.visible = false
	add_child(_talent_status)

	_table = GridContainer.new()
	_table.name = "StatTable"
	_table.add_theme_constant_override("h_separation", 6)
	_table.add_theme_constant_override("v_separation", 3)
	add_child(_table)
	_add_row("능력치", "기본", "특성", "기타", true)
	var has_bonus := false
	for row in _stats(base, intrinsic, magic, weapon):
		var increase := _increase(row[2], base, levels) if available and row.size() == 3 else ""
		has_bonus = has_bonus or not increase.is_empty()
		_add_row(row[0], row[1], increase, "")
	_talent_status.text = "" if has_bonus else _talent_status.text
	_refresh_columns(false)

func _stats(base: Dictionary, intrinsic: Dictionary, magic: Dictionary, weapon: Dictionary) -> Array:
	var rows := [
		["최대 HP", str(int(base.hp)), "max_hp"],
		["최대 MP", "%.0f" % magic.max_mana, "max_mana"],
		["공격력 배율", _percent(base.power), "attack_power"],
		["공격 속도 배율", _percent(base.rate), "attack_speed"],
		["이동 속도", "%.0f /초" % base.speed, "move_speed"],
		["초당 HP 회복", "%.2f" % base.hp_regen, "hp_regen"],
		["초당 MP 회복", "%.2f" % magic.mana_regen, "mp_regen"],
		["치명타 확률", _percent(base.crit), "crit_chance"],
		["치명타 피해", _percent(base.crit_damage), "crit_damage"],
		["물리 관통", _percent(intrinsic.physical_penetration)],
		["마법 관통", _percent(intrinsic.magical_penetration)],
		["물리 방어", _percent(intrinsic.physical_defense)],
		["마법 방어", _percent(intrinsic.magical_defense)],
		["받는 피해 감소", "0%", "damage_reduction"],
		["피격 후 무적시간", "%.2f초" % base.hit_lock, "invulnerability"],
		["밀어내기 저항", "0%", "knockback_resist"],
		["상태이상 지속시간 감소", "0%", "status_resist"],
		["HP 회복 효율", "100%", "healing_efficiency"],
		["적 처치 시 HP 회복", "0.00", "kill_heal"],
		["고유기 MP 소모", "%.0f" % magic.mana_cost],
		["MP 소모 감소", "0%", "mana_cost_reduction"],
		["경험치 흡수 반경", "%.0f" % base.pickup],
	]
	if not weapon.is_empty():
		rows.append_array([
			["소총 기본 피해", "%.0f" % weapon.damage],
			["소총 기본 사격 간격", "%.2f초" % weapon.interval],
			["소총 표적 거리", "%.0f" % weapon.reach, "attack_range"],
			["소총 탄속", "%.0f /초" % weapon.speed, "projectile_speed"],
		])
	return rows

static func _percent(value: float) -> String:
	return "%.0f%%" % (value * 100.0)

static func _increase(id: String, base: Dictionary, levels: Dictionary) -> String:
	var rank: int = levels[id]
	if rank == 0:
		return ""
	if id == "max_hp":
		return "+%d" % (Talents.maximum_hp(int(base.hp), levels) - int(base.hp))
	if id == "max_mana":
		return "+%s" % str(Talents.DEFINITIONS[id].values[rank]).trim_suffix(".0")
	var effect := Talents.effect_text(id, rank)
	# Reduction rows measure the amount reduced, so higher is a positive bonus.
	return "+" + effect.trim_prefix("-") + "p" if effect.begins_with("-") else effect

func _toggle(node_name: String, caption: String, icon: Texture2D, parent: HBoxContainer) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = caption
	button.icon = icon
	button.toggle_mode = true
	button.custom_minimum_size.y = 46
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_constant_override("icon_max_width", 22)
	button.add_theme_font_size_override("font_size", 16)
	CombatSkin.style_button(button)
	parent.add_child(button)
	button.toggled.connect(_refresh_columns)
	return button

func _refresh_columns(_pressed: bool) -> void:
	var talents := _talent_toggle.button_pressed
	var other := _other_toggle.button_pressed
	_table.columns = 2 + int(talents) + int(other)
	for cell in _talent_cells:
		cell.visible = talents
	for cell in _other_cells:
		cell.visible = other
	_talent_status.visible = talents and not _talent_status.text.is_empty()

func _add_row(title: String, base: String, talent: String, other: String, header := false) -> void:
	var name_cell := _cell(title, header)
	name_cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_cell.get_child(0).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_cell(base, header)
	_talent_cells.append(_cell(talent, header, BONUS_COLOR))
	_other_cells.append(_cell(other, header))

func _cell(text: String, header: bool, color: Color = CombatSkin.LIGHT) -> PanelContainer:
	var cell := PanelContainer.new()
	cell.custom_minimum_size = Vector2(84, 28)
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_theme_stylebox_override("panel", CombatSkin.plate(Color("312729") if header else Color("201b20"), Color("514036"), 8))
	_table.add_child(cell)
	var label := _label(text, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cell.add_child(label)
	return cell

static func _label(text: String, color: Color = CombatSkin.LIGHT) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", color)
	return label
