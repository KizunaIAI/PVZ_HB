## 两个新待机动作的独立预览；植物只作演示，不实例化战斗系统。
extends Node2D

## 角色美术场景，提供取盆与受击接口。
@onready var character: Node2D = $Character
## 左侧演示攻击者；钢盆落点使用此节点的实际位置。
@onready var plant: Node2D = $Plant
## 演示豌豆，仅用于显示打破气泡的来源。
@onready var pea: Node2D = $Pea
## 阶段说明文字。
@onready var status: Label = $Interface/Status
## 受击按钮，仅在幻想阶段可用。
@onready var hit_button: Button = $Interface/Hit
## 自动演示开关，手动操作后关闭。
@onready var auto_demo: CheckButton = $Interface/Auto
## 预览定时器，负责幻想停留及演示循环。
@onready var demo_timer: Timer = $DemoTimer
## 豌豆与植物反馈 Tween，重播时取消。
var preview_tween: Tween
## 当前是否已有一颗演示豌豆在飞，避免按钮重复触发。
var pea_in_flight: bool = false


## 连接预览 UI、动作阶段以及钢盆落点反馈，并启动自动展示。
func _ready() -> void:
	$Interface/Dream.pressed.connect(_manual_dream)
	hit_button.pressed.connect(_manual_hit)
	$Interface/Reset.pressed.connect(_manual_reset)
	character.phase_changed.connect(_phase_changed)
	character.basin_arrived.connect(_basin_arrived)
	demo_timer.timeout.connect(_on_demo_timeout)
	auto_demo.toggled.connect(_auto_toggled)
	_phase_changed(&"idle")
	demo_timer.start(0.8)


## 手动播放待机1，取消自动循环及飞行中的演示豌豆。
func _manual_dream() -> void:
	auto_demo.button_pressed = false
	_clear_preview()
	character.play_dream_idle()


## 手动触发待机2；先用可见豌豆打破幻想，再把植物作为攻击者传入。
func _manual_hit() -> void:
	auto_demo.button_pressed = false
	_fire_pea()


## 恢复用户微调后的戴盆待机；不改变原始角色场景。
func _manual_reset() -> void:
	auto_demo.button_pressed = false
	_clear_preview()
	character.reset_idle()


## 清理演示道具及回调，使重复播放可从干净状态开始。
func _clear_preview() -> void:
	demo_timer.stop()
	if preview_tween != null and preview_tween.is_valid():
		preview_tween.kill()
	pea.visible = false
	pea_in_flight = false
	plant.rotation = 0.0
	plant.scale = Vector2.ONE


## 从植物口部发射演示豌豆；本段不计算伤害、不产生正式子弹。
func _fire_pea() -> void:
	if character.phase != &"dream" or pea_in_flight:
		return
	pea_in_flight = true
	hit_button.disabled = true
	pea.position = plant.position + Vector2(50, -35)
	pea.visible = true
	preview_tween = create_tween()
	preview_tween.tween_property(pea, "global_position", character.to_global(Vector2(-55, -600)), 0.65)
	preview_tween.tween_callback(_pea_hit)


## 豌豆到达气泡后传入实际植物引用；视觉和目标来源保持一致。
func _pea_hit() -> void:
	pea.visible = false
	pea_in_flight = false
	character.react_to_hit(plant)


## [param phase] 为角色的新阶段；据此更新按钮、文案和自动演示间隔。
func _phase_changed(phase: StringName) -> void:
	# 每个阶段的简短中文说明，避免预览露出实现信息。
	var descriptions: Dictionary = {
		&"idle": "戴盆待机",
		&"take": "双手取盆 · 翻正端好",
		&"dream": "想吃一大盆米饭……",
		&"angry": "谁打破了我的米饭梦！",
		&"throw": "哼！接盆！",
		&"recover": "盆已丢出"
	}
	status.text = descriptions.get(phase, "")
	hit_button.disabled = phase != &"dream" or pea_in_flight
	if auto_demo.button_pressed:
		if phase == &"dream":
			demo_timer.start(2.4)
		elif phase == &"recover":
			demo_timer.start(1.5)


## [param attacker] 是实际到达的目标；演示只对同一个植物播放轻微晃动。
func _basin_arrived(attacker: Node2D) -> void:
	if attacker != plant:
		return
	preview_tween = create_tween()
	preview_tween.tween_property(plant, "rotation", -0.18, 0.08)
	preview_tween.tween_property(plant, "rotation", 0.12, 0.1)
	preview_tween.tween_property(plant, "rotation", 0.0, 0.16)


## 自动循环依次展示原始待机、取盆幻想、受击丢盆；手动关闭后不再执行。
func _on_demo_timeout() -> void:
	if not auto_demo.button_pressed:
		return
	match character.phase:
		&"idle":
			character.play_dream_idle()
		&"dream":
			_fire_pea()
		&"recover":
			_clear_preview()
			character.reset_idle()
			demo_timer.start(0.8)


## [param enabled] 控制自动展示；在当前阶段安排下一步而不打断正在播放的动作。
func _auto_toggled(enabled: bool) -> void:
	if enabled:
		demo_timer.start(1.0)
	else:
		demo_timer.stop()
