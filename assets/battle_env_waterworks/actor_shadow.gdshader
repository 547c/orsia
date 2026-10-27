shader_type canvas_item;

// 배우 실루엣을 바닥에 눕힌 그림자. 발에서 멀수록(머리 쪽) 옅어진다. 색·세기는 modulate로 준다
uniform float foot_v = 1.0;

void fragment() {
	float a = texture(TEXTURE, UV).a;
	float d = clamp((foot_v - UV.y) / foot_v, 0.0, 1.0);
	COLOR = vec4(COLOR.rgb, a * COLOR.a * mix(1.0, 0.25, d));
}
