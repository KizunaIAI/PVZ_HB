## 大纲装备数据与纯属性计算，只包含用户给出的四种小件、五种成装和独立羁绊头盔。
class_name CurrencyWarEquipment
extends RefCounted

## 普通植物的装备槽数；睡莲、花盆不使用此上限，因为不能装备。
const SLOT_LIMIT: int = 3
## 小件等概率掉落候选，允许重复。
const BASIC: Array[String] = ["knife", "sword", "armor", "charm"]
## 成装等概率掉落候选，允许重复；机枪头盔不是随机战利品。
const COMPLETED: Array[String] = ["spine", "shiv", "breaker", "chain", "pendant"]
## 固定属性、攻击动作叠层和效果说明；所有百分比使用0至1的倍率增量。
const ITEMS: Dictionary = {
	"knife": {"name": "小刀", "speed": 0.1, "tip": "攻速+10%"},
	"sword": {"name": "大剑", "attack": 10.0, "tip": "攻击力+10"},
	"armor": {"name": "铁甲", "defense": 5.0, "tip": "防御+5"},
	"charm": {"name": "护符", "health": 100, "tip": "最大生命+100"},
	"spine": {"name": "破脊之刃", "attack": 20.0, "speed": 0.15, "attack_stack": 1.0, "tip": "攻击+20、攻速+15%；每次攻击动作永久叠加1攻击，本节点结束清空"},
	"shiv": {"name": "电刀", "speed": 0.3, "speed_stack": 0.05, "tip": "攻速+30%；每次攻击动作叠加5%攻速，本节点结束清空"},
	"breaker": {"name": "破军", "attack": 100.0, "execute": 0.5, "tip": "攻击+100；敌人生命低于50%时伤害+50%"},
	"chain": {"name": "锁子甲", "defense": 20.0, "reduction": 0.3, "tip": "防御+20；免伤30%，多件按加法"},
	"pendant": {"name": "生命吊坠", "health": 1000, "regen": 0.02, "tip": "最大生命+1000；每秒恢复最大生命的2%"},
	"helmet": {"name": "机枪头盔", "tip": "获得其他场上豌豆实时攻击与攻速总和的5%。每次攻击按羁绊档位有1%/2%/3.5%/8%概率释放两秒168发大招。\n独立装备不占三格，仅豌豆可佩戴；准备时退回备战可取下，失去羁绊后消失。"},
}
## 只收录大纲已定义的五种两件配方，未定义组合不合成。
const RECIPES: Dictionary = {"knife+sword": "spine", "knife+knife": "shiv", "sword+sword": "breaker", "armor+armor": "chain", "charm+charm": "pendant"}


## 返回已有[param first]和新放入[param second]的小件合成结果；未定义配方或成装组合返回空字符串。
static func recipe(first: String, second: String) -> String:
	if not BASIC.has(first) or not BASIC.has(second):
		return ""
	# 配方不区分放入次序，键按字母顺序稳定排序。
	var pair: String = first + "+" + second if first <= second else second + "+" + first
	return RECIPES.get(pair, "")


## 累加[param equipment]各槽在[param actions]记录的佩戴期间动作数对应的属性，不把佩戴前攻击补算为叠层。
static func stats(equipment: Array, actions: Array) -> Dictionary:
	# 统一返回零初始值，非攻击植物可以忽略攻击和攻速，生命、防御仍能生效。
	var result: Dictionary = {"attack": 0.0, "speed": 0.0, "defense": 0.0, "health": 0, "execute": 0.0, "reduction": 0.0, "regen": 0.0}
	# 同种物品逐件累加，不去重。
	for slot: int in range(equipment.size()):
		# 每个槽对应一件物品，即使同名也有各自的佩戴起点。
		var item: String = str(equipment[slot])
		if not ITEMS.has(item) or item == "helmet":
			continue
		# 每件物品配置只读，不把动态攻击叠层写回共享数据。
		var definition: Dictionary = ITEMS[item]
		# 所有已定义属性按加法叠加。
		for attribute: String in result:
			result[attribute] += definition.get(attribute, 0)
		# 刚佩戴或刚合成的装备从零开始，后续每个攻击动作独立累加。
		var count: int = int(actions[slot]) if slot < actions.size() else 0
		result.attack += float(definition.get("attack_stack", 0)) * count
		result.speed += float(definition.get("speed_stack", 0)) * count
	return result
