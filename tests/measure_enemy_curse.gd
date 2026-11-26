extends "res://tests/measure_balance.gd"
## Same original evolve choices/movement; no telegraph-aware bot or HP/MP gifts.
func _initialize() -> void:
	var rows:Array=[]
	for map_id in ["prologue_wall","outskirts_trial"]:
		map_name=map_id
		for talents in ["none","full"]:
			profile_name=talents
			account_levels=Talents.empty_levels()
			if talents=="full":
				for id in Talents.IDS:account_levels[id]=3
			for version in [3]:
				pattern_override=version
				for seed_value in [7,42,143,407,2026]:
					var row:Dictionary=measure_balanced(seed_value)
					row.map_id=map_id
					row.talents=talents
					rows.append(row)
	print(JSON.stringify({"scope":"20complete curse-v3 runs,5seeds per map/talent,unchanged original evolve controller/spawn geometry;not device or final balance approval","runs":rows}))
	quit(0)
