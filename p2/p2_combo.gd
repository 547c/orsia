class_name P2Combo
extends Control

# 연속 표시(격투 게임의 "N HITS" 꼴): 패링 노트와 긋기 점을 이어서 성공한 수(보기만, 피해와 무관).
# 오를 때 숫자가 하얗게 톡 커지고 고리가 퍼진다. 5 · 10 · 20에서 색이 오르고, 끊기면 붉게 떨며 사라진다

const TIERS := [[0, Color("#f3ead7")], [5, Color("#ffe04a")], [10, Color("#ff9a3a")], [20, Color("#ff5a48")]]

var count := 0
var best := 0
var _since := 99.0
var _broke := -1.0
var _lost := 0
var _show := 0.0
var _heal := -1.0
var _big: Font
var _small: Font
var _c: P2Pixel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(200, 64)
	_big = P2Ui.bold_font(48)
	_small = P2Ui.pixel_font(16)
	_c = P2Pixel.attach(self, _paint)


func add() -> void:
	count += 1
	best = maxi(best, count)
	_since = 0.0
	_broke = -1.0


func healed() -> void:
	_heal = 0.0


func reset() -> void:
	if count >= 2:
		_lost = count
		_broke = 0.0
	count = 0
	_since = 0.0


func _process(delta: float) -> void:
	_since += delta
	if _broke >= 0.0:
		_broke += delta
	if _heal >= 0.0:
		_heal += delta
	var want := 1.0 if (count >= 2 and _since < 3.0) or (_broke >= 0.0 and _broke < 0.5) else 0.0
	_show = move_toward(_show, want, delta * 6.0)
	visible = _show > 0.01
	_c.redraw()


func _tier() -> Color:
	var c: Color = TIERS[0][1]
	for t in TIERS:
		if count >= int(t[0]):
			c = t[1]
	return c


func _paint() -> void:
	var broke := _broke >= 0.0
	var gone := clampf(_broke / 0.5, 0.0, 1.0) if broke else 0.0
	var col := Color("#c0301c") if broke else _tier()
	var fade := _show * (1.0 - gone)
	var base := Vector2(86, 46) + Vector2(sin(_broke * 70.0) * 4.0 * (1.0 - gone), 0.0)
	var band := PackedVector2Array([base + Vector2(-66, 5), base + Vector2(96, 5), base + Vector2(88, 13), base + Vector2(-74, 13)])
	_c.draw_colored_polygon(band, Color(0.04, 0.03, 0.05, 0.7 * fade))
	_c.draw_colored_polygon(PackedVector2Array([band[0], band[0].lerp(band[1], 0.7), band[3].lerp(band[2], 0.7), band[3]]), Color(col, 0.9 * fade))
	_c.draw_line(band[0], band[0].lerp(band[1], 0.7), Color(col.lightened(0.4), 0.9 * fade), P2Pixel.w(2.0))
	var txt := str(_lost if broke else count)
	var tw := _big.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 48).x
	var u := clampf(_since / 0.18, 0.0, 1.0)
	var sc := 1.0 + 0.5 * (1.0 - u) * (1.0 - u)
	var mid := base + Vector2(-tw / 2.0, -17)
	var flick := 1.0 if count < 20 or broke else 0.85 + 0.15 * sin(_since * 30.0)
	var xf := Transform2D(0.0, Vector2(sc, sc), 0.0, mid)
	_c.text(_big, Vector2(-tw / 2.0, 17), txt, 48, Color(col.lerp(Color.WHITE, (1.0 - u) * 0.7) * flick, fade), 8, Color(0.06, 0.03, 0.02, fade), xf)
	var lab := "끊김" if broke else "연속"
	_c.text(_small, base + Vector2(8, 0), lab, 16, Color(col.lerp(Color.WHITE, 0.35), fade), 4, Color(0, 0, 0, fade))
	if u < 1.0 and not broke:
		_c.draw_arc(mid, lerpf(16.0, 44.0, u), 0.0, TAU, 40, Color(col, (1.0 - u) * fade), P2Pixel.w(3.0), false)
	if _heal >= 0.0 and _heal < 1.0:
		var hp := base + Vector2(8, 22 - 10.0 * _heal)
		var ha := _show * (1.0 - clampf((_heal - 0.6) / 0.4, 0.0, 1.0))
		_c.text(_small, hp, "체력 +1", 16, Color("#8be08b", ha), 4, Color(0, 0, 0, ha))
