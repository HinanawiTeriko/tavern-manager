class_name BrewShakeMeter
extends RefCounted

## 摇晃计数器（纯逻辑）。喂入水平速度样本，统计「够速的方向翻转」次数，映射品质档。
## 阈值从 data/barrel.json 的 "shake" 段加载（热调）。摇晃不喂 L3，只算品质。

var min_speed: float = 150.0
var min_count: int = 4
var good_count: int = 10
var shake_count: int = 0
var _last_sign: int = 0

func load_thresholds(d: Dictionary) -> void:
	min_speed = float(d.get("min_speed", min_speed))
	min_count = int(d.get("min_count", min_count))
	good_count = int(d.get("good_count", good_count))

func reset() -> void:
	shake_count = 0
	_last_sign = 0

func add_sample(vx: float) -> void:
	if absf(vx) < min_speed:
		return
	var s := 1 if vx > 0.0 else -1
	if _last_sign != 0 and s != _last_sign:
		shake_count += 1
	_last_sign = s

func has_enough() -> bool:
	return shake_count >= min_count

func quality_tier() -> String:
	return "good" if shake_count >= good_count else "normal"
