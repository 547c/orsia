extends Node
# 화면 이동: 메인 메뉴 ↔ 원정 화면(원정 · 연습)

const MENU_PATH := "res://ui/main_menu.tscn"
const RUN_HOST_PATH := "res://p2/p5_run_host.tscn"

var host_request: Dictionary = {}
var _busy := false


func busy() -> bool:
	return _busy


func start_expedition(over: Dictionary = {}) -> bool:
	if _busy or not RunService.run.is_empty() or not RunService.field.is_empty():
		return false
	if not RunService.begin_expedition(-1, over) and not SaveManager.has_pending():
		return false
	_enter_host.call_deferred("expedition", false)
	return true


func start_practice(group_id: String, diff: String) -> bool:
	if _busy or not RunService.run.is_empty() or not RunService.field.is_empty():
		return false
	if not RunService.begin_practice(group_id, diff) and not SaveManager.has_pending():
		return false
	_enter_host.call_deferred("field", false)
	return true


# 이어하기: 저장된 원정 · 연습이 있으면 그 화면으로
func resume() -> bool:
	if _busy:
		return false
	if not RunService.run.is_empty():
		_enter_host.call_deferred("expedition", true)
		return true
	if not RunService.field.is_empty():
		_enter_host.call_deferred("field", true)
		return true
	return false


func _enter_host(mode: String, resumed: bool) -> void:
	_busy = true
	host_request = {"mode": mode, "resumed": resumed}
	await FadeOverlay.fade_out()
	get_tree().change_scene_to_file(RUN_HOST_PATH)
	await get_tree().process_frame
	await get_tree().process_frame
	await FadeOverlay.fade_in()
	_busy = false


func leave_run_host(_kind: String) -> void:
	host_request = {}
	RunService.battle = null
	GameState.end_combat_scope()
	to_menu()


func to_menu() -> void:
	_busy = true
	await FadeOverlay.fade_out()
	get_tree().change_scene_to_file(MENU_PATH)
	await get_tree().process_frame
	await get_tree().process_frame
	await FadeOverlay.fade_in()
	_busy = false
