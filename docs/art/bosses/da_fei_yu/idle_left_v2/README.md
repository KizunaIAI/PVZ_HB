# 大肥鱼：按新侧面参考重画的骨骼待机

本版以用户补充的 [侧面截图](pose_reference.png)为当前左向外形基准，重画完整透明角色，并在 Godot 内用二维骨骼制作四秒待机循环。

## 外形调整

- 保持左侧轮廓、单眼侧脸、短脖子和紧凑头身比。
- 近侧手臂自然垂下，小手落在身侧；裙摆、围裙按参考的侧面角度绘制。
- 长发顺着背部流下，浅蓝发梢靠近裙摆与鲸尾；鲸尾采用厚实弧线和浅蓝色腹面。
- 用完整绘制的身体保留肩袖、领口和裙摆的自然衔接，再进行小幅骨骼变换。

## 查看

- [新版 Godot 预览](../../../../../scenes/art_preview/da_fei_yu_idle_left_v2_preview.tscn)：打开后按 F6，支持暂停、半速与重新播放。
- 常用入口 [左向预览](../../../../../scenes/art_preview/da_fei_yu_idle_left_preview.tscn)现指向基于本版新增的 [钢盆外观](../steel_basin_v1/README.md)；本页的专用预览继续保留未佩戴配件的形象。
- [循环动图](idle_left_v2_preview.gif)：来自实际 Godot 渲染，四秒、二十帧每秒、共八十帧。
- [完整界面录像](../../../../../artifacts/art/da_fei_yu/idle_left_v2_preview.mp4)保留原生三十帧每秒。
- [前后对比](../../../../../artifacts/art/da_fei_yu/left_v1_v2_comparison.png)：左为上一版，右为本版。

## 骨骼与素材

- [美术角色场景](../../../../../scenes/character/zombie_boss/da_fei_yu/da_fei_yu_left_v2_visual.tscn)使用真实的 `Skeleton2D`、`Bone2D`、加权 `Polygon2D` 与 `AnimationPlayer`。
- 脚、躯干、头部、后发、鲸尾共五个控制骨骼；脚底保持固定，躯干小幅呼吸，后发与尾巴错开相位。
- [动画资源](../../../../../animation/character/zombie_boss/da_fei_yu/da_fei_yu_idle_left_v2.tres)包含七条变换轨道，`idle` 为四秒循环，`RESET` 绑定姿势保存在角色场景中。
- 二十八列、四十行的规则网格共 1189 个顶点、2240 个三角形；面部使用头部骨骼的整体变换，颈部、衣裙及腿部通过连续权重连接。
- 完整贴图保存在 `res://assets/image/character/boss/da_fei_yu/idle_left_v2/character.png`，为 348 × 500 像素透明 PNG。沿用项目 assets 忽略规则，本目录保留可重建源图。
- [原始生成图](character_source.png)由内置 imagegen 依据用户新参考生成；[完整提示词](prompt.txt)。
- [构建记录](rig_manifest.json)保存贴图尺寸、控制骨骼绑定位置、网格与轨道信息。
- [本地装配工具](build_mesh_rig.cjs)仅导出完整 PNG、生成骨骼权重及写入 Godot 资源，不重绘角色。可在仓库根目录执行 `node docs/art/bosses/da_fei_yu/idle_left_v2/build_mesh_rig.cjs` 重建本版；使用本机已有 Sharp 依赖。

骨骼绑定方式参照 Godot 官方的 [Bone2D](https://docs.godotengine.org/en/stable/classes/class_bone2d.html)与 [Polygon2D](https://docs.godotengine.org/en/stable/classes/class_polygon2d.html)文档。当前权重和动作针对小幅待机制作。

## 保留的旧版

上一版完整保留于 [旧版入口](../../../../../scenes/art_preview/da_fei_yu_idle_left_v1_preview.tscn)和 [旧版记录](../idle_left_v1/README.md)。正面场景保持原样。

## 运行记录

使用 Godot 4.7.2 Compatibility 实际运行新版场景，并通过 Movie Maker 录制四秒、三十帧每秒的画面。已查看静止造型及循环中四个时刻的画面，运行日志未见脚本或资源加载错误。未新增或运行自动化测试，尚未接入 Boss 战斗逻辑。
