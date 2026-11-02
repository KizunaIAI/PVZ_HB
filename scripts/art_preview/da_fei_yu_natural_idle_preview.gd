## 大肥鱼自然待机对照：左侧戴盆站立，右侧端盆幻想，均使用游戏内的同一份美术资源。
extends Node2D

## 左侧站立动画播放器，复用已接入钢盆场景。
@onready var standing_player: AnimationPlayer = $Standing/AnimationPlayer
## 右侧完整动作控制器，取盆后保持自然端盆循环。
@onready var dreaming: Node2D = $Dreaming


## 播放两种待机，并允许从相同起点重播。
func _ready() -> void:
	$Interface/Replay.pressed.connect(_replay)
	_replay()


## 重置两种待机起点；右侧取盆动画完成后持续展示端盆呼吸，不触发战斗。
func _replay() -> void:
	standing_player.play(&"idle")
	standing_player.seek(0.0, true)
	dreaming.play_dream_idle()
