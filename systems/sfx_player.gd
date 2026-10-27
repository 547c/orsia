extends Node

# 짧은 효과음 공용 재생기. 겹쳐 울려도 끊기지 않게 작은 풀을 돌려 쓴다

const POOL_SIZE := 4
const DEFAULT_VOLUME_DB := -6.0

# 메뉴 전반에서 재사용하는 공용 효과음. 여기 한 곳에 모아두면 버튼마다 경로 문자열을 중복해 적지 않는다
const UI_CLICK_SOUND := "res://assets/sfx/400 Sounds pack/UI/select_2.wav"
const EQUIP_SOUND := "res://assets/sfx/400 Sounds pack/Items/item_equip.wav"
const PAGE_TURN_SOUND := "res://assets/sfx/400 Sounds pack/Items/page_turn.wav"
const UNLOCK_SOUND := "res://assets/sfx/400 Sounds pack/Environment/lock_unlock.wav"

var _players: Array[AudioStreamPlayer] = []
var _next_index: int = 0


func _ready() -> void:
	for i in range(POOL_SIZE):
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)


# stream_path의 효과음을 재생. 풀에서 순서대로 플레이어를 하나씩 돌려써서, 짧은 시간 안에
# 여러 소리가 겹쳐도(최대 POOL_SIZE개까지 동시) 서로 잘리지 않는다
func play(stream_path: String, volume_db: float = DEFAULT_VOLUME_DB, pitch_scale: float = 1.0) -> void:
	var stream := load(stream_path) as AudioStream
	if stream == null:
		return

	var player := _players[_next_index]
	_next_index = (_next_index + 1) % _players.size()

	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.play()
