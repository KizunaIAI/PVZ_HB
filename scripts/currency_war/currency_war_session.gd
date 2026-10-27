## 仅保存当前整局内存状态，使十五节点切场景时不会重领阳光或恢复阵亡植物。
class_name CurrencyWarSession
extends RefCounted

## 显式加载规则，避免首次导入时依赖编辑器类型缓存。
const RunRules = preload("res://scripts/currency_war/currency_war_run.gd")
## 跨节点共享的整局规则，返回菜单或重新开始时清空。
static var active_run: RunRules


## 获取本局规则；F6运行节点场景时也能建立一次新局，不会每节点重新初始化。
static func get_run() -> RunRules:
	if active_run == null:
		active_run = RunRules.new()
	return active_run


## 开始新局，取消旧局内存，不从仓库取用植物；未来冒险模式的取用规则由用户另定。
static func start_new() -> void:
	active_run = RunRules.new()


## 离开整局时释放引用；不删除仓库，也不产生新的植物奖励。
static func clear() -> void:
	active_run = null
