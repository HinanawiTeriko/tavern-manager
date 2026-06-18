extends Node

const PHYSICS_LAW_SYSTEM_PATH := "res://scripts/systems/physics_law_system.gd"

var _checks := 0
var _failures := 0
var _system_script: Script = null


func _ready() -> void:
	_system_script = load(PHYSICS_LAW_SYSTEM_PATH)
	_ok(_system_script != null, "physics law system script should exist")
	if _system_script == null:
		_finish()
		return
	_check_loads_expected_laws()
	_check_activation_contract()
	_finish()


func _ok(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(message)


func _check_loads_expected_laws() -> void:
	var system = _system_script.new()
	_ok(system.load_from_path("res://data/physics_laws.json"), "physics laws should load")
	_ok(system.has_law("low_gravity"), "low_gravity should exist")
	_ok(system.has_law("heavy_gravity"), "heavy_gravity should exist")
	_ok(system.has_law("slippery_physics"), "slippery_physics should exist")
	_ok(system.has_law("bouncy_physics"), "bouncy_physics should exist")

	var low: Dictionary = system.get_law("low_gravity")
	var heavy: Dictionary = system.get_law("heavy_gravity")
	var slippery: Dictionary = system.get_law("slippery_physics")
	var bouncy: Dictionary = system.get_law("bouncy_physics")
	_ok(String(low.get("id", "")) == "low_gravity", "low gravity lookup should return id")
	_ok(float(low.get("gravity_scale_multiplier", 0.0)) >= 0.2, "low gravity multiplier should respect DeskItem minimum")
	_ok(float(low.get("gravity_scale_multiplier", 0.0)) < 1.0, "low gravity should reduce gravity")
	_ok(float(heavy.get("gravity_scale_multiplier", 0.0)) > 1.0, "heavy gravity should increase gravity")
	_ok(float(heavy.get("gravity_scale_multiplier", 0.0)) <= 2.0, "heavy gravity multiplier should respect DeskItem maximum")
	_ok(float(slippery.get("linear_damp_multiplier", 1.0)) < 1.0, "slippery law should reduce linear damping")
	_ok(float(slippery.get("angular_damp_multiplier", 1.0)) < 1.0, "slippery law should reduce angular damping")
	_ok(float(bouncy.get("bounce_override", 0.0)) > 0.0, "bouncy law should set bounce")
	_ok(float(bouncy.get("bounce_override", 0.0)) <= 1.0, "bouncy law should clamp bounce to Godot material range")
	_ok(float(low.get("release_impulse_multiplier", 1.0)) > 1.0, "doge law should add moon-table release drift")
	_ok(float(low.get("random_lift_impulse", 0.0)) > 0.0, "doge law should define a float-up pulse")
	_ok(float(heavy.get("near_customer_pull", 0.0)) > 0.0, "snack cat law should pull food toward the customer")
	_ok(float(heavy.get("collision_impulse_multiplier", 1.0)) > 1.0, "snack cat law should make impacts feel heavier")
	_ok(float(slippery.get("release_spin_multiplier", 1.0)) > 1.0, "cheems law should add extra slipping spin")
	_ok(float(slippery.get("collision_impulse_multiplier", 1.0)) > 1.0, "cheems law should kick items sideways on collision")
	_ok(float(bouncy.get("collision_impulse_multiplier", 1.0)) > 1.0, "popcat law should exaggerate rebounds")
	_ok(float(bouncy.get("random_lift_impulse", 0.0)) > 0.0, "popcat law should define a pop-up impulse")


func _check_activation_contract() -> void:
	var system = _system_script.new()
	_ok(system.load_from_path("res://data/physics_laws.json"), "physics laws should load before activation")
	_ok(system.try_activate_for_night("low_gravity"), "first law should activate")
	_ok(not system.try_activate_for_night("heavy_gravity"), "second nightly law should not replace active law")
	_ok(system.has_active_law(), "system should report active law")
	_ok(String(system.get_active_law().get("id", "")) == "low_gravity", "active law should stay as first law")
	system.clear_active_law()
	_ok(not system.has_active_law(), "clear should remove active law")
	_ok(system.try_activate_for_night("heavy_gravity"), "law should activate after clear")


func _finish() -> void:
	print("Physics law system checks: %d failures: %d" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
