## 管理波次推进；货币战争逐只分散出怪，原版模式继续使用整波生成。
extends Node
## 僵尸波次管理器
class_name ZombieWaveManager

#region 波次管理器参数
## 是否有墓碑,即墓碑是否生成僵尸
var is_have_tombston := false
## 一轮游戏最大波次
var max_wave_one_round :int
#endregion

## 波次刷新管理器
@onready var zombie_wave_refresh_manager: ZombieWaveRefreshManager = $ZombieWaveRefreshManager
## 波次创建管理器
@onready var zombie_wave_create_manager: ZombieWaveCreateManager = $ZombieWaveCreateManager
## 每秒进度条更新计时器
@onready var every_wave_progress_timer: Timer = $EveryWaveProgressTimer

## 关卡进度条
@onready var flag_progress_bar: FlagProgressBar = %FlagProgressBar
## 大波时文字提醒
@onready var ui_remind_word: UIRemindWord = %UIRemindWord

## 大波僵尸时墓碑生产的僵尸类型
@export var zombie_type_candidate_tombstone :Array[CharacterRegistry.ZombieType] = [CharacterRegistry.ZombieType.Z001Norm]

## 当前波次类型
enum E_WaveType{
	Norm,		## 普通波
	FlagFront,	## 旗前波
	Flag,		## 旗帜波
	Final,		## 最后一波
}
var curr_wave_type:E_WaveType
## 最大波次(多轮游戏时更新最大波次)
var max_wave :int
## 当前波次
var curr_wave := -1
## 自由测试暂停自然刷新；默认关闭，仅由独立开发者工具设置，重载节点后恢复。
var developer_refresh_suspended: bool = false
## 货币战争相邻两只自然僵尸的随机出场间隔，单位为游戏秒，暂停和倍速由场景树统一控制。
@export var currency_war_spawn_interval_range: Vector2 = Vector2(0.8, 1.5)
## 货币战争每批自然僵尸的数量；一批全部出场后才进入等待清空或超时的闸门。
@export var currency_war_batch_size: int = 5
## 上一批僵尸出现后允许等待的最长游戏秒数；超时即使仍有存活也放行下一批。
@export var currency_war_batch_timeout: float = 20.0
## 当前波尚未出场的自然僵尸类型；未清空时禁止提前刷新或误判末波清场。
var _currency_war_pending_spawns: Array[CharacterRegistry.ZombieType] = []
## 分散出怪使用的单次计时器，随管理器销毁，避免换节点后旧回调继续出怪。
var _currency_war_spawn_timer: Timer
## 当前批次尚未刷出的数量；大于 0 时仍在按间隔逐只出场。
var _currency_war_batch_remaining: int = 0
## 当前批次已经出场且尚未离场的僵尸；清空后才考虑放行下一批。
var _currency_war_batch_alive: Array[Zombie000Base] = []
## 批次放行闸门计时器，从本批第一只出场开始计时。
var _currency_war_batch_timer: Timer
## 批次清空轮询计时器；只在等待本批清空时运行，避免依赖会因节点重挂触发的退出信号。
var _currency_war_gate_timer: Timer
## 当前波已经实际出场僵尸的初始总生命，包含模式初始化后的护甲和奖励关一血。
var _currency_war_wave_health: int = 0
## 排队出怪期间已经损失的生命；全部出场后带入原版残半刷新计算，避免清场伤害丢失。
var _currency_war_wave_lost_health: int = 0
## 每波进度条所占大小
var progress_bar_segment_every_wave:float
## 每段根据当前波次时间，每秒多长
var progress_bar_segment_mini_every_sec:float

## 波次刷新信号,给zombie_manager,删除魅惑僵尸，更新是否为最后一波
signal signal_wave_refresh(is_end_wave:bool)


func _ready() -> void:
	## 刷新波次信号
	zombie_wave_refresh_manager.signal_refresh.connect(start_next_wave)
	## 新波次自然刷新时间
	zombie_wave_refresh_manager.signal_norm_time.connect(update_progress_bar_segment_mini_every_sec)

## 初始化波次管理器
func init_zombie_wave_manager(game_para:ResourceLevelData):
	is_have_tombston = game_para.is_have_tombston
	max_wave_one_round = game_para.max_wave
	## 如果存在存档
	if game_para.save_game_data_main_game:
		curr_wave = game_para.save_game_data_main_game.curr_wave
		max_wave = game_para.save_game_data_main_game.curr_max_wave
	else:
		curr_wave = -1
		max_wave = game_para.max_wave

	# 货币战争每个实际波显示一面旗；其他模式保留原版十波一旗。
	flag_progress_bar.init_flag_from_wave(max_wave_one_round, 1 if game_para.game_mode == MainSceneRegistry.MainScenes.CurrencyWar else 10)
	# 一波短局也可使用原版进度条，避免分母为零。
	progress_bar_segment_every_wave = 100.0 / maxi(1, max_wave_one_round - 1)

	zombie_wave_create_manager.init_zombie_wave_create_manager(game_para)

## 多轮游戏开始下一轮僵尸波次管理器更新数据
func start_next_game_zombie_wave_mananger_update():
	max_wave += max_wave_one_round
	flag_progress_bar.start_next_game_flag_progress_bar_update()
	flag_progress_bar.visible = false
	zombie_wave_create_manager.update_zombie_refresh_types()

## 计算当前进度并更新进度条
func set_progress_bar(curr_flag:int=-1):
	# 一波短局刷出唯一波时已完成刷新进度，清场仍由僵尸管理器判断。
	var curr_progress: float = 100.0 if max_wave_one_round == 1 else curr_wave % max_wave_one_round * progress_bar_segment_every_wave
	flag_progress_bar.set_progress(curr_progress, curr_flag)

## 开始第一波
func start_first_wave():
	# 首波等待可能在打开开发者模式前已经开始，计时结束后仍须拦截整套首波流程。
	if developer_refresh_suspended:
		return
	start_next_wave()
	every_wave_progress_timer.start()
	flag_progress_bar.visible = true

## 开始刷新下一波,发射刷新下一波信号
func start_next_wave() -> void:
	if developer_refresh_suspended or has_pending_spawns():
		return
	if curr_wave >= max_wave - 1:
		return
	curr_wave += 1
	if zombie_wave_create_manager.zombie_manager.game_para.game_mode == MainSceneRegistry.MainScenes.CurrencyWar:
		_start_currency_war_wave()
		return
	# 本波的真实敌人列表，短局末波与原版旗帜波共用后续血量和清场同步。
	var curr_wave_all_zombies:Array[Zombie000Base]
	# 非十波整组的最后一波直接结束刷新，不额外插入旗帜僵尸或特殊大波。
	if curr_wave == max_wave - 1 and curr_wave % 10 != 9:
		curr_wave_type = E_WaveType.Final
		curr_wave_all_zombies = zombie_wave_create_manager.create_curr_wave_all_zombies(curr_wave, false)
		set_progress_bar()
	## 旗前波
	elif curr_wave % 10 == 8:
		curr_wave_type = E_WaveType.FlagFront
		curr_wave_all_zombies = zombie_wave_create_manager.create_curr_wave_all_zombies(curr_wave, false)
	## 旗帜波
	elif curr_wave % 10 == 9 :
		## 最后一波
		if curr_wave == max_wave - 1:
			curr_wave_type = E_WaveType.Final
			await ui_remind_word.zombie_approach(true)
			curr_wave_all_zombies = zombie_wave_create_manager.create_curr_wave_all_zombies(curr_wave, true)
			set_progress_bar(int(curr_wave%max_wave_one_round/10.0))
			## 额外生成大波特殊僵尸,珊瑚僵尸,蹦极僵尸
			zombie_wave_create_manager.spawn_special_zombie_in_big_wave(true)

		else:
			curr_wave_type = E_WaveType.Flag
			await ui_remind_word.zombie_approach(false)
			curr_wave_all_zombies = zombie_wave_create_manager.create_curr_wave_all_zombies(curr_wave, true)
			set_progress_bar(int(curr_wave%max_wave_one_round/10.0))
			## 额外生成大波特殊僵尸,珊瑚僵尸,蹦极僵尸
			zombie_wave_create_manager.spawn_special_zombie_in_big_wave(false)

		## 如果有墓碑
		if is_have_tombston:
			call_tombstone_create_zombie()

	## 普通波
	else:
		curr_wave_type = E_WaveType.Norm
		curr_wave_all_zombies = zombie_wave_create_manager.create_curr_wave_all_zombies(curr_wave, false)
		set_progress_bar()

	var wave_all_hp := 0
	for zombie:Zombie000Base in curr_wave_all_zombies:
		## 波次生成的僵尸额外连接掉血信号,旗前波死亡触发信号
		zombie.signal_zombie_hp_loss.connect(zombie_wave_refresh_manager.judge_half_refresh)
		wave_all_hp += zombie.hp_component.get_all_hp()

	zombie_wave_refresh_manager.update_wave_health_data(wave_all_hp, curr_wave_type, curr_wave)

	signal_wave_refresh.emit(curr_wave == max_wave - 1)


## 返回当前波是否仍有待出场的僵尸；供原版死亡和魅惑清场判定查询，不把未出场单位计入真实僵尸数量。
func has_pending_spawns() -> bool:
	return not _currency_war_pending_spawns.is_empty()


## 取消尚未出场的自然僵尸；开发者模式或场景切换前调用时不补刷、不结算奖励。
func cancel_pending_spawns() -> void:
	_currency_war_pending_spawns.clear()
	if is_instance_valid(_currency_war_spawn_timer):
		_currency_war_spawn_timer.stop()
	# 取消后不能留下批次状态，否则旧僵尸离场会把下一波误判成需要放行。
	_currency_war_batch_alive.clear()
	_currency_war_batch_remaining = 0
	if is_instance_valid(_currency_war_batch_timer):
		_currency_war_batch_timer.stop()
	if is_instance_valid(_currency_war_gate_timer):
		_currency_war_gate_timer.stop()


## 开始当前货币战争波次，保留既有数量与随机池，先出第一只，之后按游戏时间逐只出场。
func _start_currency_war_wave() -> void:
	curr_wave_type = E_WaveType.Final if curr_wave == max_wave - 1 else E_WaveType.Norm
	_currency_war_pending_spawns = zombie_wave_create_manager.create_curr_wave_zombie_list(curr_wave, false)
	_currency_war_wave_health = 0
	_currency_war_wave_lost_health = 0
	zombie_wave_create_manager.wave_all_zombies.clear()
	# 整波尚未出完时不启动下一波计时，也不让清掉首批僵尸触发残半刷新。
	zombie_wave_refresh_manager.curr_can_refresh_type = ZombieWaveRefreshManager.E_RefreshType.Null
	zombie_wave_refresh_manager.curr_refresh_status = ZombieWaveRefreshManager.E_RefreshStatus.DisableRefresh
	zombie_wave_refresh_manager.wave_min_time_timer.stop()
	zombie_wave_refresh_manager.wave_norm_refresh_timer.stop()
	if not is_instance_valid(_currency_war_spawn_timer):
		_currency_war_spawn_timer = Timer.new()
		_currency_war_spawn_timer.one_shot = true
		add_child(_currency_war_spawn_timer)
		_currency_war_spawn_timer.timeout.connect(_spawn_next_currency_war_zombie)
	set_progress_bar(curr_wave)
	signal_wave_refresh.emit(curr_wave == max_wave - 1)
	# 换波时清掉上一波的批次状态，避免旧僵尸离场触发新波放行。
	_currency_war_batch_alive.clear()
	_currency_war_batch_remaining = 0
	if is_instance_valid(_currency_war_gate_timer):
		_currency_war_gate_timer.stop()
	_open_currency_war_batch()


## 每次只创建一只自然僵尸；选行、初始化、奖励关生命与死亡信号均继续复用原版工厂。
func _spawn_next_currency_war_zombie() -> void:
	if developer_refresh_suspended:
		cancel_pending_spawns()
		return
	if not has_pending_spawns():
		return
	# 从本波已经抽定的清单取一只，间隔不改变总数量或类型概率。
	var zombie_type: CharacterRegistry.ZombieType = _currency_war_pending_spawns.pop_front()
	# 按原版行权重分配到当前开放且地形适配的行。
	var lane: int = zombie_wave_create_manager.zombie_choose_row_system.select_spawn_row(Global.character_registry.get_zombie_info(zombie_type, CharacterRegistry.ZombieInfoAttribute.ZombieRowType))
	# 创建完成后再读取真实生命，包含模式在ready期间应用的生命和护甲修正。
	var zombie: Zombie000Base = zombie_wave_create_manager.wave_create_zombie(zombie_type, lane, curr_wave)
	zombie_wave_create_manager.wave_all_zombies.append(zombie)
	_currency_war_wave_health += zombie.hp_component.get_all_hp()
	zombie.signal_zombie_hp_loss.connect(_on_currency_war_zombie_hp_loss)
	# 记入本批存活名单，由批次轮询判断本批是否已经清空。
	_currency_war_batch_alive.append(zombie)
	_currency_war_batch_remaining = maxi(0, _currency_war_batch_remaining - 1)
	if _currency_war_batch_remaining > 0:
		# 本批还没出完，继续按随机间隔逐只出场。
		# 导出参数须为正数，倒置或零值仍保证每次有实际间隔，不会同帧刷完。
		var minimum: float = maxf(0.05, minf(currency_war_spawn_interval_range.x, currency_war_spawn_interval_range.y))
		# 上界不小于下界；Timer继承暂停与Engine.time_scale，二倍速会相应加快出怪。
		var maximum: float = maxf(minimum, maxf(currency_war_spawn_interval_range.x, currency_war_spawn_interval_range.y))
		_currency_war_spawn_timer.start(randf_range(minimum, maximum))
	elif has_pending_spawns():
		# 本批已全部出场，开始等待清空或超时后再放行下一批。
		_start_currency_war_gate_timer()
	else:
		# 使用整波实际初始总生命和已发生伤害接回原版下一波刷新机制。
		zombie_wave_refresh_manager.update_wave_health_data(_currency_war_wave_health, curr_wave_type, curr_wave)
		zombie_wave_refresh_manager.wave_current_health = maxi(0, _currency_war_wave_health - _currency_war_wave_lost_health)
		zombie_wave_refresh_manager.judge_half_refresh(0, curr_wave)


## 开启新一批自然僵尸：取本批数量并立刻放出第一只，同时开始批次放行计时。
## 上一批未清空时换批会丢弃旧批次的存活追踪，只按当前批次判断是否清空。
func _open_currency_war_batch() -> void:
	if developer_refresh_suspended:
		cancel_pending_spawns()
		return
	if not has_pending_spawns():
		return
	# 本批还在陆续出场时不重复开新批，避免覆盖剩余名额。
	if _currency_war_batch_remaining > 0:
		return
	# 换成新批次后，旧批次僵尸离场不再参与放行判断，轮询也一并停掉。
	_currency_war_batch_alive.clear()
	if is_instance_valid(_currency_war_gate_timer):
		_currency_war_gate_timer.stop()
	_currency_war_batch_remaining = mini(maxi(1, currency_war_batch_size), _currency_war_pending_spawns.size())
	if not is_instance_valid(_currency_war_batch_timer):
		_currency_war_batch_timer = Timer.new()
		_currency_war_batch_timer.one_shot = true
		add_child(_currency_war_batch_timer)
		_currency_war_batch_timer.timeout.connect(_on_currency_war_batch_timeout)
	# 从本批第一只出场开始计时；超时后即使没清空也放行下一批。
	_currency_war_batch_timer.start(currency_war_batch_timeout)
	_spawn_next_currency_war_zombie()


## 启动批次清空轮询；本批全部出场后调用，清空或超时才放行下一批。
## [br]不订阅[signal Node.tree_exited]，僵尸在创建或重挂时会短暂离树，会导致闸门被提前放行。
func _start_currency_war_gate_timer() -> void:
	if not is_instance_valid(_currency_war_gate_timer):
		_currency_war_gate_timer = Timer.new()
		# 0.25秒一次的轮询足以跟手，又不会让每帧都做一次存活检查。
		_currency_war_gate_timer.wait_time = 0.25
		_currency_war_gate_timer.one_shot = false
		add_child(_currency_war_gate_timer)
		_currency_war_gate_timer.timeout.connect(_on_currency_war_gate_timeout)
	_currency_war_gate_timer.start()


## 轮询本批存活情况；本批清空且仍有排队时停掉闸门并放行下一批。
func _on_currency_war_gate_timeout() -> void:
	# 本批还有没出场的名额时继续按间隔出场，不提前放行下一批。
	if _currency_war_batch_remaining > 0:
		_currency_war_gate_timer.stop()
		return
	# 剔除已释放或已经离场的僵尸，剩下的才算本批仍在场上。
	var still_present: Array[Zombie000Base] = []
	for zombie: Zombie000Base in _currency_war_batch_alive:
		if is_instance_valid(zombie) and zombie.is_inside_tree():
			still_present.append(zombie)
	_currency_war_batch_alive = still_present
	if not _currency_war_batch_alive.is_empty():
		return
	_currency_war_gate_timer.stop()
	if not has_pending_spawns():
		return
	_currency_war_batch_timer.stop()
	_open_currency_war_batch()


## 上一批出场满[member currency_war_batch_timeout]秒仍未清空时强制放行下一批。
func _on_currency_war_batch_timeout() -> void:
	if not has_pending_spawns():
		return
	# 本批仍在陆续出场时再等一轮，避免打断正在刷出的名额。
	if _currency_war_batch_remaining > 0:
		_currency_war_batch_timer.start(currency_war_batch_timeout)
		return
	_open_currency_war_batch()


## 记录[param all_loss_hp]点生命流失；[param wave]与当前波一致才累计，出怪完成后继续交给原版残半刷新。
func _on_currency_war_zombie_hp_loss(all_loss_hp: int, wave: int) -> void:
	if wave != curr_wave or developer_refresh_suspended:
		return
	_currency_war_wave_lost_health += all_loss_hp
	if not has_pending_spawns():
		zombie_wave_refresh_manager.judge_half_refresh(all_loss_hp, wave)

func call_tombstone_create_zombie():
	EventBus.push_event("create_tombstone", [randi()%3+1])
	await get_tree().create_timer(1.0, false).timeout
	for i in range(Global.main_game.plant_cell_manager.tombstone_list.size()):
		var new_zombie_type = zombie_type_candidate_tombstone.pick_random()
		Global.main_game.plant_cell_manager.tombstone_list[i].create_new_zombie(new_zombie_type)

## 更新每秒旗帜进度(僵尸波次更新管理器信号触发)
func update_progress_bar_segment_mini_every_sec(time:float):
	## 如果是旗帜波，时间加6（僵尸靠近）+3（最后一波置为0）秒红字时间
	if curr_wave % 10 == 9:
		time += 6
		if curr_wave == max_wave - 1:
			time = 0

	progress_bar_segment_mini_every_sec = progress_bar_segment_every_wave / time

## 随时间每秒更新进度条
func _on_every_wave_progress_timer_timeout() -> void:
	# 每秒进度条增加对应的进度值
	flag_progress_bar.set_progress_add_every_sec(progress_bar_segment_mini_every_sec)
