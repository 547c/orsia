class_name P2MusicMeta
# tools/music/bake.js가 만드는 파일: 구운 세계 · 빠르기 · 막기 음 동기(반음, C5 기준). 손으로 고치지 말고 다시 구울 것

const PRE := 0.06
const BARS := 8
const STEMS := ["bed", "light", "kick", "lead", "hat", "perc", "kick4", "bass", "counter", "spark"]
const WORLDS := {
	"gye": {"motif_g": [0, 3, 5, 7, 10, 7, 5, 3, 5, 7], "motif_c": [7, 10, 12, 10, 7, 5, 7, 5, 3, 0], "tones": [0, 3, 5, 7, 10, 12], "bpms": [112, 124, 136]},
}
