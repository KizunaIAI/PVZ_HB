## 中毒视觉对照预览，直接调用货币战争的大蒜附毒入口和毒伤计时。
## 展示原色、重复施毒、冰冻叠加三种情况，不保存战斗进度。
extends Node2D

## 原版普通僵尸，展示状态只播放身体动画。
const ZOMBIE: PackedScene = preload("res://scenes/character/zombie/zombie_001_norm.tscn")
## 原版大蒜，作为真实附毒回调的来源。
const GARLIC: PackedScene = preload("res://scenes/character/plant/plant_037_garlic.tscn")
## 使用游戏中的战斗控制器推进独立中毒层。
const Combat = preload("res://scripts/currency_war/currency_war_combat.gd")
## 战斗规则仅供此预览，不连接存档 Session。
const RunRules = preload("res://scripts/currency_war/currency_war_run.gd")
## 三只用于对照的僵尸。
var _zombies: Array[Zombie000Base] = []
## 美术预览的局部战斗控制器。
var _combat: Combat
## 回调中的大蒜源，不实际启用换行或啃食。
var _garlic: Plant000Base
## 自动展示时序，重播时取消旧序列。
var _sequence: Tween


## 建立三列真实角色与控制按钮，并自动播放一次中毒及到期过程。
func _ready() -> void:
	# 独立规则和空实体映射，不向正常游戏局新增单位。
	var run: RunRules = RunRules.new()
	run.phase = RunRules.Phase.BATTLE
	_combat = Combat.new()
	add_child(_combat)
	_combat.configure(run, {}, self, [], [])
	_garlic = GARLIC.instantiate() as Plant000Base
	_garlic.character_init_type = Character000Base.E_CharacterInitType.IsShow
	add_child(_garlic)
	_garlic.visible = false
	_garlic.set_meta("war_garlic_poison_damage", 10)
	# 三列统一角色和播放比例，仅叠加状态不同。
	for index: int in range(3):
		# 每列使用一只原版僵尸，足够高的预览血量用于完整展示到期恢复。
		var zombie: Zombie000Base = ZOMBIE.instantiate() as Zombie000Base
		zombie.character_init_type = Character000Base.E_CharacterInitType.IsShow
		zombie.get_node("HpComponent").max_hp = 2000
		zombie.position = Vector2(240 + index * 290, 460)
		zombie.scale = Vector2.ONE * 2.2
		add_child(zombie)
		_zombies.append(zombie)
		_add_label(["原始外观", "中毒 · 自动追加一层", "中毒＋冰冻颜色"][index], Vector2(125 + index * 290, 485), 22)
	_add_label("僵尸中毒效果", Vector2(54, 35), 32)
	_add_label("身体染绿 · 绿色气泡上升破裂 · 每秒毒伤脉冲 · 到期恢复原色", Vector2(54, 88), 19)
	_add_label("0.8 秒附毒，2.8 秒中间再次附毒；右侧 5.8 秒、中间 7.8 秒结束", Vector2(54, 124), 17)
	# 重播按钮只影响此预览序列。
	var replay: Button = Button.new()
	replay.text = "重新演示"
	replay.position = Vector2(55, 540)
	replay.size = Vector2(190, 40)
	replay.pressed.connect(_replay)
	add_child(replay)
	# 受击按钮用于直观看到闪亮槽位与中毒颜色共同生效。
	var flash: Button = Button.new()
	flash.text = "受击闪亮"
	flash.position = Vector2(270, 540)
	flash.size = Vector2(190, 40)
	flash.pressed.connect(_hit_flash)
	add_child(flash)
	_replay()


## [param text]为标签内容，[param at]为像素位置，[param font_size]为字号。
func _add_label(text: String, at: Vector2, font_size: int) -> void:
	# 无交互标签不阻挡预览按钮。
	var label: Label = Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("#193727"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)


## 清理旧层后重新展示；真实控制器负责每秒扣血与五秒到期。
func _replay() -> void:
	if _sequence != null and _sequence.is_valid():
		_sequence.kill()
	while not _combat._poisons.is_empty():
		_combat._release_poison_layer(_combat._poisons.size() - 1)
	_zombies[2].body.set_other_color(BodyCharacter.E_ChangeColors.IceColor, Color(0.5, 1, 1))
	_sequence = create_tween()
	_sequence.tween_interval(0.8)
	_sequence.tween_callback(_apply_first)
	_sequence.tween_interval(2.0)
	_sequence.tween_callback(_combat._on_garlic_bitten.bind(_zombies[1], _garlic))
	_sequence.tween_interval(0.4)
	_sequence.tween_callback(_hit_flash)


## 对后两列施加真实的大蒜毒伤层；第一列一直保持原始外观。
func _apply_first() -> void:
	_combat._on_garlic_bitten(_zombies[1], _garlic)
	_combat._on_garlic_bitten(_zombies[2], _garlic)


## 播放已有的受击闪亮，用于美术观察，不追加伤害。
func _hit_flash() -> void:
	_zombies[1].body.body_light()
	_zombies[2].body.body_light()
