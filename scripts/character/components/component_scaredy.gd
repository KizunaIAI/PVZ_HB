## 原版胶囊害怕检测；货币战争可注入精确格子查询，与缩地攻击共用目标规则。
extends ComponentNormBase
class_name ScaredyComponent


signal signal_scaredy_start
signal signal_scaredy_end
@onready var detect_component: DetectComponent = $DetectComponent

## 货币战争注入的3×3目标查询，未配置时保持原版物理检测。
var _currency_war_query: Callable
## 模式查询上一次是否找到敌人，仅在进入/离开范围时发出信号，避免每帧重复缩地或停火。
var _currency_war_has_target: bool = false

## 害怕时影响的节点
@export var scaredy_influence_components:Array[ComponentNormBase]

func _ready() -> void:
	super()
	detect_component.signal_can_attack.connect(func():signal_scaredy_start.emit())
	detect_component.signal_not_can_attack.connect(func():signal_scaredy_end.emit())

## 启用组件
func enable_component(is_enable_factor:E_IsEnableFactor):
	super(is_enable_factor)
	if is_enabling:
		detect_component.enable_component(E_IsEnableFactor.Scaredy)

## 禁用组件
func disable_component(is_enable_factor:E_IsEnableFactor):
	super(is_enable_factor)
	detect_component.disable_component(E_IsEnableFactor.Scaredy)
	_currency_war_has_target = false
	signal_scaredy_end.emit()


## 使用[param query]返回的实际格子目标替代原版胶囊；只改变当前实例，不修改共享场景资源。
func configure_currency_war_query(query: Callable) -> void:
	_currency_war_query = query
	# 保留原版启用/睡眠因素，关闭原胶囊的索敌与碰撞回调，避免两套范围互相覆盖状态。
	detect_component.set_process(false)
	for area: Area2D in detect_component.all_ray_area:
		area.set_deferred("monitoring", false)


## [param _delta]为游戏帧时长；模式逐帧查询真实目标，僵尸走动、死亡或被击退后下一帧更新害怕状态。
func _process(_delta: float) -> void:
	if not _currency_war_query.is_valid():
		return
	# 原版睡眠、死亡和组件禁用仍能停止检测，不能被模式查询强制唤醒。
	var enemies: Array = _currency_war_query.call() if is_enabling and detect_component.is_enabling else []
	# 只有是否有目标发生改变时通知植物，连续害怕期间不重复施放缩地攻击。
	var has_target: bool = not enemies.is_empty()
	detect_component.enemy_can_be_attacked = enemies[0] if has_target else null
	if has_target == _currency_war_has_target:
		return
	_currency_war_has_target = has_target
	if has_target:
		signal_scaredy_start.emit()
	else:
		signal_scaredy_end.emit()
