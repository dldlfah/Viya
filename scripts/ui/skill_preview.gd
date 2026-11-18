extends RefCounted
## Read-only comparison. All combat values come from RunState/MagicState profiles.
## No preview simulation, selection calls, resources, timers or random draws.

static func build(run, id: String) -> Dictionary:
	var growth = run.growth
	var entry: Dictionary = growth.definition(id)
	if entry.is_empty() or not growth.eligible().has(id):
		return {}
	var rank: int = growth.skill_level(id)
	var kind: String = str(entry["kind"])
	var effect: String = str(entry["effect"])
	if kind == "ultimate" and str(run.magic.config.get("upgrade_skill_id", "")) != id:
		return {}
	var next_levels: Dictionary = growth.owned.duplicate(true)
	next_levels[id] = rank + 1
	var before: Dictionary = run.stats_profile(growth.owned)
	var after: Dictionary = run.stats_profile(next_levels)
	before["hp"] = run.hp
	after["hp"] = run.selection_health(run.hp, run.max_hp, int(after["max_hp"]))
	var rows: Array[Dictionary] = []
	var note: String = ""
	if kind in ["attack", "character"]:
		var old_attack: Dictionary = run.attack_profile(effect, rank, float(before["stats"]["rate"]))
		var new_attack: Dictionary = run.attack_profile(effect, rank + 1, float(after["stats"]["rate"]))
		if new_attack.is_empty():
			return {}
		before["attack"] = old_attack
		after["attack"] = new_attack
		_add(rows, "1발 기본 피해" if new_attack.has("projectiles") else "1대상 기본 피해", old_attack, new_attack, "damage", "number")
		_add(rows, "발동 간격", old_attack, new_attack, "interval", "seconds")
		for key in ["projectiles", "hits", "targets", "radius"]:
			if new_attack.has(key):
				var label: String = {"projectiles": "한 번에 발사", "hits": "탄환당 최대 타격 대상",
					"targets": "최대 연쇄 대상", "radius": "반경"}[key]
				_add(rows, label, old_attack, new_attack, key, "number")
		note = "피해는 공격력·치명타 적용 전입니다. 남은 공격 대기는 유지됩니다."
	elif kind == "passive":
		if effect == "vitality":
			_add(rows, "최대 HP", before, after, "max_hp", "number")
			_add(rows, "선택 직후 HP", before, after, "hp", "number")
			note = "최대 체력 증가분만큼 회복하며, 미리보기만으로 회복하지 않습니다."
		else:
			var fields: Dictionary = {
				"power": ["power", "피해 배율", "multiplier"],
				"haste": ["rate", "자동 공격 속도 배율", "multiplier"],
				"stride": ["speed", "이동 속도", "number"],
				"magnet": ["pickup", "획득 범위", "number"],
				"learning": ["xp", "경험치 획득 배율", "multiplier"],
				"precision": ["crit", "치명타 확률", "percent"],
				"recovery": ["regen", "초당 HP 회복", "number"]}
			if not fields.has(effect):
				return {}
			var field: Array = fields[effect]
			_add(rows, str(field[1]), before["stats"], after["stats"], str(field[0]), str(field[2]))
			if effect == "haste":
				var old_rifle: Dictionary = run.attack_profile("rifle", growth.skill_level("common_rifle"), float(before["stats"]["rate"]))
				var new_rifle: Dictionary = run.attack_profile("rifle", growth.skill_level("common_rifle"), float(after["stats"]["rate"]))
				if not new_rifle.is_empty():
					_add(rows, "소총 발동 간격", old_rifle, new_rifle, "interval", "seconds")
				note = "자동 공격에 적용됩니다. 고유 마법의 마나 소모·회복은 유지됩니다."
			elif effect == "learning":
				note = "요구 경험치(기존의 3배)는 변경되지 않습니다."
			elif effect in ["stride", "magnet"]:
				note = "거리·속도는 전투 논리 단위입니다."
	elif kind == "ultimate":
		var old_magic: Dictionary = run.magic.profile(rank)
		var new_magic: Dictionary = run.magic.profile(rank + 1)
		if old_magic.is_empty() or new_magic.is_empty():
			return {}
		before["magic"] = old_magic
		after["magic"] = new_magic
		_add(rows, "마법 기본 피해", old_magic, new_magic, "damage", "number")
		_add(rows, "마법 반경", old_magic, new_magic, "radius", "number")
		_add(rows, "소모 MP", old_magic, new_magic, "mana_cost", "number")
		_add(rows, "초당 MP 회복", old_magic, new_magic, "mana_regen", "number")
		note = "강화 Lv.0에도 마법은 사용 가능합니다. 현재 MP 유지. 기본 피해는 배율·치명타 적용 전입니다."
		if float(new_magic.cooldown) > 0.0:
			_add(rows, "재사용 시간", old_magic, new_magic, "cooldown", "seconds")
			note += " 남은 재사용 시간은 유지됩니다."
	else:
		return {}
	return {"id": id, "kind": kind, "effect": effect, "rank": rank, "next_rank": rank + 1,
		"before": before, "after": after, "rows": rows, "note": note}

static func _add(rows: Array[Dictionary], label: String, before: Dictionary, after: Dictionary, key: String, unit: String) -> void:
	rows.append({"label": label, "key": key, "unit": unit,
		"before": before.get(key), "after": after[key]})

static func describe(data: Dictionary) -> String:
	if data.is_empty():
		return "비교 정보 없음 · 현재 선택 가능한 후보인지 확인해 주세요."
	var lines := PackedStringArray()
	for row in data["rows"]:
		var next_text: String = _value(row["after"], str(row["unit"]))
		if row["before"] != null and is_equal_approx(float(row["before"]), float(row["after"])):
			lines.append("%s %s (유지)" % [row["label"], next_text])
		else:
			lines.append("%s %s → %s" % [row["label"], _value(row["before"], str(row["unit"])), next_text])
	if not str(data["note"]).is_empty():
		lines.append(str(data["note"]))
	return "\n".join(lines)

static func _value(value, unit: String) -> String:
	if value == null:
		return "미보유"
	match unit:
		"multiplier":
			return "×%.2f" % float(value)
		"percent":
			return "%.1f%%" % (float(value) * 100.0)
		"seconds":
			return "%.3f초" % float(value)
	return ("%.2f" % float(value)).trim_suffix("0").trim_suffix("0").trim_suffix(".")
