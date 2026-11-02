## 播放用户视频的入场、待机、技能及退场；仅在原视频钢盆离手后接管独立飞行道具。
## 人物动作与眨眼均保留原帧，离手帧、尺寸和位置由同一素材处理流程生成。
extends Node2D

## 入场完成并切入待机时发出。
signal entrance_finished
## 入场开始叉腰的帧发出一次，正式Boss据此接入背景音乐。
signal entrance_music_cue
## 退场完整播放并隐藏外观时发出，宿主可安全释放角色。
signal exit_finished
## 当前阶段改变时发出；[param value]为 idle、entrance、exit、prepare、dream、retaliate、token、summon、lane_dive 或 lane_emerge。
signal phase_changed(value: StringName)
## 原视频钢盆离手时发出；[param attacker]为锁定目标，Boss指植物、伙伴指敌方僵尸，已移除时为 null。
signal basin_released(attacker: Node2D)
## 钢盆抵达锁定落点时发出；[param attacker]已移除时为 null，宿主负责伤害。
signal basin_arrived(attacker: Node2D)
## 投掷视频及独立盆均播放完毕，已回到普通待机时发出。
signal attack_finished
## 幻想上完整播放结束，宿主可在此主动衔接幻想下。
signal dream_finished
## 新技能关键帧触发；[param action]为 token 或 summon，每次播放只发出一次。
signal skill_triggered(action: StringName)
## 下潜结束、角色完全隐藏时通知宿主换行，然后自动播放出水。
signal lane_submerged
## 新技能完整播放并返回待机时发出。
signal skill_finished

## 由原视频处理脚本生成的动作帧与原盆像素中心，不重复人工填写偏移。
const CUES: Resource = preload("res://animation/character/zombie_boss/da_fei_yu/da_fei_yu_video_cues.tres")
## 独立盆飞行时长，单位为原速游戏秒；个体冻结和减速同步影响此进度。
@export_range(0.1, 3.0, 0.01) var flight_duration: float = 0.72
## 抛物线最高点相对直线路径的抬升，单位为世界像素。
@export_range(0.0, 200.0, 1.0) var flight_arc_height: float = 48.0
## 当前动作阶段，供 Boss 的待机计时和预览读取。
var phase: StringName = &"idle"
## 离手瞬间采样的世界落点，目标移开后不继续追踪。
var flight_end_global: Vector2
## 全部视频帧的原生播放器。
@onready var sprite: AnimatedSprite2D = $Sprite
## 从原视频离手帧直接裁出的钢盆，贴图已包含该帧的透视和朝向。
@onready var basin: Sprite2D = $Basin
## 本次钢盆锁定目标的弱引用，Boss指植物、伙伴指敌方僵尸，不阻止目标释放。
var _source_plant: WeakRef
## 攻击者最后有效的世界位置，离手前移除时作为落点回退。
var _last_target_position: Vector2
## 原盆离手的世界坐标，独立于 Boss 局部缩放和朝向。
var _flight_start_global: Vector2
## 已累计的原速飞行游戏秒。
var _flight_elapsed: float = 0.0
## 个体控制倍率，0 冻结；全局倍速由 delta 和原生播放器共同继承。
var _playback_speed: float = 1.0
## 当前是否正在飞行，死亡或重播时取消。
var _flying: bool = false
## 当前反击是否已经触发离手，避免重复 frame_changed 发出多个盆。
var _released: bool = false
## 反击视频是否播放完毕，用于等待视频和道具均结束后再回待机。
var _attack_animation_done: bool = false
## 本轮新技能是否已经结算，防止重复帧通知。
var _skill_triggered: bool = false
## 本轮入场的音乐关键帧是否已触发，避免重复frame_changed重启音乐。
var _entrance_music_started: bool = false


## 独立美术及图鉴默认待机，正式 Boss 自身初始化时切换入场。
func _ready() -> void:
	sprite.animation_finished.connect(_on_animation_finished)
	sprite.frame_changed.connect(_on_frame_changed)
	play_idle()


## [param delta]为游戏帧时长；以原速进度驱动盆的世界抛物线，暂停和个体减速均可同步。
func _process(delta: float) -> void:
	if not _flying:
		return
	_flight_elapsed += delta * _playback_speed
	# 归一化飞行进度，最后一帧精确落到离手时锁定的位置。
	var progress: float = clampf(_flight_elapsed / flight_duration, 0.0, 1.0)
	basin.global_position = _flight_start_global.lerp(flight_end_global, progress) + Vector2(0.0, -flight_arc_height * sin(progress * PI))
	basin.rotation = -TAU * progress
	if progress >= 1.0:
		_flying = false
		basin.hide()
		basin_arrived.emit(_get_attacker())
		_finish_attack_if_ready()


## 从入场原视频首帧开始，取消上一动作的独立道具。
func play_entrance() -> void:
	_cancel_flight()
	_entrance_music_started = false
	sprite.show()
	_set_phase(&"entrance")
	sprite.play(&"entrance")
	sprite.set_frame_and_progress(0, 0.0)


## 回到原视频普通待机首帧，用于图鉴展示以及反击完成后的恢复。
func play_idle() -> void:
	_cancel_flight()
	sprite.show()
	_set_phase(&"idle")
	sprite.play(&"idle")
	sprite.set_frame_and_progress(0, 0.0)


## 从原视频首帧播放一次退场并取消旧技能；死亡退场恢复原速，避免被冻结状态卡住释放。
## 全局暂停及倍速仍由原生播放器继承；重复调用不重置已经开始的退场。
func play_exit() -> void:
	if phase == &"exit":
		return
	_cancel_flight()
	_skill_triggered = false
	_set_phase(&"exit")
	set_playback_speed(1.0)
	sprite.show()
	sprite.play(&"exit")
	sprite.set_frame_and_progress(0, 0.0)


## 播放幻想上；原视频气泡出现后才进入可被打断的 dream 阶段，未受击则仅循环最后1秒望着米饭流口水的片段。
func play_attack_1() -> void:
	_cancel_flight()
	_set_phase(&"prepare")
	sprite.play(&"dream_up")
	sprite.set_frame_and_progress(0, 0.0)


## [param attacker]是本次有效伤害来源；只锁定首次打破幻想的在树植物，返回是否开始反击。
func react_to_hit(attacker: Node2D) -> bool:
	if phase != &"dream" or not is_instance_valid(attacker) or not attacker.is_inside_tree():
		return false
	_source_plant = weakref(attacker)
	_last_target_position = attacker.global_position
	_released = false
	_attack_animation_done = false
	_set_phase(&"retaliate")
	sprite.play(&"dream_down")
	sprite.set_frame_and_progress(0, 0.0)
	return true


## 按实际显示帧触发幻想可打断与盆离手，不使用独立定时器猜测视频时间。
func _on_frame_changed() -> void:
	if phase == &"entrance" and not _entrance_music_started and sprite.frame >= int(CUES.get_meta(&"entrance_music_frame")):
		_entrance_music_started = true
		entrance_music_cue.emit()
	if phase == &"token" or phase == &"summon":
		# 本技能的零基结算帧，与原视频伸手和挥手动作同步。
		var cue: int = int(CUES.get_meta(&"token_frame" if phase == &"token" else &"summon_frame"))
		if not _skill_triggered and sprite.frame >= cue:
			_skill_triggered = true
			skill_triggered.emit(phase)
	if sprite.animation == &"dream_up" and phase == &"prepare" and sprite.frame >= int(CUES.get_meta(&"dream_ready_frame")):
		_set_phase(&"dream")
	elif sprite.animation == &"dream_down" and phase == &"retaliate" and not _released and sprite.frame >= int(CUES.get_meta(&"basin_release_frame")):
		_release_basin()


## 在第一个明确离手帧显示同像素钢盆，并采样攻击者落点；后续原视频的盆已在素材中清除。
func _release_basin() -> void:
	_released = true
	# 仍存在的真实攻击者；已移除时使用上一有效位置，不改选其他植物。
	var attacker: Node2D = _get_attacker()
	if is_instance_valid(attacker) and attacker.is_inside_tree():
		_last_target_position = attacker.global_position
	basin.position = CUES.get_meta(&"basin_release_position")
	basin.rotation = 0.0
	basin.scale = Vector2.ONE
	basin.show()
	_flight_start_global = basin.global_position
	flight_end_global = _last_target_position
	_flight_elapsed = 0.0
	_flying = true
	basin_released.emit(attacker)


## 入场自动接待机，退场结束隐藏；幻想上接流口水循环，反击等待视频和飞行都完成。
func _on_animation_finished() -> void:
	match sprite.animation:
		&"exit":
			sprite.hide()
			exit_finished.emit()
		&"token", &"summon", &"lane_emerge":
			play_idle()
			skill_finished.emit()
		&"lane_dive":
			lane_submerged.emit()
			_set_phase(&"lane_emerge")
			sprite.play(&"lane_emerge")
			sprite.set_frame_and_progress(0, 0.0)
		&"entrance":
			play_idle()
			entrance_finished.emit()
		&"dream_up":
			_set_phase(&"dream")
			sprite.play(&"dream_hold")
			dream_finished.emit()
		&"dream_down":
			_attack_animation_done = true
			_finish_attack_if_ready()


## 同时满足反击视频结束和盆已落地后，回普通待机并通知宿主重置技能间隔。
func _finish_attack_if_ready() -> void:
	if phase == &"retaliate" and _attack_animation_done and not _flying:
		play_idle()
		attack_finished.emit()


## 返回仍有效的原锁定目标；不自动改选目标、不复用上一次投掷来源。
func _get_attacker() -> Node2D:
	return _source_plant.get_ref() as Node2D if _source_plant != null else null


## 取消尚未落地的盆并清理来源，用于重播、切普通待机或死亡，避免旧回调造成伤害。
func _cancel_flight() -> void:
	_flying = false
	_released = false
	_attack_animation_done = false
	_source_plant = null
	basin.hide()


## [param value]为当前动作阶段；仅在变化时通知宿主及预览。
func _set_phase(value: StringName) -> void:
	if phase != value:
		phase = value
		$TokenText.set_emitting(value == &"token")
		phase_changed.emit(value)


## [param speed]为个体速度倍率，0 冻结，1 使用源视频帧率；同倍率驱动视频和独立盆。
func set_playback_speed(speed: float) -> void:
	_playback_speed = maxf(0.0, speed)
	sprite.speed_scale = _playback_speed
	$TokenText.set_playback_speed(_playback_speed)


## 保持当前人物画面并取消未命中的盆，用于静态头像或人工暂停展示。
func pause_animation() -> void:
	sprite.pause()
	$TokenText.set_playback_speed(0.0)
	_cancel_flight()


## [param action]为 token、summon 或 lane_dive；返回是否开始，忙碌时不抢占幻想或入场。
func play_skill(action: StringName) -> bool:
	if phase != &"idle" or action not in [&"token", &"summon", &"lane_dive"]:
		return false
	_cancel_flight()
	_skill_triggered = false
	_set_phase(action)
	sprite.play(action)
	sprite.set_frame_and_progress(0, 0.0)
	return true


## [param target]为主动投掷目标，可为空；空目标时只演出向前投掷，不结算命中。
func play_dream_down(target: Node2D = null) -> void:
	_cancel_flight()
	_source_plant = weakref(target) if is_instance_valid(target) else null
	_last_target_position = target.global_position if is_instance_valid(target) else global_position + Vector2(120.0, 0.0)
	_set_phase(&"retaliate")
	sprite.play(&"dream_down")
	sprite.set_frame_and_progress(0, 0.0)
