extends Node

var _checks := 0
var _failures := 0


class FakeMemeArrivalView extends Node:
	var daily_menu := {}
	var shown_customers: Array = []
	var customer_lines: Array[String] = []
	var stage_lines: Array = []
	var applied_laws: Array = []
	var meme_events: Array = []

	func show_customer(customer_name: String, order_name: String, npc_id: String = "guest", order_key: String = "") -> void:
		shown_customers.append({
			"customer_name": customer_name,
			"order_name": order_name,
			"npc_id": npc_id,
			"order_key": order_key,
		})

	func customer_say(text: String) -> void:
		customer_lines.append(text)

	func apply_physics_law(law: Dictionary) -> void:
		applied_laws.append(law.duplicate(true))

	func show_stage_caption(text: String, color: Color = Color.WHITE) -> void:
		stage_lines.append({"text": text, "color": color})

	func show_meme_guest_event(customer_name: String, hint: String) -> void:
		meme_events.append({"customer_name": customer_name, "hint": hint})

	func set_close_enabled(_enabled: bool) -> void:
		pass

	func update_top_bar(_gold: int, _rep: int, _day: int, _last_day: int, _max_gold: int = 0) -> void:
		pass


func _ready() -> void:
	_check_game_manager_speaks_meme_arrival_line()
	_finish()


func _ok(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(message)


func _check_game_manager_speaks_meme_arrival_line() -> void:
	var gm = get_node("/root/GameManager")
	_ok(gm != null and gm.has_method("_on_guest_arrived"), "GameManager should expose guest arrival handler")
	if gm == null or not gm.has_method("_on_guest_arrived"):
		return

	var old_view = gm._tavern_view
	var tm = get_node_or_null("/root/TutorialManager")
	var old_first_guest_arrived := false
	if tm != null:
		old_first_guest_arrived = bool(tm.first_guest_arrived)
		tm.first_guest_arrived = true

	var fake_view := FakeMemeArrivalView.new()
	add_child(fake_view)
	gm._tavern_view = fake_view
	if gm.physics_laws != null:
		gm.physics_laws.clear_active_law()

	var guest := GuestData.new()
	guest.guest_name = "Doge"
	guest.order_key = "bread"
	guest.npc_id = "meme_doge"
	guest.has_dialogue = false
	guest.set_meta("portrait_id", "meme_doge")
	guest.set_meta("physics_law_id", "low_gravity")
	guest.set_meta("arrival_line", "wow... woof?")
	guest.set_meta("event_hint", "such 客人. very 点单. wow.")

	gm._on_guest_arrived(guest)

	_ok(fake_view.shown_customers.size() == 1, "meme guest arrival should still show the customer")
	_ok(fake_view.applied_laws.size() == 1, "meme guest arrival should still activate physics law")
	_ok(fake_view.meme_events.size() == 1, "meme guest arrival should show one event notice")
	if fake_view.meme_events.size() == 1:
		_ok(String(fake_view.meme_events[0].get("customer_name", "")) == "Doge", "meme event notice should name the arriving guest")
		_ok(String(fake_view.meme_events[0].get("hint", "")) == "such 客人. very 点单. wow.", "meme event notice should use the guest event hint")
	_ok(fake_view.customer_lines.size() == 1, "meme guest arrival should speak one animal-like line")
	if fake_view.customer_lines.size() == 1:
		_ok(fake_view.customer_lines[0] == "wow... woof?", "meme guest arrival line should use guest metadata")
	_ok(not guest.has_dialogue, "arrival line should not switch meme guest into important NPC dialogue flow")

	if gm.physics_laws != null:
		gm.physics_laws.clear_active_law()
	gm._tavern_view = old_view
	if tm != null:
		tm.first_guest_arrived = old_first_guest_arrived
	fake_view.queue_free()


func _finish() -> void:
	print("Meme guest arrival line checks: %d failures: %d" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
