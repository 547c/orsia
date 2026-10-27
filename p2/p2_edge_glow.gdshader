shader_type canvas_item;
// 화면 가장자리 빛(낮은 체력 심장 박동 · 연속 10의 금빛 테두리): 가장자리에서 width px 안쪽으로 옅어지고, 2px 칸 4×4 바이어 무늬로 몇 단계만
uniform vec4 tint : source_color = vec4(0.85, 0.08, 0.06, 1.0);
uniform float amount = 0.0;
uniform float width = 110.0;
uniform vec2 view = vec2(1280.0, 720.0);

void fragment() {
	vec2 p = UV * view;
	vec2 m = min(p, view - p);
	float edge = 1.0 - smoothstep(0.0, width, min(m.x, m.y));
	float corner = 1.0 - smoothstep(0.0, width * 1.6, length(m));
	float e = clamp(max(edge, corner) * amount, 0.0, 1.0);
	ivec2 q = ivec2(floor(p / 2.0));
	int idx = (q.x % 4) + (q.y % 4) * 4;
	float bayer[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	float a = clamp(floor(e * 3.0 + (bayer[idx] + 0.5) / 16.0) / 3.0, 0.0, 1.0);
	COLOR = vec4(tint.rgb, a * tint.a * 0.6);
}
