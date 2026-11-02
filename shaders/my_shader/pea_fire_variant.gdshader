// 原版火球换色：保持亮度、饱和度、透明边缘和动画，只移动火焰色相。
shader_type canvas_item;

// 目标火焰色相，0为红色，0.77为紫色，范围0至1。
uniform float flame_hue : hint_range(0.0, 1.0) = 0.77;

// 将原火焰颜色转换到HSV，便于保留明暗细节。
vec3 rgb_to_hsv(vec3 color) {
	// 色相计算用的通道偏移常量。
	vec4 offsets = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	// 按通道大小排序后的中间分量。
	vec4 ordered = mix(vec4(color.bg, offsets.wz), vec4(color.gb, offsets.xy), step(color.b, color.g));
	// 最大通道与色相偏移。
	vec4 maximum = mix(vec4(ordered.xyw, color.r), vec4(color.r, ordered.yzx), step(ordered.x, color.r));
	// 通道差值决定饱和度，极小偏移防止灰色像素除零。
	float difference = maximum.x - min(maximum.w, maximum.y);
	return vec3(abs(maximum.z + (maximum.w - maximum.y) / (6.0 * difference + 0.00001)), difference / (maximum.x + 0.00001), maximum.x);
}

// 将换色后的HSV恢复到原纹理颜色空间。
vec3 hsv_to_rgb(vec3 hsv) {
	// 各色通道在当前色相上的权重。
	vec3 weights = abs(fract(hsv.xxx + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return hsv.z * mix(vec3(1.0), clamp(weights - 1.0, 0.0, 1.0), hsv.y);
}

void fragment() {
	// COLOR包含原贴图及节点透明度，保留动画中的淡入淡出。
	vec4 original = COLOR;
	// 原火焰HSV明暗信息，白亮核心因低饱和度自然保留。
	vec3 hsv = rgb_to_hsv(original.rgb);
	hsv.x = fract(flame_hue + (hsv.x - 0.08) * 0.3 + 1.0);
	COLOR = vec4(hsv_to_rgb(hsv), original.a);
}
