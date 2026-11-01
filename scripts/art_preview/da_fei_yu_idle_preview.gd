## 大肥鱼待机动画的独立美术预览控制器，供部件版与骨骼版共用。
## 仅控制播放、慢速和重播；角色动作保存在可编辑的 Animation 资源中。
extends Node2D

## 角色场景自带的动画播放器，用于播放四秒待机循环。
@onready var animation_player: AnimationPlayer = $Character/AnimationPlayer
## 暂停按钮，文字随播放状态切换。
@onready var pause_button: Button = $Interface/PauseButton
## 速度按钮，仅在正常速度和半速之间切换。
@onready var speed_button: Button = $Interface/SpeedButton
## 重播按钮，从待机循环起点重新开始播放。
@onready var restart_button: Button = $Interface/RestartButton


## 连接预览按钮；角色场景中的自动播放负责开始待机动画。
func _ready() -> void:
	pause_button.pressed.connect(_toggle_pause)
	speed_button.pressed.connect(_toggle_speed)
	restart_button.pressed.connect(_restart_idle)


## 暂停或继续当前动画，保留暂停位置，并同步按钮文字。
func _toggle_pause() -> void:
	if animation_player.is_playing():
		animation_player.pause()
		pause_button.text = "继续播放"
	else:
		animation_player.play(&"idle")
		pause_button.text = "暂停动画"


## 在一倍与半倍速度之间切换；不改变暂停状态或当前播放位置。
func _toggle_speed() -> void:
	if is_equal_approx(animation_player.speed_scale, 1.0):
		animation_player.speed_scale = 0.5
		speed_button.text = "播放速度：0.5×"
	else:
		animation_player.speed_scale = 1.0
		speed_button.text = "播放速度：1×"


## 从待机循环起点重新播放，保留当前速度，并退出暂停状态。
func _restart_idle() -> void:
	animation_player.play(&"idle")
	animation_player.seek(0.0, true)
	pause_button.text = "暂停动画"
