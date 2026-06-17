class_name LedgerData
extends RefCounted

var day: int = 0
var gold_today: int = 0
var rep_today: int = 0
var gold_total: int = 0
var rep_total: int = 0
var guests_served: int = 0
var orders_success: int = 0
var orders_failed: int = 0
var guest_entries: Array[Dictionary] = []
var rumor_summary: Dictionary = {}
var npc_fates: Array[Dictionary] = []
var fate_warning_next_day: bool = false
