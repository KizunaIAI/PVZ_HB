## 保留原版害怕与射击；货币战争通过回调在首次进入缩地状态时施放专属范围攻击。
extends Plant000Base
class_name Plant014ScaredyShroom

@onready var scaredy_component: ScaredyComponent = $ScaredyComponent

@export_group("动画状态")
@export var is_scared := false

@onready var attack_component: AttackComponentBulletBase = $AttackComponent



func ready_norm_signal_connect():
	super()
	scaredy_component.signal_scaredy_start.connect(change_is_scared.bind(true))
	scaredy_component.signal_scaredy_end.connect(change_is_scared.bind(false))

	for component:ComponentNormBase in scaredy_component.scaredy_influence_components:
		scaredy_component.signal_scaredy_start.connect(component.disable_component.bind(ComponentNormBase.E_IsEnableFactor.Scaredy))
		scaredy_component.signal_scaredy_end.connect(component.enable_component.bind(ComponentNormBase.E_IsEnableFactor.Scaredy))
	signal_update_speed.connect(attack_component.owner_update_speed)

## 使用[param curr_is_scared]同步原版状态；仅站立转缩地时通知模式，检测器重复发出害怕信号不会再次施放。
func change_is_scared(curr_is_scared:bool):
	# 害怕检测可能因同一僵尸状态变化重复发信号，每段连续缩地只触发一次。
	var entered_scared: bool = curr_is_scared and not is_scared
	self.is_scared = curr_is_scared
	if entered_scared:
		# 其他模式未注册回调，保留原版胆小菇行为。
		var callback: Callable = get_meta("currency_war_scared_callback", Callable())
		if callback.is_valid():
			callback.call()
