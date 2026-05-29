class_name CraftStyleSystem
extends RefCounted

## L3 动作风格分类。MVP 单轴：上菜释放速度 serve_drop_speed → 3 类。
## 数据接口按 5 类（双轴：力度 × 节奏）预留，分类函数现只返回 3 类。
## 扩展到 5 类时只改 classify()，不动调用方。

const STYLE_ROUGH := "粗鲁"
const STYLE_CALM := "平静"
const STYLE_GENTLE := "温柔"

var _rough_speed: float = 900.0
var _gentle_speed: float = 150.0

func load_data() -> void:
	var file = FileAccess.open("res://data/craft_style_thresholds.json", FileAccess.READ)
	if file == null:
		push_warning("[CraftStyle] craft_style_thresholds.json 未找到，用默认阈值")
		return
	var json_text = file.get_as_text()
	file.close()
	var data = JSON.parse_string(json_text)
	if data == null or not data is Dictionary:
		push_error("[CraftStyle] thresholds JSON 格式无效")
		return
	var sds: Dictionary = data.get("serve_drop_speed", {})
	_rough_speed = float(sds.get("rough", _rough_speed))
	_gentle_speed = float(sds.get("gentle", _gentle_speed))

## craft_style: { "serve_drop_speed": float, ...其余字段 MVP 不读 }
## 缺 serve_drop_speed（旧调用方传空）→ "平静"（安全默认）。
## 有该键但速度很低 → "温柔"（轻放即温柔，与缺信号区分）。
func classify(craft_style: Dictionary) -> String:
	if not craft_style.has("serve_drop_speed"):
		return STYLE_CALM
	var speed: float = float(craft_style["serve_drop_speed"])
	if speed >= _rough_speed:
		return STYLE_ROUGH
	if speed <= _gentle_speed:
		return STYLE_GENTLE
	return STYLE_CALM
	# 5 类扩展点：引入第二轴（节奏 = operation_pause_avg / time_to_serve），
	# 四象限返回 粗鲁/果断/敷衍/温柔，中间保留 平静。
