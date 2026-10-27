class_name P2MashPad
extends Control

# 연타(폭풍 연사): DUR초 동안 누른 수만큼(왼쪽·오른쪽 클릭 · 누르기 키). 누를 때마다 shot 신호 → 화면이 화살을 쏜다

signal shot(n: int)
signal finished(count: int)

const DUR := 1.5
# 이보다 빠른 연속 입력은 세지 않는다(사람 손 한계 근처 · 자동 클릭 막기)
const MIN_GAP := 0.07

var cap := 40
var count := 0
var _t := 0.0
var _done := false
var _font: Font
var _big: Font
var _pop := 0.0
var _last := -1.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = P2Ui.bold_font(24)
	_big = P2Ui.bold_font(60)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_hit()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if P2NoteChart.is_hit_key(event) and (event as InputEventKey).pressed:
		_hit()
		get_viewport().set_input_as_handled()


func _hit() -> void:
	if _done or count >= cap:
		return
	if _last >= 0.0 and _t - _last < MIN_GAP:
		return
	_last = _t
	count += 1
	_pop = 1.0
	shot.emit(count)


func force(n: int) -> void:
	for i in range(n):
		_hit()
	_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	finished.emit(count)
	queue_free()


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	_pop = maxf(0.0, _pop - delta * 8.0)
	if _t >= DUR:
		_finish()
		return
	queue_redraw()


func _draw() -> void:
	var w := 420.0
	var bar := Rect2(640.0 - w / 2.0, 610.0, w, 16.0)
	draw_rect(bar.grow(3.0), Color(0.03, 0.02, 0.05, 0.85))
	draw_rect(Rect2(bar.position, Vector2(w * (1.0 - _t / DUR), bar.size.y)), Color("#ffd25a"))
	var txt := tr("연타! 누르는 만큼 발사")
	var tw := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	draw_string_outline(_font, Vector2(640.0 - tw / 2.0, 598.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, 8, Color(0.03, 0.02, 0.05))
	draw_string(_font, Vector2(640.0 - tw / 2.0, 598.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 1, 1))
	var n := "×%d" % count
	var sz := int(60 * (1.0 + 0.25 * _pop))
	var nw := _big.get_string_size(n, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
	draw_string_outline(_big, Vector2(640.0 - nw / 2.0, 560.0), n, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, 14, Color(0.03, 0.02, 0.05))
	draw_string(_big, Vector2(640.0 - nw / 2.0, 560.0), n, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color("#ffe27a").lerp(Color.WHITE, _pop))
