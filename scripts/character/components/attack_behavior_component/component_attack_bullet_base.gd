extends AttackComponentBase
## 发射子弹攻击行为基础组件
class_name AttackComponentBulletBase

@onready var animation_tree: AnimationTree = $"../AnimationTree"
## 冷却时间计时器
@onready var bullet_attack_cd_timer: Timer = $BulletAttackCdTimer

## 用检测组件对应的值赋值，仙人掌会修改值更新子弹属性
## 当前发射子弹可以攻击的敌人状态
##("1 正常", "2 悬浮", "4 地刺", "8 低矮")
var can_attack_plant_status:int = 1
##("1 正常", "2 跳跃", "4 水下", "8 空中", "16 地下")
var can_attack_zombie_status:int = 1
## 是否使用行属性进行攻击判断
var is_lane:=true

## 攻击参数,动画攻击一次的参数
@export var attack_para:StringName= &"parameters/OneShot/request"
### TODO:子弹攻击伤害(为正数时可以给子弹赋值,默认为子弹攻击力)
#@export var attack_value_bullet:int = -1
@export var attack_cd:float = 1.5
## 攻击子弹类型
@export var attack_bullet_type:BulletRegistry.BulletType = BulletRegistry.BulletType.Bullet001Pea
## 子弹生产位置
@export var markers_2d_bullet: Array[Marker2D]
@export_group("发射子弹音效")
## 攻击音效名字（发射子弹）
@export var attack_sfx:StringName = &"Throw"

## 发射一次子弹信号
signal signal_shoot_bullet
## 一次攻击动画开始时发出，货币战争按动作叠装备，不随多发子弹重复计数。
signal signal_attack_action
## 货币战争专用子弹工厂；接收原版子弹类型，返回未入树的独立实例，其他模式为空。
var currency_war_bullet_factory: Callable
## 当前攻击轮的发射倍数；原版机枪动画四次发射，模式触发八发时每次发射两颗。
var currency_war_volley_multiplier: int = 1
## 同一动画回调中额外子弹的游戏秒间隔，机枪取原发射间隔的一半；0表示沿用同帧发射。
var currency_war_extra_shot_delay: float = 0.0

## 主游戏场景子弹父节点
var bullets: Node2D
func _ready() -> void:
	super()
	bullet_attack_cd_timer.wait_time = attack_cd
	if is_instance_valid(Global.main_game):
		bullets = Global.main_game.bullets
	## 用检测组件对应的值赋值，仙人掌会修改值更新子弹属性
	can_attack_plant_status = detect_component.can_attack_plant_status
	##("1 正常", "2 跳跃", "4 水下", "8 空中", "16 地下")
	can_attack_zombie_status = detect_component.can_attack_zombie_status
	## 是否使用行属性进行攻击判断
	is_lane = detect_component.is_lane


## 角色速度修改
func owner_update_speed(speed_product:float):
	if not bullet_attack_cd_timer.is_stopped():
		if speed_product == 0:
			bullet_attack_cd_timer.paused = true
		else:
			bullet_attack_cd_timer.paused = false

			bullet_attack_cd_timer.start(bullet_attack_cd_timer.time_left / speed_product)

	bullet_attack_cd_timer.wait_time = attack_cd / speed_product

## 开始攻击
func attack_start():
	super()
	## 先随机等待一段时间调用一次攻击
	await get_tree().create_timer(randf_range(0, bullet_attack_cd_timer.wait_time/3)).timeout
	if is_attack_res:
		## 首次攻击还未使用计时器循环攻击
		if bullet_attack_cd_timer.is_stopped():
			_on_bullet_attack_cd_timer_timeout()
			bullet_attack_cd_timer.start()
	## 等待一段时间后可能为非攻击状态
	else:
		attack_end()

## 结束攻击
func attack_end():
	super()
	bullet_attack_cd_timer.stop()
	set_cancel_attack()


## 攻击间隔后触发执行攻击
func _on_bullet_attack_cd_timer_timeout() -> void:
	# 在这里调用实际攻击逻辑
	signal_attack_action.emit()
	animation_tree.set(attack_para, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func set_cancel_attack():
	#animation_tree.set(attack_para, AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)
	pass

## 动画调用发射子弹；货币战争植物的专用倍率只应用于其新发射子弹，其他模式保持原版伤害。
func _shoot_bullet():
	signal_shoot_bullet.emit()
	# 原版默认为一倍，模式八发只扩展本轮，不增加攻击动作或装备叠层次数。
	for shot: int in range(currency_war_volley_multiplier):
		if shot > 0 and currency_war_extra_shot_delay > 0.0:
			# 使用受暂停和倍速影响的计时器，把补弹插入原版两颗之间，避免八发重叠成四颗的视觉。
			await get_tree().create_timer(currency_war_extra_shot_delay, false).timeout
			if not is_instance_valid(owner) or owner.is_death or not is_enabling:
				return
		# 每个发射点独立创建子弹，保留原版方向与行号。
		for i: int in range(markers_2d_bullet.size()):
			# 模式工厂逐颗判定特殊弹，普通模式返回原版实例。
			var bullet: Bullet000Base = create_attack_bullet()
			# 原版发射参数仍决定攻击状态与实际起点。
			var bullet_paras: Dictionary = get_bullet_paras(markers_2d_bullet[i].global_position, detect_component.ray_area_direction[i])
			bullet.init_bullet(bullet_paras)
			bullets.add_child(bullet)
			play_throw_sfx()


## 返回未入树的攻击子弹，模式工厂负责特殊弹与实时伤害；原版模式保持原资源和攻击规则。
## [param shot_direction]用于裂荚区分前后脑特殊弹，普通植物默认向右。
func create_attack_bullet(shot_direction: Vector2 = Vector2.RIGHT) -> Bullet000Base:
	if currency_war_bullet_factory.is_valid():
		return currency_war_bullet_factory.call(attack_bullet_type, shot_direction)
	# 未接入模式工厂的组件仍兼容已有模式攻击元数据，不改变其他玩法。
	var bullet: Bullet000Base = Global.bullet_registry.get_bullet_scenes(attack_bullet_type).instantiate()
	if bullet is Bullet000NormBase and owner.has_meta("currency_war_attack_value"):
		bullet.attack_value = int(owner.get_meta("currency_war_attack_value"))
		bullet.set_meta("currency_war_execute", owner.get_meta("currency_war_execute", 0.0))
	elif bullet is Bullet000NormBase and owner.has_meta("currency_war_attack_multiplier"):
		bullet.attack_value = roundi(bullet.attack_value * float(owner.get_meta("currency_war_attack_multiplier")))
	return bullet


func get_bullet_paras(marker_2d_bullet_glo_pos:Vector2, ray_direction:Vector2) -> Dictionary[Bullet000NormBase.E_InitParasAttr,Variant]:
	return {
		Bullet000NormBase.E_InitParasAttr.IsActivateLane : is_lane,
		Bullet000NormBase.E_InitParasAttr.BulletLane : owner.lane,
		Bullet000NormBase.E_InitParasAttr.Position : bullets.to_local(marker_2d_bullet_glo_pos),
		Bullet000NormBase.E_InitParasAttr.Direction : ray_direction,
		Bullet000NormBase.E_InitParasAttr.CanAttackPlantState : can_attack_plant_status,
		Bullet000NormBase.E_InitParasAttr.CanAttackZombieState : can_attack_zombie_status,
		Bullet000NormBase.E_InitParasAttr.SourceCharacter : owner,
	}


func play_throw_sfx():
	## 播放音效
	SoundManager.play_character_SFX(attack_sfx)
