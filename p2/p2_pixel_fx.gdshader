shader_type canvas_item;
render_mode blend_premul_alpha;
// 효과 그림판(3배 픽셀): 반투명을 몇 단계로 · 색을 몇 단계로 줄여 바이어 무늬로 디더링(손으로 찍은 픽셀 효과처럼),
// 어두운 쪽은 보랏빛으로 기울이고, 단단한 덩어리 둘레엔 어두운 외곽선 한 칸
uniform float levels = 4.0;
uniform float tones = 5.0;
uniform vec4 outline : source_color = vec4(0.07, 0.04, 0.1, 0.92);
varying vec4 tint;

void vertex() {
	tint = COLOR;
}

float bayer(ivec2 p) {
	int idx = (p.x % 4) + (p.y % 4) * 4;
	float m[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (m[idx] + 0.5) / 16.0;
}

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec4 c = texture(TEXTURE, UV);
	ivec2 p = ivec2(floor(UV / px));
	float b = bayer(p);
	if (c.a < 0.03) {
		float n = max(max(texture(TEXTURE, UV + vec2(px.x, 0.0)).a, texture(TEXTURE, UV - vec2(px.x, 0.0)).a),
			max(texture(TEXTURE, UV + vec2(0.0, px.y)).a, texture(TEXTURE, UV - vec2(0.0, px.y)).a));
		float o = step(0.6, n) * outline.a * tint.a;
		COLOR = vec4(outline.rgb * o, o);
	} else {
		float a = clamp(floor(c.a * levels + b) / levels, 0.0, 1.0);
		vec3 rgb = clamp(c.rgb / c.a, 0.0, 1.0);
		rgb = floor(rgb * tones + b) / tones;
		float l = dot(rgb, vec3(0.3, 0.59, 0.11));
		rgb = mix(rgb, rgb * vec3(0.8, 0.76, 1.15), (1.0 - l) * 0.4);
		rgb *= tint.rgb;
		COLOR = vec4(rgb * a * tint.a, a * tint.a);
	}
}
