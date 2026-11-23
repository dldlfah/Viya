extends RefCounted
## Formats existing durable result/account records. Never saves or settles a reward.
const Phase=preload("res://scripts/combat/run_state.gd").Phase
static func durable(summary:Dictionary,pending:Dictionary) -> bool:
	var saved:Variant=pending.get("run")
	if not saved is Dictionary:return false
	return saved.get("run_id")==summary.get("run_id") and not str(summary.get("run_id","")).is_empty() \
		and saved.get("phase")=={"cleared":Phase.CLEARED,"defeat":Phase.DEFEAT,"timeout":Phase.DEFEAT,"abandoned":Phase.ABANDONED}.get(summary.get("outcome"),-1) \
		and saved.get("end_reason")==summary.get("outcome") and saved.get("run_mode","campaign")==summary.get("run_mode","campaign") \
		and saved.get("stage")==summary.get("stage") and saved.get("gold_collected")==summary.get("gold_collected")

static func recorded(summary:Dictionary,wallet) -> bool:
	if not wallet.loaded or str(summary.get("run_id","")).is_empty():return false
	if summary.get("run_mode","campaign")=="gold_slime":
		return wallet.dungeon.closed_id==summary.run_id and wallet.dungeon.closed_outcome==summary.outcome and wallet.dungeon.closed_reward==summary.gold_reward
	return summary.get("outcome")=="cleared" and wallet.last_run==summary.run_id and wallet.next_stage==int(summary.stage)+1

static func describe(summary:Dictionary,pending:Dictionary,wallet,battle_error:Error,gold_error:Error) -> Dictionary:
	if not summary.get("ended",false) or summary.get("outcome") not in ["cleared","defeat","timeout","abandoned"] or summary.get("run_mode","campaign") not in ["campaign","gold_slime"]:return {}
	var dungeon:bool=summary.get("run_mode","campaign")=="gold_slime"
	var saved:bool=battle_error==OK and durable(summary,pending)
	var credited:bool=recorded(summary,wallet)
	var paid:bool=saved and credited and gold_error==OK
	var status:String
	var state:String
	var note:String=""
	if summary.outcome=="cleared":
		if paid:
			state="paid"
			status="지급 완료 · %d 금화" % int(summary.gold_reward)
		elif credited:
			state="recorded"
			status="지급 기록 있음 · 저장 확인 필요"
		else:
			state="pending"
			status="지급 대기 · 예정 %d 금화" % int(summary.gold_reward)
		if not saved:note="전투 결과 저장 확인 필요"
		elif gold_error!=OK or not credited:note="금화 저장 확인 필요"
	else:
		state="unpaid"
		status="보상 미지급 · 0 금화"
		if dungeon:note="던전 종료 기록 저장 완료" if paid else "던전 종료 기록 저장 대기"
		elif not saved:note="전투 결과 저장 대기"
	var balance:String="잔액 확인 불가"
	if wallet.loaded:
		balance=("보유 금화 %d" if gold_error==OK else "마지막 확인 금화 %d") % int(wallet.total)
	var lines:PackedStringArray=["골드 슬라임 던전" if dungeon else "캠페인 S%d" % int(summary.stage),status]
	if summary.outcome=="cleared":
		lines.append("기본 보상 %d + 획득 금화 %d = %s %d 금화" % [int(summary.gold_bonus),int(summary.gold_collected),"정산 대상" if state=="pending" else "총",int(summary.gold_reward)])
	else:lines.append("획득 금화 %d · 클리어 보상 미지급" % int(summary.gold_collected))
	lines.append(balance)
	if not note.is_empty():lines.append(note)
	return {"state":state,"recorded":credited,"saved":saved,"text":"\n".join(lines)}
