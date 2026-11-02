## 大肥鱼召唤僵尸的脚底法阵，仅播放显示，不改变出生、伤害或管理器登记。
extends Node2D

## 亮起到消失的原速游戏秒。
const DURATION: float = 1.45
## 已累计原速游戏秒，随宿主控制倍率推进。
var _elapsed: float = 0.0
## 正式使用时的僵尸宿主，美术预览可为空。
var _target: Zombie000Base
## 独立材质，避免多个僵尸互相改动法阵进度。
var _material: ShaderMaterial


## 放在身体后方，复制实例材质，并在宿主死亡时立即清理。
func _ready() -> void:
	z_index = -2
	_target = get_parent() as Zombie000Base
	_material = $Circle.material.duplicate() as ShaderMaterial
	$Circle.material = _material
	if is_instance_valid(_target):
		_target.signal_character_death.connect(queue_free)
	_material.set_shader_parameter(&"opacity", 0.0)


## [param delta]为游戏帧秒数；快速亮起，尾段淡出，到期释放，正常继承树暂停。
func _process(delta: float) -> void:
	# 正式僵尸的个体控制倍率，纯美术预览使用原速。
	var speed: float = GlobalUtils.get_dic_product(_target.influence_speed_factors) if is_instance_valid(_target) else 1.0
	_elapsed += delta * speed
	if _elapsed >= DURATION:
		queue_free()
		return
	# 约0.1秒亮起、最后0.55秒淡出。
	var opacity: float = smoothstep(0.0, 0.1, _elapsed) * (1.0 - smoothstep(0.9, DURATION, _elapsed))
	_material.set_shader_parameter(&"elapsed", _elapsed)
	_material.set_shader_parameter(&"opacity", opacity)
