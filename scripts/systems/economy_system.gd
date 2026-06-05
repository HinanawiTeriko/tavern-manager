class_name EconomySystem
extends RefCounted

signal changed(gold: int, reputation: int, level: int)

var gold: int = 0
var reputation: int = 0
var tavern_level: int = 1
var current_day: int = 1
var gold_today: int = 0
var rep_today: int = 0

const MAX_DAYS: int = 30
const MAX_REP_THRESHOLD: int = 0x7FFFFFFF
const _level_rep_thresholds: Array = [0, 50, 150]
const QUALITY_GOLD_MULT := {"good": 1.5, "normal": 1.0, "poor": 0.5}
const QUALITY_REP := {"good": 3, "normal": 2, "poor": 0}

func get_level_rep_threshold() -> int:
	if tavern_level < _level_rep_thresholds.size():
		return _level_rep_thresholds[tavern_level]
	return MAX_REP_THRESHOLD

func add_gold(amount: int) -> void:
	gold += amount
	gold_today += amount
	changed.emit(gold, reputation, tavern_level)

func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	changed.emit(gold, reputation, tavern_level)
	return true

func add_reputation(amount: int) -> void:
	reputation += amount
	rep_today += amount
	_check_level_up()
	changed.emit(gold, reputation, tavern_level)

func reset_daily() -> void:
	gold_today = 0
	rep_today = 0

func _check_level_up() -> void:
	if tavern_level < _level_rep_thresholds.size() and reputation >= _level_rep_thresholds[tavern_level]:
		tavern_level += 1
		print("[Economy] 酒馆升级到 Lv.", tavern_level)

func is_last_day() -> bool:
	return current_day >= MAX_DAYS

## 按成品品质算上菜金币：good ×1.5 / normal ×1 / poor ×0.5，未知回退 ×1。
func gold_for_quality(price: int, quality: String) -> int:
	var mult: float = float(QUALITY_GOLD_MULT.get(quality, 1.0))
	return floori(price * mult)

## 按成品品质算声望增量：good +3 / normal +2 / poor +0，未知回退 +2。
func reputation_for_quality(quality: String) -> int:
	return int(QUALITY_REP.get(quality, 2))
