shader_type canvas_item;

// 뒤 벽 물줄기: 2px 칸 세로 물줄기가 초당 fps장으로 끊어 떨어진다(손으로 찍은 픽셀 폭포처럼). 줄마다 길이·위상이 다르고 밝은 머리 + 중간 + 어두운 몸
uniform float flow_clock = 0.0;
uniform float fps = 10.0;
uniform float cells_per_frame = 2.0;
uniform float seed = 0.0;
uniform vec2 canvas_origin = vec2(-80.0, -80.0);
varying vec4 item_modulation;

void vertex() {
    item_modulation = COLOR;
}

float hash(float n) {
    return fract(sin(n * 12.9898) * 43758.5453);
}

void fragment() {
    vec2 c = floor((UV / TEXTURE_PIXEL_SIZE + canvas_origin) / 2.0);
    float t = floor(flow_clock * fps);
    float h = hash(c.x + seed * 17.0);
    float len = 8.0 + floor(h * 7.0);
    float k = mod(c.y - t * cells_per_frame + floor(h * 31.0), len);
    vec3 shade = vec3(0.10, 0.32, 0.39);
    if (k < 1.0) {
        shade = vec3(0.62, 0.86, 0.88);
    } else if (k < 4.0) {
        shade = vec3(0.26, 0.57, 0.64);
    }
    COLOR = vec4(shade, texture(TEXTURE, UV).a * 0.86) * item_modulation;
}
