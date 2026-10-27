shader_type canvas_item;

// 올린 카드 위를 비스듬히 한 번 지나가는 빛줄기. 카드 틀 알파로 잘라 빈 모서리에는 안 그린다
uniform sampler2D mask : filter_nearest;
uniform float t = -1.0;

void fragment() {
	float d = UV.x * 0.8 + UV.y * 0.45 - t * 1.25;
	float band = smoothstep(0.09, 0.0, abs(d)) * 0.32 + smoothstep(0.025, 0.0, abs(d - 0.06)) * 0.18;
	COLOR = vec4(1.0, 0.97, 0.86, band * texture(mask, UV).a);
}
