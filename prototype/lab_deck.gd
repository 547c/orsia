extends Deck
# Existing draw/discard/Hand behavior; a stable, uniform per-encounter shuffle.
var rng := RandomNumberGenerator.new()

func _init(cards: Array[Card], seed_value: int) -> void:
	rng.seed = seed_value
	super(cards)

func shuffle() -> void:
	for i in range(draw_pile.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temp: Card = draw_pile[i]
		draw_pile[i] = draw_pile[j]
		draw_pile[j] = temp

func _pick_weighted_index() -> int:
	return draw_pile.size() - 1
