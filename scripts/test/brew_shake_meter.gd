class_name BrewShakeMeter
extends RefCounted

## 摇晃计数器（纯逻辑）。喂入速度向量样本，统计「够速的方向翻转」次数，映射品质档。
## 方向翻转 = 任意方向掉头（左右/上下/斜向皆可）：相邻够速样本的点积 < 0（夹角 > 90°）。
## 阈值从 data/barrel.json 的 "shake" 段加载（热调）。摇晃不喂 L3，只算品质。

var min_speed: float = 150.0
var min_count: int = 4
var good_count: int = 10
var shake_count: int = 0
var _last_dir: Vector2 = Vector2.ZERO

func load_thresholds(d: Dictionary) -> void:
	min_speed = float(d.get("min_speed", min_speed))
	min_count = int(d.get("min_count", min_count))
	good_count = int(d.get("good_count", good_count))

func reset() -> void:
	shake_count = 0
	_last_dir = Vector2.ZERO

func add_sample(v: Vector2) -> void:
	if v.length() < min_speed:
		return   # 太慢：不计、不更新方向（挡掉匀速拖和轻微抖动）
	var dir := v.normalized()
	if _last_dir != Vector2.ZERO and _last_dir.dot(dir) < 0.0:
		shake_count += 1   # 相对上一个够速方向掉头 > 90° → 一次摇晃
	_last_dir = dir

func has_enough() -> bool:
	return shake_count >= min_count

func quality_tier() -> String:
	return "good" if shake_count >= good_count else "normal"
