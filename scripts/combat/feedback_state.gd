extends RefCounted
## Presentation state only; never changes damage, XP, MP, or input ownership.
## Provisional display timing. Only RunState advances the simulation clock.
const LOW_HP_RATIO := 0.30
const ORDER := ["hurt", "magic", "levelup"]
const DURATIONS := {"hurt": 0.55, "magic": 0.90, "levelup": 1.20}
const PRESENTATION := {
	"normal": {"label": "전투 집중", "detail": "기본 상태", "accent": "b69a65"},
	"hurt": {"label": "피격 · 고통", "detail": "피해를 입었습니다", "accent": "ec7b87"},
	"magic": {"label": "마법 · 결의", "detail": "고유 마법 발동", "accent": "dba3ec"},
	"levelup": {"label": "성장 · 기쁨", "detail": "레벨업 반응", "accent": "7cd3b2"},
	"low_hp": {"label": "저체력 · 지침", "detail": "체력 회복 필요", "accent": "e4ad66"},
	"defeat": {"label": "전투 종료", "detail": "다시 출격 가능", "accent": "9d98a5"}
}
var clocks: Dictionary = {"hurt": 0.0, "magic": 0.0, "levelup": 0.0}
var defeated: bool = false
var _last_level_ticket: int = -1

func reset() -> void:
	for key in ORDER:
		clocks[key] = 0.0
	defeated = false
	_last_level_ticket = -1

func trigger(kind: String) -> bool:
	if defeated or not DURATIONS.has(kind):
		return false
	# At most one pending event per kind: no unbounded expression queue.
	clocks[kind] = float(DURATIONS[kind])
	return true

func level_up(offer_ticket: int) -> bool:
	if defeated or offer_ticket <= _last_level_ticket:
		return false
	_last_level_ticket = offer_ticket
	return trigger("levelup")

func finish() -> void:
	defeated = true
	for key in ORDER:
		clocks[key] = 0.0

func advance(delta: float, running: bool) -> void:
	if not running or defeated or delta <= 0.0 or not is_finite(delta):
		return
	# Only the currently visible reaction spends its time. A higher priority
	# event temporarily covers lower ones rather than silently eating them.
	var budget: float = delta
	for key in ORDER:
		var left: float = float(clocks[key])
		if left <= 0.0:
			continue
		var consumed: float = minf(left, budget)
		clocks[key] = maxf(0.0, left - consumed)
		if float(clocks[key]) < 0.000001:
			clocks[key] = 0.0
		budget = maxf(0.0, budget - consumed)
		if budget <= 0.0:
			return

func is_low(hp: int, maximum: int) -> bool:
	return hp > 0 and maximum > 0 and float(hp) / float(maximum) <= LOW_HP_RATIO

func current(hp: int, maximum: int) -> String:
	if defeated or hp <= 0:
		return "defeat"
	for key in ORDER:
		if float(clocks[key]) > 0.0:
			return str(key)
	return "low_hp" if is_low(hp, maximum) else "normal"

func snapshot(hp: int, maximum: int) -> Dictionary:
	var key: String = current(hp, maximum)
	var result: Dictionary = PRESENTATION[key].duplicate(true)
	result["key"] = key
	result["low_hp"] = is_low(hp, maximum)
	result["remaining"] = float(clocks.get(key, 0.0))
	return result
