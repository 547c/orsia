shader_type canvas_item;
render_mode unshaded;

// 화면 색 손질 한 장(사건 동안만 켬): 색 분리(chroma, chroma_c에서 바깥으로) · 방사 흐림(zoom, 큰 한 방) · 채도 빼기(desat) · 물들이기(tint) ·
// 열 아지랑이(haze, 바닥 쪽) · 위아래 검은 띠(bars, 차징·필살) · 가장자리 어둡게(vig, vig_color로 물들임)
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform vec2 view_px = vec2(1280.0, 720.0);
uniform float t = 0.0;
uniform float chroma = 0.0;
uniform vec2 chroma_c = vec2(640.0, 360.0);
uniform float zoom = 0.0;
uniform vec2 zoom_c = vec2(640.0, 360.0);
uniform float desat = 0.0;
uniform vec4 tint_color : source_color = vec4(0.6, 0.25, 0.95, 1.0);
uniform float tint = 0.0;
uniform float haze = 0.0;
uniform float bars = 0.0;
uniform float vig = 0.0;
uniform vec4 vig_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	vec2 p = SCREEN_UV * view_px;
	vec2 uv = SCREEN_UV;
	if (haze > 0.0) {
		float w = sin(p.y * 0.08 + t * 9.0) * cos(p.x * 0.03 - t * 6.0);
		uv += vec2(w * 3.5, sin(p.x * 0.05 + t * 7.0) * 2.0) * haze / view_px * smoothstep(140.0, 430.0, p.y);
	}
	vec3 col;
	if (zoom > 0.001) {
		vec2 dz = (uv - zoom_c / view_px) * zoom * 0.09;
		col = vec3(0.0);
		for (int k = 0; k < 7; k++) {
			col += texture(screen_tex, uv - dz * float(k) / 6.0).rgb;
		}
		col /= 7.0;
	} else if (chroma > 0.0) {
		vec2 dir = normalize(p - chroma_c + vec2(0.001, 0.0));
		col.r = texture(screen_tex, uv + dir * chroma / view_px).r;
		col.g = texture(screen_tex, uv).g;
		col.b = texture(screen_tex, uv - dir * chroma / view_px).b;
	} else {
		col = texture(screen_tex, uv).rgb;
	}
	float g = dot(col, vec3(0.3, 0.59, 0.11));
	col = mix(col, vec3(g), desat);
	col = mix(col, clamp(col * tint_color.rgb * 1.7, 0.0, 1.0), tint);
	float vd = length((SCREEN_UV - 0.5) * vec2(1.6, 1.0));
	float vk = clamp(vig * smoothstep(0.3, 0.95, vd), 0.0, 1.0);
	col = mix(col, col * 0.25 + vig_color.rgb * 0.5, vk);
	float bh = bars * 96.0;
	if (p.y < bh || p.y > view_px.y - bh) {
		col = vec3(0.0);
	}
	COLOR = vec4(col, 1.0);
}
