class_name RyanSliceSystem
extends RefCounted

# [走查脚手架] 伊芙琳灰账线结算在 Day20；正式 30 天循环接入前，切片先推进到 Day20。
const LAST_DAY := 20
const DEFAULT_NORMAL_ORDER_LIMIT := 3
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
	5: {
		"events": [{"type": "important_npc", "npc_id": "evelyn", "display_name": "伊芙琳", "portrait_id": "grey_ledger_lady"}],
	},
	6: {
		"events": [{"type": "important_npc", "npc_id": "toby", "display_name": "瘦小少年"}],
	},
	8: {
		"events": [{"type": "important_npc", "npc_id": "evelyn", "display_name": "伊芙琳", "portrait_id": "grey_ledger_lady"}],
	},
	13: {
		"events": [{"type": "important_npc", "npc_id": "evelyn", "display_name": "伊芙琳", "portrait_id": "grey_ledger_lady"}],
		"ledger_entries": ["第二十日。伊芙琳。\n灰账清算。\n封存。"],
	},
	20: {
		"events": [{"type": "important_npc", "npc_id": "evelyn", "display_name": "伊芙琳", "portrait_id": "grey_ledger_lady"}],
	},
}

var total_orders_success: int = 0
var _completed_days: Array[int] = []


func last_day() -> int:
	return LAST_DAY


func normal_order_limit(day: int) -> int:
	if DAY_CONFIG.has(day):
		return int(DAY_CONFIG[day].get("normal_order_limit", DEFAULT_NORMAL_ORDER_LIMIT))
	return DEFAULT_NORMAL_ORDER_LIMIT


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
