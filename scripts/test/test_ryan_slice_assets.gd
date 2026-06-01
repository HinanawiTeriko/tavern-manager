extends Node

var _checks := 0
var _failures := 0


func _ready() -> void:
	for path in [
		"res://assets/textures/backgrounds/tavern_bg.png",
		"res://assets/textures/characters/ryan_neutral.png",
		"res://assets/textures/characters/ryan_excited.png",
		"res://assets/textures/characters/ryan_hesitant.png",
		"res://assets/textures/characters/ryan_dejected.png",
		"res://assets/textures/icons/items/sleep_powder.png",
		"res://assets/textures/icons/items/bloodied_contract.png",
		"res://assets/textures/icons/items/alternative_contract.png",
		"res://assets/textures/vfx/ingredient_drop.png",
		"res://assets/textures/vfx/product_ready.png",
		"res://assets/textures/vfx/serve_success.png",
		"res://assets/textures/vfx/new_document.png",
	]:
		_ok(FileAccess.file_exists(path), "asset exists: " + path)

	var gm = get_node("/root/GameManager")
	for key in [
		"ale", "flour", "meat_raw", "herb", "ale_beer", "bread", "meat_cooked",
		"herb_broth", "sleep_powder", "bloodied_contract", "alternative_contract",
	]:
		_ok(gm.try_load_material_icon(key) != null, "mapped icon loads: " + key)
	_finish()


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-RYAN-ASSETS] FAIL: " + msg)


func _finish() -> void:
	if _failures == 0:
		print("[TEST-RYAN-ASSETS] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-RYAN-ASSETS] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)
