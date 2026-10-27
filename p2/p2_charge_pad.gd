class_name P2ChargePad
extends Control

# 차징(집중 사격 · 기공파): 누른 채 버티면 고리가 차오른다(1.2초에 가득). 금빛 구간(85~100%)에서 놓으면 완벽(치명),
# 가득 찬 뒤에는 0.6초 더 버티다 저절로 발사. 1.5초 안에 누르지 않으면 ×1로 발사. 배율 = 1 + 2 × 찬 정도(최대 ×3)
# 입력: 왼쪽 클릭 · 아무 키(누르기 키). 우클릭·Esc = 취소 없음(이미 카드를 냈다)

signal changed(level: float)
signal finished(res: Dictionary)

const FILL := 1.2
const HOLD_MAX := 0.6
const WAIT := 1.5
const SWEET := 0.85

var center := Vector2(640, 300)
var color := Color("#bfe8ff")
var level := 0.0
var _state := "wait"
var _t := 0.0
var _full_t := 0.0
var _done := false
var _font: Font
var _c: P2Pixel


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = P2Ui.bold_font(24)
	_c = P2Pixel.attach(self, _paint, false, 3)
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_state = "charge"


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_press((event as InputEventMouseButton).pressed)
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if P2NoteChart.is_hit_key(event):
		_press((event as InputEventKey).pressed)
		get_viewport().set_input_as_handled()


func _press(down: bool) -> void:
	if _done:
		return
	if down and _state == "wait":
		_state = "charge"
	elif not down and _state == "charge":
		_release()


func force_release(lv: float) -> void:
	level = clampf(lv, 0.0, 1.0)
	_state = "charge"
	_release()


func _release() -> void:
	if _done:
		return
	_done = true
	var perfect := level >= SWEET and _full_t <= 0.0
	finished.emit({"power": 1.0 + 2.0 * level, "perfect": perfect, "level": level})
	queue_free()


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	match _state:
		"wait":
			if _t >= WAIT:
				_release()
				return
		"charge":
			if level < 1.0:
				level = minf(1.0, level + delta / FILL)
			else:
				_full_t += delta
				if _full_t >= HOLD_MAX:
					_release()
					return
			changed.emit(level)
	_c.redraw()


func _paint() -> void:
	var r := 78.0
	_c.draw_arc(center, r, 0.0, TAU, 64, Color(0.05, 0.04, 0.08, 0.7), 12.0, false)
	var a0 := -PI / 2.0
	_c.draw_arc(center, r, a0 + TAU * SWEET, a0 + TAU, 16, Color("#ffe27a", 0.55), 12.0, false)
	if level > 0.0:
		var hot := level >= SWEET and _full_t <= 0.0
		_c.draw_arc(center, r, a0, a0 + TAU * level, 64, Color("#ffe27a") if hot else color, 8.0, false)
	if _full_t > 0.0:
		var pulse := 0.5 + 0.5 * sin(_t * 30.0)
		_c.draw_arc(center, r + 8.0 + pulse * 4.0, 0.0, TAU, 48, Color(1, 0.4, 0.3, 0.8), 3.0, false)
	var txt := tr("누르고 버티기") if _state == "wait" else (tr("지금 놓기!") if level >= SWEET and _full_t <= 0.0 else tr("놓으면 발사"))
	var tw := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	var tp := center + Vector2(-tw / 2.0, r + 40.0)
	_c.text(_font, tp, txt, 24, Color("#ffe27a") if level >= SWEET else Color(1, 1, 1), 8, Color(0.03, 0.02, 0.05))
	var pct := "×%.1f" % (1.0 + 2.0 * level)
	var pw := _font.get_string_size(pct, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	_c.text(_font, center + Vector2(-pw / 2.0, -r - 18.0), pct, 24, Color(1, 1, 1), 8, Color(0.03, 0.02, 0.05))
