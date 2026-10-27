class_name P2Beat
extends Node

# 손맛 시험판 박자 소리: 음원 파일 없이 코드로 만든 짧은 드럼(킥·스네어·하이햇·스틱·둔탁)과 종소리(음 높이는 pitch_scale).
# 악보·긋기가 박자 반주와 맞힌 노트의 음을 이걸로 낸다. 효과음 버스로 보낸다

const RATE := 22050
const SCALE := [0, 2, 4, 7, 9, 12, 14, 16]
const VOL := {"kick": -13.0, "snare": -15.0, "hat": -22.0, "stick": -14.0, "thud": -11.0, "chime": -13.0, "bass": -10.0}

static var _streams := {}
static var gain := 1.0
var _players: Array[AudioStreamPlayer] = []
var counts := {}
var _next := 0


func _ready() -> void:
	for i in range(8):
		var p := AudioStreamPlayer.new()
		p.bus = P2BattleView.FX_BUS
		add_child(p)
		_players.append(p)


# step: 종소리 음계 칸(0 = 도). 북은 pitch 그대로
func play(key: String, step := 0, vol := 0.0) -> void:
	counts[key] = int(counts.get(key, 0)) + 1
	if gain <= 0.001:
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream(key)
	p.volume_db = float(VOL.get(key, -14.0)) + vol + linear_to_db(gain)
	p.pitch_scale = pow(2.0, float(SCALE[clampi(step, 0, SCALE.size() - 1)]) / 12.0) if key == "chime" else (pow(2.0, float(step) / 12.0) if key == "bass" else 1.0)
	p.play()


static func stream(key: String) -> AudioStreamWAV:
	if not _streams.has(key):
		_streams[key] = _make(key)
	return _streams[key]


static func _make(key: String) -> AudioStreamWAV:
	var dur := float({"kick": 0.22, "snare": 0.16, "hat": 0.05, "stick": 0.035, "thud": 0.2, "chime": 0.5, "bass": 0.34}.get(key, 0.1))
	var n := int(dur * RATE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	var last := 0.0
	for i in range(n):
		var t := float(i) / RATE
		var v := 0.0
		match key:
			"kick", "thud":
				var f := (40.0 if key == "thud" else 50.0) + 110.0 * exp(-t * 25.0)
				phase += TAU * f / RATE
				v = sin(phase) * exp(-t * (10.0 if key == "thud" else 14.0))
			"snare":
				v = rng.randf_range(-1.0, 1.0) * exp(-t * 28.0) * 0.7 + sin(TAU * 190.0 * t) * exp(-t * 20.0) * 0.4
			"hat":
				var w := rng.randf_range(-1.0, 1.0)
				v = (w - last) * 0.5 * exp(-t * 80.0)
				last = w
			"stick":
				v = sin(TAU * 1800.0 * t) * exp(-t * 120.0)
			"bass":
				phase += TAU * 65.41 / RATE
				v = (sin(phase) + 0.3 * sin(phase * 2.0) + 0.1 * sin(phase * 3.0)) * exp(-t * 6.0) * minf(1.0, t / 0.006) * 0.8
			"chime":
				var f0 := 523.25
				v = (sin(TAU * f0 * t) + 0.35 * sin(TAU * f0 * 2.0 * t) + 0.12 * sin(TAU * f0 * 3.0 * t)) * exp(-t * 7.0) * 0.55 * minf(1.0, t / 0.003)
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 30000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	return s
