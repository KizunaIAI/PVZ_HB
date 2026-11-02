## 召唤动作美术预览：按真实视频关键帧展示僵尸与脚底法阵，不启动战斗或经济结算。
extends Node2D

## 正式召唤脚底法阵，与游戏内复用同一场景。
const EFFECT: PackedScene = preload("res://scenes/fx/da_fei_yu_summon_effect.tscn")
## 展示用僵尸，不注册到关卡管理器。
const ZOMBIE: PackedScene = preload("res://scenes/character/zombie/zombie_001_norm.tscn")
## Boss视频外观，关键帧通知来自正式素材时间点。
@onready var visual: Node2D = $Visual


## 从召唤动作首帧开始，按正式帧通知触发展示实体。
func _ready() -> void:
	visual.skill_triggered.connect(_on_skill_triggered)
	visual.play_skill(&"summon")


## [param action]为关键帧所属动作；仅在召唤帧同时显示三只僵尸及法阵。
func _on_skill_triggered(action: StringName) -> void:
	if action != &"summon":
		return
	$Caption.text = "3.25秒 · 尾巴翘起，同帧出现僵尸和脚底法阵"
	# 展示多个落点，实际游戏仍由Boss选择前一列随机合法行。
	for point: Vector2 in [Vector2(180, 500), Vector2(360, 440), Vector2(530, 520)]:
		# 展示状态禁用真实战斗、移动和关卡计数。
		var zombie: Zombie000Base = ZOMBIE.instantiate()
		zombie.init_zombie({Zombie000Base.E_ZInitAttr.CharacterInitType: Character000Base.E_CharacterInitType.IsShow})
		zombie.position = point
		zombie.z_index = 5
		add_child(zombie)
		# 与实战相同的脚底原点及法阵材质。
		var effect: Node2D = EFFECT.instantiate()
		zombie.add_child(effect)
		effect.global_scale = Vector2.ONE
