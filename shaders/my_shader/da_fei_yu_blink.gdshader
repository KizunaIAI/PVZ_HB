// 原人物纹理自身的连续 UV 形变，不使用额外贴图或遮眼颜色。
shader_type canvas_item;

// 原图左右眼角的 X 与 Y，单位为原图像素。
uniform vec4 eye_shape;
// 逐姿势标定的上下眼缘，各九个等距采样点，单位为原图像素。
uniform float upper_line[9];
uniform float lower_line[9];
// 随上眼睑平移的原有睫毛带厚度，单位为原图像素。
uniform float lash_height = 6.0;
// 眉毛下方参与展开的原有眼皮高度，单位为原图像素。
uniform float skin_height = 0.8;
// 闭合程度，0 睁开、1 闭合。
uniform float closure : hint_range(0.0, 1.0) = 0.0;
// 保留原人物与父级的调色、受击闪光和透明度。
varying vec4 character_tint;

void vertex() {
	character_tint = COLOR;
}

void fragment() {
	// 骨骼变形后仍使用原画 UV，眼睛随原人物表面运动。
	vec2 point = UV / TEXTURE_PIXEL_SIZE;
	// 默认采样位置保持不变，只有眼窝内执行反向形变映射。
	vec2 source = point;
	// 归一化横向位置，两端眼角处的上下弧线自然相接。
	float across = (point.x - eye_shape.x) / max(eye_shape.y - eye_shape.x, 1.0);
	if (closure > 0.0 && across > 0.0 && across < 1.0) {
		// 分段拟合原睫毛，避免将黑色睫毛误当作可展开的皮肤。
		float section = across * 8.0;
		int left = min(int(section), 7);
		float fraction = fract(section);
		float upper = mix(upper_line[left], upper_line[left + 1], fraction);
		float lower = mix(lower_line[left], lower_line[left + 1], fraction);
		// 原睫毛带整条下移，厚度不随眼球收拢而缩小。
		float lash = min(lash_height, max(0.0, lower - upper - 0.05));
		float travel = max(0.0, lower - upper - lash - 0.05) * closure;
		float lid = upper + travel;
		float forehead = upper - skin_height;
		if (point.y >= forehead && point.y < lid) {
			// 原有眼皮向下展开，所有颜色仍取自原人物。
			source.y = forehead + (point.y - forehead) * skin_height / max(lid - forehead, 0.001);
		} else if (point.y >= lid && point.y < lid + lash) {
			source.y = point.y - travel;
		} else if (point.y >= lid + lash && point.y < lower) {
			// 眼白和虹膜收拢到眼缘，全闭时剩余高度不足 0.1 像素。
			source.y = upper + lash + (point.y - lid - lash) * (lower - upper - lash) / max(lower - lid - lash, 0.001);
		}
	}
	COLOR = texture(TEXTURE, source * TEXTURE_PIXEL_SIZE) * character_tint;
}
