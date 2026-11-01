## 大肥鱼的米饭幻想气泡；轮廓由原生绘图组成，米饭盆使用独立贴图。
extends Node2D

## 气泡破碎进度，0 为完整、1 为完全散开；由动作 Tween 驱动。
var burst: float = 0.0:
	set(value):
		burst = value
		queue_redraw()


## 绘制云朵边缘及散开的泡沫；米饭图像由子节点负责。
func _draw() -> void:
	# 云朵外围各圆的位置；扩散时沿中心向外移动。
	var lobes: Array[Vector2] = [Vector2(-85, 0), Vector2(-65, -40), Vector2(-15, -58), Vector2(40, -48), Vector2(83, -12), Vector2(68, 35), Vector2(10, 48), Vector2(-48, 42)]
	# 散开后逐渐缩小每个圆，避免整块白云突然消失。
	var radius: float = lerpf(40.0, 10.0, burst)
	# 遍历云朵外缘圆，先统一画外轮廓。
	for point: Vector2 in lobes:
		draw_circle(point * (1.0 + burst * 0.8), radius + 3.0, Color("#a6bddb"))
	# 遍历相同圆组填白，消除圆与圆重叠处的内边线。
	for point: Vector2 in lobes:
		draw_circle(point * (1.0 + burst * 0.8), radius, Color("#fffdf9"))
	if burst < 0.15:
		draw_rect(Rect2(-68, -40, 130, 80), Color("#fffdf9"))
	draw_circle(Vector2(-62, 108), 13.0 * (1.0 - burst), Color("#fffdf9"))
	draw_circle(Vector2(-78, 142), 7.0 * (1.0 - burst), Color("#fffdf9"))
