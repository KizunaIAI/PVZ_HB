shader_type canvas_item;

// 原版整块草皮的边缘，五行背景直接显示原图。
uniform sampler2D edge_mask : filter_linear;
uniform bool use_edge_mask = false;
// 图片在庭院背景中的原点与原始像素尺寸。
uniform vec2 image_origin = vec2(0.0);
uniform vec2 image_size = vec2(1400.0, 600.0);
// 已有草坪的纵向区间；负值表示开局没有已铺区域。
uniform vec2 previous_band = vec2(-1.0);
// 新区域从左到右展开的比例，完成后为1。
uniform float reveal : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 pixel = image_origin + UV * image_size;
	float existing = step(previous_band.x, pixel.y) * step(pixel.y, previous_band.y);
	float unrolled = step(pixel.x, mix(237.0, 1012.0, reveal));
	float edge = use_edge_mask ? texture(edge_mask, UV).r * texture(edge_mask, UV).a : 1.0;
	COLOR.a *= edge * max(existing, unrolled);
}
