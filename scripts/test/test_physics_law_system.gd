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
	_ok(system.has_law("gugu_waddle_physics"), "gugu_waddle_physics should exist")
	_ok(system.has_law("orunji_bounce_physics"), "orunji_bounce_physics should exist")
	_ok(system.has_law("anon_hia_laugh_physics"), "anon_hia_laugh_physics should exist")
	_ok(system.has_law("nailong_belly_laugh_physics"), "nailong_belly_laugh_physics should exist")

	var low: Dictionary = system.get_law("low_gravity")
	var heavy: Dictionary = system.get_law("heavy_gravity")
	var slippery: Dictionary = system.get_law("slippery_physics")
	var bouncy: Dictionary = system.get_law("bouncy_physics")
	var gugu_waddle: Dictionary = system.get_law("gugu_waddle_physics")
	var orunji_bounce: Dictionary = system.get_law("orunji_bounce_physics")
	var anon_hia_laugh: Dictionary = system.get_law("anon_hia_laugh_physics")
	var nailong_laugh: Dictionary = system.get_law("nailong_belly_laugh_physics")
	_ok(String(low.get("id", "")) == "low_gravity", "low gravity lookup should return id")
	_ok(float(low.get("gravity_scale_multiplier", 0.0)) >= 0.2, "low gravity multiplier should respect DeskItem minimum")
	_ok(float(low.get("gravity_scale_multiplier", 0.0)) <= 0.22, "low gravity should be visibly floaty")
	_ok(float(low.get("linear_damp_multiplier", 1.0)) <= 0.35, "low gravity should let released items drift")
	_ok(float(low.get("angular_damp_multiplier", 1.0)) <= 0.45, "low gravity should preserve visible spin")
	_ok(float(heavy.get("gravity_scale_multiplier", 0.0)) > 1.0, "heavy gravity should increase gravity")
	_ok(float(heavy.get("gravity_scale_multiplier", 0.0)) <= 2.0, "heavy gravity multiplier should respect DeskItem maximum")
	_ok(float(heavy.get("collision_impulse_multiplier", 1.0)) >= 2.2, "heavy gravity should make impacts slam hard")
	_ok(float(heavy.get("near_customer_pull", 0.0)) >= 210.0, "heavy gravity should strongly pull food toward the customer")
	_ok(float(slippery.get("linear_damp_multiplier", 1.0)) <= 0.06, "slippery law should remove almost all linear damping")
	_ok(float(slippery.get("angular_damp_multiplier", 1.0)) <= 0.06, "slippery law should remove almost all angular damping")
	_ok(float(bouncy.get("bounce_override", 0.0)) >= 0.98, "bouncy law should set near-full bounce")
	_ok(float(bouncy.get("bounce_override", 0.0)) <= 1.0, "bouncy law should clamp bounce to Godot material range")
	_ok(float(low.get("release_impulse_multiplier", 1.0)) >= 2.0, "low gravity should add obvious moon-table release drift")
	_ok(float(low.get("release_spin_multiplier", 1.0)) >= 2.2, "low gravity should add visible spin on release")
	_ok(float(low.get("random_lift_impulse", 0.0)) >= 280.0, "low gravity should define a strong float-up pulse")
	_ok(float(low.get("pulse_interval_seconds", 8.0)) <= 1.3, "low gravity should pulse often enough to be noticed")
	_ok(float(low.get("stage_chaos_feed", 0.0)) >= 0.5, "low gravity should feed visible stage chaos")
	_ok(float(slippery.get("release_impulse_multiplier", 1.0)) >= 2.5, "slippery law should shoot released items farther")
	_ok(float(slippery.get("release_spin_multiplier", 1.0)) >= 3.0, "slippery law should add obvious slipping spin")
	_ok(float(slippery.get("collision_impulse_multiplier", 1.0)) >= 2.0, "slippery law should kick items sideways on collision")
	_ok(float(slippery.get("stage_chaos_feed", 0.0)) >= 0.6, "slippery law should feed visible stage chaos")
	_ok(float(bouncy.get("release_impulse_multiplier", 1.0)) >= 1.6, "bouncy law should boost release hops")
	_ok(float(bouncy.get("release_spin_multiplier", 1.0)) >= 2.0, "bouncy law should spin bouncing items")
	_ok(float(bouncy.get("collision_impulse_multiplier", 1.0)) >= 2.8, "bouncy law should exaggerate rebounds")
	_ok(float(bouncy.get("random_lift_impulse", 0.0)) >= 300.0, "bouncy law should define a strong pop-up impulse")
	_ok(float(bouncy.get("pulse_interval_seconds", 8.0)) <= 1.1, "bouncy law should pop often enough to read")
	_ok(float(bouncy.get("stage_chaos_feed", 0.0)) >= 0.7, "bouncy law should feed visible stage chaos")
	_ok(float(gugu_waddle.get("gravity_scale_multiplier", 1.0)) <= 0.8, "gugu law should keep items low and gliding")
	_ok(float(gugu_waddle.get("linear_damp_multiplier", 1.0)) <= 0.06, "gugu law should make items keep sliding")
	_ok(float(gugu_waddle.get("angular_damp_multiplier", 1.0)) <= 0.06, "gugu law should preserve table spin")
	_ok(float(gugu_waddle.get("release_impulse_multiplier", 1.0)) >= 2.3, "gugu law should stretch release slides")
	_ok(float(gugu_waddle.get("release_spin_multiplier", 1.0)) >= 3.0, "gugu law should add sleepy table spin")
	_ok(float(gugu_waddle.get("collision_impulse_multiplier", 1.0)) >= 2.0, "gugu law should make low slides knock items away")
	_ok(float(gugu_waddle.get("stage_chaos_feed", 0.0)) >= 0.55, "gugu law should feed visible stage chaos")
	_ok(float(orunji_bounce.get("bounce_override", 0.0)) >= 0.98, "orunji law should make items doro-bouncy")
	_ok(float(orunji_bounce.get("release_impulse_multiplier", 1.0)) >= 1.55, "orunji law should add hop drift on release")
	_ok(float(orunji_bounce.get("release_spin_multiplier", 1.0)) >= 1.9, "orunji law should add bounce spin")
	_ok(float(orunji_bounce.get("collision_impulse_multiplier", 1.0)) >= 2.6, "orunji law should make collisions hop")
	_ok(float(orunji_bounce.get("random_lift_impulse", 0.0)) >= 280.0, "orunji law should occasionally hop items high")
	_ok(float(orunji_bounce.get("pulse_interval_seconds", 8.0)) <= 1.1, "orunji law should hop often enough to read")
	_ok(float(orunji_bounce.get("stage_chaos_feed", 0.0)) >= 0.65, "orunji law should feed visible stage chaos")
	_ok(float(anon_hia_laugh.get("gravity_scale_multiplier", 1.0)) <= 0.25, "anon hia laugh law should make the table feel very light")
	_ok(float(anon_hia_laugh.get("linear_damp_multiplier", 1.0)) <= 0.35, "anon hia laugh law should keep float drift readable")
	_ok(float(anon_hia_laugh.get("release_impulse_multiplier", 1.0)) >= 2.0, "anon hia laugh law should give floaty release drift")
	_ok(float(anon_hia_laugh.get("release_spin_multiplier", 1.0)) >= 2.0, "anon hia laugh law should add visible laugh spin")
	_ok(float(anon_hia_laugh.get("random_lift_impulse", 0.0)) >= 260.0, "anon hia laugh law should pulse items upward")
	_ok(float(anon_hia_laugh.get("pulse_interval_seconds", 8.0)) <= 1.2, "anon hia laugh law should pulse often enough to read")
	_ok(float(anon_hia_laugh.get("stage_chaos_feed", 0.0)) >= 0.55, "anon hia laugh law should feed visible stage chaos")
	_ok(float(nailong_laugh.get("gravity_scale_multiplier", 1.0)) >= 1.95, "nailong laugh law should make items heavy")
	_ok(float(nailong_laugh.get("linear_damp_multiplier", 1.0)) >= 1.4, "nailong laugh law should make loose food feel weighty")
	_ok(float(nailong_laugh.get("collision_impulse_multiplier", 1.0)) >= 2.2, "nailong laugh law should make heavy items thump")
	_ok(float(nailong_laugh.get("near_customer_pull", 0.0)) >= 220.0, "nailong laugh law should pull loose food toward the belly")
	_ok(float(nailong_laugh.get("stage_chaos_feed", 0.0)) >= 0.55, "nailong laugh law should feed visible stage chaos")


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
