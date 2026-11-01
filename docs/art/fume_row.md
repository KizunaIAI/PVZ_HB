# 二星以上大喷菇的整行喷雾

货币战争中的二星、三星大喷菇保留原粒子贴图、粒子尺寸、发射时机和寿命，根据喷口到本行草坪右边缘的距离调整初速度、径向速度、限速曲线与粒子数量。缩小散射角，保持烟雾在本行；扩大 GPU 粒子可见矩形，避免后半行被提前裁剪。

每株使用独立材质及速度曲线，原资源不修改。一星及其他模式沿用原视觉；恢复一星时还原原材质、数量和可见矩形。每次发射从当前世界位置重新计算，兼容移动、缩放和不同场景的草坪宽度。不改变原有伤害、射程和攻击频率。

- 实现：`scripts/character/plant/plant_011_fume_shroom.gd` 的 `set_row_fume_end` 与 `_update_row_fume`。
- 入口：`scripts/currency_war/currency_war_combat.gd` 的星级同步。
- 对照预览：打开 `res://scenes/art_preview/fume_row_preview.tscn` 后 F6，从上到下依次为一星、二星、三星。
- [实机动图](../../artifacts/art/fume_row/fume_row.gif)。

已实际运行前院场景并检查粒子覆盖；未新增或运行自动化测试。运行期间没有发现脚本错误，录制退出仍有资源释放提示。
