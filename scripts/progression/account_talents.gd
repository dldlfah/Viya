extends RefCounted
## Shared by every character. These attack bonuses are provisional tuning.
const SCHEMA := 1
const ATTACK_COSTS := [1000, 50000, 1000000]
const ATTACK_BONUSES := [0.0, 0.05, 0.10, 0.15]

static func valid_level(value: Variant) -> bool:
	return value is int and value >= 0 and value < ATTACK_BONUSES.size()

static func power_multiplier(level: int) -> float:
	return 1.0 + float(ATTACK_BONUSES[level])

static func gold_text(value: int) -> String:
	var digits := str(value)
	var result := ""
	for index in range(digits.length()):
		if index > 0 and (digits.length() - index) % 3 == 0:
			result += ","
		result += digits[index]
	return result
