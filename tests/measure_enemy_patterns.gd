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
			for version in [0,1]:
				pattern_override=version
				for seed_value in [7,407]:
					var row:Dictionary=measure_balanced(seed_value)
					row.map_id=map_id
					row.talents=talents
					rows.append(row)
	var identical:bool=true
	for talents in ["none","full"]:
		for seed_value in [7,407]:
			var pair:Array=rows.filter(func(x):return x.map_id=="outskirts_trial" and x.talents==talents and x.seed==seed_value)
			var a:Dictionary=pair[0].duplicate(true)
			var b:Dictionary=pair[1].duplicate(true)
			a.erase("enemy_pattern_version")
			b.erase("enemy_pattern_version")
			identical=identical and a==b
	print(JSON.stringify({"scope":"16complete real simulation runs,two seeds7/407 per map/talent/version,unchanged original evolve controller and spawn geometry;not human/device or final balance approval","unaffected_outskirts_equal":identical,"runs":rows}))
	quit(0 if identical else 1)
