extends Control
class_name FlagProgressBar
## 使用真实进度值和追赶进度值，使进度条平滑移动

## 真实进度值 (0-100)
var real_value: float = 0.0
## 追赶进度值 (0-100)
var chase_value: float = 0.


## 进度条
@onready var texture_progress_bar: TextureProgressBar = $TextureProgressBar
## 小僵尸头表示进度条
@onready var mini_zombie: TextureRect = $MiniZombie
## 旗帜
@onready var flag: FlagProgressBarFlag = $Flag

## 小僵尸的起始位置
var start_minizombie :float = 142
## 小僵尸的结束位置
var end_minizombie :float = -4
## 小僵尸的当前位置
var curr_minizombie : float
## 进度条开始位置，用于生成旗帜
var start_flag = start_minizombie + 6
## 进度条结束位置，用于生成旗帜
var end_flag = end_minizombie + 6
## 存储生成的旗帜
var flag_arr : Array[FlagProgressBarFlag] = []
## 当前旗帜的索引
#@export var curr_flag_i : int = 0


func _ready() -> void:
	curr_minizombie = start_minizombie
	set_progress(0)
	texture_progress_bar.value = 0
	mini_zombie.position.x = start_minizombie


## 按[param flag_num]生成旗帜并删除原始模板；[param waves_per_flag]默认10保持原版，货币战争传1表示每波一旗。
func create_flag(flag_num:int, waves_per_flag: int = 10):
	flag_arr.clear()
	# 计算总距离
	var total_distance = start_flag - end_flag
	#var segment_length_wave = total_distance / (flag_num * 10 - 1)

	# 计算每个分段的结束位置
	for i in range(1, flag_num+1):  # 1到10
		# 单旗放在终点；多旗按各波开始的进度均匀排列，普通模式仍每十小波一旗。
		var end_pos = start_flag - total_distance * (1.0 if flag_num * waves_per_flag <= 1 else (i * float(waves_per_flag) - 1.0) / (flag_num * float(waves_per_flag) - 1.0))

		var flag_new : FlagProgressBarFlag = flag.duplicate()

		add_child(flag_new)
		move_child(flag_new, 1)
		flag_arr.append(flag_new)
		flag_new.position.x = end_pos

	## 删除原始的flag
	flag.queue_free()

## 根据[param wave_num]生成旗帜；[param waves_per_flag]默认10，货币战争为1，其1/2/4波对应1/2/4面旗帜。
func init_flag_from_wave(wave_num:int, waves_per_flag: int = 10):
	assert(wave_num > 0, "关卡至少需要一波僵尸")
	# 普通模式短局仍不插入十波旗帜，模式专用波则逐波显示旗帜。
	var flag_num: int = int(wave_num / float(maxi(1, waves_per_flag)))
	create_flag(flag_num, maxi(1, waves_per_flag))

## 开始下一轮游戏,进度条更新数据
func start_next_game_flag_progress_bar_update():
	set_progress(0, -1)
	texture_progress_bar.value = 0
	for curr_flag:FlagProgressBarFlag in flag_arr:
		curr_flag.down_flag()


## 设置真实进度
func set_progress(value: float, flag_i:int = -1):
	real_value = clamp(value, 0.0, 100.0)

	if flag_i != -1:
		flag_arr[flag_i].up_flag()


## 设置每秒进度增加
func set_progress_add_every_sec(add_value:float):
	var value = real_value + add_value
	real_value = clamp(value, 0.0, 100.0)


# 动画追赶进度
func _process(delta):
	# 在1秒内追赶真实进度
	if abs(chase_value - real_value) > 0.1:
		# 计算追赶速度 (每秒10单位)
		var speed = 10.0 * delta

		if chase_value < real_value:
			chase_value = min(chase_value + speed, real_value)
		else:
			# 如果真实进度减小，追赶进度也会减小
			chase_value = max(chase_value - speed, real_value)

		# 更新UI
		texture_progress_bar.value = chase_value
		curr_minizombie = start_minizombie + chase_value * (end_minizombie - start_minizombie) * 0.01
		mini_zombie.position.x = curr_minizombie

	else:
		# 如果非常接近，直接设为相等
		if chase_value != real_value:
			chase_value = real_value

			texture_progress_bar.value = chase_value
			curr_minizombie = start_minizombie + chase_value * (end_minizombie - start_minizombie) * 0.01
			mini_zombie.position.x = curr_minizombie
