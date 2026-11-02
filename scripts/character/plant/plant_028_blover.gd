extends Plant000Base
class_name Plant028Blover

## 三叶草吹的时间
@export var blover_time:float = 2.0

var is_blow_away_once:=false

## 进入战场后等待原版吹风时长；本模式的准备和暂停不消耗该时间。
func ready_norm():
	super()
	# 场景创建早于模式绑定回调，直接从当前关卡模式判断暂停计时策略。
	var mode_blover: bool = Global.game_para != null and Global.game_para.game_mode == MainSceneRegistry.MainScenes.CurrencyWar
	await get_tree().create_timer(blover_time, not mode_blover).timeout
	# 模式技能完成后直接回备战，不能先清零生命被误判为阵亡。
	var callback: Callable = get_meta("currency_war_return_callback", Callable())
	if callback.is_valid() and hp_component.curr_hp > 0:
		callback.call()
	else:
		hp_component.Hp_loss_death()

## 吹散迷雾
func blow_away_fog():
	if is_blow_away_once:
		return
	is_blow_away_once = true
	if is_instance_valid(Global.main_game.background_manager.fog):
		Global.main_game.background_manager.fog.be_flow_away()

	EventBus.push_event("blover_blow_away_in_sky_zombie")
	# 全屏击退和临时攻速在原版吹风释放帧触发，准备或暂停不提前计时。
	var callback: Callable = get_meta("currency_war_blover_callback", Callable())
	if callback.is_valid():
		callback.call()

