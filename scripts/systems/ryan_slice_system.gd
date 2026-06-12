class_name RyanSliceSystem
extends RefCounted

# [走查脚手架] Mira 线高潮在 Day12，需游戏推进到 Day12 才能走查四结局。
# 原值为 3（Ryan 切片收尾日）。合入 main 前须决策：正式接 30 天循环，还是回退为 3。
const LAST_DAY := 12
const DAY_CONFIG := {
	1: {
		"normal_order_limit": 2,
		"events": [{"type": "important_npc", "npc_id": "ryan", "display_name": "莱恩"}],
	},
	2: {
		"normal_order_limit": 2,
		"events": [{"type": "important_npc", "npc_id": "ryan", "display_name": "莱恩"}],
		"ledger_entries": ["第三日。莱恩。\n北矿道。\n未归。"],
	},
	3: {
		"normal_order_limit": 2,
		"events": [{"type": "fate_reveal", "npc_id": "ryan", "display_name": "佣兵甲", "portrait_id": "mercenary_a"}],
	},
}

var total_orders_success: int = 0
var _completed_days: Array[int] = []


func last_day() -> int:
	return LAST_DAY


func normal_order_limit(day: int) -> int:
	return int(DAY_CONFIG.get(day, {}).get("normal_order_limit", 0))


func night_events(day: int) -> Array:
	return DAY_CONFIG.get(day, {}).get("events", []).duplicate(true)


func day_start_ledger_entries(day: int) -> Array:
	return DAY_CONFIG.get(day, {}).get("ledger_entries", []).duplicate()


func important_display_name(day: int, npc_id: String, fallback: String) -> String:
	for event in night_events(day):
		if String(event.get("npc_id", "")) == npc_id:
			return String(event.get("display_name", fallback))
	return fallback


func important_portrait_id(day: int, npc_id: String, fallback: String) -> String:
	for event in night_events(day):
		if String(event.get("npc_id", "")) == npc_id:
			return String(event.get("portrait_id", fallback))
	return fallback


func should_finish_after_day(day: int) -> bool:
	return day >= LAST_DAY


func record_order_success() -> void:
	total_orders_success += 1


func complete_day(day: int) -> void:
	if not _completed_days.has(day):
		_completed_days.append(day)
		_completed_days.sort()


func is_day_complete(day: int) -> bool:
	return _completed_days.has(day)


func capture_state() -> Dictionary:
	return {
		"total_orders_success": total_orders_success,
		"completed_days": _completed_days.duplicate(),
	}


func restore_state(data: Dictionary) -> void:
	total_orders_success = int(data.get("total_orders_success", 0))
	_completed_days.clear()
	for day in data.get("completed_days", []):
		_completed_days.append(int(day))
	_completed_days.sort()
