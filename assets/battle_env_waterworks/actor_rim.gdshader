shader_type canvas_item;
render_mode blend_add;

// 실루엣 가장자리 중 빛을 향한 곳만 밝힌다: 가까운 횃불 쪽은 따뜻하게, 위쪽은 물빛으로 옅게
uniform vec2 light_dir = vec2(-1.0, 0.0);
uniform float px = 1.0;
uniform vec4 warm : source_color = vec4(1.0, 0.74, 0.42, 0.55);
uniform vec4 cool : source_color = vec4(0.40, 0.78, 0.90, 0.22);

void fragment() {
	float a = step(0.5, texture(TEXTURE, UV).a);
	float w = a * (1.0 - step(0.5, texture(TEXTURE, UV + light_dir * TEXTURE_PIXEL_SIZE * px).a));
	float c = a * (1.0 - step(0.5, texture(TEXTURE, UV + vec2(0.0, -1.0) * TEXTURE_PIXEL_SIZE * px).a));
	COLOR = vec4((warm.rgb * warm.a * w + cool.rgb * cool.a * c) * COLOR.a, max(w, c) * COLOR.a);
}
