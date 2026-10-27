shader_type canvas_item;
render_mode unshaded;

// 공간베기: 화면을 가르는 선(최대 3)이 차례로 한쪽 끝부터 그어지고(reveal), 선 양쪽 화면이 선을 따라 미끄러지며(slide) 벌어진다(gap).
// 벌어진 틈은 어둡고 가장자리가 빛난다. tint = 화면을 차갑게 가라앉힘. 픽셀 화면이라 선과 틈은 계단 없이 또렷하게(2px 단위)
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform vec2 view_px = vec2(1280.0, 720.0);
uniform vec4 line0 = vec4(640.0, 300.0, 1.0, 0.0);
uniform vec4 line1 = vec4(640.0, 300.0, 0.0, 1.0);
uniform vec4 line2 = vec4(640.0, 300.0, 0.7, 0.7);
uniform int count = 1;
uniform float span = 1700.0;
uniform float reveal = 0.0;
uniform float slide = 0.0;
uniform float gap = 0.0;
uniform float glow = 0.0;
uniform float tint = 0.0;
uniform float flash = 0.0;
uniform vec4 edge_color : source_color = vec4(0.85, 0.95, 1.0, 1.0);

void fragment() {
	vec2 p = floor(SCREEN_UV * view_px / 2.0) * 2.0;
	vec2 off = vec2(0.0);
	float seam = 0.0;
	float void_k = 0.0;
	float shade = 0.0;
	for (int i = 0; i < 3; i++) {
		if (i >= count) {
			break;
		}
		vec4 L = i == 0 ? line0 : (i == 1 ? line1 : line2);
		vec2 d = normalize(L.zw);
		vec2 n = vec2(-d.y, d.x);
		float s = dot(p - L.xy, n);
		float a = dot(p - L.xy, d) + span * 0.5;
		float shown = step(a, span * clamp((reveal - float(i) * 0.22) / 0.56, 0.0, 1.0));
		float side = s >= 0.0 ? 1.0 : -1.0;
		off += side * (d * slide * 0.5 + n * gap * 0.5) * shown;
		shade += side * (0.05 + 0.03 * float(i)) * shown * step(0.5, gap);
		float edge = abs(s) - gap * 0.5;
		seam = max(seam, step(edge, 2.0) * step(-2.0, edge) * shown);
		void_k = max(void_k, step(abs(s), gap * 0.5 - 1.0) * shown);
	}
	vec3 col = texture(screen_tex, SCREEN_UV - off / view_px).rgb;
	float g = dot(col, vec3(0.3, 0.59, 0.11));
	col = mix(col, vec3(g * 0.7, g * 0.82, g * 1.1), tint);
	col *= 1.0 + shade;
	col = mix(col, vec3(0.02, 0.02, 0.06), void_k);
	col = mix(col, edge_color.rgb, seam * glow);
	col = mix(col, vec3(1.0, 0.98, 0.94), flash);
	COLOR = vec4(col, 1.0);
}
