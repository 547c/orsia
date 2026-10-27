class_name P2SlashTrail
extends Node2D

# 손맛 시험판: 맞는 순간, 플레이어가 그은 선 그대로 베인 자국이 지나간다 (빠르게 그어지고 가늘어지며 사라짐)

const DRAW := 0.07
const FADE := 0.3
const OVERSHOOT := 22.0

var pts := PackedVector2Array()
var core := Color("#fffaf0")
var glow := Color("#ffd98a")
var width := 5.0
var _t := 0.0


# stroke: 기준점(local 0,0)에 대한 자리들. grade: perfect / hit / graze. rune이면 청록 문양 자국
func setup(stroke: PackedVector2Array, grade: String, rune := false) -> void:
	if rune:
		glow = Color("#5fd8cf")
	pts = _smooth(_thin(stroke))
	if pts.size() >= 2:
		var a := pts[0] + (pts[0] - pts[1]).normalized() * OVERSHOOT
		var n := pts.size()
		var b := pts[n - 1] + (pts[n - 1] - pts[n - 2]).normalized() * OVERSHOOT
		pts.insert(0, a)
		pts.append(b)
	match grade:
		"perfect":
			glow = Color("#ffd25a") if not rune else Color("#9ff3ff")
			width = 7.0
		"graze":
			core = Color("#d8cbb4")
			glow = Color("#8a7d68")
			width = 3.0


func _process(delta: float) -> void:
	_t += delta
	if _t > DRAW + FADE:
		queue_free()
	queue_redraw()


func _draw() -> void:
	if pts.size() < 2:
		return
	var total := 0.0
	for i in range(1, pts.size()):
		total += pts[i - 1].distance_to(pts[i])
	var head := total * clampf(_t / DRAW, 0.0, 1.0)
	var u := clampf((_t - DRAW) / FADE, 0.0, 1.0)
	var w := width * (1.0 - u)
	var acc := 0.0
	for i in range(1, pts.size()):
		var a := pts[i - 1]
		var b := pts[i]
		var seg := a.distance_to(b)
		if acc >= head:
			break
		if acc + seg > head:
			b = a.lerp(b, (head - acc) / seg)
		# 양끝으로 갈수록 가늘게 (칼자국 모양)
		var mid := 1.0 - absf((acc + seg * 0.5) / total - 0.5) * 1.4
		draw_line(a, b, Color(glow, 0.45 * (1.0 - u)), (w * 2.6 + 4.0) * mid, P2Pixel.smooth())
		draw_line(a, b, Color(core, 1.0 - u * u), maxf(2.0, w * mid), P2Pixel.smooth())
		acc += seg


func _thin(src: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in src:
		if out.is_empty() or out[out.size() - 1].distance_to(p) >= 8.0:
			out.append(p)
	if src.size() > 0 and out[out.size() - 1] != src[src.size() - 1]:
		out.append(src[src.size() - 1])
	return out


func _smooth(src: PackedVector2Array) -> PackedVector2Array:
	if src.size() < 3:
		return src
	var out := PackedVector2Array([src[0]])
	for i in range(src.size() - 1):
		out.append(src[i].lerp(src[i + 1], 0.25))
		out.append(src[i].lerp(src[i + 1], 0.75))
	out.append(src[src.size() - 1])
	return out
