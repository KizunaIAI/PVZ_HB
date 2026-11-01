# 僵尸中毒效果

按用户确认的“僵尸身体变绿，身上冒绿色气泡”方向接入。参考 [Poison Damage Over Time](https://particlefx.studio/effects/poison-damage-over-time) 的表现，用 Godot 原生绘图及已有状态颜色槽实现；没有导入网页示例角色、打包下载素材或第三方播放代码。

## 游戏接入

- 入口：货币战争中，大蒜每次被啃食所附加的独立中毒层。
- 保留原有每层五秒、每秒一次及星级伤害数值。
- 附毒后身体染绿，气泡在身体范围内持续上升并破裂；毒伤发生时绿色短暂加强。
- 同一僵尸多层毒伤共用一个显示节点，最后一层结束才恢复原色。
- 僵尸死亡立即停止特效；控制器退出或切场景时归还显示层。
- 中毒使用新追加的 PoisonColor 槽，不覆盖冰冻、魅惑、受击闪亮或身体裁剪材质。
- 气泡跟随角色根节点移动、翻转及缩放，动画随游戏暂停和时间倍率推进。

## 文件

- 显示实现：`scripts/fx/other_effect/zombie_poison_effect.gd`。
- 接入代码：`scripts/currency_war/currency_war_combat.gd`。
- 状态颜色：`scripts/character/components/body_character.gd`。
- 预览场景：`scenes/art_preview/zombie_poison_preview.tscn`，打开后 F6。
- [静态对照](../../artifacts/art/zombie_poison/poison_still.png)、[动画](../../artifacts/art/zombie_poison/poison.gif)、[录像](../../artifacts/art/zombie_poison/poison.mp4)。

预览直接调用游戏的真实附毒入口：左侧原色，中间在两秒后追加一层，右侧叠加冰冻颜色。能观察到右侧先恢复冰冻色、中间稍后恢复原色，也可点击“受击闪亮”观察叠加表现。

已在 Godot 中运行上述美术预览并检查录像和运行日志；按项目约定，未新增或运行自动化测试。
