# 大肥鱼 · 自然待机

修改前已提交本地检查点 `7db8314`，包含当时所有未提交且未被 Git 忽略的开发内容；未推送远程。

这次保留角色贴图、头身比例及用户钢盆变换，使用 Godot 原生骨骼和 AnimationPlayer 优化持续待机：

- 八秒完整循环，包含两次略有差异的呼吸；吸气约 1.5 秒，呼气约 2.5 秒。
- 躯干先动，头与双手略后跟随，长发和鲸尾再延迟跟随；使用三次插值及首尾同速的循环。
- 身体只做很小的重心变化，脚掌所在区域固定，不再整体上下漂浮。
- 戴盆站立沿用已有五骨骼；端盆姿势新增六骨骼网格，双手单独控制。
- 独立钢盆直接跟随端盆双手骨骼，气泡缓慢漂浮；二者均与八秒循环对齐。
- 游戏和图鉴自动使用同一份更新后的资源。冰冻、减速及死亡停播同步覆盖新增端盆播放器。

本轮优化的是持续待机。取盆、蓄力及丢盆仍沿用此前关键姿势，没有新增眨眼贴图或改变技能时机。

## 文件及预览

- 站立循环：`animation/character/zombie_boss/da_fei_yu/da_fei_yu_idle_left_v2.tres`。
- 端盆循环：`animation/character/zombie_boss/da_fei_yu/da_fei_yu_hold_idle.tres`。
- 端盆骨骼场景：`scenes/character/zombie_boss/da_fei_yu/da_fei_yu_hold_idle_visual.tscn`。
- 并排预览：打开 `res://scenes/art_preview/da_fei_yu_natural_idle_preview.tscn` 后 F6。
- [引擎录制动图](../../../../artifacts/art/da_fei_yu/natural_idle.gif)、[录像](../../../../artifacts/art/da_fei_yu/natural_idle.mp4)。
- 复现：在仓库根目录运行 `node docs/art/bosses/da_fei_yu/build_natural_idle.cjs`；只写入本次动画和新端盆场景，不写回基础钢盆场景。

已在 Godot 实际运行并检查骨骼变形和站立／端盆对照。按项目约定未新增或运行自动化测试。新待机修改留在工作区，便于查看；本地 Git 检查点是修改之前的状态。
