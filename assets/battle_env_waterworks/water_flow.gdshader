shader_type canvas_item;

// 수면: 2px 칸 · 초당 fps장으로 끊어 움직이는 픽셀 물. 원래 물결 무늬는 옅게 깔고, 줄마다 속도·간격이 다른 물결 마루(앞줄일수록 빠르고 길게),
// 횃불 아래 흔들리는 주황 반사, 물줄기 아래 푸른 반사와 떨어지는 자리의 거품을 얹는다
uniform sampler2D flow_pattern : filter_nearest, repeat_enable;
uniform float flow_clock = 0.0;
uniform float fps = 8.0;
uniform float strength : hint_range(0.0, 1.0) = 0.85;
uniform vec2 canvas_origin = vec2(-80.0, -80.0);
uniform vec2 torch_x = vec2(156.0, 1223.0);
uniform vec2 fall_x = vec2(398.0, 1146.0);
uniform float top_y = 246.0;
varying vec4 item_modulation;

void vertex() {
    item_modulation = COLOR;
}

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
    vec2 s = UV / TEXTURE_PIXEL_SIZE + canvas_origin;
    vec2 c = floor(s / 2.0);
    float t = floor(flow_clock * fps);
    float row = c.y - floor(top_y / 2.0);
    float mask = texture(TEXTURE, UV).a;
    vec4 ripple = texture(flow_pattern, vec2((c.x - t) / 256.0, (c.y - 121.0) / 48.0));
    vec3 col = ripple.rgb;
    float a = ripple.a * 0.4;
    // 물결 마루: 두 줄에 한 줄, 줄마다 간격 · 길이 · 출발점이 다르고 앞줄일수록 빨리 흐른다
    if (mod(row, 2.0) < 1.0) {
        float speed = 1.0 + floor(row / 8.0);
        float span = 16.0 + floor(hash(vec2(row, 1.0)) * 18.0);
        float x = c.x - t * speed + floor(hash(vec2(row, 7.0)) * 40.0);
        float seg = floor(x / span);
        float dash = 2.0 + floor(hash(vec2(seg, row)) * 2.0) + floor(row / 10.0);
        if (mod(x, span) < dash) {
            col = mix(vec3(0.36, 0.66, 0.72), vec3(0.62, 0.86, 0.88), step(0.6, hash(vec2(seg, row + 3.0))));
            a = mix(0.45, 0.8, clamp(row / 16.0, 0.0, 1.0));
        }
    }
    // 반사: 줄마다 · 두 장마다 옆으로 흔들리는 끊긴 띠. 횃불 아래는 주황, 물줄기 아래는 푸른빛
    float sway = (hash(vec2(row, floor(t / 2.0))) - 0.5) * 8.0;
    float on = step(0.3, hash(vec2(row + 11.0, floor(t / 2.0))));
    for (int i = 0; i < 2; i++) {
        float dt = abs(s.x + sway - torch_x[i]);
        float wt = 6.0 + row * 1.2;
        if (dt < wt && on > 0.5) {
            col = mix(vec3(1.0, 0.68, 0.32), vec3(1.0, 0.9, 0.62), step(dt, wt * 0.35));
            a = max(a, min(1.0, 1.25 * (1.0 - dt / (wt + 2.0))));
        }
        float df = abs(s.x + sway * 0.5 - fall_x[i]);
        if (df < 8.0 + row && on > 0.5) {
            col = vec3(0.55, 0.84, 0.88);
            a = max(a, 0.6 * (1.0 - df / (10.0 + row)));
        }
        // 거품: 물줄기가 떨어지는 자리(앞 세 줄)에 하얀 점이 끓는다
        if (row < 3.0 && abs(s.x - fall_x[i]) < 14.0 && hash(c + vec2(t, float(i))) > 0.55) {
            col = vec3(0.86, 0.95, 0.96);
            a = 0.9;
        }
    }
    COLOR = vec4(col, a * mask * strength) * item_modulation;
}
