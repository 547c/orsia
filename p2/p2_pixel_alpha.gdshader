shader_type canvas_item;
render_mode blend_premul_alpha;
// 픽셀 그림판의 반투명을 몇 단계로 줄이고 4×4 바이어 무늬로 디더링한다(손으로 찍은 픽셀 그림의 빛·잔상처럼)
uniform float levels = 4.0;
varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (c.a < 0.004) {
		COLOR = vec4(0.0);
	} else {
		ivec2 p = ivec2(floor(UV / TEXTURE_PIXEL_SIZE));
		int idx = (p.x % 4) + (p.y % 4) * 4;
		float bayer[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
		float a = clamp(floor(c.a * levels + (bayer[idx] + 0.5) / 16.0) / levels, 0.0, 1.0);
		vec3 rgb = c.rgb / c.a;
		COLOR = vec4(rgb * tint.rgb * a * tint.a, a * tint.a);
	}
}
