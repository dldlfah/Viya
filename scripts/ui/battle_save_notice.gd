extends RefCounted
## Confirmed persistence presentation only. Never owns or restores a RunState.
const NOTICE_SECONDS := 3.0
var run_id:String=""
var checkpoint:int=0
var until:float=-1
var sequence:int=0 # QA observation counter,not saved or used for rewards.

static func resumable(data:Dictionary) -> bool:
	return data.get("run") is Dictionary and data.run.get("phase",-1) in [1,2,4]

func reset(id:String="",saved_checkpoint:int=0) -> void:
	run_id=id
	checkpoint=saved_checkpoint
	until=-1

func seed(data:Dictionary,error:Error) -> void:
	if error==OK and resumable(data):reset(str(data.run.run_id),int(data.run.checkpoint_index))
	else:reset()

func confirmed(data:Dictionary,error:Error,state,announce:bool) -> void:
	if error!=OK:
		until=-1
		return
	if not resumable(data) or str(data.run.run_id)!=state.run_id:return
	if run_id!=state.run_id:reset(state.run_id)
	var next:int=data.run.checkpoint_index
	if next>checkpoint and announce:
		sequence+=1
		until=state.elapsed+NOTICE_SECONDS
	checkpoint=next

func count_for(id:String) -> int:
	return checkpoint if id==run_id else 0

func visible(state,error:Error) -> bool:
	return error==OK and state.phase==state.Phase.RUNNING and state.run_id==run_id and state.elapsed<until

static func summary(data:Dictionary,catalog) -> String:
	if not resumable(data) or not data.get("growth") is Dictionary or not data.get("magic") is Dictionary:return ""
	var run:Dictionary=data.run
	var dungeon:bool=run.get("run_mode","campaign")=="gold_slime"
	var map:Dictionary=catalog.definition(str(run.get("map_id","legacy_arena")))
	var name:String=str(map.get("name",run.get("map_id","전장 정보 없음")))
	var seconds:int=maxi(0,int(floor(float(run.elapsed))))
	var text:String="저장된 전투 · %s\n%s\n진행 %02d:%02d · 체크포인트 %d/2 · Lv.%d\nHP %d · MP %.1f · 획득 금화 %d" % [
		"골드 던전" if dungeon else "캠페인 S%d" % int(run.stage),name,int(seconds / 60.0),seconds%60,int(run.checkpoint_index),int(data.growth.level),int(run.hp),float(data.magic.mana),int(run.gold_collected)]
	if int(data.growth.get("pending",0))>0:text+="\n남은 성장 선택 %d회 · 같은 선택을 이어갑니다" % int(data.growth.pending)
	if dungeon:text+="\n이어하기는 추가 입장 횟수를 사용하지 않습니다"
	return text
