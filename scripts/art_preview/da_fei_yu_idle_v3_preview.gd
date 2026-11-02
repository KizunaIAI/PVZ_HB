extends Node2D
## 大肥鱼待机 v3 预览控制器。
## 同屏对比 1.0 与 0.32 两种缩放，提供暂停、半速、重播，并实时显示眨眼状态。

## 1.0 缩放实例，用于检查动作细节。
@onready var full_visual: Node2D = $StandingFull
## 0.32 缩放实例，用于核对实机可读性。
@onready var small_visual: Node2D = $StandingSmall
## 1.0 实例的播放器。
@onready var full_player: AnimationPlayer = $StandingFull/AnimationPlayer
## 0.32 实例的播放器。
@onready var small_player: AnimationPlayer = $StandingSmall/AnimationPlayer
## 状态文字，显示当前眨眼层。
@onready var state_label: Label = $Interface/StateLabel
## 半速开关，记录当前是否为半速，初值为 false。
var _half_speed: bool = false


func _ready() -> void:
	$Interface/BtnPause.pressed.connect(_on_pause_pressed)
	$Interface/BtnHalf.pressed.connect(_on_half_pressed)
	$Interface/BtnReplay.pressed.connect(_on_replay_pressed)
	full_player.play(&"idle")
	small_player.play(&"idle")


func _process(_delta: float) -> void:
	# 读取新的真实眼睑状态，旧版肤色遮盖层已移除。
	var blink: Node = full_visual.get_node_or_null("Rig/Skeleton2D/Head/Blink")
	if blink == null:
		return
	var state := "睁眼"
	if blink.eye_state == 2:
		state = "闭眼"
	elif blink.eye_state == 1:
		state = "半闭"
	state_label.text = "眨眼：%s    时间：%.2f / 12.00 秒" % [state, full_player.current_animation_position]


func _on_pause_pressed() -> void:
	# 两个实例同步暂停或继续，保持并排对比一致。
	var paused := full_player.speed_scale == 0.0
	var speed := 0.5 if _half_speed else 1.0
	full_player.speed_scale = 0.0 if paused == false else speed
	small_player.speed_scale = full_player.speed_scale


func _on_half_pressed() -> void:
	# 在 1.0 与 0.5 之间切换倍速，暂停状态保持不变。
	_half_speed = not _half_speed
	var speed := 0.5 if _half_speed else 1.0
	if full_player.speed_scale != 0.0:
		full_player.speed_scale = speed
		small_player.speed_scale = speed


func _on_replay_pressed() -> void:
	# 从头播放，并恢复为正常速度。
	full_player.speed_scale = 1.0
	small_player.speed_scale = 1.0
	_half_speed = false
	full_player.seek(0.0, true)
	small_player.seek(0.0, true)
	full_player.play(&"idle")
	small_player.play(&"idle")
