class_name AppetiteSystem
extends RefCounted

const FOOD_ATTRIBUTES_PATH := "res://data/food_attributes.json"
const GUEST_APPETITES_PATH := "res://data/guest_appetites.json"
const ATTRIBUTE_TAGS := {
	"might": "力量",
	"vitality": "顶饿",
	"fortune": "体面",
	"charm": "精致",
	"arcana": "秘香",
	"alacrity": "轻快",
}
const PRODUCT_TAGS := {
	"meat_cooked": ["热食"],
	"rock_lizard_steak": ["热食"],
	"meat_sand": ["热食"],
	"meat_stew": ["热食"],
	"cave_mushroom_stew": ["热食", "清香"],
	"herb_tea": ["清香"],
	"herbal_ale": ["清香"],
	"herb_broth": ["清香"],
	"ale_beer": ["酒水"],
	"miner_dark_ale": ["酒水"],
	"wine": ["酒水"],
	"old_road_wine": ["酒水", "清香"],
	"spiced_wine": ["酒水"],
	"malt_porridge": ["热食"],
}

var food_attributes: Dictionary = {}
var guest_appetites: Dictionary = {}


func load_data(food_path: String = FOOD_ATTRIBUTES_PATH, appetite_path: String = GUEST_APPETITES_PATH) -> bool:
	food_attributes = _load_dictionary(food_path)
	guest_appetites = _load_dictionary(appetite_path)
	return not food_attributes.is_empty() and not guest_appetites.is_empty()


func evaluate(customer_id: String, product_key: String, quality: String = "normal", seasoning_attribute: String = "") -> Dictionary:
	var profile: Dictionary = guest_appetites.get(customer_id, {})
	var attrs: Dictionary = food_attributes.get(product_key, {})
	if profile.is_empty() or attrs.is_empty():
		return {
			"tier": "none",
			"score": 0.0,
			"bonus_gold": 0,
			"bonus_rep": 0,
			"matched_attributes": [],
			"matched_tags": [],
			"reaction": "",
		}

	var preferred: Dictionary = profile.get("preferred", {})
	var matched: Array[String] = []
	var score := 0.0
	for attr in preferred.keys():
		var attr_key := String(attr)
		var attr_value := float(attrs.get(attr_key, 0.0))
		if attr_value <= 0.0:
			continue
		score += attr_value * float(preferred[attr])
		matched.append(attr_key)
	var matched_tags := _tags_for_attributes(matched)

	var seasoning: Dictionary = profile.get("seasoning", {})
	if seasoning_attribute != "" and seasoning.has(seasoning_attribute):
		score += float(seasoning[seasoning_attribute])
		if not matched_tags.has(seasoning_attribute):
			matched_tags.append(seasoning_attribute)

	match quality:
		"good":
			score += 1.0
		"poor":
			score -= 1.0

	var tier := "fulfilled"
	if score >= float(profile.get("delightThreshold", 5.0)):
		tier = "delighted"
	elif score >= float(profile.get("satisfyThreshold", 2.5)):
		tier = "satisfied"

	var bonus_gold := 0
	var bonus_rep := 0
	if tier == "delighted":
		bonus_gold = int(profile.get("bonusGold", 0))
		bonus_rep = int(profile.get("bonusRep", 0))
	elif tier == "satisfied":
		bonus_gold = mini(1, int(profile.get("bonusGold", 0)))

	return {
		"tier": tier,
		"score": score,
		"bonus_gold": bonus_gold,
		"bonus_rep": bonus_rep,
		"matched_attributes": matched,
		"matched_tags": matched_tags,
		"reaction": String(profile.get("reaction", "")) if tier == "delighted" else "",
	}


func get_product_tags(product_key: String) -> Array[String]:
	var result: Array[String] = []
	for tag in PRODUCT_TAGS.get(product_key, []):
		var tag_text := String(tag)
		if tag_text != "" and not result.has(tag_text):
			result.append(tag_text)
	var attrs: Dictionary = food_attributes.get(product_key, {})
	for attr in attrs.keys():
		if float(attrs[attr]) <= 0.0:
			continue
		var label := String(ATTRIBUTE_TAGS.get(String(attr), ""))
		if label != "" and not result.has(label):
			result.append(label)
	return result


func _tags_for_attributes(attributes: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for attr in attributes:
		var label := String(ATTRIBUTE_TAGS.get(attr, ""))
		if label != "" and not result.has(label):
			result.append(label)
	return result


func _load_dictionary(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("[AppetiteSystem] cannot load data: " + path)
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		push_error("[AppetiteSystem] invalid data: " + path)
		return {}
	return parsed
