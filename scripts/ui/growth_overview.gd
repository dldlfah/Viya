extends RefCounted
## Read-only projections of the existing run. No new stat formulas or RNG.
const Growth = preload("res://scripts/progression/growth_state.gd")

static func capture(run) -> Dictionary:
	var growth = run.growth
	var upgrade_id: String = str(run.magic.config.get("upgrade_skill_id", ""))
	var upgrade: Dictionary = growth.definition(upgrade_id)
	var rank: int = growth.skill_level(upgrade_id)
	return {"character_id": growth.character_id, "level": growth.level,
		"xp": growth.xp, "xp_required": growth.threshold(), "pending": growth.pending,
		"attack": _row(growth, "attack"), "passive": _row(growth, "passive"),
		"attack_cap": Growth.ATTACK_CAP, "passive_cap": Growth.PASSIVE_CAP,
		"hp": run.hp, "max_hp": run.max_hp, "stats": run.stats.duplicate(true),
		"magic": run.magic.profile(rank).duplicate(true), "magic_rank": rank,
		"upgrade_name": str(upgrade.get("name", "[임시] 고유 마법 강화")),
		"mana": run.magic.mana, "max_mana": float(run.magic.config.get("max_mana", 0.0)),
		"cooldown_left": run.magic.cooldown_left,
		"summary": run.result_summary().duplicate(true)}

static func _row(growth, row: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in growth.row_entries(row):
		var id: String = str(entry["id"])
		result.append({"id": id, "name": str(entry["name"]),
			"level": growth.skill_level(id), "max_level": int(entry["max_level"]),
			"description": str(entry["description"])})
	return result

static func compact(data: Dictionary) -> String:
	return "공격 %d/%d · 패시브 %d/%d · 고유 마법 강화 Lv.%d" % [
		data["attack"].size(), data["attack_cap"], data["passive"].size(),
		data["passive_cap"], data["magic_rank"]]

static func sections(data: Dictionary) -> Array[Dictionary]:
	var stats: Dictionary = data["stats"]
	var magic: Dictionary = data["magic"]
	var result: Array[Dictionary] = []
	result.append({"title": "성장 · Lv.%d" % int(data["level"]),
		"body": "캐릭터 %s / EXP %.2f / %.0f\n남은 성장 선택 %d회 · 장착 한도와 수치는 임시입니다." % [
			data["character_id"], data["xp"], data["xp_required"], data["pending"]]})
	result.append({"title": "공격 스킬 %d/%d" % [data["attack"].size(), data["attack_cap"]],
		"body": _row_text(data["attack"])})
	result.append({"title": "패시브 스킬 %d/%d" % [data["passive"].size(), data["passive_cap"]],
		"body": _row_text(data["passive"])})
	var magic_text: String = "마법 설정 없음"
	if not magic.is_empty():
		magic_text = "%s\n%s Lv.%d (공격·패시브 칸과 별도)\n기본 피해 %.0f / 반경 %.0f\n소모 MP %.0f / 재사용 %.1f초\n현재 MP %.1f / %.0f / 남은 재사용 %.1f초\n피해는 공격력·치명타 적용 전 기본값입니다." % [
			magic["name"], data["upgrade_name"], data["magic_rank"], magic["damage"], magic["radius"],
			magic["mana_cost"], magic["cooldown"], data["mana"], data["max_mana"], data["cooldown_left"]]
	result.append({"title": "고유 마법", "body": magic_text})
	result.append({"title": "현재 적용 능력치", "body":
		"HP %d / %d\n공격 피해 배율 ×%.2f / 자동 공격 속도 배율 ×%.2f\n이동 속도 %.1f / 경험치 획득 배율 ×%.2f\n획득 범위 %.1f / 치명타 확률 %.1f%% / 초당 체력 회복 %.2f\n거리·속도는 전투 논리 단위이며 장비 점수나 영구 능력치가 아닙니다." % [
			data["hp"], data["max_hp"], stats["power"], stats["rate"], stats["speed"],
			stats["xp"], stats["pickup"], float(stats["crit"]) * 100.0, stats["regen"]]})
	return result

static func _row_text(entries: Array) -> String:
	if entries.is_empty():
		return "아직 획득한 스킬이 없습니다."
	var lines := PackedStringArray()
	for entry in entries:
		lines.append("%s · Lv.%d/%d\n%s" % [entry["name"], entry["level"],
			entry["max_level"], entry["description"]])
	return "\n\n".join(lines)
