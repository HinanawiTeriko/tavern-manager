class_name WorkspaceSystem
extends RefCounted

# 容器/工具按天解锁（spec §6.2）。值为解锁的最早天数。
const CONTAINER_UNLOCK_DAY := {
	"barrel": 1,
	"grill": 2,
	"pot": 3,
	"spoon": 3,
}

func unlocked_containers(day: int) -> Array[String]:
	var result: Array[String] = []
	for key in CONTAINER_UNLOCK_DAY:
		if day >= int(CONTAINER_UNLOCK_DAY[key]):
			result.append(key)
	result.sort()
	return result

func is_container_unlocked(key: String, day: int) -> bool:
	if not CONTAINER_UNLOCK_DAY.has(key):
		return false
	return day >= int(CONTAINER_UNLOCK_DAY[key])

# 按能力判定越界恢复目标（spec §6.3）。优先级保证关键物品永不销毁：
# 工具/容器回泊位 > 剧情物品回背包 > 可读文档回文档泊位 > 成品回回收区 >
# 材料回背包 > 兜底回背包。
func recovery_target(capabilities: Array[String]) -> String:
	if capabilities.has("container") or capabilities.has("tool"):
		return "dock"
	if capabilities.has("story_item"):
		return "backpack"
	if capabilities.has("readable"):
		return "doc_dock"
	if capabilities.has("product"):
		return "recycle"
	if capabilities.has("material"):
		return "backpack"
	return "backpack"
