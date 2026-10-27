shader_type canvas_item;
// 화면 전환: 검은 막이 4px 칸 바이어 무늬로 가장자리부터 center 쪽으로 덮인다(progress 0 = 다 보임, 1 = 다 덮임). 거꾸로 돌리면 center부터 열린다
uniform float progress = 0.0;
uniform vec2 center = vec2(640.0, 360.0);
uniform vec2 view = vec2(1280.0, 720.0);
uniform float cell = 4.0;

void fragment() {
	vec2 p = UV * view;
	ivec2 q = ivec2(floor(p / cell));
	int idx = (q.x % 4) + (q.y % 4) * 4;
	float bayer[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	float far = length(view) * 0.8;
	float d = 1.0 - clamp(length((vec2(q) + 0.5) * cell - center) / far, 0.0, 1.0);
	float th = d * 0.72 + (bayer[idx] + 0.5) / 16.0 * 0.28;
	COLOR = vec4(0.0, 0.0, 0.0, progress >= 0.999 ? 1.0 : step(th, progress));
}
