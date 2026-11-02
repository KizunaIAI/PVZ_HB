# 视频接入前的动画保留

- `pre_video_20261102.zip`：接入前原样快照，包含 107 个文件，覆盖原 Boss 场景、全部旧动画外观和动画资源、相关预览脚本、旧眨眼着色器及原有图片素材。
- 可独立打开的旧版 Boss：`res://scenes/character/zombie_boss/da_fei_yu/legacy/da_fei_yu_boss_legacy.tscn`，使用复制保留的 `scripts/character/zombie_boss/legacy/da_fei_yu_boss_legacy.gd`。
- 原骨骼、钢盆、取盆幻想、丢盆和眼睛形变场景仍在原路径，原美术预览仍可单独查看。当前正式 Boss 与图鉴均切到视频方案，不实例化这些旧动画。
- 旧版入场延时、反击来源及伤害逻辑完整保存在 legacy 脚本；当前视频版已另接用户提供的幻想上、幻想下素材，并复用相同的真实攻击者反击规则，不混播旧骨骼画面。

快照用于保留与比对，不要直接解压覆盖当前视频接入。查看旧版本优先打开 legacy 场景。
