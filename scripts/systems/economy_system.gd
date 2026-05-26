class_name EconomySystem
extends RefCounted

signal changed()

var gold: int = 0
var reputation: int = 0
var tavern_level: int = 1
var current_day: int = 1
var gold_today: int = 0
var rep_today: int = 0

const MAX_DAYS: int = 30
const _level_rep_thresholds: Array = [0, 50, 150]

func get_level_rep_threshold() -> int:
	if tavern_level < _level_rep_thresholds.size():
		return _level_rep_thresholds[tavern_level]
	return 0x7FFFFFFF

func add_gold(amount: int) -> void:
	gold += amount
	gold_today += amount
	changed.emit()

func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	changed.emit()
	return true

func add_reputation(amount: int) -> void:
	reputation += amount
	rep_today += amount
	_check_level_up()
	changed.emit()

func reset_daily() -> void:
	gold_today = 0
	rep_today = 0

func _check_level_up() -> void:
	if tavern_level < _level_rep_thresholds.size() and reputation >= _level_rep_thresholds[tavern_level]:
		tavern_level += 1
		print("[Economy] 酒馆升级到 Lv.", tavern_level)

func is_last_day() -> bool:
	return current_day >= MAX_DAYS
