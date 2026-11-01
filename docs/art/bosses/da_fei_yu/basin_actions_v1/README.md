# 大肥鱼 · 取盆幻想与受击丢盆

以用户当前调整后的钢盆场景为基准；不修改基础造型和戴盆参数。原始场景快照见 [user_baseline.tscn](user_baseline.tscn)。

## 预览

- Godot 入口：`res://scenes/art_preview/da_fei_yu_basin_actions_preview.tscn`，打开后 F6。
- 可复用角色：`res://scenes/character/zombie_boss/da_fei_yu/da_fei_yu_basin_actions_visual.tscn`。
- 默认自动演示；按钮可以单独播放取盆幻想、植物攻击和恢复戴盆待机。
- 原生引擎录像：[MP4](../../../../../artifacts/art/da_fei_yu/basin_actions_v1.mp4)，[GIF](../../../../../artifacts/art/da_fei_yu/basin_actions_v1.gif)。

## 动作

1. 双手取下头盆，翻正后端在身前，头顶弹出装满米饭的盆的幻想气泡。幻想会持续停留，等待受击。
2. 植物打破幻想，米饭先淡出、云朵扩散消失；大肥鱼鼓脸生气、双手蓄力，将盆抛向攻击者。盆飞出后不会在正式美术接口中自动补回；预览循环通过重置展示下一轮。

新动作使用四张关键姿势和 Godot Tween 驱动独立道具、气泡及轻微身体变换；基础待机继续使用已有 Skeleton2D。这是动作美术初版，手臂尚未拆成连续骨骼部件，取盆到端盆之间可见关键姿势切换。

取盆初稿曾多画手臂；最终按用户红框删去中央额头前的多余手臂，保留远侧及右侧手臂。最终采用 `reach_corrected_source.png`，不是原始图集的左上格。

## 接入

- `play_dream_idle()`：播放取盆，进入持续幻想。
- `react_to_hit(attacker: Node2D) -> bool`：仅在幻想阶段接受有效攻击者；重复受击不额外丢盆。返回是否触发本次反击。
- `basin_released(attacker)` 与 `basin_arrived(attacker)`：供后续战斗逻辑接入；当前不计算伤害、不注册正式 Boss。
- 钢盆离手时采样该植物的位置；植物离手前被移除时使用最后有效位置，信号目标为空。
- `reset_idle()`：取消未完成动作，恢复用户微调后的戴盆站姿。

## 素材与复现

采用内置 imagegen 生成；提示词见 [prompts.md](prompts.md) 和 [用户指定修正](reach_user_correction.md)。透明原图已归档在本目录。PNG 裁切与等比缩放使用 Sharp，不重绘像素内容。

- `node docs/art/bosses/da_fei_yu/basin_actions_v1/prepare_assets.cjs`：从归档原图导出本轮贴图到 assets；assets 遵循仓库已有忽略规则。
- `node docs/art/bosses/da_fei_yu/basin_actions_v1/build_scenes.cjs`：只重建本轮新增的两个场景，不修改用户基础场景。
- 微调端盆位置：`scripts/art_preview/da_fei_yu_basin_actions.gd` 的 `HOLD_POSITION`；各姿势脚底锚点位于角色场景的 Poses 子节点。

已在 Godot 实际运行并录制检查动作。按项目约定，未新增或运行自动化测试。
