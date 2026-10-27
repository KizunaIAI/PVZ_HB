shader_type canvas_item;

// 原版单行草皮的边缘遮罩，使用白色区域保留自然草叶轮廓。
uniform sampler2D edge_mask : filter_linear;

void fragment() {
	// 保留原始草皮颜色，仅裁掉黑色背景，便于叠放在原版泥地上。
	// 同时兼容黑白区域和透明边缘，防止透明像素残留白色RGB时出现黑框。
	vec4 edge = texture(edge_mask, UV);
	COLOR.a *= edge.r * edge.a;
}
