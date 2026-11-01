# 大肥鱼：Godot 部件版待机预览

本版使用固定的角色部件贴图，通过 Godot 的 `Node2D`、`Sprite2D` 与 `AnimationPlayer` 制作待机。脸部、鲸鱼围裙图案和服装纹理不随时间重绘，以改善上一版逐帧生成造成的外形变化。

## 查看方式

- 在 Godot 中打开并运行 [独立预览场景](../../../../../scenes/art_preview/da_fei_yu_idle_preview.tscn)，即使用 F6 运行当前场景。
- 预览提供暂停／继续、正常／半速、重新播放三个按钮。
- [当前循环动图](idle_godot_proportions.gif)已按用户反馈修正身体比例，来自实际 Godot 场景录制，共四秒、八十帧、每秒二十帧。
- [当前完整界面录像](../../../../../artifacts/art/da_fei_yu/idle_godot_proportions.mp4)保留原始三十帧每秒，分辨率为 1066 × 600。
- [比例调整前后对比](../../../../../artifacts/art/da_fei_yu/proportions_comparison.png)：左为调整前，右为调整后。
- [调整前的循环动图](idle_godot_preview.gif)保留用于回看。

## 场景与动画

- [可复用美术角色](../../../../../scenes/character/zombie_boss/da_fei_yu/da_fei_yu_visual.tscn)：只包含美术部件与播放器，不依赖 Boss 战斗脚本。
- [待机 Animation 资源](../../../../../animation/character/zombie_boss/da_fei_yu/da_fei_yu_idle.tres)：四秒循环，十二条部件变换轨道，名称为 `idle`；静止姿势保存在角色场景内的 `RESET` 动画中。
- [预览控制脚本](../../../../../scripts/art_preview/da_fei_yu_idle_preview.gd)：仅处理三个播放按钮。
- 脚底为角色本地坐标原点；双脚不参与待机变换。
- 身体上下位移约四个本地像素；头部稍有跟随；后发和前侧发束延迟轻摆；尾巴围绕连接点小幅转动。
- 头部连接点下移并减小相对呼吸幅度；复用裙装领口区域作为前景遮挡，使下巴贴近白色领口，避免露出过长的颈根。
- 裙装横向略加宽、纵向压缩，同时保持裙摆下沿不变；双臂缩短并收拢，连接点藏入现有肩袖。
- 双腿横向收窄，鞋面纵向压低，使短袜从裙摆下露出；脚底仍保持在角色原点。
- 前侧发束缩短，避免遮住肩袖和手臂衔接；所有装配比例统一记录在工具的 `proportions` 配置中。
- 当前是部件动画，尾巴仍为整张贴图绕关节摆动，尚未采用骨骼网格弯曲。眼睛保持睁开，本版先比较呼吸和摆动的稳定性。

## 素材与来源

部件贴图保存在 `res://assets/image/character/boss/da_fei_yu/idle_parts_v1/`，共九个部件：头部、后发、裙装、左右手臂、双腿、鲸尾、左右前侧发束。该目录沿用项目已有的 `assets` 忽略规则；本目录保留生成原图与装配工具，可重建对应素材。

- 所有新增绘制由内置 imagegen 生成，以用户提供的 [形象参考](../reference.png)为基准。
- [最初的部件表](parts_source.png)及其 [生成提示词](parts_prompt.txt)。
- 为消除相邻部件碎片和重复领口，单独生成了 [头部](head_source.png)及 [头部提示词](head_prompt.txt)，以及 [后发](back_hair_source.png)及 [后发提示词](back_hair_prompt.txt)。
- [部件清单](parts_manifest.json)记录最终来源、切分区域与实际导出尺寸。
- [本地装配工具](build_rig.cjs)仅负责切分、去除透明留白、等比缩放以及写入 Godot 文本资源，不生成角色绘画。

需重新装配时，在仓库根目录执行 `node docs/art/bosses/da_fei_yu/idle_godot_v1/build_rig.cjs`。工具使用本机已有的 Sharp 依赖路径。此命令会重建本版贴图、场景和动画资源，手工调整场景前请留意这一点。

## 运行记录

- 使用本机 Godot 4.7.2 的 Compatibility 渲染器实际运行了独立预览，并由 Movie Maker 录制四秒、每秒三十帧的画面。
- 已查看运行截图及循环中不同位置的画面，调整了头颈衔接和后发长度。
- 2026-10-28 根据用户反馈修正露颈、手臂、裙装与腿脚比例，重新运行并录制 Godot 场景，查看了循环中四个时刻的画面。
- 最终预览运行日志未见脚本错误或资源加载错误。
- 未新增或运行自动化测试；尚未接入战斗场景。
