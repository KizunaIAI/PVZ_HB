## 货币战争特殊豌豆：保留原版直线移动、命中与破军计算，仅补充已定义的冰冻和范围命中能力。
extends BulletLinear000Base

## 命中后的冰减速剩余速度倍率；1表示无减速，不影响普通子弹。
var slow_factor: float = 1.0
## 冰减速持续游戏秒，沿用原版寒冰豌豆的持续时间。
var slow_seconds: float = 3.0
## 冰球定身秒数；0表示不冰冻，已定义冰球使用1秒。
var freeze_seconds: float = 0.0
## 范围命中的世界坐标半径；零向量表示普通单体命中，实际尺寸由规则层按草坪格子传入。
var splash_radius: Vector2 = Vector2.ZERO
## 弹丸显示倍率，仅放大本体，不额外扩大首次命中的碰撞盒。
var visual_scale: float = 1.0
## 可选弹丸着色，透明表示保留原版外观，紫球与冰球只修改视觉。
var pea_tint: Color = Color.TRANSPARENT


## 子节点就绪后调整本体显示，不改变原版运动速度和攻击距离。
func _ready() -> void:
	super()
	body.scale *= visual_scale
	if pea_tint.a > 0.0:
		# 只为当前弹丸创建材质，避免同场其他普通豌豆被共享材质染色。
		var tint: ShaderMaterial = ShaderMaterial.new()
		tint.shader = preload("res://shaders/my_shader/currency_war_pea.gdshader")
		tint.set_shader_parameter("pea_tint", pea_tint)
		body.material = tint
		# 本体精灵显式继承父材质，不修改原版共享纹理。
		for item: Node in body.find_children("*", "CanvasItem", true, false):
			item.use_parent_material = true


## 对[param zombie]施加直接或范围伤害，范围包含命中对象一次；冰球不附带原版冰冻的额外20点伤害。
func _attack_zombie(zombie: Zombie000Base) -> void:
	if splash_radius.x > 0.0 and splash_radius.y > 0.0:
		# 在命中时读取实际敌人列表，不让发射后出生的有效敌人漏掉范围伤害。
		var enemies: Array = Global.main_game.zombie_manager.all_zombies_1d.duplicate()
		# 范围以实际命中僵尸受击中心为原点，避免子弹前缘偏移导致直接目标漏判。
		var impact: Vector2 = zombie.hurt_box_component.global_position
		# 同一敌人只遍历一次，保留阵营、死亡与可攻击状态过滤。
		for enemy: Zombie000Base in enemies:
			if not is_instance_valid(enemy) or enemy.is_death or enemy.is_hypno or not enemy.curr_be_attack_status & can_attack_zombie_status:
				continue
			# 按两个轴的实际格子尺寸换算距离，其他行也可在范围内受到伤害。
			var offset: Vector2 = (enemy.hurt_box_component.global_position - impact) / splash_radius
			if offset.length_squared() <= 1.0:
				super(enemy)
		return
	super(zombie)
	if zombie.is_death or zombie.hp_component.curr_hp_armor2 > 0:
		return
	if slow_factor < 1.0:
		zombie.be_ice_decelerate(slow_seconds, slow_factor)
	if freeze_seconds > 0.0:
		zombie.be_ice_freeze(freeze_seconds, slow_seconds, 0)
