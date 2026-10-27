shader_type canvas_item;

uniform sampler2D maek_mask : filter_linear, repeat_disable;
uniform float flow_time = 0.0;
uniform float flow_amount : hint_range(0.0, 1.0) = 0.8;
uniform float flow_speed : hint_range(0.0, 2.0) = 0.75;
uniform float flow_density : hint_range(4.0, 24.0) = 12.0;
uniform vec4 flash_color : source_color = vec4(1.0);
uniform float flash_mix : hint_range(0.0, 1.0) = 0.0;
uniform float breath_amount : hint_range(0.0, 0.08) = 0.0;
uniform float breath_phase : hint_range(0.0, 1.0) = 0.0;
uniform float breath_pivot_uv : hint_range(0.0, 1.0) = 0.65;

varying vec4 actor_modulation;

void vertex() {
	actor_modulation = COLOR;
}

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float smooth_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0)), f.x), f.y);
}

void fragment() {
	// Breath stretches only above the waist; artwork and mask share the same UV so the flow stays on the body.
	vec2 uv = UV;
	if (uv.y < breath_pivot_uv) {
		uv.y = breath_pivot_uv + (uv.y - breath_pivot_uv) / (1.0 + breath_amount * breath_phase);
	}
	// Vertex modulation (modulate/self_modulate, death fade) is applied once here.
	vec4 base = texture(TEXTURE, uv) * actor_modulation;
	float mask = texture(maek_mask, uv).r;
	vec2 p = uv * vec2(flow_density * 0.7, flow_density);
	p.y -= flow_time * flow_speed;
	float bend = smooth_noise(p * vec2(0.45, 0.35)) * 3.5;
	float broad = sin(p.y * 6.283185 + sin(p.x * 1.8) * 1.2 + bend);
	float crest = smoothstep(0.25, 0.93, broad);
	float fine = smoothstep(0.45, 0.9, sin(p.y * 9.4 + p.x * 1.4 + bend * 2.0));
	float ripple = crest * 0.75 + fine * 0.25;
	// Local moving surface contrast, not whole-body alpha/UV distortion or a bead.
	vec3 water = base.rgb * (0.85 + ripple * 0.22);
	water += vec3(0.02, 0.12, 0.18) * ripple;
	vec3 result = mix(base.rgb, water, mask * flow_amount);
	COLOR = vec4(mix(result, flash_color.rgb, flash_mix), base.a);
}
