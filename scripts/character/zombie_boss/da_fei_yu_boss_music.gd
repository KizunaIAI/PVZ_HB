## 大肥鱼背景音乐接入：多只Boss共享播放，最后一只离场后恢复此前音乐，不覆盖已切换的新场景音乐。
extends RefCounted

## 用户提供的原始音乐，运行时复制流资源开启循环，不改写音频文件。
const TRACK: AudioStreamMP3 = preload("res://assets/audio/BGM/da_fei_yu/fei_yu_mo_yu.mp3")
## 全局BGM播放器上的共享播放上下文键，随播放器生命周期释放。
const CONTEXT: StringName = &"da_fei_yu_music_context"


## [param holder]为开始叉腰的Boss或显式美术预览；首次申请保存原音乐，多次申请不重播。
static func acquire(holder: Node) -> void:
	# 统一使用原BGM通道，保留用户音乐音量和静音设置。
	var player: AudioStreamPlayer = SoundManager.bgm_play
	# 共享上下文仅保存实例编号，不持有Boss强引用。
	var context: Dictionary = player.get_meta(CONTEXT, {})
	# 本次申请者的唯一实例编号。
	var holder_id: int = holder.get_instance_id()
	if not context.is_empty() and context.holders.has(holder_id):
		return
	if context.is_empty():
		# 独立循环流，避免修改原导入资源或其他播放器的设置。
		var stream: AudioStreamMP3 = TRACK.duplicate() as AudioStreamMP3
		stream.loop = true
		context = {"holders": [], "previous": player.stream, "position": player.get_playback_position(), "playing": player.playing, "paused": player.stream_paused, "track": stream}
		SoundManager.play_bgm(stream)
		player.stream_paused = false
	context.holders.append(holder_id)
	player.set_meta(CONTEXT, context)
	# 换行reparent会短暂离树，延后检查真实离场；保留连接，后续死亡或切场景仍需释放。
	holder.tree_exiting.connect(_release_if_outside_tree.bind(holder_id), CONNECT_DEFERRED)


## [param holder_id]触发离树后延迟核对；换行已重新入树则保留播放进度，真正移除或释放才归还音乐。
static func _release_if_outside_tree(holder_id: int) -> void:
	# 只凭实例编号查询，不持有申请者强引用，也兼容已经queue_free的节点。
	var holder: Node = instance_from_id(holder_id) as Node
	if is_instance_valid(holder) and holder.is_inside_tree():
		return
	release(holder_id)


## [param holder_id]离场时释放申请；最后一只退出且仍播放本曲时恢复此前播放位置。
static func release(holder_id: int) -> void:
	# 自动加载退出时可能已被销毁，不访问无效播放器。
	if not is_instance_valid(SoundManager) or not is_instance_valid(SoundManager.bgm_play):
		return
	# 当前BGM播放器和共享的Boss使用者列表。
	var player: AudioStreamPlayer = SoundManager.bgm_play
	# 空上下文表示此前已经完成恢复。
	var context: Dictionary = player.get_meta(CONTEXT, {})
	if context.is_empty():
		return
	context.holders.erase(holder_id)
	if not context.holders.is_empty():
		return
	player.remove_meta(CONTEXT)
	if player.stream != context.track:
		return
	player.stop()
	player.stream = context.previous
	if bool(context.playing) and player.stream != null:
		player.play(float(context.position))
	player.stream_paused = bool(context.paused)
