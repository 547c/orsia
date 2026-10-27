class_name P2Sparks
extends Node2D

# 픽셀 조각 한 묶음: 맞은 자리에서 공격 방향으로 튀는 파편(burst), 또는 손끝으로 모여드는 빛(gather). 도트처럼 정수 자리에 네모로 그린다

var _p: Array = []
var _t := 0.0
var _life := 0.4
var _gravity := 0.0
var _to := Vector2.ZERO
var _gather := false


# dir 방향으로 spread(라디안) 안에서 흩어진다. colors 중 무작위, size는 [최소, 최대] px
func burst(at: Vector2, dir: Vector2, spread: float, count: int, speed: Vector2, colors: Array, size: Vector2i, life := 0.42, gravity := 520.0) -> void:
	position = at
	_life = life
	_gravity = gravity
	for i in range(count):
		var a := dir.angle() + randf_range(-spread, spread)
		_p.append({"pos": Vector2(randf_range(-6, 6), randf_range(-10, 10)), "vel": Vector2.RIGHT.rotated(a) * randf_range(speed.x, speed.y),
			"c": colors[randi() % colors.size()], "s": randi_range(size.x, size.y), "life": life * randf_range(0.6, 1.0)})


# radius 둘레에서 가운데(at)로 life 동안 모인다
func gather(at: Vector2, radius: float, count: int, colors: Array, life := 0.22) -> void:
	position = at
	_life = life
	_gather = true
	for i in range(count):
		var from := Vector2.RIGHT.rotated(randf() * TAU) * radius * randf_range(0.6, 1.0)
		_p.append({"from": from, "pos": from, "c": colors[randi() % colors.size()], "s": randi_range(2, 4), "delay": randf_range(0.0, life * 0.4), "life": life})


func _process(delta: float) -> void:
	_t += delta
	for q in _p:
		if _gather:
			var u := clampf((_t - float(q.delay)) / (float(q.life) - float(q.delay)), 0.0, 1.0)
			q.pos = (q.from as Vector2) * (1.0 - u * u)
		else:
			q.vel = (q.vel as Vector2) * pow(0.04, delta) + Vector2(0, _gravity * delta)
			q.pos = (q.pos as Vector2) + (q.vel as Vector2) * delta
	if _t > _life:
		queue_free()
	queue_redraw()


func _draw() -> void:
	for q in _p:
		var a := 1.0 - clampf(_t / float(q.life), 0.0, 1.0)
		if _gather:
			a = clampf((_t - float(q.delay)) / 0.05, 0.0, 1.0) * (1.0 if _t < float(q.life) * 0.85 else 0.4)
		if a <= 0.0:
			continue
		var s := float(q.s)
		draw_rect(Rect2(((q.pos as Vector2) - Vector2(s, s) / 2.0).round(), Vector2(s, s)), Color(q.c as Color, a))
