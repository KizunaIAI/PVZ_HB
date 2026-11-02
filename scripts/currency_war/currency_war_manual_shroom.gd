## 货币战争寒冰菇与毁灭菇的手动引爆、重复特效和休眠；仅挂载到本模式的战斗实体。
extends Node

## 节点阶段枚举，准备、备战与暂停期间不消耗休眠时间。
const RunRules = preload("res://scripts/currency_war/currency_war_run.gd")
## 一至三星引爆后的休眠秒数，不受攻速装备缩短。
const SLEEP_SECONDS: Array[float] = [90.0, 30.0, 10.0]
## 持有当前节点与阶段的单局规则。
var _run: RunRules
## 对应持有植物的纯数据记录，剩余休眠供换位和跨节点重建恢复。
var _unit: Dictionary
## 原版可受伤植物；本组件不改变其血量和死亡处理。
var _plant: Plant000Base
## 原版爆炸组件，继续负责音效、冻结和攻击动作信号。
var _bomb: BombComponentBase
## 原版身体动画播放器，手动播放待机和睡眠，绕开自动引爆状态机。
var _animation: AnimationPlayer
## 休眠剩余游戏秒，零表示允许玩家再次点击释放。
var _remaining: float = 0.0


## 为[param plant]绑定[param run]与[param unit]；恢复本局休眠，关闭自动爆炸、自毁和留坑。
func configure(plant: Plant000Base, run: RunRules, unit: Dictionary) -> void:
	_plant = plant
	_run = run
	_unit = unit
	_bomb = plant.get_node("BombComponent") as BombComponentBase
	_animation = plant.get_node("AnimationPlayer") as AnimationPlayer
	_remaining = maxf(0.0, float(unit.get("manual_shroom_remaining", 0.0)))
	# 保留原版身体资源，仅让当前实体的手动控制替代自动自毁动画。
	(plant.get_node("AnimationTree") as AnimationTree).active = false
	plant.is_can_death_language = false
	_bomb.is_auto_bomb_in_death = false
	if plant is Plant016DoomShroom:
		if _bomb.signal_bomb_once.is_connected(plant.plant_cell.create_crater):
			_bomb.signal_bomb_once.disconnect(plant.plant_cell.create_crater)
		plant.set_meta("currency_war_fullscreen_bomb", _damage_fullscreen)
	if _bomb is BombComponentIce:
		_bomb.time_ice = 3.0 + clampi(int(unit.star), 1, 3) - 1
	_set_sleeping(_remaining > 0.0)


## 仅按战斗中经过的[param delta]游戏秒推进休眠；实体死亡或准备时不推进。
func _process(delta: float) -> void:
	if not is_instance_valid(_plant) or _plant.is_death or get_tree().paused or _run.phase != RunRules.Phase.BATTLE or _remaining <= 0.0:
		return
	_remaining = maxf(0.0, _remaining - delta)
	_unit["manual_shroom_remaining"] = _remaining
	if _remaining == 0.0:
		_set_sleeping(false)


## 手动引爆一次，成功返回true；休眠、暂停、非战斗或死亡时不产生效果。
func activate() -> bool:
	if _run.phase != RunRules.Phase.BATTLE or get_tree().paused or _plant.is_death or _remaining > 0.0 or not _bomb.is_enabling:
		return false
	# 在伤害可能触发节点结算前保存冷却，避免最后一击切节点时遗漏休眠。
	_remaining = SLEEP_SECONDS[clampi(int(_unit.star), 1, 3) - 1]
	_unit["manual_shroom_remaining"] = _remaining
	# 原版特效会移出植物播放并释放，先从未播放的特效复制下一次所需实例。
	var current_effect: BombEffectBase = _bomb.get_node("BombEffect") as BombEffectBase
	# 仅复制脚本和子节点，不继承本次播放的临时信号连接。
	var next_effect: BombEffectBase = current_effect.duplicate(Node.DUPLICATE_SCRIPTS) as BombEffectBase
	next_effect.hide()
	_bomb.is_bomb = false
	_bomb.bomb_once()
	_bomb.add_child(next_effect)
	if _bomb is BombComponentIce:
		_bomb.bomb_effect = next_effect
	elif _bomb is BombComponentNorm:
		_bomb.bomb_effect = next_effect
	_set_sleeping(true)
	return true


## 按[param sleeping]播放原版睡眠或待机并同步组件启停；不切入带有自毁方法轨道的动画。
func _set_sleeping(sleeping: bool) -> void:
	if sleeping:
		_plant.sleep_component.start_sleep()
	else:
		_plant.sleep_component.end_sleep()
	_animation.play(("IceShroom_sleep" if sleeping else "IceShroom_idle_only") if _plant is Plant015IceShroom else ("DoomShroom_sleep" if sleeping else "DoomShroom_idle"))


## 毁灭菇爆炸回调：对当前敌方僵尸全屏伤害，保留斩杀装备加成；魅惑友军不受伤。
func _damage_fullscreen() -> void:
	# 伤害可能同步移除僵尸，使用快照保证同一轮不漏掉相邻元素。
	for zombie: Zombie000Base in Global.main_game.zombie_manager.all_zombies_1d.duplicate():
		if not is_instance_valid(zombie) or zombie.is_death or zombie.is_hypno:
			continue
		# 本次星级和固定装备伤害已经由战斗属性同步写入爆炸组件。
		var damage: int = _bomb.bomb_value
		# 斩杀阈值包含本体和两类护甲，沿用模式普通爆炸的计算规则。
		var maximum: int = zombie.hp_component.max_hp
		if zombie.hp_component is HpComponentZombie:
			maximum += zombie.hp_component.max_hp_armor1 + zombie.hp_component.max_hp_armor2
		if float(zombie.hp_component.get_all_hp()) < maximum * 0.5:
			damage = roundi(damage * (1.0 + float(_plant.get_meta("currency_war_execute", 0.0))))
		zombie.be_bomb(damage, _bomb.is_cherry_bomb)
