# 普通待机重制与攻击动作1

## 动作命名

- **普通待机**：独立十二秒循环，轻呼吸 → 身体先探看、头随后歪向前方 → 停一会儿偷瞄并眨眼 → 尾鳍两下不同力度的回应 → 稍微收肩、回正。脚底不位移，重心、头发和盆随身体意图跟随，避免同相位机械摇摆。
- **攻击动作1**：此前的取盆、端盆幻想、幻想被打断后生气丢盆流程。当前公开入口为 `play_attack_1()`；旧 `play_dream_idle()` 仅作兼容转发。

游戏出场先播放普通待机一轮，再启动攻击动作1；攻击恢复后先回普通待机。图鉴持续普通待机，攻击动作可在独立动作预览中查看。当前时长可通过 Boss 的 `dream_delay` 和 `recovery_duration` 调整。

## 真正的眼睑眨眼

旧版只是肤色遮眼，原高位睫毛没有闭合；该方案已移除。旧图层还包含完整人物，会覆盖骨骼变形后的身体，本轮一并移除。

本次用内置 imagegen 分别重画了站立、取盆、端盆、蓄力、丢盆五种姿势的半闭、全闭眼：上眼睑带着睫毛下移，完整闭合后没有虹膜，睁眼再返回原图。眉毛和原有情绪不作为眨眼切换项。每种姿势使用自己的眼部帧，避免生硬套用同一只眼。

运行中只显示原画眼窝附近的一小块真实眼睑，边缘由局部轮廓羽化；不会整张盖回闭眼人物或在头发上贴矩形肤色。

- 自然眨眼约 0.21 秒，闭合快、睁开稍慢；十二秒内不等间隔，包含一次连眨。
- 取盆、蓄力与丢盆另有短眨拍点，端盆等待继续自然眨眼。
- 眼睑挂在头部骨骼或对应姿势下，随姿势变换；暂停、冻结和动画倍率均同步。

## 素材与实现

- 原始脸部参考、imagegen 两列原图及 [提示词](prompt.md) 均保存在本目录；目录使用 `.gdignore` 排除非运行素材。
- [manifest.json](manifest.json) 记录每个姿势的对齐区域。
- `prepare_blinks.cjs` 只作图集分格、裁切及尺寸适配；没有用程序填肤色或重绘眼睛。
- 运行贴图：`assets/image/character/boss/da_fei_yu/blink_v4/*_half.png`、`*_closed.png`。
- 眨眼播放器：`scripts/art_preview/da_fei_yu_blink.gd`。
- 羽化材质：`shaders/my_shader/da_fei_yu_blink.gdshader`。
- 普通待机资源：`animation/character/zombie_boss/da_fei_yu/da_fei_yu_ordinary_idle.tres` 及带盆版本。
- 可复现命令：依次运行本目录的 `prepare_blinks.cjs`、`build_ordinary_idle.cjs`、`attach_blinks.cjs`。

## 查看

- 普通待机：`res://scenes/art_preview/da_fei_yu_ordinary_idle_preview.tscn`。
- 普通待机与攻击动作1准备段：`res://scenes/art_preview/da_fei_yu_natural_idle_preview.tscn`。
- 完整攻击动作1及植物打断：`res://scenes/art_preview/da_fei_yu_basin_actions_preview.tscn`。

已运行 Godot 检查各姿势的实际眨眼帧、眼部对齐及普通待机，未新增或运行自动化测试。

预览导出位于 `artifacts/art/da_fei_yu/`：`ordinary_idle_v4.gif` / `.mp4` 为完整普通待机，`eyelid_slow.gif` 为眼睑慢放，`attack1_blink.mp4` 为攻击动作1。另录制了二十二秒游戏内流程，确认普通待机后进入攻击动作1，并对打破幻想的植物丢盆造成伤害。该录制退出时仍有两项 ObjectDB 实例与一项资源未释放提示；未在本次美术修改中处理退出清理。
