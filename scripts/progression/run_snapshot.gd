extends RefCounted
## Exact gameplay data. Cosmetic effects/cues are rebuilt after a restore.
const VERSION := 21
const GAME048_RULES := "695c4691c0d6cad598c66fa825388aee5cc04b373f120c99332d622fc525adb0"
const GAME047_RULES := "453182097a89e5b3da2dc52a7253ba68f33f50a2cf1fad91a4c23123cfcb3ed8"
const GAME045_RULES := "d19d8361edf34b139b7e6d6416a70eec5f47eb7c34c5e757170d0b7ff53f51d1"
const GAME039_RULES := "e537044ffa111e582b2762d59fbb56dbe0fc36968af297be831ae62aecc1c186"
const GAME038_RULES := "29f9c4404b89acd779d45598c859a8669e5d30c08fbfe218c7a9be7caa463a47"
const GAME023_RULES := "25dfc5d463289c0eb5f9aac0fab694d203fcdf0b6e2e5621a21eab91caa3ec30"
const GAME022_RULES := "9a0c5ce43584f5464325aca9faa2db1597b33bd3243b9055cc65d8e6965ba196"
const GAME021_RULES := "3480971cf9cb7602c911416d32c93e97cef575d8634b9aa37b21c77d20a6ad87"
const GAME020_RULES := "b7986a61066095ac126a39187bae083d61ad529c1cf084dcdf602b6f033ed4a0"
const GAME019_RULES := "cea5d6c275ba3c2fa7d55cb9cf615c386df1480ec4d9a1413f62d95b51292536"
const GAME017_RULES := "2e0bfb55209da4daaba2c62e718741d3603f31933a50702c8d3bc783438e7913"
const GAME016_RULES := "8d625d5607e80b1486103e77ddbf57d791b39e9ebe389c704416857e2b574d27"
const GAME015_RULES := "99b5b472aaaec892172902f02cf5abb5f368c9da43a451578ebc2b8c7706b894"
const GAME011_RULES := "7644920556aef98fd56539ab07f8deab2e446baab4fa4320d4a78247f38ca9f8"
const GAME010_RULES := "711b73b68b15d571c240c7e4b8c20261ddec790a5db723c2ef1bd2d83f68042b"
const LEGACY_RULES := "3ecf54fd2e0aedad3127fce24d77cc55ea0f8ffe3bfbf235d2470d233a34231e"
const LEGACY_FINGERPRINTS := [LEGACY_RULES,
	"3c7246f58f661c077aad3c146a3719a9719269c1809a5c65dc5e72aefbfeb7dd",
	"221b21de9116fbafd0eb9bcde72f93efa72126f76e73c89788e69d41e5dc53bd",
	"3772fbaceb94a67d68624118ddfe9f021dfb8b26dd36bdef7c16f8e4d4405ad0"]
const RUN_FIELDS := ["phase", "player", "facing", "hp", "elapsed", "kills", "shots",
	"shot_clock", "spawn_clock", "hurt_clock", "skill_clocks", "_resume_phase",
	"_enemy_serial", "_regen_remainder", "navigation_ticket", "stage", "run_id",
	"gold_collected", "gold_drop_chance", "_elites_spawned", "_boss_spawned", "_boss_defeated", "checkpoint_index", "end_reason",
	"account_attack_level", "account_talent_levels", "_damage_reduction_remainder", "_slow_left", "_kill_heal_clock", "_kill_heal_used", "enemies", "bullets", "pickups", "gold_pickups", "enemy_bullets", "_swarm_clock", "_swarm_pending", "_swarm_serial", "_scatter_clock", "_scatter_index", "map_id", "spawn_view_size", "structures", "item_pickups", "_loot_serial", "weapon_events",
	"armor_enabled", "support_attack_ids", "support_passive_ids", "combat_profile_version", "run_mode", "dungeon_day", "gold_reward_version", "enemy_pattern_version", "encounter_version", "chest_pickups", "_chest_serial", "_chests_opened", "_chest_bonus_ranks"]
const GROWTH_FIELDS := ["ruleset", "character_id", "owned", "level", "xp", "pending", "offer", "ticket", "revision", "pacing_version"]
const MAGIC_FIELDS := ["mana", "cooldown_left", "casts", "ticket"]

static func fingerprint_previous() -> String:
	var stages := FileAccess.get_file_as_string("res://data/stages.json").replace("\r\n", "\n")
	var skills := FileAccess.get_file_as_string("res://data/prototype_skills.json").replace("\r\n", "\n")
	return (stages + skills + FileAccess.get_file_as_string("res://data/maps.json").replace("\r\n", "\n") + FileAccess.get_file_as_string("res://data/destructibles.json").replace("\r\n", "\n") + FileAccess.get_file_as_string("res://data/weapon_skills.json").replace("\r\n", "\n")).sha256_text()

static func fingerprint_for_v11() -> String:
	# Keep the published v10 digest for exact conversion of in-progress battles.
	var source: String = FileAccess.get_file_as_string("res://scripts/combat/defense_rules.gd").replace("\r\n","\n")
	return (fingerprint_previous()+source).sha256_text()

static func fingerprint_for_v12() -> String:
	return (fingerprint_for_v11()+FileAccess.get_file_as_string("res://data/combat_profiles.json").replace("\r\n","\n")).sha256_text()

static func fingerprint_for_v13() -> String:
	return (fingerprint_for_v12()+FileAccess.get_file_as_string("res://data/gold_dungeon.json").replace("\r\n","\n")).sha256_text()

static func fingerprint_for_v14() -> String:
	return (fingerprint_for_v13()+FileAccess.get_file_as_string("res://data/combat_pacing.json").replace("\r\n","\n")+FileAccess.get_file_as_string("res://scripts/progression/combat_pacing.gd").replace("\r\n","\n")).sha256_text()

static func fingerprint_for_v15()->String:
	return (fingerprint_for_v14()+FileAccess.get_file_as_string("res://data/gold_rewards.json").replace("\r\n","\n")).sha256_text()

static func fingerprint_for_v16()->String:
	return (fingerprint_for_v15()+FileAccess.get_file_as_string("res://data/enemy_patterns.json").replace("\r\n","\n")+FileAccess.get_file_as_string("res://scripts/combat/enemy_patterns_v1.gd").replace("\r\n","\n")).sha256_text()

static func fingerprint_for_v17()->String:
	return (fingerprint_for_v16()+FileAccess.get_file_as_string("res://data/enemy_patterns_v2.json").replace("\r\n","\n")+FileAccess.get_file_as_string("res://scripts/combat/enemy_patterns_v2.gd").replace("\r\n","\n")+FileAccess.get_file_as_string("res://scripts/combat/enemy_patterns_v17.gd").replace("\r\n","\n")).sha256_text()

static func fingerprint_for_v18()->String:
	return (fingerprint_for_v17()+FileAccess.get_file_as_string("res://data/enemy_curse_v3.json").replace("\r\n","\n")+FileAccess.get_file_as_string("res://scripts/combat/enemy_patterns_v3.gd").replace("\r\n","\n")+FileAccess.get_file_as_string("res://scripts/combat/enemy_patterns.gd").replace("\r\n","\n")).sha256_text()

static func fingerprint_for_v19()->String:
	return (fingerprint_for_v18()+FileAccess.get_file_as_string("res://data/campaign_encounters.json").replace("\r\n","\n")+FileAccess.get_file_as_string("res://scripts/combat/campaign_encounters_v19.gd").replace("\r\n","\n")).sha256_text()

static func fingerprint_for_v20()->String:
	return (fingerprint_for_v19()+FileAccess.get_file_as_string("res://scripts/combat/campaign_encounters.gd").replace("\r\n","\n")+FileAccess.get_file_as_string("res://data/campaign_pressure.json").replace("\r\n","\n")+FileAccess.get_file_as_string("res://scripts/combat/campaign_pressure.gd").replace("\r\n","\n")).sha256_text()

static func fingerprint()->String:
	var source:=fingerprint_for_v20()
	for path in ["res://data/campaign_battlefield.json","res://scripts/world/map_catalog.gd","res://scripts/world/supply_catalog.gd","res://scripts/combat/combat_profiles.gd","res://scripts/combat/stage_catalog.gd"]:
		source+=FileAccess.get_file_as_string(path).replace("\r\n","\n")
	return source.sha256_text()

static func capture(state) -> Dictionary:
	var result := {"version": VERSION, "rules": fingerprint(), "run": {}, "growth": {}, "magic": {}, "rng": []}
	for key in RUN_FIELDS:
		result.run[key] = state.get(key)
	for key in GROWTH_FIELDS:
		result.growth[key] = state.growth.get(key)
	for key in MAGIC_FIELDS:
		result.magic[key] = state.magic.get(key)
	for generator in [state.rng, state.growth.rng, state.gold_rng, state.encounter_rng, state.scatter_rng, state.loot_rng, state.species_rng]:
		result.rng.append({"seed": generator.seed, "state": generator.state})
	return result.duplicate(true)

static func upgrade_legacy(data:Dictionary,state)->Dictionary:
	var version:Variant=data.get("version")
	var candidate:Dictionary
	if version is int and version<=20 and data.get("run") is Dictionary and data.run.get("map_id")=="siege_battlefield":return {}
	if version is int and version==20 and data.get("rules")==GAME048_RULES:
		candidate=data.duplicate(true)
		candidate.version=VERSION
		candidate.rules=fingerprint()
		return candidate # Preserve the exact published20 map, positions and RNG.
	if version==19 and data.get("rules")==GAME047_RULES:
		candidate=data.duplicate(true)
		candidate.version=VERSION
		candidate.rules=fingerprint()
		return candidate # Keep existing policy0/1, chest ledger and all seven streams.
	if version==18 and data.get("rules")==GAME045_RULES:
		candidate=data.duplicate(true)
		candidate.version=VERSION
		candidate.rules=fingerprint()
	else:candidate=_upgrade_legacy(data,state)
	if version is int and version>=1 and version<=18 and candidate.get("version")==VERSION and candidate.get("rules")==fingerprint():
		if not candidate.get("run") is Dictionary:return {}
		for key in ["encounter_version","_chest_serial","_chests_opened","_chest_bonus_ranks"]:
			if candidate.run.has(key) and (not candidate.run[key] is int or candidate.run[key]!=0):return {}
		if candidate.run.has("chest_pickups") and (not candidate.run.chest_pickups is Array or not candidate.run.chest_pickups.is_empty()):return {}
		candidate=candidate.duplicate(true)
		candidate.run.encounter_version=0 # Never retrofit population or chest rewards.
		candidate.run.chest_pickups=[]
		candidate.run._chest_serial=0
		candidate.run._chests_opened=0
		candidate.run._chest_bonus_ranks=0
	return candidate

static func _upgrade_legacy(data: Dictionary, state) -> Dictionary:
	if data.get("version")==17 and data.get("rules")==GAME039_RULES:return _upgrade_curse_revision(data)
	if data.get("version")==16 and data.get("rules")==GAME038_RULES:return _upgrade_pattern_revision(data)
	if data.get("version")==15 and data.get("rules")==GAME023_RULES:return _upgrade_patterns(data)
	if data.get("version")==14 and data.get("rules")==GAME022_RULES:return _upgrade_rewards(data)
	if data.get("version")==13 and data.get("rules")==GAME021_RULES:return _upgrade_pacing(data)
	if data.get("version")==12 and data.get("rules")==GAME020_RULES:return _upgrade_mode(data)
	if data.get("version")==11 and data.get("rules")==GAME019_RULES:
		return _upgrade_profiles(data)
	if data.get("version") == 10 and data.get("rules") == fingerprint_previous():
		return _upgrade_defense(data)
	if data.get("version") == 9 and data.get("rules") == GAME017_RULES:
		return _upgrade_weapons(data)
	if data.get("version") == 8 and data.get("rules") == GAME016_RULES:
		return _upgrade_supplies(data)
	if data.get("version") == 7 and data.get("rules") == GAME015_RULES:
		return _upgrade_map(data)
	if data.get("version") == 6 and data.get("rules") == GAME011_RULES:
		return _upgrade_scatter(data)
	if data.get("version") == 5 and data.get("rules") == GAME011_RULES:
		if not data.get("run") is Dictionary:
			return {}
		var expanded: Dictionary = state.AccountTalents.expand_six(data.run.get("account_talent_levels"))
		if expanded.is_empty():
			return {}
		data = data.duplicate(true)
		data.run.account_talent_levels = expanded
		return _upgrade_tree(data)
	if data.get("version") == 4 and data.get("rules") == GAME011_RULES:
		if not data.get("run") is Dictionary or not state.AccountTalents.valid_level(data.run.get("account_attack_level")):
			return {}
		data = data.duplicate(true)
		data.version = VERSION
		data.run.account_talent_levels = state.AccountTalents.from_attack(data.run.account_attack_level)
		data.run._damage_reduction_remainder = 0.0
		return _upgrade_tree(data)
	if data.get("version") == 3 and data.get("rules") == GAME011_RULES:
		return _upgrade_account(data)
	if data.get("version") == 2 and data.get("rules") == GAME010_RULES:
		return _upgrade_mana(data)
	if data.get("version") != 1 or data.get("rules") not in LEGACY_FINGERPRINTS:
		return data
	if not data.get("run") is Dictionary or not data.get("rng") is Array or data.rng.size() != 3:
		return data
	var run: Dictionary = data.run
	if not run.get("enemies") is Array or not run.get("stage") is int or not finite_number(run.get("elapsed"), 0, 36000):
		return data
	if not data.rng[0] is Dictionary or not data.rng[0].get("seed") is int:
		return data
	var rules: Dictionary = state.stage_catalog.for_stage(run.stage)
	if rules.is_empty():
		return data
	data = data.duplicate(true)
	data.run.enemy_bullets = []
	data.run._swarm_clock = float(rules.swarm.interval) - fmod(float(run.elapsed), float(rules.swarm.interval))
	data.run._swarm_pending = false
	data.run._swarm_serial = 0
	for enemy in data.run.enemies:
		if not enemy is Dictionary:
			return {}
		enemy.variant = "normal" # Existing enemies retain their actual HP and speed.
	var generator := RandomNumberGenerator.new()
	generator.seed = int(data.rng[0].seed) ^ 0xE11C
	data.rng.append({"seed": generator.seed, "state": generator.state})
	return _upgrade_mana(data)

static func _upgrade_mana(data: Dictionary) -> Dictionary:
	if not data.get("magic") is Dictionary or not finite_number(data.magic.get("cooldown_left"), 0, 12):
		return {} # Do not repair malformed resources into a valid save.
	data = data.duplicate(true)
	data.version = VERSION
	data.rules = fingerprint()
	data.magic.cooldown_left = 0.0 # Preserve MP/casts; the old timer no longer applies.
	return _upgrade_account(data)

static func _upgrade_account(data: Dictionary) -> Dictionary:
	if not data.get("run") is Dictionary:
		return {}
	data = data.duplicate(true)
	data.version = VERSION
	data.rules = fingerprint()
	data.run.account_attack_level = 0 # Older runs predate account talents.
	data.run.account_talent_levels = preload("res://scripts/progression/account_talents.gd").empty_levels()
	data.run._damage_reduction_remainder = 0.0
	return _upgrade_tree(data)

static func _upgrade_tree(data: Dictionary) -> Dictionary:
	data.version = VERSION
	data.run._slow_left = 0.0
	data.run._kill_heal_clock = 0.0
	data.run._kill_heal_used = 0.0
	return _upgrade_scatter(data)

static func _upgrade_scatter(data: Dictionary) -> Dictionary:
	if not data.get("run") is Dictionary or not data.get("rng") is Array or data.rng.size() != 4:
		return {}
	if not data.rng[0] is Dictionary or not data.rng[0].get("seed") is int or not data.run.get("stage") is int or not data.run.get("enemies") is Array:
		return {}
	var rules: Dictionary = preload("res://scripts/combat/stage_catalog.gd").new().for_stage(data.run.stage)
	if rules.is_empty():
		return {}
	data = data.duplicate(true)
	data.version = VERSION
	data.rules = fingerprint()
	data.run._scatter_clock = float(rules.scatter.interval) # No retroactive packs.
	data.run._scatter_index = 0
	for enemy in data.run.enemies:
		if not enemy is Dictionary:
			return {}
		enemy.scatter_group = 0
	var generator := RandomNumberGenerator.new()
	generator.seed = int(data.rng[0].seed) ^ 0x5CA77
	data.rng.append({"seed": generator.seed, "state": generator.state})
	return _upgrade_map(data)

static func _upgrade_map(data: Dictionary) -> Dictionary:
	if not data.get("run") is Dictionary:
		return {}
	data = data.duplicate(true)
	data.version = VERSION
	data.rules = fingerprint()
	data.run.map_id = "legacy_arena"
	data.run.spawn_view_size = Vector2(1256,468)
	return _upgrade_supplies(data)

static func _upgrade_supplies(data: Dictionary) -> Dictionary:
	if not data.get("run") is Dictionary or not data.get("rng") is Array or data.rng.size() != 5 or not data.rng[0] is Dictionary or not data.rng[0].get("seed") is int:
		return {}
	data = data.duplicate(true)
	data.version = VERSION
	data.rules = fingerprint()
	data.run.structures = [] # Old in-progress runs never gain retroactive loot.
	data.run.item_pickups = []
	data.run._loot_serial = 0
	var generator := RandomNumberGenerator.new()
	generator.seed = int(data.rng[0].seed) ^ 0x1007
	data.rng.append({"seed": generator.seed, "state": generator.state})
	return _upgrade_weapons(data)

static func _upgrade_weapons(data: Dictionary) -> Dictionary:
	if not data.get("growth") is Dictionary or not data.get("run") is Dictionary:
		return {}
	data = data.duplicate(true)
	data.version = VERSION
	data.rules = fingerprint()
	data.growth.ruleset = "legacy" # Keep old IDs/effects/offers exactly as played.
	data.run.weapon_events = []
	return _upgrade_defense(data)

static func _upgrade_defense(data: Dictionary) -> Dictionary:
	if not data.get("run") is Dictionary:
		return {}
	data = data.duplicate(true)
	data.version = VERSION
	data.rules = fingerprint()
	data.run.armor_enabled = false # Do not increase defense halfway through an old battle.
	data.run.support_attack_ids = []
	data.run.support_passive_ids = []
	return _upgrade_profiles(data)

static func _upgrade_profiles(data: Dictionary) -> Dictionary:
	if not data.get("run") is Dictionary or not data.get("rng") is Array or data.rng.size()!=6 or not data.rng[0] is Dictionary or not data.rng[0].get("seed") is int:
		return {}
	data=data.duplicate(true)
	data.version=VERSION
	data.rules=fingerprint()
	data.run.combat_profile_version=0 # Never recalculate old living or future actors.
	var generator:=RandomNumberGenerator.new()
	generator.seed=int(data.rng[0].seed)^0x5EEC1E5
	data.rng.append({"seed":generator.seed,"state":generator.state})
	return _upgrade_mode(data)

static func _upgrade_mode(data: Dictionary) -> Dictionary:
	if not data.get("run") is Dictionary:return {}
	data=data.duplicate(true)
	data.version=VERSION
	data.rules=fingerprint()
	data.run.run_mode="campaign"
	data.run.dungeon_day=-1
	return _upgrade_pacing(data)

static func _upgrade_pacing(data:Dictionary)->Dictionary:
	if not data.get("growth") is Dictionary:return {}
	data=data.duplicate(true)
	data.version=VERSION
	data.rules=fingerprint()
	data.growth.pacing_version=0
	return _upgrade_rewards(data)

static func _upgrade_rewards(data:Dictionary)->Dictionary:
	if not data.get("run") is Dictionary:return {}
	data=data.duplicate(true)
	data.version=VERSION
	data.rules=fingerprint()
	data.run.gold_reward_version=0
	return _upgrade_patterns(data)

static func _upgrade_patterns(data:Dictionary)->Dictionary:
	if not data.get("run") is Dictionary or not data.run.get("enemies") is Array:return {}
	if data.run.get("enemy_pattern_version",0)!=0:return {}
	for enemy in data.run.enemies:
		if not enemy is Dictionary or enemy.has("pattern"):return {}
	data=data.duplicate(true)
	data.version=VERSION
	data.rules=fingerprint()
	data.run.enemy_pattern_version=0 # Old living AND future enemies retain their original AI.
	return data


static func _upgrade_pattern_revision(data:Dictionary)->Dictionary:
	if not data.get("run") is Dictionary or not data.run.get("enemy_pattern_version") is int or data.run.enemy_pattern_version not in [0,1]:return {}
	data=data.duplicate(true)
	data.version=VERSION
	data.rules=fingerprint()
	return data # Preserve original rules and every in-progress attack field.

static func _upgrade_curse_revision(data:Dictionary)->Dictionary:
	if not data.get("run") is Dictionary or not data.run.get("enemy_pattern_version") is int or data.run.enemy_pattern_version not in [0,1,2]:return {}
	data=data.duplicate(true)
	data.version=VERSION
	data.rules=fingerprint()
	return data # Preserve published17 AI and its already-spent attack attempts.

static func finite_number(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and value >= minimum and value <= maximum

static func vector(value: Variant) -> bool:
	return value is Vector2 and value.is_finite() and value.length() < 100000.0

static func valid(data: Dictionary, state) -> bool:
	if data.get("version") != VERSION or data.get("rules") != fingerprint():
		return false
	for key in ["run", "growth", "magic"]:
		if not data.get(key) is Dictionary:
			return false
	var run: Dictionary = data.run
	var growth: Dictionary = data.growth
	var magic: Dictionary = data.magic
	for key in RUN_FIELDS:
		if not run.has(key):
			return false
	if not run.enemy_pattern_version is int or run.enemy_pattern_version not in [0,1,2,3] or (run.enemy_pattern_version>0 and (run.run_mode!="campaign" or run.combat_profile_version!=1 or not state.enemy_patterns.available(run.enemy_pattern_version))):return false
	if not run.gold_reward_version is int or run.gold_reward_version not in [0,1] or (run.gold_reward_version==1 and (run.run_mode!="gold_slime" or state.dungeon.rewards.is_empty())):return false
	if not growth.get("pacing_version") is int or growth.pacing_version not in [0,1] or (growth.pacing_version==1 and (growth.get("ruleset")!="weapons_v1" or state.growth.pacing.data.is_empty())):return false
	if run.run_mode not in ["campaign","gold_slime"] or not run.dungeon_day is int or (run.run_mode=="campaign" and (run.dungeon_day!=-1 or run.map_id=="gold_slime")) or (run.run_mode=="gold_slime" and (run.map_id!="gold_slime" or run.dungeon_day<0 or run.dungeon_day>100000000 or run.combat_profile_version!=1 or growth.get("ruleset")!="weapons_v1" or run.gold_drop_chance!=1.0 or run._elites_spawned!=0 or run._boss_spawned!=false or run._boss_defeated!=false or (not run.enemy_bullets is Array or not run.enemy_bullets.is_empty()))):
		return false
	if not run.combat_profile_version is int or run.combat_profile_version not in [0,1] or (run.combat_profile_version==1 and (run.get("armor_enabled")!=true or growth.get("ruleset")!="weapons_v1" or not state.profiles.error.is_empty() or state.profiles.hero(str(growth.get("character_id",""))).is_empty())):
		return false
	if not run.armor_enabled is bool or not run.support_attack_ids is Array or not run.support_passive_ids is Array:
		return false
	if not state.DefenseRules.valid_supports(str(growth.get("character_id","")),run.support_attack_ids,run.support_passive_ids):
		return false
	if not vector(run.get("player")) or not run.map_id is String or not vector(run.spawn_view_size) or run.spawn_view_size.x < 1 or run.spawn_view_size.y < 1:
		return false
	var map_data: Dictionary = state.map_catalog.definition(run.map_id)
	if map_data.is_empty():
		return false
	var space = state.MapSpace.new(map_data)
	if not state.encounters.valid_run(run,space.world_size) or (run.encounter_version==2 and state.pressure.data.is_empty()):return false
	if not space.valid_position(run.player,30.0):
		return false
	if not state.AccountTalents.valid_levels(run.account_talent_levels) or not state.AccountTalents.valid_level(run.account_attack_level) or run.account_attack_level != run.account_talent_levels.attack_power:
		return false
	if not finite_number(run._damage_reduction_remainder, 0, 0.999999999999):
		return false
	if run.phase not in [1, 2, 3, 4, 5, 6] or run._resume_phase not in [1, 4]:
		return false
	for key in ["hp", "kills", "shots", "_enemy_serial", "navigation_ticket", "stage", "gold_collected", "_elites_spawned", "checkpoint_index"]:
		if not run.get(key) is int or not finite_number(run[key], 0, 1000000000):
			return false
	for key in ["elapsed", "shot_clock", "spawn_clock", "hurt_clock", "_regen_remainder"]:
		if not finite_number(run.get(key), 0, 36000):
			return false
	if not vector(run.player) or not vector(run.facing) or run.stage < 1 or run.checkpoint_index > 2:
		return false
	var encounter_rules:Dictionary=state.stage_catalog.for_run(run.stage,run.run_mode)
	if encounter_rules.is_empty() or run._elites_spawned>state.encounters.elite_times(encounter_rules,run.encounter_version).size():return false
	if not finite_number(run.get("gold_drop_chance"), 0, 1):
		return false
	if not finite_number(run._swarm_clock, 0, 1000) or not run._swarm_pending is bool or not run._swarm_serial is int or run._swarm_serial < 0:
		return false
	if run.player != run.player.clamp(Vector2.ONE * 30.0, space.world_size - Vector2.ONE * 30.0):
		return false
	if run._regen_remainder >= 1.0 or run.hurt_clock > state.HIT_LOCK + float(state.AccountTalents.bonuses(run.account_talent_levels).invulnerability) + 0.000000001:
		return false
	if not run.run_id is String or run.run_id.length() != 32 or not run.run_id.is_valid_hex_number(false):
		return false
	if not run._boss_spawned is bool or not run._boss_defeated is bool or (run._boss_defeated and not run._boss_spawned):
		return false
	var rules: Dictionary = state.stage_catalog.for_run(run.stage,run.run_mode)
	if rules.is_empty() or (run.phase == 6 and ((run.run_mode=="campaign" and not run._boss_defeated) or run.elapsed + 0.000001 < rules.duration)):
		return false
	if not finite_number(run._scatter_clock, 0, 1000) or not run._scatter_index is int or run._scatter_index < 0 or run._scatter_index > ceili(float(rules.duration) / float(rules.scatter.interval)):
		return false
	if run._boss_spawned and run.elapsed + 0.000001 < float(rules.boss_at):
		return false
	var due := 0
	for moment in rules.checkpoints:
		if run.elapsed + 0.000001 >= float(moment):
			due += 1
	if run.checkpoint_index > due:
		return false
	if not growth.get("character_id") is String or not growth.get("owned") is Dictionary or not growth.get("offer") is Array:
		return false
	if growth.get("ruleset") not in ["legacy", "weapons_v1"] or (growth.ruleset=="legacy" and run.armor_enabled):
		return false
	var pool: Array[Dictionary] = state.growth.catalog.pool_for(growth.character_id,growth.ruleset)
	if not state.growth.catalog.validate_pool(pool, growth.character_id):
		return false
	for key in ["level", "pending", "ticket", "revision"]:
		if not growth.get(key) is int or not finite_number(growth[key], 0, 1000000):
			return false
	if growth.level < 1 or growth.pending >= growth.level or not finite_number(growth.get("xp"), 0, state.growth.threshold_for(growth.level,run.run_mode,growth.pacing_version)):
		return false
	if growth.xp >= state.growth.threshold_for(growth.level,run.run_mode,growth.pacing_version):
		return false
	var definitions: Dictionary = {}
	for entry in pool:
		definitions[entry.id] = entry
	var rows := {"attack": 0, "passive": 0, "ultimate": 0}
	var upgrades := 0
	for id in growth.owned:
		var rank: Variant = growth.owned[id]
		if not definitions.has(id) or not rank is int or rank < 1 or rank > int(definitions[id].max_level):
			return false
		rows[definitions[id].row] += 1
		upgrades += rank
	if rows.attack > 4 or rows.passive > 4 or rows.ultimate > 1 or upgrades + growth.pending > growth.level + run._chest_bonus_ranks:
		return false
	var eligible: Array = []
	for entry in pool:
		var rank: int = growth.owned.get(entry.id, 0)
		if rank == int(entry.max_level):
			continue
		if rank == 0 and entry.row in ["attack", "passive"] and rows[entry.row] >= 4:
			continue
		eligible.append(entry.id)
	var seen: Dictionary = {}
	for id in growth.offer:
		if not id is String or not eligible.has(id) or seen.has(id):
			return false
		seen[id] = true
	var choosing: bool = run.phase == 4 or (run.phase == 2 and run._resume_phase == 4)
	if choosing != (growth.pending > 0) or growth.offer.size() != (mini(3, eligible.size()) if choosing else 0):
		return false
	var maximum_hp: int = state.AccountTalents.maximum_hp((int(state.profiles.hero(growth.character_id).hp) if run.combat_profile_version==1 else 100) + 20 * int(growth.owned.get("passive_vitality", 0)), run.account_talent_levels)
	if run.hp > maximum_hp or run.get("end_reason") not in ["", "defeat", "timeout", "abandoned", "cleared"]:
		return false
	if (run.phase in [1, 2, 4] and run.end_reason != "") or (run.phase == 3 and run.end_reason not in ["defeat", "timeout"]) or (run.phase == 5 and run.end_reason != "abandoned") or (run.phase == 6 and run.end_reason != "cleared"):
		return false
	if (run.end_reason == "defeat") != (run.hp == 0) or (run.end_reason == "timeout" and run.elapsed + 0.000001 < rules.duration):
		return false
	var account: Dictionary = state.AccountTalents.bonuses(run.account_talent_levels)
	if not finite_number(run._slow_left, 0, state.RANGED_SLOW_DURATION * (1.0 - float(account.status_resist)) + 0.000000001) or not finite_number(run._kill_heal_clock, 0, 1) or not finite_number(run._kill_heal_used, 0, float(account.kill_heal) * 6.0 + 0.000000001):
		return false
	var selected_hero: Dictionary = state.growth.catalog.hero(growth.character_id,growth.ruleset)
	if selected_hero.is_empty():
		return false
	var config: Dictionary = state.magic_configuration(selected_hero,run.combat_profile_version,growth.character_id)
	if not finite_number(magic.get("mana"), 0, float(config.max_mana) + float(account.max_mana)) or not finite_number(magic.get("cooldown_left"), 0, config.cooldown):
		return false
	for key in ["casts", "ticket"]:
		if not magic.get(key) is int or not finite_number(magic[key], 0, 1000000000):
			return false
	if not data.get("rng") is Array or data.rng.size() != 7:
		return false
	for generator in data.rng:
		if not generator is Dictionary or not generator.get("seed") is int or not generator.get("state") is int:
			return false
	if not run.skill_clocks is Dictionary or run.skill_clocks.size() > 18:
		return false
	for id in run.skill_clocks:
		if not definitions.has(id) or not finite_number(run.skill_clocks[id], 0, 60):
			return false
	return valid_supplies(run, state, space) and valid_weapons(run,growth,state) and valid_actors(run, state)

static func valid_supplies(run: Dictionary, state, space) -> bool:
	if not run.structures is Array or not run.item_pickups is Array or not run._loot_serial is int or run._loot_serial < 0:
		return false
	var expected: Array[Dictionary] = state.supply_catalog.create(run.map_id, space)
	if run.structures.size() != expected.size() and not run.structures.is_empty():
		return false
	var sources := {}
	var destructions := 0
	var max_generation := 1 + floori((float(run.elapsed) + 0.000001) / state.SupplyCatalog.RESPAWN_SECONDS)
	for index in range(run.structures.size()):
		var actor: Variant = run.structures[index]
		var definition: Dictionary = expected[index]
		if not actor is Dictionary or actor.get("id") != definition.id or not actor.get("id") is int or actor.get("p") != definition.p or actor.get("style") != definition.style or actor.get("max_hp") != definition.max_hp or not actor.get("max_hp") is int:
			return false
		if not actor.get("hp") is int or actor.hp < 0 or actor.hp > definition.max_hp or not actor.get("generation") is int or actor.generation < 0 or actor.generation > max_generation or not finite_number(actor.get("respawn_left"), 0, state.SupplyCatalog.RESPAWN_SECONDS):
			return false
		if (actor.hp > 0 and actor.respawn_left != 0.0) or (actor.hp == 0 and (actor.respawn_left <= 0.0 or actor.generation == 0)):
			return false
		sources[actor.id] = actor.generation
		destructions += int(actor.generation)
	if run.item_pickups.size() > run._loot_serial or run._loot_serial > destructions:
		return false
	var ids := {}
	var generations := {}
	for item in run.item_pickups:
		if not item is Dictionary or not item.get("id") is int or item.id < 1 or item.id > run._loot_serial or ids.has(item.id) or not item.get("source") is int or not sources.has(item.source) or not item.get("generation") is int or item.generation < 1 or item.generation > sources[item.source] or item.get("kind") not in state.SupplyCatalog.ITEM_KINDS or not vector(item.get("p")) or not Rect2(Vector2.ZERO, space.world_size).has_point(item.p):
			return false
		var key := Vector2i(item.source,item.generation)
		if generations.has(key):
			return false
		ids[item.id] = true
		generations[key] = true
	return true

static func valid_weapons(run: Dictionary, growth: Dictionary, state) -> bool:
	var library = state.growth.catalog.weapons
	if not run.get("bullets") is Array or not run.get("enemies") is Array:
		return false
	if not run.weapon_events is Array or run.weapon_events.size() > state.WeaponModules.MAX_EVENTS or (growth.ruleset == "legacy" and not run.weapon_events.is_empty()):
		return false
	var allowed := {}
	for entry in state.growth.catalog.pool_for(growth.character_id,growth.ruleset):
		allowed[entry.id] = true
	for event in run.weapon_events:
		if not event is Dictionary or not vector(event.get("p")) or not vector(event.get("direction")) or not finite_number(event.get("left"),0,60) or not event.get("remaining") is int or event.remaining < 1 or event.remaining > 32 or not event.get("index") is int or event.index < 0 or event.index > 32 or not valid_weapon_profile(event.get("profile"),library,allowed):
			return false
	for bullet in run.bullets:
		if bullet is Dictionary and bullet.has("weapon"):
			if growth.ruleset != "weapons_v1" or not valid_weapon_profile(bullet.weapon,library,allowed) or not finite_number(bullet.get("age"),0,60) or not bullet.get("returning") is bool or bullet.get("source") != bullet.weapon.id:
				return false
	for enemy in run.enemies:
		if enemy is Dictionary and enemy.has("weapon_status"):
			var status: Variant = enemy.weapon_status
			if growth.ruleset != "weapons_v1" or not status is Dictionary or not finite_number(status.get("mark"),0,30) or not finite_number(status.get("slow"),0,0.8) or not finite_number(status.get("slow_left"),0,30) or (status.slow_left == 0 and status.slow != 0):
				return false
	return true

static func valid_weapon_profile(p: Variant, library, allowed: Dictionary) -> bool:
	if not library.valid_parameters(p) or not p.get("id") is String or not allowed.has(p.id) or not library.entries.has(p.id) or not p.get("rank") is int or p.rank < 1 or p.rank > 5 or p.get("evolved") != (p.rank==5) or p.get("family") != library.entries[p.id].family or p.get("mode") not in library.MODES:
		return false
	return true

static func valid_actors(run: Dictionary, state) -> bool:
	var rules: Dictionary = state.stage_catalog.for_run(run.stage,run.run_mode)
	var space = state.MapSpace.new(state.map_catalog.definition(run.map_id))
	var swarm: Dictionary = rules.swarm
	# Bounded by encounter interval/lifetime, with room for every legacy live flier.
	# This validates disk input only; live formations never wait for actor capacity.
	var flying_cap: int = (ceili(float(swarm.life) / float(swarm.interval)) + 1) * state.SWARM_SIZE + state.MAX_ENEMIES
	flying_cap += (ceili(float(swarm.life) / float(rules.scatter.interval)) + 1) * state.SWARM_SIZE
	var scatter_cap: int = ceili(float(rules.duration) / float(rules.scatter.interval)) * state.SWARM_SIZE
	var population_limit:int=state.encounters.population_limit(run.encounter_version,float(run.elapsed))
	var caps := {"enemies": population_limit + flying_cap + scatter_cap, "bullets": state.MAX_BULLETS, "pickups": state.MAX_PICKUPS, "gold_pickups": state.MAX_PICKUPS, "enemy_bullets": state.MAX_ENEMY_BULLETS}
	if run.run_mode=="gold_slime":caps.enemies=int(state.dungeon.data.max_enemies)
	for key in caps:
		if not run[key] is Array or run[key].size() > caps[key]:
			return false
		for item in run[key]:
			if not item is Dictionary or not vector(item.get("p")):
				return false
	var ids: Dictionary = {}
	var boss_count := 0
	var flying_count := 0
	var ground_count := 0
	var groups := {}
	for enemy in run.enemies:
		if not state.enemy_patterns.valid_actor(run,enemy):return false
		if not enemy.get("id") is int or enemy.id <= 0 or enemy.id > run._enemy_serial or ids.has(enemy.id):
			return false
		ids[enemy.id] = true
		if enemy.get("kind") not in ["normal", "elite", "boss"]:
			return false
		if not enemy.get("hp") is int or not enemy.get("max_hp") is int or enemy.hp < 1 or enemy.hp > enemy.max_hp or enemy.max_hp > 2000000:
			return false
		if not finite_number(enemy.get("speed"), 1, 1000):
			return false
		if enemy.get("variant") not in ["normal", "ranged", "fast", "heavy", "flier"]:
			return false
		if run.map_id != "legacy_arena" and enemy.variant != "flier" and not space.valid_position(enemy.p,24.0):
			return false
		if run.combat_profile_version==1:
			if not enemy.get("species") is String or not enemy.get("spawn_wave") is int:
				return false
			var definition: Dictionary=state.dungeon.species(rules.waves[0]) if run.run_mode=="gold_slime" and enemy.species=="gold_slime" else state.profiles.species(enemy.species)
			if (run.run_mode=="gold_slime" and enemy.species!="gold_slime") or (run.run_mode=="campaign" and enemy.species=="gold_slime") or definition.is_empty() or definition.kind!=enemy.kind or definition.variant!=enemy.variant or not enemy.get("contact_damage") is int or enemy.contact_damage!=int(definition.contact_damage):
				return false
			if enemy.kind=="normal":
				if enemy.spawn_wave<0 or enemy.spawn_wave>=rules.waves.size():return false
				var expected: Dictionary=state.dungeon.species(rules.waves[enemy.spawn_wave]) if run.run_mode=="gold_slime" else state.profiles.scaled(enemy.species,rules.waves[enemy.spawn_wave],rules)
				if enemy.max_hp!=int(expected.hp) or enemy.speed!=float(expected.speed):return false
			elif enemy.spawn_wave!=-1 or enemy.speed!=float(definition.speed) or (enemy.kind=="boss" and enemy.max_hp!=int(rules.boss_hp)) or (enemy.kind=="elite" and not rules.elite_hp.any(func(value):return int(value)==enemy.max_hp)):
				return false
		elif enemy.has("species") or enemy.has("contact_damage") or enemy.has("spawn_wave"):
			return false
		if enemy.kind != "normal" and enemy.variant != "normal":
			return false
		if not enemy.get("scatter_group") is int or enemy.scatter_group < 0 or enemy.scatter_group > run._scatter_index:
			return false
		if enemy.scatter_group > 0:
			if enemy.kind != "normal" or enemy.variant != ("normal" if run.run_mode=="gold_slime" else state.SCATTER_VARIANTS[(enemy.scatter_group - 1) % state.SCATTER_VARIANTS.size()]):
				return false
			groups[enemy.scatter_group] = int(groups.get(enemy.scatter_group, 0)) + 1
			if groups[enemy.scatter_group] > state.SWARM_SIZE:
				return false
		elif enemy.variant != "flier":
			ground_count += 1
		if enemy.variant == "ranged":
			if not vector(enemy.get("aim")) or not finite_number(enemy.get("fire_clock"), 0, 1000) or not finite_number(enemy.get("windup"), 0, 1000):
				return false
		elif enemy.variant == "flier":
			flying_count += 1
			if not vector(enemy.get("velocity")) or not finite_number(enemy.get("life"), 0.000001, 1000):
				return false
			if not enemy.get("group") is int or enemy.group < 0 or enemy.group > run._swarm_serial:
				return false
		if enemy.kind == "boss":
			boss_count += 1
	if flying_count > flying_cap or ground_count > population_limit:
		return false
	if boss_count > 1 or (run._boss_spawned and not run._boss_defeated and boss_count != 1) or (run._boss_defeated and boss_count != 0):
		return false
	for bullet in run.bullets:
		if not vector(bullet.get("direction")) or not bullet.get("seen") is Dictionary or bullet.seen.size() > run._enemy_serial + run.structures.size():
			return false
		for key in ["life", "speed", "damage", "remaining"]:
			if not finite_number(bullet.get(key), 0, 1000000):
				return false
		for id in bullet.seen:
			if not id is int or id in [-1, 0] or id > run._enemy_serial or id < -run.structures.size() - 1 or bullet.seen[id] != true:
				return false
	for pickup in run.pickups:
		if not finite_number(pickup.get("value"), 0.000001, 1000000000):
			return false
	for pickup in run.gold_pickups:
		if not pickup.get("value") is int or pickup.value < 1 or pickup.value > 1000000000:
			return false
	for bullet in run.enemy_bullets:
		if bullet.get("shot","")=="curse":
			if not state.enemy_patterns.valid_curse(run,bullet):return false
			continue
		if run.combat_profile_version==1:
			var source: Dictionary=state.profiles.species(str(bullet.get("species","")))
			if source.is_empty() or source.variant!="ranged" or bullet.get("shot")!=source.shot:
				return false
		if not vector(bullet.get("velocity")) or not finite_number(bullet.get("life"), 0.000001, 1000):
			return false
		if not bullet.get("damage") is int or bullet.damage < 1 or bullet.damage > 1000:
			return false
	return true

static func restore(data: Dictionary, state) -> bool:
	data = upgrade_legacy(data, state)
	if not valid(data, state):
		return false
	data = data.duplicate(true)
	var previous_navigation: int = state.navigation_ticket
	var previous_growth: int = state.growth.ticket
	var previous_magic: int = state.magic.ticket
	for key in RUN_FIELDS:
		if state.get(key) is Array:
			state.get(key).assign(data.run[key].duplicate(true))
		else:
			state.set(key, data.run[key])
	for key in GROWTH_FIELDS:
		if state.growth.get(key) is Array:
			state.growth.get(key).assign(data.growth[key].duplicate(true))
		else:
			state.growth.set(key, data.growth[key])
	state.growth.pacing_mode=state.run_mode
	state.growth.pool = state.growth.catalog.pool_for(state.growth.character_id,state.growth.ruleset)
	state.magic.reset(state.magic_configuration(state.growth.catalog.hero(state.growth.character_id,state.growth.ruleset),state.combat_profile_version,state.growth.character_id), state.growth.character_id)
	for key in MAGIC_FIELDS:
		state.magic.set(key, data.magic[key])
	var generators := [state.rng, state.growth.rng, state.gold_rng, state.encounter_rng, state.scatter_rng, state.loot_rng, state.species_rng]
	for index in range(generators.size()):
		generators[index].seed = data.rng[index].seed
		generators[index].state = data.rng[index].state
	state.map_space = state.MapSpace.new(state.map_catalog.definition(state.map_id))
	state.world_size = state.map_space.world_size
	state.stage_rules = state.stage_catalog.for_run(state.stage,state.run_mode)
	state.stage_duration = float(state.stage_rules.duration)
	state.stage_clear_gold = int(state.stage_rules.clear_gold)
	state._refresh_stats()
	state.transition_action = ""
	state.navigation_ticket = maxi(previous_navigation, state.navigation_ticket) + 1
	state.growth.ticket = maxi(previous_growth, state.growth.ticket) + 1
	state.growth.revision += 1
	state.magic.ticket = maxi(previous_magic, state.magic.ticket) + 1
	state.effects.clear()
	state.cues.reset()
	state.feedback.reset()
	state._finished_result.clear()
	if state.phase in [1, 2, 4]:
		state._resume_phase = 4 if state.growth.pending > 0 else 1
		state.phase = 2 # Always require an explicit Continue after process recovery.
	else:
		state.feedback.finish()
		state._finished_result = state._summary(state.end_reason)
	return true
