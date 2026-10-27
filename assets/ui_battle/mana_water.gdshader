shader_type canvas_item;

// 맥 수조의 물: 물 텍스처 한 장을 가면 안에서만 흘리고, 수위·수면 기울기·잔물결을 조각 픽셀 단위로 정한다.
// 시계와 수위는 전투 화면이 넘긴다(일시정지·흔들림 줄이기를 따름). TIME은 쓰지 않는다
uniform sampler2D mask_tex : filter_nearest;
uniform float surface = 12.0;
uniform float tilt = 0.0;
uniform float clock = 0.0;
uniform float flow = 1.0;

void fragment() {
	vec2 grid = vec2(textureSize(TEXTURE, 0));
	vec2 px = floor(UV * grid);
	if (texture(mask_tex, (px + 0.5) / grid).a < 0.5) {
		discard;
	}
	float wave = flow * sin(clock * 2.1 + px.x * 0.45) * 0.5;
	float s = floor(surface + tilt * (px.x - grid.x * 0.5) / (grid.x * 0.5) + wave + 0.5);
	if (px.y < s) {
		discard;
	}
	vec2 shift = vec2(floor(clock * 2.0 * flow), floor(clock * 0.7 * flow));
	vec4 c = texture(TEXTURE, (mod(px + shift, grid) + 0.5) / grid);
	if (px.y < s + 1.0) {
		c.rgb = vec3(0.851, 0.969, 1.0);
	}
	COLOR = vec4(c.rgb, 1.0);
}
