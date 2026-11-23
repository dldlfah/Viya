extends RefCounted
## Account bonuses only. No preview RunState, combat-stat formula or file writes.
const Talents=preload("res://scripts/progression/account_talents.gd")
const Saved=preload("res://scripts/ui/battle_save_notice.gd")
const CATEGORIES := {"attack":"공격","defense":"방어","recovery":"회복"}

static func unavailable() -> Dictionary:
	return {"available":false,"brief":"강화 정보를 확인할 수 없습니다. 기존 저장·불러오기 오류를 확인하세요.","detail":""}

static func for_levels(levels:Variant) -> Dictionary:
	if not Talents.valid_levels(levels):return unavailable()
	var brief:PackedStringArray=[]
	var detail:PackedStringArray=[]
	var sections:Array=[]
	var total:int=0
	for id in Talents.IDS:total+=int(levels[id])
	for category in CATEGORIES:
		var roots:Array=[]
		for chain in Talents.CHAINS[category]:roots.append(chain[0])
		var main:PackedStringArray=[]
		var entries:Array=[]
		for id in Talents.IDS:
			if Talents.DEFINITIONS[id].category!=category or int(levels[id])==0:continue
			var line:String="%s %s" % [Talents.DEFINITIONS[id].name,Talents.effect_text(id,int(levels[id]))]
			entries.append({"id":id,"level":int(levels[id]),"text":line})
			if id in roots:main.append(line)
		var extra:int=entries.size()-main.size()
		brief.append("%s · %s%s" % [CATEGORIES[category]," / ".join(main) if not main.is_empty() else "추가 강화 없음"," · 외 %d종" % extra if extra>0 else ""])
		detail.append(CATEGORIES[category]+"\n"+("\n".join(PackedStringArray(entries.map(func(entry):return entry.text))) if not entries.is_empty() else "추가 강화 없음"))
		sections.append({"category":category,"entries":entries})
	return {"available":true,"levels":levels.duplicate(true),"bonuses":Talents.bonuses(levels),"total":total,"sections":sections,
		"brief":"\n".join(brief),"detail":"\n\n".join(detail)+"\n\n계정 보너스만 표시합니다. 실제 공격·회복에는 기본 수치·전투 강화·효과 상한이 함께 적용됩니다. [임시] 수치는 조정 중입니다."}

static func for_account(wallet,error:Error) -> Dictionary:
	return for_levels(wallet.talent_levels) if wallet.loaded and error==OK else unavailable()

static func for_saved(pending:Dictionary,error:Error) -> Dictionary:
	return for_levels(pending.run.get("account_talent_levels")) if error==OK and Saved.resumable(pending) else unavailable()
