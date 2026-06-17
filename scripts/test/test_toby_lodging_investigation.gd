extends Node

const TOBY_SCENE := preload("res://scenes/ui/TobyLodgingInvestigation.tscn")
const ASSEMBLE_POINT := Vector2(640, 490)
const FREE_ASSEMBLY_POINT := Vector2(820, 350)
const CONTRACT_PAIR_TAG := "contract_fragment_pair"
const CONTRACT_COMPLETE_TAG := "contract_complete"

## 托比落脚处物理调查的 headless 逻辑回归。镜像 test_mine_investigation 的取舍：
##   1. locations.json 数据契约——告示板贴文不再授予 toby_contract、改由场景授予；
##      托比落脚处地点 day≥6 存在、不走自动授予；
##   2. GameManager.grant_investigation_document 对 toby_contract 的幂等与授予。
## 拼合的物理手感（拖碎片靠拢）只能编辑器走查，不在此 headless 覆盖。

var _checks := 0
var _failures := 0


func _ready() -> void:
	_test_locations_contract()
	_test_grant_idempotent_and_owned()
	await _test_mine_items_recover_when_outside_view_bounds()
	await _test_fragments_snap_near_assembly_and_grant_when_complete()
	_finish()


func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("[TEST-TOBY] FAIL: " + msg)


func _finish() -> void:
	if _failures == 0:
		print("[TEST-TOBY] ALL PASS (", _checks, " checks)")
		get_tree().quit(0)
	else:
		push_error("[TEST-TOBY] FAILURES: %d / %d checks" % [_failures, _checks])
		get_tree().quit(1)


func _test_locations_contract() -> void:
	var f := FileAccess.open("res://data/locations.json", FileAccess.READ)
	_ok(f != null, "locations.json opens")
	var data: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	var locations: Array = (data as Dictionary).get("locations", [])
	var board_ok := false
	var lodging_ok := false
	for loc in locations:
		if String(loc.get("id", "")) == "mercenary_board":
			for posting in loc.get("postings", []):
				if String(posting.get("id", "")) == "toby_commission":
					board_ok = true
					_ok(not posting.has("documents") or (posting.get("documents", []) as Array).is_empty(),
						"toby_commission 贴文不再直接授予委托书（搬进场景）")
		if String(loc.get("id", "")) == "toby_lodging":
			lodging_ok = true
			_ok(String(loc.get("requiresFlag", "")) == "toby_identity_known",
				"Toby lodging opens from identity inference, not from the board posting")
			_ok(int(loc.get("dayMin", 0)) == 6, "托比落脚处 day≥6 开放")
			_ok(not loc.has("documents") or (loc.get("documents", []) as Array).is_empty(),
				"托比落脚处不走自动授予（场景内拼合授予）")
	_ok(board_ok, "找到 toby_commission 贴文")
	_ok(lodging_ok, "找到 toby_lodging 地点")


func _test_grant_idempotent_and_owned() -> void:
	var gm = get_node("/root/GameManager")
	_ok(not gm.documents.owns_document("toby_contract"), "toby_contract not owned at start")
	var newly: bool = gm.grant_investigation_document("toby_contract")
	_ok(newly, "first grant returns newly-granted")
	_ok(gm.documents.owns_document("toby_contract"), "toby_contract owned after grant")
	_ok(gm.narrative.get_var("toby_contract_found") == true, "granting toby_contract marks route proof found")
	_ok(gm.inventory_sys.get_count("toby_contract") == 1, "granting adds it to story bag")
	_ok(not gm.grant_investigation_document("toby_contract"), "second grant is idempotent (not newly)")


func _test_mine_items_recover_when_outside_view_bounds() -> void:
	var scene := TOBY_SCENE.instantiate()
	add_child(scene)
	await get_tree().process_frame

	var frag := _toby_fragment(scene, "contract_fragment_a")
	_ok(frag != null, "out-of-bounds recovery test finds a Toby contract fragment")
	if frag != null:
		var safe_position := frag.global_position
		await get_tree().physics_frame
		frag.freeze = false
		frag.sleeping = false
		frag.global_position = Vector2(-260.0, 420.0)
		frag.linear_velocity = Vector2(-520.0, -40.0)
		frag.angular_velocity = -5.0
		await get_tree().physics_frame
		await get_tree().process_frame
		_ok(frag.global_position.distance_to(safe_position) <= 16.0,
			"out-of-bounds investigation item returns to its safe room position: expected %s, got %s" % [
				safe_position,
				frag.global_position,
			])
		_ok(frag.linear_velocity == Vector2.ZERO and is_zero_approx(frag.angular_velocity),
			"out-of-bounds investigation item returns without leftover throw velocity")
		_ok(scene._try_pickup(frag.global_position),
			"recovered investigation item can be picked up again")
		_ok(scene._drag_ctrl.get_body() == frag,
			"recovered investigation item becomes the active dragged body")
		scene._drag_ctrl.end_drag()

	scene.queue_free()
	await get_tree().process_frame


func _test_fragments_snap_near_assembly_and_grant_when_complete() -> void:
	var gm = get_node("/root/GameManager")
	var snapshot: Dictionary = gm._capture_save_state()
	gm.documents.restore_state({"owned": ["ledger"]})
	gm.inventory_sys.set_initial({})
	gm.inventory = gm.inventory_sys.materials
	gm.narrative.set_var("toby_contract_found", false)

	var scene := TOBY_SCENE.instantiate()
	add_child(scene)
	await get_tree().process_frame
	await get_tree().physics_frame

	var frag_a := _toby_fragment(scene, "contract_fragment_a")
	var frag_b := _toby_fragment(scene, "contract_fragment_b")
	var frag_c := _toby_fragment(scene, "contract_fragment_c")
	_ok(frag_a != null and frag_b != null and frag_c != null,
		"Toby lodging snap test finds all three contract fragments")
	if frag_a != null and frag_b != null and frag_c != null:
		_ok(scene._try_pickup(frag_b.global_position),
			"middle Toby contract fragment can be picked up before snapping")
		_ok(scene._drag_ctrl.get_body() == frag_b,
			"middle Toby contract fragment becomes the active dragged body")
		scene._drag_ctrl.end_drag()

		frag_a.global_position = ASSEMBLE_POINT + Vector2(-22, 6)
		frag_a.linear_velocity = Vector2(180, -40)
		frag_a.angular_velocity = 5.0
		scene._investigation_physics(0.016)
		_ok(frag_a.global_position == ASSEMBLE_POINT + Vector2(-22, 6),
			"one nearby Toby contract fragment does not snap to a hidden assembly slot by itself")
		_ok(not frag_a.freeze,
			"one nearby Toby contract fragment does not freeze before touching another fragment")
		_ok(not gm.documents.owns_document("toby_contract"),
			"one snapped Toby contract fragment does not grant the document yet")

		frag_a.global_position = FREE_ASSEMBLY_POINT
		frag_b.global_position = FREE_ASSEMBLY_POINT + Vector2(28, -6)
		scene._investigation_physics(0.016)
		await get_tree().process_frame
		var pair := _toby_item(scene, CONTRACT_PAIR_TAG)
		_ok(pair != null, "two nearby Toby contract fragments become one real combined piece away from the old assembly point")
		_ok(_toby_fragment(scene, "contract_fragment_a") == null and _toby_fragment(scene, "contract_fragment_b") == null,
			"the two source fragments are removed after the combined piece appears")
		_ok(not gm.documents.owns_document("toby_contract"),
			"two-piece combined Toby contract still does not grant the document")

		if pair != null:
			_ok(pair.global_position.distance_to(FREE_ASSEMBLY_POINT + Vector2(14, -3)) <= 1.0,
				"two-piece combined Toby contract appears where the player joined the first pieces")
			_ok(not pair.freeze, "two-piece combined Toby contract remains draggable instead of sticking to the floor")
			_ok(scene._try_pickup(pair.global_position),
				"middle two-piece Toby contract can be picked up after it appears")
			_ok(scene._drag_ctrl.get_body() == pair,
				"middle two-piece Toby contract becomes the active dragged body")
			scene._drag_ctrl.end_drag()
			var pair_test_position := FREE_ASSEMBLY_POINT + Vector2(120, -20)
			pair.global_position = pair_test_position
			scene._investigation_physics(0.016)
			_ok(pair.global_position == pair_test_position,
				"two-piece combined Toby contract is not pulled back to the original assembly point")
			frag_c.global_position = pair.global_position + Vector2(24, 4)
			scene._investigation_physics(0.016)
			await get_tree().process_frame
			var complete := _toby_item(scene, CONTRACT_COMPLETE_TAG)
			_ok(complete != null, "third fragment joins the nearby combined piece into a complete commission")
			_ok(complete != null and complete.global_position.distance_to(pair_test_position) <= 1.0,
				"complete commission appears where the player joined the pieces")
			_ok(not gm.documents.owns_document("toby_contract"),
				"complete commission stays in the room until the player clicks it")
			if complete != null:
				_ok(scene._on_special_pickup(complete), "clicking the complete commission is handled as collection")
				await get_tree().process_frame
				_ok(gm.documents.owns_document("toby_contract"),
					"clicking the complete commission grants the contract document")
				_ok(gm.narrative.get_var("toby_contract_found") == true,
					"collecting the completed Toby contract marks the route proof found")
				_ok(_toby_item(scene, CONTRACT_COMPLETE_TAG) == null,
					"collected complete commission is removed from the room")

	scene.queue_free()
	await get_tree().process_frame
	gm._apply_save_state(snapshot)


func _toby_fragment(scene: Node, item_tag: String) -> MineItem:
	return _toby_item(scene, item_tag)


func _toby_item(scene: Node, item_tag: String) -> MineItem:
	var world := scene.get_node_or_null("World")
	if world == null:
		return null
	for child in world.get_children():
		if child is MineItem and child.item_tag == item_tag:
			return child
	return null
