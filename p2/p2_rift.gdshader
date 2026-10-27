shader_type canvas_item;
render_mode unshaded;

// 어둠의 균열: 대상 둘레만 남기고 화면이 검게 닫힘(dark) → 화면 유리에 금이 대상에서 바깥으로 퍼짐(crack, 세 번에 나눠 올림)
// → 금을 따라 조각난 화면이 바깥으로 튕기며 살짝 돌고, 틈은 보랏빛 허공(shatter) → 섬광(flash).
// 금 = 들쭉날쭉한 방사선(각도 칸 경계) + 칸마다 다른 반지름의 곧은 가로 금(고리 대신 다각형) → 유리 깨짐처럼
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform vec2 view_px = vec2(1280.0, 720.0);
uniform vec2 center = vec2(640.0, 300.0);
uniform float dark = 0.0;
uniform float crack = 0.0;
uniform float shatter = 0.0;
uniform float flash = 0.0;
uniform float seed = 1.0;

const float RAYS = 11.0;

float hash(float n) {
	return fract(sin(n * 91.3458 + seed * 13.7) * 47453.5453);
}

// 방사선 i의 각도: 거리에 따라 마디마다 꺾인다(마디 사이는 곧게)
float ray_angle(float i, float r) {
	float base = (i / RAYS) * TAU - PI + (hash(i * 3.1) - 0.5) * 0.35;
	float seg = 46.0;
	float k = floor(r / seg);
	float f = fract(r / seg);
	float a0 = (hash(i * 17.0 + k) - 0.5) * 0.16;
	float a1 = (hash(i * 17.0 + k + 1.0) - 0.5) * 0.16;
	return base + mix(a0, a1, f);
}

// 고리 k 의 방사선 i 위 반지름
float ring_r(float k, float i) {
	float base = k == 0.0 ? 64.0 : (k == 1.0 ? 150.0 : (k == 2.0 ? 280.0 : (k == 3.0 ? 450.0 : 720.0)));
	return base * (0.78 + 0.44 * hash(i * 5.0 + k * 31.0));
}

vec2 rotate(vec2 v, float a) {
	return vec2(v.x * cos(a) - v.y * sin(a), v.x * sin(a) + v.y * cos(a));
}

float wrap_pi(float a) {
	return mod(a + PI, TAU) - PI;
}

// 이 자리의 칸(방사선 사이 i, 고리 k)과 금까지 거리
vec4 cell_of(vec2 d) {
	float r = length(d);
	float ang = atan(d.y, d.x);
	float sec = 0.0;
	float best = 99.0;
	float edge_ray = 9999.0;
	for (int j = 0; j < 11; j++) {
		float i = float(j);
		float da = wrap_pi(ang - ray_angle(i, r));
		edge_ray = min(edge_ray, abs(sin(da)) * r + (abs(da) > 1.57 ? 9999.0 : 0.0));
		float dn = wrap_pi(ray_angle(mod(i + 1.0, RAYS), r) - ray_angle(i, r));
		if (dn < 0.0) { dn += TAU; }
		float dd = wrap_pi(ang - ray_angle(i, r));
		if (dd < 0.0) { dd += TAU; }
		if (dd <= dn && dd < best) {
			best = dd;
			sec = i;
		}
	}
	float i0 = sec;
	float i1 = mod(sec + 1.0, RAYS);
	float a0 = ray_angle(i0, r);
	float span = wrap_pi(ray_angle(i1, r) - a0);
	if (span <= 0.0) { span += TAU; }
	float fa = clamp(best / max(span, 0.001), 0.0, 1.0);
	float ring = 0.0;
	float edge_ring = 9999.0;
	for (int k = 0; k < 5; k++) {
		float fk = float(k);
		vec2 p0 = vec2(cos(a0), sin(a0)) * ring_r(fk, i0);
		float a1 = a0 + span;
		vec2 p1 = vec2(cos(a1), sin(a1)) * ring_r(fk, i1);
		vec2 dd2 = p1 - p0;
		vec2 u = vec2(cos(a0 + span * fa), sin(a0 + span * fa));
		float den = u.x * dd2.y - u.y * dd2.x;
		float rk = abs(den) > 0.0001 ? (p0.x * dd2.y - p0.y * dd2.x) / den : mix(ring_r(fk, i0), ring_r(fk, i1), fa);
		if (r > rk) {
			ring = fk + 1.0;
		}
		if (hash(i0 * 7.0 + fk * 13.0) > 0.25) {
			edge_ring = min(edge_ring, abs(r - rk));
		}
	}
	return vec4(sec, ring, edge_ray, edge_ring);
}

vec2 cell_mid(float sec, float ring) {
	float a = (sec + 0.5) / RAYS * TAU - PI;
	float rr = ring == 0.0 ? 30.0 : mix(ring_r(ring - 1.0, sec), ring_r(min(ring, 4.0), sec), 0.5);
	return vec2(cos(a), sin(a)) * rr;
}

vec2 cell_off(float sec, float ring) {
	float a = (sec + 0.5) / RAYS * TAU - PI;
	vec2 dir = vec2(cos(a), sin(a));
	float push = (30.0 + 24.0 * ring) * (0.6 + 0.8 * hash(sec * 7.0 + ring * 3.0));
	vec2 side = vec2(-dir.y, dir.x) * (hash(sec * 11.0 + ring) - 0.5) * 28.0;
	return (dir * push + side) * shatter;
}

float cell_rot(float sec, float ring) {
	return (hash(sec * 19.0 + ring * 7.0) - 0.5) * 0.22 * shatter;
}

void fragment() {
	// 3배 픽셀 칸 가운데 기준: 금·조각·허공 별이 모두 픽셀 계단으로
	vec2 p = floor(SCREEN_UV * view_px / 3.0) * 3.0 + 1.5;
	vec2 d = p - center;
	float r = length(d);
	vec4 c0 = cell_of(d);
	vec2 src = d;
	float edge = min(c0.z, c0.w);
	bool gap = false;
	if (shatter > 0.01) {
		// 이 자리를 덮는 조각 찾기: 제 칸 · 안쪽 고리 · 양옆 칸 (조각은 바깥으로 밀리므로)
		gap = true;
		for (int a = 0; a < 3 && gap; a++) {
			for (int b = 0; b < 3 && gap; b++) {
				float sdel = a == 0 ? 0.0 : (a == 1 ? -1.0 : 1.0);
				float sc = mod(c0.x + sdel + RAYS, RAYS);
				float rg = c0.y - float(b);
				if (rg < 0.0) {
					continue;
				}
				vec2 off = cell_off(sc, rg);
				vec2 mid = cell_mid(sc, rg);
				vec2 sp = rotate(d - off - mid, -cell_rot(sc, rg)) + mid;
				vec4 cc = cell_of(sp);
				if (cc.x == sc && cc.y == rg) {
					gap = false;
					src = sp;
					edge = min(cc.z, cc.w);
				}
			}
		}
	}
	vec3 col = texture(screen_tex, (center + src) / view_px).rgb;
	float g = dot(col, vec3(0.3, 0.59, 0.11));
	col = mix(col, vec3(g * 0.8, g * 0.7, g * 0.95), dark * 0.55);
	float hole = mix(900.0, 120.0, dark);
	float vk = dark * smoothstep(hole, hole * 1.9, r);
	col = mix(col, vec3(0.025, 0.0, 0.05), vk * 0.94);
	float rr = length(src);
	float reach = crack * 980.0;
	float shown = step(rr, reach) * step(14.0, rr);
	float line = step(edge, 2.6) * shown;
	float glow = (1.0 - smoothstep(0.0, 9.0, edge)) * shown;
	glow = floor(glow * 3.0 + 0.5) / 3.0;
	col = mix(col, vec3(0.62, 0.3, 0.95), glow * 0.45);
	col = mix(col, vec3(0.97, 0.9, 1.0), line * (1.0 - shatter * 0.6));
	if (gap) {
		float sp2 = step(0.975, hash(floor(p.x / 3.0) * 1.7 + floor(p.y / 3.0) * 13.1));
		col = vec3(0.07, 0.0, 0.12) + vec3(0.6, 0.4, 1.0) * sp2 * 0.8;
	}
	float rim = step(edge, 3.5) * step(0.01, shatter) * (gap ? 0.0 : 1.0);
	col = mix(col, vec3(0.85, 0.6, 1.0), rim * 0.9);
	col = mix(col, vec3(1.0, 0.94, 1.0), flash);
	COLOR = vec4(col, 1.0);
}
