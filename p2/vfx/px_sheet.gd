class_name P2PxSheet
extends RefCounted

# 구운 픽셀 효과 시트 하나(tools/fx/bake_px.mjs 결과, res://assets/fx_px/<이름>/): 본체 · 빛 마스크 텍스처, 장 영역 · 장별 시간,
# 바닥 기준점(pivot, 장 안 px), 접촉 장, 장별 빛 양. 장은 늘 바깥에서 받은 효과 시각으로 고른다(멈춤 · 되감기가 그대로 따라옴)

const DIR := "res://assets/fx_px/"
static var _cache := {}

var id := ""
var role := ""
var color: Texture2D
var light: Texture2D
var rects: Array[Rect2] = []
var starts: Array[float] = []
var length := 0.0
var pivot := Vector2.ZERO
var loop := false
var contact := 0
var contact_t := 0.0
var glow: Array[float] = []
var glow_color := Color.WHITE


# 쓰는 효과가 있는 동안만 붙잡는다(약한 참조): 다 끝나면 텍스처도 놓여 종료 때 남지 않는다
static func get_sheet(name: String) -> P2PxSheet:
	var w: WeakRef = _cache.get(name)
	if w != null and w.get_ref() != null:
		return w.get_ref() as P2PxSheet
	var s := P2PxSheet.new()
	if not s._load(name):
		return null
	_cache[name] = weakref(s)
	return s


func _load(name: String) -> bool:
	var base := DIR + name + "/" + name
	var txt := FileAccess.get_file_as_string(base + ".json")
	var j: Variant = JSON.parse_string(txt) if txt != "" else null
	if not (j is Dictionary):
		push_warning("P2PxSheet: %s.json을 읽지 못함" % base)
		return false
	id = name
	color = _tex(base + ".png")
	light = _tex(base + "_light.png")
	var t := 0.0
	for f in j.frames:
		var r: Dictionary = f.frame
		rects.append(Rect2(float(r.x), float(r.y), float(r.w), float(r.h)))
		starts.append(t)
		t += float(f.duration) / 1000.0
	length = t
	var m: Dictionary = j.meta
	pivot = Vector2(float(m.pivot[0]), float(m.pivot[1]))
	loop = bool(m.get("loop", false))
	contact = clampi(int(m.get("contact", 0)), 0, rects.size() - 1)
	contact_t = starts[contact]
	role = String(m.get("role", ""))
	for g in m.get("glow", []):
		glow.append(float(g))
	var gc: Array = m.get("glow_color", [1, 1, 1])
	glow_color = Color(float(gc[0]), float(gc[1]), float(gc[2]))
	return color != null


static func _tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	# 에디터가 아직 가져오지(import) 않았으면 PNG를 바로 읽는다
	var img := Image.load_from_file(path)
	return ImageTexture.create_from_image(img) if img != null else null


# 효과 시각 t(초, 0 = 첫 장)의 장 번호. 시작 전 · 끝난 뒤(반복 아님)는 -1
func frame_at(t: float) -> int:
	if t < 0.0:
		return -1
	if t >= length:
		if not loop:
			return -1
		t = fmod(t, length)
	var i := 0
	while i + 1 < starts.size() and starts[i + 1] <= t:
		i += 1
	return i


func glow_at(i: int) -> float:
	return glow[i] if i >= 0 and i < glow.size() else 0.0
