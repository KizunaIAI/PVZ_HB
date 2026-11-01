# 大肥鱼：待机动画第一版

- 阶段：美术预览，等待用户确认表现。
- 形象基准：上级目录的 [reference.png](../reference.png)。
- 生成方式：内置 imagegen 工具；[完整生成提示词](prompt.txt)。
- 动作：小幅呼吸起伏，发梢、鲸鱼尾巴轻摆，以及一次眨眼。
- 视角：接近正面、略朝左，保留脸部与鲸鱼尾巴的辨识度。
- 帧数：八帧，依次从左到右、从上到下读取。
- 循环时长：两秒；逐帧停留时间为 300、300、300、300、300、100、100、300 毫秒。
- 导出帧尺寸：512 × 512 像素，RGBA 透明 PNG。
- 对齐：统一脚底基线为帧内 y = 480 像素。切分与补充透明留白保留生成图的原有绘制内容。

## 文件

- [idle_preview.gif](idle_preview.gif)：循环动图，供直接预览动作与节奏；GIF 颜色与透明边缘受格式限制，正式素材以 PNG 为准。
- [idle_atlas.png](idle_atlas.png)：2048 × 1024 像素的规则精灵表，四列两行。
- [frames](frames/)：八张独立透明 PNG，命名为 `idle_01.png` 至 `idle_08.png`。
- [idle_sheet.png](idle_sheet.png)：图像工具原始生成图，1774 × 887 像素，保留用于追溯。
- [animation.json](animation.json)：逐帧播放时长、尺寸及切分来源信息。
- [preview_frames.txt](preview_frames.txt)：动图编码时使用的播放顺序与时长。
- [prompt.txt](prompt.txt)：本次提交给内置 imagegen 的完整提示词。

## 状态

已查看帧图并核对导出文件的尺寸、帧数与循环时长。尚未接入 Godot，未运行测试。
