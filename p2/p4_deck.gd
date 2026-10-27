class_name P4Deck
extends "res://prototype/lab_deck.gd"
# 소진 더미: 이번 전투에서 다시 뽑히거나 섞이지 않는다. 카드를 낸 뒤 기존 실행기가 버리는 경로에서
# "이번에 소진할 카드"(exhaust_next)만 가로채 소진 더미로 보낸다 — 잠깐 버렸다가 다시 뽑히는 틈이 없다

var exhausted: Array[Card] = []
var exhaust_next := {}


func discard(cards: Array[Card]) -> void:
	for c in cards:
		var uid := P2Catalog.uid_of(c)
		if exhaust_next.has(uid):
			exhaust_next.erase(uid)
			exhausted.append(c)
		else:
			discard_pile.append(c)


func exhaust(c: Card) -> void:
	exhausted.append(c)
