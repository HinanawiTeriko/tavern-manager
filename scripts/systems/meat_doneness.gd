class_name MeatDoneness
extends RefCounted

const COOKED_MIN: float = 1.0
const BURN_MAX: float = 2.0
const GOLDEN := Color(0.5, 0.15, 0.05)
const BURNT := Color(0.1, 0.08, 0.05)

var _raw_color: Color = Color(0.65, 0.2, 0.1)
var _progress: float = 0.0


func set_raw_color(c: Color) -> void:
	_raw_color = c


func add_heat(face: int, amount: float) -> void:
	if face < 0 or face > 1:
		return
	_progress += maxf(amount, 0.0)


func face_progress(face: int) -> float:
	if face < 0 or face > 1:
		return 0.0
	return _progress


func is_face_raw(face: int) -> bool:
	return face_progress(face) < COOKED_MIN


func is_face_burnt(face: int) -> bool:
	return face_progress(face) > BURN_MAX


func face_color(face: int) -> Color:
	var t: float = face_progress(face)
	if t <= COOKED_MIN:
		return _raw_color.lerp(GOLDEN, clampf(t / COOKED_MIN, 0.0, 1.0))
	if t <= BURN_MAX:
		return GOLDEN
	return GOLDEN.lerp(BURNT, clampf(t - BURN_MAX, 0.0, 1.0))


func result() -> String:
	if _progress > BURN_MAX:
		return "burnt"
	if _progress < COOKED_MIN:
		return "raw"
	return "cooked"


static func down_face_of(face0_world: Vector2, face1_world: Vector2) -> int:
	return 1 if face1_world.y > face0_world.y else 0
