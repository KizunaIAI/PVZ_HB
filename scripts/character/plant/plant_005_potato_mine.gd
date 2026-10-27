## 原版土豆地雷；货币战争可显式启用爆炸后重新入土，其他模式保持原版消耗行为。
extends Plant000Base
class_name Plant005PotatoMine

## 出土后检测近身敌人的原版组件。
@onready var detect_component: DetectComponent = $DetectComponent
## 原版爆炸范围、伤害与特效组件。
@onready var bomb_component: BombComponentBase = $BombComponent
## 每次入土后的出土计时器，单位为游戏秒。
@onready var prepare_timer: Timer = $PrepareTimer

## 准备时间
@export var prepare_time := 10.0

@export_group("动画状态")
## 动画状态机在出土计时结束后进入上升与待触发状态。
@export var is_prepare_end := false
## 仅由货币战争控制器开启，避免修改原版冒险模式的一次性地雷规则。
var _currency_war_reusable: bool = false
## 未应用星级之前的原版出土时间，重复同步时不会叠乘。
var _currency_war_base_prepare_time: float = 0.0
## 未应用星级之前的原版爆炸伤害，重复同步时不会叠乘。
var _currency_war_base_damage: int = 0
## 原版特效在地雷节点内的变换，旧特效移到战场播放后用于摆正新的特效副本。
var _currency_war_effect_transform: Transform2D = Transform2D.IDENTITY


## 初始化正常出战角色
func ready_norm():
	super()
	## 土豆雷默认禁用攻击射线检测组件
	detect_component.disable_component(ComponentNormBase.E_IsEnableFactor.Prepare)
	## 默认禁用眨眼组件
	blink_component.disable_component(ComponentNormBase.E_IsEnableFactor.Prepare)

	prepare_timer.wait_time = prepare_time
	prepare_timer.start()

	if is_zombie_mode:
		prepare_timer.stop()
		_on_prepare_timer_timeout()

func ready_norm_signal_connect():
	super()
	## 准备完成后才会检测到敌人(触发爆炸\直接死亡)
	detect_component.signal_can_attack.connect(bomb_component.bomb_once)
	detect_component.signal_can_attack.connect(character_death)

	## 角色速度改变
	signal_update_speed.connect(update_prepare_speed)

## 亡语
func death_language():
	bomb_component.judge_death_bomb()

## 土豆类出土动画结束调用
func _rise_end():
	if _currency_war_reusable:
		# 本轮完成出土后才解除已经爆炸标记，地下等待期间不能被检测回调再次引爆。
		bomb_component.is_bomb = false
		bomb_component.is_auto_bomb_in_death = true
		blink_component.enable_component(ComponentNormBase.E_IsEnableFactor.Prepare)
		detect_component.enable_component(ComponentNormBase.E_IsEnableFactor.Prepare)
		return
	detect_component.enable_component(ComponentNormBase.E_IsEnableFactor.Prepare)
	blink_component.enable_component(ComponentNormBase.E_IsEnableFactor.Prepare)
	bomb_component.is_auto_bomb_in_death = true

## 准备时间结束
func _on_prepare_timer_timeout() -> void:
	is_prepare_end = true

## 将出土时间改为[param new_prepare_time]游戏秒并重新计时。
func set_prepare_time(new_prepare_time:float):
	prepare_time = new_prepare_time
	prepare_timer.wait_time = prepare_time
	prepare_timer.start()

## 使用[param speed_factor]调整剩余出土时间，零表示暂停，沿用原版速度因素。
func update_prepare_speed(speed_factor:float):
	if not prepare_timer.is_stopped():
		if speed_factor == 0:
			prepare_timer.paused = true
		else:
			prepare_timer.paused = false
			prepare_timer.start(prepare_timer.time_left / speed_factor)


## 按最新大纲2.3为[param star]星开启重复入土地雷；出土时间倍率1/0.5/0.2，伤害倍率1/1.5/2.5。
func configure_currency_war(star: int) -> void:
	if not _currency_war_reusable:
		_currency_war_reusable = true
		_currency_war_base_prepare_time = prepare_time
		_currency_war_base_damage = bomb_component.bomb_value
		# 只取消检测触发的自我死亡，真实被僵尸吃掉时仍正常死亡并从本局移除。
		if detect_component.signal_can_attack.is_connected(character_death):
			detect_component.signal_can_attack.disconnect(character_death)
		bomb_component.signal_bomb_once.connect(_on_currency_war_bomb)
		if bomb_component is BombComponentNorm:
			_currency_war_effect_transform = bomb_component.bomb_effect.transform
	# 升星时保留当前出土进度，不在每次买牌或刷新UI时重启计时。
	var previous_time: float = prepare_time
	# 星级由本局规则限定为1至3，边界保护避免读到非法存档索引。
	var index: int = clampi(star - 1, 0, 2)
	prepare_time = _currency_war_base_prepare_time * [1.0, 0.5, 0.2][index]
	bomb_component.bomb_value = roundi(_currency_war_base_damage * [1.0, 1.5, 2.5][index])
	if not is_equal_approx(previous_time, prepare_time):
		if not prepare_timer.is_stopped() and previous_time > 0.0:
			prepare_timer.start(prepare_time * prepare_timer.time_left / previous_time)
		prepare_timer.wait_time = prepare_time


## 本次爆炸后保留地雷实体与血量，停止攻击检测并重新进入地下等待；不会发出角色死亡信号。
func _on_currency_war_bomb() -> void:
	if not _currency_war_reusable or is_death:
		return
	detect_component.disable_component(ComponentNormBase.E_IsEnableFactor.Prepare)
	blink_component.disable_component(ComponentNormBase.E_IsEnableFactor.Prepare)
	bomb_component.is_auto_bomb_in_death = false
	is_prepare_end = false
	# 原版爆炸特效会移出地雷播放并自行释放，为下一次爆炸建立新的独立特效。
	if bomb_component is BombComponentNorm and is_instance_valid(bomb_component.bomb_effect):
		# 仅复制特效的脚本与子节点，不复制旧播放过程中的信号连接。
		var effect: BombEffectBase = bomb_component.bomb_effect.duplicate(Node.DUPLICATE_SCRIPTS) as BombEffectBase
		effect.transform = _currency_war_effect_transform
		effect.hide()
		# 粒子副本不能在等待期间自行播放，下一次引爆时由原版特效脚本启动。
		var particles: GPUParticles2D = effect.get_node("GPUParticles2D") as GPUParticles2D
		particles.emitting = false
		bomb_component.add_child(effect)
		bomb_component.bomb_effect = effect
	prepare_timer.start(prepare_time)
	call_deferred("_currency_war_rebury_animation")


## 在当前动画更新结束后切回原版地下闪灯姿态，不创建新地雷、不恢复血量。
func _currency_war_rebury_animation() -> void:
	if is_death:
		return
	# 复用原版状态机，地面等待结束后仍由原版出土动画开启检测。
	var playback: AnimationNodeStateMachinePlayback = get_node("AnimationTree").get("parameters/AnimationNodeStateMachine/playback")
	playback.start("PotatoMine_light", true)
