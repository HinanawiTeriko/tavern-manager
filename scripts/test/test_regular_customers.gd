extends Node

const EXPECTED_IDS: Array[String] = [
	"regular_belta",
	"regular_noel",
	"regular_masha",
	"regular_coen",
	"regular_dorin",
	"regular_elira",
	"regular_marco",
	"regular_nix",
	"regular_selene",
	"regular_gareth",
	"regular_lyra",
	"regular_oma",
	"regular_ketta",
	"regular_bram",
	"regular_sova",
	"regular_petra",
	"regular_jora",
	"regular_tamsin",
	"regular_kael",
	"regular_mirelle",
	"regular_fenna",
	"regular_yuval",
	"regular_nara",
	"regular_iris",
	"regular_bastian",
	"regular_qadir",
	"regular_rowan",
	"regular_maeve",
	"regular_osric",
	"regular_lio",
]
const NEW_EXPECTED_IDS: Array[String] = [
	"regular_ketta",
	"regular_bram",
	"regular_sova",
	"regular_petra",
	"regular_jora",
	"regular_tamsin",
	"regular_kael",
	"regular_mirelle",
	"regular_fenna",
	"regular_yuval",
	"regular_nara",
	"regular_iris",
	"regular_bastian",
	"regular_qadir",
	"regular_rowan",
	"regular_maeve",
	"regular_osric",
	"regular_lio",
]
const PORTRAIT_STATES: Array[String] = ["neutral", "satisfied", "dissatisfied"]

var _checks := 0
var _failures := 0
var _roster: Dictionary = {}
var _appetites: Dictionary = {}


func _ready() -> void:
	_load_roster()
	_load_appetites()
	_test_regular_customer_data_contract()
	_test_new_regular_customer_appearance_variety()
	_test_regular_customer_appetite_contract()
	if _roster.is_empty():
		_finish()
		return
	_test_guest_system_spawns_named_regular_customer()
	await _test_tavern_regular_customer_portrait_states()
	_finish()


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-REGULAR-CUSTOMERS] FAIL: " + msg)


func _finish() -> void:
	if _failures == 0:
		print("[TEST-REGULAR-CUSTOMERS] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-REGULAR-CUSTOMERS] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)


func _gm():
	return get_node("/root/GameManager")


func _load_roster() -> void:
	var file := FileAccess.open("res://data/regular_customers.json", FileAccess.READ)
	if file == null:
		_ok(false, "regular_customers.json exists")
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		_ok(false, "regular_customers.json parses as Dictionary")
		return
	for entry in parsed.get("customers", []):
		if entry is Dictionary:
			_roster[String(entry.get("id", ""))] = entry


func _load_appetites() -> void:
	var file := FileAccess.open("res://data/guest_appetites.json", FileAccess.READ)
	if file == null:
		_ok(false, "guest_appetites.json exists")
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		_ok(false, "guest_appetites.json parses as Dictionary")
		return
	_appetites = parsed


func _test_regular_customer_data_contract() -> void:
	_ok(_roster.size() >= 30, "roster has at least 30 named regular customer archetypes")
	_ok(_roster.size() >= EXPECTED_IDS.size(), "roster has all named regular customer archetypes")
	for customer_id in EXPECTED_IDS:
		_ok(_roster.has(customer_id), "roster includes " + customer_id)
		if not _roster.has(customer_id):
			continue
		var entry: Dictionary = _roster[customer_id]
		_ok(String(entry.get("display_name", "")) != "", customer_id + " has display_name")
		_ok(String(entry.get("role", "")) != "", customer_id + " has role")
		_ok(String(entry.get("portrait_key", "")) == customer_id, customer_id + " uses stable portrait key")
		_ok(int(entry.get("unlock_day", 0)) >= 1, customer_id + " has unlock_day")
		_ok(float(entry.get("spawn_weight", 0.0)) > 0.0, customer_id + " has spawn_weight")
		_ok(float(entry.get("patience_multiplier", 0.0)) > 0.0, customer_id + " has patience_multiplier")
		_ok(float(entry.get("tip_multiplier", 0.0)) > 0.0, customer_id + " has tip_multiplier")
		var favorite_orders_value = entry.get("favorite_orders", [])
		var has_favorite_orders: bool = favorite_orders_value is Array and favorite_orders_value.size() > 0
		_ok(has_favorite_orders, customer_id + " has favorite_orders")
		var reactions_value = entry.get("reactions", {})
		var reactions: Dictionary = reactions_value if reactions_value is Dictionary else {}
		for outcome in ["success", "fail_wrong", "fail_weird", "impatient"]:
			_ok(String(reactions.get(outcome, "")) != "", customer_id + " has reaction " + outcome)
		var portraits_value = entry.get("portraits", {})
		var portraits: Dictionary = portraits_value if portraits_value is Dictionary else {}
		for state in PORTRAIT_STATES:
			_ok(String(portraits.get(state, "")) == "res://assets/textures/characters/%s_%s.png" % [customer_id, state],
				customer_id + " has runtime portrait path for " + state)


func _test_new_regular_customer_appearance_variety() -> void:
	var races: Dictionary = {}
	var hair_styles: Dictionary = {}
	var hair_colors: Dictionary = {}
	for customer_id in NEW_EXPECTED_IDS:
		_ok(_roster.has(customer_id), "new roster includes " + customer_id)
		if not _roster.has(customer_id):
			continue
		var entry: Dictionary = _roster[customer_id]
		var appearance_value = entry.get("appearance", {})
		var appearance: Dictionary = appearance_value if appearance_value is Dictionary else {}
		var race := String(appearance.get("race", ""))
		var hair_style := String(appearance.get("hair_style", ""))
		var hair_color := String(appearance.get("hair_color", ""))
		_ok(race != "", customer_id + " records race for portrait generation")
		_ok(hair_style != "", customer_id + " records hair_style for portrait generation")
		_ok(hair_color != "", customer_id + " records hair_color for portrait generation")
		if race != "":
			races[race] = true
		if hair_style != "":
			hair_styles[hair_style] = true
		if hair_color != "":
			hair_colors[hair_color] = true
	_ok(races.size() >= 6, "new regular customers vary race across the batch")
	_ok(hair_styles.size() >= 10, "new regular customers vary hair styles across the batch")
	_ok(hair_colors.size() >= 10, "new regular customers vary hair colors across the batch")


func _test_regular_customer_appetite_contract() -> void:
	for customer_id in EXPECTED_IDS:
		_ok(_appetites.has(customer_id), customer_id + " has appetite profile")
		if not _appetites.has(customer_id):
			continue
		var appetite_value = _appetites[customer_id]
		var appetite: Dictionary = appetite_value if appetite_value is Dictionary else {}
		var preferred_value = appetite.get("preferred", {})
		var preferred: Dictionary = preferred_value if preferred_value is Dictionary else {}
		_ok(preferred.size() >= 2, customer_id + " has at least two preferred appetite attributes")
		_ok(float(appetite.get("satisfyThreshold", 0.0)) > 0.0, customer_id + " has satisfyThreshold")
		_ok(float(appetite.get("delightThreshold", 0.0)) > float(appetite.get("satisfyThreshold", 0.0)),
			customer_id + " has delightThreshold above satisfyThreshold")
		_ok(String(appetite.get("reaction", "")) != "", customer_id + " has appetite reaction")


func _test_guest_system_spawns_named_regular_customer() -> void:
	if _roster.is_empty():
		return
	var gm = _gm()
	gm.guests.clear_guest()
	gm.guests.configure_night(1, 1)
	gm.guests._spawn_normal()
	var guest = gm.guests.current_guest
	_ok(guest != null, "GuestSystem spawns a normal guest")
	if guest == null:
		return
	_ok(not guest.has_dialogue, "regular customers stay non-dialogue guests")
	_ok(EXPECTED_IDS.has(guest.npc_id), "normal guest exposes stable regular customer id")
	_ok(_roster.has(guest.npc_id), "spawned regular id exists in roster")
	_ok(String(guest.get_meta("regular_customer_id", "")) == guest.npc_id, "guest metadata stores regular_customer_id")
	_ok(String(guest.get_meta("template_id", "")) == guest.npc_id, "guest reactions use regular customer id")
	_ok(String(guest.guest_name) == String(_roster[guest.npc_id].get("display_name", "")), "spawned guest uses roster display name")
	var favorite_orders_value = _roster[guest.npc_id].get("favorite_orders", [])
	var favorite_orders: Array = favorite_orders_value if favorite_orders_value is Array else []
	_ok(favorite_orders.has(guest.order_key), "spawned regular orders from its favorite_orders")
	var line: String = gm.guests.get_reaction_line("success", guest.npc_id)
	var reactions_value = _roster[guest.npc_id].get("reactions", {})
	var reactions: Dictionary = reactions_value if reactions_value is Dictionary else {}
	_ok(line == String(reactions.get("success", "")),
		"regular customer reaction line comes from roster")
	gm.guests.clear_guest()


func _test_tavern_regular_customer_portrait_states() -> void:
	var tavern := preload("res://scenes/ui/Tavern.tscn").instantiate() as TavernView
	add_child(tavern)
	await get_tree().process_frame
	await get_tree().process_frame

	for customer_id in EXPECTED_IDS:
		tavern.show_customer(customer_id, "Roast", customer_id)
		_ok(_portrait_path(tavern).ends_with("/%s_neutral.png" % customer_id),
			customer_id + " enters with neutral portrait")
		tavern.show_customer_reaction("success", customer_id)
		_ok(_portrait_path(tavern).ends_with("/%s_satisfied.png" % customer_id),
			customer_id + " switches to satisfied portrait")
		tavern.show_customer(customer_id, "Roast", customer_id)
		tavern.show_customer_reaction("fail_wrong", customer_id)
		_ok(_portrait_path(tavern).ends_with("/%s_dissatisfied.png" % customer_id),
			customer_id + " switches to dissatisfied portrait")
	tavern.queue_free()


func _portrait_path(tavern: TavernView) -> String:
	var sprite := tavern.get_node_or_null("CustomerArea/CustomerSprite") as TextureRect
	if sprite == null or sprite.texture == null:
		return ""
	return sprite.texture.resource_path
