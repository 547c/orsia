extends RefCounted

# 혼합 무대 실험의 좌표 한곳. 화면 크기 · 도트 배율(n) · 카메라(사선 각 · 발 줄 높이)를 가지고 무대(3D, 단위 = 저해상도 1px) ↔ 화면(논리 px)
# 변환을 여기서만 한다. A(2D)도 같은 식으로 인물 · 바닥 자리를 잡아 두 보기의 화면 자리가 같다.
# 노트 판정 원은 화면 좌표 그대로 2D 층(P2NoteChart)에 있어 이 변환을 거치지 않는다(입력 좌표가 카메라와 무관)

# 카드 고르기 = 가까운 낮은 사선, 막기 = 높은 사선(발 줄이 내려가며 가운데~아래 바닥이 열림)
const SELECT := {"pitch": 14.0, "feet": 0.56}
const DEFEND := {"pitch": 38.0, "feet": 0.72}
# 저해상도 높이 목표(이 값에 가장 가까운 정수 배율). 원화 도트 한 칸 = 화면 n px
const LOW_H := 228.0
# 무대 바닥 뒤 끝(발 줄에서 뒤로) · 앞 끝
const FLOOR_BACK := -160.0
const FLOOR_FRONT := 420.0

var view := Vector2(1152, 648)
var n := 3
var low := Vector2i(384, 216)
var pitch := float(SELECT.pitch)
var feet := float(SELECT.feet)


# 화면 크기에 맞춰 정수 배율과 저해상도 크기를 정한다(가운데가 정수 칸에 오게 짝수로). force_n > 0이면 그 배율
func fit(size: Vector2, force_n := 0) -> void:
	view = size
	n = force_n if force_n > 0 else maxi(1, roundi(size.y / LOW_H))
	low = Vector2i(ceili(size.x / n / 2.0) * 2, ceili(size.y / n / 2.0) * 2)


func set_frame(a: Dictionary, b: Dictionary, u: float) -> void:
	pitch = lerpf(float(a.pitch), float(b.pitch), u)
	feet = lerpf(float(a.feet), float(b.feet), u)


func forward() -> Vector3:
	var p := deg_to_rad(pitch)
	return Vector3(0, -sin(p), -cos(p))


func up() -> Vector3:
	var p := deg_to_rad(pitch)
	return Vector3(0, cos(p), -sin(p))


# 화면 가운데에 오는 바닥 위 점: 발 줄(z 0)이 화면 feet 높이(정수 저해상도 줄)에 오도록 뒤로 민다
func target() -> Vector3:
	var shift := roundf((feet - 0.5) * low.y)
	return Vector3(0, 0, -shift / maxf(sin(deg_to_rad(pitch)), 0.01))


func cam_pos(dist := 800.0) -> Vector3:
	return target() - forward() * dist


# 무대 점 → 화면. 직교 카메라라 저해상도 1px = 무대 1단위, 화면에선 n배
func to_screen(p: Vector3) -> Vector2:
	var d := p - target()
	return Vector2(low.x / 2.0 + d.x, low.y / 2.0 - d.dot(up())) * n


# 화면 점 → 높이 h 바닥 위 무대 점(마우스 · 노트 자리 아래 바닥을 찾을 때)
func to_floor(s: Vector2, h := 0.0) -> Vector3:
	var lp := s / float(n)
	var p0 := target() + Vector3(lp.x - low.x / 2.0, 0, 0) + up() * (low.y / 2.0 - lp.y)
	var f := forward()
	return p0 + f * ((h - p0.y) / f.y)


# 인물 자리: 양옆(화면 가로 14% · 86%)
func side_x() -> float:
	return roundf(low.x * 0.36)


# 리듬 수행 공간(막기 구도의 가운데~아래, 두 인물 사이) · 카드 고르기 때 손패가 있던 자리
func play_rect() -> Rect2:
	return Rect2(view.x * 0.24, view.y * 0.34, view.x * 0.52, view.y * 0.54)


func hand_rect() -> Rect2:
	return Rect2(view.x * 0.18, view.y * 0.7, view.x * 0.64, view.y * 0.26)
