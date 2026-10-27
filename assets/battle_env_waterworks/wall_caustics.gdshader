shader_type canvas_item;
render_mode blend_add;

// 수로 바로 위 벽·기둥 밑부분의 물 반사광: 가느다란 밝은 무늬가 천천히 흐르고, 물가(아래)일수록 진하다.
// 2px 덩어리 · 초당 6장으로 끊어 배경 도트와 맞춘다. 시계는 환경 시계(flow_clock)를 받는다
uniform float flow_clock = 0.0;
uniform float strength = 0.16;
uniform vec4 tint : source_color = vec4(0.45, 0.86, 0.88, 1.0);
uniform vec2 size = vec2(1440.0, 104.0);

void fragment() {
	vec2 p = floor(UV * size / 2.0) * 2.0;
	float t = floor(flow_clock * 6.0) / 6.0;
	float a = sin(p.x * 0.043 + t * 0.8 + sin(p.y * 0.09 + t * 0.55) * 1.7);
	float b = sin(p.x * 0.067 - t * 0.6 + p.y * 0.05 + 1.3);
	float line = smoothstep(0.80, 0.97, a * 0.62 + b * 0.38 + 0.18);
	float fade = smoothstep(0.05, 1.0, UV.y) * (1.0 - smoothstep(0.93, 1.0, UV.y));
	COLOR = vec4(tint.rgb, line * fade * strength);
}
