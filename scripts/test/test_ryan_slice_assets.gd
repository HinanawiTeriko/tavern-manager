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
		"res://assets/textures/workspace/barrel.png",
		"res://assets/textures/workspace/pot.png",
		"res://assets/textures/workspace/grill.png",
		"res://assets/textures/workspace/spoon.png",
	]:
		_ok(FileAccess.file_exists(path), "asset exists: " + path)

	var gm = get_node("/root/GameManager")
	for key in [
		"ale", "flour", "meat_raw", "herb", "ale_beer", "bread", "meat_cooked",
		"herb_broth", "sleep_powder", "bloodied_contract", "alternative_contract",
	]:
		_ok(gm.try_load_material_icon(key) != null, "mapped icon loads: " + key)
	_test_workspace_prop_art()
	_finish()


func _test_workspace_prop_art() -> void:
	var tavern := preload("res://scenes/ui/Tavern.tscn").instantiate()
	for path in [
		"BarWorkspace/World/Brewery/Art",
		"BarWorkspace/World/Grill/Art",
		"BarWorkspace/World/Pot/Art",
		"BarWorkspace/World/Spoon/Art",
	]:
		var art := tavern.get_node_or_null(path) as Sprite2D
		_ok(art != null and art.texture != null, "workspace prop art is attached: " + path)
	for path in [
		"BarWorkspace/World/Brewery/Visual",
		"BarWorkspace/World/Brewery/MouthRim",
		"BarWorkspace/World/Grill/Visual",
		"BarWorkspace/World/Grill/HeatBars",
		"BarWorkspace/World/Pot/Visual",
		"BarWorkspace/World/Pot/Soup",
		"BarWorkspace/World/Spoon/Visual",
	]:
		_ok(not tavern.get_node(path).visible, "placeholder visual is hidden: " + path)
	tavern.free()


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
