class_name CookStationState
extends RefCounted

enum Mode { GRILL, POT }

var _mode: int = Mode.GRILL
var _ingredients: Array[String] = []
var _elapsed: float = 0.0
var _cook_time: float = 1.0
var _burn_time: float = 2.0
var _stir_progress: float = 0.0
var _required_stir: float = 3.0


func configure_grill(cook_time: float, burn_time: float) -> void:
	_mode = Mode.GRILL
	_cook_time = maxf(cook_time, 0.0)
	_burn_time = maxf(burn_time, _cook_time)
	_elapsed = 0.0
	_stir_progress = 0.0


func configure_pot(required_stir: float) -> void:
	_mode = Mode.POT
	_required_stir = maxf(required_stir, 0.0)
	_elapsed = 0.0
	_stir_progress = 0.0


func add_item(item_key: String) -> void:
	if item_key != "":
		_ingredients.append(item_key)


func advance(delta: float) -> void:
	if _mode == Mode.GRILL and not _ingredients.is_empty():
		_elapsed += maxf(delta, 0.0)


func add_stir(amount: float) -> void:
	if _mode == Mode.POT and not _ingredients.is_empty():
		_stir_progress += maxf(amount, 0.0)


func is_ready() -> bool:
	if _ingredients.is_empty():
		return false
	if _mode == Mode.GRILL:
		return _elapsed >= _cook_time
	return _stir_progress >= _required_stir


func is_burnt() -> bool:
	return _mode == Mode.GRILL and not _ingredients.is_empty() and _elapsed > _burn_time


func ingredients() -> Array[String]:
	return _ingredients.duplicate()


func clear() -> void:
	_ingredients.clear()
	_elapsed = 0.0
	_stir_progress = 0.0
