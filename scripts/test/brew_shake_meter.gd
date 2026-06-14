class_name BrewShakeMeter
extends RefCounted

## Counts full shake cycles from velocity direction reversals.
## A full shake is two valid reversals, so quality/combo does not climb too fast.
## add_sample() returns true on every valid reversal so visuals can react earlier.

var min_speed: float = 150.0
var min_count: int = 4
var good_count: int = 10
var shake_count: int = 0
var _last_dir: Vector2 = Vector2.ZERO
var _turns_since_full_shake: int = 0


func load_thresholds(d: Dictionary) -> void:
	min_speed = float(d.get("min_speed", min_speed))
	min_count = int(d.get("min_count", min_count))
	good_count = int(d.get("good_count", good_count))


func reset() -> void:
	shake_count = 0
	_last_dir = Vector2.ZERO
	_turns_since_full_shake = 0


func add_sample(v: Vector2) -> bool:
	if v.length() < min_speed:
		return false
	var dir := v.normalized()
	var reversed := false
	if _last_dir != Vector2.ZERO and _last_dir.dot(dir) < 0.0:
		reversed = true
		_turns_since_full_shake += 1
		if _turns_since_full_shake >= 2:
			shake_count += 1
			_turns_since_full_shake = 0
	_last_dir = dir
	return reversed


func has_enough() -> bool:
	return shake_count >= min_count


func quality_tier() -> String:
	return "good" if shake_count >= good_count else "normal"
