shader_type canvas_item;
render_mode blend_add;
// 빛 효과 그림판(3배 픽셀, 더하기): 밝기를 몇 단계로 줄여 바이어 무늬로 디더링해 화면에 더한다(빛이 픽셀 계단으로 번짐)
uniform float tones = 5.0;
varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	ivec2 p = ivec2(floor(UV / TEXTURE_PIXEL_SIZE));
	int idx = (p.x % 4) + (p.y % 4) * 4;
	float m[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	float b = (m[idx] + 0.5) / 16.0;
	vec3 rgb = floor(clamp(c.rgb, 0.0, 1.0) * tones + b) / tones;
	COLOR = vec4(rgb * tint.rgb * tint.a, 1.0);
}
