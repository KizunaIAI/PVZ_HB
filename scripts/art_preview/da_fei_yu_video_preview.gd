## 用户视频接入的美术预览：对比放大与游戏比例的入场、待机、幻想及独立盆接棒。
extends Node2D

## 放大展示实例，便于检查原视频动作与透明边缘。
@onready var full_visual: Node2D = $Full
## 正式游戏缩放实例，便于核对脚底与实际大小。
@onready var game_visual: Node2D = $GameScale
## 播放状态文字，用于说明当前动作阶段。
@onready var status_label: Label = $Interface/Status
## 预览暂停状态，不改变游戏本身的暂停设置。
var _paused: bool = false
## 预览是否使用半速，初始正常播放。
var _half_speed: bool = false


## 建立预览按钮，并同时从原视频入场首帧开始。
func _ready() -> void:
	$Interface/Entrance.pressed.connect(_play_entrance)
	$Interface/Idle.pressed.connect(_play_idle)
	$Interface/Pause.pressed.connect(_toggle_pause)
	$Interface/Half.pressed.connect(_toggle_half)
	$Interface/Dream.pressed.connect(_play_dream)
	$Interface/BreakDream.pressed.connect(_break_dream)
	full_visual.entrance_finished.connect(_on_entrance_finished)
	full_visual.phase_changed.connect(_on_phase_changed)
	$Interface/Token.pressed.connect(_play_skill.bind(&"token"))
	$Interface/Lane.pressed.connect(_play_skill.bind(&"lane_dive"))
	$Interface/Summon.pressed.connect(_play_skill.bind(&"summon"))
	$Interface/Exit.pressed.connect(_play_exit)
	if OS.get_cmdline_user_args().has("--showcase-music"):
		full_visual.entrance_music_cue.connect(_play_boss_music)
	_play_entrance()
	if OS.get_cmdline_user_args().has("--showcase-token"):
		_play_idle()
		_play_skill(&"token")
	if OS.get_cmdline_user_args().has("--showcase-exit"):
		_play_exit()
	if OS.get_cmdline_user_args().has("--showcase-skills"):
		_play_idle()
		_play_skill(&"token")
		await full_visual.skill_finished
		# 等待同帧的游戏比例实例也完成，避免抢占其结束回调。
		await get_tree().process_frame
		_play_skill(&"lane_dive")
		await full_visual.skill_finished
		# 等待同帧的游戏比例实例也完成，避免抢占其结束回调。
		await get_tree().process_frame
		_play_skill(&"summon")
	if OS.get_cmdline_user_args().has("--showcase-dream"):
		_play_dream()
		await get_tree().create_timer(7.0).timeout
		_break_dream()


## 同时重播两种缩放的入场，完整播放后自动进入待机。
func _play_entrance() -> void:
	full_visual.play_entrance()
	game_visual.play_entrance()
	status_label.text = "入场播放一次 → 待机循环"


## 两种缩放同时切换至待机首帧。
func _play_idle() -> void:
	full_visual.play_idle()
	game_visual.play_idle()
	status_label.text = "待机循环 · 使用原视频内的眨眼和表情"


## 两个缩放同时播放退场，完成后隐藏，使用用户原视频的转身和下潜过程。
func _play_exit() -> void:
	full_visual.play_exit()
	game_visual.play_exit()
	_update_speed()
	status_label.text = "退场播放一次 → 完整下潜后隐藏"


## 仅显式音乐预览调用，使用与正式Boss相同的播放及离场恢复逻辑。
func _play_boss_music() -> void:
	preload("res://scripts/character/zombie_boss/da_fei_yu_boss_music.gd").acquire(self)
	status_label.text = "叉腰 · 开始播放《肥鱼摸鱼曲》"


## 入场结束后提示已经自动切换到待机，不额外重新播放动画。
func _on_entrance_finished() -> void:
	status_label.text = "已自动切入待机循环"


## 播放幻想上，完成后保持原视频末段，等待点击打破幻想。
func _play_dream() -> void:
	full_visual.play_attack_1()
	game_visual.play_attack_1()


## 两个可视落点模拟不同距离的攻击植物，仅供美术预览，不结算伤害。
func _break_dream() -> void:
	full_visual.react_to_hit($FullTarget)
	game_visual.react_to_hit($GameTarget)


## [param value]为当前动作阶段，提示什么时候可以打破幻想。
func _on_phase_changed(value: StringName) -> void:
	match value:
		&"prepare": status_label.text = "幻想上 · 等待气泡出现"
		&"dream": status_label.text = "幻想中 · 可点击打破幻想"
		&"retaliate": status_label.text = "幻想下 · 离手后原盆飞向植物落点"
		&"idle": status_label.text = "普通待机"


## 只暂停当前预览实例，保留当前帧和播放进度。
func _toggle_pause() -> void:
	_paused = not _paused
	_update_speed()


## 在原速与半速之间切换，暂停状态下不恢复播放。
func _toggle_half() -> void:
	_half_speed = not _half_speed
	_update_speed()


## 将预览暂停、半速设置同步到两个实例。
func _update_speed() -> void:
	# 速度以原视频 24 帧每秒为基准。
	var speed: float = 0.0 if _paused else (0.5 if _half_speed else 1.0)
	full_visual.set_playback_speed(speed)
	game_visual.set_playback_speed(speed)


## [param action]为新技能视频；仅展示原帧，不修改正式玩家阳光或生成战斗实体。
func _play_skill(action: StringName) -> void:
	full_visual.play_skill(action)
	game_visual.play_skill(action)
	status_label.text = {&"token": "Token来 · 伸手时偷取阳光", &"lane_dive": "换行 · 下潜后换行，再播放出水", &"summon": "召唤 · 挥手时消耗偷来的阳光"}.get(action, "技能预览")
