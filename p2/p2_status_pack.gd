class_name P2StatusPack
extends Node2D

# 적 몸의 원소 상태를 손그림 픽셀 효과 묶음으로(세계 층 _fx, 최근접 확대): 화상 = 흔들리는 불꽃 기둥 · 독 = 초록 거품 ·
# 냉기 = 반짝이는 얼음 알갱이 · 독 결정 = 초록 결정 알갱이 · 저주 = 머리 위 보라 해골 · 어둠 기운 = 몸을 감싸 도는 보라 바람개비 ·
# 빛 기운 = 머리 위 흰 빛 소용돌이. 화면이 매 프레임 feet · body_h · body_w · st를 넣는다. 수치가 클수록 개수가 늘어난다

var feet := Vector2.ZERO
var body_h := 120.0
var body_w := 80.0
var st: Dictionary = {}
var alive := true
var _t := 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if not alive:
		return
	position = feet
	var h := body_h
	var w := body_w
	var umbra := int(st.get("umbra", 0))
	if umbra > 0:
		_frame("174", "dark", 10.0, Vector2(-w * 0.3, -h * 0.25), 1.0, 0.0, 0.7)
		_frame("174", "dark", 10.0, Vector2(w * 0.3, -h * 0.6), 1.0, 0.35, 0.6)
	var burn := int(st.get("burn", 0))
	if burn > 0:
		var spots := [Vector2(-0.22, -0.22), Vector2(0.2, -0.38), Vector2(-0.04, -0.58)]
		var sc := 1.5
		for k in range(clampi(1 + burn / 3, 1, 3)):
			_frame("464", "fire", 14.0, Vector2(spots[k].x * w, spots[k].y * h), sc, k * 0.27, 1.0)
	var poison := int(st.get("poison", 0))
	if poison > 0:
		_frame("519", "poison", 9.0, Vector2(0, -h * 0.12), 1.5, 0.0, 0.95)
		if poison >= 4:
			_frame("519", "poison", 9.0, Vector2(w * 0.18, -h * 0.5), 1.0, 0.45, 0.9)
	var chill := int(st.get("chill", 0))
	if chill > 0:
		var ice_spots := [Vector2(-0.3, -0.55), Vector2(0.28, -0.3), Vector2(0.05, -0.8)]
		for k in range(clampi(chill, 1, 3)):
			_frame("23", "ice", 12.0, Vector2(ice_spots[k].x * w, ice_spots[k].y * h), 1.25, k * 0.33, 1.0)
	if int(st.get("pcrys", 0)) > 0:
		_frame("23", "poison", 10.0, Vector2(-w * 0.25, -h * 0.4), 1.25, 0.2, 1.0)
		_frame("23", "poison", 10.0, Vector2(w * 0.25, -h * 0.65), 1.0, 0.6, 1.0)
	if int(st.get("lumen", 0)) > 0:
		_frame("220", "light", 9.0, Vector2(0, -h * 0.72), 1.5, 0.0, 0.95)
	if int(st.get("doom", 0)) > 0:
		_frame("633", "dark", 9.0, Vector2(0, -h - 46.0), 1.0, 0.0, 1.0)


# 묶음 한 칸: 색 줄 · 초당 장수 · 자리 · 배율 · 시작 어긋남(초) · 불투명도
func _frame(id: String, color: String, fps: float, at: Vector2, sc: float, phase: float, a: float) -> void:
	var tex := P2PackFx.tex_of(id)
	var n := maxi(1, int(tex.get_width()) / P2PackFx.CELL)
	var k := int((_t + phase) * fps) % n
	var row := int(P2PackFx.ROW.get(color, 0))
	draw_set_transform(at, 0.0, Vector2.ONE * sc)
	draw_texture_rect_region(tex, Rect2(-32, -32, 64, 64), Rect2(k * 64, row * 64, 64, 64), Color(1, 1, 1, a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
