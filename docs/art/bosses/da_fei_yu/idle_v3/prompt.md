# 大肥鱼 · 待机动画 v3「小俏皮眨眼版」制作提示词

- 对象：Boss「大肥鱼」左向钢盆造型（`da_fei_yu_steel_basin_visual.tscn`）。
- 引擎：Godot 4.7 / 2D / `Skeleton2D` + `AnimationPlayer`。
- 用途：把「一、提示词正文」整段发给执行者（AI 代理或动画师）；第五节英文段落原样交给 imagegen。
- 本轮只做待机，不改技能、走位与端盆循环。
- 与上一版差异：8 秒纯呼吸 → 12 秒「三层表演」；新增自然眨眼与小俏皮拍点。
- 实现记录：本提示词已落地，见 [README.md](README.md) 与预览 `res://scenes/art_preview/da_fei_yu_idle_v3_preview.tscn`；实际实现采用「保留原睫毛、只覆盖眼球」的两态眼层，比下文方案 A 更稳。

**一句话版（急用时只发这句）**：给戴钢盆的大肥鱼重做 12 秒循环待机，呼吸三层延迟、三处不等距自然眨眼（含一次连眨、一次慢眨）、三次小俏皮（尾鳍点两下 / 歪头偷瞄 / 钢盆回正），脚底与站姿不变，眨眼用 Head 骨骼下的三态眼贴图层实现。

---

## 一、提示词正文（可直接复制以下全部内容）

你是 Godot 2D 骨骼动画师。你会在本仓库里为 Boss「大肥鱼」重做一段**待机动画**，并让它在游戏里立刻可用。

### 0. 目标

12 秒无缝循环，让这个戴钢盆的 Q 版鲸鱼女仆「活着」：呼吸像真的、眨眼像真的、每隔几秒露出一点小得意，但**脚不离地、身体不位移**。衡量标准不是"动得多"，而是"看三十秒不觉得是循环"。

### 1. 硬约束（违反即返工）

1. **不新增 `AnimationPlayer`**。`scripts/character/zombie_boss/da_fei_yu_boss.gd` 直接持有 `visual.standing_player` / `visual.hold_idle_player`，靠它同步冰冻、减速与死亡停播。新动画写进现有播放器。
2. **不改节点名与层级**：`Standing` / `Rig` / `Skeleton2D` / `Feet`、`Body`、`Head`、`Hair`、`Tail`、`SteelBasin` / `AnimationPlayer` 全部保持原路径；动画名保持 `idle`，库键保持 `""`，`autoplay` 保持 `idle`。
3. **脚底固定**：`Feet` 骨骼与 `Rig` 偏移（`-111.36, -500`）不动，鞋底基线 `y = 500` 在世界原点，`Feet` 不建任何轨道。
4. **不改贴图、比例、缩放**：角色贴图 `348 × 500`、钢盆 `245 × 103`、`SteelBasin` 局部变换、实机 `0.32` 缩放均保持原值。本轮只允许新增"眼睛层"贴图。
5. **不改 `da_fei_yu_boss.gd`**；`hold_idle`（端盆待机）本轮不重做，但也不能被改坏。
6. **风格一致**：深蓝描边、柔和赛璐璐、Q 版短身比例，禁 3D、禁写实、禁像素风、禁新增配饰。
7. 改前先在仓库根目录提交一次本地检查点（沿用项目习惯，可 `git add -A && git commit -m "checkpoint before idle v3"`）；注释与文档用中文。

### 2. 现状事实（以这些为准，不要重新发明）

**资产**

| 内容 | 路径 |
| --- | --- |
| 角色完整贴图 | `res://assets/image/character/boss/da_fei_yu/idle_left_v2/character.png`（348×500） |
| 钢盆 | `res://assets/image/character/boss/da_fei_yu/steel_basin_v1/basin.png`（245×103） |
| 站立场景 | `scenes/character/zombie_boss/da_fei_yu/da_fei_yu_left_v2_visual.tscn` |
| 钢盆场景（继承站立场景） | `.../da_fei_yu_steel_basin_visual.tscn` |
| 现有待机 | `animation/character/zombie_boss/da_fei_yu/da_fei_yu_idle_left_v2.tres`（8 秒） |
| 取盆/丢盆装配 | `.../da_fei_yu_basin_actions_visual.tscn` + `scripts/art_preview/da_fei_yu_basin_actions.gd` |
| 上一版预览 | `scenes/art_preview/da_fei_yu_natural_idle_preview.tscn`（0.66 缩放并排） |

**绑定（Rig 本地坐标，勿改）**

| 骨骼 | rest 位置 | 长度 | 权重负责区域 |
| --- | --- | --- | --- |
| Feet | (111.36, 500) | 30 | 鞋、袜、脚踝，**固定不动** |
| Body | (104.4, 335) | 60 | 裙摆、躯干、围裙 |
| Head | (97.44, 245) | 80 | 头、脸、头饰、呆毛（刚性整体移动） |
| Hair | (201.84, 185) | 100 | 背后长发与发梢 |
| Tail | (177.48, 400) | 80 | 鲸尾与尾鳍 |
| SteelBasin | Head 下局部 (30.92, -196.5) | — | 倒扣钢盆，`z_index = 10` |

网格为 32×48 的加权 `Polygon2D`，面部区域 100% 跟随 `Head`，因此**眼睛叠加层直接挂在 `Head` 骨骼下即可与脸同步**。

**现有着色/结构**：单一网格 + 单张贴图；没有独立头部、没有眼球、没有眼睑层。现有 8 秒动画 7 条轨道（Body/Head/Hair/Tail 的 position+rotation），三次插值、首尾同速。

### 3. 表演设计

#### 3.1 基调

- **可爱**：一切幅度以"肉乎乎的重心轻微晃动"为底色，不飘不弹。
- **自然**：不同系统走不同周期（呼吸 4 秒、重心 12 秒、眨眼 3.85–4.4 秒不等），任何时刻都至少有一处在动，但没有任何两处在同一拍上。
- **小俏皮**：全片只有三次"坏一下"，每次 0.4–1.2 秒，做完立刻回到乖站姿。俏皮来自**节奏**（突然、短、带一点过冲），不来自幅度。
- **Boss 感**：它不害怕、不张望、不后退；偷瞄是"我知道你在看我"的得意，不是警惕。

#### 3.2 三层结构（必须分层写，不要合成一条曲线）

1. **呼吸层（4 秒 × 3 次）**：躯干先动 → 头与手延迟 ~0.06 s → 后发延迟 ~0.25 s → 尾根延迟 ~0.5 s。三次呼吸幅度递减（-6.0 / -5.2 / -4.6 px），第二、三次略浅，避免机械重复。
2. **微表情层（眨眼）**：不等距三次，与呼吸顶点**错相**（呼吸顶点 1.4 s，眨眼在 1.20 s / 5.45 s / 9.30 s）。
3. **俏皮层（三个 beat）**：尾鳍点两下 → 歪头偷瞄 → 钢盆回正。三次之间至少空 2 秒"乖"的时间。

#### 3.3 呼吸细节

- 吸气 1.40 秒、顶点停 0.15 秒、呼气 2.45 秒（呼气比吸气长，是人放松时的比例）。
- 缓动用 `easeInOutSine`，首尾速度为零；**不要直接对关键帧套贝塞尔**，会在大幅低采样时出现"呼吸到一半卡住"。
- 呼气中段（约 2.35 s）加 0.25 秒几乎静止的"叹气停顿"，幅度只走 1 px，这是"自然"的关键。
- 水平重心跟随 12 秒正弦（±2.0 px），头部反向轻抗（-0.35 增益），让站姿像有重量。

#### 3.4 眨眼（本轮核心）

**表演规则**

- 三次眨眼，间隔 4.25 s / 3.85 s，**不放在 4 秒整数倍上**，也不落在呼吸最高点。
- 第一次：普通眨眼，4 帧（半闭 1 / 全闭 2 / 半闭 1），约 0.13 s。
- 第二次：**连眨两下**——眨完 0.20 s 立刻再眨，第二下略轻。这是全片最"俏皮"的 0.4 秒。
- 第三次：**慢眨**——半闭 2 帧、闭合 5 帧、半闭 2 帧（约 0.30 s），睁眼后停在"半睁"0.30 s 再全开，像犯困又装没事。
- 闭眼瞬间头部下沉 0.25°、钢盆向前 0.6 px；睁眼时头先回、盆后回（真实的惯性方向相反）。
- 眨眼前后 0.4 秒内不做头部大动作；每次闭眼时长不完全相同（±1 帧），不要复制粘贴同一段关键帧。

**实现方式（二选一，优先 A）**

- **方案 A（推荐）：贴图三态叠加层。** 在 `Rig/Skeleton2D/Head` 下新增三个 `Sprite2D`：`EyeOpen` / `EyeHalf` / `EyeClosed`，`z_index = 5`（在网格之上、钢盆 10 之下），三张图共用同一画布与同一原点，只让眼睛（虹膜、瞳孔、高光、睫毛线、眼睑）有像素，其余全透明。用三条 `visible` 布尔轨道在该亮的时候亮，**同一时刻只能有一个为 true**。
  - 睁眼态必须与原贴图的眼睛**逐像素对齐**：直接从 `character.png` 裁切原眼作为 `EyeOpen`，不要去重画。
  - 闭眼态要有明确的深色睫毛弧线（描边色 `#1B2440`，2 px），否则 0.32 缩放下看不见闭眼。
  - 头部姿势由 `Head` 骨骼驱动，眼睛层作为子节点自动跟随，**不要再给眼睛层加位移轨道**。
- **方案 B（备选）：整头三态。** 仅在无法干净叠加时使用：三张同画布头贴图，切 `Head` 精灵的 `texture`。缺点是整头替换容易在切换帧闪一下，且会牵动头饰与呆毛。

**如果 AI 生成的三态对不齐**（虹膜位置漂移、眼睛大小变化）：改程序化眼睑——以原睁眼为底，用 Sharp + SVG 画上眼睑：肤色取原图脸颊采样值，眼睑形状为覆盖虹膜上半的圆弧，闭眼时整片覆盖并把睫毛线下移到眼睑边缘，半闭时只覆盖上部 45%。宁可风格朴素，也不要每次眨眼眼睛跳一下。

#### 3.5 三个小俏皮 beat

| # | 时间 | 动作 | 做法 |
| --- | --- | --- | --- |
| ① | 3.60–4.30 s | **尾鳍得意点两下** | `Tail:rotation` 快速 +4.5°（0.15 s）→ -1.5°（0.12 s）→ +3.0°（0.10 s）→ 0.5 s 归零；同时钢盆反向 -0.8° 滞后 0.1 s |
| ② | 6.80–8.05 s | **歪头偷瞄** | `Head:rotation` 0.18 s 转到 -2.8°，保持 0.77 s 期间再缓慢漂 -0.3°（活的），0.30 s 回正并过冲 +0.4°；`Hair` 与钢盆各延迟 0.12 s 跟随，发梢多甩 0.6° |
| ③ | 10.10–11.10 s | **钢盆回正** | 歪头余势 + 自身惯性：`SteelBasin:rotation` 起振 +2.2°，阻尼振荡 2 次（约 0.9 s）回到 0；`SteelBasin:position` 同相位 +1.2 px，相位差 90°，画一个很小的椭圆 |

- 三次都不许带动身体位移，不许换姿势，不许转方向。
- ② 的歪头方向固定为**屏幕左侧**（角色正面朝左），歪头时观众能看到更多侧脸——这就是"偷瞄"的读法。
- ③ 是"钢盆是戴上去的"这一设定的免费笑点，务必保留。

#### 3.6 12 秒时间轴总表（30 fps / 360 帧）

| 时间 | 事件 | 对象 | 幅度 | 曲线 |
| --- | --- | --- | --- | --- |
| 0.00 | 循环起点：呼气末、重心居中 | 全部 | 0 | — |
| 0.00–1.40 | 吸气 | Body Y | 0 → -6.0 px | easeInOutSine |
| 1.20–1.33 | 眨眼① | Eye | 4 帧 | 阶跃 |
| 1.40–1.55 | 吸气顶点微停 | Body Y | 保持 -6.0 | 线性 |
| 1.55–4.00 | 呼气 | Body Y | -6.0 → 0 | easeInOutSine |
| 2.35–2.60 | 叹气停顿 | Body Y | 停在 -2.4，仅走 1 px | 缓入缓出 |
| 3.60–4.30 | 俏皮① 尾鳍点两下 | Tail rot | +4.5°→-1.5°→+3.0°→0 | 弹性 |
| 4.00–8.00 | 第二次呼吸（较浅） | Body Y | 0 → -5.2 | 同相位 |
| 5.45–5.58 | 眨眼②a | Eye | 4 帧 | 阶跃 |
| 5.78–5.91 | 眨眼②b（连眨，略轻） | Eye | 4 帧 | 阶跃 |
| 6.80–8.05 | 俏皮② 歪头偷瞄 | Head rot | -2.8° → -3.1° → +0.4° → 0 | 弹入弹回 |
| 8.00–12.00 | 第三次呼吸（最浅） | Body Y | 0 → -4.6 | 同相位 |
| 9.30–9.60 | 眨眼③ 慢眨 | Eye | 9 帧 | 阶跃 |
| 9.75–10.05 | 慢眨后半睁 | Eye | 半睁 0.30 s | 阶跃 |
| 10.10–11.10 | 俏皮③ 钢盆回正 | SteelBasin | +2.2°，阻尼 2 次 | 阻尼正弦 |
| 11.35–12.00 | 收势回零，与 0 帧同值同速 | 全部 | 0 | easeInOutSine |

#### 3.7 明确禁止的"假可爱"

- 匀速正弦呼吸（一眼假）、全程同一振幅、全身同相位一起上下浮。
- 眨眼等间隔、每次时长一样、眨眼时整个人跟着一抖。
- 尾鳍左右匀速摆（像节拍器）；用"点两下 + 停"代替。
- 卖萌三件套乱用：鼓腮、跺脚、转圈。本轮最多用一次歪头，其余靠节奏。
- 幅度大到像在喘气或鞠躬；Boss 待机要让玩家觉得"它在等你"，不是"它在演戏"。

### 4. 技术规格

#### 4.1 轨道清单（共 13 条，轨道路径相对 `Standing` 根节点）

| # | 轨道路径 | 类型 | 说明 |
| --- | --- | --- | --- |
| 1 | `Rig/Skeleton2D/Body:position` | Vector2 | 呼吸 + 12 秒重心 |
| 2 | `Rig/Skeleton2D/Body:rotation` | float | 重心侧移时 ±0.15° 微滚（可选，建议加） |
| 3 | `Rig/Skeleton2D/Head:position` | Vector2 | 跟随呼吸 0.92 增益、延迟 0.06 s |
| 4 | `Rig/Skeleton2D/Head:rotation` | float | 呼吸微摆 ±0.35° + 歪头 beat |
| 5 | `Rig/Skeleton2D/Hair:position` | Vector2 | 跟随 0.70 增益、延迟 0.25 s |
| 6 | `Rig/Skeleton2D/Hair:rotation` | float | ±1.2° + 歪头余势 |
| 7 | `Rig/Skeleton2D/Tail:position` | Vector2 | 跟随 0.30 增益、延迟 0.50 s |
| 8 | `Rig/Skeleton2D/Tail:rotation` | float | ±2.0° 慢摆 + 点两下 |
| 9 | `Rig/Skeleton2D/Head/SteelBasin:position` | Vector2 | 次级惯性 +1.2 px |
| 10 | `Rig/Skeleton2D/Head/SteelBasin:rotation` | float | 滞后跟随 + 阻尼回正 |
| 11 | `Rig/Skeleton2D/Head/EyeOpen:visible` | bool | 默认 true |
| 12 | `Rig/Skeleton2D/Head/EyeHalf:visible` | bool | 默认 false |
| 13 | `Rig/Skeleton2D/Head/EyeClosed:visible` | bool | 默认 false |

- `Feet` 不建轨道；`Mesh` 的 `skeleton`、`bones` 权重数组不动。
- 钢盆两条轨道只在钢盆场景生效。**基础无盆场景不要引用这条含钢盆轨道的动画**，否则会刷"节点不存在"警告：v3 动画给钢盆场景用，无盆版继续用 v2。

#### 4.2 数值参数

- 循环长度 `length = 12.0`，`loop_mode = 1`，`step = 0.016667`。
- 呼吸/重心/尾巴等连续轨道：采样 `1/16 s`（每轨 193 个关键帧），`interp = 2`（三次），`loop_wrap = true`。
- 眨眼 `visible` 轨道：按 30 fps 网格给键（`1/30 s`），`interp = 1`，同一时刻只允许一个 `true`。
- 所有轨道首尾帧值相等、斜率相等；用"延迟呼吸"技巧保证 `t = 0` 与 `t = 12` 的取值与速度一致（`delayed(t, d) = breath(t - d) - breath(-d)`），尾巴用 `sin(φ - d) + sin(d)` 的写法。
- 相邻关键帧的角度差控制在 0.05 rad 以内，避免三次插值过冲把发梢甩到脸上。

#### 4.3 眨眼层装配细节

1. 从 `character.png` 量出眼睛外接矩形（4 倍放大截图量取，精确到 1 px），记录进 `rig_manifest.json` 的 `eye_box` 字段。
2. 三个 `Sprite2D` 挂在 `Rig/Skeleton2D/Head` 下，`position = 眼睛左上角 - Head 骨骼 rest 位置`（即 `(eye.x - 97.44, eye.y - 245)`），`centered = false`，`z_index = 5`。
3. 三张图同尺寸、同原点，除眼睛外全透明；`EyeOpen` 直接裁自原图，另两态与它对齐。
4. `visible` 默认：开 true，半闭/闭 false；`RESET` 动画里也要写这三个 `visible` 的初值，否则从其它状态切回会残留闭眼。

#### 4.4 循环接缝与实机可读性

- 接缝专项检查：把 `t = 11.9` 与 `t = 0.1` 的画面叠差，除呼吸差值外不应有跳变；循环播放连看 5 圈不能有"顿一下"。
- 12 秒在 `0.32` 缩放下大约 160 px 高，呼吸 6 px 只有 2 屏幕像素：**幅度按"实机能看见"调**，宁可整体再放大 20%，也不要做出看不见的细腻。
- 眨眼在实机至少要有 3 帧可见的闭合状态，否则等于没有。

### 5. 需要生成的素材（交 imagegen 时原样使用）

#### 5.1 眼睛四态图集（主素材）

```text
Use case: identity-preserve.
Asset type: ONE 2x2 expression atlas of the SAME left-facing chibi character head, for building a blink layer in Godot. Not an animation sheet, not a character sheet.
Reference image 1 is the exact character and art style: blue-haired chibi whale maid, single visible eye in left profile view, deep blue hair with pale cyan tips, navy outline, soft cel shading. Reference image 2 shows the current standing pose and framing.
Primary request: four identical head crops, same scale, same head angle, same framing, same lighting, differing ONLY in the visible eye. Each cell shows head and shoulders of the same character facing viewer LEFT, entire head inside the cell with generous padding, transparent background, no body, no hands, no tail, no steel basin, no props.
TOP LEFT: eye fully OPEN. Large round blue iris with darker limbal ring, bright top-left highlight, small lower highlight, thick dark upper lash line, thin lower lid, subtle blush, calm neutral expression. This is the identity anchor; keep the eye shape and iris size exactly as reference 1.
TOP RIGHT: eye HALF CLOSED. Upper lid lowered over the top 45 percent of the iris, lash line following the lid, pupil still visible, highlight reduced, otherwise identical head and expression.
BOTTOM LEFT: eye FULLY CLOSED. Smooth downward curved dark lash line with a soft lid crease, tiny lash tips at the outer corner, calm relaxed face, blush unchanged, no iris visible at all.
BOTTOM RIGHT: eye as a happy upward CRESCENT (closed smiling eye, inverted U curve, small lash tip), cheerful and smug, same head and angle.
Style: polished hand-drawn chibi anime illustration, clean dark navy outlines, soft cel shading, consistent line weight, flat transparent alpha. NOT pixel art, NOT 3D, NOT photoreal, no text, no grid lines, no labels, no frame borders, no cast shadows, no watermark, no makeup, no tears, no winking eyebrow changes.
```

生成后必须做的对齐检查：把四格按同一矩形裁切叠差，除眼睛区域外应完全一致；若头部角度、发饰或脸型有漂移，直接重生成，不要手工拉伸凑。

#### 5.2 可选：关键姿势参考图（给不看代码的人审片用）

```text
Use case: identity-preserve.
Asset type: ONE 4-cell reference board of a 12-second idle performance, not a sprite sheet to be sliced.
Four panels, 2 columns 2 rows, same character, same left-facing standing pose, same scale and framing, transparent background, no text.
Panel 1: neutral stand, eye open, body at rest, tail low and relaxed.
Panel 2: mid-inhale, chest slightly lifted, head a touch higher, tail beginning a small lift, eye open.
Panel 3: playful head tilt toward viewer LEFT, chin slightly raised, smug half-lidded eye, tail flicked up with a cheerful swish.
Panel 4: exhale settle, head back to neutral, eye closed in a slow sleepy blink, steel basin tilted 2 degrees and about to spring back.
Same character, same costume, same lighting in every panel. Do NOT draw a steel basin in panels 1 to 3; only panel 4 shows it tilted. Keep poses subtle, no arm gestures, no steps, no turning.
```

#### 5.3 负向清单（每次生成都带上）

`extra eyes, third eye, different eye color, makeup, tears, wink with eyebrow, changed head angle, changed hairstyle, changed costume, extra fingers, steel basin in panels 1-3, drop shadows, floor, text, watermark, grid, cropped head, mirrored character, 3D render, photoreal, pixel art`

### 6. 验收清单（逐条打勾，缺一返工）

- [ ] 动画文件为 `da_fei_yu_idle_left_v3.tres`，`length = 12.0`、`loop_mode = 1`、动画名 `idle`。
- [ ] 循环连看 5 圈无跳变、无停顿、无"回到原点"的明显接缝。
- [ ] 静音 1 倍速看 30 秒，不觉得重复；1/4 速看，呼吸不是均匀正弦。
- [ ] 三次眨眼间隔不相等，其中一次连眨、一次慢眨；闭眼帧眼睛完全闭合且无虹膜残留。
- [ ] 睁眼帧与修改前逐像素一致（可以裁图对比验证）。
- [ ] 三个俏皮 beat 都能在不看文档的情况下被路人指出来。
- [ ] 脚底像素位置从头到尾不变；角色整体没有位移。
- [ ] 钢盆在歪头与回正时不穿头、不脱头、不遮住眼睛。
- [ ] 实机 0.32 缩放、1066×600 下眨眼与歪头可辨。
- [ ] 冰冻（`speed_scale = 0`）、减速、死亡停播、取盆打断、`reset_idle()` 全部正常，没有多出来的播放器在后台跑。
- [ ] 图鉴头像与开发者召唤里的 Boss 自动用上新待机，无需改代码。
- [ ] 关掉 Godot 后重开，场景无缺失节点/资源警告。

### 7. 交付物

1. `animation/character/zombie_boss/da_fei_yu/da_fei_yu_idle_left_v3.tres`
2. 更新 `da_fei_yu_left_v2_visual.tscn` 的 `idle` 引用（旧 `v2.tres` 保留不删），钢盆场景随之继承。
3. 眼睛层贴图：`res://assets/image/character/boss/da_fei_yu/idle_v3/eye_open.png`、`eye_half.png`、`eye_closed.png`（+ 可选 `eye_crescent.png`）。
4. 复现脚本 `docs/art/bosses/da_fei_yu/idle_v3/build_idle_v3.cjs`，可从零重建动画、眼睛层与钢盆轨道；`rig_manifest.json` 记录 `eye_box`。
5. 预览场景 `scenes/art_preview/da_fei_yu_idle_v3_preview.tscn`：1.0 与 0.32 两种缩放并排、暂停/半速/重播按钮、眨眼时间点标记。
6. 文档 `docs/art/bosses/da_fei_yu/idle_v3/README.md`：动作说明、参数表、录制结果、与 v2 的对比。
7. 录制：12 秒 30 fps MP4 + GIF，另录一段 1/4 速。项目已配置 Movie Maker（`movie_writer/movie_file`），沿用即可。
8. 更新上级 `README.md` 的素材索引一行。

**不要**在未实际运行的情况下声称已通过；按项目约定不新增自动化测试，但要在 README 里写清"看过哪些时刻、哪些缩放"。

---

## 二、执行顺序建议

1. 先做**静态三态眼**：把闭眼/半闭叠在原图上截图对比，确认不跳、不脏，再谈动画。
2. 只做呼吸层，跑 12 秒，确认接缝与重心自然。
3. 加眨眼，单独循环 60 秒看节奏是否"人味"。
4. 最后加三个俏皮 beat——**加完必须回头把幅度砍 20%**，多数第一次都做过头。
5. 用 0.32 实机缩放复核一遍，再录片。

## 三、参数速查

| 项 | 值 |
| --- | --- |
| 循环 | 12.0 s / 30 fps / 360 帧 |
| 呼吸 | 3 × 4 s，幅度 -6.0 / -5.2 / -4.6 px，吸气 1.40 s、停 0.15 s、呼气 2.45 s |
| 跟随 | Body 1.00/0 s，Head 0.92/0.06 s，Hair 0.70/0.25 s，Tail 0.30/0.50 s |
| 重心 | 12 s 正弦 ±2.0 px，头 -0.35 增益反向 |
| 眨眼 | 1.20 s（4 帧）/ 5.45 s + 5.78 s（连眨）/ 9.30 s（9 帧慢眨，后接 0.3 s 半睁） |
| 俏皮 | 尾鳍 3.60–4.30 s，歪头 6.80–8.05 s（-2.8°），钢盆 10.10–11.10 s（+2.2°，阻尼 2 次） |
| 眼层 | Head 下 3 个 Sprite2D，z_index 5，画布与原点一致，仅 `visible` 轨道 |
