## 吸金菇的钱币攻击弹，沿用原版追踪运动与普通承伤，不具备金币拾取或收入功能。
extends Bullet000TrackBase

## 银币、金币、钻石各自的基础伤害；装备固定攻击加成逐枚追加一次。
const COIN_DAMAGE: Array[int] = [20, 50, 500]
## 原版三种钱币图像，仅用于弹丸显示，不实例化可拾取金币。
const COIN_TEXTURES: Array[Texture2D] = [
	preload("res://assets/reanim/coin_silver_dollar.png"),
	preload("res://assets/reanim/coin_gold_dollar.png"),
	preload("res://assets/reanim/Diamond.png"),
]
## 本颗钱币类型：0银币、1金币、2钻石，由发射者按星级独立抽取。
@export_enum("银币", "金币", "钻石") var coin_kind: int = 0


## 复用原版追踪弹初始化，再显示该类型的钱币素材。
func _ready() -> void:
	super()
	(get_node("Body/BulletBody") as Sprite2D).texture = COIN_TEXTURES[clampi(coin_kind, 0, 2)]


## 返回全场可攻击敌军，沿用原版追踪弹的空中优先、靠近房子优先；没有目标时返回null。
static func select_target() -> Zombie000Base:
	# 从原版全局检测器读取可攻击者，不扩展到地下、入水等原本不可被此检测器攻击的状态。
	var selected: Zombie000Base
	# 同档位比较横坐标，保持原版猫尾草追踪目标顺序。
	var selected_in_sky: bool = false
	# 检测器已按角色去重，排除本帧刚阵亡或刚被魅惑的失效候选。
	for character: Character000Base in Global.main_game.detect_component_global.get_all_enemy_can_be_attacked():
		# 只对敌方僵尸发射，不将友军或植物加入目标。
		var enemy: Zombie000Base = character as Zombie000Base
		if not is_instance_valid(enemy) or enemy.is_death or enemy.is_hypno:
			continue
		# 原版空中优先规则不改变僵尸血量或钱币伤害。
		var in_sky: bool = enemy.curr_be_attack_status == Zombie000Base.E_BeAttackStatusZombie.IsSky
		if selected == null or (in_sky and not selected_in_sky) or (in_sky == selected_in_sky and enemy.global_position.x < selected.global_position.x):
			selected = enemy
			selected_in_sky = in_sky
	return selected


## 按[param delta]游戏秒追踪目标；敌人死亡或被魅惑后重选，无敌人时停留等待，不跟随鼠标。
func _physics_process(delta: float) -> void:
	if not is_instance_valid(target_enemy) or target_enemy.is_death or target_enemy.is_hypno:
		target_enemy = select_target()
		if target_enemy == null:
			return
		movement_component.reset_track_movement(true, true, target_enemy.hurt_box_component.global_position)
		_try_attack_target_if_already_overlapping()
		if is_queued_for_deletion():
			return
	else:
		movement_component.reset_track_movement(true, false, target_enemy.hurt_box_component.global_position)
	movement_component.physics_process_bullet_move(delta)
	if global_position.distance_to(start_pos) > max_distance:
		queue_free()


## 原版追踪弹只命中锁定者；[param area]对应敌人阵亡或被魅惑时不再造成伤害。
func _on_area_2d_attack_area_entered(area: Area2D) -> void:
	if not is_instance_valid(target_enemy) or target_enemy.is_death or target_enemy.is_hypno:
		return
	super(area)
