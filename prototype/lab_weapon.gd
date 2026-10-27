extends WeaponState
# P1은 카드 종류로 무기 연출만 정한다: 과열·봉쇄·수동 전환이 없다. 원본 WeaponState는 그대로다.

func register_card_use(_card: Card) -> bool:
	return false


func is_redline_for_card(_card: Card) -> bool:
	return false


func can_use_card(_card: Card) -> bool:
	return true


func can_switch() -> bool:
	return false


func copy() -> WeaponState:
	return get_script().new()
