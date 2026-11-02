// CC0符文纹理的蓝青色贴地法阵，UV旋转保持投影椭圆不倾斜。
shader_type canvas_item;
render_mode blend_add, unshaded;

// 宿主传入的原速游戏秒，避免TIME在暂停时继续运行。
uniform float elapsed = 0.0;
// 法阵生命周期包络透明度。
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	// 平面旋转的中心坐标，外围留出泛光余量。
	vec2 centered = (UV - vec2(0.5)) * 1.12;
	// 法阵原速旋转相位。
	float angle = elapsed * 1.25;
	// 旋转后采样位置，不旋转屏幕上的贴地椭圆。
	vec2 sample_uv = mat2(vec2(cos(angle), -sin(angle)), vec2(sin(angle), cos(angle))) * centered + vec2(0.5);
	// 原SVG透明轮廓，保留符文线条。
	float ink = texture(TEXTURE, sample_uv).a;
	// 泛光取样间距，以原贴图像素为单位。
	vec2 step_uv = TEXTURE_PIXEL_SIZE * 4.0;
	// 四方向采样的柔和光晕。
	float glow = (texture(TEXTURE, sample_uv + vec2(step_uv.x, 0.0)).a + texture(TEXTURE, sample_uv - vec2(step_uv.x, 0.0)).a + texture(TEXTURE, sample_uv + vec2(0.0, step_uv.y)).a + texture(TEXTURE, sample_uv - vec2(0.0, step_uv.y)).a) * 0.25;
	// 出生时的短促中心蓝光。
	float center_glow = exp(-dot(centered, centered) * 18.0) * exp(-elapsed * 3.0);
	// 旋转到纹理边界外时清空，避免边缘夹取拉出四角亮块。
	float bounds = step(0.001, sample_uv.x) * step(sample_uv.x, 0.999) * step(0.001, sample_uv.y) * step(sample_uv.y, 0.999);
	COLOR = vec4(vec3(0.2, 0.72, 1.0) * (ink + glow * 0.5) * bounds + vec3(0.35, 0.7, 0.85) * center_glow, opacity);
}
