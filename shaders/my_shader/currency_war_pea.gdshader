shader_type canvas_item;

// 独立弹丸色调，保留原纹理的透明轮廓与明暗，不改写原版豌豆图片。
uniform vec4 pea_tint : source_color = vec4(1.0);

void fragment() {
	vec4 texel = texture(TEXTURE, UV);
	float light = max(texel.r, max(texel.g, texel.b));
	vec3 tint = mix(pea_tint.rgb * light, vec3(light), pow(light, 8.0) * 0.45);
	COLOR *= vec4(tint, texel.a);
}
