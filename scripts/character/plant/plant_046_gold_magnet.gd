## 原版吸金磁铁；货币战争绑定钱币攻击回调后替换吸金效果，其他模式保持原版。
extends Plant000Base
class_name Plant046GoldMagnet

## 原版待机与吸引动作状态树，模式发射仍使用同一动作的释放帧。
@onready var animation_tree: AnimationTree = $AnimationTree

## 原版吸金位置，货币战争作为五枚钱币的发射原点。
@onready var marker_2d_coin: Marker2D = $Body/BodyCorrect/Marker2DCoin
## 随角色暂停的循环计时器，周期以游戏秒计。
var attack_cd_timer:Timer

## 原版每五秒吸金；模式配置会以明确指定的间隔替换当前实例。
@export var attack_cd:float = 5
## 模式钱币发射回调；未绑定时继续发出原版吸金事件。
var currency_war_attack_callback: Callable
## 模式首次指定的基础间隔，供攻速提高时缩短释放动画；零表示尚未配置。
var _currency_war_base_interval: float = 0.0

## 创建正常出战时的循环动作计时器，继承场景暂停与倍速。
func ready_norm():
	super()
	attack_cd_timer = Timer.new()

	attack_cd_timer.wait_time = attack_cd
	attack_cd_timer.one_shot = false
	attack_cd_timer.autostart = true
	add_child(attack_cd_timer)
	# 连接超时信号
	attack_cd_timer.timeout.connect(_on_attack_cd_timer_timeout)


## 攻击间隔后触发执行攻击
func _on_attack_cd_timer_timeout() -> void:
	# 在这里调用实际攻击逻辑
	animation_tree.set("parameters/OneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


## 在原版释放帧吸金一次；模式存在回调时改为钱币攻击，不执行任何拾取。
func attack_once():
	if currency_war_attack_callback.is_valid():
		currency_war_attack_callback.call()
		return
	EventBus.push_event("gold_magnet_attract_once", marker_2d_coin.global_position)


## 将本实体改为模式发射；[param callback]在释放帧调用，[param interval]指定基础攻击间隔秒数。
func configure_currency_war(callback: Callable, interval: float) -> void:
	currency_war_attack_callback = callback
	_currency_war_base_interval = interval
	set_currency_war_attack_interval(interval)


## 将当前周期更新为[param interval]游戏秒，保留已完成百分比；加速释放动作以避免高攻速截断。
func set_currency_war_attack_interval(interval: float) -> void:
	if interval <= 0.0 or is_equal_approx(attack_cd, interval):
		return
	# 保存当前周期，反复同步属性不重新开始完整冷却。
	var previous_interval: float = attack_cd
	# 计时器处于准备暂停时，仍保留相同的剩余比例。
	var remaining: float = attack_cd_timer.time_left
	attack_cd = interval
	attack_cd_timer.wait_time = interval
	if not attack_cd_timer.is_stopped():
		attack_cd_timer.start(maxf(0.001, remaining * interval / previous_interval))
	animation_tree.set("parameters/TimeScale 2/scale", maxf(1.0, _currency_war_base_interval / interval))

