## 大肥鱼 Boss 的首版战斗接入：复用僵尸生命、检测和管理器登记，原地幻想并对真实攻击者丢盆。
## 当前仅开放图鉴和开发者召唤，不进入随机波次；动作继续使用用户确认的独立美术场景。
extends Zombie000Base

## 丢盆命中造成的普通伤害，可在 Boss 场景中调整；暂定 100。
@export_range(0, 10000, 1) var basin_damage: int = 100
## 丢盆落点与目标当前脚底的最大命中距离，单位为世界像素，允许移动植物躲开。
@export_range(1, 200, 1) var basin_hit_radius: float = 45.0
## 出场先完整播放普通待机，再进入攻击动作1；持续游戏秒数，默认一轮十二秒。
@export_range(0.1, 30.0, 0.1) var dream_delay: float = 12.0
## 丢盆后的恢复间隔，单位为游戏秒；初版结束后补回盆再进入下一轮幻想。
@export_range(0.1, 30.0, 0.1) var recovery_duration: float = 3.0
## 本次子弹同步受击期间的来源；不用于猜测或搜索附近植物。
var _damage_source: Character000Base
## 当前个体动作倍率，供阶段切换后新建立的 Tween 继续沿用冰冻或减速状态。
var _action_speed: float = 1.0
## 独立动作容器，内含所有关键姿势与抛盆道具。
@onready var visual: Node2D = $Body/DaFeiYuVisual
## 幻想启动及恢复时使用的单次计时器，继承游戏暂停和时间倍率。
@onready var action_timer: Timer = $ActionTimer


## 建立头部引用并初始化原版组件；独立动作只在角色入树完成后启动。
func _ready() -> void:
	head1_path_candidate = [NodePath("Body/DaFeiYuVisual/Standing/Rig/Skeleton2D/Head")]
	super._ready()
	action_timer.timeout.connect(_on_action_timer)
	visual.basin_arrived.connect(_on_basin_arrived)
	hp_component.set_death_hp(0)
	hp_stage_change_component.boundary_value_hp = [0]
	hp_stage_change_component.body_change = [null]
	if character_init_type == E_CharacterInitType.IsNorm:
		hp_component.show()
		action_timer.start(dream_delay)


## 保留原版生命、行和管理器信号，关闭走路与啃食；该 Boss 初版只使用定向丢盆。
func ready_norm() -> void:
	super.ready_norm()
	move_component.disable_component(ComponentNormBase.E_IsEnableFactor.Character)
	attack_component.disable_component(ComponentNormBase.E_IsEnableFactor.Character)


## [param source] 为当前子弹的发射者；null 清除本次来源，死亡或非植物来源不反击。
func set_damage_source(source: Character000Base) -> void:
	_damage_source = source


## [param attack_value]为本次伤害，[param bullet_mode]保留普通、穿透等结算规则。
## [param is_drop]与[param trigger_be_attack_SFX]沿用原版接口；致死时先走死亡流程，不再反击。
func be_attacked_bullet(attack_value: int, bullet_mode: BulletRegistry.AttackMode = BulletRegistry.AttackMode.Norm, is_drop: bool = true, trigger_be_attack_SFX := true):
	if is_death:
		return
	super.be_attacked_bullet(attack_value, bullet_mode, is_drop, trigger_be_attack_SFX)
	if not is_death and attack_value > 0 and is_instance_valid(_damage_source) and _damage_source is Plant000Base and not _damage_source.is_death:
		visual.react_to_hit(_damage_source)


## 普通待机结束后播放攻击动作1；抛盆恢复结束则先返回普通待机，不直接重复攻击姿势。
func _on_action_timer() -> void:
	if is_death:
		return
	if visual.phase == &"recover":
		visual.reset_idle()
		action_timer.start(dream_delay)
	else:
		visual.play_attack_1()


## [param attacker]为打破气泡的植物；落点采样后移动或移除的植物不会在远处被追伤。
func _on_basin_arrived(attacker: Node2D) -> void:
	if is_death or character_init_type != E_CharacterInitType.IsNorm:
		return
	if is_instance_valid(attacker) and attacker is Plant000Base and not attacker.is_death:
		# 动作锁定的落点转换为世界坐标，不能把 Boss 的局部缩放当作命中距离。
		var landing: Vector2 = visual.to_global(visual.flight_end)
		if attacker.global_position.distance_to(landing) <= basin_hit_radius:
			attacker.be_attacked_bullet(basin_damage, BulletRegistry.AttackMode.Norm, true, false)
	action_timer.start(recovery_duration)


## 死亡登记沿用僵尸管理器，取消所有动作和回调后淡出；重复调用不重复扣数量。
func character_death() -> void:
	if is_death:
		return
	super.character_death()
	action_timer.stop()
	visual.reset_idle()
	visual.standing_player.pause()
	visual.hold_idle_player.pause()
	visual.set_blink_speed(0.0)
	visual.set_process(false)
	_fade_and_remove()


## 开发者清场或直接删除时先正常登记死亡，再释放；不提前置死而跳过管理器扣数。
func character_death_disappear() -> void:
	if not is_death:
		hp_component.Hp_loss_death(false)
	queue_free()


## [param _delta]为游戏帧时长；阶段切换会重建 Tween，每帧同步当前控制倍率。
func _process(_delta: float) -> void:
	if is_death:
		return
	if visual.action_tween != null and visual.action_tween.is_valid():
		visual.action_tween.set_speed_scale(_action_speed)


## [param value]为总速度倍率，[param factor]为控制来源；同步冻结独立动作及恢复计时。
func update_speed_factor(value: float, factor: E_Influence_Speed_Factor) -> void:
	if is_death:
		return
	super.update_speed_factor(value, factor)
	if not is_node_ready():
		return
	# 当前场景随机速度固定为1；冰冻与减速因素仍会影响独立动作。
	var speed_product: float = GlobalUtils.get_dic_product(influence_speed_factors)
	_action_speed = speed_product
	if visual.action_tween != null and visual.action_tween.is_valid():
		visual.action_tween.set_speed_scale(speed_product)
	visual.standing_player.speed_scale = speed_product
	visual.hold_idle_player.speed_scale = speed_product
	visual.set_blink_speed(speed_product)
	visual.set_process(not is_zero_approx(speed_product))
	action_timer.paused = is_zero_approx(speed_product)


## [param attack_value]为爆炸伤害，[param is_cherry_bomb]为原版灰烬开关；本 Boss 不套用普僵灰烬。
func be_bomb(attack_value: int, is_cherry_bomb: bool = false):
	be_attacked_bullet(attack_value, BulletRegistry.AttackMode.Penetration, false, false)


## Boss免疫击退，仍按原版受击资格正常承受伤害与其他已定义效果。
func can_be_knocked_back() -> bool:
	return false
