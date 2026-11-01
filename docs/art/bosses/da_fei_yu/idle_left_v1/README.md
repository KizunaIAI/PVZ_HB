# 大肥鱼：面向左侧的 Godot 待机

以用户原始设定图中间的左侧视图为依据，重新绘制并装配左向部件。鼻尖、胸口、围裙和鞋尖统一朝左，长发与鲸尾位于右后方。沿用前一轮修正的紧凑 Q 版比例，尽量缩短露颈、控制手脚大小。

## 查看

- [本版历史预览场景](../../../../../scenes/art_preview/da_fei_yu_idle_left_v1_preview.tscn)：在 Godot 中打开后按 F6；支持暂停、半速及重播。常用左向入口现已切换至 [新版](../idle_left_v2/README.md)。
- [循环动图](idle_left_preview.gif)：来自实际 Godot 场景录制，四秒循环、每秒二十帧，共八十帧。
- [完整预览录像](../../../../../artifacts/art/da_fei_yu/idle_left_preview.mp4)：1066 × 600，保留每秒三十帧的原生录制。
- [运行截图](../../../../../artifacts/art/da_fei_yu/idle_left_still.png)。

## 资源

- [左向美术角色](../../../../../scenes/character/zombie_boss/da_fei_yu/da_fei_yu_left_visual.tscn)与[左向待机动画](../../../../../animation/character/zombie_boss/da_fei_yu/da_fei_yu_idle_left.tres)独立保存，正面版继续保留。
- 六个固定透明贴图部件：侧面头部、侧面衣裙、近侧手臂、双腿、侧面后发、鲸尾。
- 导出部件目录为 `res://assets/image/character/boss/da_fei_yu/idle_left_parts_v1/`，遵循项目已有的 assets 忽略规则；本目录保留可重建的源图与导出工具。
- 通过 `Node2D`、`Sprite2D` 和 `AnimationPlayer` 的九条变换轨道制作呼吸与轻摆。脚底以角色原点为基准，不参与待机变换。
- 复用衣裙的领口区域作为前景遮挡，隐藏颈根；不在正面素材上执行镜像来代替左侧视角。
- 使用已有的预览控制脚本，仅左向美术场景和标题单独引用。

## 生成记录

- 新绘制使用内置 imagegen，参考用户提供的 [形象设定图](../reference.png)。
- [完整生成提示词](parts_prompt.txt)与[原始部件图](parts_raw.png)。
- [切分及导出清单](parts_manifest.json)记录实际布局与输出尺寸。
- [本地装配工具](build_left_rig.cjs)负责机械切分、去透明留白、等比导出和写入 Godot 资源，不重绘部件。可在仓库根目录执行 `node docs/art/bosses/da_fei_yu/idle_left_v1/build_left_rig.cjs` 重建本版素材与场景；依赖当前本机已有的 Sharp 路径及正面版预览界面。

## 检查记录

已用 Godot 4.7.2 实际运行左向预览，通过 Movie Maker 录制四秒、三十帧每秒的循环，并查看循环中的四个时刻。运行日志未见脚本或资源加载错误。未新增或运行自动化测试，尚未接入 Boss 战斗逻辑。
