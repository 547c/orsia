shader_type canvas_item;
render_mode unshaded;

// 충격파: 원(최대 4개)이 퍼지며 띠 안의 화면을 바깥으로 밀어 굴절시키고, 띠 가장자리에 옅은 빛. w = (x, y, 반지름, 세기) 화면 px
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform vec2 view_px = vec2(1280.0, 720.0);
uniform vec4 w0 = vec4(0.0);
uniform vec4 w1 = vec4(0.0);
uniform vec4 w2 = vec4(0.0);
uniform vec4 w3 = vec4(0.0);
uniform int count = 0;
uniform float width = 30.0;

void fragment() {
	vec2 p = SCREEN_UV * view_px;
	vec2 off = vec2(0.0);
	float lit = 0.0;
	for (int i = 0; i < 4; i++) {
		if (i >= count) {
			break;
		}
		vec4 w = i == 0 ? w0 : (i == 1 ? w1 : (i == 2 ? w2 : w3));
		vec2 d = p - w.xy;
		float r = length(d);
		float band = 1.0 - smoothstep(0.0, width, abs(r - w.z));
		if (r > 0.5) {
			off += d / r * band * w.w;
		}
		lit = max(lit, band * clamp(w.w / 14.0, 0.0, 1.0));
	}
	vec3 col = texture(screen_tex, SCREEN_UV - off / view_px).rgb;
	col = mix(col, col * 1.25 + vec3(0.06), lit * 0.5);
	COLOR = vec4(col, 1.0);
}
