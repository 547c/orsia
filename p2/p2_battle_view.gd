class_name P2BattleView
extends Node2D
# P2 전투 화면. 무대·카드·효과·소리는 P1 combat_lab을 옮겼고, 표시 방식만 바꿨다:
# 규칙은 입력을 받는 순간 확정되지만(즉시 사용), 화면의 체력·표식·방어·사망은 _shown(표시 상태)만 읽는다.
# _shown은 각 사건(event)이 "맞는 순간" 그 사건에 기록된 값으로만 바뀌고, 행동 연출이 끝나면 실제 상태와
# 한 번 맞춘다(_reconcile). 선택 예고를 지워도 최종 상태를 미리 보여 주지 않는다 (P1 14→8→11→8 결함 수정).
# 입력 잠금은 이 컨트롤러 한 곳: 행동을 받으면 BUSY, 연출이 끝나면 한 번만 PLAYER로 돌아간다.
# P3: 손패 최대 7장(1~7 키), 본문 16px, 새 효과(뽑기·억제·가르기·각인·렌즈·잔향·철편·인장·잔류·응징·강타 창) 표시,
# 던전 타일로 만든 층별 배경, 저장 실패 시 그 자리에서 멈추고 저장 창(SaveGate)을 기다린다.
# 직업 무기(지팡이·방패·활)와 동작, 최대 마나 칸, 치명타(확정은 미리 빛나고 무작위는 맞는 순간만),
# 사냥꾼 준비 칸, 보존·충전·소진 표시, 연료화 2단계 선택(취소 가능), 폭류 X, 유물 5칸.

signal finished(result: String)

const TILES := "res://assets/graphics/Pixel Crawler - Free Pack/Environment/Tilesets/Dungeon_Tiles.png"
const BODY := "res://assets/graphics/Pixel Crawler - Free Pack/Entities/Characters/Body_A/Animations/"
const ACTOR_SCALE := 4.0
# 수호기사 고해상도 프레임: 1500×1250 투명 캔버스, 뒷발 기준점 (562,1031), 대기 몸 높이 500px(포장 기준일 뿐).
# 화면에서는 몸 높이 WARDEN_SCREEN_H px로 한 번 줄여 그린다 (밉맵 + 선형). 프레임 시간·접촉 프레임은 매니페스트 그대로
const WARDEN_DIR := "res://assets/orsia_generated/char3_warden/"
const WARDEN_FOOT := Vector2(562, 1031)
const WARDEN_BODY_PX := 500.0
const WARDEN_SCREEN_H := 136.0
# 보충: 피격 4장(40/65/55/30ms, 3번은 대기와 같은 자세) · 사냥꾼·룬술사 숨쉬기 대기 6장. 동작별 폴더를 따로 쓴다 ([시간, 반복, 폴더])
const BASE6_DIR := "res://assets/orsia_generated/char6_baseline/"
const HURT_MS := [40, 65, 55, 30]
const BREATH_MS := [200, 240, 260, 240, 200, 220]
# 수호기사 대기를 사냥꾼·룬술사와 같은 숨쉬기 6장으로, 수호기사·사냥꾼 마법 시전(cast) 추가. 옛 대기 그림은 지우지 않음
const CAST7_DIR := "res://assets/orsia_generated/char7_casting/"
# 수호기사 방패 강타(bash) · 세 직업 넓은 공격(sweep). 같은 캔버스·발 기준점·배율, 접촉 2, 시간은 받은 후보값
const CHAR8_DIR := "res://assets/orsia_generated/char8_melee/"
const CHAR8_MS := [25, 80, 55, 85, 45]
# 근접 무기 자리(발 기준 원본 px, 프레임 1·2·3): 방패 앞면 · 검 끝 · 단검 끝 · 지팡이 끝. 화면에서는 배우 배율을 곱한다
const MELEE_SOCKETS := {
	"hunter": {"sweep": {1: Vector2(-151, -223), 2: Vector2(367, -187), 3: Vector2(338, -98)}},
	"rune_caster": {"sweep": {1: Vector2(-121, -411), 2: Vector2(553, -291), 3: Vector2(459, -73)}},
}
# 근접 접근은 바닥 줄을 따라 곧게. 지나는 동안 공격자를 앞에 그리고, 그 몸과 실제로 겹치는 다른 정지한 몸만 PASS_ALPHA까지 잠깐 흐리게 (표현만)
const PASS_ALPHA := 0.45
# 흐려지기는 짧게(맥 돌진 0.16초 중 겹치는 시간이 약 0.07초), 돌아오기는 조금 길게
const PASS_FADE_IN := 0.04
const PASS_FADE_OUT := 0.10
const PASS_MIN := 8.0
# WARDEN_COMBAT_01: 새 픽셀 수호기사 11가족. 272×192, 발 (112,175), 대기 몸 135 → 화면 136 (모든 가족 같은 배율, 최근접). 시간은 매니페스트 duration_ms
const WC_DIR := "res://assets/warden_combat/"
const WARDEN_ANIMS := {
	"idle": [[240, 240, 240, 240, 240, 240], true],
	"slash": [[30, 90, 40, 80, 110, 20], false],
	"block": [[25, 55, 40, 65, 70, 20], false],
	"hurt": [[35, 90, 60, 20], false],
	"counter": [[25, 60, 35, 60, 80, 20], false],
	"cast": [[25, 65, 55, 60, 80, 20], false],
	"cast_strong": [[25, 80, 70, 70, 100, 20], false],
	"bash": [[25, 75, 45, 65, 90, 20], false],
	"sweep": [[25, 80, 45, 70, 90, 20], false],
	"focus": [[25, 70, 100, 70, 80, 20], false],
	"death": [[60, 100, 120, 500], false],
}
const WARDEN_CONTACT := {"slash": 2, "block": 3, "counter": 3, "cast": 3, "cast_strong": 3, "bash": 3, "sweep": 2, "focus": 2}
# 프레임별 무기 자리(발 기준 원본 px): 시전·반격·휩쓸기 = 검끝, 방패 강타 = 방패 앞면
const WARDEN_SOCKETS := {
	"slash": {2: Vector2(91, -79)},
	"cast": {0: Vector2(44, -91), 1: Vector2(44, -110), 2: Vector2(33, -130), 3: Vector2(102, -111), 4: Vector2(49, -104), 5: Vector2(44, -91)},
	"cast_strong": {0: Vector2(44, -91), 1: Vector2(49, -96), 2: Vector2(45, -127), 3: Vector2(132, -82), 4: Vector2(55, -112), 5: Vector2(44, -91)},
	"counter": {0: Vector2(44, -91), 1: Vector2(62, -38), 2: Vector2(81, -43), 3: Vector2(121, -65), 4: Vector2(60, -91), 5: Vector2(44, -91)},
	"bash": {0: Vector2(44, -91), 1: Vector2(20, -62), 2: Vector2(70, -72), 3: Vector2(80, -83), 4: Vector2(25, -61), 5: Vector2(44, -91)},
	"sweep": {0: Vector2(44, -91), 1: Vector2(55, -117), 2: Vector2(95, -79), 3: Vector2(99, -17), 4: Vector2(61, -108), 5: Vector2(44, -91)},
}
# 사냥꾼: 1400×1250 캔버스, 뒷발 기준점 (540,1040), 대기 몸 500px. 대기는 정지 한 장.
# 실행 시간은 매니페스트 미리보기 시간을 조금 줄인 값 (발사 4 · 근접 접촉 3 · 버티기 3 프레임은 그대로, 조준은 당긴 채 멈춤이 더 김)
const HUNTER_DIR := "res://assets/orsia_generated/char4_hunter/"
const HUNTER_FOOT := Vector2(540, 1040)
const HUNTER_ANIMS := {
	"idle": [BREATH_MS, true, BASE6_DIR + "hunter/"],
	"hurt": [HURT_MS, false, BASE6_DIR + "hunter/"],
	"cast": [[60, 85, 65, 75, 80], false, CAST7_DIR + "hunter/"],
	"shot": [[150, 70, 80, 80, 80, 160], false],
	"aim": [[120, 110, 130, 220, 80, 160], false],
	"melee": [[120, 80, 80, 80, 100, 160], false],
	"defend": [[120, 80, 100, 90, 100, 160], false],
	"sweep": [CHAR8_MS, false, CHAR8_DIR + "hunter/"],
}
const HUNTER_CONTACT := {"shot": 4, "aim": 4, "melee": 3, "defend": 3, "cast": 2, "sweep": 2}
# 수호기사·사냥꾼 시전: 프레임별 마력이 나오는 자리(발 기준 원본 px) — 수호기사 칼끝(발사 3), 사냥꾼 빈 손바닥(발사 2). 준비 프레임은 손 위치 안내값
const CAST_SOCKETS := {
	"hunter": {1: Vector2(136, -267), 2: Vector2(417, -332), 3: Vector2(136, -267)},
}
const HUNTER_BOW := Vector2(100, -82)
const HUNTER_REACH := 140.0
# 룬술사: 1500×1400 캔버스, 뒷발 기준점 (520,1120). 네 동작 모두 접촉·발사 프레임 3. 소켓은 발 기준 원본 px (수정·지팡이 끝·손바닥)
const RUNE_DIR := "res://assets/orsia_generated/char5_rune_caster/"
const RUNE_FOOT := Vector2(520, 1120)
const RUNE_ANIMS := {
	"idle": [BREATH_MS, true, BASE6_DIR + "rune_caster/"],
	"hurt": [HURT_MS, false, BASE6_DIR + "rune_caster/"],
	"cast": [[90, 60, 60, 70, 80, 120], false],
	"strong_cast": [[90, 80, 110, 80, 100, 120], false],
	"melee": [[90, 70, 80, 60, 80, 120], false],
	"defend": [[90, 60, 60, 90, 80, 120], false],
	"sweep": [CHAR8_MS, false, CHAR8_DIR + "rune_caster/"],
}
const RUNE_CONTACT := {"cast": 3, "strong_cast": 3, "melee": 3, "defend": 3, "sweep": 2}
const RUNE_SOCKET := {"cast": Vector2(478, -295), "strong_cast": Vector2(549, -300), "melee": Vector2(465, -196), "defend": Vector2(308, -290)}
# 옷 입은 고해상도 배우: 직업별 그림 묶음. 동작 이름·접촉 프레임은 직업마다 따로 (수호기사 이름을 사냥꾼에 쓰지 않음)
# 수호기사 베기 파동: 512×448 프레임 12장(기본·강화), 앞날 기준점 (392,224). 발사0–2 · 비행3–6(반복) · 접촉7–9 · 사라짐10–11
const CRESCENT_DIR := "res://assets/orsia_generated/av4_crescent/"
const CRESCENT_ANCHOR := Vector2(392, 224)
const CRESCENT := {
	"basic": {"ms": [25, 25, 25, 30, 30, 30, 30, 35, 35, 35, 35, 35], "scale": 0.5},
	"major": {"ms": [30, 30, 30, 35, 35, 35, 35, 40, 40, 40, 40, 40], "scale": 0.60},
}
# 베기 파동이 나오는 칼끝(화면 px, 발 기준): 새 수호기사 slash 2의 검끝 × 136/135
const WARDEN_TIP := Vector2(91, -79)
# 수로 배경과 큰 배치(몸 200px): 원정 하층(구간 I)의 모든 전투·직업에 켠다. 큰 층은 1440×880을 (-80,-80)에, [파일, z, 카메라 따라가기 비율, 셰이더]
const ENV_DIR := "res://assets/battle_env_waterworks/"
const ENV_LAYERS := [["far_cave", -40, 0.22, ""], ["near_arch", -30, 0.55, ""], ["water_base", -28, 0.55, ""], ["water_mask", -27, 0.55, "water_flow"],
	["fall_mask", -26, 0.55, "fall_flow"], ["torch_fixtures", -23, 0.55, ""], ["floor_ledge", -20, 1.0, ""]]
# [시트, 좌상단(화면 좌표), z, 장 수, 장당 ms, 위상(장)] — 시간은 assets/animation_timing.json 값
const ENV_ANIMS := [["fire_sheet", Vector2(140, 179), -24, 8, 70.0, 0], ["fire_sheet", Vector2(1207, 120), -24, 8, 70.0, 3], ["splash_sheet", Vector2(367, 220), -25, 6, 80.0, 0],
	["splash_sheet", Vector2(367 + FALL2_DX, 220), -25, 6, 80.0, 2]]
# 적 쪽 기둥 왼쪽 물줄기: 뒤 물줄기 그림을 옆으로 옮겨 하나 더(앞 아치가 곧게 잘린 자리의 빛 줄을 가림). 무늬 위상만 다르게
const FALL2_DX := 748.0
# [자리, 색, 반경 px, 세기, 흔들림 비율]
const ENV_LIGHTS := [[Vector2(156, 207), Color(1.0, 0.70, 0.38), 330.0, 0.50, 0.06], [Vector2(1223, 145), Color(1.0, 0.70, 0.38), 270.0, 0.45, 0.06], [Vector2(650, 278), Color(0.34, 0.69, 0.82), 580.0, 0.14, 0.0]]
const ENV_BODY_H := 200.0
# 전투 UI 조각: 원본 1배 PNG를 최근접으로 키워 쓴다. 쉬는 카드·일반 조각 3배, 올린 카드 4배
const UIB := "res://assets/ui_battle/"
# 맥 수조 물 높이(조각 48px 기준 수면 y): 가득 = 12, 빈 = 41. 0이면 물을 그리지 않는다
const MANA_FULL_Y := 12.0
const MANA_EMPTY_Y := 41.0
# 배우를 바닥에 붙이는 표현: 같은 프레임을 눕힌 실루엣 그림자(납작한 정도·기우는 정도·색)와 횃불 쪽 테두리 빛(화면 px)
const ENV_SHADE := {"squash": 0.42, "lean": 0.75, "color": Color(0.02, 0.03, 0.08, 0.5), "rim_px": 2.0}
# 횃불 아래 바닥의 빛 웅덩이 둘과 물가의 옅은 안개: [자리, 색, 크기]
const ENV_FLOOR_GLOW := [[Vector2(156, 338), Color(1.0, 0.62, 0.30, 0.16), Vector2(520, 110)], [Vector2(1223, 338), Color(1.0, 0.62, 0.30, 0.16), Vector2(520, 110)],
	[Vector2(640, 292), Color(0.42, 0.72, 0.80, 0.11), Vector2(1900, 120)]]
const ENV_HOME_X := 380.0
# 접촉 효과: 640×640 캔버스, 기준점 (320,320)을 실제 몸·접촉 자리에 둔다. start = 처음 보일 프레임(표식은 2가 터지는 순간, 0–1 모음은 _mark_converge가 대신)
const AV5_DIR := "res://assets/orsia_generated/av5/"
const AV5_CONTACT := {
	"slash_contact": {"ms": [25, 35, 35, 40, 45, 45], "scale": 0.20, "start": 0, "residue": 3},
	"slash_major_contact": {"ms": [30, 40, 40, 45, 45, 50], "scale": 0.26, "start": 0, "residue": 3},
	"mark_rupture": {"ms": [25, 25, 35, 35, 40, 45, 45, 45], "scale": 0.26, "start": 2, "residue": 5},
	"shield_contact": {"ms": [25, 35, 35, 40, 45, 45], "scale": 0.22, "start": 0, "residue": 3},
	"body_contact": {"ms": [20, 30, 35, 40, 45, 45], "scale": 0.20, "start": 0, "residue": 3},
}
# 수호기사 검날: 실제 동작 프레임에 붙는 잔상(몸 뒤)·광택(몸 위). 배우와 같은 1500×1250 캔버스·발 기준점
const AV5_WEAPON_FRAMES := {"slash": [1, 2, 3], "counter": [2, 3]}
# 접촉 한 번의 무게: 정지(초) · 맞은 몸 밀림(px)과 나감/돌아옴 · 눌림(가로, 세로) · 기울기(도) · 카메라 한 번 밀림(px)과 안정 · 섞는 번쩍임.
# 연출용 변형일 뿐 넉백·기절 규칙이 아니다. secondary = 방전 고리·가르기 같은 딸린 타격(카메라 1px 상한)
const IMPACT := {
	"light": {"hold": 0.060, "push": 22.0, "out": 0.035, "back": 0.110, "squash": Vector2(1.06, 0.95), "tilt": 0.0, "cam": 4.0, "settle": 0.110, "flash": 0.75, "fpeak": 0.030, "fclear": 0.070},
	"heavy": {"hold": 0.110, "push": 46.0, "out": 0.045, "back": 0.145, "squash": Vector2(1.11, 0.90), "tilt": 3.5, "cam": 10.0, "settle": 0.160, "flash": 1.0, "fpeak": 0.035, "fclear": 0.085},
	"counter": {"hold": 0.090, "push": 32.0, "out": 0.035, "back": 0.120, "squash": Vector2(1.08, 0.94), "tilt": 2.0, "cam": 7.0, "settle": 0.130, "flash": 0.85, "fpeak": 0.030, "fclear": 0.070},
	"secondary": {"hold": 0.0, "push": 8.0, "out": 0.030, "back": 0.100, "squash": Vector2(1.025, 0.98), "tilt": 0.0, "cam": 1.0, "settle": 0.080, "flash": 0.50, "fpeak": 0.020, "fclear": 0.045},
	"block": {"hold": 0.050, "push": 4.0, "out": 0.030, "back": 0.080, "cam": 3.0, "settle": 0.090},
	"player_hurt": {"hold": 0.070, "push": 13.0, "out": 0.035, "back": 0.120, "cam": 7.0, "settle": 0.130, "flash": 0.75, "fpeak": 0.030, "fclear": 0.080},
}
const CAM_RANK := {"secondary": 1, "block": 2, "light": 3, "counter": 4, "player_hurt": 4, "heavy": 5}
# 강약 대비 실험(표현만, 설정 '새 전투 연출'). basic = 기존 그대로 + 작은 접촉 빛. enhanced = 실제 강화 주 공격(준비 물러남 → 비행 따라가기·속도선·주변 흐림 →
# 접촉 당김·빛·왜곡 → 정리). payoff = 강화+표식 소모 / 강화+실제 치명 / 실제 보스 처치의 주 접촉 한 번(+짧은 흑백 → 색 분리 꼬리). 값은 1280×720 논리 px·ms
const AV7 := {
	"basic": {"light_r": 65.0, "light_ms": 65.0, "light_e": 1.4},
	"enhanced": {"prep_zoom": 0.95, "prep_ms": 80.0, "track_px": 12.0, "lines": 8, "cue_ms": 65.0, "blur_px": 2.0, "sharp_r": 115.0,
		"zoom": 1.055, "zoom_in_ms": 28.0, "kick": 8.0, "settle_ms": 150.0, "dim": 0.22,
		"warp_px": 2.5, "warp_r": 140.0, "warp_ms": 130.0, "light_r": 135.0, "light_ms": 100.0, "light_e": 2.2},
	"payoff": {"zoom": 1.075, "zoom_in_ms": 28.0, "kick": 10.0, "settle_ms": 175.0, "mono_ms": 70.0, "chroma_px": 2.4, "chroma_ms": 80.0,
		"warp_px": 3.5, "warp_r": 170.0, "warp_ms": 140.0, "light_r": 160.0, "light_ms": 115.0, "light_e": 2.8},
	"maek_floor": {"r": 56.0, "alpha": 0.32},
}
const AV7_RANK := 6
const AV7_IVORY := Color(0.96, 0.93, 0.84)
# 전투 화면 한 장 합성(세계 다음, UI 전): 접촉 고리 굴절 · 주변부 방사 흐림(배우 주변은 또렷) · 색 분리. 쉬는 동안은 숨김
const AV7_COMPOSITE := "shader_type canvas_item;\nrender_mode unshaded;\nuniform sampler2D screen_tex : hint_screen_texture, filter_linear;\nuniform vec2 view_px = vec2(1280.0, 720.0);\nuniform float px_scale = 1.0;\nuniform vec2 center = vec2(640.0, 360.0);\nuniform vec2 sharp_a = vec2(-9999.0);\nuniform vec2 sharp_b = vec2(-9999.0);\nuniform float sharp_r = 115.0;\nuniform float ring_r = 0.0;\nuniform float ring_w = 36.0;\nuniform float ring_amp = 0.0;\nuniform float blur_px = 0.0;\nuniform float chroma_px = 0.0;\nvoid fragment() {\n\tvec2 p = UV * view_px;\n\tvec2 px_uv = SCREEN_PIXEL_SIZE * px_scale;\n\tvec2 d = p - center;\n\tfloat r = length(d);\n\tvec2 rad = r > 0.001 ? d / r : vec2(0.0);\n\tfloat band = 1.0 - smoothstep(0.0, ring_w, abs(r - ring_r));\n\tvec2 uv = SCREEN_UV - rad * ring_amp * band * px_uv;\n\tfloat w = smoothstep(sharp_r, sharp_r + 190.0, min(length(p - sharp_a), length(p - sharp_b)));\n\tvec3 col;\n\tif (blur_px * w > 0.02) {\n\t\tcol = vec3(0.0);\n\t\tfor (int i = -2; i <= 2; i++) {\n\t\t\tcol += texture(screen_tex, uv + rad * float(i) * 0.5 * blur_px * w * px_uv).rgb;\n\t\t}\n\t\tcol /= 5.0;\n\t} else {\n\t\tcol = texture(screen_tex, uv).rgb;\n\t}\n\tif (chroma_px > 0.01) {\n\t\tvec2 co = rad * chroma_px * px_uv;\n\t\tcol.r = texture(screen_tex, uv + co).r;\n\t\tcol.b = texture(screen_tex, uv - co).b;\n\t}\n\tCOLOR = vec4(col, 1.0);\n}\n"
# 흑백 순간의 실루엣: 그림의 알파만 쓰고 색은 상아색 하나
const AV7_SILHOUETTE := "shader_type canvas_item;\nrender_mode unshaded;\nuniform vec4 tint : source_color = vec4(0.96, 0.93, 0.84, 1.0);\nvoid fragment() {\n\tCOLOR = vec4(tint.rgb, COLOR.a);\n}\n"
const FOCUS := {"zoom": 1.025, "in": 0.040, "out": 0.105, "dim": 0.10, "cap": 12.0}
const PARTIAL_BODY_OFFSET := 0.030
const MARK_PEAK_OFFSET := 0.045
const RESIDUE_ALPHA := 0.45
# 수호기사 베기 파동 재생(동작 그림은 그대로, 보여 주는 시간만): 1자세 준비 80ms → 2자세 발사 40ms → 3자세(따라가기)로 도착까지 → 4자세 회복 85ms → 대기
const WAVE_PREP := 0.090
const WAVE_RELEASE := 0.040
const WAVE_RECOVER := 0.110
const WAVE_TRAIL_CLEAR := {"basic": 0.070, "major": 0.100}
# 접촉 하나만 색을 섞는 번쩍임 (알파·기존 색조·사라짐은 그대로). 배우마다 따로 쓰는 재질
const FLASH_SHADER := "shader_type canvas_item;\nuniform vec4 flash_color : source_color = vec4(1.0);\nuniform float flash_mix = 0.0;\nvoid fragment() {\n\tCOLOR.rgb = mix(COLOR.rgb, flash_color.rgb, flash_mix);\n}\n"
# stance_x·head_y: 대기 그림에서 잰 두 발 가운데·머리 꼭대기(발 기준 원본 px, 매니페스트). shadow_w: 화면 px. reach: 근접 접촉 거리(화면 px)
# body_l·body_r: 대기 첫 장에서 칠해진 가로 범위(발 기준 원본 px) — 지나가며 겹치는지 볼 때만 씀
const ACTOR_ART := {
	"warden": {"dir": WC_DIR, "foot": Vector2(112, 175), "body_px": 135.0, "nearest": true, "anims": WARDEN_ANIMS, "contact": WARDEN_CONTACT, "sockets": WARDEN_SOCKETS,
		"stance_x": 0.0, "head_y": -134.0, "shadow_w": 56.0, "body_l": -40.0, "body_r": 46.0},
	"hunter": {"dir": HUNTER_DIR, "foot": HUNTER_FOOT, "anims": HUNTER_ANIMS, "contact": HUNTER_CONTACT,
		"stance_x": 114.75, "head_y": -497.0, "shadow_w": 81.0, "reach": HUNTER_REACH, "body_l": -45.0, "body_r": 405.0},
	"rune_caster": {"dir": RUNE_DIR, "foot": RUNE_FOOT, "anims": RUNE_ANIMS, "contact": RUNE_CONTACT,
		"stance_x": 102.25, "head_y": -499.0, "shadow_w": 74.0, "reach": 128.0, "body_l": -58.0, "body_r": 353.0},
}
# 승인된 적 그림(표현 설정만). ENEMY_ART_PICKS에 맞는 적 하나에만 붙인다 — 이름·능력치·행동·보상·저장은 그대로.
# 원본은 왼쪽을 보는 1254px 한 장 + 같은 캔버스의 맥(Maek) 가면 + 대기 흐름 셰이더. foot = 발 기준점, top = 머리 꼭대기(원본 px)
const MAEK_DIR := "res://assets/orsia_generated/enemy7_maek/"
# 같은 배우의 공격(준비·들어 올림·접촉·회복·준비)·피격(준비·피격·준비). 1800x1450 캔버스, 발 기준점 (974,1310) — 대기 원본과 같은 배율.
# blade = 접촉 프레임 칼날 기준점(발 기준 원본 px), reach = 주인공 몸 중심에서 칼날이 닿을 앞쪽 거리(화면 px). 시간은 받은 후보값(초)
const MAEK8_DIR := "res://assets/orsia_generated/enemy8_maek_actions/"
const MAEK_ACTIONS := {"origin": Vector2(974, 1310), "blade": Vector2(-878, -371), "reach": 24.0,
	"attack": [MAEK8_DIR + "attack/attack_00.png", MAEK8_DIR + "attack/attack_01.png", MAEK8_DIR + "attack/attack_02.png", MAEK8_DIR + "attack/attack_03.png", MAEK8_DIR + "attack/attack_04.png"],
	"hurt": [MAEK8_DIR + "hurt/hurt_00.png", MAEK8_DIR + "hurt/hurt_01.png", MAEK8_DIR + "hurt/hurt_02.png"],
	"attack_s": [0.035, 0.105, 0.055, 0.100, 0.055], "hurt_s": [0.020, 0.105, 0.055]}
# 하급(식칼) · 상급(맨손 주먹 정령). 대기 1254px · 동작 1800x1450, 발 기준점은 따로, 배율은 각자 몸 높이(882 · 1069px)로 136px.
# contact_offset = 접촉 프레임(2)의 칼날/주먹 기준점(동작 발 기준 원본 px). 중급은 기존 blade 그대로. top = 발 y − 몸 기준 높이
const MAEK13_EARLY := "res://assets/orsia_generated/enemy13_maek_early/"
const MAEK13_UPPER := "res://assets/orsia_generated/enemy13_maek_upper/"
const MAEK_EARLY_ACTIONS := {"origin": Vector2(1065, 1300), "contact_offset": Vector2(-835, -293), "reach": 24.0,
	"attack": [MAEK13_EARLY + "attack/attack_00.png", MAEK13_EARLY + "attack/attack_01.png", MAEK13_EARLY + "attack/attack_02.png", MAEK13_EARLY + "attack/attack_03.png", MAEK13_EARLY + "attack/attack_04.png"],
	"hurt": [MAEK13_EARLY + "hurt/hurt_00.png", MAEK13_EARLY + "hurt/hurt_01.png", MAEK13_EARLY + "hurt/hurt_02.png"],
	"attack_s": [0.025, 0.085, 0.050, 0.085, 0.045], "hurt_s": [0.020, 0.095, 0.045]}
const MAEK_UPPER_ACTIONS := {"origin": Vector2(930, 1320), "contact_offset": Vector2(-788, -676), "reach": 24.0,
	"attack": [MAEK13_UPPER + "attack/attack_00.png", MAEK13_UPPER + "attack/attack_01.png", MAEK13_UPPER + "attack/attack_02.png", MAEK13_UPPER + "attack/attack_03.png", MAEK13_UPPER + "attack/attack_04.png"],
	"hurt": [MAEK13_UPPER + "hurt/hurt_00.png", MAEK13_UPPER + "hurt/hurt_01.png", MAEK13_UPPER + "hurt/hurt_02.png"],
	"attack_s": [0.025, 0.085, 0.050, 0.085, 0.045], "hurt_s": [0.020, 0.095, 0.045]}
# 구간 I 소환사(2200x1750, 발 (1050,1550), 몸 기준 1049px → 155px)와 작은 소환수(1000x800, 발 (700,650), 몸 기준 337px → 58px).
# 모든 동작이 대기와 같은 캔버스·발 기준점. 소환수 대기는 부풀어 오른(primed) 그림 + 그에 맞는 흐름 가면. body_ref가 있으면 배율 = body_px / body_ref
const MAEK16_DIR := "res://assets/orsia_generated/enemy16_summoner/"
const SUMMONER_ACTIONS := {"origin": Vector2(1050, 1550), "contact_offset": Vector2(-712, -741), "reach": 0.0, "anims": ["attack", "hurt", "summon"],
	"attack": [MAEK16_DIR + "boss/cast/cast_00.png", MAEK16_DIR + "boss/cast/cast_01.png", MAEK16_DIR + "boss/cast/cast_02.png", MAEK16_DIR + "boss/cast/cast_03.png", MAEK16_DIR + "boss/cast/cast_04.png"],
	"hurt": [MAEK16_DIR + "boss/hurt/hurt_00.png", MAEK16_DIR + "boss/hurt/hurt_01.png", MAEK16_DIR + "boss/hurt/hurt_02.png"],
	"summon": [MAEK16_DIR + "boss/summon/summon_00.png", MAEK16_DIR + "boss/summon/summon_01.png", MAEK16_DIR + "boss/summon/summon_02.png", MAEK16_DIR + "boss/summon/summon_03.png", MAEK16_DIR + "boss/summon/summon_04.png"],
	"attack_s": [0.025, 0.070, 0.045, 0.070, 0.040], "hurt_s": [0.015, 0.100, 0.045], "summon_s": [0.030, 0.085, 0.060, 0.080, 0.045]}
const SPAWN_ACTIONS := {"origin": Vector2(700, 650), "contact_offset": Vector2(-440, -170), "reach": 24.0, "anims": ["hurt", "burst", "defeat", "ready"],
	"hurt": [MAEK16_DIR + "minion/hurt/hurt_00.png", MAEK16_DIR + "minion/hurt/hurt_01.png", MAEK16_DIR + "minion/hurt/hurt_02.png"],
	"burst": [MAEK16_DIR + "minion/burst/burst_00.png", MAEK16_DIR + "minion/burst/burst_01.png", MAEK16_DIR + "minion/burst/burst_02.png"],
	"defeat": [MAEK16_DIR + "minion/defeat/defeat_00.png", MAEK16_DIR + "minion/defeat/defeat_01.png"],
	"ready": [MAEK16_DIR + "minion/ready/ready_00.png"],
	"hurt_s": [0.015, 0.090, 0.035], "burst_s": [0.060, 0.070, 0.090], "defeat_s": [0.065, 0.100], "hurt_end_idle": true}
# 하급·중급 맥 사수. 1800x1450 캔버스, 발 (900,1340), 몸 기준 927 · 991px → 136px. 대기 6장마다 맞는 흐름 가면이 따로 있다(프레임과 함께 바꿈).
# 공격은 제자리: 준비 → 당기기 → 놓기(2, 화살 한 발 출발) → 회복 → 준비. release_socket = 놓는 프레임의 활 자리(발 기준 원본 px, 화면에서 맞춘 값)
const MAEK19_DIR := "res://assets/orsia_generated/enemy19_archers/"
# 하급 맥 방패병. 1800x1450 캔버스, 발 (900,1340), 몸 기준 1027px → 136px. 방패 있음/없음 두 벌(대기 6장+가면·공격 5·피격 3)과
# 방패 흡수 3 · 방패 놓침 4. 어느 벌을 보일지는 화면에 보인 방패 값(_shown)이 정한다 — _shield_set
const SB25_DIR := "res://assets/orsia_generated/enemy25_shieldbearer/"
const SB25_IDLE_MS := [220, 260, 300, 280, 300, 240]
# 중층 맥 방패병. 같은 캔버스·발 기준, 몸 기준 1121px. 구조·시간·상태 처리는 하층과 같고 그림·몸 크기·곤봉 끝만 다르다
# reach 32: 24면 큰 나무 방패가 주인공 방패·앞발에 약 10px 파고들어, 곤봉 끝이 주인공 방패 앞면에 닿는 거리로 맞춤(실제 접촉 화면에서 확인)
const SB28_DIR := "res://assets/orsia_generated/enemy28_shieldbearer_mid/"
# 구간 I 선택 정예 '맥 거완'. 1800x1450, 발 (900,1340), 몸 기준 1022px. 대기·준비(팔 듦)·힘 풀림 세 벌의 대기 6장+가면,
# 공격(보통 6 한 타격마다)·준비 전환·강타·약타·피격·힘 풀림 전환. 어느 대기 벌인지는 실제 사건이 정한다 — _steady_set
const ME31_DIR := "res://assets/orsia_generated/enemy31_maek_elite/"
# 구간 II 보스 '맥 귀족'. 1800x1450, 발 (900,1340), 몸 기준 1196px. 제자리 시전(물창 발사 손 = release_socket), 봉인 손짓, 무릎 꿇은 쓰러짐(defeat)
const NB38_DIR := "res://assets/orsia_generated/enemy38_maek_noble/"
# 구간 I N3 지원술사(기존 기수 역할의 표현만). 제자리 시전: 앞손 발사(contact_offset)에서 기존 마력 핵 — 소환사와 같은 cast 경로(cast_art)
const SP43_DIR := "res://assets/orsia_generated/enemy43_maek_support/"
# 구간 I N4 주술사(기존 hexer 표현만). 공격 = cast_art 마력 핵(봉 고리 contact_offset), 주술 = hex 자세(hex_socket은 주술 순간 고리)
const HX45_DIR := "res://assets/orsia_generated/enemy45_maek_hexer/"
const ENEMY_ART := {
	"maek_hexer_early": {"body": HX45_DIR + "idle/idle_00.png", "mask": HX45_DIR + "idle_masks/mask_00.png", "shader": MAEK_DIR + "maek_idle_flow.gdshader",
		"idle_frames": [HX45_DIR + "idle/idle_00.png", HX45_DIR + "idle/idle_01.png", HX45_DIR + "idle/idle_02.png", HX45_DIR + "idle/idle_03.png", HX45_DIR + "idle/idle_04.png", HX45_DIR + "idle/idle_05.png"], "idle_masks": [HX45_DIR + "idle_masks/mask_00.png", HX45_DIR + "idle_masks/mask_01.png", HX45_DIR + "idle_masks/mask_02.png", HX45_DIR + "idle_masks/mask_03.png", HX45_DIR + "idle_masks/mask_04.png", HX45_DIR + "idle_masks/mask_05.png"], "idle_ms": [250, 270, 300, 300, 270, 250],
		"foot": Vector2(900, 1340), "top": 388.0, "left": 169.0, "right": 1277.0, "body_px": 136.0, "body_ref": 952.0, "shadow_rx": 40.0,
		"amount": 0.8, "speed": 0.75, "density": 12.0, "cast_art": true,
		"actions": {"origin": Vector2(900, 1340), "anims": ["attack", "hex", "hurt"], "contact_offset": Vector2(-806, -687), "hex_socket": Vector2(-582, -1037),
		"attack": [HX45_DIR + "attack/attack_00.png", HX45_DIR + "attack/attack_01.png", HX45_DIR + "attack/attack_02.png", HX45_DIR + "attack/attack_03.png", HX45_DIR + "attack/attack_04.png"], "hex": [HX45_DIR + "hex/hex_00.png", HX45_DIR + "hex/hex_01.png", HX45_DIR + "hex/hex_02.png", HX45_DIR + "hex/hex_03.png", HX45_DIR + "hex/hex_04.png"], "hurt": [HX45_DIR + "hurt/hurt_00.png", HX45_DIR + "hurt/hurt_01.png", HX45_DIR + "hurt/hurt_02.png"],
		"attack_s": [0.020, 0.070, 0.055, 0.050, 0.030], "hex_s": [0.020, 0.070, 0.085, 0.050, 0.030], "hurt_s": [0.020, 0.100, 0.040]}},
	"maek_support_early": {"body": SP43_DIR + "idle/idle_00.png", "mask": SP43_DIR + "idle_masks/mask_00.png", "shader": MAEK_DIR + "maek_idle_flow.gdshader",
		"idle_frames": [SP43_DIR + "idle/idle_00.png", SP43_DIR + "idle/idle_01.png", SP43_DIR + "idle/idle_02.png", SP43_DIR + "idle/idle_03.png", SP43_DIR + "idle/idle_04.png", SP43_DIR + "idle/idle_05.png"], "idle_masks": [SP43_DIR + "idle_masks/mask_00.png", SP43_DIR + "idle_masks/mask_01.png", SP43_DIR + "idle_masks/mask_02.png", SP43_DIR + "idle_masks/mask_03.png", SP43_DIR + "idle_masks/mask_04.png", SP43_DIR + "idle_masks/mask_05.png"], "idle_ms": [250, 270, 300, 300, 270, 250],
		"foot": Vector2(900, 1340), "top": 324.0, "left": 290.0, "right": 1298.0, "body_px": 136.0, "body_ref": 1016.0, "shadow_rx": 40.0,
		"amount": 0.8, "speed": 0.75, "density": 12.0, "cast_art": true,
		"actions": {"origin": Vector2(900, 1340), "anims": ["attack", "hurt"], "contact_offset": Vector2(-549, -646),
		"attack": [SP43_DIR + "attack/attack_00.png", SP43_DIR + "attack/attack_01.png", SP43_DIR + "attack/attack_02.png", SP43_DIR + "attack/attack_03.png", SP43_DIR + "attack/attack_04.png"], "hurt": [SP43_DIR + "hurt/hurt_00.png", SP43_DIR + "hurt/hurt_01.png", SP43_DIR + "hurt/hurt_02.png"],
		"attack_s": [0.020, 0.070, 0.055, 0.050, 0.030], "hurt_s": [0.020, 0.100, 0.040]}},
	"maek_noble_mid": {"body": NB38_DIR + "idle/idle_00.png", "mask": NB38_DIR + "idle_masks/mask_00.png", "shader": MAEK_DIR + "maek_idle_flow.gdshader",
		"idle_frames": [NB38_DIR + "idle/idle_00.png", NB38_DIR + "idle/idle_01.png", NB38_DIR + "idle/idle_02.png", NB38_DIR + "idle/idle_03.png", NB38_DIR + "idle/idle_04.png", NB38_DIR + "idle/idle_05.png"], "idle_masks": [NB38_DIR + "idle_masks/mask_00.png", NB38_DIR + "idle_masks/mask_01.png", NB38_DIR + "idle_masks/mask_02.png", NB38_DIR + "idle_masks/mask_03.png", NB38_DIR + "idle_masks/mask_04.png", NB38_DIR + "idle_masks/mask_05.png"], "idle_ms": [250, 270, 300, 300, 270, 250],
		"foot": Vector2(900, 1340), "top": 144.0, "left": 406.0, "right": 1250.0, "body_px": 168.0, "body_ref": 1196.0, "shadow_rx": 54.0,
		"amount": 0.8, "speed": 0.75, "density": 12.0, "ranged_art": true, "lance": true,
		"actions": {"origin": Vector2(900, 1340), "anims": ["attack", "hurt", "seal", "defeat"], "release_socket": Vector2(-527, -788),
		"attack": [NB38_DIR + "attack/attack_00.png", NB38_DIR + "attack/attack_01.png", NB38_DIR + "attack/attack_02.png", NB38_DIR + "attack/attack_03.png", NB38_DIR + "attack/attack_04.png"], "hurt": [NB38_DIR + "hurt/hurt_00.png", NB38_DIR + "hurt/hurt_01.png", NB38_DIR + "hurt/hurt_02.png"],
		"seal": [NB38_DIR + "seal/seal_00.png", NB38_DIR + "seal/seal_01.png", NB38_DIR + "seal/seal_02.png", NB38_DIR + "seal/seal_03.png", NB38_DIR + "seal/seal_04.png"], "defeat": [NB38_DIR + "death/death_00.png", NB38_DIR + "death/death_01.png"],
		"attack_s": [0.020, 0.075, 0.055, 0.075, 0.035], "hurt_s": [0.020, 0.100, 0.040], "seal_s": [0.020, 0.070, 0.060, 0.050, 0.025], "defeat_s": [0.050, 0.160]}},
	"maek_elite_low": {"body": ME31_DIR + "idle_00.png", "mask": ME31_DIR + "idle_mask_00.png", "shader": MAEK_DIR + "maek_idle_flow.gdshader",
		"idle_frames": [ME31_DIR + "idle_00.png", ME31_DIR + "idle_01.png", ME31_DIR + "idle_02.png", ME31_DIR + "idle_03.png", ME31_DIR + "idle_04.png", ME31_DIR + "idle_05.png"], "idle_masks": [ME31_DIR + "idle_mask_00.png", ME31_DIR + "idle_mask_01.png", ME31_DIR + "idle_mask_02.png", ME31_DIR + "idle_mask_03.png", ME31_DIR + "idle_mask_04.png", ME31_DIR + "idle_mask_05.png"], "idle_ms": SB25_IDLE_MS,
		"foot": Vector2(900, 1340), "top": 318.0, "left": 268.0, "right": 1275.0, "body_px": 150.0, "body_ref": 1022.0, "shadow_rx": 46.0,
		"amount": 0.8, "speed": 0.75, "density": 12.0,
		"steady": {"charged": {"idle_frames": [ME31_DIR + "charged_00.png", ME31_DIR + "charged_01.png", ME31_DIR + "charged_02.png", ME31_DIR + "charged_03.png", ME31_DIR + "charged_04.png", ME31_DIR + "charged_05.png"], "idle_masks": [ME31_DIR + "charged_mask_00.png", ME31_DIR + "charged_mask_01.png", ME31_DIR + "charged_mask_02.png", ME31_DIR + "charged_mask_03.png", ME31_DIR + "charged_mask_04.png", ME31_DIR + "charged_mask_05.png"]},
			"weakened": {"idle_frames": [ME31_DIR + "weakened_00.png", ME31_DIR + "weakened_01.png", ME31_DIR + "weakened_02.png", ME31_DIR + "weakened_03.png", ME31_DIR + "weakened_04.png", ME31_DIR + "weakened_05.png"], "idle_masks": [ME31_DIR + "weakened_mask_00.png", ME31_DIR + "weakened_mask_01.png", ME31_DIR + "weakened_mask_02.png", ME31_DIR + "weakened_mask_03.png", ME31_DIR + "weakened_mask_04.png", ME31_DIR + "weakened_mask_05.png"]}},
		"actions": {"origin": Vector2(900, 1340), "anims": ["attack", "charge", "slam", "weak_slam", "hurt", "stagger"], "reach": 24.0,
		"contact_offset": Vector2(-857, -626), "slam_contact": Vector2(-832, -608), "weak_slam_contact": Vector2(-857, -626),
		"attack": [ME31_DIR + "attack_00.png", ME31_DIR + "attack_01.png", ME31_DIR + "attack_02.png", ME31_DIR + "attack_03.png", ME31_DIR + "attack_04.png"], "charge": [ME31_DIR + "charge_00.png", ME31_DIR + "charge_01.png", ME31_DIR + "charge_02.png"], "slam": [ME31_DIR + "slam_00.png", ME31_DIR + "slam_01.png", ME31_DIR + "slam_02.png", ME31_DIR + "slam_03.png", ME31_DIR + "slam_04.png"], "weak_slam": [ME31_DIR + "weak_slam_00.png", ME31_DIR + "weak_slam_01.png", ME31_DIR + "weak_slam_02.png", ME31_DIR + "weak_slam_03.png", ME31_DIR + "weak_slam_04.png"],
		"hurt": [ME31_DIR + "hurt_00.png", ME31_DIR + "hurt_01.png", ME31_DIR + "hurt_02.png"], "stagger": [ME31_DIR + "stagger_00.png", ME31_DIR + "stagger_01.png", ME31_DIR + "stagger_02.png"],
		"attack_s": [0.020, 0.075, 0.050, 0.070, 0.030], "charge_s": [0.020, 0.090, 0.035], "slam_s": [0.020, 0.080, 0.065, 0.085, 0.035],
		"weak_slam_s": [0.020, 0.070, 0.050, 0.075, 0.030], "hurt_s": [0.020, 0.100, 0.040], "stagger_s": [0.020, 0.090, 0.025],
		"hurt_end_idle": true, "rewind": true}},
	"maek_shield_mid": {"body": SB28_DIR + "idle_shielded_00.png", "mask": SB28_DIR + "idle_shielded_mask_00.png", "shader": MAEK_DIR + "maek_idle_flow.gdshader",
		"idle_frames": [SB28_DIR + "idle_shielded_00.png", SB28_DIR + "idle_shielded_01.png", SB28_DIR + "idle_shielded_02.png", SB28_DIR + "idle_shielded_03.png", SB28_DIR + "idle_shielded_04.png", SB28_DIR + "idle_shielded_05.png"], "idle_masks": [SB28_DIR + "idle_shielded_mask_00.png", SB28_DIR + "idle_shielded_mask_01.png", SB28_DIR + "idle_shielded_mask_02.png", SB28_DIR + "idle_shielded_mask_03.png", SB28_DIR + "idle_shielded_mask_04.png", SB28_DIR + "idle_shielded_mask_05.png"], "idle_ms": SB25_IDLE_MS,
		"foot": Vector2(900, 1340), "top": 219.0, "left": 280.0, "right": 1340.0, "body_px": 136.0, "body_ref": 1121.0, "shadow_rx": 42.0,
		"amount": 0.8, "speed": 0.75, "density": 12.0,
		"unshielded": {"idle_frames": [SB28_DIR + "idle_unshielded_00.png", SB28_DIR + "idle_unshielded_01.png", SB28_DIR + "idle_unshielded_02.png", SB28_DIR + "idle_unshielded_03.png", SB28_DIR + "idle_unshielded_04.png", SB28_DIR + "idle_unshielded_05.png"], "idle_masks": [SB28_DIR + "idle_unshielded_mask_00.png", SB28_DIR + "idle_unshielded_mask_01.png", SB28_DIR + "idle_unshielded_mask_02.png", SB28_DIR + "idle_unshielded_mask_03.png", SB28_DIR + "idle_unshielded_mask_04.png", SB28_DIR + "idle_unshielded_mask_05.png"],
			"attack": [SB28_DIR + "attack_unshielded_00.png", SB28_DIR + "attack_unshielded_01.png", SB28_DIR + "attack_unshielded_02.png", SB28_DIR + "attack_unshielded_03.png", SB28_DIR + "attack_unshielded_04.png"], "hurt": [SB28_DIR + "hurt_unshielded_00.png", SB28_DIR + "hurt_unshielded_01.png", SB28_DIR + "hurt_unshielded_02.png"]},
		"actions": {"origin": Vector2(900, 1340), "anims": ["attack", "hurt", "absorb", "loss"], "contact_offset": Vector2(-698, -461), "reach": 32.0,
		"attack": [SB28_DIR + "attack_shielded_00.png", SB28_DIR + "attack_shielded_01.png", SB28_DIR + "attack_shielded_02.png", SB28_DIR + "attack_shielded_03.png", SB28_DIR + "attack_shielded_04.png"], "hurt": [SB28_DIR + "hurt_shielded_00.png", SB28_DIR + "hurt_shielded_01.png", SB28_DIR + "hurt_shielded_02.png"],
		"absorb": [SB28_DIR + "shield_absorb_00.png", SB28_DIR + "shield_absorb_01.png", SB28_DIR + "shield_absorb_02.png"], "loss": [SB28_DIR + "shield_loss_00.png", SB28_DIR + "shield_loss_01.png", SB28_DIR + "shield_loss_02.png", SB28_DIR + "shield_loss_03.png"],
		"attack_s": [0.020, 0.085, 0.055, 0.085, 0.035], "hurt_s": [0.020, 0.100, 0.040], "absorb_s": [0.020, 0.065, 0.025], "loss_s": [0.020, 0.045, 0.045, 0.025]}},
	"maek_shield_early": {"body": SB25_DIR + "idle_shielded_00.png", "mask": SB25_DIR + "idle_shielded_mask_00.png", "shader": MAEK_DIR + "maek_idle_flow.gdshader",
		"idle_frames": [SB25_DIR + "idle_shielded_00.png", SB25_DIR + "idle_shielded_01.png", SB25_DIR + "idle_shielded_02.png", SB25_DIR + "idle_shielded_03.png", SB25_DIR + "idle_shielded_04.png", SB25_DIR + "idle_shielded_05.png"], "idle_masks": [SB25_DIR + "idle_shielded_mask_00.png", SB25_DIR + "idle_shielded_mask_01.png", SB25_DIR + "idle_shielded_mask_02.png", SB25_DIR + "idle_shielded_mask_03.png", SB25_DIR + "idle_shielded_mask_04.png", SB25_DIR + "idle_shielded_mask_05.png"], "idle_ms": SB25_IDLE_MS,
		"foot": Vector2(900, 1340), "top": 313.0, "left": 388.0, "right": 1341.0, "body_px": 136.0, "body_ref": 1027.0, "shadow_rx": 40.0,
		"amount": 0.8, "speed": 0.75, "density": 12.0,
		"unshielded": {"idle_frames": [SB25_DIR + "idle_unshielded_00.png", SB25_DIR + "idle_unshielded_01.png", SB25_DIR + "idle_unshielded_02.png", SB25_DIR + "idle_unshielded_03.png", SB25_DIR + "idle_unshielded_04.png", SB25_DIR + "idle_unshielded_05.png"], "idle_masks": [SB25_DIR + "idle_unshielded_mask_00.png", SB25_DIR + "idle_unshielded_mask_01.png", SB25_DIR + "idle_unshielded_mask_02.png", SB25_DIR + "idle_unshielded_mask_03.png", SB25_DIR + "idle_unshielded_mask_04.png", SB25_DIR + "idle_unshielded_mask_05.png"],
			"attack": [SB25_DIR + "attack_unshielded_00.png", SB25_DIR + "attack_unshielded_01.png", SB25_DIR + "attack_unshielded_02.png", SB25_DIR + "attack_unshielded_03.png", SB25_DIR + "attack_unshielded_04.png"], "hurt": [SB25_DIR + "hurt_unshielded_00.png", SB25_DIR + "hurt_unshielded_01.png", SB25_DIR + "hurt_unshielded_02.png"]},
		"actions": {"origin": Vector2(900, 1340), "anims": ["attack", "hurt", "absorb", "loss"], "contact_offset": Vector2(-666, -498), "reach": 24.0,
		"attack": [SB25_DIR + "attack_shielded_00.png", SB25_DIR + "attack_shielded_01.png", SB25_DIR + "attack_shielded_02.png", SB25_DIR + "attack_shielded_03.png", SB25_DIR + "attack_shielded_04.png"], "hurt": [SB25_DIR + "hurt_shielded_00.png", SB25_DIR + "hurt_shielded_01.png", SB25_DIR + "hurt_shielded_02.png"],
		"absorb": [SB25_DIR + "shield_absorb_00.png", SB25_DIR + "shield_absorb_01.png", SB25_DIR + "shield_absorb_02.png"], "loss": [SB25_DIR + "shield_loss_00.png", SB25_DIR + "shield_loss_01.png", SB25_DIR + "shield_loss_02.png", SB25_DIR + "shield_loss_03.png"],
		"attack_s": [0.020, 0.085, 0.055, 0.085, 0.035], "hurt_s": [0.020, 0.100, 0.040], "absorb_s": [0.020, 0.065, 0.025], "loss_s": [0.020, 0.045, 0.045, 0.025]}},
	"maek_archer_early": {"body": MAEK19_DIR + "early/idle/idle_00.png", "mask": MAEK19_DIR + "early/idle_masks/mask_00.png", "shader": MAEK_DIR + "maek_idle_flow.gdshader",
		"idle_frames": [MAEK19_DIR + "early/idle/idle_00.png", MAEK19_DIR + "early/idle/idle_01.png", MAEK19_DIR + "early/idle/idle_02.png", MAEK19_DIR + "early/idle/idle_03.png", MAEK19_DIR + "early/idle/idle_04.png", MAEK19_DIR + "early/idle/idle_05.png"], "idle_masks": [MAEK19_DIR + "early/idle_masks/mask_00.png", MAEK19_DIR + "early/idle_masks/mask_01.png", MAEK19_DIR + "early/idle_masks/mask_02.png", MAEK19_DIR + "early/idle_masks/mask_03.png", MAEK19_DIR + "early/idle_masks/mask_04.png", MAEK19_DIR + "early/idle_masks/mask_05.png"], "idle_ms": [250, 270, 300, 300, 270, 250],
		"foot": Vector2(900, 1340), "top": 413.0, "left": 309.0, "right": 1202.0, "body_px": 136.0, "body_ref": 927.0, "shadow_rx": 36.0,
		"amount": 0.8, "speed": 0.75, "density": 12.0, "ranged_art": true,
		"actions": {"origin": Vector2(900, 1340), "anims": ["attack", "hurt"], "release_socket": Vector2(-499, -655),
		"attack": [MAEK19_DIR + "early/attack/attack_00.png", MAEK19_DIR + "early/attack/attack_01.png", MAEK19_DIR + "early/attack/attack_02.png", MAEK19_DIR + "early/attack/attack_03.png", MAEK19_DIR + "early/attack/attack_04.png"],
		"hurt": [MAEK19_DIR + "early/hurt/hurt_00.png", MAEK19_DIR + "early/hurt/hurt_01.png", MAEK19_DIR + "early/hurt/hurt_02.png"],
		"attack_s": [0.020, 0.085, 0.055, 0.090, 0.040], "hurt_s": [0.020, 0.100, 0.040]}},
	"maek_archer_mid": {"body": MAEK19_DIR + "mid/idle/idle_00.png", "mask": MAEK19_DIR + "mid/idle_masks/mask_00.png", "shader": MAEK_DIR + "maek_idle_flow.gdshader",
		"idle_frames": [MAEK19_DIR + "mid/idle/idle_00.png", MAEK19_DIR + "mid/idle/idle_01.png", MAEK19_DIR + "mid/idle/idle_02.png", MAEK19_DIR + "mid/idle/idle_03.png", MAEK19_DIR + "mid/idle/idle_04.png", MAEK19_DIR + "mid/idle/idle_05.png"], "idle_masks": [MAEK19_DIR + "mid/idle_masks/mask_00.png", MAEK19_DIR + "mid/idle_masks/mask_01.png", MAEK19_DIR + "mid/idle_masks/mask_02.png", MAEK19_DIR + "mid/idle_masks/mask_03.png", MAEK19_DIR + "mid/idle_masks/mask_04.png", MAEK19_DIR + "mid/idle_masks/mask_05.png"], "idle_ms": [250, 270, 300, 300, 270, 250],
		"foot": Vector2(900, 1340), "top": 349.0, "left": 207.0, "right": 1330.0, "body_px": 136.0, "body_ref": 991.0, "shadow_rx": 36.0,
		"amount": 0.8, "speed": 0.75, "density": 12.0, "ranged_art": true,
		"actions": {"origin": Vector2(900, 1340), "anims": ["attack", "hurt"], "release_socket": Vector2(-572, -708),
		"attack": [MAEK19_DIR + "mid/attack/attack_00.png", MAEK19_DIR + "mid/attack/attack_01.png", MAEK19_DIR + "mid/attack/attack_02.png", MAEK19_DIR + "mid/attack/attack_03.png", MAEK19_DIR + "mid/attack/attack_04.png"],
		"hurt": [MAEK19_DIR + "mid/hurt/hurt_00.png", MAEK19_DIR + "mid/hurt/hurt_01.png", MAEK19_DIR + "mid/hurt/hurt_02.png"],
		"attack_s": [0.020, 0.085, 0.055, 0.090, 0.040], "hurt_s": [0.020, 0.100, 0.040]}},
	"maek_summoner": {"body": MAEK16_DIR + "boss/registered_ready.png", "mask": MAEK16_DIR + "boss/ready_flow_mask.png", "shader": MAEK_DIR + "maek_idle_flow.gdshader",
		"foot": Vector2(1050, 1550), "top": 461.0, "left": 461.0, "right": 1536.0, "body_px": 155.0, "body_ref": 1049.0, "shadow_rx": 50.0,
		"amount": 0.8, "speed": 0.75, "density": 12.0, "actions": SUMMONER_ACTIONS},
	"maek_spawn": {"body": MAEK16_DIR + "minion/primed/primed_00.png", "mask": MAEK16_DIR + "minion/primed_flow_mask.png", "shader": MAEK_DIR + "maek_idle_flow.gdshader",
		"foot": Vector2(700, 650), "top": 231.0, "left": 492.0, "right": 864.0, "body_px": 58.0, "body_ref": 337.0, "shadow_rx": 24.0,
		"amount": 0.8, "speed": 0.75, "density": 12.0, "actions": SPAWN_ACTIONS, "death_sfx": "magic_hit"},
	"maek_early": {"body": MAEK13_EARLY + "maek_early_original.png", "mask": MAEK13_EARLY + "maek_early_flow_mask.png", "shader": MAEK_DIR + "maek_idle_flow.gdshader",
		"foot": Vector2(720, 1146), "top": 264.0, "left": 402.0, "right": 1191.0, "body_px": 136.0, "shadow_rx": 38.0,
		"amount": 0.8, "speed": 0.75, "density": 12.0, "actions": MAEK_EARLY_ACTIONS},
	"maek_upper": {"body": MAEK13_UPPER + "maek_upper_original.png", "mask": MAEK13_UPPER + "maek_upper_flow_mask.png", "shader": MAEK_DIR + "maek_idle_flow.gdshader",
		"foot": Vector2(733, 1186), "top": 117.0, "left": 133.0, "right": 1176.0, "body_px": 136.0, "shadow_rx": 44.0,
		"amount": 0.8, "speed": 0.75, "density": 12.0, "actions": MAEK_UPPER_ACTIONS},
	"maek_mid": {"body": MAEK_DIR + "maek_mid_original.png", "mask": MAEK_DIR + "maek_mid_flow_mask.png", "shader": MAEK_DIR + "maek_idle_flow.gdshader",
		"foot": Vector2(620, 1190), "top": 107.0, "left": 190.0, "right": 1233.0, "body_px": 136.0, "shadow_rx": 40.0,
		"amount": 0.8, "speed": 0.75, "density": 12.0, "actions": MAEK_ACTIONS},
}
const ENEMY_ART_PICKS := [{"source": "expedition", "encounter": "n1", "role": "scout", "index": 0, "art": "maek_early", "sector": "normal"},
	{"source": "expedition", "encounter": "n1", "role": "scout", "index": 1, "art": "maek_early", "sector": "normal"},
	{"source": "expedition", "encounter": "n3", "role": "scout", "index": 1, "art": "maek_early", "sector": "normal"},
	{"source": "expedition", "encounter": "n3", "role": "banner", "index": 0, "art": "maek_support_early", "sector": "normal"},
	{"source": "expedition", "encounter": "n4", "role": "hexer", "index": 0, "art": "maek_hexer_early", "sector": "normal"},
	{"source": "expedition", "encounter": "x1", "role": "guard_h", "index": 1, "art": "maek_upper"},
	{"source": "expedition", "encounter": "boss", "role": "maek_summoner_low", "index": 0, "art": "maek_summoner"},
	{"source": "expedition", "encounter": "boss", "role": "maek_spawn_low", "index": 1, "art": "maek_spawn"},
	{"source": "expedition", "encounter": "boss", "role": "maek_spawn_low", "index": 2, "art": "maek_spawn"},
	{"source": "expedition", "encounter": "n2", "role": "archer", "index": 1, "art": "maek_archer_early", "sector": "normal"},
	{"source": "expedition", "encounter": "elite", "role": "archer", "index": 1, "art": "maek_archer_early", "sector": "normal"},
	{"source": "expedition", "encounter": "n2", "role": "shieldbearer", "index": 0, "art": "maek_shield_early", "sector": "normal"},
	{"source": "expedition", "encounter": "h1a", "role": "shieldbearer", "index": 0, "art": "maek_shield_mid", "sector": "hard"},
	{"source": "expedition", "encounter": "elite", "role": "maek_elite_low", "index": 0, "art": "maek_elite_low", "sector": "normal"},
	{"source": "expedition", "encounter": "hboss", "role": "maek_noble_mid", "index": 0, "art": "maek_noble_mid", "sector": "hard"}]
# 준비된 표현 샘플 전용(점검 드라이버가 그 프로세스에서만 채움): 역할 → 그림. 보통 게임에서는 비어 있어 캠페인 배치가 바뀌지 않는다
static var sample_art := {}
# SD 전투 그림(기본, --old-art이면 예전 그림): assets/sd_combat/<id>/manifest.json을 읽어 만든 그림 표. 열쇠는 "sd:<id>". 그림이 없는 배우는 예전 그림
const SD_DIR := "res://assets/sd_combat/"
# 원정 하층에서 SD 그림으로 바꿀 역할 → SD 배우 id. 그림이 오는 대로 더한다
const SD_ROLES := {"scout": "scout_low"}
static var sd_art := {}


static func sd_on() -> bool:
	return not "--old-art" in OS.get_cmdline_user_args()


# 전투 손맛(기본): 패링 원 · 긋기 베기 · 연출. --classic-combat이면 예전 방식, --no-parry / --no-slash / --no-juice로 하나씩 끈다.
# 점검 드라이버는 feel_force로 정한다(적힌 것만 켜짐)
static var feel_force := {}


static func feel_on(part: String) -> bool:
	if not feel_force.is_empty():
		return bool(feel_force.get(part, false))
	var args := OS.get_cmdline_user_args()
	return not "--classic-combat" in args and not ("--no-" + part) in args


static func _sd_manifest(id: String) -> Dictionary:
	var path := SD_DIR + id + "/manifest.json"
	if not FileAccess.file_exists(path):
		return {}
	var m = JSON.parse_string(FileAccess.get_file_as_string(path))
	return m if m is Dictionary else {}


func _ea(key: String) -> Dictionary:
	return sd_art[key] if sd_art.has(key) else ENEMY_ART[key]


func _ea_or(key: String) -> Dictionary:
	return sd_art.get(key, ENEMY_ART.get(key, {}))


# SD 적: 게임 크기로 줄인 그림(몸 높이가 이미 화면 px)이라 배율은 수로 배치에서 1이 되게 body_px를 136 기준으로 적는다
func _sd_enemy_key(id: String) -> String:
	var key := "sd:" + id
	if sd_art.has(key):
		return key
	var m := _sd_manifest(id)
	if m.is_empty():
		return ""
	var dir := SD_DIR + id + "/"
	var foot := Vector2(float(m.foot[0]), float(m.foot[1]))
	var body := float(m.body)
	var idle: Dictionary = m.anims.idle
	var frames: Array = []
	var masks: Array = []
	for i in range((idle.ms as Array).size()):
		frames.append(dir + "idle/idle_%02d.png" % i)
		masks.append(dir + "idle/mask_%02d.png" % i)
	sd_art[key] = {"body": frames[0], "mask": masks[0], "shader": MAEK_DIR + "maek_idle_flow.gdshader",
		"idle_frames": frames, "idle_masks": masks, "idle_ms": idle.ms,
		"foot": foot, "top": foot.y - body, "left": foot.x + float(m.left), "right": foot.x + float(m.right),
		"body_px": 136.0 * body / ENV_BODY_H, "body_ref": body, "shadow_rx": 36.0, "amount": 0.8, "speed": 0.75, "density": 12.0}
	return key


# SD 주인공: 직업 코드가 부르는 동작 이름은 모두 있어야 한다. 아직 그림이 없는 동작은 가장 가까운 그림(베기 → 대기)을 빌린다
func _sd_player_art(cls: String) -> Dictionary:
	var m := _sd_manifest(cls)
	if m.is_empty():
		return {}
	var base: Dictionary = ACTOR_ART[cls]
	var have: Dictionary = m.anims
	var anims := {}
	var contact := {}
	var sockets := {}
	var tip := Vector2(float(m.tip[0]), float(m.tip[1])) if m.has("tip") else WARDEN_TIP
	for anim in base.anims:
		var src := String(anim) if have.has(anim) else ("slash" if have.has("slash") and anim != "idle" and anim != "death" else "idle")
		var times: Array = have[src].ms
		anims[anim] = [times, bool(have[src].loop) and anim == "idle", SD_DIR + cls + "/", src]
		contact[anim] = mini(int(have[src].get("contact", (base.contact as Dictionary).get(anim, 0))), times.size() - 1)
		var tb := {}
		for i in range(times.size()):
			tb[i] = tip
		sockets[anim] = tb
	var body := float(m.body)
	return {"sd": true, "dir": SD_DIR + cls + "/", "foot": Vector2(float(m.foot[0]), float(m.foot[1])), "body_px": body, "nearest": false,
		"anims": anims, "contact": contact, "sockets": sockets, "tip": tip, "stance_x": 0.0, "head_y": -body,
		"shadow_w": base.shadow_w, "body_l": -0.28 * body, "body_r": 0.3 * body}
# 소환사 전투 자리: 소환사는 뒤(오른쪽), 소환수 둘은 앞. 예고 칸(160px)이 겹치지 않게 간격을 둔다 (규칙 순서는 그대로 0 → 1 → 2)
const SUMMONER_SLOTS := [1080.0, 720.0, 885.0]
# 이만큼 넘는 한 방은 처치가 아니어도 흑백 순간(행동당 한 번)
const BIG_IMPACT := 20
const FEET_Y := 366.0
const PLAYER_X := 330.0
const ENEMY_SLOTS := {1: [900.0], 2: [860.0, 1080.0], 3: [780.0, 945.0, 1110.0]}
# 화면 틀 (1280×720): 위쪽은 주인공(유물 포함)·전투 배너·메뉴, 가운데는 인물과 적 정보 칸, 아래는 부채꼴 손패.
# 인물 발밑(366)과 대상 타원(376)을 올린 카드 윗변(377)보다 위에 두어, 고르거나 끄는 카드는 늘 온전히 보이고 몸·예고를 가리지 않는다.
# 쉬는 카드는 원본 카드 틀 2배(136×218), 올린 카드는 3배(204×327).
# 손패 입력은 _hand_hit 하나가 받는다: 쉬는 카드 모양으로 가장 가까운 카드를 고르고(겹침에서 깜빡이지 않게),
# 누른 채 8px 넘게 움직이면 끌기, 그 전에 놓으면 기존 클릭. 끌기는 놓는 순간 한 번만 기존 play_card로 보낸다.
const PLAYER_MODULE := Rect2(20, 16, 300, 164)
const TURN_BANNER := Rect2(520, 10, 240, 64)
const MENU_RECT := Rect2(1210, 28, 48, 48)
const ENEMY_W := 160.0
const ENEMY_STACK := 166.0
const HP_W := 150.0
const MARK_W := 24.0
const PRED_Y := 96.0
const PRED_TEXT_W := 140.0
const MANA_ORB := Vector2(12, 470)
const SHINE := preload("res://p2/p2_card_shine.gdshader")
const PILES_Y := 626.0
const HAND_LEFT := 190.0
const HAND_RIGHT := 1066.0
const REST := Vector2(168, 264)
const BIG := Vector2(224, 352)
const REST_TOP := 512.0
const BIG_BOTTOM := 704.0
const HAND_Y := REST_TOP
const HAND_HIT_TOP := 440.0
const HINT_RECT := Rect2(16, 54, 330, 0)
const DRAG_THRESHOLD := 8.0
const SELF_ZONE := Rect2(176, 182, 300, 196)
const ALL_ZONE := Rect2(660, 90, 600, 290)
# 안내·예상 칸 글자색. 칸이 어두운 돌 틀이라 밝은 색 (예전 양피지 칸의 어두운 잉크색 자리)
const C_INK := Color("#e8dcc4")
const F := 16

const VFX := {
	"slash": ["res://assets/vfx/Free/Part 6/283.png", 5, 9, 36.0],
	"slash_major": ["res://assets/vfx/Free/Part 6/283.png", 4, 9, 30.0],
	"magic": ["res://assets/vfx/Free/Part 14/652.png", 2, 16, 44.0],
	"detonate": ["res://assets/vfx/Free/Part 14/652.png", 2, 16, 38.0],
	"crit": ["res://assets/vfx/Free/Part 14/652.png", 0, 16, 44.0],
	"burst": ["res://assets/vfx/Free/Part 14/652.png", 0, 16, 40.0],
	"guard": ["res://assets/vfx/Free/Part 10/475.png", 5, 12, 30.0],
	"counter": ["res://assets/vfx/Free/Part 5/232.png", 5, 9, 32.0],
	"thorn": ["res://assets/vfx/Free/Part 5/222.png", 4, 9, 45.0],
	"charge": ["res://assets/vfx/Free/Part 3/123.png", 1, 12, 60.0],
	"arc": ["res://assets/vfx/Free/Part 11/507.png", 2, 12, 44.0],
	"prepare": ["res://assets/vfx/Free/Part 3/123.png", 4, 12, 40.0],
	"enemy_ORC": ["res://assets/vfx/Free/Part 1/06.png", 7, 15, 34.0],
	"enemy_SKELETON": ["res://assets/vfx/Free/Part 4/195.png", 5, 14, 34.0],
	"enemy_RUINS_BOSS": ["res://assets/vfx/Free/Part 1/06.png", 3, 15, 30.0],
	"enemy_MUMMY": ["res://assets/vfx/Free/Part 1/06.png", 3, 15, 30.0],
}

const SFX_DIR := "res://assets/sfx/400 Sounds pack/"
# [파일, 기본 dB, 시작 지점(초)]. 시작 지점은 앞쪽 무음을 건너뛰어 맞는 순간과 소리가 겹치게 한다.
# 계열: 물리 = 건조한 금속(sword_light) · 강화/치명은 몸통(punch_3)을 더함 · 마법 = 짧은 레트로 타격 + 유리 울림
const SFX := {
	"select": ["UI/select_2.wav", -13.0],
	"cancel": ["UI/click_double_off.wav", -15.0],
	"deny": ["UI/sci_fi_disallow.wav", -14.0],
	"draw": ["Card and Board/card_draw_1.wav", -17.0],
	"play": ["Card and Board/card_fan.wav", -16.0],
	"swing": ["Other/whoosh_1.wav", -15.0, 0.03],
	"sword_hit": ["Weapons/sword_light.wav", -12.0],
	"slash_major": ["Weapons/sword_slice.wav", -12.0, 0.09],
	"weight": ["Weapons/harsh_thud.wav", -18.0, 0.01],
	"body": ["Combat and Gore/punch_3.wav", -13.0],
	"burst": ["Retro/explosion_small.wav", -12.0],
	"shatter": ["Materials/glass_ping_big.wav", -20.0, 0.04],
	"cast": ["Retro/power_up.wav", -21.0],
	"magic_hit": ["Retro/explosion_quick.wav", -13.0],
	"mark": ["Materials/glass_ping_small.wav", -18.0, 0.02],
	"arc": ["Retro/power_up.wav", -15.0],
	"guard": ["Weapons/weapon_equip_short.wav", -10.0, 0.02],
	"block": ["Weapons/sword_clash.wav", -11.0, 0.05],
	"counter": ["Weapons/sword_light.wav", -9.0],
	"thorn": ["Weapons/sword_light.wav", -11.0],
	"hurt": ["Combat and Gore/punch_2.wav", -8.0, 0.02],
	"enemy_swing": ["Combat and Gore/swipe.wav", -12.0, 0.06],
	"arrow": ["Weapons/shot_muffled.wav", -10.0],
	"prepare": ["Weapons/sword_sharpen.wav", -16.0, 0.1],
	"death_ORC": ["Combat and Gore/crunch_quick.wav", -10.0, 0.03],
	"death_SKELETON": ["Combat and Gore/bone_snap.wav", -10.0],
	"death_RUINS_BOSS": ["Retro/explosion_medium.wav", -8.0],
	"death_MUMMY": ["Combat and Gore/crunch_quick.wav", -10.0, 0.03],
	"heal": ["Musical Effects/vibraphone_chime_quick.wav", -10.0],
	"victory": ["Musical Effects/xylophone_level_complete.wav", -10.0],
	"defeat": ["Musical Effects/8_bit_defeated.wav", -10.0],
	"bash": ["Weapons/harsh_thud.wav", -8.0, 0.01],
	"suppress": ["Retro/power_down.wav", -14.0],
	"echo": ["Musical Effects/vibraphone_chime_positive.wav", -13.0],
	"weaken": ["Retro/power_down.wav", -10.0],
	"lock": ["Weapons/sword_sharpen.wav", -12.0, 0.1],
	"crit": ["Weapons/sword_clash_2.wav", -12.0, 0.03],
	"crit_ring": ["Materials/metal_clang.wav", -21.0, 0.02],
	"crit_ready": ["Weapons/weapon_upgrade.wav", -11.0, 0.06],
	"bow": ["Other/elastic_twang.wav", -11.0, 0.02],
	"mana": ["Retro/coin_2.wav", -15.0],
	"exhaust": ["Other/light_match.wav", -9.0],
	"furnace": ["Retro/explosion_small.wav", -11.0],
	"brace": ["Weapons/weapon_equip.wav", -12.0, 0.13],
	"staff": ["Retro/power_up_2.wav", -18.0],
	"fire": ["Environment/fire_lighting.wav", -9.0],
	"boom_l": ["Retro/explosion_large.wav", -8.0],
	"boom_m": ["Retro/explosion_medium.wav", -9.0],
	"ice": ["Environment/ice_in_water.wav", -8.0],
	"glass": ["Materials/glass_ping_big.wav", -11.0, 0.04],
	"crunch": ["Combat and Gore/crunch.wav", -8.0],
	"crack": ["Combat and Gore/bone_snap.wav", -7.0],
	"wind": ["Environment/air_burst.wav", -8.0],
	"whoosh": ["Other/whoosh_2.wav", -9.0],
	"gurgle": ["Environment/gurgling.wav", -11.0],
	"ghost": ["Other/ghost_long.wav", -11.0],
	"spook": ["Retro/ghost.wav", -11.0],
	"charge": ["Retro/grow_big.wav", -11.0],
	"power": ["Retro/power_up_2.wav", -9.0],
	"clang": ["Materials/metal_clang.wav", -9.0, 0.02],
	"snap": ["Other/snap.wav", -7.0],
	"punch": ["Combat and Gore/punch.wav", -8.0],
	"kick": ["Combat and Gore/kick.wav", -8.0],
	"static": ["Other/white_noise_short.wav", -17.0],
	"mystery": ["Musical Effects/brass_mystery.wav", -9.0],
	"slurp": ["Other/drink_slurp.wav", -11.0],
	"splash": ["Environment/water_splashing.wav", -11.0],
}
const FX_BUS := "P5Fx"
# 생성 부품: 1254×1254 정지 그림에서 실제 실루엣만 잘라 쓴다 (원본은 그대로, 최근접 표본, 밉맵 없음)
const ARCANE_DIR := "res://assets/orsia_generated/av1/"
const ARCANE := {
	"core": ["orsia_arcane_core_v1.png", Rect2(321, 269, 667, 717)],
	"sigil": ["orsia_arcane_sigil_v1.png", Rect2(90, 84, 1075, 1072)],
	"mark": ["orsia_arcane_mark_v1.png", Rect2(178, 282, 898, 691)],
}
const C_ARCANE := Color("#5fd8cf")
const C_IVORY := Color("#fff0ca")
const C_CRIT := Color("#ffcf4a")
const C_FIRE := Color("#ff9a4a")

const C_TEXT := Color("#f3ead7")
const C_DIM := Color("#b3a58c")
const C_HP := Color("#d8483e")
const C_BLOCK := Color("#8fc3e8")
const C_MARK := Color("#7fe6dc")
const C_GOLD := Color("#f2c461")
const C_PANEL := Color(0.08, 0.06, 0.05, 0.86)
# 피해 숫자 [글자, 테두리·그림자]. 속성이 늘면 한 줄씩
const DMG_TONE := {
	"phys": [Color("#fff1d6"), Color("#3b1d10")],
	"magic": [Color("#8ff3ff"), Color("#0c2c52")],
	"mark": [Color("#7fe6dc"), Color("#0b3a36")],
	"fire": [Color("#ffb04a"), Color("#4a1406")],
	"poison": [Color("#9cf06a"), Color("#173a0c")],
	"crit": [Color("#ffe04a"), Color("#8a1c0c")],
	"hurt": [Color("#ff5a48"), Color("#2c0606")],
	"zero": [Color("#b3a58c"), Color("#1a1410")],
}
const DMG_BIG := 10
const DMG_TONE_OF := {"furnace": "fire", "arc": "magic", "echo": "magic", "echo_string": "magic", "transfer": "magic", "mark_chain": "mark"}

enum UI { BANNER, PLAYER, BUSY, ENEMY, OVER, MULLIGAN, FUEL }

var model: RunModel
var battle: P2Battle
var gate: P2Ui.SaveGate
var enc_id := ""
# 도전 상태는 패배 확정 순간 비워지므로, 전투 화면이 쓰는 값은 시작할 때 보관한다
var _run_info := {}
var _state := UI.BUSY
var _selected: Card = null
var _target := -1
var _reduce_motion := false
var _env: Node2D
var _env_clock := 0.0
var _home_x := PLAYER_X
var _body_h := WARDEN_SCREEN_H
var _ks := 1.0
var _shaded: Array = []
static var _uitex := {}
var _ui_clock := 0.0
var _mana_level := -1.0
var _mana_tilt := 0.0
var _mana_tw: Tween
var _mana_water: TextureRect
var _mana_pred: Label
var _mana_tick: TextureRect
var _block_icon: TextureRect
var _top_labels := {}
var _turn_marks: Array = []
var _hand_rail: NinePatchRect
var _timings: Array[Dictionary] = []
var _vfx_frames := {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_next := 0
var _sfx_last := {}
var _sfx_streams := {}
var _arcane_tex := {}
var _crescent_frames := {}
var _cam: Camera2D
var _cam_tw: Tween
var _cam_rank := 0
var _cam_until := 0
var _dim: ColorRect
var _fx_back: Node2D
# 선·조각·장막 같은 코드로 그린 효과는 픽셀 층에(무대 _fx 아래 · 화면 _ui 맨 위). 그림 효과(스프라이트)는 그대로 _fx
var _fxp: P2Pixel
var _fxpa: P2Pixel
var _fxbp: P2Pixel
var _fxba: P2Pixel
var _uipx: P2Pixel
var _uipa: P2Pixel
const FX_PIX := 3
const FX_PEN := preload("res://p2/p2_pixel_fx.gdshader")
const FX_PEN_ADD := preload("res://p2/p2_pixel_add.gdshader")
var _uip: P2Pixel
# 분위기 입자 · 심층 횃불 빛 · 배경 숨쉬기(정수 px, 시차만) · 심장 박동 시계 · 연속 금빛 테두리 · 마지막 일격(한 전투에 한 번)
var _amb: P2Ambience
var _torches: Array = []
var _bg_node: Node2D
var _breath := Vector2.ZERO
var _breath_t := 0.0
var _heart_t := 0.0
var _heart_beat := -1
var _edge: ColorRect
var _final_done := false
# 리듬 설정의 키 지정: 다음 두 키(Esc 취소 · F키·Tab·조합키 제외)를 누르기 키로
var _key_capture: Array = []
var _key_capture_on := false
var _key_capture_labels: Array = []
var final_log: Array = []
var _new_fx := true
var _av7_layer: CanvasLayer
var _av7_rect: ColorRect
var _av7_mat: ShaderMaterial
var _av7_lines: Node2D
var _av7_tw: Tween
var _av7_fx := {"center": Vector2(640, 360), "sharp_a": Vector2(-9999, -9999), "sharp_b": Vector2(-9999, -9999), "ring_r": 0.0, "ring_amp": 0.0, "blur_px": 0.0, "chroma_px": 0.0}
var _av7_mono: Node2D
var _av7_lights: Array = []
var _av7_payoff_token := -1
var _av7_sil_shader: Shader
var av7_log: Array = []
var _action_token := 0
var _trail_cut := false
var _flash_shader: Shader
var _t_play := 0
var _t_ack := -1.0
var _t_commit := -1.0
var _t_contact := -1.0
var _av5_frames := {}
var _av5_weapon := {}
var _blade_tier := ""
var _blade_trail: Sprite2D
var _blade_edge: Sprite2D
var _raven: Texture2D
var _mull_pick: Array = []
var _fuel_pick := ""
var _weapon: Sprite2D
var _crit_glow: Sprite2D
var _hires := false
var _dressed := false
var _art := {}
var _player_down := false
var _recoil: Tween
var _prep_label: Label
var _cancel_button: Button

# 표시 상태: 화면은 이것만 그린다
var _shown := {}
var _bar_tweens := {}
var _display_log: Array = []
var reconcile_fixes := 0
var pred_overflow: Array[String] = []
var sfx_log: Array = []
var crescent_log: Array = []
var cast_log: Array = []
var contact_log: Array = []
var camera_log: Array = []
var react_log: Array = []
var art_log: Array = []
var enemy_action_log: Array = []
var route_log: Array = []
var summon_log: Array = []
var arrow_log: Array = []
var shield_log: Array = []
var steady_log: Array = []
var lance_log: Array = []
var _summon_explained := false
var melee_log: Array = []
var pass_log: Array = []
var _pass := {}
var _pass_gen := 0
var vfx_log: Array = []
var blade_log: Array = []
var _float_slots: Array = []
var commit_holds := 0

var _stage: Node2D
var _actors: Node2D
var _fx: Node2D
var _player: AnimatedSprite2D
var _enemy_sprites: Array[AnimatedSprite2D] = []
var _ui: Control
var _hud_hp_bar: ProgressBar
var _hud_hp_label: Label
var _hud_block: Label
var _hud_title: Label
var _hud_piles: Label
var _hud_relics: HBoxContainer
var _trait_icon: TextureRect
var _trait_count: Label
var _player_badge: Label
var _enemy_panels: Array[Dictionary] = []
var _panels_root: Control
var _hand_root: Control
var _art_cid := ""
var _fold_tw: Tween
var _card_views := {}
var _guide: Label
var _end_button: Button
var _use_button: Button
var _mull_button: Button
var _retreat_button: Button
var _potion_button: Button
var _mana_potion_button: Button
var _overlay: Control
var _banner: Label
var _numbers: Control
var _dmg_side := 1.0
# 손맛 시험판: 악보 등급별 고리 시간·노트 자리(칼 부딪히는 자리 기준 가운데 + 둘레 여섯, 서로 74px), 슬로모션 배속,
# 이번 카드의 긋기 결과(맞는 순간 그 선으로 베인 자국), 판정 기록(점검용)
const PARRY_BPM := [112, 124, 136, 148]
const NOTE_R := 44.0
const CELL := Vector2(115, 95)
# 보스·정예 고유 공격 문장: [종류, 열(-2..2), 행(-1..1), 앞 노트와 반 박 간격]. split = 첫 타격에 속하는 노트 수(여러 타격 공격),
# var = 세 번째부터 바뀌는 동작 {노트 번호: [종류, 열, 행]}. 처음 두 번은 같은 문장으로 익히고, 그다음 한 군데가 바뀐다
const MIMIC_PHRASES := {
	2: {"name": "덥석", "notes": [["f", -1, 0, 0], ["t", 1, 0, 2], ["f", 0, -1, 2], ["t", 0, 1, 2]], "split": 2, "var": {2: ["x", 0, -1]}},
	1: {"name": "통째로", "notes": [["t", -1, 1, 0], ["t", 0, 0, 1], ["t", 1, -1, 1], ["d", 2, 0, 2]], "var": {1: ["f", 0, 0]}},
}
const PHRASES := {
	"maek_elite_low": {
		2: {"name": "쿵쿵", "notes": [["t", -2, 0, 0], ["t", -1, 0, 1], ["t", 1, 0, 3], ["t", 2, 0, 1]], "split": 2, "var": {3: ["d", 2, -1]}},
		1: {"name": "내려찍기", "notes": [["t", 0, 1, 0], ["t", 0, 0, 2], ["t", 0, -1, 2], ["h", 1, -1, 3]], "var": {2: ["x", 0, -1]}},
	},
	"maek_summoner_low": {
		1: {"name": "주문", "notes": [["t", -1, -1, 0], ["t", 1, -1, 2], ["t", 1, 1, 2], ["t", -1, 1, 2]], "var": {3: ["d", -1, 1]}},
	},
	"maek_noble_mid": {
		1: {"name": "물창", "notes": [["t", 2, -1, 0], ["t", 1, -1, 1], ["t", 0, -1, 1], ["s", 1, 0, 2], ["h", -1, 1, 2]], "var": {2: ["x", 0, -1]}},
	},
	"x_boss": {
		2: {"name": "균열", "notes": [["d", -2, -1, 0], ["t", -1, 0, 1], ["t", 0, 1, 1], ["f", 2, -1, 2], ["d", 1, 0, 2], ["t", 0, -1, 1]], "split": 3, "var": {4: ["x", 1, 0]}},
		1: {"name": "붕괴", "notes": [["t", -2, 1, 0], ["t", 2, 1, 1], ["t", -2, -1, 1], ["t", 2, -1, 1], ["s", 0, 0, 2], ["h", 0, 1, 3]], "var": {3: ["f", 2, -1]}},
	},
	"leader": {
		2: {"name": "돌파", "notes": [["t", -1, 0, 0], ["t", 0, 0, 1], ["d", 1, -1, 2], ["t", 2, 0, 1]], "split": 2, "var": {1: ["x", 0, 0]}},
		1: {"name": "돌격", "notes": [["t", 2, 0, 0], ["t", 1, 0, 1], ["t", 0, 0, 1], ["h", -1, 0, 1]], "var": {2: ["d", 0, 0]}},
	},
	"ruins_boss": {
		2: {"name": "맥동", "notes": [["s", -1, -1, 0], ["t", 1, 1, 3], ["f", 1, -1, 2], ["t", -1, 1, 2]], "split": 2, "var": {3: ["d", -1, 1]}},
		1: {"name": "폭주", "notes": [["d", 0, 0, 0], ["t", -2, 0, 2], ["t", 2, 0, 1], ["f", 0, -1, 2], ["h", 0, 1, 2]], "var": {1: ["x", -2, 0]}},
	},
	"mimic_n": MIMIC_PHRASES, "mimic_h": MIMIC_PHRASES, "mimic_x": MIMIC_PHRASES,
}
# 적마다 고유 노트(첫 노트는 늘 맨 앞 종류). t 짧은 · h 롱 · d 두 번 · s 따라가기 · f 도망 · x 페인트. 없으면 짧은 노트만
const NOTE_POOL := {
	"scout": ["t"], "scout_h": ["t", "d"], "archer": ["d"], "archer_h": ["d", "t"], "shieldbearer": ["h", "t"],
	"banner": ["t", "x"], "hexer": ["f", "t"], "poisoner": ["s", "t"], "breaker": ["h", "t"], "guard_h": ["h", "s", "t"],
	"elite": ["t", "s", "d"], "maek_elite_low": ["t", "s", "d", "x"], "leader": ["s", "d", "x", "t"], "cannon": ["d"],
	"boss": ["d", "s", "x", "f"], "maek_summoner_low": ["f", "d", "s", "x"], "maek_noble_mid": ["s", "f", "x", "d"],
	"hard_boss": ["d", "s", "f", "x"], "x_boss": ["d", "s", "f", "x"], "ruins_boss": ["d", "s", "f", "x"],
	"mimic_n": ["f", "t"], "mimic_h": ["f", "d"], "mimic_x": ["f", "d", "x"],
}
const NOTE_HINT := {"bomb": "깜빡이는 주황 테 = 소환수 폭발\n제때 누르면 막음\n먼저 처치하면 안 터짐",
	"arrow": "화살이 오는 쪽으로\n마우스를 옮겨 방패 돌리기\n(방향키·WASD도 됨)",
	"rev": "노란 화살은 가까이 와서\n반대쪽으로 넘어옴",
	"drum": "북이 왼쪽 원에 닿을 때\n빨강 = 왼쪽 클릭\n파랑 = 오른쪽 클릭",
	"roll": "노란 띠 = 연타\n띠가 지나는 동안 여러 번",
	"dodge": "붉은 칸이 박자에 맞춰 터짐\n숫자 = 남은 박자\n마우스로 심장을 다른 칸에",
	"chase": "보라 칸 = 나를 노림\n한 박 전에 고정되면 옮기기",
	"echo": "적이 먼저 친 박자를\n노트 없이 그대로 따라 치기\n(클릭 · 아무 키)",
	"h": "주황 네모 = 길게\n누른 채 테두리가 찰 때까지",
	"d": "분홍 겹원 = 두 번\n닿을 때 누르고 곧바로 한 번 더",
	"s": "초록 세모 = 따라가기\n누른 채 세모 공을 따라가기",
	"f": "보라 마름모 = 도망\n다가가면 달아남, 끝에 잡기",
	"x": "빨강 X = 페인트\n누르지 말고 참기",
	"crush": "검붉은 테 = 강타\n완벽해도 절반만 막힘\n나머지는 방어로"}
const PARRY_SPOTS := [Vector2(0, 0), Vector2(74, 0), Vector2(37, 64), Vector2(-37, 64), Vector2(-74, 0), Vector2(-37, -64), Vector2(37, -64)]
const SLOW_SPEED := 0.25
var _juice := false
var _world_speed := 1.0
var _slow_tw: Tween
var _slow_keep: Array = []
var _slowed: Array = []
var _stop_bonus := 0.0
var _cut_rect: ColorRect
var _cut_mat: ShaderMaterial
var _wave_rect: ColorRect
var _wave_mat: ShaderMaterial
var _waves: Array = []
var skill_log: Array = []
var wave_log: Array = []
var _show: P2BattleShow
var _crit_label_token := -1
var _cur_kind := ""
var _cur_magic := false
var _barrier: P2Barrier
var _seen_notes := {}
var _phrase_seen := {}
var _beat: P2Beat
# 세계 음악(박자 시계). 구운 세계의 적만 나오는 전투에서만 켜지고, 아니면 예전처럼 배경음악 + 박자 반주
var _music: P2Music
# 카메라 = 기본(긴장 줌·쏠림) + 흔들림. 흔들림·새 연출은 _cam_raw만 움직이고 기본 위에 얹힌다
var _cam_raw_off := Vector2.ZERO
var _cam_raw_z := 1.0
var _cam_base_off := Vector2.ZERO
var _cam_base_z := 1.0
var _tension_tw: Tween
var _vignette: ColorRect
var _vig := {"dark": 0.0, "pulse": 0.0, "danger": 0.0}
var _drag_ghost: Control
var _aim_fx: P2AimArrow
var _incoming: Control
var _miss_kind := {}
var _hint_again := {}
var _combo: P2Combo
var _pp_sq := Vector2.ONE
var _pp_tilt := 0.0
var _pp_tw: Tween
var _pp_clock := 0.0
var _pp_base := Vector2.ZERO
var _pp_pulse := 0.0
var _beat_n := 0
static var result_hold := 8.0
static var ease_force := -1.0
static var recent_offsets: Array = []
var _approach_k := 1.0
var _rs := {"p": 0, "g": 0, "m": 0, "sl": {"perfect": 0, "hit": 0, "part": 0, "graze": 0}, "offs": [], "streak": 0, "best": 0}
var _result_open := false
var _keys: P2KeyOverlay
var _hitbar: P2HitBar
var _rhythm_open := 0
var _duck_lp: AudioEffectLowPassFilter
var _duck_amp: AudioEffectAmplify
var _duck_tw: Tween
const VIGNETTE := """shader_type canvas_item;
uniform float dark = 0.0;
uniform float danger = 0.0;
void fragment() {
	vec2 d = UV - vec2(0.5);
	d.x *= 1.7;
	float e = smoothstep(0.32, 0.95, length(d));
	float a = clamp(dark + danger, 0.0, 1.0);
	COLOR = vec4(mix(vec3(0.0), vec3(0.6, 0.03, 0.02), danger / max(dark + danger, 0.001)), e * a);
}
"""
var _slash_trace := {}
var _feel_rng := RandomNumberGenerator.new()
var parry_log: Array = []
var slash_log: Array = []
var _debug: Label
var _hand_hit: Control
var _big_root: Control
var _big: Control
var _big_card: Card
var _hover: Card
var _press := {}
var _drag := {}
var _aim_root: Control
var _zone_self: Panel
var _drop_line: Control
var _zone_all: Panel
var _mana_label: Label
var gesture_log: Array = []
var _prompt_box: NinePatchRect
var _prompt_label: Label
var _prompt_close: Button
var _prompt_text := ""
var _notice_until := 0
var _seal_label: Label
var _class_label: Label
var _portrait_button: Button
var _portrait: TextureRect
var _turn_banner: Control
var _hud_phase: Label
var _menu_button: Button
var _menu: Control
var _info: Control
var _mana_frame: TextureRect
var _mana_clip: Control
var _mana_fill: TextureRect
var _pile_tiles: Array = []
var _player_status: HBoxContainer
var _player_pred: NinePatchRect


func setup(m: RunModel, b: P2Battle, g: P2Ui.SaveGate = null) -> void:
	P2Catalog.view_stats = b.stats
	model = m
	battle = b
	gate = g
	if gate != null:
		gate.opened.connect(func() -> void:
			_cancel_gesture("gate")
			_camera_neutral())
	enc_id = b.encounter_id
	b.parry_mode = feel_on("parry")
	_juice = feel_on("juice")
	if feel_on("parry") or feel_on("slash"):
		_beat = P2Beat.new()
		add_child(_beat)
	var rh := P2Ui.load_rhythm()
	P2NoteChart.offset = clampf(float(rh.offset_ms) / 1000.0, -0.08, 0.08)
	P2NoteChart.hit_keys = P2Ui.hit_keys_of(String(rh.keys))
	_approach_k = clampf(float(rh.approach), 0.7, 1.4)
	P2Beat.gain = clampf(float(rh.beat), 0.0, 1.0)
	_feel_rng.randomize()
	_run_info = m.battle_info()
	# 움직임 연출과 새 전투 연출은 늘 켠다(끄는 설정 없음)
	_reduce_motion = false
	_new_fx = true
	add_to_group("battle_box")
	_raven = load(P2Catalog.RAVEN)
	_ensure_fx_bus()
	for i in range(10):
		var p := AudioStreamPlayer.new()
		p.bus = FX_BUS
		add_child(p)
		_sfx_players.append(p)
	_preload_feedback_assets()
	_build_stage()
	_build_ui()
	_show = P2BattleShow.new()
	add_child(_show)
	_show.setup(self)
	var sector := String(_run_info.get("sector", "normal"))
	if feel_on("parry") and not b.mods.has("dt") and P2Music.supports(b.roles, sector):
		_music = P2Music.new()
		_music.setup(b.roles, sector, FX_BUS)
		get_tree().root.add_child.call_deferred(_music)
		_music.start.call_deferred()
		tree_exiting.connect(func() -> void:
			if is_instance_valid(_music):
				_music.release(1.4))
		MusicManager.stop()
	else:
		MusicManager.play("Decisive Battle 1 - Don't Be Afraid" if _is_boss() else "Battle 1")
	_sync_shown_from_battle()
	_spawn_enemies()
	_build_enemy_panels()
	if _show != null:
		_show.rebuild_enemies()
	_render_all()
	_build_hand(true)


# 새 전투는 소개 배너 → 플레이어 턴. 다시 켠 전투는 저장된 경계에서 이어간다(적 단계면 잠근 채 남은 적만)
func begin(resumed: bool) -> void:
	var g: Dictionary = P2Catalog.GROUPS[_run_info.group]
	var title := "%s · %s" % [_enc_label(), g.name]
	if resumed:
		_banner_text("이어하기\n" + title, 24)
	else:
		_banner_text(title + "\n" + _enc_hint(), 24)
	_state = UI.BANNER
	await _show_banner(0.9)
	if battle._resolving:
		_state = UI.ENEMY
		_refresh_card_states()
		await _run_enemy_phase(Time.get_ticks_usec())
		return
	if battle.opening_applied and battle.turn_number == 1 and battle.cards_played_this_turn == 0 and not resumed and battle.opening_block > 0:
		_float_number("준비 II: 방어 +%d" % battle.opening_block, _player_body() + Vector2(0, -60), C_BLOCK, 24, 30.0, 0.8)
		_sfx("guard", 1.1)
	_state = UI.PLAYER
	_refresh_card_states()
	_refresh_targeting()
	# 손맛 전투를 처음 하면 첫 턴에 연습 악보를 한 번(피해 없음) 치고, 오차가 한쪽으로 몰렸으면 판정 보정을 맞춘다
	if not resumed and battle.parry_mode and battle.turn_number == 1 and not bool(P2Ui.load_rhythm().practiced):
		P2Ui.save_rhythm({"practiced": true})
		_notice(tr("처음이니 연습 악보를 한 번 칩니다 (피해 없음)"), 3.0)
		await _wait(1.2)
		if is_inside_tree() and _state == UI.PLAYER:
			await practice(true)
			await _wait(3.5)
	if not resumed and not battle.anchor_uids.is_empty() and battle.turn_number == 1:
		_show_anchors()


func _show_anchors() -> void:
	var names: Array[String] = []
	for c in battle.hand.cards:
		if battle.anchor_uids.has(P2Catalog.uid_of(c)):
			names.append(c.card_name)
			var v: Control = _card_views.get(c)
			if v != null:
				# 색만 반짝이고 투명도는 그대로(그사이 턴을 끝내 손패가 흐려져도 되살리지 않게)
				var glow := func(c: Color) -> void: v.modulate = Color(c.r, c.g, c.b, v.modulate.a)
				var t := v.create_tween()
				t.tween_method(glow, Color.WHITE, Color(1.5, 1.3, 0.8), 0.2)
				t.tween_method(glow, Color(1.5, 1.3, 0.8), Color.WHITE, 0.4)
				t.tween_method(glow, Color.WHITE, Color(1.5, 1.3, 0.8), 0.2)
				t.tween_method(glow, Color(1.5, 1.3, 0.8), Color.WHITE, 0.4)
	_notice(tr("첫 손패에 직업 핵심 카드:") + "\n" + " · ".join(names), 6.0)
	_guide.text = "%s 첫 전투: 직업 핵심 카드 %s이(가) 첫 손패에 있습니다. %s" % [P2Catalog.CLASSES[battle.class_id].name,
		" · ".join(names), String(P2Catalog.CLASSES[battle.class_id].example)]
	_display_log.append({"frame": Engine.get_process_frames(), "kind": "anchors_shown", "names": names})


func _is_boss() -> bool:
	return bool(_run_info.get("boss", false))


# 연습은 원정 밖 한 판(그만두기 = 비용 없이 물러남)
func _practice() -> bool:
	return bool(_run_info.get("practice", false))


func _enc_label() -> String:
	if _practice():
		return "연습 · " + _run_label()
	return _run_label()


func _run_label() -> String:
	match enc_id:
		"boss":
			return "구간 I 보스"
		"hboss":
			return "구간 II 보스"
		"xboss":
			return "최종 보스"
		"elite":
			return "선택 전투"
		"elite_h", "elite_x":
			return "정예 " + P2Catalog.GROUPS[enc_id].name
		"h1a":
			return "하드 · 방패 통로"
		"h1b":
			return "하드 · 주술 통로"
		"h2":
			return "하드 · 포격 진지"
		"x1", "x2":
			return "익스트림 " + enc_id.to_upper()
	return "필수 전투 " + enc_id.to_upper()


func _enc_hint() -> String:
	if _practice():
		return "연습 한 판입니다. 피해·보상 없이 물약도 쓰지 않습니다. 끝나면 성적만 남습니다."
	match enc_id:
		"boss":
			if battle.has_summoner():
				return "소환수는 다음 적 차례에 폭발 6. 먼저 처치하면 폭발하지 않고, 방어로 막을 수 있습니다. 소환사를 쓰러뜨리면 바로 승리."
			return "보스의 방패 8은 첫 공격 카드 한 장의 피해를 막고 사라집니다. 연타 5×2 → 준비 → 강타 16."
		"hboss":
			if battle.noble_index() >= 0:
				return "이번 턴 귀족에게 피해를 준 카드 1장마다 내 공격 ×1.5 → ×2, 대신 귀족 물창도 8 → 11 → 14. 첫·세 번째 물창 뒤 다음 손패 1장이 묶이고, 카드 2장으로 맞히면 풀립니다."
			return "강타 20 차례인 턴에 보스에게 실제 피해 14 이상을 주면 강타가 10으로 약해집니다."
		"xboss":
			return "균열의 핵만 쓰러뜨리면 승리합니다. 장치는 부숴도 다시 세워지고 보상이 없습니다."
		"elite":
			if not battle.unwind_info(0).is_empty():
				return "맥 거완이 팔을 들면 다음 내 차례에 카드 직접 공격으로 3번 맞혀 강타 14를 6으로 약하게 할 수 있습니다. 이기면 카드와 강화 또는 유물을 고릅니다."
			return "선택 전투입니다. 이기면 카드와 강화 또는 유물을 고릅니다."
		"n1":
			return "적 머리 위가 이번 턴 행동입니다. 막을지, 먼저 쓰러뜨릴지 고르세요."
		"n2":
			return "방패병의 방패 8은 공격 카드 한 장의 피해 합계를 막고 사라집니다. 약한 카드로 먼저 벗기세요."
		"n3":
			return "기수가 살아 있는 동안 다른 적의 공격이 타격마다 +2. 기수를 먼저 쓰러뜨리면 예고가 바로 줄어듭니다."
		"n4":
			return "주술을 받으면 다음 내 턴 방어 카드가 2씩 약해집니다. 그 턴에는 공격으로 버티는 것도 방법입니다."
		"x1":
			return "독은 내 턴이 끝날 때 방어를 무시하고 2씩 두 번 들어옵니다. 회복약은 독과 주술도 풉니다."
	return "적 머리 위가 이번 턴 행동입니다."


func _exit_tree() -> void:
	_action_token += 1
	_pass_drop("exit")
	_unduck_bus()
	for t in _bar_tweens.values():
		if t != null and (t as Tween).is_valid():
			(t as Tween).kill()


# ── 무대 ────────────────────────────────────────────────────────────────────

func _build_stage() -> void:
	var cam := Camera2D.new()
	cam.position = Vector2(640, 360)
	add_child(cam)
	cam.make_current()
	_cam = cam
	_stage = Node2D.new()
	add_child(_stage)
	if battle.source == "expedition" and String(_run_info.get("sector", "")) == "normal":
		_build_env()
	else:
		_build_backdrop()
		var floor_shade := ColorRect.new()
		floor_shade.color = Color(0.05, 0.04, 0.03, 0.55)
		floor_shade.position = Vector2(-80, 470)
		floor_shade.size = Vector2(1440, 330)
		_stage.add_child(floor_shade)
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0)
	_dim.position = Vector2(-80, -80)
	_dim.size = Vector2(1440, 880)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_dim)
	_fx_back = Node2D.new()
	_stage.add_child(_fx_back)
	_amb = P2Ambience.new()
	var sector := String(_run_info.get("sector", ""))
	_amb.setup({"normal": "water" if battle.source == "expedition" else "dust", "hard": "frost", "extreme": "ember"}.get(sector, "dust"), _is_boss())
	_fx_back.add_child(_amb)
	_actors = Node2D.new()
	_actors.y_sort_enabled = true
	_stage.add_child(_actors)
	_fx = Node2D.new()
	# 수로 배경의 지속 광원은 z 10까지만 비춘다 — 효과·떠오르는 숫자는 그 위에 두어 물들지 않게
	_fx.z_index = 20 if _env != null else 0
	_stage.add_child(_fx)
	# 효과는 모두 3배 픽셀 그림판에(보통 · 빛 더하기, 앞 · 뒤): 매끈한 선 대신 손으로 찍은 픽셀처럼
	_fxp = P2Pixel.attach(_fx, Callable(), false, FX_PIX, FX_PEN)
	_fxpa = P2Pixel.attach(_fx, Callable(), false, FX_PIX, FX_PEN_ADD)
	_fxbp = P2Pixel.attach(_fx_back, Callable(), false, FX_PIX, FX_PEN)
	_fxba = P2Pixel.attach(_fx_back, Callable(), false, FX_PIX, FX_PEN_ADD)
	for host in [_fx, _fxp]:
		P2Vfx.route(host, _fxp, _fxpa)
	P2Vfx.route(_fx_back, _fxbp, _fxba)
	_player = AnimatedSprite2D.new()
	# 그림이 아직 없는 직업(콤보술사)은 표의 art 직업 그림을 빌린다
	_art_cid = String(P2Catalog.CLASSES.get(battle.class_id, {}).get("art", battle.class_id))
	_hires = _art_cid == "warden"
	_dressed = ACTOR_ART.has(_art_cid)
	if _dressed:
		# 큰 캔버스는 위치 맞춤용 공간: 발 기준점을 원점에 두고 몸 높이로 배율을 정한다 (수호기사·사냥꾼 같은 화면 높이)
		_art = ACTOR_ART[_art_cid]
		if sd_on() and battle.source == "expedition":
			var sd := _sd_player_art(_art_cid)
			if not sd.is_empty():
				_art = sd
		_player.sprite_frames = _dressed_frames()
		if _art_cid != battle.class_id:
			_player.self_modulate = Color(0.92, 0.66, 1.3) if battle.class_id == "shaman" else Color(1.0, 0.8, 1.18)
		_player.centered = false
		_player.offset = -(_art.foot as Vector2)
		_player.scale = Vector2.ONE * (_body_h / float(_art.get("body_px", WARDEN_BODY_PX)))
		_player.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if _art.get("nearest", false) else CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_player.animation_finished.connect(_on_actor_finished)
	else:
		_player.sprite_frames = _player_frames()
		_player.centered = false
		_player.offset = Vector2(-32, -48)
		_player.scale = Vector2.ONE * ACTOR_SCALE
	_player.position = Vector2(_home_x, FEET_Y)
	_player.play("idle")
	_actors.add_child(_player)
	if _dressed:
		_stance_shadow()
	else:
		_add_shadow(_player, 1.0)
	_env_shadow(_player)
	# 옛 500px 몸에 맞춘 칼날·잔상 겹침은 새 픽셀 수호기사에 붙이지 않는다
	if _hires and not _art.get("nearest", false) and not _art.has("sd"):
		_build_blade_overlay()
	_build_weapon()
	_build_av7_layer()


# 세계(층 0) 다음, 전투 UI(층 20) 앞에 그리는 합성 층 하나. 화면 읽기 셰이더 한 장 + 속도선. 입력은 받지 않는다
func _build_av7_layer() -> void:
	_av7_layer = CanvasLayer.new()
	_av7_layer.layer = 5
	add_child(_av7_layer)
	_av7_rect = ColorRect.new()
	_av7_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_av7_rect.size = Vector2(1280, 720)
	_av7_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = AV7_COMPOSITE
	_av7_mat = ShaderMaterial.new()
	_av7_mat.shader = sh
	_av7_rect.material = _av7_mat
	_av7_rect.visible = false
	_av7_layer.add_child(_av7_rect)
	var lines_host := Control.new()
	lines_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	lines_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_av7_layer.add_child(lines_host)
	_av7_lines = P2Pixel.attach(lines_host)
	_av7_warm()


# 첫 접촉 빛·합성·실루엣에서 그리기 변형이 처음 준비되며 생기는 멈칫을 피하려고, 전투 시작 배너 동안 셋을 보이지 않는 세기로 잠깐 그린다
func _av7_warm() -> void:
	if not _new_fx or _stage == null or _av7_rect == null:
		return
	var l := PointLight2D.new()
	l.texture = _av7_light_tex()
	l.texture_scale = 12.0
	l.energy = 0.002
	l.position = Vector2(640, 300)
	_stage.add_child(l)
	if _av7_sil_shader == null:
		_av7_sil_shader = Shader.new()
		_av7_sil_shader.code = AV7_SILHOUETTE
	var sil := Sprite2D.new()
	sil.texture = _av7_light_tex()
	sil.scale = Vector2.ONE * 0.05
	sil.position = Vector2(4, 4)
	sil.modulate.a = 0.01
	var sm := ShaderMaterial.new()
	sm.shader = _av7_sil_shader
	sil.material = sm
	_stage.add_child(sil)
	_av7_rect.visible = true
	var t := l.create_tween()
	t.tween_interval(0.4)
	t.tween_callback(func() -> void:
		l.queue_free()
		sil.queue_free()
		_av7_apply())


# 직업 무기를 몸 앞에 든다 (아이템 아이콘 16px). 동작: 룬술사 지팡이 들기 · 수호기사 방패 버티기 · 사냥꾼 활 당기기
const WEAPON_POSE := {"rune_caster": [Vector2(8, -17), -20.0], "warden": [Vector2(9, -13), 0.0], "hunter": [Vector2(9, -15), 45.0]}


func _build_weapon() -> void:
	var cid := _art_cid
	if not WEAPON_POSE.has(cid):
		return
	# 수호기사 고해상도 그림에는 검·방패가 이미 그려져 있어 따로 든 무기 아이콘을 붙이지 않는다 (치명 준비 빛은 그대로)
	if not _dressed:
		_weapon = Sprite2D.new()
		_weapon.texture = P2Catalog.icon_tex(cid)
		_weapon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_weapon.scale = Vector2.ONE * 0.6
		_weapon.position = WEAPON_POSE[cid][0]
		_weapon.rotation_degrees = WEAPON_POSE[cid][1]
		_weapon.set_meta("home", _weapon.position)
		_weapon.set_meta("rot", _weapon.rotation_degrees)
		_player.add_child(_weapon)
	_crit_glow = _glow(_stage, _player_body(), 220.0, Color(1.0, 0.78, 0.25, 0.7))
	_crit_glow.visible = false


# 던전 타일로 세운 전투 배경. 일반층은 붉은 횃불·나무 문, 하드층은 푸른 불·철창, 보스방은 더 어둡고 바닥 문양
func _build_env() -> void:
	_home_x = ENV_HOME_X
	_body_h = ENV_BODY_H
	_ks = ENV_BODY_H / WARDEN_SCREEN_H
	var back := ColorRect.new()
	back.color = Color("#0b0a0f")
	back.position = Vector2(-80, -80)
	back.size = Vector2(1440, 880)
	back.z_index = -50
	_stage.add_child(back)
	# 수로 배경은 통째로 절반 해상도 그림판에: 2px 격자 · 색 단계를 줄여 점 무늬(지도와 같은 결). 배우·효과·UI는 원래 해상도. --smooth면 예전처럼
	var pixel := not P2Pixel.smooth()
	_env = Node2D.new()
	if pixel:
		var vp := P2Pixel.canvas(_stage, Vector2(-80, -80), Vector2(1440, 880), false)
		var box := vp.get_parent() as SubViewportContainer
		box.z_index = -20
		box.light_mask = 0
		var dm := ShaderMaterial.new()
		dm.shader = load("res://p2/p2_pixel_dither.gdshader")
		dm.set_shader_parameter("levels", 22.0)
		dm.set_shader_parameter("amount", 0.5)
		box.material = dm
		_env.position = Vector2(80, 80) / P2Pixel.PIX
		_env.scale = Vector2.ONE / P2Pixel.PIX
		vp.add_child(_env)
	else:
		_stage.add_child(_env)
	for l in ENV_LAYERS:
		var sp := Sprite2D.new()
		sp.texture = _tall_fall() if String(l[0]) == "fall_mask" else load(ENV_DIR + String(l[0]) + ".png")
		if String(l[3]) != "":
			var m := ShaderMaterial.new()
			m.shader = load(ENV_DIR + String(l[3]) + ".gdshader")
			if String(l[3]) == "water_flow":
				m.set_shader_parameter("flow_pattern", load(ENV_DIR + "water_pattern.png"))
			sp.material = m
		_env_add(sp, Vector2(-80, -80), int(l[1]), float(l[2]))
	var fall2 := Sprite2D.new()
	fall2.texture = _tall_fall()
	var fm := ShaderMaterial.new()
	fm.shader = load(ENV_DIR + "fall_flow.gdshader")
	fm.set_shader_parameter("seed", 3.0)
	fall2.material = fm
	_env_add(fall2, Vector2(-80.0 + FALL2_DX, -80.0), -26, 0.55)
	var caustic := Sprite2D.new()
	caustic.texture = _av7_light_tex()
	caustic.scale = Vector2(1440.0, 104.0) / 128.0
	caustic.centered = false
	var cm := ShaderMaterial.new()
	cm.shader = load(ENV_DIR + "wall_caustics.gdshader")
	caustic.material = cm
	_env_add(caustic, Vector2(-80, 138), -29, 0.55)
	caustic.scale = Vector2(1440.0, 104.0) / 128.0
	for a in ENV_ANIMS:
		var sp := Sprite2D.new()
		sp.texture = load(ENV_DIR + String(a[0]) + ".png")
		sp.hframes = int(a[3])
		sp.frame = int(a[5])
		sp.set_meta("anim", a)
		_env_add(sp, a[1], int(a[2]), 0.55)
	# 지속 광원: 장면 소유(_env)라 전투를 떠나면 함께 사라진다. 새 연출의 일시 타격 광원 목록(_av7_lights)에는 넣지 않는다
	for l in ENV_LIGHTS:
		var light := PointLight2D.new()
		light.texture = _av7_light_tex()
		light.texture_scale = float(l[2]) * 2.0 / 128.0
		light.color = l[1]
		light.energy = float(l[3])
		light.position = l[0]
		light.range_z_min = -50
		light.range_z_max = 10
		light.set_meta("light", l)
		_env.add_child(light)
		# 그림판 안 빛은 배경만 비추므로, 배우를 비출 같은 빛을 바깥에 하나 더(세기는 _tick_env가 맞춤)
		if pixel:
			var twin := light.duplicate() as PointLight2D
			twin.remove_meta("light")
			twin.range_z_min = -10
			_stage.add_child(twin)
			light.set_meta("twin", twin)
	var amb := CanvasModulate.new()
	amb.color = Color(0.90, 0.93, 1.0)
	_stage.add_child(amb)
	for g in ENV_FLOOR_GLOW:
		var glow := Sprite2D.new()
		glow.texture = _av7_light_tex()
		glow.position = g[0]
		glow.modulate = g[1]
		glow.scale = (g[2] as Vector2) / 128.0
		glow.z_index = -6
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		glow.material = add
		_env.add_child(glow)
	_stage.set_meta("backdrop", "waterworks")


# 물줄기 그림을 화면 위 끝(위 띠 뒤)까지 늘인다: 원래 시작 줄(126) 아래 무늬를 위로 되풀이
static var _tall_fall_tex: ImageTexture


func _tall_fall() -> Texture2D:
	if _tall_fall_tex == null:
		var img := (load(ENV_DIR + "fall_mask.png") as Texture2D).get_image()
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		for y in range(0, 126):
			for x in range(456, 500):
				img.set_pixel(x, y, img.get_pixel(x, 126 + y % 60))
		_tall_fall_tex = ImageTexture.create_from_image(img)
	return _tall_fall_tex


func _env_add(sp: Sprite2D, at: Vector2, z: int, factor: float) -> void:
	sp.centered = false
	sp.position = at
	sp.z_index = z
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sp.set_meta("home", at)
	sp.set_meta("f", factor)
	_env.add_child(sp)


# 배우를 바닥에 붙인다: 같은 프레임을 빛 반대쪽·앞쪽으로 눕힌 그림자와, 가까운 횃불을 향한 가장자리의 테두리 빛.
# 둘 다 배우의 자식이라 이동·사망 투명도를 그대로 따르고, 그림·기준점은 _tick_env가 매 프레임 맞춘다. 규칙·판정과 무관한 표현
func _env_shadow(actor: Node2D) -> void:
	if _env == null:
		return
	for kind in ["shadow", "rim"]:
		var sp := Sprite2D.new()
		sp.centered = false
		sp.show_behind_parent = kind == "shadow"
		var m := ShaderMaterial.new()
		m.shader = load(ENV_DIR + "actor_%s.gdshader" % kind)
		sp.material = m
		sp.name = "EnvShadow" if kind == "shadow" else "EnvRim"
		actor.add_child(sp)
	_shaded.append(actor)
	_shade_sync(actor)


func _shade_sync(actor: Node2D) -> void:
	var tex: Texture2D = (actor as AnimatedSprite2D).sprite_frames.get_frame_texture((actor as AnimatedSprite2D).animation, (actor as AnimatedSprite2D).frame) if actor is AnimatedSprite2D else (actor as Sprite2D).texture
	if tex == null:
		return
	var off: Vector2 = actor.get("offset")
	var flip: bool = actor.get("flip_h")
	# 왼쪽 횃불과 오른쪽 횃불 사이에서 빛 방향이 끊기지 않게: 화면 가운데에서는 그림자가 똑바로 앞으로 떨어진다
	var lx := clampf((actor.position.x - 640.0) / 300.0, -1.0, 1.0)
	var shadow: Sprite2D = actor.get_node("EnvShadow")
	var rim: Sprite2D = actor.get_node("EnvRim")
	for sp in [shadow, rim]:
		sp.texture = tex
		sp.offset = off
		sp.flip_h = flip
		sp.texture_filter = actor.texture_filter
	shadow.scale = Vector2(1.0, -float(ENV_SHADE.squash))
	shadow.skew = lx * float(ENV_SHADE.lean)
	shadow.modulate = ENV_SHADE.color
	(shadow.material as ShaderMaterial).set_shader_parameter("foot_v", -off.y / float(tex.get_height()))
	var dir := Vector2(lx, -0.35).normalized()
	(rim.material as ShaderMaterial).set_shader_parameter("light_dir", Vector2(-dir.x if flip else dir.x, dir.y))
	(rim.material as ShaderMaterial).set_shader_parameter("px", maxf(1.0, round(float(ENV_SHADE.rim_px) / actor.scale.x)))


# 물·불·광원 흔들림은 이 시계 하나로 (게임이 멈추면 _process가 돌지 않아 함께 멈춘다). 흔들림 줄이기: 움직임·시차를 멈추고 정지 불·고정 조명만
func _tick_env(delta: float) -> void:
	if _env == null:
		return
	var still := _reduce_motion
	if not still:
		_env_clock += delta
	var d := Vector2.ZERO if still or _cam == null else _cam.offset + _breath
	for c in _env.get_children():
		if c.has_meta("f"):
			(c as Node2D).position = (c.get_meta("home") as Vector2) + (1.0 - float(c.get_meta("f"))) * d
		if c.has_meta("anim"):
			var a: Array = c.get_meta("anim")
			(c as Sprite2D).frame = (int(_env_clock * 1000.0 / float(a[4])) + int(a[5])) % int(a[3])
		elif c is Sprite2D and (c as Sprite2D).material is ShaderMaterial:
			((c as Sprite2D).material as ShaderMaterial).set_shader_parameter("flow_clock", _env_clock)
		elif c.has_meta("light"):
			var l: Array = c.get_meta("light")
			(c as PointLight2D).energy = float(l[3]) * (1.0 if still else 1.0 + float(l[4]) * sin(_env_clock * 9.0 + (l[0] as Vector2).x))
			if c.has_meta("twin"):
				(c.get_meta("twin") as PointLight2D).energy = (c as PointLight2D).energy
	_shaded = _shaded.filter(func(a): return is_instance_valid(a))
	for a in _shaded:
		_shade_sync(a)


func _build_backdrop() -> void:
	var hard := String(_run_info.sector) in ["hard", "extreme"]
	var boss := _is_boss()
	# 화면 밖 여백(새 연출 준비 단계의 물러남·따라가기에서 바깥 회색이 보이지 않게). 확대 1 이상에서는 보이지 않는다
	var back := ColorRect.new()
	back.color = Color("#0b0a0f")
	back.position = Vector2(-80, -80)
	back.size = Vector2(1440, 880)
	_stage.add_child(back)
	var bd := Node2D.new()
	_bg_node = bd
	var tint := Color(0.56, 0.66, 0.9) if hard else Color(0.82, 0.74, 0.66)
	if boss:
		tint = tint.darkened(0.22)
	bd.modulate = tint
	_stage.add_child(bd)
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	var src := TileSetAtlasSource.new()
	src.texture = load(TILES)
	src.texture_region_size = Vector2i(16, 16)
	ts.add_source(src, 0)
	var floor_tiles := [Vector2i(4, 0), Vector2i(5, 0), Vector2i(6, 0), Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1), Vector2i(4, 2), Vector2i(5, 2), Vector2i(6, 2)]
	for y in range(3):
		for x in range(3):
			src.create_tile(Vector2i(x, y))
	for c in floor_tiles:
		src.create_tile(c)
	var map := TileMapLayer.new()
	map.tile_set = ts
	map.scale = Vector2(4, 4)
	map.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bd.add_child(map)
	var rng := RandomNumberGenerator.new()
	for x in range(-1, 21):
		map.set_cell(Vector2i(x, 0), 0, Vector2i(posmod(x, 3), 0))
		map.set_cell(Vector2i(x, 1), 0, Vector2i(posmod(x, 3), 1))
		map.set_cell(Vector2i(x, 2), 0, Vector2i(posmod(x, 3), 1))
		map.set_cell(Vector2i(x, 3), 0, Vector2i(posmod(x, 3), 2))
		for y in range(4, 12):
			rng.seed = x * 131 + y * 17 + (7 if hard else 0)
			map.set_cell(Vector2i(x, y), 0, floor_tiles[0 if rng.randi() % 10 < 5 else rng.randi() % floor_tiles.size()])
	var col := 3 if hard else 0
	for x in [32.0, 480.0, 1184.0]:
		var pillar := _tile_sprite(Rect2(col * 16, 232, 16, 48), 4.0)
		pillar.position = Vector2(x, 64)
		bd.add_child(pillar)
	var door := _tile_sprite(Rect2(32 if hard else 0, 112, 32, 48), 4.0)
	door.position = Vector2(150, 64)
	bd.add_child(door)
	var gate_r := _tile_sprite(Rect2(32, 112, 32, 48), 4.0)
	gate_r.position = Vector2(1010, 64)
	bd.add_child(gate_r)
	if not hard:
		var banner := _tile_sprite(Rect2(86, 160, 20, 64), 3.0)
		banner.position = Vector2(700, 60)
		bd.add_child(banner)
	var flame_col := Color(0.45, 0.7, 1.0, 0.55) if hard else Color(1.0, 0.6, 0.28, 0.55)
	for x in [330.0, 860.0]:
		var sconce := _tile_sprite(Rect2(64 if hard else 16, 288, 16, 16), 3.0)
		sconce.position = Vector2(x - 24, 118)
		bd.add_child(sconce)
		var g := _glow(_stage, Vector2(x, 140), 300.0, flame_col)
		var light := PointLight2D.new()
		light.texture = _av7_light_tex()
		light.texture_scale = 640.0 / 128.0
		light.color = Color(flame_col, 1.0)
		light.energy = 0.45
		light.position = Vector2(x, 150)
		_stage.add_child(light)
		_torches.append([light, g, x])
	if boss:
		var ring := Line2D.new()
		ring.width = 3.0
		ring.default_color = Color(0.5, 0.75, 1.0, 0.45) if hard else Color(0.8, 0.5, 1.0, 0.45)
		# 소환사 전투는 소환사(뒤쪽 자리) 둘레만 — 앞쪽 소환수까지 한 원으로 묶어 보이지 않게
		var summ := battle.has_summoner()
		var rc := Vector2(float(SUMMONER_SLOTS[0]) if summ else float(ENEMY_SLOTS[1][0]), FEET_Y + 6)
		var rr := Vector2(110.0, 26.0) if summ else Vector2(190.0, 38.0)
		for i in range(49):
			var a := TAU * i / 48.0
			ring.add_point(rc + Vector2(cos(a) * rr.x, sin(a) * rr.y))
		_stage.add_child(ring)
	var top := TextureRect.new()
	var grad := GradientTexture2D.new()
	grad.gradient = Gradient.new()
	grad.gradient.set_color(0, Color(0, 0, 0, 0.75))
	grad.gradient.set_color(1, Color(0, 0, 0, 0))
	grad.fill_from = Vector2(0.5, 0)
	grad.fill_to = Vector2(0.5, 1)
	top.texture = grad
	top.size = Vector2(1280, 200)
	top.stretch_mode = TextureRect.STRETCH_SCALE
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(top)
	var pool := _glow(_stage, Vector2(700, FEET_Y - 30), 128.0, Color(1.0, 0.86, 0.62, 0.13) if not hard else Color(0.7, 0.8, 1.0, 0.12))
	pool.scale = Vector2(1000.0 / 128.0, 300.0 / 128.0)
	var low := TextureRect.new()
	var lg := GradientTexture2D.new()
	lg.gradient = Gradient.new()
	lg.gradient.set_color(0, Color(0, 0, 0, 0))
	lg.gradient.set_color(1, Color(0, 0, 0, 0.72))
	lg.fill_from = Vector2(0.5, 0)
	lg.fill_to = Vector2(0.5, 1)
	low.texture = lg
	low.position = Vector2(0, FEET_Y + 20)
	low.size = Vector2(1280, 720 - FEET_Y - 20)
	low.stretch_mode = TextureRect.STRETCH_SCALE
	low.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(low)
	_stage.set_meta("backdrop", "hard" if hard else "normal")


func _tile_sprite(region: Rect2, scale_: float) -> Sprite2D:
	var at := AtlasTexture.new()
	at.atlas = load(TILES)
	at.region = region
	var s := Sprite2D.new()
	s.texture = at
	s.centered = false
	s.scale = Vector2.ONE * scale_
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return s


func _glow(parent: Node, pos: Vector2, size: float, color: Color) -> Sprite2D:
	var tex := GradientTexture2D.new()
	tex.width = 128
	tex.height = 128
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.gradient = Gradient.new()
	tex.gradient.set_color(0, color)
	tex.gradient.set_color(1, Color(color, 0.0))
	var s := Sprite2D.new()
	s.texture = tex
	s.position = pos
	s.scale = Vector2.ONE * (size / 128.0)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	s.material = mat
	parent.add_child(s)
	if not _reduce_motion:
		var t := s.create_tween().set_loops()
		t.tween_property(s, "modulate:a", 0.78, 0.35 + randf() * 0.2)
		t.tween_property(s, "modulate:a", 1.0, 0.3 + randf() * 0.2)
	return s


func _player_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	_add_strip(frames, "idle", BODY + "Idle_Base/Idle_Side-Sheet.png", Vector2i(64, 64), 4, 6.0, true)
	_add_strip(frames, "thrust", BODY + "Pierce_Base/Pierce_Side-Sheet.png", Vector2i(64, 64), 8, 26.0, false)
	_add_strip(frames, "hit", BODY + "Hit_Base/Hit_Side-Sheet.png", Vector2i(64, 64), 4, 16.0, false)
	_add_strip(frames, "death", BODY + "Death_Base/Death_Side-Sheet.png", Vector2i(64, 64), 8, 10.0, false)
	return frames


# 옷 입은 배우의 동작들 (지금 직업의 그림 묶음). 속도 1000 = 프레임 길이(상대값)를 ms 그대로 쓴다
func _dressed_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var anims: Dictionary = _art.anims
	for anim in anims:
		var times: Array = anims[anim][0]
		frames.add_animation(anim)
		frames.set_animation_speed(anim, 1000.0)
		frames.set_animation_loop(anim, bool(anims[anim][1]))
		var dir := String(anims[anim][2]) if (anims[anim] as Array).size() > 2 else String(_art.dir)
		# 네 번째 칸: 다른 동작의 그림을 빌려 쓸 때 그 동작 이름 (SD 시범)
		var src := String(anims[anim][3]) if (anims[anim] as Array).size() > 3 else String(anim)
		for i in range(times.size()):
			frames.add_frame(anim, load(dir + "%s/%s_%02d.png" % [src, src, i]), float(times[i]))
	return frames


func _contact(anim: String) -> int:
	return int((_art.contact as Dictionary).get(anim, 0))


# 동작 하나를 from 프레임부터 틀고, 접촉 프레임이 시작될 때까지의 시간(초)을 돌려준다
func _actor_play(anim: String, from := 0) -> float:
	if _player_down:
		return 0.0
	match anim:
		"block", "defend":
			_pp_pose(Vector2(1.06, 0.94), -6.0, 0.08, 0.22, 0.25)
		"cast", "cast_strong", "focus", "strong_cast":
			_pp_pose(Vector2(0.95, 1.07), -4.0, 0.12, 0.18, 0.3)
	_player.play(anim)
	_player.frame = from
	var times: Array = _art.anims[anim][0]
	var t := 0.0
	for i in range(from, _contact(anim)):
		t += float(times[i]) / 1000.0
	return t


# 직업별 방어·반격 동작 이름 (없으면 "": 옛 배우)
func _defend_anim() -> String:
	return "block" if _hires else ("defend" if _dressed else "")


# 수호기사·사냥꾼 시전의 지금 프레임 마력 자리 (그 프레임 안내값이 없으면 발사 프레임 자리)
func _cast_socket() -> Vector2:
	if _art.has("sockets"):
		var anim := String(_player.animation) if String(_player.animation) in ["cast", "cast_strong"] else "cast"
		var tb: Dictionary = _art.sockets[anim]
		var at := _player.frame if String(_player.animation) == anim else _contact(anim)
		return _player.position + (tb.get(at, tb[_contact(anim)]) as Vector2) * _player.scale.x
	var table: Dictionary = CAST_SOCKETS[_art_cid]
	var f := _player.frame if _player.animation == "cast" else _contact("cast")
	var off: Vector2 = table.get(f, table[_contact("cast")])
	return _player.position + off * _player.scale.x


func _rune_socket(anim: String) -> Vector2:
	return _player.position + (RUNE_SOCKET[anim] as Vector2) * _player.scale.x


func _counter_anim() -> String:
	return "counter" if _hires else ("melee" if _dressed else "")


# 실제로 그려진 프레임이 f에 닿을 때까지 기다린다 (타이머를 이어 붙이면 짧은 접촉 프레임을 지나칠 수 있어서). 다른 동작으로 바뀌면 바로 끝
func _await_frame(anim: String, f: int, limit := 1.0) -> void:
	var t0 := Time.get_ticks_msec()
	while _player.animation == anim and _player.frame < f and Time.get_ticks_msec() - t0 < int(limit * 1000.0):
		await get_tree().process_frame


# 집중·연료화 공통 몸 동작(있는 배우만): 모으는 프레임까지 기다린 뒤 기존 효과. 타격 사건은 없다
func _focus_body() -> void:
	if _dressed and (_art.anims as Dictionary).has("focus"):
		await _wait(_actor_play("focus", 1))


# 한 번만 도는 동작이 끝나면 대기로 돌아간다 (쓰러진 뒤에는 그대로)
func _on_actor_finished() -> void:
	if _dressed and not _player_down and _player.animation != "idle":
		_player.play("idle")


# 옷 입은 배우 피격: 실제 피해가 표시되는 순간 피격 그림(0프레임부터 한 번)을 틀고, 끝나면 대기로 (animation_finished).
# 흔들림 줄이기에서도 자세는 바뀐다(밀림만 뺌). 쓰러진 뒤에는 아무것도 되살리지 않는다
func _actor_hurt() -> void:
	if not _dressed:
		_player.play("hit")
		return
	if _player_down:
		return
	if (_art.anims as Dictionary).has("hurt"):
		_player.play("hurt")
		_player.frame = 0
	_pp_pose(Vector2(1.12, 0.87), -13.0, 0.04, 0.07, 0.42)
	_player_nudge("player_hurt")


# 주인공 몸 밀림(주인 하나: _recoil). 막기 2px · 피격 9px, 왼쪽으로 나갔다 제자리로
# ── SD 주인공 몸짓: 동작 그림이 오기 전까지 정지 그림 한 장을 기울이고 누르고 늘여 자세를 만든다(발 기준, + 기울기 = 앞으로 숙임).
# 숨쉬기는 늘 곱해지고, 자세는 마지막에 부른 것 하나만. 그림자(다각형 자식)는 반대로 되돌려 바닥에 붙어 있게 ──

func _sd_player() -> bool:
	return _dressed and _art.has("sd")


# sq·tilt 자세로 t_in초에 옮겨 가고, hold초 머문 뒤 back초에 튕기듯 바로 선다(back 0이면 그 자세 그대로 둠)
func _pp_pose(sq: Vector2, tilt: float, t_in: float, hold := 0.0, back := 0.25) -> void:
	if not _sd_player() or _reduce_motion or _player_down:
		return
	if _pp_tw != null and _pp_tw.is_valid():
		_pp_tw.kill()
	var s0 := _pp_sq
	var r0 := _pp_tilt
	_pp_tw = create_tween()
	_pp_tw.tween_method(func(u: float) -> void:
		_pp_sq = s0.lerp(sq, u)
		_pp_tilt = lerpf(r0, tilt, u), 0.0, 1.0, maxf(t_in, 0.01)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if back > 0.0:
		if hold > 0.0:
			_pp_tw.tween_interval(hold)
		_pp_tw.tween_method(func(u: float) -> void:
			_pp_sq = sq.lerp(Vector2.ONE, u)
			_pp_tilt = lerpf(tilt, 0.0, u), 0.0, 1.0, back).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _tick_sd_player(delta: float) -> void:
	if not _sd_player() or _player == null:
		return
	if _pp_base == Vector2.ZERO:
		_pp_base = _player.scale
	if _player_down:
		return
	_pp_clock += delta
	var b := 0.0 if _reduce_motion else 0.5 - 0.5 * cos(TAU * _pp_clock / 1.8)
	_pp_pulse = move_toward(_pp_pulse, 0.0, delta * 6.0)
	var bp := _pp_pulse * _pp_pulse
	var s := _pp_sq * Vector2(1.0 - 0.006 * b - 0.012 * bp, 1.0 + 0.014 * b + 0.026 * bp)
	_player.scale = _pp_base * s
	_player.rotation_degrees = _pp_tilt
	for ch in _player.get_children():
		if ch is Polygon2D:
			(ch as Polygon2D).scale = Vector2(1.0 / (_pp_base.x * s.x), 1.0 / (_pp_base.x * s.y))
			(ch as Polygon2D).rotation_degrees = -_pp_tilt


func _player_nudge(profile: String) -> void:
	if _recoil != null and _recoil.is_valid():
		_recoil.kill()
	_player.position.x = _home_x
	if _reduce_motion or _player_down:
		return
	var p: Dictionary = IMPACT[profile]
	_recoil = create_tween()
	_recoil.tween_interval(float(p.hold))
	_recoil.tween_property(_player, "position:x", _home_x - float(p.push), float(p.out))
	_recoil.tween_property(_player, "position:x", _home_x, float(p.back))


# 옷 입은 배우 쓰러짐: 죽음 동작이 없어 피격 가장 깊은 자세(2)에 멈추고 어둡게 가라앉는 임시 연출.
# 치명 피해 순간 바로 부르고, 전투 종료에서 다시 불러도 한 번만. 이후 대기 복귀·동작·밀림은 모두 막힌다
func _actor_death() -> void:
	if not _dressed:
		_player.play("death")
		return
	if _player_down:
		return
	_player_down = true
	if _recoil != null and _recoil.is_valid():
		_recoil.kill()
	if (_art.anims as Dictionary).has("death"):
		# 쓰러짐 동작을 한 번 재생하고 마지막 자세 유지(반복 없음). down 뒤라 대기 복귀·다른 동작은 이미 막혀 있다
		_player.position.x = _home_x
		_player.play("death")
		_player.frame = 0
		return
	if (_art.anims as Dictionary).has("hurt"):
		_player.play("hurt")
		_player.frame = 2
	else:
		_player.play("idle")
		_player.frame = 0
	_player.pause()
	var t := create_tween()
	t.tween_property(_player, "modulate", Color(0.45, 0.4, 0.45, 0.6), 0.45)
	t.parallel().tween_property(_player, "position:y", FEET_Y + 4.0, 0.45)


func _add_strip(frames: SpriteFrames, anim: String, path: String, size: Vector2i, count: int, fps: float, loop: bool) -> void:
	var sheet := load(path) as Texture2D
	frames.add_animation(anim)
	frames.set_animation_speed(anim, fps)
	frames.set_animation_loop(anim, loop)
	for i in range(count):
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(i * size.x, 0, size.x, size.y)
		frames.add_frame(anim, atlas)


# 옷 입은 배우의 바닥 그림자: 두 발 가운데(stance_x) 아래 화면 기준 폭 shadow_w × 높이 14 타원. 배우의 자식이라 이동(뿌리)만 따라가고 숨쉬기와는 무관
func _stance_shadow() -> void:
	var sh := Polygon2D.new()
	var pts := PackedVector2Array()
	var rx := float(_art.shadow_w) / 2.0 * _ks
	for i in range(20):
		var a := TAU * i / 20.0
		pts.append(Vector2(cos(a) * rx, sin(a) * 7.0))
	sh.polygon = pts
	sh.color = Color(0, 0, 0, 0.38)
	sh.show_behind_parent = true
	sh.scale = Vector2.ONE / _player.scale.x
	sh.position = Vector2(float(_art.stance_x), 0.0)
	sh.name = "StanceShadow"
	_player.add_child(sh)


# 주인공 몸 중심(두 발 가운데 위, 대기 몸 높이의 절반)과 머리 꼭대기 — 효과·떠오르는 글자·머리 위 상태가 쓰는 자리
func _player_body() -> Vector2:
	if not _dressed:
		return _body_center(_player.position)
	return _player.position + Vector2(float(_art.stance_x) * _player.scale.x, float(_art.head_y) * _player.scale.x * 0.5)


func _player_head_y() -> float:
	return FEET_Y + (float(_art.head_y) * _player.scale.x if _dressed else -128.0)


func _add_shadow(actor: Node2D, width: float) -> void:
	var shadow := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(16):
		var a := TAU * i / 16.0
		pts.append(Vector2(cos(a) * 9.0 * width, sin(a) * 2.6))
	shadow.polygon = pts
	shadow.color = Color(0, 0, 0, 0.35)
	shadow.show_behind_parent = true
	actor.add_child(shadow)


func _enemy_frames(variant: Dictionary) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var idle := int(variant.idle_frame_size)
	var run_size := int(variant.run_frame_size)
	_add_strip(frames, "idle", variant.idle_path, Vector2i(idle, idle), int(variant.idle_frame_count), 6.0, true)
	_add_strip(frames, "run", variant.run_path, Vector2i(run_size, run_size), int(variant.run_frame_count), 14.0, true)
	_add_strip(frames, "death", variant.death_path, Vector2i(int(variant.death_frame_width), int(variant.death_frame_height)), int(variant.death_frame_count), 10.0, false)
	return frames


func _set_enemy_anim(sprite: AnimatedSprite2D, anim: String) -> void:
	if sprite.has_meta("art_foot"):
		_art_claim(sprite)
		sprite.set_meta("art_busy", false)
		if anim != "idle":
			(sprite.material as ShaderMaterial).set_shader_parameter("flow_amount", 0.0)
			_breath_off(sprite)
		sprite.offset = -_art_origin(sprite, anim)
		sprite.play(anim)
		return
	var tex := sprite.sprite_frames.get_frame_texture(anim, 0)
	var size := tex.get_size()
	# 64px 시트(미라/보스)는 캔버스가 커서 발 위치를 아래쪽 여백만큼 보정한다
	var foot := float(sprite.get_meta("foot_pad", 0.0))
	sprite.offset = Vector2(-size.x / 2.0, -size.y + foot)
	sprite.play(anim)


func _slots() -> Array:
	if battle.has_summoner() and battle.monsters.size() == SUMMONER_SLOTS.size():
		return SUMMONER_SLOTS
	return ENEMY_SLOTS[battle.monsters.size()]


func _enemy_art_key(i: int) -> String:
	if sd_on() and battle.source == "expedition" and String(_run_info.get("sector", "")) == "normal" and SD_ROLES.has(String(battle.roles[i])):
		var sd := _sd_enemy_key(String(SD_ROLES[String(battle.roles[i])]))
		if sd != "":
			return sd
	for pick in ENEMY_ART_PICKS:
		if pick.has("sector") and String(_run_info.get("sector", "")) != String(pick.sector):
			continue
		if battle.source == String(pick.source) and battle.encounter_id == String(pick.encounter) and String(battle.roles[i]) == String(pick.role) and i == int(pick.index):
			return String(pick.art)
	if sample_art.has(String(battle.roles[i])):
		return String(sample_art[String(battle.roles[i])])
	return ""


# 한 장 원본을 대기·달리기·쓰러짐에 그대로 쓴다(새 동작 그림 없음). 재질은 배우마다 하나, 셰이더·가면은 공유.
# 같은 재질의 flash_color/flash_mix를 _actor_flash가 그대로 쓴다(flash_mat 표시)
func _art_frames(a: Dictionary, over: Dictionary) -> SpriteFrames:
	var idle_frames: Array = over.get("idle_frames", a.get("idle_frames", []))
	var tex: Texture2D = load(idle_frames[0] if not idle_frames.is_empty() else a.body)
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for anim in ["idle", "run", "death"]:
		frames.add_animation(anim)
		frames.set_animation_loop(anim, anim != "death")
		if anim == "idle" and not idle_frames.is_empty():
			frames.set_animation_speed("idle", 1000.0)
			for k in range(idle_frames.size()):
				frames.add_frame("idle", load(idle_frames[k]), float(a.idle_ms[k]))
		else:
			frames.add_frame(anim, tex)
	if a.has("actions"):
		for anim in a.actions.get("anims", ["attack", "hurt"]):
			frames.add_animation(anim)
			frames.set_animation_loop(anim, false)
			for path in over.get(anim, a.actions[anim]):
				frames.add_frame(anim, load(path))
	return frames


func _dress_enemy_art(sprite: AnimatedSprite2D, key: String) -> void:
	var a: Dictionary = _ea(key)
	sprite.sprite_frames = _art_frames(a, {})
	if a.has("unshielded"):
		# 방패 두 벌: 같은 이름의 동작(idle·attack·hurt)을 벌째로 바꿔 끼운다. 흡수·놓침은 두 벌에 같이 있다
		sprite.set_meta("frames_s", sprite.sprite_frames)
		sprite.set_meta("frames_u", _art_frames(a, a.unshielded))
		sprite.set_meta("masks_s", (a.idle_masks as Array).map(func(p): return load(p)))
		sprite.set_meta("masks_u", (a.unshielded.idle_masks as Array).map(func(p): return load(p)))
		sprite.set_meta("shielded", true)
	if a.has("steady"):
		# 거완: 대기·준비·힘 풀림 세 벌. 동작 그림은 세 벌에 같이 있어 벌을 바꿔도 동작은 이어진다
		var sets := {"idle": sprite.sprite_frames}
		var masks := {"idle": (a.idle_masks as Array).map(func(p): return load(p))}
		for st in a.steady:
			sets[st] = _art_frames(a, a.steady[st])
			masks[st] = (a.steady[st].idle_masks as Array).map(func(p): return load(p))
		sprite.set_meta("steady_frames", sets)
		sprite.set_meta("steady_masks", masks)
		sprite.set_meta("steady", "idle")
	sprite.set_meta("art_gen", 0)
	sprite.set_meta("art_busy", false)
	sprite.centered = false
	sprite.flip_h = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var foot: Vector2 = a.foot
	var body_ref := float(a.get("body_ref", foot.y - float(a.top)))
	sprite.scale = Vector2.ONE * float(a.body_px) / body_ref * _ks
	sprite.set_meta("art", key)
	sprite.set_meta("art_foot", foot)
	sprite.set_meta("flow_clock", 0.0)
	var mat := ShaderMaterial.new()
	mat.shader = load(a.shader)
	mat.set_shader_parameter("maek_mask", load(a.mask))
	mat.set_shader_parameter("flow_time", 0.0)
	mat.set_shader_parameter("flow_amount", 0.0)
	mat.set_shader_parameter("flow_speed", float(a.speed))
	mat.set_shader_parameter("flow_density", float(a.density))
	# 호흡: 허리(발 위 몸 38%) 위만 늘여 머리가 허리~머리(몸 62%) × 비율만큼 오른다. 136px 몸에서 한 장 2.3px, 여섯 장은 기존 프레임 위에 1.3px
	mat.set_shader_parameter("breath_pivot_uv", (foot.y - body_ref * 0.38) / float(sprite.sprite_frames.get_frame_texture("idle", 0).get_height()))
	sprite.set_meta("breath_k", (1.3 if (a.get("idle_frames", []) as Array).size() > 1 else 2.3) / (0.62 * 136.0))
	sprite.set_meta("breath_w", 0.0)
	sprite.material = mat
	sprite.set_meta("flash_mat", true)
	if a.has("idle_masks"):
		# 대기 숨쉬기 프레임과 같은 변형의 가면을 함께 바꾼다 (동작 그림에서는 흐름 0이라 가면을 읽지 않음)
		sprite.set_meta("idle_masks", sprite.get_meta("masks_s") if sprite.has_meta("masks_s") else (a.idle_masks as Array).map(func(p): return load(p)))
		var swap := func() -> void: _art_idle_mask(sprite)
		sprite.frame_changed.connect(swap)
		sprite.animation_changed.connect(swap)
	# 이 맥 적 발밑의 옅은 청록 빛(대기 흐름 세기·시계를 따라감, 새 연출 끔이면 없음)
	var glow := Sprite2D.new()
	glow.texture = _av7_light_tex()
	var gr := float(AV7.maek_floor.r) * clampf(float(a.body_px) / 136.0, 0.55, 1.2)
	glow.scale = Vector2(gr * 2.0 / 128.0, gr * 0.9 / 128.0)
	glow.modulate = Color(0.45, 0.9, 1.0, 0.0)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = add
	glow.visible = false
	_fx_back.add_child(glow)
	sprite.set_meta("floor_glow", glow)


func _art_acts(sprite: AnimatedSprite2D) -> bool:
	return sprite.has_meta("art") and (_ea(sprite.get_meta("art")) as Dictionary).has("actions")


# 대기·달리기·쓰러짐은 원본 캔버스, 공격·피격은 큰 동작 캔버스 — 발 기준점만 다르고 배율은 같다
func _art_origin(sprite: AnimatedSprite2D, anim: String) -> Vector2:
	var a: Dictionary = _ea(sprite.get_meta("art"))
	return a.actions.origin if a.has("actions") and anim in a.actions.get("anims", ["attack", "hurt"]) else a.foot


# 이 배우 동작의 주인 하나: 새 동작·피격·쓰러짐·씬 정리가 세대를 올리면 이전 콜백은 아무것도 하지 않는다
func _art_claim(sprite: AnimatedSprite2D) -> int:
	var gen := int(sprite.get_meta("art_gen", 0)) + 1
	sprite.set_meta("art_gen", gen)
	return gen


# 동작 그림으로 바꾸기 전에 맥 흐름·호흡을 즉시 0으로 (대기 가면·허리 기준은 동작 그림 UV와 맞지 않음). 프레임은 직접 넘긴다
func _art_pose(sprite: AnimatedSprite2D, anim: String, frame: int) -> void:
	(sprite.material as ShaderMaterial).set_shader_parameter("flow_amount", 0.0)
	_breath_off(sprite)
	sprite.offset = -_art_origin(sprite, anim)
	if sprite.animation != anim:
		sprite.play(anim)
	sprite.pause()
	sprite.frame = frame
	art_log.append({"pose": "%s:%d" % [anim, frame], "ms": Time.get_ticks_msec(), "frame": Engine.get_process_frames(), "x": sprite.position.x, "art": String(sprite.get_meta("art"))})


# 이 배우의 시간만 센다: 게임 멈춤·히트스톱(speed_scale 0) 동안은 멈추고, 세대가 바뀌면 false
func _art_hold(sprite: AnimatedSprite2D, sec: float, gen: int) -> bool:
	var t := 0.0
	while t < sec:
		await get_tree().process_frame
		if not is_instance_valid(sprite) or not is_inside_tree() or int(sprite.get_meta("art_gen", 0)) != gen:
			return false
		if not get_tree().paused and sprite.speed_scale > 0.0:
			t += get_process_delta_time()
	return true


# 공격 들어가기: 준비 → 들어 올림(돌진이 닿고 실제 사건을 보일 때까지 유지). 접촉 프레임은 사건 표시 직전에 _art_contact가 연다
func _art_attack_in(sprite: AnimatedSprite2D, rush := 0.0) -> void:
	var acts: Dictionary = _ea(sprite.get_meta("art")).actions
	var gen := _art_claim(sprite)
	var an := String(sprite.get_meta("atk", "attack"))
	sprite.set_meta("art_busy", true)
	sprite.set_meta("dashing", true)
	_art_pose(sprite, an, 0)
	_sfx("enemy_swing")
	var blade: Vector2 = (acts.get(an + "_contact", acts.get("contact_offset", acts.get("blade"))) as Vector2) * sprite.scale.x
	var dest := _player_body().x + float(acts.get(an + "_reach", acts.reach)) * _ks - blade.x
	var pg := _pass_begin(sprite, [])
	sprite.set_meta("pass_gen", pg)
	route_log.append({"actor": String(sprite.get_meta("art")), "from": sprite.position.x, "to": dest, "pass": pg})
	var dash := _route_tween(sprite, dest, rush, true, Tween.TRANS_EXPO) if rush > 0.0 else _route_tween(sprite, dest, 0.16, false)
	if rush > 0.0:
		_afterimages(sprite, rush * 0.5)
	if await _art_hold(sprite, float(acts[an + "_s"][0]), gen):
		_art_pose(sprite, an, 1)
	if dash.is_running():
		await dash.finished


func _art_winding(sprite: AnimatedSprite2D) -> bool:
	return _art_acts(sprite) and sprite.animation == String(sprite.get_meta("atk", "attack")) and sprite.frame == 1


# 첫 실제 적 공격 사건을 보이는 바로 그 프레임에 접촉 자세 → 회복 → 준비 (같은 세대일 때만)
func _art_contact(sprite: AnimatedSprite2D) -> void:
	var gen := int(sprite.get_meta("art_gen", 0))
	_art_pose(sprite, String(sprite.get_meta("atk", "attack")), 2)
	_art_attack_out(sprite, gen, true)


# 여러 타격 공격(거완 6×2): 다음 실제 타격 전에 다시 들어 올려 그 타격도 접촉 프레임에 보인다
func _art_rewinds(sprite: AnimatedSprite2D) -> bool:
	return _art_acts(sprite) and bool(_ea(sprite.get_meta("art")).actions.get("rewind", false)) and not bool(sprite.get_meta("dying", false))


func _art_rewind(sprite: AnimatedSprite2D) -> void:
	var an := String(sprite.get_meta("atk", "attack"))
	var gen := _art_claim(sprite)
	sprite.set_meta("art_busy", true)
	_art_pose(sprite, an, 1)
	await _art_hold(sprite, float(_ea(sprite.get_meta("art")).actions[an + "_s"][1]), gen)


func _art_attack_out(sprite: AnimatedSprite2D, gen: int, hit: bool) -> void:
	var an := String(sprite.get_meta("atk", "attack"))
	var ms: Array = _ea(sprite.get_meta("art")).actions[an + "_s"]
	if hit and not await _art_hold(sprite, float(ms[2]), gen):
		return
	_art_pose(sprite, an, 3)
	if not await _art_hold(sprite, float(ms[3]), gen):
		return
	_art_pose(sprite, an, 4)
	if not await _art_hold(sprite, float(ms[4]), gen):
		return
	sprite.set_meta("art_busy", false)


# 실제 남은 피해가 들어가는 순간 바로 피격 자세(첫 준비 프레임은 건너뜀). 치명이면 그 자세로 멈춘 채 쓰러짐(대기로 돌아가지 않음)
func _art_hurt(sprite: AnimatedSprite2D, dead: bool, shield_after := -1) -> void:
	if not _art_acts(sprite) or bool(sprite.get_meta("dying", false)):
		return
	if shield_after >= 0:
		_shield_set(sprite, shield_after > 0, "hurt")
	var gen := _art_claim(sprite)
	sprite.set_meta("art_busy", not dead)
	_art_pose(sprite, "hurt", 1)
	if not dead:
		_art_hurt_out(sprite, gen)


func _art_hurt_out(sprite: AnimatedSprite2D, gen: int) -> void:
	var acts: Dictionary = _ea(sprite.get_meta("art")).actions
	var ms: Array = acts.hurt_s
	if not await _art_hold(sprite, float(ms[1]), gen):
		return
	# 소환수: 피격 그림의 끝 프레임(작은 준비 자세)이 아니라 지금 상태(부풀어 오른 대기)로 바로 돌아간다
	if not bool(acts.get("hurt_end_idle", false)):
		_art_pose(sprite, "hurt", 2)
		if not await _art_hold(sprite, float(ms[2]), gen):
			return
	sprite.set_meta("art_busy", false)
	if not bool(sprite.get_meta("dashing", false)) and not bool(sprite.get_meta("dying", false)):
		_set_enemy_anim(sprite, "idle")


# ── 사수: 제자리 쏘기. 놓는 프레임(2)에 기존 화살 하나가 활 자리에서 실제 주인공 쪽으로, 닿는 순간은 부르는 쪽 사건 처리 ──
func _art_shot_in(sprite: AnimatedSprite2D, chart: P2NoteChart = null) -> void:
	var acts: Dictionary = _ea(sprite.get_meta("art")).actions
	var gen := _art_claim(sprite)
	sprite.set_meta("art_busy", true)
	var ms: Array = acts.attack_s
	_art_pose(sprite, "attack", 0)
	if await _art_hold(sprite, float(ms[0]), gen):
		_art_pose(sprite, "attack", 1)
	if chart != null:
		await _chart_until(chart, 0, float(ms[1]) + 0.16)
	if await _art_hold(sprite, float(ms[1]), gen):
		_art_pose(sprite, "attack", 2)
	if int(sprite.get_meta("art_gen", 0)) != gen:
		return
	var from := sprite.position + (acts.release_socket as Vector2) * sprite.scale.x
	arrow_log.append({"art": String(sprite.get_meta("art")), "pose": "%s:%d" % [sprite.animation, sprite.frame], "from": from, "f": Engine.get_process_frames(), "hp": int(_shown.hp)})
	_art_shot_out(sprite, gen)
	if bool(_ea(sprite.get_meta("art")).get("lance", false)):
		_sfx("cast", 0.8)
		await _water_lance(from, _player_body() + Vector2(18, 0), maxi(0, [8, 11, 14].find(int(_shown.get("nlock", 8)))))
		return
	_sfx("bow", 0.9)
	await _arrow(from, _player_body() + Vector2(18, 0), 0.16)


func _art_shot_out(sprite: AnimatedSprite2D, gen: int) -> void:
	var ms: Array = _ea(sprite.get_meta("art")).actions.attack_s
	if not await _art_hold(sprite, float(ms[2]), gen):
		return
	_art_pose(sprite, "attack", 3)
	if not await _art_hold(sprite, float(ms[3]), gen):
		return
	_art_pose(sprite, "attack", 4)
	if not await _art_hold(sprite, float(ms[4]), gen):
		return
	sprite.set_meta("art_busy", false)
	if not bool(sprite.get_meta("dying", false)):
		_set_enemy_anim(sprite, "idle")


# ── 방패병: 방패 있음/없음 벌 바꾸기 · 흡수 · 놓침 ──
# 벌을 바꿔도 지금 동작 이름·프레임·재생은 그대로 두고, 대기 가면도 같은 벌로. 재질(번쩍임)·알파·흐림은 건드리지 않는다
func _shield_set(sprite: AnimatedSprite2D, shielded: bool, why: String) -> void:
	if not sprite.has_meta("frames_u") or bool(sprite.get_meta("shielded", true)) == shielded:
		return
	var anim := sprite.animation
	var f := sprite.frame
	var playing := sprite.is_playing()
	sprite.set_meta("shielded", shielded)
	sprite.set_meta("shield_why", why)
	sprite.set_meta("idle_masks", sprite.get_meta("masks_s" if shielded else "masks_u"))
	sprite.sprite_frames = sprite.get_meta("frames_s" if shielded else "frames_u")
	sprite.animation = anim
	sprite.frame = f
	if playing:
		sprite.play(anim)
	_art_idle_mask(sprite)


# 방패가 실제 피해를 막은 순간: 흡수 자세 1부터 바로. 이 타격으로 방패가 0이면 이어서 놓침, 아니면 방패 든 준비 → 대기
func _shield_absorb(sprite: AnimatedSprite2D, left: int) -> void:
	if not sprite.has_meta("frames_u") or bool(sprite.get_meta("dying", false)):
		return
	var gen := _art_claim(sprite)
	sprite.set_meta("art_busy", true)
	if left == 0:
		_shield_set(sprite, false, "absorb")
	var acts: Dictionary = _ea(sprite.get_meta("art")).actions
	_art_pose(sprite, "absorb", 1)
	if not await _art_hold(sprite, float(acts.absorb_s[1]), gen):
		return
	if left == 0:
		_shield_loss_play(sprite, gen)
		return
	_art_pose(sprite, "absorb", 2)
	if not await _art_hold(sprite, float(acts.absorb_s[2]), gen):
		return
	sprite.set_meta("art_busy", false)
	if not bool(sprite.get_meta("dashing", false)) and not bool(sprite.get_meta("dying", false)):
		_set_enemy_anim(sprite, "idle")


# 놓침 1 → 3(방패 없는 준비) → 대기. 피격·쓰러짐·새 동작이 세대를 올리면 그 자리에서 멈춘다
func _shield_loss_play(sprite: AnimatedSprite2D, gen: int) -> void:
	var ms: Array = _ea(sprite.get_meta("art")).actions.loss_s
	for k in [1, 2, 3]:
		_art_pose(sprite, "loss", k)
		if not await _art_hold(sprite, float(ms[k]), gen):
			return
	sprite.set_meta("art_busy", false)
	if not bool(sprite.get_meta("dashing", false)) and not bool(sprite.get_meta("dying", false)):
		_set_enemy_anim(sprite, "idle")


# 보인 방패가 >0 → 0이 된 사건 하나에 한 번: 피격·흡수가 이미 벌을 바꿨으면 기록만, 쓰러짐이면 아무것도 재생하지 않음, 아니면(카드 끝 사라짐 등) 놓침
func _shield_dropped(i: int, ev: Dictionary) -> void:
	var sprite := _enemy_sprites[i]
	if not sprite.has_meta("frames_u"):
		return
	var mode := "loss"
	if bool(sprite.get_meta("dying", false)) or not bool(_shown.enemies[i].alive):
		mode = "dead"
		_shield_set(sprite, false, "dead")
	elif not bool(sprite.get_meta("shielded", true)):
		mode = String(sprite.get_meta("shield_why", ""))
	else:
		_shield_set(sprite, false, "loss")
		var gen := _art_claim(sprite)
		sprite.set_meta("art_busy", true)
		_shield_loss_play(sprite, gen)
	shield_log.append({"index": i, "kind": String(ev.kind), "mode": mode, "f": Engine.get_process_frames(), "hp": int(_shown.enemies[i].hp)})


# ── 귀족: 물창 · 봉인 손짓 · 카드 봉인 배지 ──
var _lance_frames: SpriteFrames = null
var _seal_tex: Array = []


func _water_lance(from: Vector2, to: Vector2, level: int) -> void:
	if _lance_frames == null:
		_lance_frames = SpriteFrames.new()
		_lance_frames.remove_animation("default")
		for a in [["emit", [0, 1], [45, 45], false], ["fly", [2, 3], [50, 50], true], ["hit", [4, 5], [55, 70], false]]:
			_lance_frames.add_animation(a[0])
			_lance_frames.set_animation_speed(a[0], 1000.0)
			_lance_frames.set_animation_loop(a[0], a[3])
			for k in range(2):
				_lance_frames.add_frame(a[0], load(NB38_DIR + "water_lance/water_lance_%02d.png" % a[1][k]), float(a[2][k]))
	var sp := AnimatedSprite2D.new()
	sp.sprite_frames = _lance_frames
	sp.centered = false
	sp.offset = -Vector2(64, 256)
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# 비행 그림의 실제 물창 길이(약 560 원본 px)를 공명 0/1/2에 76/92/112px로
	sp.scale = Vector2.ONE * float([76.0, 92.0, 112.0][clampi(level, 0, 2)]) / 560.0
	sp.position = from
	_fx.add_child(sp)
	lance_log.append({"level": level, "from": from, "f": Engine.get_process_frames()})
	sp.play("emit")
	await sp.animation_finished
	if not is_instance_valid(sp):
		return
	sp.play("fly")
	var t := create_tween()
	t.tween_property(sp, "position", to, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await t.finished
	if not is_instance_valid(sp):
		return
	sp.play("hit")
	sp.animation_finished.connect(sp.queue_free)


func _art_seal_cast(sprite: AnimatedSprite2D) -> void:
	if not _art_acts(sprite) or bool(sprite.get_meta("dying", false)):
		return
	var gen := _art_claim(sprite)
	sprite.set_meta("art_busy", true)
	var ms: Array = _ea(sprite.get_meta("art")).actions.seal_s
	_sfx("lock", 0.9)
	for k in [1, 2, 3, 4]:
		_art_pose(sprite, "seal", k)
		if not await _art_hold(sprite, float(ms[k]), gen):
			return
	sprite.set_meta("art_busy", false)
	if not bool(sprite.get_meta("dying", false)):
		_set_enemy_anim(sprite, "idle")


# 손패 카드 그림 오른쪽 위의 작은 자물쇠: form(0–2) → 유지(3–5 반복), break(6–8) 한 번. 이어하기·다시 그릴 때는 유지만(다시 재생 없음)
func _seal_badge(view: Control, mode: String) -> void:
	if view == null:
		return
	var old: TextureRect = view.get_meta("seal_badge") if view.has_meta("seal_badge") else null
	if mode == "off" or mode == "break":
		if old == null:
			return
		view.remove_meta("seal_badge")
		var tw: Tween = old.get_meta("tw")
		if tw != null and tw.is_valid():
			tw.kill()
		if mode == "off":
			old.queue_free()
			return
		var bt := old.create_tween()
		for k in [6, 7, 8]:
			bt.tween_callback(func() -> void: old.texture = _seal_tex[k])
			bt.tween_interval([0.045, 0.055, 0.070][k - 6])
		bt.tween_callback(old.queue_free)
		return
	if old != null:
		return
	if _seal_tex.is_empty():
		for k in range(9):
			_seal_tex.append(load(NB38_DIR + "card_seal/card_seal_%02d.png" % k))
	var u := view.size.x / 68.0
	var b := TextureRect.new()
	b.texture = _seal_tex[0 if mode == "form" else 3]
	b.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	b.size = Vector2(30, 30) * u
	b.position = Vector2(62.0 * u - b.size.x + 4.0 * u, 2.0 * u)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(b)
	view.set_meta("seal_badge", b)
	var t := b.create_tween()
	if mode == "form":
		for k in [0, 1, 2]:
			t.tween_callback(func() -> void: b.texture = _seal_tex[k])
			t.tween_interval([0.05, 0.05, 0.055][k])
	var hold := b.create_tween().set_loops()
	hold.pause()
	for k in [3, 4, 5]:
		hold.tween_callback(func() -> void: b.texture = _seal_tex[k])
		hold.tween_interval(0.14)
	t.tween_callback(hold.play)
	b.set_meta("tw", hold)


# ── 거완: 대기·준비·힘 풀림 벌 바꾸기와 힘 풀림 반응 ──
# 처음 만들 때·이어하기·보정 때 고를 벌: 강타 직전 내 차례면 준비(3번 맞았으면 힘 풀림), 그 밖에는 보통 대기
func _unwind_steady(i: int) -> String:
	var u := battle.unwind_info(i)
	if u.is_empty() or battle._resolving or battle.cycle_index(i) != int(u.strike):
		return "idle"
	return "weakened" if int(_shown.enemies[i].get("unwind", 0)) >= int(u.need) else "charged"


func _steady_set(sprite: AnimatedSprite2D, state: String) -> void:
	if not sprite.has_meta("steady_frames") or String(sprite.get_meta("steady")) == state:
		return
	var anim := sprite.animation
	var f := sprite.frame
	var playing := sprite.is_playing()
	sprite.set_meta("steady", state)
	sprite.set_meta("idle_masks", (sprite.get_meta("steady_masks") as Dictionary)[state])
	sprite.sprite_frames = (sprite.get_meta("steady_frames") as Dictionary)[state]
	sprite.animation = anim
	sprite.frame = f
	if playing:
		sprite.play(anim)
	_art_idle_mask(sprite)
	steady_log.append({"index": _enemy_sprites.find(sprite), "state": state, "f": Engine.get_process_frames()})


# 세 번째 직접 타격 뒤(피격·체력은 이미 보임): 움찔 1 → 2 → 힘 풀린 대기. 쓰러졌거나 새 동작이 세대를 올리면 멈춘다
func _art_stagger(sprite: AnimatedSprite2D) -> void:
	if not sprite.has_meta("steady_frames") or bool(sprite.get_meta("dying", false)):
		return
	var gen := _art_claim(sprite)
	sprite.set_meta("art_busy", true)
	_steady_set(sprite, "weakened")
	var ms: Array = _ea(sprite.get_meta("art")).actions.stagger_s
	_art_pose(sprite, "stagger", 1)
	if not await _art_hold(sprite, float(ms[1]), gen):
		return
	_art_pose(sprite, "stagger", 2)
	if not await _art_hold(sprite, float(ms[2]), gen):
		return
	sprite.set_meta("art_busy", false)
	if not bool(sprite.get_meta("dashing", false)) and not bool(sprite.get_meta("dying", false)):
		_set_enemy_anim(sprite, "idle")


# ── 소환사·소환수 연출 (실제 사건을 보일 때만 움직인다) ─────────────────────────────

# 소환: 손을 모음 → 앞 바닥으로 내밀며 놓는 프레임(2)에 실제 소환 사건의 두 마리가 함께 나타남 → 회복
func _anim_summon(index: int, ev: Dictionary) -> void:
	var sprite := _enemy_sprites[index]
	var acts: Dictionary = _ea(sprite.get_meta("art")).actions if _art_acts(sprite) else {}
	var gen := _art_claim(sprite) if not acts.is_empty() else 0
	if not acts.is_empty():
		sprite.set_meta("art_busy", true)
		var ms: Array = acts.summon_s
		_art_pose(sprite, "summon", 0)
		if await _art_hold(sprite, float(ms[0]), gen):
			_art_pose(sprite, "summon", 1)
			_sfx("cast", 0.7)
		if await _art_hold(sprite, float(ms[1]), gen):
			_art_pose(sprite, "summon", 2)
	_apply_event(ev)
	summon_log.append({"frame": Engine.get_process_frames(), "pose": "%s:%d" % [sprite.animation, sprite.frame], "spawned": (ev.spawned as Array).map(func(x): return String(x.iid))})
	if not acts.is_empty():
		_art_summon_out(sprite, gen)
	await _wait(0.32)
	if not _summon_explained and not (ev.spawned as Array).is_empty():
		_summon_explained = true
		_notice("먼저 처치하면 폭발하지 않습니다. 폭발은 방어로 막을 수 있습니다.", 4.5)


func _art_summon_out(sprite: AnimatedSprite2D, gen: int) -> void:
	var ms: Array = _ea(sprite.get_meta("art")).actions.summon_s
	if not await _art_hold(sprite, float(ms[2]), gen):
		return
	_art_pose(sprite, "summon", 3)
	if not await _art_hold(sprite, float(ms[3]), gen):
		return
	_art_pose(sprite, "summon", 4)
	if not await _art_hold(sprite, float(ms[4]), gen):
		return
	sprite.set_meta("art_busy", false)
	if not bool(sprite.get_meta("dying", false)):
		_set_enemy_anim(sprite, "idle")


# 소환된 개체를 화면에: 새 개체이므로 이전 동작·피격 콜백(세대)을 끊고 제자리·밝기·깊이를 새로. 작은 준비 그림 → 곧 부풀어 오른 대기
func _reveal_spawn(i: int, sp: Dictionary) -> void:
	var e: Dictionary = _shown.enemies[i]
	e.alive = true
	e.hp = int(sp.get("hp", 5))
	e.max = int(sp.get("max", 5))
	e.marks = 0
	e.supp = 0
	e.shield = 0
	var sprite := _enemy_sprites[i]
	sprite.set_meta("dying", false)
	sprite.set_meta("consumed", false)
	sprite.set_meta("dashing", false)
	sprite.visible = true
	sprite.modulate = Color(1, 1, 1, 0.0)
	sprite.z_index = 0
	sprite.position = Vector2(float(sprite.get_meta("home_x")), FEET_Y)
	var gen := _art_claim(sprite)
	if _art_acts(sprite):
		_art_pose(sprite, "ready", 0)
	create_tween().tween_property(sprite, "modulate:a", 1.0, 0.08)
	_vfx("magic", _enemy_torso(i), 0.55)
	_render_enemy(i, false)
	_spawn_prime(sprite, gen)


func _spawn_prime(sprite: AnimatedSprite2D, gen: int) -> void:
	if not await _art_hold(sprite, 0.18, gen):
		return
	if not bool(sprite.get_meta("dying", false)):
		_set_enemy_anim(sprite, "idle")


# 물탄: 준비 → 손바닥을 앞으로 내미는 프레임(2)에 기존 마력 핵(물빛)이 날아가고, 실제 맞는 순간은 부르는 쪽 사건 처리. 강한 10은 더 큰 핵·충격
func _art_cast_in(sprite: AnimatedSprite2D, events: Array, chart: P2NoteChart = null) -> void:
	var acts: Dictionary = _ea(sprite.get_meta("art")).actions
	var gen := _art_claim(sprite)
	sprite.set_meta("art_busy", true)
	var strong := events.any(func(e): return (String(e.kind) == "enemy_hit" and int(e.raw) >= 10) or (String(e.kind) == "enemy_hits_pending" and (e.hits as Array).any(func(x): return int(x) >= 10)))
	var ms: Array = acts.attack_s
	_art_pose(sprite, "attack", 0)
	if await _art_hold(sprite, float(ms[0]), gen):
		_art_pose(sprite, "attack", 1)
	_sfx("cast", 0.75 if strong else 0.95)
	if chart != null:
		await _chart_until(chart, 0, float(ms[1]) + (0.15 if strong else 0.13))
	if await _art_hold(sprite, float(ms[1]), gen):
		_art_pose(sprite, "attack", 2)
	var palm := sprite.position + (acts.contact_offset as Vector2) * sprite.scale.x
	cast_log.append({"class": String(sprite.get_meta("art")), "frame": "%s:%d" % [sprite.animation, sprite.frame], "socket": palm, "strong": strong})
	_art_cast_out(sprite, gen)
	await _core_shot(palm, _player_body() + Vector2(14, -4), 0.15 if strong else 0.13, 44.0 if strong else 28.0)
	if strong:
		_vfx("magic", _player_body(), 1.25)


func _art_cast_out(sprite: AnimatedSprite2D, gen: int, anim := "attack") -> void:
	var ms: Array = _ea(sprite.get_meta("art")).actions[anim + "_s"]
	if not await _art_hold(sprite, float(ms[2]), gen):
		return
	_art_pose(sprite, anim, 3)
	if not await _art_hold(sprite, float(ms[3]), gen):
		return
	_art_pose(sprite, anim, 4)
	if not await _art_hold(sprite, float(ms[4]), gen):
		return
	sprite.set_meta("art_busy", false)
	if not bool(sprite.get_meta("dying", false)):
		_set_enemy_anim(sprite, "idle")


# 소환수 폭발: 부풀어 오른 채 곧게 짧게 튀어 와서(굽은 길 없음), 실제 사건을 보이는 프레임에 방향 있는 물 터짐(1) → 물보라(2)
func _spawn_burst_in(sprite: AnimatedSprite2D) -> void:
	var acts: Dictionary = _ea(sprite.get_meta("art")).actions
	var gen := _art_claim(sprite)
	sprite.set_meta("art_busy", true)
	sprite.set_meta("dashing", true)
	_art_pose(sprite, "burst", 0)
	_sfx("enemy_swing", 1.3)
	var jet: Vector2 = (acts.contact_offset as Vector2) * sprite.scale.x
	var dest := _player_body().x + float(acts.reach) - jet.x
	var pg := _pass_begin(sprite, [])
	sprite.set_meta("pass_gen", pg)
	route_log.append({"actor": "maek_spawn", "from": sprite.position.x, "to": dest, "pass": pg})
	var dash := _route_tween(sprite, dest, 0.16, false)
	if dash.is_running():
		await dash.finished
	if int(sprite.get_meta("art_gen", 0)) != gen:
		return


func _spawn_winding(sprite: AnimatedSprite2D) -> bool:
	return sprite.has_meta("art") and String(sprite.get_meta("art")) == "maek_spawn" and sprite.animation == "burst" and sprite.frame == 0


func _spawn_contact(sprite: AnimatedSprite2D) -> void:
	var gen := int(sprite.get_meta("art_gen", 0))
	_art_pose(sprite, "burst", 1)
	_sfx("burst", 1.2)
	_spawn_splash(sprite, gen)


func _spawn_splash(sprite: AnimatedSprite2D, gen: int) -> void:
	var ms: Array = _ea(sprite.get_meta("art")).actions.burst_s
	if not await _art_hold(sprite, float(ms[1]), gen):
		return
	_art_pose(sprite, "burst", 2)
	sprite.set_meta("splashed", true)


# 소멸: 물보라 그림 그대로 잠깐 → 투명해지며 사라짐. 다음 소환 때 새 개체로 다시 쓰인다
func _spawn_consumed_fx(i: int) -> void:
	var sprite := _enemy_sprites[i]
	sprite.set_meta("consumed", true)
	sprite.set_meta("dying", true)
	(sprite.material as ShaderMaterial).set_shader_parameter("flow_amount", 0.0)
	var gen := int(sprite.get_meta("art_gen", 0))
	if not (sprite.animation == "burst" and sprite.frame == 2):
		_art_pose(sprite, "burst", 2)
	var t := create_tween()
	t.tween_interval(0.09)
	t.tween_property(sprite, "modulate:a", 0.0, 0.18)
	t.tween_callback(func() -> void:
		if is_instance_valid(sprite) and int(sprite.get_meta("art_gen", 0)) == gen and bool(sprite.get_meta("consumed", false)):
			sprite.visible = false
			sprite.z_index = 0
			sprite.position = Vector2(float(sprite.get_meta("home_x")), FEET_Y))


# 플레이어가 처치한 소환수: 움찔 → 낮은 물웅덩이 (폭발 그림과 다름, 대기 복귀 없음)
func _art_defeat(sprite: AnimatedSprite2D) -> void:
	var gen := _art_claim(sprite)
	sprite.set_meta("art_busy", false)
	_art_pose(sprite, "defeat", 0)
	var ms: Array = _ea(sprite.get_meta("art")).actions.defeat_s
	if await _art_hold(sprite, float(ms[0]), gen):
		_art_pose(sprite, "defeat", 1)


# 소환사가 쓰러져 전투가 끝나면 남은 소환수는 조용히 무너져 사라진다 (규칙 상태는 건드리지 않는 겉모습)
func _dismiss_spawns() -> void:
	if battle.player_hp() <= 0:
		return
	for i in range(_enemy_sprites.size()):
		if battle.is_spawn_slot(i) and bool(_shown.enemies[i].alive) and _art_acts(_enemy_sprites[i]):
			var sprite := _enemy_sprites[i]
			sprite.set_meta("dying", true)
			(sprite.material as ShaderMaterial).set_shader_parameter("flow_amount", 0.0)
			(_enemy_panels[i].root as Control).visible = false
			_art_defeat(sprite)
			var t := create_tween()
			t.tween_interval(0.25)
			t.tween_property(sprite, "modulate:a", 0.0, 0.3)
			summon_log.append({"dismiss": i})


# 돌아가기 전에 이 배우의 회복·피격이 끝나기를 기다린다(짧은 상한)
func _art_settle(sprite: AnimatedSprite2D) -> void:
	var t0 := Time.get_ticks_msec()
	while is_instance_valid(sprite) and bool(sprite.get_meta("art_busy", false)) and Time.get_ticks_msec() - t0 < 600:
		await get_tree().process_frame


func _add_art_shadow(sprite: AnimatedSprite2D) -> void:
	var a: Dictionary = _ea(sprite.get_meta("art"))
	var shadow := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(16):
		var t := TAU * i / 16.0
		pts.append(Vector2(cos(t) * float(a.shadow_rx) * _ks, sin(t) * 6.0) / sprite.scale.x)
	shadow.polygon = pts
	shadow.color = Color(0, 0, 0, 0.35)
	shadow.show_behind_parent = true
	sprite.add_child(shadow)
	_env_shadow(sprite)


func _process(delta: float) -> void:
	if _debug != null and _debug.visible and Engine.get_process_frames() % 30 == 0:
		_update_debug()
	if not _waves.is_empty():
		_tick_waves(delta)
	_tick_sd_player(delta)
	var wd := delta * _world_speed
	for sp in _enemy_sprites:
		if is_instance_valid(sp) and sp.has_meta("art"):
			_tick_enemy_art(sp, delta if _slow_keep.has(sp) else wd)
	_tick_pass(delta)
	_tick_env(wd)
	_tick_mana(wd)
	_tick_vignette(delta)
	_tick_backdrop(wd)
	if _amb != null:
		_amb.speed = _world_speed


# 배경 숨쉬기(배우는 그대로, 배경만 1~2px 정수 단위로 아주 천천히) · 심층 횃불 흔들림. 게임이 멈추면 함께 멈춘다
func _tick_backdrop(delta: float) -> void:
	_breath_t += delta
	var b := Vector2(roundf(sin(_breath_t * 0.42) * 2.0), roundf(sin(_breath_t * 0.29 + 1.3) * 1.0))
	if b != _breath:
		_breath = b
		if _bg_node != null:
			_bg_node.position = _breath
	for t in _torches:
		var f := 1.0 + 0.08 * sin(_breath_t * 9.0 + float(t[2])) + 0.05 * sin(_breath_t * 23.0 + float(t[2]) * 0.3)
		(t[0] as PointLight2D).energy = 0.45 * f
		(t[1] as Sprite2D).modulate.a = clampf(f, 0.0, 1.0)


# 맥 흐름은 살아 있는 실제 대기에서만: 돌진·맞는 반응·히트스톱·쓰러짐이면 끄고 시계를 멈춘다.
# 게임이 멈추면(저장 창·일시정지) _process가 돌지 않아 시계도 멈춘다. 흔들림 줄이기는 흐름을 멈추고 절반 세기로 둔다. 난수·저장과 무관
func _art_idle_mask(sprite: AnimatedSprite2D) -> void:
	if not is_instance_valid(sprite) or sprite.animation != "idle" or not sprite.has_meta("idle_masks"):
		return
	var masks: Array = sprite.get_meta("idle_masks")
	(sprite.material as ShaderMaterial).set_shader_parameter("maek_mask", masks[clampi(sprite.frame, 0, masks.size() - 1)])
	sprite.set_meta("mask_frame", sprite.frame)


func _tick_enemy_art(sp: AnimatedSprite2D, delta: float) -> void:
	var mat := sp.material as ShaderMaterial
	var a: Dictionary = _ea(sp.get_meta("art"))
	# 숨쉬기 대기: 흔들림 줄이기면 첫 장에 멈춰 둔다(공격·피격 자세는 그대로 보임)
	if a.has("idle_frames") and sp.animation == "idle" and not bool(sp.get_meta("dying", false)):
		if _reduce_motion:
			if sp.is_playing() or sp.frame != 0:
				sp.pause()
				sp.frame = 0
		elif not sp.is_playing():
			sp.play("idle")
	var alive := sp.visible and not bool(sp.get_meta("dying", false))
	var react: Tween = sp.get_meta("react_tw") if sp.has_meta("react_tw") else null
	var reacting := react != null and react.is_valid() and react.is_running()
	var idle := alive and sp.animation == "idle" and not bool(sp.get_meta("dashing", false)) and sp.speed_scale > 0.0 and not reacting
	var target := float(a.amount) * (0.5 if _reduce_motion else 1.0) if idle else 0.0
	var amt := float(mat.get_shader_parameter("flow_amount"))
	amt = move_toward(amt, target, delta * (12.0 if target < amt else 4.0)) if alive else 0.0
	mat.set_shader_parameter("flow_amount", amt)
	if idle and not _reduce_motion:
		var clock := float(sp.get_meta("flow_clock")) + delta
		sp.set_meta("flow_clock", clock)
		mat.set_shader_parameter("flow_time", clock)
	# 호흡도 살아 있는 실제 대기에서만. 히트스톱(speed_scale 0)에는 지금 모양을 그대로 두고, 대기로 돌아오면 0.1초에 걸쳐 되살린다
	var bw := float(sp.get_meta("breath_w"))
	if not alive or _reduce_motion or sp.animation != "idle" or bool(sp.get_meta("dashing", false)) or reacting:
		bw = 0.0
	elif sp.speed_scale > 0.0:
		bw = move_toward(bw, 1.0, delta * 10.0)
		mat.set_shader_parameter("breath_phase", _breath_phase(sp, a))
	sp.set_meta("breath_w", bw)
	mat.set_shader_parameter("breath_amount", float(sp.get_meta("breath_k")) * bw)
	var glow: Sprite2D = sp.get_meta("floor_glow") if sp.has_meta("floor_glow") else null
	if glow != null and is_instance_valid(glow):
		var ga := float(AV7.maek_floor.alpha) * (amt / float(a.amount)) * (0.85 + 0.15 * sin(float(sp.get_meta("flow_clock")) * 2.4))
		glow.visible = _new_fx and alive and ga > 0.005
		glow.position = Vector2(sp.position.x + 10.0, FEET_Y)
		glow.modulate.a = ga


func _breath_off(sprite: AnimatedSprite2D) -> void:
	(sprite.material as ShaderMaterial).set_shader_parameter("breath_amount", 0.0)
	sprite.set_meta("breath_w", 0.0)


# 여섯 장 몸은 그 대기 박자 그대로(첫 장 가운데가 가장 내쉰 때), 한 장 몸은 흐름 시계로 1.8초 주기. 자리마다 조금 어긋나게
func _breath_phase(sp: AnimatedSprite2D, a: Dictionary) -> float:
	var cyc := float(sp.get_meta("flow_clock")) / 1.8 + 0.23 * _enemy_sprites.find(sp)
	if (a.get("idle_frames", []) as Array).size() > 1:
		var ms: Array = a.idle_ms
		var t := sp.frame_progress * float(ms[sp.frame]) - float(ms[0]) * 0.5
		for k in sp.frame:
			t += float(ms[k])
		cyc = t / float(ms.reduce(func(acc, v): return acc + v, 0))
	return 0.5 - 0.5 * cos(TAU * cyc)


func _spawn_enemies() -> void:
	for s in _enemy_sprites:
		if s.has_meta("floor_glow") and is_instance_valid(s.get_meta("floor_glow")):
			(s.get_meta("floor_glow") as Node).queue_free()
		s.queue_free()
	_enemy_sprites.clear()
	var slots: Array = _slots()
	for m in battle.monsters:
		var d: Dictionary = P2Catalog.ENEMIES[battle.roles[m.index]]
		var sprite := AnimatedSprite2D.new()
		var art := _enemy_art_key(m.index)
		if art != "":
			_dress_enemy_art(sprite, art)
		else:
			sprite.sprite_frames = _enemy_frames(m.variant)
			sprite.centered = false
			sprite.flip_h = true
			var big := int(m.variant.idle_frame_size) >= 64
			var extra := float(d.get("scale", 1.0))
			sprite.scale = Vector2.ONE * ACTOR_SCALE * extra * (0.75 if big else 1.0) * _ks
			if big:
				sprite.set_meta("foot_pad", 3.0)
			sprite.self_modulate = d.get("tint", Color.WHITE)
		sprite.position = Vector2(float(slots[m.index]) + 120.0, FEET_Y)
		sprite.modulate.a = 0.0
		_set_enemy_anim(sprite, "idle")
		# 방패병: 처음 만들 때·이어하기는 저장된(보인) 방패 값으로 벌만 고른다 — 이미 0이면 놓침을 다시 재생하지 않음
		_shield_set(sprite, int(_shown.enemies[m.index].get("shield", 0)) > 0, "")
		if sprite.has_meta("steady_frames"):
			_steady_set(sprite, _unwind_steady(m.index))
		_actors.add_child(sprite)
		if art != "":
			_add_art_shadow(sprite)
		else:
			_add_shadow(sprite, 1.4 if battle.roles[m.index] in ["breaker", "elite", "boss", "guard_h", "leader", "hard_boss", "x_boss", "ruins_boss", "shieldbearer", "maek_summoner_low"] else 0.9)
		_enemy_sprites.append(sprite)
		sprite.set_meta("home_x", float(slots[m.index]))
		if not _shown.enemies[m.index].alive:
			sprite.visible = false
			continue
		var tween := create_tween()
		tween.tween_property(sprite, "position:x", float(slots[m.index]), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).set_delay(0.08 * m.index)
		tween.parallel().tween_property(sprite, "modulate:a", 1.0, 0.25).set_delay(0.08 * m.index)


# ── 화면(UI) ─────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	_ui = Control.new()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_ui)
	_uip = P2Pixel.attach(_ui, Callable(), true)
	_uipx = P2Pixel.attach(_ui, Callable(), true, FX_PIX, FX_PEN)
	_uipa = P2Pixel.attach(_ui, Callable(), true, FX_PIX, FX_PEN_ADD)
	P2Vfx.route(_ui, _uipx, _uipa)
	_build_hud()
	_zone_self = _zone(SELF_ZONE, "나에게 사용")
	_zone_all = _zone(ALL_ZONE, "모든 적에게")
	_panels_root = Control.new()
	_panels_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panels_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_panels_root)
	_build_player_status()
	# 안내 줄은 없다: 규칙은 올린 카드, 예상 결과는 대상 옆 배지, 필요한 입력·실패만 손패 위 짧은 안내
	_guide = _label("", F, C_TEXT)
	_guide.visible = false
	_ui.add_child(_guide)
	_prompt_box = _ui_patch("prompt_frame", Vector2(HINT_RECT.size.x, 42), [4, 3, 4, 3])
	_prompt_box.position = HINT_RECT.position
	_prompt_box.visible = false
	_ui.add_child(_prompt_box)
	_prompt_label = _label("", F, C_INK, HINT_RECT.size.x - 56)
	_prompt_label.position = Vector2(22, 9)
	_prompt_label.size = Vector2(HINT_RECT.size.x - 56, 24)
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# 한글은 띄어쓰기에서만 줄을 바꾼다(낱말 중간에서 끊기지 않게)
	_prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt_box.add_child(_prompt_label)
	_prompt_close = Button.new()
	_prompt_close.text = "×"
	_prompt_close.flat = true
	_prompt_close.focus_mode = Control.FOCUS_NONE
	_prompt_close.tooltip_text = tr("알림 닫기")
	P2Ui.crisp(_prompt_close, P2Ui.T_BODY)
	_prompt_close.add_theme_color_override("font_color", C_INK)
	_prompt_close.position = Vector2(HINT_RECT.size.x - 34, 8)
	_prompt_close.size = Vector2(24, 24)
	_prompt_close.pressed.connect(func() -> void:
		_notice_until = 0
		_show_prompt_text(_prompt_text, false))
	_prompt_close.visible = false
	_prompt_box.add_child(_prompt_close)
	# 손패 받침선: 실제 손패 폭에 맞춘다 (_fit_hand_rail)
	_hand_rail = _ui_patch("hand_rail", Vector2(400, 27), [8, 2, 8, 2])
	_hand_rail.position = Vector2(FAN_LEFT, REST_TOP - 22)
	_ui.add_child(_hand_rail)
	_hand_root = Control.new()
	_hand_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hand_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_hand_root)
	_big_root = Control.new()
	_big_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_big_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_big_root)
	_hand_hit = Control.new()
	_hand_hit.position = Vector2(HAND_LEFT - 5, HAND_HIT_TOP)
	_hand_hit.size = Vector2(HAND_RIGHT - HAND_LEFT + 10, 720 - HAND_HIT_TOP)
	_hand_hit.mouse_filter = Control.MOUSE_FILTER_STOP
	_hand_hit.gui_input.connect(_on_hand_input)
	_hand_hit.mouse_exited.connect(_on_hand_exit)
	_ui.add_child(_hand_hit)
	# 왼쪽 아래: 마나 구슬 · 더미 세 칸 (손패 옆)
	_build_mana_orb()
	_build_piles()
	_mull_button = _button("손패 교체", Vector2(578, 447), Vector2(124, 40), F)
	_mull_button.tooltip_text = "선택 II: 카드를 내기 전에 첫 손패를 최대 2장 바꿀 수 있습니다. 더미에서 먼저 뽑고, 고른 카드는 더미 맨 아래로 갑니다."
	_mull_button.visible = false
	_mull_button.pressed.connect(_toggle_mulligan)
	_ui.add_child(_mull_button)
	# 오른쪽: 물약 · 취소 · 사용 · 다가오는 공격. 턴 종료는 손패 위 가운데(누르고 바로 전장으로 손이 간다)
	_potion_button = _round_button(Vector2(866, 8))
	_potion_button.pressed.connect(func() -> void: _use_potion("hp_potion"))
	_ui.add_child(_potion_button)
	_mana_potion_button = _round_button(Vector2(978, 8))
	_mana_potion_button.pressed.connect(func() -> void: _use_potion("mana_potion"))
	_ui.add_child(_mana_potion_button)
	_cancel_button = _button("취소 [Esc]", Vector2(1146, 520), Vector2(124, 38), F)
	_cancel_button.visible = false
	_cancel_button.pressed.connect(_cancel_selection)
	_ui.add_child(_cancel_button)
	_use_button = _button("사용 [Enter]", Vector2(1146, 564), Vector2(124, 52), F)
	_use_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_use_button.visible = false
	_use_button.pressed.connect(_confirm_selected)
	_ui.add_child(_use_button)
	for b in [_mull_button, _cancel_button, _use_button]:
		_skin_button(b)
	_seal_label = _label("", F, C_BLOCK)
	_seal_label.position = Vector2(1068, 594)
	_seal_label.size = Vector2(196, 22)
	_seal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_seal_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_seal_label.add_theme_constant_override("outline_size", 4)
	_ui.add_child(_seal_label)
	# 턴 종료: 위쪽 "N턴 · 누구 차례" 바로 밑 가운데(손패 위는 판정 오차 막대 자리)
	_end_button = _button("턴 종료 [E]", Vector2(562, 82), Vector2(156, 42), 20)
	_skin_button(_end_button, true)
	_end_button.tooltip_text = "턴 종료 (E): 살아 있는 적이 한 번씩 행동합니다"
	_end_button.pressed.connect(_on_end_turn_pressed)
	_ui.add_child(_end_button)
	_build_incoming()
	_aim_root = Control.new()
	_aim_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_aim_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_aim_root)
	_aim_fx = P2AimArrow.new()
	_aim_fx.visible = false
	_aim_root.add_child(_aim_fx)
	_numbers = Control.new()
	_numbers.set_anchors_preset(Control.PRESET_FULL_RECT)
	_numbers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_numbers)
	_banner = _label("", 36, C_TEXT)
	_banner.set_anchors_preset(Control.PRESET_FULL_RECT)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner.position.y = -120
	_banner.add_theme_color_override("font_outline_color", Color.BLACK)
	_banner.add_theme_constant_override("outline_size", 5)
	_banner.visible = false
	_ui.add_child(_banner)
	# 올린 카드는 버튼·안내판 위에(창 아래에) 그린다. 입력은 통과시켜 손패 입력 칸이 그대로 받는다
	_ui.move_child(_big_root, _ui.get_child_count() - 1)
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_overlay)
	_debug = _label("", F, Color(0.8, 1, 0.8))
	_debug.position = Vector2(12, 200)
	_debug.visible = false
	_ui.add_child(_debug)


# 끌기 놓을 곳 표시: 나에게(방어·뽑기·연료화) / 모든 적에게(광역). 끌 때만 보인다
func _zone(rect: Rect2, text: String) -> Panel:
	var z := Panel.new()
	z.position = rect.position
	z.size = rect.size
	var s := StyleBoxFlat.new()
	s.bg_color = Color(1, 0.85, 0.45, 0.05)
	s.border_color = Color(1, 0.85, 0.45, 0.45)
	s.set_border_width_all(2)
	s.set_corner_radius_all(10)
	z.add_theme_stylebox_override("panel", s)
	z.mouse_filter = Control.MOUSE_FILTER_IGNORE
	z.visible = false
	var l := _label(text, F, C_GOLD)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	l.size = Vector2(rect.size.x, 24)
	l.position = Vector2(0, rect.size.y - 28)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	z.add_child(l)
	z.set_meta("style", s)
	_ui.add_child(z)
	return z


# 위쪽: 화면 폭의 얇은 돌 띠 하나 (직업 · 체력 · 금화 · 회복약 · 전투 이름 · 덱 · 설정) + 바로 아래 차례 한 줄.
# 유물은 가진 것만 띠 아래 왼쪽에. 주인공 체력·방어는 발밑에 둔다(배우를 따라감)
func _build_hud() -> void:
	_ui.add_child(_ui_rect("top_left", Vector2.ZERO))
	var strip := TextureRect.new()
	strip.texture = _ui_tex("top_strip")
	strip.stretch_mode = TextureRect.STRETCH_TILE
	strip.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	strip.position = Vector2(24, 0)
	strip.size = Vector2(1232, 42)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(strip)
	_ui.add_child(_ui_rect("top_right", Vector2(1256, 0)))
	_class_label = _label("", F, C_TEXT)
	_class_label.position = Vector2(14, 8)
	_class_label.size = Vector2(214, 24)
	_class_label.clip_text = true
	_ui.add_child(_class_label)
	_portrait_button = Button.new()
	_portrait_button.flat = true
	_portrait_button.focus_mode = Control.FOCUS_NONE
	_portrait_button.position = Vector2(0, 0)
	_portrait_button.size = Vector2(222, 42)
	_portrait_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_portrait_button.pressed.connect(_toggle_info)
	_ui.add_child(_portrait_button)
	for spec in [["hp", "hud_heart_compact", 232.0], ["gold", "hud_coin_compact", 356.0], ["potion", "potion_health_compact", 800.0], ["mana_potion", "potion_mana_compact", 912.0]]:
		var ic := _ui_rect(String(spec[1]), Vector2(float(spec[2]), 3))
		ic.mouse_filter = Control.MOUSE_FILTER_PASS
		_ui.add_child(ic)
		var l := _label("", F, C_TEXT)
		l.position = Vector2(float(spec[2]) + 40, 8)
		l.size = Vector2(80 if spec[0] != "potion" and spec[0] != "mana_potion" else 24, 24)
		_ui.add_child(l)
		_top_labels[spec[0]] = l
		l.set_meta("icon", ic)
	_turn_banner = Control.new()
	_turn_banner.position = Vector2(520, 0)
	_turn_banner.size = Vector2(240, 42)
	_turn_banner.mouse_filter = Control.MOUSE_FILTER_PASS
	_ui.add_child(_turn_banner)
	_hud_title = _label("", F, C_TEXT)
	_hud_title.position = Vector2(0, 8)
	_hud_title.size = Vector2(240, 24)
	_hud_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_title.clip_text = true
	_turn_banner.add_child(_hud_title)
	_hud_phase = _label("", F, C_TEXT)
	_hud_phase.position = Vector2(440, 54)
	_hud_phase.size = Vector2(400, 24)
	_hud_phase.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_phase.add_theme_color_override("font_outline_color", Color.BLACK)
	_hud_phase.add_theme_constant_override("outline_size", 4)
	_ui.add_child(_hud_phase)
	_turn_marks = [_ui_rect("turn_left", Vector2(0, 52)), _ui_rect("turn_right", Vector2(0, 52))]
	for mk in _turn_marks:
		_ui.add_child(mk)
	_menu_button = Button.new()
	_menu_button.flat = true
	_menu_button.focus_mode = Control.FOCUS_NONE
	_menu_button.position = Vector2(1228, 3)
	_menu_button.size = Vector2(36, 36)
	_menu_button.tooltip_text = tr("메뉴 (Esc): 흔들림 설정 · 전투 정보 · 후퇴 · 종료")
	var gear := P2Ui.tex_icon(load(P2Ui.GUI2X + "Mini icons/Icon_19.png"), 28)
	gear.position = Vector2(4, 4)
	_menu_button.add_child(gear)
	_menu_button.pressed.connect(_toggle_menu)
	_ui.add_child(_menu_button)
	# 유물: 위 띠 오른쪽(설정 앞)에 칸 순서대로. 띠 아래 왼쪽은 안내 칸 자리로 비워 둔다
	_hud_relics = HBoxContainer.new()
	_hud_relics.position = Vector2(1022, 3)
	_hud_relics.add_theme_constant_override("separation", 2)
	_ui.add_child(_hud_relics)
	_trait_icon = P2Ui.tex_icon(null, 30)
	_trait_icon.position = Vector2(168, 6)
	_ui.add_child(_trait_icon)
	_trait_count = _label("", 14, C_TEXT)
	_trait_count.position = Vector2(200, 12)
	_trait_count.size = Vector2(24, 18)
	_trait_count.add_theme_color_override("font_outline_color", Color.BLACK)
	_trait_count.add_theme_constant_override("outline_size", 4)
	_trait_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_trait_count)
	# 주인공 발밑: 체력 막대 + 방어 표식 (배우의 집 위치를 따라간다)
	var hx := _home_x - 80.0
	_hud_hp_bar = _ui_bar(Vector2(hx, FEET_Y + 16), 160)
	_hud_hp_bar.max_value = int(_run_info.max_hp)
	_ui.add_child(_hud_hp_bar)
	_hud_hp_label = _label("", F, C_TEXT)
	_hud_hp_label.position = _hud_hp_bar.position + Vector2(0, -1)
	_hud_hp_label.size = _hud_hp_bar.size
	_hud_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hud_hp_label.add_theme_color_override("font_outline_color", Color("#0e0c20"))
	_hud_hp_label.add_theme_constant_override("outline_size", 4)
	_ui.add_child(_hud_hp_label)
	_block_icon = _ui_rect("block_badge", Vector2(hx + 168, FEET_Y + 9))
	_block_icon.mouse_filter = Control.MOUSE_FILTER_STOP
	_ui.add_child(_block_icon)
	_hud_block = _label("", F, C_BLOCK)
	_hud_block.position = Vector2(hx + 208, FEET_Y + 15)
	_hud_block.size = Vector2(60, 24)
	_hud_block.add_theme_color_override("font_outline_color", Color.BLACK)
	_hud_block.add_theme_constant_override("outline_size", 4)
	_ui.add_child(_hud_block)
	_player_badge = _label("", F, C_BLOCK)
	_player_badge.visible = false
	_ui.add_child(_player_badge)
	_prep_label = _label("", F, C_CRIT)
	_prep_label.visible = false
	_ui.add_child(_prep_label)


# 조각 하나를 k배 최근접으로 키운 텍스처 (나인패치 여백은 원본 px × k). 전투마다 다시 만들지 않게 모아 둔다
func _ui_tex(id: String, k := 3) -> Texture2D:
	var key := "%s@%d" % [id, k]
	if not _uitex.has(key):
		var img := (load(UIB + id + ".png") as Texture2D).get_image()
		img.resize(img.get_width() * k, img.get_height() * k, Image.INTERPOLATE_NEAREST)
		_uitex[key] = ImageTexture.create_from_image(img)
	return _uitex[key]


func _ui_rect(id: String, pos: Vector2, k := 3) -> TextureRect:
	var r := TextureRect.new()
	r.texture = _ui_tex(id, k)
	r.position = pos
	r.size = r.texture.get_size()
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


# 위 띠의 작은 동그라미 사용 버튼(글자 대신 +). 누를 수 없으면 흐리게
func _round_button(pos: Vector2) -> Button:
	var b := Button.new()
	b.position = pos
	b.size = Vector2(26, 26)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.draw.connect(func() -> void:
		var c := Color(0.45, 0.42, 0.4) if b.disabled else (Color("#ffe9a8") if b.is_hovered() else C_GOLD)
		var o := Vector2(0, 1) if b.button_pressed or (b.is_hovered() and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)) else Vector2.ZERO
		b.draw_rect(Rect2(Vector2(7, 12) + o, Vector2(12, 2)), c)
		b.draw_rect(Rect2(Vector2(12, 7) + o, Vector2(2, 12)), c))
	for st in [["normal", Color(0.12, 0.08, 0.06), C_GOLD], ["hover", Color(0.22, 0.15, 0.08), Color("#ffe9a8")], ["pressed", Color(0.3, 0.2, 0.08), Color.WHITE],
			["disabled", Color(0.1, 0.09, 0.09), Color(0.4, 0.38, 0.36)]]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = st[1]
		sb.border_color = st[2]
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(13)
		sb.anti_aliasing = false
		b.add_theme_stylebox_override(String(st[0]), sb)
	return b


# 돌 틀 창(설정·전투 정보·확인): 화면을 어둡게 덮고 그 위에 어두운 돌 틀. 안쪽 칸을 돌려준다(옛 P2Ui.panel과 같은 구조)
func _stone_panel(parent: Control, pos: Vector2, size: Vector2, accent := C_GOLD) -> Panel:
	var d := ColorRect.new()
	d.color = Color(0, 0, 0, 0.55)
	d.set_anchors_preset(Control.PRESET_FULL_RECT)
	d.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(d)
	var frame := _ui_patch("tooltip_frame", size, [5, 5, 5, 5])
	frame.position = pos
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	d.add_child(frame)
	var line := ColorRect.new()
	line.color = Color(accent, 0.6)
	line.position = Vector2(18, 44)
	line.size = Vector2(size.x - 36, 2)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(line)
	var p := Panel.new()
	p.position = Vector2(8, 6)
	p.size = size - Vector2(16, 12)
	p.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	frame.add_child(p)
	return p


func _skin_children(p: Node) -> void:
	for c in p.get_children():
		if c is Button:
			_skin_button(c as Button)


func _ui_patch(id: String, size: Vector2, m: Array, k := 3) -> NinePatchRect:
	var n := NinePatchRect.new()
	n.texture = _ui_tex(id, k)
	n.patch_margin_left = int(m[0]) * k
	n.patch_margin_top = int(m[1]) * k
	n.patch_margin_right = int(m[2]) * k
	n.patch_margin_bottom = int(m[3]) * k
	n.size = size
	n.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return n


func _ui_style(id: String, m: Array, tint := Color.WHITE) -> StyleBoxTexture:
	var st := StyleBoxTexture.new()
	st.texture = _ui_tex(id)
	st.texture_margin_left = int(m[0]) * 3
	st.texture_margin_top = int(m[1]) * 3
	st.texture_margin_right = int(m[2]) * 3
	st.texture_margin_bottom = int(m[3]) * 3
	st.modulate_color = tint
	return st


# 돌 틀 버튼: 보통·올림·누름·막힘. 턴 종료는 전용 조각 네 장, 나머지(물약·취소·사용·손패 교체)는 안내 틀 하나를 밝기만 바꿔 쓴다
func _skin_button(b: Button, end_turn := false) -> void:
	if end_turn:
		var m := [10, 3, 5, 3]
		for pair in [["normal", "end_turn_normal"], ["hover", "end_turn_hover"], ["pressed", "end_turn_pressed"], ["disabled", "end_turn_disabled"]]:
			var st := _ui_style(String(pair[1]), m)
			st.content_margin_left = 33.0
			b.add_theme_stylebox_override(String(pair[0]), st)
	else:
		var m2 := [4, 3, 4, 3]
		b.add_theme_stylebox_override("normal", _ui_style("prompt_frame", m2))
		b.add_theme_stylebox_override("hover", _ui_style("prompt_frame", m2, Color(1.3, 1.3, 1.35)))
		b.add_theme_stylebox_override("pressed", _ui_style("prompt_frame", m2, Color(0.8, 0.8, 0.85)))
		b.add_theme_stylebox_override("disabled", _ui_style("prompt_frame", m2, Color(0.75, 0.75, 0.75, 0.7)))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", C_TEXT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", C_GOLD)
	b.add_theme_color_override("font_disabled_color", Color(0.6, 0.58, 0.56))
	b.add_theme_color_override("font_outline_color", Color("#0e0c20"))
	b.add_theme_constant_override("outline_size", 3)


# 체력 막대 = 돌 틀(나인패치) + 반복 채움. 값은 기존처럼 ProgressBar.value로 움직이고(_tween_bar), 채움 폭이 그 값을 따른다
func _ui_bar(pos: Vector2, w: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.position = pos
	bar.size = Vector2(w, 21)
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	bar.add_theme_stylebox_override("fill", StyleBoxEmpty.new())
	bar.add_child(_ui_patch("hp_frame", Vector2(w, 21), [3, 2, 3, 2]))
	var empty := ColorRect.new()
	empty.color = Color(0.07, 0.05, 0.07)
	empty.position = Vector2(9, 6)
	empty.size = Vector2(w - 18, 9)
	empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(empty)
	var trail := ColorRect.new()
	trail.color = Color("#f2c461")
	trail.position = Vector2(9, 6)
	trail.size = Vector2(0, 9)
	trail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(trail)
	var fill := TextureRect.new()
	fill.texture = _ui_tex("hp_fill")
	fill.stretch_mode = TextureRect.STRETCH_TILE
	fill.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.position = Vector2(9, 6)
	fill.size = Vector2(w - 18, 9)
	bar.add_child(fill)
	var sync := func(v: float) -> void:
		var nw := floorf((w - 18.0) * clampf(v / maxf(1.0, bar.max_value), 0.0, 1.0) / 3.0) * 3.0
		fill.size.x = nw
		fill.visible = nw > 0.0
		var old: Tween = trail.get_meta("tw") if trail.has_meta("tw") else null
		if old != null and old.is_valid():
			old.kill()
		if nw >= trail.size.x:
			trail.size.x = nw
		else:
			var tt := trail.create_tween()
			tt.tween_interval(0.35)
			tt.tween_property(trail, "size:x", nw, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			trail.set_meta("tw", tt)
	bar.value_changed.connect(sync)
	bar.set_meta("sync", sync)
	return bar


# 체력 막대: 각진 픽셀 느낌 (둥근 모서리 없음, 어두운 테두리)
func _bar_style(fill: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = Color(0.08, 0.05, 0.06)
	s.set_border_width_all(2)
	return s


# 원본 2x 틀 한 장을 나인패치로 (모서리·끝 장식은 원래 크기, 가운데만 늘림)
func _patch(file: String, size: Vector2, m: Array, tile := false) -> NinePatchRect:
	var n := NinePatchRect.new()
	n.texture = load(P2Ui.GUI2X + file)
	n.patch_margin_left = int(m[0])
	n.patch_margin_top = int(m[1])
	n.patch_margin_right = int(m[2])
	n.patch_margin_bottom = int(m[3])
	if tile:
		n.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE_FIT
	n.size = size
	n.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return n


# 잎 장식 주 틀 (안쪽은 불투명한 차분한 바탕). 높이 76 이상에서만 쓴다
func _frame(rect: Rect2) -> Panel:
	var p := Panel.new()
	p.position = rect.position
	p.size = rect.size
	p.add_theme_stylebox_override("panel", P2Ui.style("leaf"))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


# 맥 수조: 빈 안쪽 → 물 한 장(가면으로 자르고 셰이더로 수위·흐름) → 고정 틀 → 고정 유리 반사 → 숫자.
# 수위는 실제 마나 비율로 0.2초 따라가고, 바뀔 때 수면이 1px 남짓 기울었다 가라앉는다. 카드 예상 소모는 옆에 따로(실제 수위는 그대로)
func _build_mana_orb() -> void:
	var title := _label("마나", F, Color("#9fd4ff"))
	title.position = Vector2(MANA_ORB.x + 11, MANA_ORB.y - 24)
	title.size = Vector2(144, 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 4)
	_ui.add_child(title)
	var back := _ui_rect("mana_back", MANA_ORB)
	back.mouse_filter = Control.MOUSE_FILTER_STOP
	_ui.add_child(back)
	_mana_frame = back
	_mana_water = TextureRect.new()
	_mana_water.texture = load(UIB + "mana_water.png")
	_mana_water.position = MANA_ORB
	_mana_water.size = Vector2(144, 144)
	_mana_water.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_mana_water.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load(UIB + "mana_water.gdshader")
	mat.set_shader_parameter("mask_tex", load(UIB + "mana_mask.png"))
	_mana_water.material = mat
	_ui.add_child(_mana_water)
	_ui.add_child(_ui_rect("mana_frame", MANA_ORB))
	_ui.add_child(_ui_rect("mana_reflection", MANA_ORB))
	_mana_label = _label("", 24, Color.WHITE)
	_mana_label.position = MANA_ORB + Vector2(11, 2)
	_mana_label.size = Vector2(144, 144)
	_mana_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mana_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_mana_label.add_theme_color_override("font_outline_color", Color("#16304f"))
	_mana_label.add_theme_constant_override("outline_size", 4)
	_ui.add_child(_mana_label)
	_mana_tick = _ui_rect("mana_cost_tick", MANA_ORB + Vector2(104, -26))
	_mana_tick.visible = false
	_ui.add_child(_mana_tick)
	_mana_pred = _label("", F, C_GOLD)
	_mana_pred.position = MANA_ORB + Vector2(124, -27)
	_mana_pred.size = Vector2(32, 24)
	_mana_pred.add_theme_color_override("font_outline_color", Color.BLACK)
	_mana_pred.add_theme_constant_override("outline_size", 4)
	_ui.add_child(_mana_pred)


# 더미 세 칸: 뽑을 · 버린 · 소진. 마우스를 올리면 목록, 누르면 전투 정보(Tab)
func _build_piles() -> void:
	_pile_tiles.clear()
	var names := ["뽑기", "버림", "소진"]
	var icons := ["pile_draw", "pile_discard", "pile_exhaust"]
	for k in range(3):
		var pos := Vector2(18 + k * 56, PILES_Y)
		var tile := _ui_rect(icons[k], pos)
		tile.mouse_filter = Control.MOUSE_FILTER_STOP
		tile.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_toggle_info())
		_ui.add_child(tile)
		var n := _label("0", F, Color.WHITE)
		n.position = pos + Vector2(0, 48)
		n.size = Vector2(48, 22)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n.add_theme_color_override("font_outline_color", Color("#0e0c20"))
		n.add_theme_constant_override("outline_size", 4)
		_ui.add_child(n)
		var cap := _label(names[k], 12, C_DIM)
		cap.position = pos + Vector2(-4, 70)
		cap.size = Vector2(56, 18)
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap.add_theme_color_override("font_outline_color", Color.BLACK)
		cap.add_theme_constant_override("outline_size", 3)
		_ui.add_child(cap)
		tile.set_meta("count", n)
		_pile_tiles.append(tile)


# 주인공 머리 위: 지금 켜진 상태 (방어·반격·독·주술·준비·막고 치기) — 아이콘 + 수치.
# 예상 변화는 머리 오른쪽 빈 무대의 배지 (실제 상태와 따로, 적 정보 칸과 겹치지 않음)
func _build_player_status() -> void:
	_player_status = HBoxContainer.new()
	_player_status.alignment = BoxContainer.ALIGNMENT_CENTER
	_player_status.add_theme_constant_override("separation", 6)
	_player_status.position = Vector2(_player_body().x - 160, _player_head_y() - 36)
	_player_status.size = Vector2(320, 32)
	_player_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_player_status)
	_player_pred = _ui_patch("tooltip_frame", Vector2(284, 34), [5, 5, 5, 5])
	_player_pred.position = Vector2(_player_body().x + 46, _player_head_y() - 22)
	_player_pred.visible = false
	if _env != null:
		# 200px 몸에서는 머리 위가 HUD·안내 띠와 겹친다: 상태 줄과 마나 예상 칸을 머리 오른쪽 빈 무대에 둔다
		_player_status.alignment = BoxContainer.ALIGNMENT_BEGIN
		_player_status.position = Vector2(_player_body().x + 72, 198)
		_player_status.size.x = 160
		_player_pred.position = Vector2(_player_body().x + 72, 162)
	_player_status.set_meta("base_pos", _player_status.position)
	_player_pred.set_meta("base_pos", _player_pred.position)
	_ui.add_child(_player_pred)
	var l := _label("", F, C_INK, 252)
	l.position = Vector2(16, 5)
	l.size = Vector2(252, 24)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_player_pred.add_child(l)
	_player_pred.set_meta("label", l)


# 상태 하나: 상태 아이콘 조각(12px × 3) + 수치. 있을 때만 만든다
func _chip(icon: String, text: String, color: Color, tip: String) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 2)
	h.mouse_filter = Control.MOUSE_FILTER_STOP
	h.tooltip_text = tip
	var ic := TextureRect.new()
	ic.texture = _ui_tex(icon)
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(ic)
	var l := _label(text, F, color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.custom_minimum_size.y = 36
	h.add_child(l)
	return h


func _box(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	return P2Ui.box(bg, border, width)


func _label(text: String, size: int, color: Color, wrap := 0.0) -> Label:
	return P2Ui.text(text, size, color, wrap)


func _button(text: String, pos: Vector2, size: Vector2, font_size: int) -> Button:
	return P2Ui.crisp(P2Ui.button(text, pos, size), font_size) as Button


func _icon_tex(tex: Texture2D, size: float) -> TextureRect:
	var t := P2Ui.tex_icon(tex, size)
	t.stretch_mode = TextureRect.STRETCH_SCALE
	return t


# ── 소리 / VFX / 숫자 ───────────────────────────────────────────────────────

func _preload_feedback_assets() -> void:
	for key in SFX:
		_sfx_streams[key] = load(SFX_DIR + SFX[key][0])
	for key in VFX:
		_vfx_frames_for(key)
	for key in ARCANE:
		_arcane(key)
	for tier in CRESCENT:
		_crescent_frames_for(tier)
	for key in AV5_CONTACT:
		_av5_frames_for(key)


func _av5_frames_for(key: String) -> SpriteFrames:
	if not _av5_frames.has(key):
		var ms: Array = AV5_CONTACT[key].ms
		var frames := SpriteFrames.new()
		frames.remove_animation("default")
		frames.add_animation("play")
		frames.set_animation_speed("play", 1000.0)
		frames.set_animation_loop("play", false)
		for i in range(ms.size()):
			frames.add_frame("play", load(AV5_DIR + "%s/%s_%02d.png" % [key, key, i]), float(ms[i]))
		_av5_frames[key] = frames
	return _av5_frames[key]


# 접촉 효과 하나를 실제 접촉 자리(기준점 320,320)에 틀고 끝나면 스스로 사라진다 (기다리지 않음)
func _contact_fx(key: String, pos: Vector2, behind := false, scale_mult := 1.0) -> AnimatedSprite2D:
	var c := AnimatedSprite2D.new()
	c.sprite_frames = _av5_frames_for(key)
	c.centered = false
	c.offset = -Vector2(320, 320)
	c.scale = Vector2.ONE * float(AV5_CONTACT[key].scale) * scale_mult
	c.position = pos
	c.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	(_fx_back if behind and _fx_back != null else _fx).add_child(c)
	c.play("play")
	c.frame = int(AV5_CONTACT[key].start)
	var residue := int(AV5_CONTACT[key].get("residue", 99))
	c.frame_changed.connect(func() -> void:
		if c.frame >= residue:
			c.modulate.a = RESIDUE_ALPHA)
	c.animation_finished.connect(c.queue_free)
	contact_log.append({"key": key, "pos": pos, "ms": Time.get_ticks_msec(), "behind": behind})
	return c


func _contact_fx_later(key: String, pos: Vector2, delay: float, behind := false) -> void:
	var token := _action_token
	await _wait(delay)
	if is_inside_tree() and token == _action_token:
		_contact_fx(key, pos, behind)


# 검날 잔상·광택: 배우의 지금 동작·프레임에 맞는 그림만 보이고, 그 밖(대기·시전·피격·쓰러짐)에는 바로 숨긴다
func _build_blade_overlay() -> void:
	for tier in ["basic", "major"]:
		for anim in AV5_WEAPON_FRAMES:
			for f in AV5_WEAPON_FRAMES[anim]:
				for part in ["trail", "edge"]:
					_av5_weapon["%s/%s_%02d_%s" % [tier, anim, f, part]] = load(AV5_DIR + "weapon_%s/%s_%02d_%s.png" % [tier, anim, f, part])
	_blade_trail = Sprite2D.new()
	_blade_trail.centered = false
	_blade_trail.offset = -WARDEN_FOOT
	_blade_trail.show_behind_parent = true
	_blade_trail.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_blade_trail.visible = false
	_player.add_child(_blade_trail)
	_blade_edge = Sprite2D.new()
	_blade_edge.centered = false
	_blade_edge.offset = -WARDEN_FOOT
	_blade_edge.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_blade_edge.visible = false
	_player.add_child(_blade_edge)
	_player.frame_changed.connect(_update_blade_overlay)
	_player.animation_changed.connect(_update_blade_overlay)


func _update_blade_overlay() -> void:
	if _blade_trail == null:
		return
	var anim := String(_player.animation)
	var tier := _blade_tier if anim == "slash" else ("basic" if anim == "counter" else "")
	var show := tier != "" and not _player_down and AV5_WEAPON_FRAMES.has(anim) and (AV5_WEAPON_FRAMES[anim] as Array).has(_player.frame)
	if show:
		_blade_trail.texture = _av5_weapon["%s/%s_%02d_trail" % [tier, anim, _player.frame]]
		_blade_edge.texture = _av5_weapon["%s/%s_%02d_edge" % [tier, anim, _player.frame]]
		blade_log.append("%s:%d:%s%s" % [anim, _player.frame, tier, ":cut" if _trail_cut and anim == "slash" else ""])
	_blade_trail.visible = show and not (_trail_cut and anim == "slash")
	_blade_edge.visible = show
	_blade_edge.modulate.a = 0.6 if _trail_cut and anim == "slash" else 1.0


# 파동 한 종류: launch(0–2, 한 번) · flight(3–6, 반복) · contact(7–11, 한 번). 속도 1000 = 프레임 길이를 ms 그대로
func _crescent_frames_for(tier: String) -> SpriteFrames:
	if not _crescent_frames.has(tier):
		var ms: Array = CRESCENT[tier].ms
		var frames := SpriteFrames.new()
		frames.remove_animation("default")
		for part in [["launch", 0, 3, false], ["flight", 3, 7, true], ["contact", 7, 12, false]]:
			frames.add_animation(part[0])
			frames.set_animation_speed(part[0], 1000.0)
			frames.set_animation_loop(part[0], part[3])
			for i in range(int(part[1]), int(part[2])):
				frames.add_frame(part[0], load(CRESCENT_DIR + "%s/%s_%02d.png" % [tier, tier, i]), float(ms[i]))
		_crescent_frames[tier] = frames
	return _crescent_frames[tier]


# 전투 효과음 전용 버스: 겹칠 때도 −3 dBFS를 넘지 않게 리미터를 건다. Master로 보내므로 기존 음량 설정이 그대로 먹는다
static func _ensure_fx_bus() -> void:
	if AudioServer.get_bus_index(FX_BUS) != -1:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, FX_BUS)
	AudioServer.set_bus_send(idx, "Master")
	var lim := AudioEffectHardLimiter.new()
	lim.ceiling_db = -3.0
	lim.pre_gain_db = 0.0
	AudioServer.add_bus_effect(idx, lim)


func _arcane(key: String) -> AtlasTexture:
	if not _arcane_tex.has(key):
		var t := AtlasTexture.new()
		t.atlas = load(ARCANE_DIR + String(ARCANE[key][0]))
		t.region = ARCANE[key][1]
		t.filter_clip = true
		_arcane_tex[key] = t
	return _arcane_tex[key]


# 생성 부품 한 장을 실제 실루엣 높이(또는 너비) px로 무대에 놓는다. 회전 없이 크기·투명도만 움직인다
func _arcane_sprite(key: String, pos: Vector2, px: float, by_width := false) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = _arcane(key)
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var r: Rect2 = ARCANE[key][1]
	sp.scale = Vector2.ONE * (px / (r.size.x if by_width else r.size.y))
	sp.position = pos
	_fx.add_child(sp)
	return sp


# 세계 음악 전투의 악보 동안: 음높이가 있는 효과음은 음계와 부딪혀 빼고, 막기 · 휘두르기는 막기 음 뒤로 물린다
const MUSIC_SFX := {"crit_ring": -80.0, "block": -9.0, "enemy_swing": -7.0, "swing": -6.0}


func _sfx(key: String, pitch := 1.0, volume_offset := 0.0) -> void:
	if not SFX.has(key):
		return
	if _music != null and _rhythm_open > 0 and MUSIC_SFX.has(key):
		if float(MUSIC_SFX[key]) <= -60.0:
			return
		volume_offset += float(MUSIC_SFX[key])
	var now := Time.get_ticks_msec()
	if now - int(_sfx_last.get(key, -1000)) < 45:
		return
	_sfx_last[key] = now
	var player := _sfx_players[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx_players.size()
	player.stream = _sfx_streams[key]
	player.volume_db = float(SFX[key][1]) + volume_offset
	player.pitch_scale = pitch
	player.play(float(SFX[key][2]) if (SFX[key] as Array).size() > 2 else 0.0)
	sfx_log.append({"key": key, "ms": now})


func _vfx(key: String, pos: Vector2, scale_mult := 1.0, flip := false) -> AnimatedSprite2D:
	vfx_log.append({"key": key, "ms": Time.get_ticks_msec()})
	var s := AnimatedSprite2D.new()
	s.sprite_frames = _vfx_frames_for(key)
	s.position = pos
	s.scale = Vector2.ONE * 2.0 * scale_mult
	s.flip_h = flip
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_fx.add_child(s)
	s.play("play")
	s.animation_finished.connect(s.queue_free)
	return s


func _vfx_frames_for(key: String) -> SpriteFrames:
	if not _vfx_frames.has(key):
		var cfg: Array = VFX[key]
		var frames := SpriteFrames.new()
		frames.remove_animation("default")
		frames.add_animation("play")
		frames.set_animation_speed("play", cfg[3])
		frames.set_animation_loop("play", false)
		var sheet := load(cfg[0]) as Texture2D
		for i in range(int(cfg[2])):
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(i * 64, int(cfg[1]) * 64, 64, 64)
			frames.add_frame("play", atlas)
		_vfx_frames[key] = frames
	return _vfx_frames[key]


func _float_number(text: String, pos: Vector2, color: Color, size := 24, rise := 46.0, life := 0.8) -> void:
	var l := _label(text, size, color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	l.add_theme_constant_override("outline_size", 4 if size >= 30 else 3)
	l.size = Vector2(240, 40)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = (pos - Vector2(120, 20 + 26 * _float_lane(pos))).round()
	l.modulate.a = 0.0
	_numbers.add_child(l)
	var t := create_tween()
	t.tween_property(l, "modulate:a", 1.0, 0.06)
	t.parallel().tween_property(l, "position:y", l.position.y - rise, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(l, "modulate:a", 0.0, 0.25).set_delay(life - 0.25)
	t.tween_callback(l.queue_free)


func _float_lane(pos: Vector2) -> int:
	var now := Time.get_ticks_msec()
	_float_slots = _float_slots.filter(func(e): return now - int(e.t) < 450)
	var lane := 0
	for e in _float_slots:
		if absf((e.p as Vector2).x - pos.x) < 70.0 and absf((e.p as Vector2).y - pos.y) < 40.0:
			lane += 1
	_float_slots.append({"p": pos, "t": now})
	return lane


# 피해 숫자: 굵은 글꼴·속성 색·두꺼운 테두리와 아래 그림자. pop배로 튀어나와 자리 잡고, 연타는 좌우로 갈라져 떠오른다
func _damage_number(text: String, w: Vector2, tone: String, size: int, pop := 1.0) -> void:
	var c: Array = DMG_TONE[tone]
	var edge: Color = c[1]
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", P2Ui.bold_font(size))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c[0])
	l.add_theme_color_override("font_outline_color", edge)
	l.add_theme_constant_override("outline_size", size / 6)
	l.add_theme_color_override("font_shadow_color", edge)
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", size / 12)
	l.add_theme_constant_override("shadow_outline_size", size / 6)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size = Vector2(240, roundf(size * 1.5))
	l.pivot_offset = l.size / 2.0
	var pos := _to_ui(w).round()
	l.position = (pos - l.size / 2.0 - Vector2(0, roundf(size * 0.7) * _float_lane(pos))).round()
	_numbers.add_child(l)
	var life := 0.8 + (pop - 1.0) * 0.5
	var t := create_tween()
	if _reduce_motion:
		t.tween_property(l, "position:y", l.position.y - 30.0, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		_dmg_side = -_dmg_side
		var drift := _dmg_side * (6.0 + size * 0.2)
		l.scale = Vector2.ONE * pop
		l.modulate = Color(1.9, 1.9, 1.9)
		t.tween_property(l, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(l, "modulate", Color.WHITE, 0.12)
		t.parallel().tween_property(l, "position:y", l.position.y - (24.0 + size * 0.4), life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(l, "position:x", l.position.x + drift, life).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(l, "modulate:a", 0.0, 0.22).set_delay(life - 0.22)
	t.tween_callback(l.queue_free)


# 이 적의 머리 위 칸(예고·이름·체력·상태 줄) 바로 아래에서 시작하는 떠오르는 글자 자리. rise만큼 올라가도 그 칸에 닿지 않는다
# (_float_number 글자 칸 위쪽 = pos.y − 20 − rise). 칸 위치는 지금 화면 좌표(카메라 투영 반영)를 그대로 읽는다
func _below_panel(i: int, rise: float) -> Vector2:
	var r := (_enemy_panels[i].info as Control).get_global_rect()
	return Vector2(r.get_center().x, r.end.y + 4.0 + 20.0 + rise)


# 예전의 무작위 무대 흔들기 대신: 카메라 한 곳이 한 번 밀렸다 돌아온다 (남은 호출처도 같은 주인을 쓴다)
func _shake(amount: float, _steps := 4) -> void:
	_camera_kick("counter" if amount >= 5.0 else "light", Vector2.RIGHT)


# 카메라 주인 하나: 접촉 묶음마다 가장 센 프로필 한 번. 더 센 밀림이 진행 중이면 약한 것은 끼어들지 않는다
func _camera_kick(profile: String, dir: Vector2, focus := false) -> void:
	camera_log.append({"profile": profile, "focus": focus, "ms": Time.get_ticks_msec()})
	if _reduce_motion or _cam == null:
		return
	var p: Dictionary = IMPACT[profile]
	var rank := int(CAM_RANK.get(profile, 1))
	var now := Time.get_ticks_msec()
	if now < _cam_until and rank < _cam_rank and not focus:
		return
	if _cam_tw != null and _cam_tw.is_valid():
		_cam_tw.kill()
	var amp := minf(float(p.get("cam", 0.0)), float(FOCUS.cap))
	var settle := float(p.get("settle", 0.09))
	_cam_rank = rank
	var off := -dir.normalized() * amp
	var z1 := float(FOCUS.zoom) if focus else 1.0
	var t_in := float(FOCUS["in"]) if focus else 0.02
	var t_out := maxf(settle, float(FOCUS.out)) if focus else settle
	_cam_until = now + int((t_in + t_out) * 1000.0)
	var o0 := _cam_raw_off
	var z0 := _cam_raw_z
	_cam_tw = create_tween()
	_cam_tw.tween_method(func(v: float) -> void: _apply_cam(o0.lerp(off, v), lerpf(z0, z1, v)), 0.0, 1.0, t_in)
	_cam_tw.tween_method(func(v: float) -> void: _apply_cam(off.lerp(Vector2.ZERO, v), lerpf(z1, 1.0, v)), 0.0, 1.0, t_out).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if focus and _dim != null:
		_cam_tw.parallel().tween_property(_dim, "color:a", 0.0, t_out).from(float(FOCUS.dim))


func _apply_cam(off: Vector2, z: float) -> void:
	_cam_raw_off = off
	_cam_raw_z = z
	_cam.offset = _cam_base_off + off
	_cam.zoom = Vector2.ONE * z * _cam_base_z
	_project_annotations()


func _camera_neutral() -> void:
	if _cam_tw != null and _cam_tw.is_valid():
		_cam_tw.kill()
	_cam_rank = 0
	_cam_until = 0
	if _cam != null:
		_apply_cam(Vector2.ZERO, 1.0)
	if _dim != null:
		_dim.color.a = 0.0
	_av7_neutral()


# ── 한 공격의 준비 → 비행 → 실제 접촉 → 정리 (카메라 주인·행동 표식은 기존 것) ──────────────────

func _av7_on() -> bool:
	return _new_fx and not _reduce_motion and _cam != null and _av7_rect != null


func _av7_neutral() -> void:
	if _av7_tw != null and _av7_tw.is_valid():
		_av7_tw.kill()
	for k in ["ring_r", "ring_amp", "blur_px", "chroma_px"]:
		_av7_fx[k] = 0.0
	_av7_apply()
	if _av7_lines != null:
		for c in _av7_lines.get_children():
			c.queue_free()
	if _av7_mono != null and is_instance_valid(_av7_mono):
		_av7_mono.queue_free()
	_av7_mono = null
	for l in _av7_lights:
		if is_instance_valid(l):
			(l as Node).queue_free()
	_av7_lights.clear()


# 합성 셰이더에 지금 값을 넣고, 아무 효과도 없으면 숨긴다(화면 복사 없음)
func _av7_apply() -> void:
	if _av7_rect == null:
		return
	var active := float(_av7_fx.ring_amp) > 0.01 or float(_av7_fx.blur_px) > 0.01 or float(_av7_fx.chroma_px) > 0.01
	_av7_rect.visible = active
	if not active:
		return
	var ws := Vector2(get_tree().root.size)
	_av7_mat.set_shader_parameter("px_scale", minf(ws.x / 1280.0, ws.y / 720.0))
	for k in ["center", "sharp_a", "sharp_b", "ring_r", "ring_amp", "blur_px", "chroma_px"]:
		_av7_mat.set_shader_parameter(k, _av7_fx[k])


func _av7_set(k: String, v: Variant) -> void:
	_av7_fx[k] = v
	_av7_apply()


func _av7_mark(phase: String, tier: String) -> Dictionary:
	var e := {"phase": phase, "tier": tier, "ms": Time.get_ticks_msec(), "frame": Engine.get_process_frames(), "zoom": _cam.zoom.x if _cam != null else 1.0}
	av7_log.append(e)
	return e


# 강화 공격의 준비: 조금 물러나며(0.95) 뒤쪽 배경을 살짝 어둡게. 실제 사건·저장은 이미 끝난 뒤의 겉모습
func _av7_prepare() -> bool:
	if not _av7_on():
		return false
	var e: Dictionary = AV7.enhanced
	if _cam_tw != null and _cam_tw.is_valid():
		_cam_tw.kill()
	if _av7_tw != null and _av7_tw.is_valid():
		_av7_tw.kill()
	_cam_rank = AV7_RANK
	_cam_until = Time.get_ticks_msec() + 3000
	var o0 := _cam_raw_off
	var z0 := _cam_raw_z
	_cam_tw = create_tween()
	_cam_tw.tween_method(func(v: float) -> void: _apply_cam(o0.lerp(Vector2.ZERO, v), lerpf(z0, float(e.prep_zoom), v)), 0.0, 1.0, float(e.prep_ms) / 1000.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if _dim != null:
		_cam_tw.parallel().tween_property(_dim, "color:a", float(e.dim), float(e.prep_ms) / 1000.0)
	_av7_mark("prepare", "enhanced")
	return true


# 비행: 실제 목표 쪽으로 카메라가 최대 12px 따라가고, 비행 끝 65ms에 주변 속도선·방사 흐림(배우 둘 주변은 또렷)
func _av7_flight(from_w: Vector2, to_w: Vector2, travel: float) -> void:
	if not _av7_on() or _cam_rank != AV7_RANK:
		return
	var e: Dictionary = AV7.enhanced
	var dir := (to_w - from_w).normalized()
	if _cam_tw != null and _cam_tw.is_valid():
		_cam_tw.kill()
	var o0 := _cam_raw_off
	var z0 := _cam_raw_z
	var off := dir * float(e.track_px)
	_cam_tw = create_tween()
	_cam_tw.tween_method(func(v: float) -> void: _apply_cam(o0.lerp(off, v), lerpf(z0, lerpf(float(e.prep_zoom), 1.0, 0.35), v)), 0.0, 1.0, travel).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_av7_mark("flight", "enhanced")
	var cue := float(e.cue_ms) / 1000.0
	if _av7_tw != null and _av7_tw.is_valid():
		_av7_tw.kill()
	_av7_tw = create_tween()
	_av7_tw.tween_interval(maxf(0.0, travel - cue))
	_av7_tw.tween_callback(func() -> void:
		_av7_fx.center = _to_ui(to_w)
		_av7_fx.sharp_a = _to_ui(_player_body())
		_av7_fx.sharp_b = _to_ui(to_w)
		_av7_fx.sharp_r = float(e.sharp_r)
		_av7_mat.set_shader_parameter("sharp_r", float(e.sharp_r))
		_av7_speed_lines(dir, cue)
		_av7_mark("cue", "enhanced"))
	_av7_tw.tween_method(func(v: float) -> void: _av7_set("blur_px", v), 0.0, float(e.blur_px), cue)


# 주변부 속도선(화면 위·아래 띠, 배우 띠는 피함): 비행 방향으로 짧게 지나가며 사라진다
func _av7_speed_lines(dir: Vector2, life: float) -> void:
	var n := int(AV7.enhanced.lines)
	for i in range(n):
		var top := i % 2 == 0
		var y := (70.0 + 30.0 * float(i / 2)) if top else (450.0 + 26.0 * float(i / 2))
		var x0 := 120.0 + float((i * 197) % 900)
		var len := 140.0 + float((i * 53) % 90)
		var line := Line2D.new()
		line.width = 2.0 if i % 3 else 3.0
		line.default_color = Color(AV7_IVORY, 0.55)
		line.add_point(Vector2.ZERO)
		line.add_point(Vector2(len, 0).rotated(dir.angle()))
		line.position = Vector2(x0, y)
		_av7_lines.add_child(line)
		var t := line.create_tween()
		t.tween_property(line, "position", line.position + dir * 170.0, life + 0.05)
		t.parallel().tween_property(line, "modulate:a", 0.0, life + 0.05).set_ease(Tween.EASE_IN)
		t.tween_callback(line.queue_free)


# 실제 접촉(사건 표시와 같은 순간): 카메라가 당겨지며 맞는 쪽으로 튕기고, 접촉점에서 빛·굴절 고리. payoff면 그려진 다음 짧은 흑백 → 색 분리
func _av7_contact(pos_w: Vector2, tier: String, dir: Vector2, actors: Array) -> bool:
	if not _av7_on() or _cam_rank != AV7_RANK:
		return false
	var e: Dictionary = AV7.enhanced
	var p: Dictionary = AV7[tier] if tier == "payoff" else e
	if _cam_tw != null and _cam_tw.is_valid():
		_cam_tw.kill()
	var o0 := _cam_raw_off
	var z0 := _cam_raw_z
	var off := -dir.normalized() * float(p.kick)
	var z1 := float(p.zoom)
	var settle := float(p.settle_ms) / 1000.0
	_cam_until = Time.get_ticks_msec() + int((float(p.zoom_in_ms) / 1000.0 + settle) * 1000.0)
	_cam_tw = create_tween()
	_cam_tw.tween_method(func(v: float) -> void: _apply_cam(o0.lerp(off, v), lerpf(z0, z1, v)), 0.0, 1.0, float(p.zoom_in_ms) / 1000.0)
	_cam_tw.tween_method(func(v: float) -> void: _apply_cam(off.lerp(Vector2.ZERO, v), lerpf(z1, 1.0, v)), 0.0, 1.0, settle).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if _dim != null:
		_cam_tw.parallel().tween_property(_dim, "color:a", 0.0, settle)
	camera_log.append({"profile": "av7_" + tier, "focus": tier == "payoff", "ms": Time.get_ticks_msec()})
	_av7_light(pos_w, tier, Color(1.0, 0.86, 0.6))
	# 흐림은 바로 끄고, 접촉점에서 굴절 고리가 퍼진다(화면 좌표는 지금 카메라로 투영)
	if _av7_tw != null and _av7_tw.is_valid():
		_av7_tw.kill()
	_av7_fx.blur_px = 0.0
	for c in _av7_lines.get_children():
		c.queue_free()
	_av7_fx.center = _to_ui(pos_w)
	_av7_ring(float(p.warp_px), float(p.warp_r), float(p.warp_ms) / 1000.0)
	_av7_mark("contact", tier)
	if tier == "payoff" and _av7_payoff_token != _action_token:
		_av7_payoff_token = _action_token
		_av7_payoff_beat(actors, pos_w)
	return true


func _av7_ring(amp: float, radius: float, dur: float) -> void:
	_av7_tw = create_tween()
	_av7_tw.tween_method(func(v: float) -> void:
		_av7_fx.ring_r = radius * v
		_av7_fx.ring_amp = amp * (1.0 - v)
		_av7_apply(), 0.0, 1.0, dur).set_ease(Tween.EASE_OUT)
	_av7_tw.tween_callback(func() -> void:
		_av7_fx.ring_amp = 0.0
		_av7_apply())


# payoff 한 번: 실제 접촉이 그려진 다음 프레임부터 약 24ms(최소 한 프레임) 전투 공간만 검정 + 배우·접촉 그림의 상아색 실루엣.
# 이 동안 흐림·색 분리·굴절은 끔. 끝나면 1.8px 색 분리가 50ms에 사라지고 굴절 꼬리. UI·숫자는 위 층이라 그대로
func _av7_payoff_beat(actors: Array, pos_w: Vector2) -> void:
	var token := _action_token
	var p: Dictionary = AV7.payoff
	await _await_drawn()
	if not is_inside_tree() or token != _action_token or not _av7_on():
		return
	if _av7_tw != null and _av7_tw.is_valid():
		_av7_tw.kill()
	_av7_fx.ring_amp = 0.0
	_av7_fx.chroma_px = 0.0
	_av7_apply()
	if _av7_mono != null and is_instance_valid(_av7_mono):
		_av7_mono.queue_free()
	_av7_mono = _av7_silhouettes(actors)
	var mark := _av7_mark("mono", "payoff")
	var t0 := Time.get_ticks_msec()
	await _await_drawn()
	var held := (Time.get_ticks_msec() - t0) / 1000.0
	while held < float(p.mono_ms) / 1000.0 and is_inside_tree() and token == _action_token:
		await get_tree().process_frame
		if not get_tree().paused:
			held += get_process_delta_time()
	if _av7_mono != null and is_instance_valid(_av7_mono):
		_av7_mono.queue_free()
	_av7_mono = null
	if not is_inside_tree() or token != _action_token:
		return
	mark["held_ms"] = Time.get_ticks_msec() - t0
	_av7_fx.center = _to_ui(pos_w)
	_av7_mark("chroma", "payoff")
	_av7_tw = create_tween()
	_av7_tw.tween_method(func(v: float) -> void:
		_av7_fx.chroma_px = float(p.chroma_px) * (1.0 - v)
		_av7_fx.ring_r = float(p.warp_r) * (0.75 + 0.25 * v)
		_av7_fx.ring_amp = float(p.warp_px) * 0.45 * (1.0 - v)
		_av7_apply(), 0.0, 1.0, float(p.chroma_ms) / 1000.0)
	_av7_tw.tween_callback(func() -> void:
		_av7_fx.chroma_px = 0.0
		_av7_fx.ring_amp = 0.0
		_av7_apply())


func _av7_silhouettes(actors: Array) -> Node2D:
	if _av7_sil_shader == null:
		_av7_sil_shader = Shader.new()
		_av7_sil_shader.code = AV7_SILHOUETTE
	var root := Node2D.new()
	_stage.add_child(root)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.03)
	bg.position = Vector2(-500, -400)
	bg.size = Vector2(2280, 1520)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)
	var mat := ShaderMaterial.new()
	mat.shader = _av7_sil_shader
	for a in actors:
		if not is_instance_valid(a) or not (a is AnimatedSprite2D) or not (a as CanvasItem).is_visible_in_tree():
			continue
		var src := a as AnimatedSprite2D
		var tex := src.sprite_frames.get_frame_texture(src.animation, src.frame)
		if tex == null:
			continue
		var sil := Sprite2D.new()
		sil.texture = tex
		sil.centered = src.centered
		sil.offset = src.offset
		sil.flip_h = src.flip_h
		sil.texture_filter = src.texture_filter
		sil.material = mat
		root.add_child(sil)
		sil.global_transform = src.global_transform
	return root


# 접촉 빛: 실제 접촉점에 짧은 방사 빛(PointLight2D, 코드로 만든 원형 그라데이션). 흔들림 줄이기·새 연출 끔이면 없음
func _av7_light(pos_w: Vector2, tier: String, color: Color) -> void:
	if not _new_fx or _reduce_motion or _stage == null:
		return
	var p: Dictionary = AV7[tier]
	var l := PointLight2D.new()
	l.texture = _av7_light_tex()
	l.texture_scale = float(p.light_r) * 2.0 / 128.0
	l.color = color
	l.energy = 0.0
	l.position = pos_w
	_stage.add_child(l)
	_av7_lights.append(l)
	var dur := float(p.light_ms) / 1000.0
	var t := l.create_tween()
	t.tween_property(l, "energy", float(p.light_e), dur * 0.2)
	t.tween_property(l, "energy", 0.0, dur * 0.8).set_ease(Tween.EASE_IN)
	t.tween_callback(func() -> void:
		_av7_lights.erase(l)
		l.queue_free())
	av7_log.append({"phase": "light", "tier": tier, "ms": Time.get_ticks_msec(), "frame": Engine.get_process_frames(), "pos": pos_w})


var _av7_light_texture: GradientTexture2D


func _av7_light_tex() -> GradientTexture2D:
	if _av7_light_texture == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.45, Color(1, 1, 1, 0.35))
		_av7_light_texture = GradientTexture2D.new()
		_av7_light_texture.gradient = g
		_av7_light_texture.width = 128
		_av7_light_texture.height = 128
		_av7_light_texture.fill = GradientTexture2D.FILL_RADIAL
		_av7_light_texture.fill_from = Vector2(0.5, 0.5)
		_av7_light_texture.fill_to = Vector2(1.0, 0.5)
	return _av7_light_texture


# 이 접촉이 payoff인가: 실제 사건만 본다(강화 사본 + 실제 표식 소모 / 강화 사본 + 실제 치명 / 실제 보스 처치). 미리 알 수 없는 치명은 준비에 쓰지 않는다
func _av7_payoff(upgraded: bool, wave: Array) -> bool:
	for ev in wave:
		if upgraded and (int(ev.get("consumed", 0)) > 0 or bool(ev.get("crit", false))):
			return true
		if bool(ev.get("dead", false)) and _is_boss_index(int(ev.index)):
			return true
	return false


# 입력을 풀기 전에 카메라·주석을 제자리로 (보통은 이미 끝나 있음, 남았으면 짧게 기다렸다 강제로)
func _camera_settled(limit := 0.2) -> void:
	var t0 := Time.get_ticks_msec()
	while _cam_tw != null and _cam_tw.is_valid() and _cam_tw.is_running() and Time.get_ticks_msec() - t0 < int(limit * 1000.0) and is_inside_tree():
		await get_tree().process_frame
	if is_inside_tree():
		_camera_neutral()


# 세계 위치 → 화면(UI) 위치 (카메라 밀림·확대 반영)
func _to_ui(w: Vector2) -> Vector2:
	if _cam == null:
		return w
	return (w - Vector2(640, 360) - _cam.offset) * _cam.zoom.x + Vector2(640, 360)


func _to_world(u: Vector2) -> Vector2:
	if _cam == null:
		return u
	return (u - Vector2(640, 360)) / _cam.zoom.x + Vector2(640, 360) + _cam.offset


# 이번 카드에서 그은 방향(맞은 몸이 밀려 가는 쪽). 적은 늘 오른쪽이라 가로는 오른쪽으로 접는다
func _stroke_dir() -> Vector2:
	var rel: PackedVector2Array = _slash_trace.get("rel", PackedVector2Array())
	if rel.size() < 2:
		return Vector2.RIGHT
	var d := rel[rel.size() - 1] - rel[0]
	if d.length() < 8.0:
		return Vector2.RIGHT
	d = d.normalized()
	return Vector2(maxf(absf(d.x), 0.4), d.y).normalized()


# 적 머리 위 칸·주인공 상태는 세계에 붙어 있으므로 카메라가 움직이는 동안 '제자리(슬롯) 발 기준점'을 투영해 같이 옮긴다 (크기·글자 그대로)
func _project_annotations() -> void:
	for i in range(_enemy_panels.size()):
		var p: Dictionary = _enemy_panels[i]
		var s: Node2D = _enemy_sprites[i] if i < _enemy_sprites.size() else null
		var a := Vector2(float(s.get_meta("home_x", s.position.x)) if s != null else 640.0, FEET_Y)
		var d := (_to_ui(a) - a).round()
		var root: Control = p.root
		root.position = (root.get_meta("base_pos", root.position) as Vector2) + d
		var ch: Control = p.charge
		ch.position = (ch.get_meta("base_pos", ch.position) as Vector2) + d
	if _player_status != null:
		var pa := Vector2(_home_x, FEET_Y)
		var pd := (_to_ui(pa) - pa).round()
		_player_status.position = (_player_status.get_meta("base_pos", _player_status.position) as Vector2) + pd
		_player_pred.position = (_player_pred.get_meta("base_pos", _player_pred.position) as Vector2) + pd
		# 적 예상 칸과 겹치면 그 아래 빈 무대로 내린다
		if _player_pred.visible:
			for q in _enemy_panels:
				var eb: Control = q.pred
				if eb.is_visible_in_tree() and eb.get_global_rect().intersects(_player_pred.get_global_rect()):
					_player_pred.position.y = eb.get_global_rect().end.y + 6.0


# 접촉 지점에서 생기는 숫자: 세계 위치를 한 번 화면으로 옮겨 반올림 (글자 크기는 그대로)
func _world_number(text: String, w: Vector2, color: Color, size := 24, rise := 46.0, life := 0.8) -> void:
	_float_number(text, _to_ui(w).round(), color, size, rise, life)


func _enemy_torso(i: int) -> Vector2:
	if i < 0 or i >= _enemy_sprites.size():
		return Vector2(900, FEET_Y - 64.0)
	var sp := _enemy_sprites[i]
	return Vector2(float(sp.get_meta("home_x", sp.position.x)), FEET_Y - float(sp.get_meta("torso_h", 128.0)) * 0.5)


# 지금 실제 위치(돌진 중인 공격자 등)의 몸통
func _enemy_torso_now(i: int) -> Vector2:
	var sp := _enemy_sprites[i]
	return Vector2(sp.position.x, FEET_Y - float(sp.get_meta("torso_h", 128.0)) * 0.5)


# 배우마다 따로 쓰는 섞는 번쩍임 (재질은 처음 쓸 때 한 번 만듦, 알파·self_modulate·사라짐은 건드리지 않음)
func _actor_flash(sprite: CanvasItem, color: Color, mix: float, peak: float, clear: float) -> void:
	if not is_instance_valid(sprite):
		return
	if sprite.material != null and not sprite.has_meta("flash_mat"):
		return
	var m := sprite.material as ShaderMaterial
	if m == null:
		if _flash_shader == null:
			_flash_shader = Shader.new()
			_flash_shader.code = FLASH_SHADER
		m = ShaderMaterial.new()
		m.shader = _flash_shader
		sprite.material = m
		sprite.set_meta("flash_mat", true)
	var old: Tween = sprite.get_meta("flash_tw") if sprite.has_meta("flash_tw") else null
	if old != null and old.is_valid():
		old.kill()
	var amt := mix * (0.35 if _reduce_motion else 1.0)
	m.set_shader_parameter("flash_color", color)
	var t := create_tween()
	t.tween_method(func(v: float) -> void: m.set_shader_parameter("flash_mix", v), 0.0, amt, peak)
	t.tween_method(func(v: float) -> void: m.set_shader_parameter("flash_mix", v), amt, 0.0, clear)
	sprite.set_meta("flash_tw", t)


# 맞은 몸 반응(주인 하나): 접촉 순간 아주 작은 밀림·발 기준 눌림 → 짧은 정지 → 끝까지 밀렸다 돌아옴. 쓰러지면 돌아오지 않는다.
# 기준은 슬롯 제자리(돌진 중이면 지금 실제 위치). 그림자는 눌림·기울기를 되돌려 바닥 타원이 찌그러지지 않게
func _victim_react(sprite: AnimatedSprite2D, profile: String, dir: Vector2, dead: bool) -> void:
	if not is_instance_valid(sprite):
		return
	_kill_react(sprite)
	if _reduce_motion:
		return
	var p: Dictionary = IMPACT[profile]
	var bx := sprite.position.x if sprite.get_meta("dashing", false) else float(sprite.get_meta("home_x", sprite.position.x))
	var bscale: Vector2 = sprite.get_meta("base_scale", sprite.scale)
	sprite.set_meta("base_scale", bscale)
	var sgn := signf(dir.x) if dir.x != 0.0 else 1.0
	var push := float(p.push)
	var sq: Vector2 = p.get("squash", Vector2.ONE)
	var tilt := float(p.get("tilt", 0.0)) * sgn
	sprite.position.x = bx + sgn * push * 0.3
	_set_squash(sprite, bscale, sq, tilt)
	var lift := maxf(0.0, -dir.y) * push * 0.7
	if lift > 1.0:
		var by := float(sprite.get_meta("home_y", sprite.position.y))
		sprite.set_meta("home_y", by)
		var h := create_tween()
		h.tween_interval(float(p.hold))
		h.tween_property(sprite, "position:y", by - lift, float(p.out) + 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		h.tween_property(sprite, "position:y", by, float(p.back) + 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		sprite.set_meta("hop_tw", h)
	var t := create_tween()
	t.tween_interval(float(p.hold))
	t.tween_property(sprite, "position:x", bx + sgn * push, float(p.out)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_method(func(v: float) -> void: _set_squash(sprite, bscale, sq.lerp(Vector2.ONE, v), tilt * (1.0 - v)), 0.0, 1.0, float(p.out) + float(p.back))
	if not dead:
		t.tween_property(sprite, "position:x", bx, float(p.back)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	sprite.set_meta("react_tw", t)
	react_log.append({"profile": profile, "dead": dead})


func _kill_react(sprite: AnimatedSprite2D) -> void:
	var old: Tween = sprite.get_meta("react_tw") if sprite.has_meta("react_tw") else null
	if old != null and old.is_valid():
		old.kill()
	var hop: Tween = sprite.get_meta("hop_tw") if sprite.has_meta("hop_tw") else null
	if hop != null and hop.is_valid():
		hop.kill()
		sprite.position.y = float(sprite.get_meta("home_y", sprite.position.y))
	if sprite.has_meta("base_scale"):
		_set_squash(sprite, sprite.get_meta("base_scale"), Vector2.ONE, 0.0)


func _set_squash(sprite: Node2D, bscale: Vector2, sq: Vector2, tilt: float) -> void:
	sprite.scale = bscale * sq
	sprite.rotation_degrees = tilt
	for ch in sprite.get_children():
		if ch is Polygon2D:
			(ch as Polygon2D).scale = Vector2(1.0 / sq.x, 1.0 / sq.y)
			(ch as Polygon2D).rotation_degrees = -tilt


# 접촉 하나의 무게 고르기: 실제 사건의 표시(강화·표식 소모·치명·반격)만 본다. 처치는 무게를 바꾸지 않는다(보스 처치는 초점만)
func _contact_profile(ev: Dictionary, tier := "") -> String:
	if String(ev.kind) == "counter":
		return "counter"
	if String(ev.kind) != "hit":
		return "secondary"
	if tier == "major" or int(ev.get("consumed", 0)) > 0 or bool(ev.get("crit", false)):
		return "heavy"
	return "light"


func _stronger(a: String, b: String) -> String:
	return a if int(CAM_RANK.get(a, 0)) >= int(CAM_RANK.get(b, 0)) else b


func _is_boss_index(i: int) -> bool:
	return String(P2Catalog.ENEMIES[battle.roles[i]].get("rank", "")) == "boss"


# 새 행동이 시작되면 이전 행동의 해롭지 않은 잔여(카메라·주석 위치)는 정리
func _cancel_residue() -> void:
	_camera_neutral()


func _flash(sprite: CanvasItem, color: Color) -> void:
	sprite.modulate = color.lerp(Color.WHITE, 0.55) if _reduce_motion else color
	create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.16)


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _hit_stop(sprites: Array, duration := 0.04) -> void:
	duration += _stop_bonus
	_stop_bonus = 0.0
	var prior := {}
	for s in sprites:
		if is_instance_valid(s) and not prior.has(s):
			prior[s] = s.speed_scale
			s.speed_scale = 0.0
	if _juice and not _reduce_motion:
		for s in prior:
			if s == _player or _enemy_sprites.has(s):
				_vibrate(s, duration, 1.5 if s == _player else 3.0)
	await _wait(duration)
	for s in prior:
		if is_instance_valid(s) and is_zero_approx(s.speed_scale):
			s.speed_scale = float(prior[s])


func _enemy_pos(index: int) -> Vector2:
	if index < 0 or index >= _enemy_sprites.size():
		return Vector2(900, FEET_Y)
	return _enemy_sprites[index].position


func _body_center(pos: Vector2) -> Vector2:
	return pos + Vector2(0, -64)


func _banner_text(text: String, size: int) -> void:
	_banner.text = text
	_banner.add_theme_font_size_override("font_size", size)


func _show_banner(hold: float) -> void:
	_banner.visible = true
	_banner.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(_banner, "modulate:a", 1.0, 0.15)
	t.tween_interval(hold)
	t.tween_property(_banner, "modulate:a", 0.0, 0.2)
	await t.finished
	_banner.visible = false


# ── 표시 상태 ─────────────────────────────────────────────────────────────────

func _sync_shown_from_battle() -> void:
	var es: Array = []
	for m in battle.monsters:
		es.append({"hp": m.hp, "max": m.max_hp, "marks": battle.mark_count(m.index), "alive": m.is_alive(),
			"supp": battle.suppression[m.index] if m.index < battle.suppression.size() else 0,
			"shield": battle.shields[m.index] if m.index < battle.shields.size() else 0,
			"unwind": battle.unwind_count[m.index] if m.index < battle.unwind_count.size() else 0,
			"ulock": battle.unwind_lock[m.index] if m.index < battle.unwind_lock.size() else -1,
			"st": (battle.est[m.index] as Dictionary).duplicate() if m.index < battle.est.size() else {}})
	var bonus := P2Catalog.WARDEN_COUNTER_BONUS if battle.class_id == "warden" else 0
	_shown = {"hp": int(GameState.get_flag("player_hp")), "block": battle.get_pending_defense(),
		"counter": battle.counter_charges, "enemies": es, "tally": battle.boss_tally, "prep": battle.hunter_prep, "combo": battle.combo,
		"cq": Array(battle.counter_queue).map(func(v): return int(v) + bonus),
		"res": battle.noble_res, "nlock": battle.noble_lock, "seal_uid": battle.noble_seal_uid}


func _reconcile(point: String) -> void:
	var before := JSON.stringify(_shown)
	var shown_enemies: Array = (_shown.enemies as Array).duplicate(true)
	var shown_hp := int(_shown.hp)
	_sync_shown_from_battle()
	for i in range(shown_enemies.size()):
		var a: Dictionary = shown_enemies[i]
		var b: Dictionary = _shown.enemies[i]
		if int(a.hp) != int(b.hp) or int(a.marks) != int(b.marks) or bool(a.alive) != bool(b.alive):
			reconcile_fixes += 1
			_display_log.append({"frame": Engine.get_process_frames(), "kind": "reconcile_fix", "point": point, "index": i, "shown": a, "actual": b})
			if bool(a.alive) and not bool(b.alive):
				_enemy_death(i)
			elif not bool(a.alive) and bool(b.alive) and battle.is_spawn_slot(i):
				_reveal_spawn(i, {"hp": int(b.hp), "max": int(b.max)})
	if shown_hp != int(_shown.hp) and not (point == "battle_end" and battle.victory_heal > 0):
		reconcile_fixes += 1
		_display_log.append({"frame": Engine.get_process_frames(), "kind": "reconcile_fix", "point": point, "player_hp": [shown_hp, _shown.hp]})
	if before != JSON.stringify(_shown):
		_render_all()


# 사건 하나를 "맞는 순간"에 표시 상태로 옮긴다
func _apply_event(ev: Dictionary) -> void:
	var kind := String(ev.kind)
	var sb := int(ev.get("index", -1)) if ev.has("shield_left") or kind == "shield_expire" else -1
	var sb_before := int(_shown.enemies[sb].get("shield", 0)) if sb >= 0 and sb < (_shown.enemies as Array).size() else 0
	_apply_event_state(ev, kind)
	if sb_before > 0 and int(_shown.enemies[sb].get("shield", 0)) == 0:
		_shield_dropped(sb, ev)


func _apply_event_state(ev: Dictionary, kind: String) -> void:
	match kind:
		"hit", "arc", "counter", "thorn", "cleave", "lens", "echo", "transfer", "echo_string", "furnace", "mark_chain", "echo_edge", "drum_echo", "shield_counter", "slam_splash", "chain", "dot", "shard", "link", "trap_snap", "wall_reflect", "bounce", "steam_splash", "riposte_beat", "combo_burst":
			var i := int(ev.index)
			var e: Dictionary = _shown.enemies[i]
			e.hp = int(ev.hp)
			e.marks = int(ev.marks)
			if ev.has("shield_left"):
				e.shield = int(ev.shield_left)
			if ev.has("unwind"):
				e.unwind = int(ev.unwind)
			if bool(ev.dead):
				e.alive = false
				e.supp = 0
			if kind == "counter":
				_shown.counter = maxi(0, int(_shown.counter) - 1)
				if not (_shown.cq as Array).is_empty():
					(_shown.cq as Array).pop_front()
			if kind != "counter" and kind != "thorn" and battle.charge_window_open(i):
				_shown.tally = int(_shown.tally) + int(ev.damage)
			_render_enemy(i, true)
			if bool(ev.dead):
				_enemy_death(i)
		"status":
			var es: Dictionary = _shown.enemies[int(ev.index)]
			var stx: Dictionary = (es.get("st", {}) as Dictionary).duplicate()
			if int(ev.after) <= 0:
				stx.erase(String(ev.key))
			else:
				stx[String(ev.key)] = int(ev.after)
			es["st"] = stx
			if _show != null:
				_show.render_status(int(ev.index))
		"inscribe":
			var e2: Dictionary = _shown.enemies[int(ev.index)]
			e2.marks = int(ev.marks)
			_render_enemy(int(ev.index), true)
		"suppress":
			_shown.enemies[int(ev.index)].supp = int(ev.amount)
			_render_enemy(int(ev.index), false)
		"suppressed":
			_shown.enemies[int(ev.index)].supp = 0
			_render_enemy(int(ev.index), false)
		"boss_weakened":
			_shown.tally = maxi(int(_shown.tally), int(ev.tally))
			_render_enemy(int(ev.index), false)
		"boss_lock":
			_shown.tally = int(ev.tally)
			_render_enemy(int(ev.index), false)
		"guard":
			_shown.block = int(ev.block)
			_shown.counter = int(ev.counter)
			if bool(ev.counter_added):
				(_shown.cq as Array).append(int(ev.counter_value))
			_render_hud()
		"spend_block", "absorb", "opening_block", "blade", "seal", "carry", "glove", "burn_endure", "iron_tempo", "ember_jar", "chalice", "collector":
			_shown.block = int(ev.block)
			_render_hud()
		"shield_expire":
			_shown.enemies[int(ev.index)].shield = 0
			_render_enemy(int(ev.index), false)
		"unwind":
			_shown.enemies[int(ev.index)].unwind = int(ev.count)
			_render_enemy(int(ev.index), false)
		"resonance":
			_shown.res = int(ev.level)
			_render_all()
		"noble_lock":
			_shown.nlock = int(ev.hit)
			_shown.res = 0
			_render_all()
		"noble_seal":
			_shown.seal_uid = String(ev.uid)
			_refresh_card_states()
		"noble_unseal":
			_shown.seal_uid = ""
			_refresh_card_states()
		"unwind_lock":
			_shown.enemies[int(ev.index)].ulock = int(ev.hit)
			_render_enemy(int(ev.index), false)
		"poison_tick", "potion", "heal", "self_hurt":
			_shown.hp = int(ev.hp)
			_render_hud()
		"summon":
			for sp in ev.spawned:
				_reveal_spawn(int(sp.index), sp)
		"spawn_consumed":
			var ce: Dictionary = _shown.enemies[int(ev.index)]
			ce.alive = false
			ce.hp = 0
			(_enemy_panels[int(ev.index)].root as Control).visible = false
		"rebuild":
			for di in ev.devices:
				var d: Dictionary = _shown.enemies[int(di)]
				d.alive = true
				d.hp = int(battle.monsters[int(di)].max_hp)
				d.marks = 0
				d.supp = 0
				_revive_enemy(int(di))
				_render_enemy(int(di), false)
			_render_all()
		"hex", "poison", "hex_active", "block_strike_ready":
			_render_hud()
		"prep":
			_shown.prep = int(ev.after)
			_render_prep()
		"combo":
			_shown.combo = int(ev.after)
			if _player_status != null:
				_render_player_status()
		"mana_refund", "x_paid":
			_render_mana()
		"enemy_hit":
			_shown.block = int(ev.block)
			_shown.hp = int(ev.hp)
			_render_hud()
	_log_display(ev)


func _log_display(ev: Dictionary) -> void:
	var entry := {"frame": Engine.get_process_frames(), "kind": ev.kind, "player_hp_text": _hud_hp_label.text,
		"block_text": _player_badge.text, "actor": "%s:%d" % [_player.animation, _player.frame]}
	if String(ev.kind) == "hit" and int(ev.get("reprisal", 0)) > 0:
		entry["reprisal"] = int(ev.reprisal)
	if ev.has("index") and String(ev.kind) != "enemy_hit" and String(ev.kind) != "prepare":
		var i := int(ev.index)
		var p: Dictionary = _enemy_panels[i]
		entry["index"] = i
		entry["enemy_hp_text"] = (p.hp_label as Label).text
		entry["marks_shown"] = int((p.marks as Control).get_meta("count", 0)) if (p.marks as Control).visible else 0
		entry["panel_visible"] = (p.root as Control).visible
	_display_log.append(entry)


func _queued_free_count(node: Node) -> int:
	var n := 0
	for c in node.get_children():
		if c.is_queued_for_deletion():
			n += 1
	return n


func get_display_log() -> Array:
	return _display_log.duplicate(true)


func clear_display_log() -> void:
	_display_log.clear()


func shown_state() -> Dictionary:
	return _shown.duplicate(true)


# 오른쪽 아래 '다가오는 공격': 이번 적 차례에 들어올 피해 합 · 지금 방어로 막고 남는 피해 · 노트 수 · 강타 · 특수 행동
func _build_incoming() -> void:
	_incoming = _ui_patch("prompt_frame", Vector2(200, 92), [4, 3, 4, 3])
	_incoming.position = Vector2(1070, 620)
	_incoming.mouse_filter = Control.MOUSE_FILTER_STOP
	_incoming.tooltip_text = tr("이번 적 차례에 들어올 공격 합계와, 지금 방어로 막고 남는 피해")
	_ui.add_child(_incoming)
	# 글 대신 아이콘: 칼 = 들어올 피해, 방패 = 지금 방어, 하트 = 막고 남아 깎일 체력. 숫자는 크게
	for spec in [["l0", Vector2(10, 4), 12, C_GOLD, 180.0], ["dmg", Vector2(36, 20), 24, C_TEXT, 54.0], ["blk", Vector2(122, 20), 24, C_BLOCK, 54.0],
			["l2", Vector2(36, 50), 24, C_TEXT, 100.0], ["l3", Vector2(118, 58), 12, C_DIM, 74.0]]:
		var l := _label("", int(spec[2]), spec[3])
		l.position = spec[1]
		l.size = Vector2(float(spec[4]), 30 if int(spec[2]) > 12 else 18)
		l.clip_text = true
		l.add_theme_color_override("font_outline_color", Color.BLACK)
		l.add_theme_constant_override("outline_size", 3)
		_incoming.add_child(l)
		_incoming.set_meta(String(spec[0]), l)
	(_incoming.get_meta("l3") as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for ic in [["intent_attack", Vector2(10, 24)], ["block_badge", Vector2(96, 24)], ["hud_heart_compact", Vector2(10, 54)]]:
		var r := _ui_rect(String(ic[0]), ic[1], 2)
		_incoming.add_child(r)
	(_incoming.get_meta("l0") as Label).text = tr("다가오는 공격")


func _render_incoming() -> void:
	if _incoming == null or battle == null or _shown.is_empty():
		return
	var total := 0
	var notes := 0
	var crush := 0
	var acts: Array[String] = []
	for i in range(_enemy_panels.size()):
		if i >= (_shown.enemies as Array).size() or not bool(_shown.enemies[i].alive):
			continue
		var act := battle.intent_action(i)
		if not act.is_empty():
			var nm := String({"hex": "주술", "poison": "독", "summon": "소환", "rebuild": "재가동"}.get(String(act.get("act", "")), ""))
			if nm != "":
				acts.append(nm)
			continue
		var hits := _shown_intent(i)
		if not P2Battle._is_damaging(hits):
			continue
		var add := battle.attack_bonus + _shown_aura(i) + battle.affix_add(i)
		var supp := int(_shown.enemies[i].get("supp", 0))
		for h in hits:
			total += maxi(0, battle.scaled(int(h)) + add - supp)
		if battle.parry_mode:
			for g in _parry_pattern(i, hits.map(func(h): return battle.scaled(int(h))), supp > 0):
				notes += (g.kinds as Array).size()
				crush += 1 if bool(g.crush) else 0
	var blk := int(_shown.get("block", 0))
	var left := total - blk
	(_incoming.get_meta("dmg") as Label).text = str(total)
	(_incoming.get_meta("blk") as Label).text = str(blk)
	(_incoming.get_meta("l2") as Label).text = ("−%d" % left) if left > 0 else (tr("다 막음") if total > 0 else tr("공격 없음"))
	(_incoming.get_meta("l2") as Label).add_theme_color_override("font_color", Color("#ff8a7a") if left > 0 else P2Ui.C_GOOD)
	var extra: Array[String] = []
	if notes > 0:
		extra.append(tr("노트 %d") % notes)
	if crush > 0:
		extra.append(tr("강타 %d") % crush)
	extra.append_array(acts)
	(_incoming.get_meta("l3") as Label).text = " · ".join(extra)


func _render_all() -> void:
	# 처음 만들 때·이어하기·보정: 보인 방패 값에 맞춰 조용히 벌만 맞춘다(놓침 재생 없음). 동작 중인 배우는 건드리지 않는다
	for i in range(mini(_enemy_sprites.size(), (_shown.enemies as Array).size())):
		var sp := _enemy_sprites[i]
		if sp.has_meta("frames_u") and not bool(sp.get_meta("art_busy", false)) and not bool(sp.get_meta("dying", false)) and sp.animation == "idle":
			_shield_set(sp, int(_shown.enemies[i].get("shield", 0)) > 0, "")
		if sp.has_meta("steady_frames") and not battle._resolving and not bool(sp.get_meta("art_busy", false)) and not bool(sp.get_meta("dying", false)) and sp.animation == "idle":
			_steady_set(sp, _unwind_steady(i))
	_render_hud()
	for i in range(_enemy_panels.size()):
		_render_enemy(i, false)
	_render_incoming()


func _tween_bar(key: String, bar: ProgressBar, value: float, animate: bool) -> void:
	var old: Tween = _bar_tweens.get(key)
	if old != null and old.is_valid():
		old.kill()
	if not animate:
		bar.value = value
		return
	var t := create_tween()
	t.tween_property(bar, "value", value, 0.14)
	_bar_tweens[key] = t


func _render_hud() -> void:
	var hp := int(_shown.hp)
	var max_hp := int(_run_info.max_hp)
	_tween_bar("player", _hud_hp_bar, hp, true)
	_hud_hp_label.text = "%d / %d" % [hp, max_hp]
	_render_mana()
	var block := int(_shown.block)
	var cq: Array = _shown.get("cq", [])
	_hud_block.text = str(block)
	_barrier_sync(block)
	_render_incoming()
	if _juice:
		var mhp := maxf(1.0, float(_run_info.get("max_hp", 1)))
		_vig.danger = 0.42 if float(_shown.hp) <= mhp * 0.3 and float(_shown.hp) > 0.0 else 0.0
		if _vig.danger > 0.0:
			_vignette_node()
	_hud_block.add_theme_color_override("font_color", C_BLOCK if block > 0 else C_DIM)
	_block_icon.modulate = Color.WHITE if block > 0 else Color(0.6, 0.6, 0.65)
	_block_icon.tooltip_text = "방어 %d: 이번 적 단계의 피해를 먼저 막고, 적 단계가 끝나면 사라집니다 (이월 효과 제외)%s" % [block, "\n반격 " + " · ".join(PackedStringArray(cq.map(func(v): return str(v)))) if not cq.is_empty() else ""]
	_render_top()
	_player_badge.text = _badge_text(block)
	_hud_title.text = _enc_label()
	_turn_banner.tooltip_text = "%s — %s" % [_enc_label(), _enc_hint()]
	_render_phase()
	_render_piles()
	_render_relics()
	_render_potions()
	_render_status()
	_render_prep()


func _render_top() -> void:
	if _top_labels.is_empty():
		return
	(_top_labels.hp as Label).text = "%d/%d" % [int(_shown.hp), int(_run_info.max_hp)]
	var gold := int(model.run.get("gold", 0)) if model != null and not model.run.is_empty() else 0
	(_top_labels.gold as Label).text = str(gold)
	var hp_n := _potion_count("hp_potion")
	var mp_n := _potion_count("mana_potion")
	(_top_labels.potion as Label).text = str(hp_n)
	((_top_labels.potion as Label).get_meta("icon") as Control).tooltip_text = tr("회복약 %d (옆 동그라미 · Q로 사용)") % hp_n
	(_top_labels.mana_potion as Label).text = str(mp_n)
	(_top_labels.mana_potion as Label).visible = mp_n > 0
	((_top_labels.mana_potion as Label).get_meta("icon") as Control).visible = mp_n > 0
	((_top_labels.mana_potion as Label).get_meta("icon") as Control).tooltip_text = tr("마나 물약 %d (옆 동그라미로 사용)") % mp_n
	((_top_labels.gold as Label).get_meta("icon") as Control).tooltip_text = tr("금화 %d") % gold


func _render_phase() -> void:
	var whose := "내 차례"
	match _state:
		UI.ENEMY:
			whose = "적 차례"
		UI.BANNER:
			whose = "전투 시작"
		UI.OVER:
			whose = "전투 끝"
		UI.MULLIGAN:
			whose = "첫 손패 교체"
		UI.FUEL:
			whose = "연료화 고르는 중"
	_hud_phase.text = "%d턴 · %s" % [battle.turn_number, whose]
	# 양끝 장식은 글자 폭에 붙인다
	var half := _text_width(_hud_phase.text, P2Ui.snap_size(F)) / 2.0
	if _turn_marks.size() == 2:
		(_turn_marks[0] as Control).position.x = 640.0 - half - 66.0
		(_turn_marks[1] as Control).position.x = 640.0 + half + 12.0


func _render_piles() -> void:
	var ex := (battle.deck as P4Deck).exhausted
	var draw_names: Array = battle.deck.draw_pile.map(func(c): return c.card_name)
	draw_names.sort()
	var counts := [battle.deck.draw_pile.size(), battle.deck.discard_pile.size(), ex.size()]
	var tips := ["뽑을 더미 %d장 (순서 숨김): %s" % [counts[0], ", ".join(PackedStringArray(draw_names)) if not draw_names.is_empty() else "없음"],
		"버린 더미 %d장: %s" % [counts[1], ", ".join(PackedStringArray(battle.deck.discard_pile.map(func(c): return c.card_name))) if not battle.deck.discard_pile.is_empty() else "없음"],
		"소진 %d장 (이번 전투에서 다시 나오지 않음): %s" % [counts[2], ", ".join(PackedStringArray(ex.map(func(c): return c.card_name))) if not ex.is_empty() else "없음"]]
	for k in range(_pile_tiles.size()):
		var tile: Control = _pile_tiles[k]
		(tile.get_meta("count") as Label).text = str(counts[k])
		tile.tooltip_text = tips[k] + "\n손패 %d / %d · 덱 %d장 · 누르면 전투 정보 (Tab)" % [battle.hand.cards.size(), P2Battle.HAND_MAX, int(_run_info.deck)]
	_hud_piles = _pile_tiles[0].get_meta("count")


func _render_relics() -> void:
	for c in _hud_relics.get_children():
		c.queue_free()
	var cap := P2Catalog.relic_capacity({"traits": battle.traits})
	# 가진 유물만 (빈 칸을 장식으로 늘리지 않는다). 칸 수는 '유물' 글자 도움말에
	var order: Array = battle.relic_order if not battle.relic_order.is_empty() else battle.relics
	_hud_relics.position.x = 1022.0 - 38.0 * maxi(0, order.size() - P2Catalog.RELIC_SLOTS)
	for id in order:
		var slot := Control.new()
		slot.custom_minimum_size = Vector2(36, 36)
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		var ic := _icon_tex(P2Ui.relic_tex(id), 30)
		ic.position = Vector2(3, 3)
		slot.add_child(ic)
		var lv := battle.rl(String(id))
		P2Ui.relic_level_mark(slot, lv, 36.0)
		slot.tooltip_text = "%s\n%s%s\n(유물 %d칸 중 %d칸)" % [P2Catalog.RELICS[id].name, P2Catalog.RELICS[id].text, P2Ui.relic_level_text(lv), cap, order.size()]
		slot.set_meta("relic", id)
		_hud_relics.add_child(slot)


func _render_player_status() -> void:
	for c in _player_status.get_children():
		c.queue_free()
	var block := int(_shown.block)
	var cq: Array = _shown.get("cq", [])
	if not cq.is_empty():
		_player_status.add_child(_chip("status_counter", "반격 " + "·".join(PackedStringArray(cq.map(func(v): return str(v)))), C_GOLD, "반격 기회: 방어가 실제로 막은 적 타격 하나마다 먼저 얻은 것부터 이 피해를 돌려줍니다"))
	if battle.poison_ticks > 0:
		_player_status.add_child(_chip("status_poison", "독 %d×%d" % [battle.poison_amount, battle.poison_ticks], Color("#8be08b"), "독: 내 턴이 끝날 때 방어를 무시하고 %d씩, %d회 더. 회복약으로 풀립니다" % [battle.poison_amount, battle.poison_ticks]))
	if battle.hex_active:
		_player_status.add_child(_chip("status_hex", "주술 −%d" % P2Catalog.HEX_AMOUNT, C_MARK, "주술: 이번 턴 방어 카드가 %d씩 약해집니다. 회복약으로 풀립니다" % P2Catalog.HEX_AMOUNT))
	elif battle.hex_next:
		_player_status.add_child(_chip("status_hex", "주술 예정", C_MARK, "주술 예정: 다음 내 턴 방어 카드가 %d씩 약해집니다" % P2Catalog.HEX_AMOUNT))
	var cmb := int(_shown.get("combo", 0))
	if battle.class_id == "combo":
		_player_status.add_child(_chip("status_crit", tr("연격 ×%d") % cmb, Color("#ffb04a") if cmb >= 3 else C_GOLD,
			tr("연격: 같은 적을 이어 때리면 타격마다 +1(최대 %d). 콤보술사는 연격 1당 그 적에게 타격 피해 +1. 다른 적을 때리거나 턴이 끝나면 0") % P2Catalog.COMBO_MAX))
	if battle.class_id == "hunter" and battle.prep_enabled:
		var n := int(_shown.get("prep", 0))
		var ready := n >= P2Catalog.HUNTER_PREP_NEEDED
		_player_status.add_child(_chip("status_crit" if ready else "status_prepare", "확정 치명" if ready else "준비 " + "●".repeat(n) + "○".repeat(P2Catalog.HUNTER_PREP_NEEDED - n), C_CRIT,
			"사냥꾼 준비: 피해를 준 비치명 공격 카드 2번 → 다음 공격 카드는 확정 치명타. 치명타가 나면 0으로."))
	if battle.block_strike_ready:
		_player_status.add_child(_chip("status_counter", "첫 공격 +%d" % P2Battle.TRAIT_BLOCK_STRIKE_BONUS, C_GOLD, "막고 치기: 이번 턴 첫 공격 카드 피해 +%d" % P2Battle.TRAIT_BLOCK_STRIKE_BONUS))
	var res := int(_shown.get("res", 0))
	if res > 0 and battle.noble_index() >= 0:
		_player_status.add_child(_chip("status_resonance", tr("이번 턴 공격 ×%s") % ["1.5", "2"][res - 1], Color("#9fd4ff"),
			tr("이번 턴 귀족에게 피해를 준 카드 수(최대 2): 1장 = 내 공격 ×1.5 · 물창 11, 2장 = 내 공격 ×2 · 물창 14. 내 턴이 끝나면 처음부터.")))


# 직업·치명·특성 한정 효과는 초상 도움말과 전투 정보(Tab)에. 비축 인장 예고만 턴 종료 버튼 위에
func _render_status() -> void:
	var cname := String(P2Catalog.CLASSES.get(battle.class_id, {}).get("name", ""))
	_class_label.text = cname
	var lines := _status_lines()
	_portrait_button.tooltip_text = "\n".join(PackedStringArray(lines)) + "\n(누르거나 Tab: 전투 정보)"
	_trait_icon.visible = not battle.traits.is_empty()
	_trait_count.text = "×%d" % battle.traits.size() if battle.traits.size() > 1 else ""
	if not battle.traits.is_empty():
		if _trait_icon.texture == null:
			_trait_icon.texture = P2Catalog.icon_tex(battle.traits[0])
		_trait_icon.tooltip_text = "\n".join(PackedStringArray(battle.traits.map(func(t): return "%s — %s%s" % [P2Catalog.TRAITS[t].name, P2Catalog.TRAITS[t].text, " (이번 턴 사용함)" if battle.trait_used.has(t) else ""])))
		_trait_icon.mouse_filter = Control.MOUSE_FILTER_STOP
	var seal := battle.relics.has("reserve_seal") and _state == UI.PLAYER
	_seal_label.text = "끝내면 방어 +%d" % battle.end_turn_seal_preview() if seal else ""
	_seal_label.tooltip_text = "비축 인장: 턴을 끝낼 때 남은 마나 1당 방어 2 (최대 4)" if seal else ""
	_seal_label.mouse_filter = Control.MOUSE_FILTER_STOP if seal else Control.MOUSE_FILTER_IGNORE


# 지금 켜져 있는 규칙(직업·치명·특성 한정 효과·인장) 전체 문장
func _status_lines() -> Array[String]:
	var lines: Array[String] = []
	match battle.class_id:
		"rune_caster":
			lines.append("룬술사 · 최대 마나 %d" % battle.max_mana)
		"warden":
			lines.append("수호기사 · 카드로 얻은 반격 피해 +%d" % P2Catalog.WARDEN_COUNTER_BONUS)
		"hunter":
			lines.append("사냥꾼 · " + ("다음 공격 확정 치명타" if int(_shown.get("prep", 0)) >= P2Catalog.HUNTER_PREP_NEEDED else "준비 %d/%d" % [int(_shown.get("prep", 0)), P2Catalog.HUNTER_PREP_NEEDED]))
	if P2Catalog.CLASSES.has(battle.class_id):
		lines.append("직업 효과: " + String(P2Catalog.CLASSES[battle.class_id].passive))
	if battle.crit_mode != "off":
		lines.append("치명타 확률 %d%% · 피해 ×%s" % [battle.crit_chance(), str(snappedf(battle.crit_mult(), 0.01))])
	for t in battle.traits:
		lines.append("특성 %s%s — %s" % [P2Catalog.TRAITS[t].name, " (이번 턴 사용함)" if battle.trait_used.has(t) else "", P2Catalog.TRAITS[t].text])
	if battle.block_strike_ready:
		lines.append("막고 치기: 이번 턴 첫 공격 +%d" % P2Battle.TRAIT_BLOCK_STRIKE_BONUS)
	if battle.hex_active:
		lines.append("주술: 이번 턴 방어 카드 −%d" % P2Catalog.HEX_AMOUNT)
	elif battle.hex_next:
		lines.append("주술 예정: 다음 턴 방어 카드 −%d" % P2Catalog.HEX_AMOUNT)
	if battle.poison_ticks > 0:
		lines.append("독 %d: 내 턴 종료에 %d회 더 (방어 무시)" % [battle.poison_amount, battle.poison_ticks])
	if battle.relics.has("reserve_seal") and _state == UI.PLAYER:
		lines.append("비축 인장: 지금 끝내면 방어 +%d" % battle.end_turn_seal_preview())
	return lines


func _render_mana() -> void:
	var mana := int(GameState.get_flag("player_mana"))
	if _mana_label == null:
		return
	_mana_label.text = "%d/%d" % [mana, battle.max_mana]
	_mana_frame.tooltip_text = tr("마나 %d / %d — 카드를 낼 때 씁니다 (카드 왼쪽 위 숫자). 내 턴이 시작되면 다시 가득 찹니다.") % [mana, battle.max_mana]
	var f := clampf(float(mana) / float(battle.max_mana), 0.0, 1.0) if battle.max_mana > 0 else 0.0
	var to := lerpf(MANA_EMPTY_Y, MANA_FULL_Y, f) if mana > 0 else 48.0
	if _mana_level < 0.0 or _reduce_motion:
		_mana_level = to
		_mana_tilt = 0.0
		return
	if absf(to - _mana_level) < 0.01:
		return
	# 수위는 0.2초 따라가고, 수면은 줄면 오른쪽·차면 왼쪽으로 1px 남짓 기울었다가 0.4초 안에 가라앉는다
	if _mana_tw != null and _mana_tw.is_valid():
		_mana_tw.kill()
	_mana_tw = create_tween().set_parallel()
	_mana_tw.tween_property(self, "_mana_level", to, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_mana_tilt = 1.4 if to > _mana_level else -1.4
	_mana_tw.tween_property(self, "_mana_tilt", 0.0, 0.42).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


# 맥 물: UI 시계(일시정지·흔들림 줄이기를 따름)와 수위를 셰이더에 넘긴다. 흔들림 줄이기면 흐름·물결 없이 정확한 수위만
func _tick_mana(delta: float) -> void:
	if _mana_water == null:
		return
	if not _reduce_motion:
		_ui_clock += delta
	var mat := _mana_water.material as ShaderMaterial
	mat.set_shader_parameter("surface", _mana_level if _mana_level >= 0.0 else 48.0)
	mat.set_shader_parameter("tilt", 0.0 if _reduce_motion else _mana_tilt)
	mat.set_shader_parameter("clock", _ui_clock)
	mat.set_shader_parameter("flow", 0.0 if _reduce_motion else 1.0)


func _badge_text(block: int) -> String:
	var cq: Array = _shown.get("cq", [])
	var lines: Array[String] = []
	if block > 0:
		lines.append("방어 %d" % block)
	if not cq.is_empty():
		lines.append("반격 " + " · ".join(PackedStringArray(cq.map(func(v): return str(v)))))
	return "\n".join(lines)


# 사냥꾼 준비: 상태 칸에 ●○ / 확정 치명타. 준비되면 몸 주위가 금빛으로 빛난다 (무작위 치명타는 미리 보이지 않음)
func _render_prep() -> void:
	if _prep_label == null:
		return
	if battle.class_id != "hunter" or not battle.prep_enabled:
		_prep_label.text = ""
		if _crit_glow != null:
			_crit_glow.visible = false
	else:
		var n := int(_shown.get("prep", 0))
		var ready := n >= P2Catalog.HUNTER_PREP_NEEDED
		_prep_label.text = "다음 공격 확정 치명타" if ready else "준비 " + "●".repeat(n) + "○".repeat(P2Catalog.HUNTER_PREP_NEEDED - n)
		if _crit_glow != null:
			_crit_glow.visible = ready
	if _player_status != null:
		_render_player_status()


func _render_enemy(i: int, animate: bool) -> void:
	if i >= _enemy_panels.size():
		return
	var p: Dictionary = _enemy_panels[i]
	var e: Dictionary = _shown.enemies[i]
	(p.root as Control).visible = bool(e.alive)
	if not bool(e.alive):
		(p.charge as Control).visible = false
		return
	_tween_bar("enemy%d" % i, p.hp_bar, int(e.hp), animate)
	(p.hp_label as Label).text = "%d / %d" % [int(e.hp), int(e.max)]
	(p.info as Label).text = _info_text(i)
	# 거완 '3번 맞히면 약해짐'이 붙는 동안만 작은 글씨(12) — 갑옷 표시와 함께 한 줄에 들어가게
	(p.info as Label).add_theme_font_size_override("font_size", 12 if (p.info as Label).text.contains(tr("3번 맞히면 약해짐")) or (p.info as Label).text.contains(tr("다음 손패 1장 봉인")) else F)
	var intent: NinePatchRect = p.intent
	var il: Label = p.intent_label
	var act := battle.intent_action(i)
	if not act.is_empty():
		var full := P2Catalog.move_text(act)
		il.text = _intent_short(act, full)
		il.add_theme_color_override("font_color", Color("#e7d4ff"))
		intent.tooltip_text = _intent_detail(act, full)
	else:
		var hits := _shown_intent(i)
		var supp := int(e.get("supp", 0))
		var suppressed := supp > 0 and P2Battle._is_damaging(hits)
		var add := battle.attack_bonus + _shown_aura(i) + battle.affix_add(i)
		if P2Battle._is_damaging(hits):
			hits = hits.map(func(h): return maxi(0, battle.scaled(int(h)) + add - supp))
		il.text = P2Catalog.move_text(hits) + (" (+%d)" % add if add > 0 and not hits.is_empty() else "")
		if battle.is_spawn_slot(i):
			# 적 단계 도중(막 태어난 직후)에도 기한은 '다음 적 차례'이므로 같은 말. 수치는 실제 예고(억제 반영), 없으면 기본 6
			var bv := int(hits[0]) if P2Battle._is_damaging(hits) else int((P2Catalog.ENEMIES[battle.roles[i]].moves[0] as Array)[0])
			il.text = "다음 적 차례: 폭발 %d" % bv
		il.add_theme_color_override("font_color", C_BLOCK if suppressed else (Color("#ffb3a8") if add > 0 else C_TEXT))
		var why: Array[String] = []
		if add > 0:
			why.append("지원·위험 +%d" % add)
		if suppressed:
			why.append("억제 −%d" % supp)
		intent.tooltip_text = tr("다음 적 차례에 할 일: %s%s") % [il.text, " (" + ", ".join(why) + ")" if not why.is_empty() else ""]
		if battle.is_spawn_slot(i):
			intent.tooltip_text = "%s (방어로 막을 수 있음). 먼저 처치하면 폭발하지 않습니다." % il.text
		if not battle.unwind_info(i).is_empty():
			_unwind_intent(i, hits, il, intent)
		if P2Catalog.ENEMIES[battle.roles[i]].has("noble"):
			intent.tooltip_text = tr("물창: 이번 턴 귀족에게 피해를 준 카드 0·1·2장에 따라 8 · 11 · 14. 첫·세 번째 물창 뒤 다음 손패 1장을 묶습니다 (카드 2장으로 맞히면 풀림, 아니면 다음 내 턴에 풀림).")
	_fit_intent(p, i, act)
	var ct := _charge_text(i)
	(p.charge_label as Label).text = ct
	(p.charge as Control).visible = ct != ""
	var before := int((p.marks as Control).get_meta("count", 0))
	_set_mark_pips(p.marks, int(e.marks), -1)
	if animate and int(e.marks) > before:
		_mark_pulse(i)
	if _show != null:
		_show.render_status(i)


# 예고 칸 = 의미 아이콘 + 짧은 글. 피해 예고는 "공격 "을 떼고 숫자만(아이콘이 공격을 말한다). 칸 폭은 글자에 맞춘다
func _fit_intent(p: Dictionary, i: int, act: Dictionary) -> void:
	var intent: NinePatchRect = p.intent
	var il: Label = p.intent_label
	var icon := "intent_attack"
	if not act.is_empty():
		icon = {"hex": "intent_hex", "poison": "intent_poison", "summon": "intent_summon", "rebuild": "intent_rebuild"}.get(String(act.get("act", "")), "intent_unknown")
	else:
		var hits := _shown_intent(i)
		if not P2Battle._is_damaging(hits):
			icon = "intent_prepare"
		elif hits.size() > 1:
			icon = "intent_multi"
		elif not battle.charge_info(i).is_empty() or (not battle.unwind_info(i).is_empty() and battle.cycle_index(i) == int(battle.unwind_info(i).strike)):
			icon = "intent_heavy"
		elif _shown_aura(i) > 0:
			icon = "intent_support"
	if il.text.begins_with("공격 "):
		il.text = il.text.substr(3)
	(intent.get_meta("icon") as TextureRect).texture = _ui_tex(icon)
	if battle.parry_mode:
		_intent_pips(intent, i, act)
	_render_incoming()
	var w := clampf(_text_width(il.text, P2Ui.snap_size(F)) + 62.0, 96.0, 260.0)
	intent.size.x = w
	il.size.x = w - 52.0
	(p.strike as ColorRect).size.x = w - 52.0
	intent.position.x = ENEMY_W / 2.0 - w / 2.0


# 예고 칸에는 짧은 말, 정확한 효과는 도움말로 (새 용어를 만들지 않는다)
func _intent_short(act: Dictionary, full: String) -> String:
	match String(act.get("act", "")):
		"hex":
			return "주술 (방어 −%d)" % P2Catalog.HEX_AMOUNT
	return full


func _intent_detail(act: Dictionary, full: String) -> String:
	match String(act.get("act", "")):
		"summon":
			return "소환수 %d마리: 다음 내 차례가 지난 뒤 적 차례에 각각 폭발 6. 먼저 처치하면 폭발하지 않고, 폭발은 방어로 막을 수 있습니다." % int(act.get("count", 2))
		"hex":
			return "주술: 다음 내 턴 동안 방어 카드가 %d씩 약해집니다. 회복약으로 풀립니다." % P2Catalog.HEX_AMOUNT
		"poison":
			return "독: 내 턴이 끝날 때 방어를 무시하고 %d씩 %d회 들어옵니다. 회복약으로 풀립니다." % [int(act.get("amount", 2)), int(act.get("ticks", 2))]
		"rebuild":
			return "장치 재가동: 부서진 장치를 다시 세웁니다 (장치를 부숴도 승리가 아님)."
	return full


func _info_text(i: int) -> String:
	var parts: Array[String] = []
	var d: Dictionary = P2Catalog.ENEMIES[battle.roles[i]]
	if String(d.get("rank", "")) == "device":
		parts.append("장치")
	if bool(d.get("main", false)):
		parts.append("본체")
	if battle.armor[i] > 0:
		parts.append("갑옷 %d" % battle.armor[i])
	var sh := int(_shown.enemies[i].get("shield", 0))
	if sh > 0:
		parts.append("방패 %d" % sh)
	var u := battle.unwind_info(i)
	if not u.is_empty() and battle.unwind_window_open(i) and int(_shown.enemies[i].get("unwind", 0)) < int(u.need):
		parts.append(tr("3번 맞히면 약해짐"))
	if P2Catalog.ENEMIES[battle.roles[i]].has("noble") and battle.noble_seal_due():
		parts.append(tr("다음 손패 1장 봉인"))
	if int(d.get("aura", 0)) > 0:
		parts.append("지원 +%d" % int(d.aura))
	var supp := int(_shown.enemies[i].get("supp", 0))
	if supp > 0:
		parts.append("억제 −%d" % supp)
	return " · ".join(parts)


# 화면에 살아 있는 다른 기수의 지원 (기수가 쓰러지는 순간 예고가 바로 줄어든다)
func _shown_aura(i: int) -> int:
	var total := 0
	for k in range(battle.roles.size()):
		if k != i and bool(_shown.enemies[k].alive):
			total += int(P2Catalog.ENEMIES[battle.roles[k]].get("aura", 0))
	return total


func _charge_text(i: int) -> String:
	var c := battle.charge_info(i)
	if c.is_empty():
		return ""
	var moves: Array = P2Catalog.ENEMIES[battle.roles[i]].moves
	var cyc := battle.cycle_index(i)
	if battle.boss_locked.has(i):
		return "강타 %d 고정" % int(battle.boss_locked[i])
	if cyc == int(c.round):
		var t := int(_shown.tally)
		if t >= int(c.threshold):
			return "약화! 강타 %d → %d\n이번 턴 피해 %d / %d" % [int(c.full), int(c.weak), t, int(c.threshold)]
		return "강타 %d → 이번 턴 피해 %d를 주면 %d\n지금 %d / %d" % [int(c.full), int(c.threshold), int(c.weak), t, int(c.threshold)]
	var wait := posmod(int(c.round) - cyc, moves.size())
	return "강타 창까지 %d턴\n(강타 %d · 그 턴 피해 %d면 %d)" % [wait, int(c.full), int(c.threshold), int(c.weak)]


# 표시용 예고: 강타 창은 화면에 옮겨진 누적 피해(_shown.tally)로 약화 여부를 고른다. 거완은 화면에 옮겨진 횟수·굳힌 값
func _shown_intent(i: int) -> Array:
	var hits := battle.intent(i)
	var c := battle.charge_info(i)
	if not c.is_empty() and battle.cycle_index(i) == int(c.round) and not battle.boss_locked.has(i):
		hits = [int(c.weak) if int(_shown.tally) >= int(c.threshold) else int(c.full)]
	var u := battle.unwind_info(i)
	if not u.is_empty() and battle.cycle_index(i) == int(u.strike):
		var ul := int(_shown.enemies[i].get("ulock", -1))
		hits = [ul] if ul >= 0 else [int(u.weak) if int(_shown.enemies[i].get("unwind", 0)) >= int(u.need) else battle.unwind_full(i)]
	var nb: Dictionary = P2Catalog.ENEMIES[battle.roles[i]].get("noble", {})
	if not nb.is_empty():
		var nl := int(_shown.get("nlock", -1))
		hits = [nl] if nl >= 0 else [int(nb.lance[clampi(int(_shown.get("res", 0)), 0, 2)])]
	return hits


# 거완 예고 글: 준비 → '강타 준비', 강타 차례 → '강타 14 ○○○'(맞힌 칸) 또는 '강타 6·힘 풀림'. 긴 설명은 도움말 하나
func _unwind_intent(i: int, hits: Array, il: Label, intent: NinePatchRect) -> void:
	var u := battle.unwind_info(i)
	var e: Dictionary = _shown.enemies[i]
	var cyc := battle.cycle_index(i)
	var help := tr("강타 준비 뒤 다음 내 차례에 카드 직접 공격으로 이 적의 체력을 3번 줄이면 그 강타가 %d → %d로 약해집니다. 반격·가시·독·유물 추가 피해와 갑옷에 막혀 0인 타격은 세지 않습니다.") % [battle.unwind_full(i), int(u.weak)]
	if hits.is_empty() and posmod(cyc + 1, battle._moves(i).size()) == int(u.strike):
		il.text = tr("강타 준비")
		intent.tooltip_text = help
		return
	if cyc != int(u.strike):
		return
	var n := int(e.get("unwind", 0))
	var need := int(u.need)
	var weak := int(e.get("ulock", -1)) == int(u.weak) or (int(e.get("ulock", -1)) < 0 and n >= need)
	var v := int(hits[0]) if not hits.is_empty() else 0
	il.text = (tr("강타 %d·힘 풀림") % v) if weak else (tr("강타 %d") % v + " " + "●".repeat(n) + "○".repeat(need - n))
	intent.tooltip_text = help + "\n" + (tr("지금: 힘 풀림 · 이번 강타 %d") % v if weak else tr("지금 %d / %d번") % [n, need])


# 적 하나당 정보 칸(위에서부터): 예고 배지 · 이름 · 체력 · 상태 · 표식 · 예상 칸(미리보기 때만 채움), 그 아래 몸.
# 예상 칸을 미리 비워 두어 예상 배지가 얼굴·체력·예고·옆 적을 덮지 않는다. 몸 높이는 실제 그림에서 잰다.
# 혼자인 적(보스·미믹)은 정보 칸을 몸 왼쪽 빈 무대에 둔다. 대상 표시는 발밑 금색 타원
func _build_enemy_panels() -> void:
	for p in _enemy_panels:
		(p.root as Control).queue_free()
		(p.charge as Control).queue_free()
		(p.ring_node as Node).queue_free()
	_enemy_panels.clear()
	var slots: Array = _slots()
	var solo := battle.monsters.size() == 1
	for m in battle.monsters:
		var x := float(slots[m.index])
		var role: String = battle.roles[m.index]
		var tall := role in ["elite", "maek_elite_low", "maek_noble_mid", "boss", "leader", "hard_boss", "x_boss", "ruins_boss", "mimic_n", "mimic_h", "mimic_x", "maek_summoner_low"]
		var vis := _visible_size(m.index)
		_enemy_sprites[m.index].set_meta("torso_h", vis.y)
		var body := vis.y + 6.0
		var root := Control.new()
		var col_x := 0.0
		# 칸 하나가 머리 위 예고부터 발밑 정보까지 덮는다(마우스 대상 영역). 예상 칸은 몸 옆 빈 쪽
		root.position = Vector2(x - ENEMY_W / 2.0, maxf(48.0, FEET_Y - body - 46.0))
		root.size = Vector2(ENEMY_W, FEET_Y + 84.0 - root.position.y)
		root.set_meta("compact", true)
		var under := Vector2(0, FEET_Y - root.position.y)
		root.mouse_filter = Control.MOUSE_FILTER_STOP
		root.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		root.gui_input.connect(_on_enemy_input.bind(m.index))
		root.mouse_entered.connect(_on_enemy_hover.bind(m.index, true))
		root.mouse_exited.connect(_on_enemy_hover.bind(m.index, false))
		root.tooltip_text = "%s — %s" % [m.display_name, battle.role_text(m.index)]
		root.set_meta("body_center", Vector2(x, FEET_Y - vis.y * 0.5))
		_panels_root.add_child(root)
		var ring := _make_ring(root, Vector2(x, FEET_Y) - root.position, 4 if tall else 3)
		root.add_child(ring)
		var intent := _ui_patch("intent_plate", Vector2(96, 42), [6, 3, 6, 3])
		intent.position = Vector2(ENEMY_W / 2.0 - 48.0, 0)
		intent.mouse_filter = Control.MOUSE_FILTER_PASS
		root.add_child(intent)
		var intent_icon := TextureRect.new()
		intent_icon.texture = _ui_tex("intent_attack")
		intent_icon.position = Vector2(6, 3)
		intent_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		intent_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		intent.add_child(intent_icon)
		intent.set_meta("icon", intent_icon)
		var intent_label := _label("", F, C_TEXT)
		intent_label.position = Vector2(44, 9)
		intent_label.size = Vector2(46, 24)
		intent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		intent_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		intent_label.add_theme_color_override("font_outline_color", Color(0.12, 0.06, 0.08))
		intent_label.add_theme_constant_override("outline_size", 4)
		intent.add_child(intent_label)
		var strike := ColorRect.new()
		strike.color = Color(1, 0.9, 0.8, 0.9)
		strike.position = Vector2(44, 20)
		strike.size = Vector2(46, 2)
		strike.visible = false
		intent.add_child(strike)
		var rank := String(P2Catalog.ENEMIES[role].get("rank", ""))
		var ax := battle.affix(m.index)
		var name_label := _label("%s%s%s" % [tr("보스 · ") if rank == "boss" else "", (String(P2Catalog.AFFIX[ax].name) + " ") if ax != "" else "", m.display_name], F,
			(P2Catalog.AFFIX[ax].col as Color) if ax != "" else (C_GOLD if tall else C_TEXT))
		if ax != "":
			root.tooltip_text += "\n%s: %s" % [P2Catalog.AFFIX[ax].name, P2Catalog.AFFIX[ax].rule]
		name_label.position = under + Vector2(col_x - 12, 40)
		name_label.size = Vector2(ENEMY_W + 24, 22)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.clip_text = true
		name_label.add_theme_color_override("font_outline_color", Color.BLACK)
		name_label.add_theme_constant_override("outline_size", 4)
		root.add_child(name_label)
		var hp_bar := _ui_bar(under + Vector2(ENEMY_W / 2.0 - HP_W / 2.0, 16), HP_W)
		hp_bar.max_value = m.max_hp
		hp_bar.value = int(_shown.enemies[m.index].hp)
		(hp_bar.get_meta("sync") as Callable).call(hp_bar.value)
		root.add_child(hp_bar)
		var ghost := ColorRect.new()
		ghost.color = Color(1, 0.9, 0.5, 0.75)
		ghost.position = hp_bar.position + Vector2(9, 6)
		ghost.size = Vector2(0, 9)
		ghost.visible = false
		ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(ghost)
		var hp_label := _label("", F, C_TEXT)
		hp_label.position = hp_bar.position + Vector2(0, -1)
		hp_label.size = Vector2(HP_W, 22)
		hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hp_label.add_theme_color_override("font_outline_color", Color.BLACK)
		hp_label.add_theme_constant_override("outline_size", 4)
		root.add_child(hp_label)
		var info := _label("", F, Color("#d5dde4"))
		info.position = under + Vector2(col_x - 12, 62)
		info.size = Vector2(ENEMY_W + 24, 22)
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info.clip_text = true
		info.add_theme_color_override("font_outline_color", Color.BLACK)
		info.add_theme_constant_override("outline_size", 4)
		root.add_child(info)
		# 표식: 체력 막대 오른쪽에 생성 표식 그림 하나 + 실제 개수 글자 (원형 장식 없이 작게, 개수는 따로 그린 글자)
		var marks := Control.new()
		marks.position = hp_bar.position + Vector2(HP_W + 3, -2)
		marks.size = Vector2(46, 24)
		marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
		marks.visible = false
		root.add_child(marks)
		var mark_icon := TextureRect.new()
		mark_icon.texture = _arcane("mark")
		mark_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		mark_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		mark_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		mark_icon.size = Vector2(MARK_W, 24)
		mark_icon.pivot_offset = mark_icon.size / 2.0
		mark_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		marks.add_child(mark_icon)
		var mark_count := _label("", F, C_MARK)
		mark_count.position = Vector2(MARK_W, 0)
		mark_count.size = Vector2(22, 24)
		mark_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		mark_count.add_theme_color_override("font_outline_color", Color.BLACK)
		mark_count.add_theme_constant_override("outline_size", 3)
		marks.add_child(mark_count)
		marks.set_meta("icon", mark_icon)
		marks.set_meta("count_label", mark_count)
		# 예상 칸: 위 줄 = 예상 피해(처치), 아래 두 줄까지 = 치명 확률과 결과·방패·갑옷 등 (모두 20px). 실제 상태와 다른 밝은 판
		var pred := _ui_patch("tooltip_frame", Vector2(160, 68), [5, 5, 5, 5])
		pred.position = Vector2(col_x + 3, PRED_Y)
		if root.has_meta("compact"):
			# 몸 왼쪽이 비어 있으면 왼쪽, 다른 적의 몸에 걸리면 자기 몸 오른쪽(화면 안으로)
			var box := Rect2(x - vis.x / 2.0 - 150.0, 197.0, 160.0, 68.0)
			for k in range(battle.monsters.size()):
				var o := _visible_size(k)
				if k != m.index and box.intersects(Rect2(float(slots[k]) - o.x / 2.0, FEET_Y - o.y, o.x, o.y).grow(-8.0)):
					box.position.x = minf(x + vis.x / 2.0 - 10.0, 1278.0 - 160.0)
					break
			pred.position = box.position - root.position
		pred.visible = false
		root.add_child(pred)
		var pl := _label("", F, C_INK)
		pl.position = Vector2(10, 5)
		pl.size = Vector2(PRED_TEXT_W, 24)
		pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pl.clip_text = true
		pred.add_child(pl)
		var pd := _label("", F, Color("#e0bfa4"))
		pd.position = Vector2(10, 25)
		pd.size = Vector2(PRED_TEXT_W, 44)
		pd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pd.add_theme_constant_override("line_spacing", -4)
		pd.clip_text = true
		pred.add_child(pd)
		pred.set_meta("detail", pd)
		var charge := _ui_patch("tooltip_frame", Vector2(268, 70), [5, 5, 5, 5])
		charge.position = root.position + Vector2(col_x, -76)
		if not solo:
			charge.position = Vector2(x - 134, root.position.y - 76)
		charge.visible = false
		charge.mouse_filter = Control.MOUSE_FILTER_PASS
		charge.tooltip_text = tr("보스 강타 창: 그 턴에 보스에게 준 실제 피해가 기준 이상이면 강타가 약해집니다")
		_panels_root.add_child(charge)
		var cl := _label("", F, C_INK, charge.size.x - 28)
		cl.position = Vector2(14, 6)
		cl.size = Vector2(charge.size.x - 28, charge.size.y - 12)
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		charge.add_child(cl)
		root.set_meta("base_pos", root.position)
		charge.set_meta("base_pos", charge.position)
		_enemy_panels.append({"root": root, "ring": ring, "intent": intent, "intent_label": intent_label,
			"strike": strike, "hp_bar": hp_bar, "ghost": ghost, "hp_label": hp_label, "info": info,
			"marks": marks, "preview": pl, "pred": pred, "charge": charge, "charge_label": cl, "ring_node": ring.get_meta("node")})


# 대기 그림에서 실제로 칠해진 영역(전투 배율)의 너비·높이 (발밑 여백 제외)
func _visible_size(i: int) -> Vector2:
	var s := _enemy_sprites[i]
	if s.has_meta("art"):
		var a: Dictionary = _ea(s.get_meta("art"))
		return Vector2((float(a.right) - float(a.left)) * s.scale.x, ((a.foot as Vector2).y - float(a.top)) * s.scale.y)
	var frames := s.sprite_frames
	var top := 9999
	var left := 9999
	var right := 0
	var fh := 0
	for k in range(frames.get_frame_count("idle")):
		var img := frames.get_frame_texture("idle", k).get_image()
		var r := img.get_used_rect()
		fh = img.get_height()
		top = mini(top, r.position.y)
		left = mini(left, r.position.x)
		right = maxi(right, r.end.x)
	var foot := float(s.get_meta("foot_pad", 0.0))
	return Vector2(maxf(32.0, (right - left) * s.scale.x), maxf(48.0, (fh - foot - top) * s.scale.y))


# 대상 표시: 발밑 모서리 조각(target_feet). 몸 뒤 무대에 그리고, 실제로 대상을 고르는 중에만 보인다.
# 화면 쪽 ring 칸은 켜고 끄는 손잡이일 뿐 크기가 없다
func _make_ring(root: Control, center: Vector2, k: int) -> Panel:
	var ring := Panel.new()
	ring.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.visible = false
	var node := Node2D.new()
	node.position = root.position + center
	node.visible = false
	var sp := Sprite2D.new()
	sp.texture = _ui_tex("target_feet", k)
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sp.position = Vector2(0, 2)
	node.add_child(sp)
	_stage.add_child(node)
	_stage.move_child(node, _actors.get_index())
	var sync := func() -> void: node.visible = ring.visible and root.visible
	ring.visibility_changed.connect(sync)
	root.visibility_changed.connect(sync)
	ring.set_meta("node", node)
	return ring


# 실제(화면에 옮겨진) 표식 개수만 그린다. 미리보기의 변화는 예상 칸 글자로만 보인다 (예상과 실제를 섞지 않음)
func _set_mark_pips(box: Control, count: int, _preview_count: int) -> void:
	box.visible = count > 0
	box.set_meta("count", count)
	(box.get_meta("count_label") as Label).text = str(count)


# ── 손패 ────────────────────────────────────────────────────────────────────

func _build_hand(animate: bool, kept := {}, after := 0.0) -> void:
	_cancel_gesture("rebuild")
	_clear_focus()
	for v in _card_views.values():
		(v as Control).queue_free()
	_card_views.clear()
	_hand_root.position = Vector2.ZERO
	if _hand_rail != null:
		_hand_rail.modulate = Color.WHITE
	var cards := battle.hand.cards
	var k := 0
	for i in range(cards.size()):
		var view := _add_card_view(cards[i], i, cards.size())
		if animate and kept.has(cards[i]):
			_animate_card_in(view, 0.0, kept[cards[i]])
		elif animate:
			_animate_card_in(view, after + 0.06 * k)
			k += 1
	if animate and not cards.is_empty():
		_sfx("draw")
	_fit_hand_rail()
	_refresh_card_states()


# 부채꼴 자리 (회전 전 왼쪽 위 · 회전각). 회전 중심은 카드 아래 가운데. 바깥 카드는 10° 기울어도 마나 열·턴 종료 열(145~1135)을 넘지 않는다
const FAN_LEFT := 200.0
const FAN_RIGHT := 1060.0


func _fan(i: int, n: int) -> Dictionary:
	var pitch := REST.x + 10.0
	if n > 1:
		pitch = minf(pitch, (FAN_RIGHT - FAN_LEFT - REST.x) / float(n - 1))
	var total := REST.x + pitch * maxi(0, n - 1)
	var x := (FAN_LEFT + FAN_RIGHT) / 2.0 - total / 2.0 + i * pitch
	var t := 0.0
	if n > 1:
		t = (i - (n - 1) / 2.0) / ((n - 1) / 2.0)
	# 기울이지 않는다: 최근접 표본으로 그린 픽셀 글자는 회전하면 획이 계단처럼 끊겨 한글이 깨져 보인다
	return {"pos": Vector2(x, REST_TOP + 8.0 * t * t), "rot": 0.0}


func _add_card_view(card: Card, i: int, n: int) -> Control:
	var view := _card_face(card, 2, str(i + 1))
	view.pivot_offset = Vector2(REST.x / 2.0, REST.y)
	var g := _fan(i, n)
	view.position = g.pos
	view.rotation_degrees = g.rot
	view.set_meta("home", g.pos)
	view.set_meta("rot", g.rot)
	_hand_root.add_child(view)
	_card_views[card] = view
	return view


# 전투 카드 한 장: 전투 UI 조각 틀(공격·방어·마법·기술 × 보통·강화) + 기존 카드 그림·이름·본문·단축키·비용.
# 쉬는 카드 3배(168×264), 올린 카드 4배(224×352). 보상·덱 보기 화면의 P2Ui.card_art는 바꾸지 않는다
func _card_face(card: Card, s: int, key: String) -> Control:
	var k := 3 if s < 3 else 4
	var big := k == 4
	var kind := String({"red": "attack", "grey": "defense", "blue": "magic", "green": "skill"}.get(P2Catalog.frame_color(card), "skill"))
	var upgraded := P2Catalog.upgrade_of(card) != ""
	var root := Control.new()
	root.size = Vector2(56, 88) * k
	root.custom_minimum_size = root.size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_ui_rect("card_%s_%s" % [kind, "upgraded" if upgraded else "normal"], Vector2.ZERO, k))
	var icon_size := 32.0 * (k - 1)
	var ic := P2Ui.tex_icon(P2Catalog.icon_tex(P2Catalog.card_icon_key(card)), icon_size)
	ic.position = (Vector2(7, 9) * k + (Vector2(43, 26) * k - Vector2(icon_size, icon_size)) / 2.0).floor()
	root.add_child(ic)
	var owner := String(P2Catalog.CARD_CLASS.get(P2Catalog.kind_of(card), ""))
	if owner != "":
		var badge := P2Ui.class_badge(owner, 7.0 * k)
		badge.position = Vector2(50 * k - 7.0 * k * 0.6, 9 * k - 7.0 * k * 0.35).floor()
		root.add_child(badge)
	var nm := _label(card.card_name, P2Ui.T_HEAD if big else P2Ui.T_BODY, C_GOLD if upgraded else Color.WHITE)
	nm.add_theme_color_override("font_outline_color", Color("#0e0c20"))
	nm.add_theme_constant_override("outline_size", 4)
	nm.position = Vector2(4, 38) * k + Vector2(0, -4)
	nm.size = Vector2(48, 6) * k + Vector2(0, 8)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nm.clip_text = true
	root.add_child(nm)
	if upgraded:
		root.add_child(_ui_rect("upgrade_badge", Vector2(46, 34) * k, k))
	var f := P2Catalog.face(card, battle.class_id)
	var body_rect := Rect2(Vector2(7, 46) * k, Vector2(43, 35) * k)
	var head := _label(String(f[0]), P2Ui.T_HEAD if big else P2Ui.T_BODY, P2Ui.C_GOOD if int(f[2]) > 0 else Color("#fff4df"), body_rect.size.x - 2)
	head.add_theme_color_override("font_outline_color", Color("#0e0c20"))
	head.add_theme_constant_override("outline_size", 3)
	head.position = body_rect.position + Vector2(1, 6)
	head.size = Vector2(body_rect.size.x - 2, 0)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(head)
	root.set_meta("head", head)
	var tag_y := body_rect.position.y + 6.0 + maxf(26.0, head.get_minimum_size().y) + 2.0
	if big:
		var body := _label(String(f[1]), P2Ui.T_BODY, Color(0.96, 0.92, 0.85), body_rect.size.x - 8)
		body.position = Vector2(body_rect.position.x + 4, tag_y)
		body.size = Vector2(body_rect.size.x - 8, 0)
		body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		body.add_theme_constant_override("line_spacing", 0)
		root.add_child(body)
		root.set_meta("body", body)
		tag_y = body_rect.end.y - 26.0
	var tag_bg := ColorRect.new()
	tag_bg.color = Color(0.06, 0.05, 0.1, 0.85)
	tag_bg.position = Vector2(body_rect.position.x, tag_y)
	tag_bg.size = Vector2(body_rect.size.x, 24)
	tag_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag_bg.visible = false
	root.add_child(tag_bg)
	var tag := _label("", P2Ui.T_BODY if big else P2Ui.T_SMALL, C_GOLD)
	tag.position = tag_bg.position
	tag.size = tag_bg.size
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tag.clip_text = true
	root.add_child(tag)
	root.set_meta("tag", tag)
	root.set_meta("tag_bg", tag_bg)
	var badge := _ui_rect("cost_drop", Vector2(2, 0) * k, k)
	root.add_child(badge)
	var cost := _label("X" if P2Catalog.is_x_cost(card) else str(card.mana_cost), P2Ui.T_HEAD, Color("#e2f1ff"))
	cost.add_theme_color_override("font_outline_color", Color("#16304f"))
	cost.add_theme_constant_override("outline_size", 4)
	cost.position = Vector2(0, 4 * k)
	cost.size = Vector2(14, 14) * k
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(cost)
	root.set_meta("cost", cost)
	root.set_meta("badge", badge)
	# 고른 카드 표시 = 맥 테두리 조각 (강화 테두리와 다른 것). 기존 코드가 Panel로 켜고 끄므로 Panel에 조각을 입힌다
	var glow := Panel.new()
	var gs := StyleBoxTexture.new()
	gs.texture = _ui_tex("card_selection_rim", k)
	glow.add_theme_stylebox_override("panel", gs)
	glow.size = root.size
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.visible = false
	root.add_child(glow)
	root.set_meta("glow", glow)
	if key != "":
		var cap := _ui_patch("hotkey_badge", Vector2(30, 24), [2, 2, 2, 2])
		cap.position = Vector2(root.size.x / 2.0 - 15.0, -18)
		cap.mouse_filter = Control.MOUSE_FILTER_PASS
		cap.tooltip_text = tr("단축키 %s") % key
		var kl := _label(key, P2Ui.T_SMALL, Color("#d9cdb8"))
		kl.size = Vector2(30, 24)
		kl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		kl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cap.add_child(kl)
		root.add_child(cap)
		root.set_meta("key", kl)
	root.set_meta("card", card)
	return root


# 뽑기: 뽑기 더미에서 작게 나와 위로 휘어 날아와 제자리에 톡 안착한다(카드마다 짧은 소리).
# 남는 카드(보존·봉인)는 옛 자리에서 새 자리로 옮겨 간다. 나는 동안 제자리가 바뀌면 그쪽으로 간다
func _animate_card_in(view: Control, delay: float, from := Vector2.INF) -> void:
	view.set_meta("entering", true)
	var done := func() -> void:
		view.set_meta("entering", false)
		_place_hand()
		_refresh_card_states()
	if _reduce_motion:
		view.modulate.a = 0.0
		var t0 := view.create_tween()
		t0.tween_property(view, "modulate:a", 1.0, 0.15).set_delay(delay)
		t0.tween_callback(done)
		return
	var pile := from == Vector2.INF
	var src := from if not pile else Vector2(18 + 24, PILES_Y + 24) - Vector2(REST.x / 2.0, REST.y * 0.9)
	view.position = src
	if pile:
		view.scale = Vector2(0.2, 0.2)
		view.modulate.a = 0.0
	var fly := func(u: float) -> void:
		var home: Vector2 = view.get_meta("home")
		view.position = src.lerp(home, u) - Vector2(0, sin(u * PI) * (70.0 if pile else 24.0))
	var t := view.create_tween()
	t.tween_interval(delay)
	if pile:
		t.tween_callback(func() -> void: _sfx("draw", 0.95 + 0.05 * float(view.get_index()), -8.0))
	t.tween_method(fly, 0.0, 1.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if pile:
		t.parallel().tween_property(view, "modulate:a", 1.0, 0.08)
		t.parallel().tween_property(view, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_callback(done)


# 턴 끝: 남지 않는 카드는 버림 더미로 작아지며 차례로 날아간다. 남는 카드는 지금 자리를 돌려준다
func _discard_hand_views() -> Dictionary:
	var kept := {}
	var dest := Vector2(18 + 56 + 24, PILES_Y + 24)
	var k := 0
	for card in _card_views.keys():
		var v: Control = _card_views[card]
		# 버렸다가 섞여 다시 뽑힌 같은 카드는 남은 카드가 아니다
		if battle.hand.cards.has(card) and (P2Catalog.retains(card) or P2Catalog.uid_of(card) == battle._noble_released):
			kept[card] = v.global_position
			continue
		_card_views.erase(card)
		if _reduce_motion:
			v.queue_free()
			continue
		v.reparent(_ui)
		var from := v.position
		var to := dest - v.pivot_offset
		var t := v.create_tween()
		t.tween_interval(0.03 * k)
		t.tween_method(func(u: float) -> void: v.position = from.lerp(to, u) - Vector2(0, sin(u * PI) * 40.0), 0.0, 1.0, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.parallel().tween_property(v, "scale", Vector2(0.15, 0.15), 0.24).set_ease(Tween.EASE_IN)
		t.parallel().tween_property(v, "modulate:a", 0.0, 0.24).set_ease(Tween.EASE_IN)
		t.tween_callback(v.queue_free)
		k += 1
	if k > 0:
		_sfx("draw", 0.8, -10.0)
	return kept


# 뽑기(집중·예비 주머니): 새로 들어온 카드만 아래에서 올라오고, 나머지는 자리만 옮긴다
func _add_drawn_cards() -> int:
	var cards := battle.hand.cards
	var added := 0
	for i in range(cards.size()):
		if _card_views.has(cards[i]):
			continue
		var view := _add_card_view(cards[i], i, cards.size())
		_animate_card_in(view, 0.06 * added)
		added += 1
	_relayout_hand()
	return added


func _renumber_hand() -> void:
	var cards := battle.hand.cards
	for i in range(cards.size()):
		if _card_views.has(cards[i]):
			var key: Label = (_card_views[cards[i]] as Control).get_meta("key")
			key.text = str(i + 1)
			(key.get_parent() as Control).tooltip_text = tr("단축키 %s") % str(i + 1)


func _apply_tag(view: Control, card: Card, fuel_target: bool) -> void:
	var tg: Array = _card_tag(card)
	var tag: Label = view.get_meta("tag")
	tag.text = String(tg[0])
	tag.add_theme_color_override("font_color", tg[1])
	if fuel_target:
		tag.text = "함께 소진"
		tag.add_theme_color_override("font_color", C_FIRE)
	(view.get_meta("tag_bg") as ColorRect).visible = tag.text != ""


# 카드 아래 한 줄: 지금 상태에서 달라지는 값 (보존·충전, 소진, 폭류 X, 장막 방어, 확정 치명)
func _card_tag(card: Card) -> Array:
	var kind := P2Catalog.kind_of(card)
	var mana := int(GameState.get_flag("player_mana"))
	if String(_shown.get("seal_uid", "")) == P2Catalog.uid_of(card):
		return [tr("봉인 · 공격 %d장") % maxi(1, 2 - int(_shown.get("res", 0))), C_MARK]
	if P2Catalog.retains(card):
		if battle.aim_charged.has(P2Catalog.uid_of(card)):
			return ["충전됨 · 피해 %d" % battle.card_base_value(card), C_CRIT]
		return ["보존 · 한 턴 뒤 %d" % (P2Catalog.FULL_AIM_CHARGED if P2Catalog.upgrade_of(card) == "full_aim" else P2Catalog.AIM_CHARGED), Color("#9fd4ff")]
	if P2Catalog.is_x_cost(card):
		var x := maxi(1, mana)
		return ["X = %d → 마법 %d" % [x, card.value * x] if mana > 0 else "마나 없음", Color("#9fd4ff")]
	if kind == "mana_veil":
		return ["지금 방어 %d" % (card.value + mini(P2Catalog.VEIL_BONUS_CAP, 2 * maxi(0, mana - card.get_mana_cost()))), C_BLOCK]
	if P2Catalog.exhausts(card):
		return ["소진 (이번 전투)", C_FIRE]
	if P2Catalog.is_attack(card) and int(_shown.get("prep", 0)) >= P2Catalog.HUNTER_PREP_NEEDED and battle.class_id == "hunter" and battle.prep_enabled:
		return ["확정 치명타", C_CRIT]
	if card.effect == Card.EffectType.DEFEND and battle.hex_active:
		return ["주술: 방어 −%d" % P2Catalog.HEX_AMOUNT, C_MARK]
	if P2Catalog.is_attack(card):
		var fb := 0
		var parts: Dictionary = battle.first_hit_bonus(card)
		for k in parts:
			fb += int(parts[k])
		if fb > 0:
			return ["첫 타격 +%d" % fb, C_GOLD]
	return ["", C_TEXT]


func _refresh_card_states() -> void:
	_update_focus()
	for card in _card_views:
		var view: Control = _card_views[card]
		view.visible = card != _big_card and not view.has_meta("returning") and (_drag.is_empty() or card != _drag.card)
		if view.get_meta("entering", false):
			continue
		var shown_sealed := String(_shown.get("seal_uid", "")) == P2Catalog.uid_of(card)
		var playable := battle != null and battle.can_play_card(card) and not shown_sealed
		_seal_badge(view, "hold" if shown_sealed else "off")
		var picked := _state == UI.MULLIGAN and _mull_pick.has(P2Catalog.uid_of(card))
		var fuel_target := _state == UI.FUEL and P2Catalog.uid_of(card) == _fuel_pick
		view.modulate = Color.WHITE if playable or _state == UI.MULLIGAN or _state == UI.FUEL else Color(0.55, 0.55, 0.55)
		if picked:
			view.modulate = Color(1.3, 1.1, 0.7)
		if fuel_target:
			view.modulate = Color(1.45, 0.75, 0.55)
		_apply_tag(view, card, fuel_target)
		var chosen: bool = card == _selected or picked or fuel_target
		var glow: Panel = view.get_meta("glow")
		glow.visible = chosen
		glow.modulate = C_FIRE if fuel_target else Color.WHITE
		var home: Vector2 = view.get_meta("home")
		view.position.y = home.y + (-24.0 if chosen else 0.0)
	if _big != null and _big_card != null:
		var fuel_big := _state == UI.FUEL and P2Catalog.uid_of(_big_card) == _fuel_pick
		_big.modulate = Color.WHITE if battle.can_play_card(_big_card) or _state == UI.MULLIGAN or _state == UI.FUEL else Color(0.7, 0.7, 0.7)
		_apply_tag(_big, _big_card, fuel_big)
		(_big.get_meta("glow") as Panel).visible = _big_card == _selected or fuel_big
	if _state == UI.FUEL:
		var other := _hand_card(_fuel_pick)
		_use_button.text = "함께 소진\n확정 [Enter]"
		_use_button.visible = other != null
	elif _selected != null and _card_views.has(_selected) and not P2Catalog.is_targeted(_selected) and _state == UI.PLAYER:
		_use_button.text = "%s\n%s" % [_selected.card_name, tr("사용 [Enter]")]
		_use_button.visible = true
	elif _state == UI.MULLIGAN:
		_use_button.text = "교체 확정\n(%d장)" % _mull_pick.size()
		_use_button.visible = true
	else:
		_use_button.visible = false
	_end_button.disabled = _state != UI.PLAYER
	_end_button.modulate.a = 0.35 if _state == UI.ENEMY else 1.0
	var any := false
	if battle != null and _state == UI.PLAYER:
		for c in battle.hand.cards:
			any = any or battle.can_play_card(c)
	_end_button.self_modulate = Color(1.3, 1.2, 0.85) if _state == UI.PLAYER and not any else Color.WHITE
	if _retreat_button != null and is_instance_valid(_retreat_button):
		_retreat_button.disabled = _state != UI.PLAYER
	_render_potions()
	_render_phase()
	_mull_button.visible = (_state == UI.PLAYER or _state == UI.MULLIGAN) and battle.can_mulligan()
	_mull_button.text = "교체 취소" if _state == UI.MULLIGAN else "손패 교체"
	_cancel_button.visible = _state == UI.FUEL or (_state == UI.PLAYER and _selected != null)


# ── 올린 카드 ────────────────────────────────────────────────────────────────
# 마우스 아래 카드 > 고른 카드(키보드 포함) 순. 그 카드 자리 바로 위에 곧게 세워 BIG 크기로 그리고, 쉬는 자리는 비운다.
# 올린 카드는 표시만 하고 입력을 받지 않는다. 끄는 동안에는 올린 카드 대신 작아진 카드가 마우스를 따라온다

func _focus_target() -> Card:
	if not _drag.is_empty():
		return null
	if not (_state == UI.PLAYER or _state == UI.FUEL or _state == UI.MULLIGAN):
		return null
	if _hover != null and _card_views.has(_hover):
		return _hover
	if _selected != null and _card_views.has(_selected):
		return _selected
	return null


func _update_focus() -> void:
	var card := _focus_target()
	if card == _big_card:
		if _big != null and _card_views.has(card):
			var to := _big_bottom(_card_views[card]) - _big.pivot_offset
			if to.distance_to(_big.position) > 1.0 and not _reduce_motion:
				_big.create_tween().tween_property(_big, "position", to, 0.08).set_ease(Tween.EASE_OUT)
			else:
				_big.position = to
		return
	_clear_focus()
	if card == null or not _card_views.has(card):
		_place_hand()
		return
	var view: Control = _card_views[card]
	_big = _card_face(card, 3, str(battle.hand.cards.find(card) + 1))
	_big.pivot_offset = Vector2(BIG.x / 2.0, BIG.y)
	_big_card = card
	if not _reduce_motion and _big.get_child(0) is TextureRect:
		var shine := ColorRect.new()
		shine.size = BIG
		shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sm := ShaderMaterial.new()
		sm.shader = SHINE
		sm.set_shader_parameter("mask", (_big.get_child(0) as TextureRect).texture)
		shine.material = sm
		_big.add_child(shine)
		shine.create_tween().tween_method(func(u: float) -> void: sm.set_shader_parameter("t", u), -0.2, 1.2, 0.42).set_delay(0.05)
	var shadow := Panel.new()
	var ss := StyleBoxFlat.new()
	ss.bg_color = Color(0, 0, 0, 0.28)
	ss.set_corner_radius_all(10)
	shadow.add_theme_stylebox_override("panel", ss)
	shadow.size = BIG
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_big.add_child(shadow)
	_big.move_child(shadow, 0)
	_mouse_through(_big)
	_big_root.add_child(_big)
	view.visible = false
	if _hover == card and _selected != card:
		_sfx("select", 0.9 + 0.06 * battle.hand.cards.find(card), -12.0)
	var to := _big_bottom(view) - _big.pivot_offset
	if _reduce_motion or view.get_meta("entering", false):
		_big.position = to
		shadow.position = Vector2(8, 10)
	else:
		_big.position = view.position + view.pivot_offset - _big.pivot_offset
		_big.rotation_degrees = view.rotation_degrees
		_big.scale = Vector2.ONE * (REST.x / BIG.x)
		var t := _big.create_tween().set_parallel()
		t.tween_property(_big, "position", to, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(_big, "rotation_degrees", 0.0, 0.12)
		t.tween_property(_big, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(shadow, "position", Vector2(8, 10), 0.16).from(Vector2.ZERO)
	_place_hand()
	_hand_hit.tooltip_text = "%s\n%s" % [P2Catalog.long_text(P2Catalog.kind_of(card), P2Catalog.upgrade_of(card)),
		tr("마나 %s · 단축키 %d") % ["X" if P2Catalog.is_x_cost(card) else str(card.mana_cost), battle.hand.cards.find(card) + 1]]


func _deny_shake(card: Card) -> void:
	var v: Control = _big if _big_card == card and _big != null else _card_views.get(card)
	if v != null and not v.has_meta("deny") and not _reduce_motion:
		v.set_meta("deny", true)
		var x0 := v.position.x
		var t := v.create_tween()
		for dx in [8.0, -7.0, 5.0, -3.0, 0.0]:
			t.tween_property(v, "position:x", x0 + dx, 0.035)
		t.tween_callback(func() -> void: v.remove_meta("deny"))
	if battle.is_noble_sealed(card) or P2Catalog.is_fuel(card):
		return
	_float_number(tr("마나 부족"), MANA_ORB + Vector2(56, -40), Color("#ff8a7a"), F, 18.0, 0.7)
	if _reduce_motion:
		return
	_mana_label.pivot_offset = _mana_label.size / 2.0
	var m := _mana_label.create_tween()
	m.tween_property(_mana_label, "modulate", Color(1.0, 0.4, 0.35), 0.05)
	m.parallel().tween_property(_mana_label, "scale", Vector2(1.3, 1.3), 0.05)
	m.tween_property(_mana_label, "modulate", Color.WHITE, 0.35)
	m.parallel().tween_property(_mana_label, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# 올린 카드 아래 가운데: 그 카드 자리 바로 위(가운데로 옮기지 않는다). 화면 밖으로만 안 나가게
func _big_bottom(view: Control) -> Vector2:
	var cx: float = (view.get_meta("home") as Vector2).x + REST.x / 2.0
	return Vector2(clampf(cx, BIG.x / 2.0 + 8.0, 1280.0 - BIG.x / 2.0 - 8.0), BIG_BOTTOM)


func _clear_focus() -> void:
	if _big != null:
		var old := _big
		var view: Control = _card_views.get(_big_card)
		if view != null and is_instance_valid(view) and not _reduce_motion and _state == UI.PLAYER:
			# 내려놓기: 제자리 크기로 줄어들며 돌아간 뒤 손패 카드가 다시 보인다
			view.set_meta("returning", true)
			var to := view.position + view.pivot_offset - old.pivot_offset
			var t := old.create_tween().set_parallel()
			t.tween_property(old, "position", to, 0.1).set_ease(Tween.EASE_OUT)
			t.tween_property(old, "scale", Vector2.ONE * (REST.x / BIG.x), 0.1).set_ease(Tween.EASE_OUT)
			var vref: WeakRef = weakref(view)
			t.chain().tween_callback(func() -> void:
				old.queue_free()
				var vv: Control = vref.get_ref()
				if vv != null:
					vv.remove_meta("returning")
					vv.visible = _card_views.values().has(vv) and _card_views.get(_big_card) != vv and (_drag.is_empty() or _card_views.get(_drag.card) != vv))
		else:
			old.queue_free()
	_big = null
	if _big_card != null and _card_views.has(_big_card) and not (_card_views[_big_card] as Control).has_meta("returning"):
		(_card_views[_big_card] as Control).visible = true
	_big_card = null
	if _hand_hit != null:
		_hand_hit.tooltip_text = ""


func _hand_card(uid: String) -> Card:
	if uid == "":
		return null
	for c in battle.hand.cards:
		if P2Catalog.uid_of(c) == uid:
			return c
	return null


# ── 입력 ────────────────────────────────────────────────────────────────────

# 쉬는 카드 모양(회전 반영) 안에 든 카드 중 가운데가 가장 가까운 카드. 지금 카드에는 6px 여유(경계 깜빡임 방지).
# 쉬는 카드보다 위쪽이면 올린 카드 영역 안에서만 지금 카드를 유지한다
func _card_at(p: Vector2) -> Card:
	var best: Card = null
	var best_d := INF
	for c in battle.hand.cards:
		if not _card_views.has(c):
			continue
		var view: Control = _card_views[c]
		var home: Vector2 = view.get_meta("home")
		var pivot := home + Vector2(REST.x / 2.0, REST.y)
		var local := (p - pivot).rotated(-deg_to_rad(float(view.get_meta("rot")))) + Vector2(REST.x / 2.0, REST.y)
		if local.x < -2.0 or local.x > REST.x + 2.0 or local.y < -24.0 or local.y > REST.y + 40.0:
			continue
		var d := absf(local.x - REST.x / 2.0) - (6.0 if c == _hover else 0.0)
		if d < best_d:
			best_d = d
			best = c
	if best == null and _hover != null and _big != null and _big_card == _hover:
		var r := Rect2(_big_bottom(_card_views[_hover]) - _big.pivot_offset, BIG)
		if r.has_point(p):
			return _hover
	return best


func _set_hover(card: Card) -> void:
	if card == _hover:
		return
	_hover = card
	_refresh_card_states()
	if _state != UI.PLAYER or _selected != null or not _drag.is_empty():
		return
	if card != null:
		var target := _target
		if P2Catalog.is_targeted(card) and (target < 0 or not battle.get_monster(target).is_alive()):
			target = battle.alive_monsters()[0].index
		_clear_preview()
		_show_preview(card, target if P2Catalog.is_targeted(card) else -1)
	else:
		_refresh_targeting()


func _on_hand_exit() -> void:
	if _drag.is_empty() and _press.is_empty():
		_set_hover(null)


func _on_hand_input(event: InputEvent) -> void:
	if battle == null or (gate != null and gate.is_open()):
		return
	if event is InputEventMouseMotion:
		var p: Vector2 = _hand_hit.position + (event as InputEventMouseMotion).position
		if not _drag.is_empty():
			_update_drag(p)
		elif not _press.is_empty() and ((event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			if not bool(_press.get("consumed", false)) and p.distance_to(_press.pos) > DRAG_THRESHOLD:
				_try_begin_drag(p)
		else:
			_set_hover(_card_at(p))
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		var p2: Vector2 = _hand_hit.position + mb.position
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_set_hover(_card_at(p2))
				_press = {"card": _hover, "pos": p2} if _hover != null else {}
			else:
				_on_left_release(p2)
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if not _drag.is_empty() or not _press.is_empty():
				_cancel_gesture("right_click")
			else:
				_cancel_selection()
	_hand_hit.accept_event()


# 문턱을 넘지 않고 놓으면 기존 클릭 동작 (교체 고르기 · 연료 고르기 · 고르기 · 같은 카드 다시 = 사용)
func _on_left_release(p: Vector2) -> void:
	if not _drag.is_empty():
		await _end_drag(p)
		return
	if _press.is_empty():
		return
	var card: Card = _press.card
	var consumed := bool(_press.get("consumed", false))
	_press = {}
	if consumed or not battle.hand.cards.has(card):
		return
	gesture_log.append({"frame": Engine.get_process_frames(), "kind": "click", "card": card.card_name})
	if _state == UI.MULLIGAN:
		_toggle_mull_pick(card)
	elif _state == UI.FUEL:
		_pick_fuel(card)
	elif _selected == card and not P2Catalog.is_targeted(card):
		_confirm_selected()
	else:
		_select_card(card)


func _drag_zone(card: Card) -> String:
	if P2Catalog.is_targeted(card):
		return "enemy"
	if P2Catalog.is_debuff(card) and card.is_aoe:
		return "all"
	if P2Catalog.is_fuel(card):
		return "fuel"
	if P2Catalog.is_attack(card):
		return "all"
	return "self"


func _try_begin_drag(p: Vector2) -> void:
	var card: Card = _press.card
	if _state != UI.PLAYER or not battle.hand.cards.has(card):
		return
	if not battle.can_play_card(card):
		_press.consumed = true
		_select_card(card)
		return
	var zone := _drag_zone(card)
	_drag = {"card": card, "zone": zone, "target": -1, "valid": false}
	_press = {}
	_hover = card
	gesture_log.append({"frame": Engine.get_process_frames(), "kind": "drag_begin", "card": card.card_name, "zone": zone})
	_sfx("select", 1.15, -4.0)
	_zone_self.visible = zone == "self" or zone == "fuel"
	_zone_all.visible = zone == "all"
	_show_drop_line(zone == "self" or zone == "fuel")
	_fit_zone(_zone_self, _player_rect().grow(14.0))
	_fit_zone(_zone_all, _enemies_rect().grow(14.0))
	_clear_focus()
	if _card_views.has(card):
		(_card_views[card] as Control).visible = false
	_drag_ghost = _card_face(card, 3, "")
	_drag_ghost.pivot_offset = REST / 2.0
	_drag_ghost.scale = Vector2.ONE * 0.72
	_mouse_through(_drag_ghost)
	_drag_ghost.position = p - REST / 2.0 + Vector2(0, 30)
	_ui.add_child(_drag_ghost)
	_place_hand()
	_refresh_card_states()
	_update_drag(p, true)


func _enemy_near(p: Vector2) -> int:
	if p.y > HAND_HIT_TOP or p.x < 540.0:
		return -1
	var best := -1
	var best_d := 150.0
	for i in range(_enemy_panels.size()):
		if not bool(_shown.enemies[i].alive) or not battle.get_monster(i).is_alive():
			continue
		var root: Control = _enemy_panels[i].root
		var d := absf(p.x - (root.position.x + root.size.x / 2.0))
		if Rect2(root.position, root.size).grow(12.0).has_point(p):
			d -= 1000.0
		if d < best_d:
			best_d = d
			best = i
	return best


func _update_drag(p: Vector2, force := false) -> void:
	var zone := String(_drag.zone)
	var target := -1
	var valid := false
	match zone:
		"enemy":
			target = _enemy_near(p)
			valid = target >= 0
		"all":
			valid = _enemies_rect().grow(60.0).has_point(p) or (p.x > 560.0 and p.y < HAND_HIT_TOP)
		_:
			# 나에게 쓰는 카드는 손패 위 아무 곳에 놓아도 쓴다(주인공을 겨눌 필요 없음)
			valid = p.y < HAND_HIT_TOP
	var changed := force or valid != bool(_drag.valid) or target != int(_drag.target)
	_drag.valid = valid
	_drag.target = target
	if _drag_ghost != null:
		# 마우스를 따라 기울며 오고, 쓸 수 있는 자리 위에서는 조금 더 작아지고 밝아진다
		_drag_ghost.position = p - REST / 2.0 + Vector2(0, 30)
		var tilt := clampf((p.x - float(_drag.get("last_x", p.x))) * 0.012, -0.22, 0.22)
		_drag_ghost.rotation = lerpf(_drag_ghost.rotation, tilt, 0.35)
		_drag.last_x = p.x
		_drag_ghost.scale = Vector2.ONE * (0.6 if valid else 0.72)
		_drag_ghost.modulate = Color(1.2, 1.12, 0.95) if valid else Color.WHITE
	if changed:
		_drag_preview()
		if _drop_line != null and _drop_line.visible:
			_drop_line.queue_redraw()


# 끄는 동안의 예고: 복제본 미리보기(preview_ex)만 쓰고 실제 체력·표식·마나는 건드리지 않는다
func _drag_preview() -> void:
	var card: Card = _drag.card
	var zone := String(_drag.zone)
	var valid := bool(_drag.valid)
	_clear_preview()
	for i in range(_enemy_panels.size()):
		var on := valid and bool(_shown.enemies[i].alive) and (zone == "all" or zone == "enemy" and i == int(_drag.target))
		(_enemy_panels[i].ring as Panel).visible = on
	for z in [_zone_self, _zone_all]:
		(z.get_meta("style") as StyleBoxFlat).bg_color = Color(1, 0.85, 0.45, 0.14 if valid else 0.04)
	if valid:
		if zone == "fuel":
			_set_prompt(tr("놓으면 함께 소진할 카드 고르기로") + "\n" + tr("(아직 아무것도 소진하지 않음)"))
		else:
			_set_prompt("")
			_show_preview(card, int(_drag.target) if zone == "enemy" else -1)
	else:
		_set_prompt(_drop_hint(zone))


func _drop_hint(zone: String) -> String:
	if zone == "self" or zone == "fuel":
		return tr("손패 위 아무 곳에 놓으면 사용") + "\n" + tr("손패로 되돌리기·우클릭·Esc = 취소")
	return tr("%s 위에 놓으면 사용") % tr({"enemy": "적", "all": "적이 있는 전장"}[zone]) + "\n" + tr("다른 곳·우클릭·Esc = 취소")


func _end_drag(p: Vector2) -> void:
	_update_drag(p)
	var d := _drag.duplicate()
	var card: Card = d.card
	_drag = {}
	_hide_gesture_visuals()
	var ok := bool(d.valid) and _state == UI.PLAYER and not (gate != null and gate.is_open()) and battle.hand.cards.has(card)
	if not ok:
		gesture_log.append({"frame": Engine.get_process_frames(), "kind": "drag_cancel", "reason": "invalid_drop", "card": card.card_name})
		_sfx("cancel", 1.0, -4.0)
		_return_ghost(card)
		_refresh_card_states()
		_refresh_targeting()
		return
	gesture_log.append({"frame": Engine.get_process_frames(), "kind": "drag_drop", "card": card.card_name, "zone": d.zone, "target": int(d.target)})
	if String(d.zone) == "fuel":
		_return_ghost(card)
		_select_card(card)
		return
	if String(d.zone) == "enemy":
		_target = int(d.target)
	_state = UI.BUSY
	_refresh_card_states()
	await _suck_ghost(_drop_point(d))
	if not is_inside_tree():
		return
	_state = UI.PLAYER
	var played := await play_card(card, int(d.target) if String(d.zone) == "enemy" else -1, {"sucked": true})
	if not played and _card_views.has(card):
		(_card_views[card] as Control).visible = true


# 놓은 대상의 화면 자리
func _drop_point(d: Dictionary) -> Vector2:
	match String(d.zone):
		"enemy":
			return _to_ui(_enemy_torso(int(d.target)))
		"all":
			return _enemies_rect().get_center()
	return _player_rect().get_center()


# 블랙홀: 카드가 돌며 작아져 대상 가운데로 빨려 들어가고, 그 자리에서 빛 알갱이가 모인다
func _suck_ghost(at: Vector2) -> void:
	var g := _drag_ghost
	_drag_ghost = null
	if g == null:
		return
	_sfx("swing", 1.5, -6.0)
	if _reduce_motion:
		g.queue_free()
		return
	var t := g.create_tween().set_parallel()
	t.tween_property(g, "position", at - REST / 2.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(g, "scale", Vector2.ONE * 0.04, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(g, "rotation", g.rotation + TAU, 0.2)
	t.tween_property(g, "modulate", Color(2.2, 2.0, 1.6, 0.0), 0.2).set_ease(Tween.EASE_IN)
	var sp := P2Sparks.new()
	sp.gather(at, 110.0, 18, [C_GOLD, Color.WHITE, C_IVORY], 0.22)
	_uip.add_child(sp)
	await t.finished
	g.queue_free()


# 놓을 수 없는 곳: 카드가 손패 자리로 돌아간다
func _return_ghost(card: Card) -> void:
	var g := _drag_ghost
	_drag_ghost = null
	if g == null:
		return
	var view: Control = _card_views.get(card)
	_place_hand()
	if view == null or _reduce_motion:
		g.queue_free()
		if view != null:
			view.visible = true
		return
	var home: Vector2 = _hand_root.position + (view.get_meta("home") as Vector2)
	var t := g.create_tween().set_parallel()
	t.tween_property(g, "position", home, 0.14).set_ease(Tween.EASE_OUT)
	t.tween_property(g, "scale", Vector2.ONE, 0.14)
	t.tween_property(g, "rotation", deg_to_rad(float(view.get_meta("rot"))), 0.14)
	var vref: WeakRef = weakref(view)
	t.chain().tween_callback(func() -> void:
		g.queue_free()
		var vv: Control = vref.get_ref()
		if vv != null and _card_views.get(card) == vv:
			vv.visible = true)


# 빨려 들어간 카드는 손패에서 바로 뺀다(날아가는 그림 없음)
func _drop_view(card: Card) -> void:
	if not _card_views.has(card):
		return
	(_card_views[card] as Control).queue_free()
	_card_views.erase(card)
	_relayout_hand()


func _mouse_through(n: Node) -> void:
	if n is Control:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in n.get_children():
		_mouse_through(c)


# 주인공 몸에 딱 맞춘 화면 사각형(나에게 쓰는 카드의 놓는 자리·표시)
func _player_rect() -> Rect2:
	var span := _body_span(_player)
	var top := _player_head_y()
	var a := _to_ui(Vector2(span.x, top))
	var b := _to_ui(Vector2(span.y, FEET_Y))
	return Rect2(a, b - a)


# 살아 있는 적 몸들을 감싸는 화면 사각형
func _enemies_rect() -> Rect2:
	var r := Rect2()
	var first := true
	for i in range(_enemy_sprites.size()):
		if not bool(_shown.enemies[i].alive):
			continue
		var sp := _enemy_sprites[i]
		var span := _body_span(sp)
		var h := float(sp.get_meta("torso_h", 128.0))
		var e := Rect2(_to_ui(Vector2(span.x, FEET_Y - h)), Vector2(span.y - span.x, h))
		r = e if first else r.merge(e)
		first = false
	return r if not first else ALL_ZONE


func _fit_zone(z: Panel, r: Rect2) -> void:
	z.position = r.position
	z.size = r.size
	for c in z.get_children():
		if c is Label:
			(c as Label).size.x = r.size.x
			(c as Label).position = Vector2(0, r.size.y - 28.0)


func _hide_gesture_visuals() -> void:
	if _aim_fx != null:
		_aim_fx.visible = false
		_zone_self.visible = false
		_zone_all.visible = false
	_show_drop_line(false)


# 나에게 쓰는 카드를 끄는 동안: 손패 위 경계에 금빛 줄. 이 줄 위로 올리면 쓸 수 있고, 올라가면 줄이 밝아진다
func _show_drop_line(on: bool) -> void:
	if _drop_line == null:
		if not on:
			return
		_drop_line = Control.new()
		_drop_line.position = Vector2(0, HAND_HIT_TOP - 30.0)
		_drop_line.size = Vector2(1280, 40)
		_drop_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_drop_line.draw.connect(func() -> void:
			var lit := not _drag.is_empty() and bool(_drag.get("valid", false))
			var a := 0.95 if lit else 0.5
			var x := 60.0
			while x < 1220.0:
				_drop_line.draw_line(Vector2(x, 30), Vector2(minf(x + 18.0, 1220.0), 30), Color(C_GOLD, a), 3.0 if lit else 2.0)
				x += 28.0
			var t := tr("이 줄 위 아무 곳에 놓으면 사용")
			var f := P2Ui.pixel_font(P2Ui.T_BODY)
			var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, P2Ui.T_BODY).x
			_drop_line.draw_string_outline(f, Vector2(640.0 - w / 2.0, 22), t, HORIZONTAL_ALIGNMENT_LEFT, -1, P2Ui.T_BODY, 4, Color(0, 0, 0, a))
			_drop_line.draw_string(f, Vector2(640.0 - w / 2.0, 22), t, HORIZONTAL_ALIGNMENT_LEFT, -1, P2Ui.T_BODY, Color(C_GOLD, a)))
		_ui.add_child(_drop_line)
	_drop_line.visible = on
	_drop_line.queue_redraw()


# 끌기·누르기 상태를 지운다 (실제 상태는 바뀐 적이 없으므로 되돌릴 것이 없다). 저장 창·포커스 이탈·턴 종료·물약에서도 부른다
func _cancel_gesture(reason: String) -> void:
	if _drag.is_empty() and _press.is_empty():
		return
	var had_drag := not _drag.is_empty()
	var dragged: Card = _drag.get("card")
	_press = {}
	_drag = {}
	_hide_gesture_visuals()
	if dragged != null:
		_return_ghost(dragged)
	gesture_log.append({"frame": Engine.get_process_frames(), "kind": "gesture_cancel", "reason": reason, "drag": had_drag})
	if had_drag and _hand_hit != null:
		_sfx("cancel", 1.0, -6.0)
		_refresh_card_states()
		_refresh_targeting()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_WM_MOUSE_EXIT:
		_cancel_gesture("focus_lost")


# 곡선 화살표: 카드에서 대상까지 위로 휜 곡선을 따라 화살 마디가 흐른다
func _draw_arrow(from: Vector2, to: Vector2, color: Color) -> void:
	_aim_fx.set_arrow(from, to, color)


func _on_enemy_hover(index: int, inside: bool) -> void:
	if not _drag.is_empty():
		return
	if inside:
		_target = index
	elif _target == index:
		_target = -1
	_refresh_targeting()


func _on_enemy_input(event: InputEvent, index: int) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	if event.button_index == MOUSE_BUTTON_RIGHT:
		_cancel_selection()
		return
	if event.button_index != MOUSE_BUTTON_LEFT or _selected == null:
		return
	if P2Catalog.is_targeted(_selected):
		_target = index
		_confirm_selected()
	elif _selected.effect == Card.EffectType.DAMAGE:
		_confirm_selected()


func _input(event: InputEvent) -> void:
	if not _key_capture_on or not (event is InputEventKey) or not event.pressed or (event as InputEventKey).echo:
		return
	get_viewport().set_input_as_handled()
	var k := P2NoteChart.key_id(event as InputEventKey)
	var kb := _key_capture_labels[0] as Button
	if k == KEY_ESCAPE:
		_key_capture_on = false
		kb.text = tr("키: ") + tr(P2Ui.keys_label(String(P2Ui.load_rhythm().keys)))
		return
	if (k >= KEY_F1 and k <= KEY_F12) or k in [KEY_TAB, KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META, KEY_CAPSLOCK] or _key_capture.has(k):
		return
	_key_capture.append(k)
	if _key_capture.size() < 2:
		kb.text = tr("두 번째 키를 누르세요")
		return
	var keys := "custom:%d,%d" % [int(_key_capture[0]), int(_key_capture[1])]
	P2Ui.save_rhythm({"keys": keys, "keys_custom": keys})
	P2NoteChart.hit_keys = P2Ui.hit_keys_of(keys)
	_key_capture_on = false
	kb.text = tr("키: ") + tr(P2Ui.keys_label(keys))


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or (gate != null and gate.is_open()):
		return
	if _result_open and event is InputEventKey and event.pressed and not event.echo:
		_result_open = false
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if _menu != null or _info != null:
			if event.keycode == KEY_ESCAPE or (event.keycode == KEY_TAB and _info != null):
				_close_popups()
			get_viewport().set_input_as_handled()
			return
		if _overlay.get_child_count() > 0:
			return
		if _show != null and _state == UI.PLAYER and _show.key_input(event):
			get_viewport().set_input_as_handled()
			return
		match event.keycode:
			KEY_F3:
				_debug.visible = not _debug.visible
				_update_debug()
			KEY_TAB:
				_toggle_info()
			KEY_ESCAPE:
				if not _drag.is_empty() or not _press.is_empty():
					_cancel_gesture("esc")
				elif _state == UI.MULLIGAN or _state == UI.FUEL or _selected != null:
					_cancel_selection()
				else:
					_toggle_menu()
			KEY_E:
				_on_end_turn_pressed()
			KEY_Q:
				_use_potion("hp_potion")
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				if _drag.is_empty():
					_confirm_selected()
			KEY_LEFT, KEY_RIGHT:
				if _drag.is_empty():
					_cycle_target(-1 if event.keycode == KEY_LEFT else 1)
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7:
				var i: int = event.keycode - KEY_1
				if battle != null and i < battle.hand.cards.size() and _drag.is_empty():
					if _state == UI.MULLIGAN:
						_toggle_mull_pick(battle.hand.cards[i])
					elif _state == UI.FUEL:
						_pick_fuel(battle.hand.cards[i])
					else:
						_select_card(battle.hand.cards[i])
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if not _drag.is_empty() or not _press.is_empty():
			_cancel_gesture("right_click")
		else:
			_cancel_selection()


# ── 메뉴 · 전투 정보 (전투 중에만) ─────────────────────────────────────────────
# 메뉴: 흔들림 설정 · 전투 정보 · 후퇴(기존 확인 창) · 종료(저장 대기 중엔 막힘). 열리면 끌기는 취소되고 뒤의 입력은 막힌다

func _toggle_menu() -> void:
	if _menu != null:
		_close_popups()
		return
	_close_popups()
	_cancel_gesture("menu")
	var p := _stone_panel(_overlay, Vector2(MENU_RECT.end.x - 360, MENU_RECT.end.y + 8), Vector2(360, 270.0 + (246.0 if battle.parry_mode else 0.0)))
	_menu = p.get_parent().get_parent()
	_menu.gui_input.connect(_popup_outside_click)
	var t := _label("메뉴", 24, C_GOLD)
	t.position = Vector2(20, 12)
	p.add_child(t)
	var y := 50.0
	var info := _button("전투 정보 (Tab)", Vector2(20, y), Vector2(304, 40), F)
	info.pressed.connect(func() -> void:
		_close_popups()
		_toggle_info())
	p.add_child(info)
	y += 48
	_retreat_button = _button("그만두기" if _practice() else "후퇴 (원정 포기)", Vector2(20, y), Vector2(304, 40), F)
	_retreat_button.disabled = _state != UI.PLAYER
	_retreat_button.pressed.connect(func() -> void:
		_close_popups()
		_ask_retreat())
	p.add_child(_retreat_button)
	y += 48
	var quit := _button("종료 (진행은 자동 저장됨)", Vector2(20, y), Vector2(304, 40), F)
	quit.pressed.connect(func() -> void:
		if model.has_pending():
			return
		get_tree().quit())
	p.add_child(quit)
	y += 48
	if battle.parry_mode:
		y = _menu_rhythm(p, y + 6.0)
	var close := _button("닫기 (Esc)", Vector2(20, y), Vector2(304, 40), F)
	close.pressed.connect(_close_popups)
	p.add_child(close)
	_skin_children(p)
	gesture_log.append({"frame": Engine.get_process_frames(), "kind": "menu_open"})


# 전투 정보: 캐릭터 / 특성·유물 / 더미 / 이 전투 — 짧은 제목 아래 묶고 한 칸에서 스크롤 (항상 떠 있는 문단 대신)
func _toggle_info() -> void:
	if _info != null:
		_close_popups()
		return
	_close_popups()
	_cancel_gesture("info")
	var p := _stone_panel(_overlay, Vector2(150, 96), Vector2(980, 520))
	_info = p.get_parent().get_parent()
	_info.gui_input.connect(_popup_outside_click)
	var t := _label(tr("전투 정보") + " — " + _enc_label(), 24, C_GOLD)
	t.position = Vector2(20, 12)
	p.add_child(t)
	var sc := ScrollContainer.new()
	sc.position = Vector2(20, 50)
	sc.size = Vector2(p.size.x - 40, p.size.y - 114)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(sc)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.custom_minimum_size.x = sc.size.x - 24
	sc.add_child(col)
	for group in _info_groups():
		var h := _label(String(group[0]), 24, C_GOLD)
		col.add_child(h)
		var body := _label("\n".join(PackedStringArray(group[1])), F, C_TEXT, sc.size.x - 40)
		col.add_child(body)
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0, 8)
		col.add_child(gap)
	var close := _button(tr("닫기 (Tab · Esc)"), Vector2(p.size.x - 240, p.size.y - 56), Vector2(220, 42), F)
	close.pressed.connect(_close_popups)
	p.add_child(close)
	_skin_children(p)
	gesture_log.append({"frame": Engine.get_process_frames(), "kind": "info_open"})


func _info_groups() -> Array:
	var me: Array[String] = []
	var cname := String(P2Catalog.CLASSES.get(battle.class_id, {}).get("name", ""))
	me.append("%s · %s" % [cname, String(P2Catalog.CLASSES.get(battle.class_id, {}).get("passive", ""))])
	if battle.crit_mode != "off":
		me.append(tr("치명타 확률 %d%% · 피해 ×%s") % [battle.crit_chance(), str(snappedf(battle.crit_mult(), 0.01))])
	if battle.class_id == "rune_caster":
		me.append(tr("최대 마나 %d") % battle.max_mana)
	var build_lines: Array[String] = []
	for tr_id in battle.traits:
		build_lines.append("%s %s%s — %s" % [tr("특성"), P2Catalog.TRAITS[tr_id].name, tr(" (이번 턴 사용함)") if battle.trait_used.has(tr_id) else "", P2Catalog.TRAITS[tr_id].text])
	for id in battle.relics:
		build_lines.append("%s %s — %s" % [tr("유물"), P2Catalog.RELICS[id].name, P2Catalog.RELICS[id].text])
	if build_lines.is_empty():
		build_lines.append(tr("특성·유물 없음"))
	var ex := (battle.deck as P4Deck).exhausted
	var draw_names: Array = battle.deck.draw_pile.map(func(c): return c.card_name)
	draw_names.sort()
	var piles: Array[String] = [
		tr("뽑을 더미 %d장 (순서 숨김): %s") % [draw_names.size(), ", ".join(PackedStringArray(draw_names)) if not draw_names.is_empty() else tr("없음")],
		tr("버린 더미 %d장: %s") % [battle.deck.discard_pile.size(), ", ".join(PackedStringArray(battle.deck.discard_pile.map(func(c): return c.card_name))) if not battle.deck.discard_pile.is_empty() else tr("없음")],
		tr("소진 %d장 (이번 전투에서 다시 나오지 않음): %s") % [ex.size(), ", ".join(PackedStringArray(ex.map(func(c): return c.card_name))) if not ex.is_empty() else tr("없음")],
		tr("손패 %d / %d · 덱 %d장") % [battle.hand.cards.size(), P2Battle.HAND_MAX, int(_run_info.deck)]]
	var now: Array[String] = []
	for l in _status_lines():
		if l.begins_with("주술") or l.begins_with("독") or l.begins_with("막고 치기") or l.begins_with("비축 인장"):
			now.append(l)
	now.append(_enc_hint())
	return [[tr("캐릭터"), me], [tr("특성 · 유물"), build_lines], [tr("더미"), piles], [tr("지금 · 이 전투"), now]]


func _popup_outside_click(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		_close_popups()


func _close_popups() -> void:
	for n in [_menu, _info]:
		if n != null and is_instance_valid(n):
			(n as Node).queue_free()
	_menu = null
	_info = null
	_retreat_button = null


func _select_card(card: Card) -> void:
	if _state != UI.PLAYER or battle == null or not battle.hand.cards.has(card):
		return
	if not battle.can_play_card(card):
		_sfx("deny")
		if battle.is_noble_sealed(card):
			_guide.text = tr("봉인된 카드: 공격 2장으로 해제 · 다음 내 턴 자동 해제 (연료화로 함께 소진할 수는 있음)")
		elif P2Catalog.is_fuel(card):
			_guide.text = "연료화는 함께 소진할 다른 카드가 손에 있어야 합니다."
		else:
			_guide.text = "마나가 부족합니다 (필요 %d · 남은 마나 %d)" % [card.mana_cost, int(GameState.get_flag("player_mana"))]
		_notice(_guide.text)
		_deny_shake(card)
		return
	_selected = card
	_sfx("select")
	if P2Catalog.is_fuel(card):
		_state = UI.FUEL
		_fuel_pick = ""
		_display_log.append({"frame": Engine.get_process_frames(), "kind": "fuel_select"})
	if P2Catalog.is_targeted(card):
		if _target < 0 or not battle.get_monster(_target).is_alive():
			_target = battle.alive_monsters()[0].index
	_refresh_card_states()
	_refresh_targeting()


func _cancel_selection() -> void:
	if _state == UI.MULLIGAN:
		_toggle_mulligan()
		return
	if _state == UI.FUEL:
		_state = UI.PLAYER
		_fuel_pick = ""
		_display_log.append({"frame": Engine.get_process_frames(), "kind": "fuel_cancel"})
	if _selected == null:
		return
	_selected = null
	_sfx("cancel", 1.0, -4.0)
	_refresh_card_states()
	_refresh_targeting()


# 연료화 둘째 선택: 함께 소진할 손패 카드. 연료화 자신을 다시 누르면 취소. 확정 전에는 아무것도 바뀌지 않는다
func _pick_fuel(card: Card) -> void:
	if _state != UI.FUEL:
		return
	if card == _selected:
		_cancel_selection()
		return
	_fuel_pick = P2Catalog.uid_of(card)
	_sfx("select", 0.9)
	_display_log.append({"frame": Engine.get_process_frames(), "kind": "fuel_pick", "uid": _fuel_pick})
	_refresh_card_states()
	_refresh_targeting()


func _cycle_target(direction: int) -> void:
	if _state != UI.PLAYER or _selected == null or not P2Catalog.is_targeted(_selected):
		return
	var alive := battle.alive_monsters()
	var i := 0
	for k in range(alive.size()):
		if alive[k].index == _target:
			i = k
	_target = alive[(i + direction + alive.size()) % alive.size()].index
	_sfx("select", 1.2, -6.0)
	_refresh_targeting()


func _refresh_targeting() -> void:
	_clear_preview()
	if battle == null:
		return
	if _aim_fx != null and _drag.is_empty():
		_aim_fx.visible = false
	if _state == UI.FUEL:
		for p in _enemy_panels:
			(p.ring as Panel).visible = false
		if _fuel_pick == "":
			_guide.text = "연료화: 함께 소진할 카드를 고르세요 (클릭 또는 1~7). 취소: Esc · 우클릭 · 연료화 다시 누르기"
			_set_prompt(tr("연료화: 함께 소진할 카드 고르기") + "\n" + tr("클릭·1~7 · 취소 Esc"))
		else:
			var other := _hand_card(_fuel_pick)
			_set_prompt(tr("두 장 모두 이번 전투에서 소진: %s") % (other.card_name if other != null else "") + "\n" + tr("Enter 확정 · Esc 취소"))
			_show_preview(_selected, -1, {"fuel_uid": _fuel_pick})
		return
	if _state == UI.MULLIGAN:
		_set_prompt(tr("바꿀 카드 최대 2장 고르기") + "\n" + tr("[교체 확정] · 다시 누르면 취소"))
		return
	for i in range(_enemy_panels.size()):
		var targeted := _selected != null and (not P2Catalog.is_targeted(_selected) and _selected.effect == Card.EffectType.DAMAGE or P2Catalog.is_targeted(_selected) and i == _target)
		(_enemy_panels[i].ring as Panel).visible = targeted and bool(_shown.enemies[i].alive) and _state == UI.PLAYER
	if _state != UI.PLAYER:
		_set_prompt("")
		return
	if _selected == null:
		_set_guide_default()
		return
	if P2Catalog.is_targeted(_selected):
		_set_prompt(tr("적을 눌러 사용 · ←/→ 대상") + "\n" + tr("Enter 사용 · Esc 취소"))
		if _target >= 0 and _drag.is_empty() and _card_views.has(_selected):
			_draw_arrow(_big_bottom(_card_views[_selected]) + Vector2(0, -BIG.y + 12.0), _to_ui(_enemy_torso(_target)), C_GOLD)
	else:
		_set_prompt(tr("다시 누르거나 Enter로 사용") + "\n" + tr("Esc 취소"))
	_show_preview(_selected, _target if P2Catalog.is_targeted(_selected) else -1)


func _set_guide_default() -> void:
	var any := false
	for c in battle.hand.cards:
		any = any or battle.can_play_card(c)
	if not any:
		_guide.text = "쓸 수 있는 카드가 없습니다 — [턴 종료]"
	elif battle.can_mulligan():
		_guide.text = "선택 II: 카드를 내기 전에 첫 손패를 최대 2장 바꿀 수 있습니다."
	else:
		_guide.text = _enc_hint()
	_set_prompt("")


# 손패 위 짧은 안내: 입력이 필요한 상태(연료화·교체·고른 카드·끌기)에서만. 알림은 잠깐 보였다가 안내로 돌아간다
func _set_prompt(text: String) -> void:
	_prompt_text = text
	if Time.get_ticks_msec() >= _notice_until:
		_show_prompt_text(text, false)


func _notice(text: String, secs := 1.8) -> void:
	_notice_until = Time.get_ticks_msec() + int(secs * 1000.0)
	_show_prompt_text(text, true)
	var until := _notice_until
	await get_tree().create_timer(secs).timeout
	if is_instance_valid(self) and until == _notice_until:
		_notice_until = 0
		_show_prompt_text(_prompt_text, false)


# 짧은 도움말 칸: 주인공과 적 사이 위쪽 빈 무대에 두 줄 안팎. 알림(경고·첫 전투)은 × 로 닫을 수 있고,
# 입력이 필요한 상태 안내(연료화·교체·고른 카드·끌기)는 그 상태가 끝나면 사라진다
func _show_prompt_text(text: String, warn: bool) -> void:
	if _prompt_box == null:
		return
	_prompt_label.text = text
	_prompt_label.add_theme_color_override("font_color", P2Ui.C_WARN if warn else C_INK)
	_prompt_box.visible = text != ""
	_prompt_close.visible = warn and text != ""
	if text == "":
		return
	_prompt_label.size = Vector2(HINT_RECT.size.x - 56, 0)
	var need := maxf(24.0, _prompt_label.get_minimum_size().y)
	_prompt_box.size = Vector2(HINT_RECT.size.x, need + 18.0)
	_prompt_label.size = Vector2(HINT_RECT.size.x - 56, need)


# ── 미리보기 (실제 규칙 경로를 복제본에 돌린 결과) ──────────────────────────────

func _show_preview(card: Card, target: int, play_extra := {}) -> void:
	if P2Catalog.is_fuel(card) and String(play_extra.get("fuel_uid", "")) == "":
		_guide.text = "연료화: 낼 때 함께 소진할 카드를 고릅니다 → 마나 +2 (최대 %d)" % battle.max_mana
		_set_pred(_player_pred, _player_pred.get_meta("label"), "함께 소진할 카드 1장을 고르면 마나 +%d (최대 %d)" % [P2Catalog.FUEL_MANA, battle.max_mana], 300.0)
		return
	var p := battle.preview_ex(card, target, play_extra)
	var parts: Array[String] = []
	for ev in p.events:
		match String(ev.kind):
			"hit":
				var who: String = battle.get_monster(ev.index).display_name
				var s := "%s %d" % [who, ev.damage]
				var extra: Array[String] = []
				if int(ev.get("reprisal", 0)) > 0:
					extra.append("응징 +%d" % ev.reprisal)
				if ev.consumed > 0:
					extra.append("표식 %d×3" % ev.consumed)
				if int(ev.get("shield_block", 0)) > 0:
					extra.append("방패 −%d" % int(ev.shield_block))
				if bool(ev.get("pierce", false)):
					extra.append("갑옷 무시")
				elif ev.armor > 0:
					extra.append("갑옷 −%d" % ev.armor)
				if not extra.is_empty():
					s += " (%s)" % ", ".join(extra)
				if ev.mark_added:
					s += " · 표식 %d" % ev.marks
				if ev.dead:
					s += " · 처치"
				parts.append(s)
			"spend_block":
				parts.append("방어 %d 사용" % ev.amount)
			"guard":
				parts.append("%s방어 +%d → %d%s" % ["마나 장막 " if bool(ev.get("veil", false)) else "", ev.amount, ev.block, " · 반격 %d 준비" % int(ev.counter_value) if ev.counter_added else ""])
			"exhaust":
				parts.append("소진: " + ", ".join(PackedStringArray(ev.names)))
			"mana_refund":
				parts.append("마나 +%d (%s)" % [int(ev.amount), _source_name(String(ev.source))])
			"x_paid":
				parts.append("X = %d (마나 전부)" % int(ev.x))
			"transfer":
				parts.append("전이 → %s %d" % [battle.get_monster(ev.index).display_name, ev.damage])
			"echo_string":
				parts.append("메아리 줄 → %s %d" % [battle.get_monster(ev.index).display_name, ev.damage])
			"furnace":
				parts.append("소각로 → %s %d" % [battle.get_monster(ev.index).display_name, ev.damage])
			"prep":
				parts.append("준비 %d → %d" % [int(ev.before), int(ev.after)])
			"combo":
				parts.append("연격 %d → %d" % [int(ev.before), int(ev.after)])
			"arc":
				parts.append("방전 고리 → %s %d" % [battle.get_monster(ev.index).display_name, ev.damage])
			"cleave":
				parts.append("가르기 → %s %d" % [battle.get_monster(ev.index).display_name, ev.damage])
			"inscribe":
				parts.append("이중 각인 → %s 표식 %d" % [battle.get_monster(ev.index).display_name, ev.marks])
			"suppress":
				parts.append("억제 −%d → 다음 행동 %s" % [ev.amount, P2Catalog.move_text(ev.intent)])
			"lens":
				parts.append("사냥꾼 렌즈 → %s %d" % [battle.get_monster(ev.index).display_name, ev.damage])
			"echo":
				parts.append("잔향 → %s %d%s" % [battle.get_monster(ev.index).display_name, ev.damage, " · 표식" if ev.mark_added else ""])
			"absorb":
				parts.append("흡수 방어 +%d" % ev.amount)
			"blade":
				parts.append("철편 부적 방어 +%d" % ev.amount)
			"ember_jar":
				parts.append("잿불 단지 방어 +%d" % ev.amount)
			"chalice":
				parts.append("피의 성배 방어 +%d" % ev.amount)
			"iron_tempo":
				parts.append("강철 박자 방어 +%d" % ev.amount)
			"echo_edge":
				parts.append("메아리 칼끝 → %s %d" % [battle.get_monster(ev.index).display_name, ev.damage])
			"boss_weakened":
				parts.append("강타 약화 → %d" % ev.hit)
			"unwind":
				parts.append(tr("힘 풀림 · 강타 %d") % int(ev.hit))
			"resonance":
				parts.append(tr("공명 %d · 보스 공격 %d") % [int(ev.level), battle.scaled(int(ev.lance))])
			"noble_unseal":
				if String(ev.why) == "resonance":
					parts.append(tr("봉인 해제"))
			"first_bonus":
				parts.append("첫 타격 +%d" % int(ev.amount))
			"mark_chain":
				parts.append("표식 연쇄 → %s %d" % [battle.get_monster(ev.index).display_name, ev.damage])
			"burn_endure":
				parts.append("태워서 버티기 방어 +%d · 1장" % int(ev.amount))
			"heal":
				parts.append("체력 +%d" % int(ev.amount))
	if int(p.draw) > 0:
		parts.append("%d장 뽑기" % p.draw)
	elif P2Catalog.is_draw(card):
		parts.append("뽑을 자리/카드 없음")
	if int(p.satchel) > 0:
		parts.append("예비 주머니 1장")
	if P2Catalog.is_attack(card) and bool(p.forced):
		parts.push_front("확정 치명타 ×%s" % str(snappedf(battle.crit_mult(), 0.01)))
	var crit_branch: Dictionary = p.get("crit", {})
	var crit_lost := {}
	if not crit_branch.is_empty():
		var normal_sum := 0
		var crit_sum := 0
		for i in range(p.monsters.size()):
			normal_sum += int(p.monsters[i].hp_before) - int(p.monsters[i].hp)
			var cl := int(crit_branch.monsters[i].hp_before) - int(crit_branch.monsters[i].hp)
			crit_sum += cl
			crit_lost[i] = cl
		var crit_weak := (crit_branch.events as Array).any(func(e): return String(e.kind) == "boss_weakened") and not (p.events as Array).any(func(e): return String(e.kind) == "boss_weakened")
		parts.append("치명 %d%%: 피해 %d → %d%s%s" % [int(p.crit_chance), normal_sum, crit_sum,
			" · 마나 +1" if int(crit_branch.mana_after) > int(p.mana_after) else "", " · 치명이면 강타 약화" if crit_weak else ""])
	if P2Catalog.is_fuel(card):
		parts.append("마나 %d → %d" % [int(GameState.get_flag("player_mana")), int(p.mana_after)])
	_guide.text = "%s:  %s" % [card.card_name, "  ·  ".join(parts)]
	var playable := battle.can_play_card(card)
	if not playable:
		_guide.text = "마나가 부족합니다 (필요 %d)" % card.mana_cost
	# 대상마다: 위 줄 = 평범한 결과(예상 피해 · 처치), 아래 줄 = 치명 확률과 그때 결과 · 방패 · 갑옷 · 표식 · 억제 · 강타 약화
	var extra := {}
	for ev in p.events:
		if not ev.has("index"):
			continue
		var k := int(ev.index)
		if not extra.has(k):
			extra[k] = []
		match String(ev.kind):
			"hit":
				if int(ev.get("shield_block", 0)) > 0:
					(extra[k] as Array).append(tr("방패 −%d") % int(ev.shield_block))
				if bool(ev.get("pierce", false)):
					(extra[k] as Array).append(tr("갑옷 무시"))
				elif int(ev.get("armor", 0)) > 0:
					(extra[k] as Array).append(tr("갑옷 −%d") % int(ev.armor))
				if int(ev.get("consumed", 0)) > 0:
					(extra[k] as Array).append(tr("표식 %d 터짐") % int(ev.consumed))
			"boss_weakened":
				(extra[k] as Array).append(tr("강타 약화 → %d") % int(ev.hit))
	# 원소 반응 미리보기: 이 카드를 내면 그 적에게 날 반응을 맨 앞에(이름 + 반응 피해)
	var reacts := {}
	for ev in p.events:
		if String(ev.kind) == "react" and String(ev.name) != "spread":
			reacts[int(ev.index)] = tr(String(ev.label)).trim_suffix("!") + (" +%d" % int(ev.amount) if int(ev.amount) > 0 else "")
	var crit_weak := not crit_branch.is_empty() and (crit_branch.events as Array).any(func(e): return String(e.kind) == "boss_weakened") and not (p.events as Array).any(func(e): return String(e.kind) == "boss_weakened")
	var forced := bool(p.forced) and P2Catalog.is_attack(card)
	for i in range(p.monsters.size()):
		if i >= _enemy_panels.size():
			continue
		var m: Dictionary = p.monsters[i]
		var panel: Dictionary = _enemy_panels[i]
		var lost: int = int(m.hp_before) - int(m.hp)
		var bar: ProgressBar = panel.hp_bar
		var ghost: ColorRect = panel.ghost
		var main := ""
		var details: Array[String] = []
		if lost > 0 or m.dead:
			ghost.visible = lost > 0
			var w := bar.size.x / bar.max_value
			ghost.position.x = bar.position.x + w * m.hp
			ghost.size.x = w * lost
			if m.dead:
				main = (tr("치명 처치 (%d)") if forced else tr("처치 (피해 %d)")) % lost
			else:
				main = (tr("치명 피해 %d") if forced else tr("예상 피해 %d")) % lost
			if forced:
				details.append(tr("확정 치명"))
			(panel.strike as ColorRect).visible = m.dead
		if crit_lost.has(i) and int(crit_lost[i]) > lost:
			details.append(tr("치명 %d%%: %d") % [int(p.crit_chance), int(crit_lost[i])])
		if extra.has(i):
			for t in extra[i]:
				details.append(String(t))
		if int(m.suppression) > int(_shown.enemies[i].get("supp", 0)) and not m.dead:
			details.append(tr("억제 −%d") % int(m.suppression))
		if crit_weak and crit_lost.has(i) and int(crit_lost[i]) > lost:
			details.append(tr("치명: 강타 약화"))
		var nbp: Dictionary = P2Catalog.ENEMIES[battle.roles[i]].get("noble", {})
		if not nbp.is_empty() and not m.dead:
			var r0 := int(p.get("noble_res_before", 0))
			var r1 := int(p.get("noble_res", r0))
			var nparts: Array[String] = []
			if r1 != r0:
				nparts.append(tr("보스 공격 %d → %d") % [battle.scaled(int(nbp.lance[r0])), battle.scaled(int(nbp.lance[r1]))])
			if bool(p.get("noble_unseal", false)):
				nparts.append(tr("봉인 해제"))
			if not nparts.is_empty():
				details.push_front(" ".join(PackedStringArray(nparts)))
			if not crit_branch.is_empty() and int(crit_branch.get("noble_res", r1)) > r1:
				details.append(tr("치명 %d%%: 보스 공격 → %d%s") % [int(p.crit_chance), battle.scaled(int(nbp.lance[int(crit_branch.noble_res)])), tr(" · 봉인 해제") if bool(crit_branch.get("noble_unseal", false)) and not bool(p.get("noble_unseal", false)) else ""])
		if not battle.unwind_info(i).is_empty() and battle.unwind_window_open(i) and not m.dead:
			var ub := int(m.get("unwind_before", 0))
			var ua := int(m.get("unwind", 0))
			var uneed := int(battle.unwind_info(i).need)
			if ua != ub:
				# 이 카드로 3번이 되면 같은 줄에 바뀐 강타 값 (두 줄 예상 칸에서 잘리지 않게)
				details.push_front((tr("맞힘 %d → %d: 강타 %d") % [ub, ua, int(battle.unwind_info(i).weak)]) if ua >= uneed and ub < uneed else (tr("맞힘 %d → %d") % [ub, ua]))
			if not crit_branch.is_empty():
				var uc := int((crit_branch.monsters[i] as Dictionary).get("unwind", ua))
				if uc > ua:
					details.append(tr("치명 %d%%: 맞힘 %d → %d") % [int(p.crit_chance), ub, uc])
		if int(m.marks) != int(m.marks_before):
			_set_mark_pips(panel.marks, int(m.marks_before), int(m.marks))
			if not m.dead and int(m.marks) > int(m.marks_before) and lost <= 0:
				details.append(tr("표식 %d → %d") % [int(m.marks_before), int(m.marks)])
		if reacts.has(i):
			if main != "":
				details.push_front(main)
			main = String(reacts[i])
		if main == "" and not details.is_empty():
			main = details.pop_front()
		if main != "" and bool(_shown.enemies[i].alive):
			_set_enemy_pred(panel, main, " · ".join(PackedStringArray(details)))
	# 주인공 쪽: 방어·반격 · 뽑기 · 마나 · 준비 · 회복 · 소진 (머리 오른쪽 빈 무대)
	var mine: Array[String] = []
	if not playable:
		mine.append(tr("마나 부족: 필요 %d · 남은 %d") % [card.mana_cost, int(GameState.get_flag("player_mana"))])
	var block_after: int = p.block
	if block_after != int(_shown.block):
		mine.append(tr("방어 %d → %d") % [int(_shown.block), block_after])
	for ev in p.events:
		match String(ev.kind):
			"guard":
				if bool(ev.counter_added):
					mine.append(tr("반격 %d 준비") % int(ev.counter_value))
			"spend_block":
				mine.append(tr("방어 %d 사용") % int(ev.amount))
			"mana_refund":
				if String(ev.source) != "fuel":
					mine.append(tr("마나 +%d (%s)") % [int(ev.amount), _source_name(String(ev.source))])
			"x_paid":
				mine.append(tr("X = %d (마나 전부)") % int(ev.x))
			"prep":
				mine.append(tr("준비 %d → %d") % [int(ev.before), int(ev.after)])
			"combo":
				mine.append(tr("연격 %d → %d") % [int(ev.before), int(ev.after)])
			"heal":
				mine.append(tr("체력 +%d") % int(ev.amount))
			"exhaust":
				mine.append(tr("소진: ") + ", ".join(PackedStringArray(ev.names)))
	if int(p.draw) > 0:
		mine.append(tr("%d장 뽑기") % p.draw)
	elif P2Catalog.is_draw(card):
		mine.append(tr("뽑을 자리/카드 없음"))
	if int(p.satchel) > 0:
		mine.append(tr("예비 주머니 1장"))
	# 마나 변화는 따로 상자를 띄우지 않고 마나 구슬 숫자에 보인다 (결과는 영향받는 쪽 옆에, 마나는 구슬에)
	if playable and int(p.mana_after) != int(GameState.get_flag("player_mana")):
		# 예상 소모는 수조 옆에 따로 (실제 숫자·수위는 그대로)
		var d := int(p.mana_after) - int(GameState.get_flag("player_mana"))
		_mana_pred.text = ("%+d" % d).replace("-", "−")
		_mana_pred.add_theme_color_override("font_color", C_GOLD if d < 0 else P2Ui.C_GOOD)
		_mana_tick.visible = d < 0
		_mana_label.set_meta("pred", true)
	if not mine.is_empty():
		var txt := " · ".join(PackedStringArray(mine))
		_set_pred(_player_pred, _player_pred.get_meta("label"), txt, clampf(_text_width(txt, F) + 40.0, 140.0, 284.0))
		_project_annotations()
	_update_debug()


func _clear_preview() -> void:
	for panel in _enemy_panels:
		(panel.ghost as ColorRect).visible = false
		(panel.strike as ColorRect).visible = false
		(panel.pred as Control).visible = false
	if _player_pred != null:
		_player_pred.visible = false
	if _mana_label != null and bool(_mana_label.get_meta("pred", false)):
		_mana_label.set_meta("pred", false)
		_mana_pred.text = ""
		_mana_tick.visible = false
	if _shown.is_empty():
		return
	for i in range(_enemy_panels.size()):
		if bool(_shown.enemies[i].alive):
			_set_mark_pips(_enemy_panels[i].marks, int(_shown.enemies[i].marks), -1)
			(_enemy_panels[i].info as Label).text = _info_text(i)
	_player_badge.text = _badge_text(int(_shown.block))


func _set_pred(badge: NinePatchRect, label: Label, text: String, width: float) -> void:
	label.text = text
	label.custom_minimum_size = Vector2(width - 32.0, 0)
	label.position = Vector2(16, 5)
	label.size = Vector2(width - 32.0, 0)
	var need := maxf(22.0, label.get_minimum_size().y)
	badge.size = Vector2(width, need + 12.0)
	label.size = Vector2(width - 32.0, need)
	badge.visible = text != ""


# 적 예상 칸: 위 줄은 평범한 결과("예상 피해 5"), 아래 두 줄까지는 치명 확률·방패·갑옷·표식 같은 덧붙임.
# 모두 20px. 덧붙임은 " · " 단위로 줄을 채우고, 두 줄을 넘는 것은 칸의 도움말에 남긴다 (글자를 줄여 맞추지 않음)
func _set_enemy_pred(panel: Dictionary, main: String, detail: String) -> void:
	var badge: NinePatchRect = panel.pred
	var ml: Label = panel.preview
	var dl: Label = badge.get_meta("detail")
	var rows: Array[String] = []
	var cur := ""
	for item in detail.split(" · ", false):
		var cand := item if cur == "" else cur + " · " + item
		if cur == "" or _text_width(cand, P2Ui.T_BODY) <= PRED_TEXT_W:
			cur = cand
		else:
			rows.append(cur)
			cur = item
	if cur != "":
		rows.append(cur)
	ml.text = main
	dl.text = "\n".join(PackedStringArray(rows.slice(0, 2)))
	badge.tooltip_text = main + ("\n" + "\n".join(PackedStringArray(rows)) if not rows.is_empty() else "")
	for r in [main] + rows:
		if _text_width(String(r), P2Ui.T_BODY) > PRED_TEXT_W:
			pred_overflow.append(String(r))
	if rows.size() > 2:
		pred_overflow.append("+%d줄" % (rows.size() - 2))
	var n := mini(2, rows.size())
	dl.size.y = 24.0 + 20.0 * maxf(0, n - 1)
	badge.size.y = 32.0 if n == 0 else 30.0 + 20.0 * n
	badge.visible = main != "" or detail != ""
	if badge.visible:
		_place_pred(_enemy_panels.find(panel))


# 예상 칸 자리: 몸 왼쪽 → 몸 오른쪽 → 자기 예고 칸 위 순으로, 다른 적의 몸·예고 칸·보스 강타 창·위쪽 칸에 걸리지 않는 첫 자리.
# 셋 다 걸리면 처음 자리(몸 옆) 그대로
func _place_pred(i: int) -> void:
	if i < 0:
		return
	var p: Dictionary = _enemy_panels[i]
	var root: Control = p.root
	if not root.has_meta("compact"):
		return
	var badge: Control = p.pred
	var sz := badge.size
	var x := float(_slots()[i])
	var vis := _vis_cached(i)
	var it: Control = p.intent
	var top_y := (root.position + it.position).y
	var blocks: Array = [PLAYER_MODULE, TURN_BANNER, MENU_RECT]
	for k in range(_enemy_panels.size()):
		var q: Dictionary = _enemy_panels[k]
		if (q.charge as Control).visible:
			blocks.append((q.charge as Control).get_global_rect())
		if k == i or not (q.root as Control).visible:
			continue
		blocks.append(enemy_body_rect(k).grow(-8.0))
		blocks.append(Rect2((q.root as Control).position + (q.intent as Control).position, (q.intent as Control).size))
	var first := Vector2.INF
	for c in [Vector2(x - vis.x / 2.0 - 150.0, 197.0), Vector2(x + vis.x / 2.0 - 10.0, 197.0), Vector2(x - sz.x / 2.0, top_y - sz.y - 4.0)]:
		var at := Vector2(clampf((c as Vector2).x, 4.0, 1276.0 - sz.x), maxf(8.0, (c as Vector2).y))
		if first == Vector2.INF:
			first = at
		var r := Rect2(at, sz)
		if not blocks.any(func(b): return r.intersects(b)):
			badge.position = at - root.position
			return
	badge.position = first - root.position


func _text_width(t: String, size: int) -> float:
	return P2Ui.pixel_font(size).get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


func _source_name(source: String) -> String:
	match source:
		"fuel":
			return "연료화"
		"crit_capacitor":
			return "치명 축전기"
		"pursuit_slash":
			return "추격 베기"
		"reflux_burst":
			return "역류 파열"
		"mana_cycle":
			return "마나 순환"
		"elem_cycle":
			return "원소 순환"
		"chain_kill":
			return "연속 처치"
		"waited_shot":
			return "기다린 한 발"
		"mana_potion":
			return "마나 물약"
	return source


# ── 선택 II: 첫 손패 교체 ─────────────────────────────────────────────────────

func _toggle_mulligan() -> void:
	_cancel_gesture("mulligan")
	if _state == UI.MULLIGAN:
		_state = UI.PLAYER
		_mull_pick.clear()
		_guide.text = "교체를 취소했습니다."
		_notice(_guide.text)
	elif _state == UI.PLAYER and battle.can_mulligan():
		_selected = null
		_state = UI.MULLIGAN
		_mull_pick.clear()
		_guide.text = "바꿀 카드를 최대 2장 고르고 [교체 확정]을 누르세요. 더미에서 먼저 뽑고, 고른 카드는 더미 맨 아래로 갑니다."
	_refresh_card_states()
	_refresh_targeting()


func _toggle_mull_pick(card: Card) -> void:
	var uid := P2Catalog.uid_of(card)
	if _mull_pick.has(uid):
		_mull_pick.erase(uid)
	elif _mull_pick.size() < 2:
		_mull_pick.append(uid)
	else:
		_sfx("deny")
		return
	_sfx("select")
	_refresh_card_states()


func confirm_mulligan(uids: Array) -> bool:
	if _state != UI.MULLIGAN and _state != UI.PLAYER:
		return false
	if not battle.mulligan(uids):
		_sfx("deny")
		return false
	_state = UI.BUSY
	await _commit("mulligan")
	_state = UI.PLAYER
	_mull_pick.clear()
	_sfx("draw")
	_build_hand(true)
	_guide.text = "첫 손패를 %d장 교체했습니다." % uids.size()
	_notice(_guide.text)
	_refresh_card_states()
	return true


# 행동 하나를 저장한다. 저장이 실패하면 진행을 멈추고 저장 창(다시 저장 / 저장하지 않고 종료)을 기다린다.
# 다시 저장은 모델이 붙잡아 둔 같은 결과만 기록하므로, 여기서 규칙을 다시 돌리지 않는다.
func _commit(reason: String) -> void:
	if model.commit_battle(reason):
		return
	if not model.has_pending():
		return
	commit_holds += 1
	_display_log.append({"frame": Engine.get_process_frames(), "kind": "save_hold", "reason": reason})
	if gate != null:
		await gate.run()


# ── 실행: 카드 ──────────────────────────────────────────────────────────────

func _confirm_selected() -> void:
	if _state == UI.MULLIGAN:
		if not _mull_pick.is_empty():
			confirm_mulligan(_mull_pick.duplicate())
		return
	if _state == UI.FUEL:
		if _fuel_pick != "":
			await play_card(_selected, -1, {"fuel_uid": _fuel_pick})
		return
	if _state != UI.PLAYER or _selected == null:
		return
	var card := _selected
	var target := _target if P2Catalog.is_targeted(card) else -1
	await play_card(card, target)


# 카드 한 장: 규칙이 받아들이면 즉시 확정·저장(되돌리기 없음), 화면은 사건을 맞는 순간에 옮긴다
func play_card(card: Card, target: int, extra := {}) -> bool:
	if _state != UI.PLAYER and _state != UI.FUEL:
		return false
	_cancel_gesture("play")
	var t0 := Time.get_ticks_usec()
	_t_play = Time.get_ticks_msec()
	_t_ack = -1.0
	_t_commit = -1.0
	_t_contact = -1.0
	var home := _hand_root.position + (_card_views[card] as Control).position if _card_views.has(card) else Vector2(640, 600)
	var other := _hand_card(String(extra.get("fuel_uid", "")))
	var other_home := _hand_root.position + (_card_views[other] as Control).position if other != null and _card_views.has(other) else Vector2(640, 600)
	# 중립 확인: 카드가 살짝 눌리고 입력이 잠긴다. 카드·마나·체력·더미·난수는 아직 그대로 (성공 소리·카드 날림 없음)
	var prior_state := _state
	_state = UI.BUSY
	_action_token += 1
	var token := _action_token
	_cancel_residue()
	_ack_press(card)
	if other != null:
		_ack_press(other)
	await _await_drawn()
	_t_ack = Time.get_ticks_msec() - _t_play
	if not is_inside_tree() or token != _action_token:
		return false
	if _slash_wanted(card, target):
		var res := await _slash_input(card, target)
		if not is_inside_tree() or token != _action_token:
			return false
		if String(res.grade) == "cancel":
			_state = prior_state
			_refresh_card_states()
			_refresh_targeting()
			_sfx("cancel")
			return false
		battle.strike_grade = String(res.grade)
		battle.strike_power = float(res.get("power", 1.0))
		battle.strike_reverse = bool(res.get("reversed", false))
		battle.strike_thorns = int(res.get("thorns_eaten", 0))
		_slash_trace = res
	if _show != null and feel_on("slash") and P2Catalog.kind_of(card) in ["focus_shot", "ki_blast"]:
		var cr: Dictionary = await _show.charge_input(card, P2Catalog.kind_of(card))
		if not is_inside_tree() or token != _action_token:
			return false
		battle.charge_power = float(cr.power)
		if bool(cr.perfect):
			battle.strike_grade = "perfect"
			battle.strike_power = 1.3
	if _show != null and feel_on("slash") and P2Catalog.kind_of(card) == "barrage":
		battle.mash_hits = maxi(1, await _show.mash_input(card))
		if not is_inside_tree() or token != _action_token:
			return false
	var played := battle.play_card_ex(card, target, extra)
	battle.charge_power = 0.0
	battle.mash_hits = 0
	battle.strike_grade = ""
	battle.strike_power = 1.0
	battle.strike_reverse = false
	battle.strike_thorns = 0
	if not played:
		_slash_trace = {}
		_state = prior_state
		_refresh_card_states()
		_refresh_targeting()
		_sfx("deny")
		return false
	_selected = null
	_fuel_pick = ""
	var events := battle.events.duplicate(true)
	var tc := Time.get_ticks_msec()
	await _commit("card")
	_t_commit = Time.get_ticks_msec() - tc
	_clear_preview()
	for p in _enemy_panels:
		(p.ring as Panel).visible = false
	_sfx("play")
	if bool(extra.get("sucked", false)):
		_drop_view(card)
	else:
		_fly_card_out(card, home, false, _play_point(card, target))
	if other != null:
		_fly_card_out(other, other_home, true)
	_render_mana()
	_refresh_card_states()
	await get_tree().process_frame
	var feedback_ms := (Time.get_ticks_usec() - t0) / 1000.0
	await _animate_card(card, target, events)
	_slash_trace = {}
	_reconcile("card")
	await _camera_settled()
	if battle.battle_over:
		_record_timing(card.card_name, feedback_ms, t0)
		await _on_battle_over()
		return true
	_state = UI.PLAYER
	_render_hud()
	_record_timing(card.card_name, feedback_ms, t0)
	_refresh_card_states()
	_refresh_targeting()
	return true


# ── 손맛 시험판: 긋기 베기 ──

func _slash_wanted(card: Card, target: int) -> bool:
	if feel_on("slash") and P2Catalog.kind_of(card) == "heal_sigil":
		return true
	if not feel_on("slash") or not P2Catalog.is_attack(card):
		return false
	if P2Catalog.kind_of(card) in ["quickshot", "aimed_shot", "focus_shot", "ki_blast", "barrage"]:
		return false
	return target >= 0 or not P2Catalog.is_targeted(card)


# 문양(몸 높이 비율). 기본 카드는 순서 없는 두 점, 강한 카드는 번호 순서(지그재그·연속 V), 마법은 순서 문양(삼각형 · 별)
const GLYPHS := {
	"slash": [Vector2(-0.3, -0.27), Vector2(0.3, 0.25)],
	"bash": [Vector2(0.0, -0.34), Vector2(0.0, 0.22)],
	"pierce": [Vector2(-0.26, 0.0), Vector2(0.2, 0.0)],
	"zigzag": [Vector2(-0.3, -0.3), Vector2(0.28, -0.12), Vector2(-0.28, 0.1), Vector2(0.3, 0.3)],
	"twin": [Vector2(-0.3, -0.26), Vector2(0.0, 0.22), Vector2(0.3, -0.26)],
	"tri": [Vector2(0.0, -0.34), Vector2(0.3, 0.2), Vector2(-0.3, 0.2), Vector2(0.0, -0.34)],
	"star": [Vector2(0.0, -0.36), Vector2(0.212, 0.291), Vector2(-0.342, -0.111), Vector2(0.342, -0.111), Vector2(-0.212, 0.291), Vector2(0.0, -0.36)],
	"jab": [Vector2(-0.1, 0.02), Vector2(0.12, -0.02)],
	"w": [Vector2(-0.36, -0.24), Vector2(-0.18, 0.24), Vector2(0.0, -0.08), Vector2(0.18, 0.24), Vector2(0.36, -0.24)],
	"storm": [Vector2(-0.36, -0.3), Vector2(0.32, -0.2), Vector2(-0.32, -0.06), Vector2(0.34, 0.06), Vector2(-0.32, 0.18), Vector2(0.36, 0.3)],
	"cross": [Vector2(-0.38, -0.34), Vector2(0.38, 0.34), Vector2(0.38, -0.34), Vector2(-0.38, 0.34)],
	"chevron": [Vector2(-0.26, -0.3), Vector2(0.3, 0.0), Vector2(-0.26, 0.3)],
	"needle": [Vector2(-0.34, 0.3), Vector2(0.0, 0.0), Vector2(0.34, -0.3)],
	"diamond": [Vector2(0.0, -0.32), Vector2(0.3, 0.0), Vector2(0.0, 0.32), Vector2(-0.3, 0.0), Vector2(0.0, -0.32)],
	"spiral": [Vector2(0.000, -0.420), Vector2(0.331, -0.190), Vector2(0.296, 0.173), Vector2(-0.003, 0.305), Vector2(-0.232, 0.131), Vector2(-0.196, -0.117), Vector2(0.003, -0.190)],
	"arc": [Vector2(-0.372, 0.061), Vector2(-0.234, -0.159), Vector2(0.000, -0.240), Vector2(0.234, -0.159), Vector2(0.372, 0.061)],
	"arrow": [Vector2(-0.34, 0.30), Vector2(0.30, -0.28), Vector2(0.02, -0.30)],
	"bullseye": [Vector2(0.000, -0.320), Vector2(0.304, -0.099), Vector2(0.188, 0.259), Vector2(-0.188, 0.259), Vector2(-0.304, -0.099), Vector2(0.000, 0.000)],
	"hex": [Vector2(0.000, -0.330), Vector2(0.286, -0.165), Vector2(0.286, 0.165), Vector2(0.000, 0.330), Vector2(-0.286, 0.165), Vector2(-0.286, -0.165)],
	"flame": [Vector2(-0.18, 0.32), Vector2(-0.30, 0.02), Vector2(-0.06, -0.10), Vector2(0.0, -0.38), Vector2(0.22, -0.06), Vector2(0.16, 0.32)],
	"note": [Vector2(-0.30, 0.24), Vector2(-0.06, 0.30), Vector2(-0.02, -0.36), Vector2(0.28, -0.16)],
	"heart": [Vector2(0.0, 0.34), Vector2(-0.34, -0.04), Vector2(-0.2, -0.30), Vector2(0.0, -0.14), Vector2(0.2, -0.30), Vector2(0.34, -0.04)],
	"hammer": [Vector2(-0.34, -0.32), Vector2(0.34, -0.32), Vector2(0.0, 0.38)],
	"comet": [Vector2(-0.34, 0.28), Vector2(-0.06, 0.0), Vector2(0.1, 0.2), Vector2(0.34, -0.34)],
	"flake": [Vector2(0.0, -0.38), Vector2(0.0, 0.36), Vector2(-0.32, 0.2), Vector2(0.32, -0.2)],
	"crystal": [Vector2(0.0, -0.38), Vector2(0.28, -0.12), Vector2(0.2, 0.32), Vector2(-0.2, 0.32), Vector2(-0.28, -0.12), Vector2(0.0, -0.38)],
	"rift": [Vector2(-0.08, -0.4), Vector2(0.14, -0.18), Vector2(-0.12, 0.02), Vector2(0.12, 0.2), Vector2(-0.04, 0.4)],
	"gale": [Vector2(-0.36, 0.06), Vector2(-0.12, -0.28), Vector2(0.16, -0.08), Vector2(-0.02, 0.16), Vector2(0.36, 0.08)],
	"fang": [Vector2(-0.3, -0.3), Vector2(-0.12, 0.32), Vector2(0.06, -0.3), Vector2(0.3, 0.32)],
	"hexa": [Vector2(-0.3, -0.26), Vector2(0.3, -0.26), Vector2(0.0, 0.34), Vector2(-0.3, -0.26)],
	"breaker": [Vector2(-0.32, -0.32), Vector2(0.32, 0.32), Vector2(0.0, 0.0), Vector2(0.0, 0.4)],
	"rise": [Vector2(0.04, 0.38), Vector2(-0.04, -0.38)],
	"comb": [Vector2(-0.32, -0.25), Vector2(0.32, -0.12), Vector2(-0.32, 0.02), Vector2(0.32, 0.16)],
}
# 카드마다 고유 문양: [문양, 점 반지름, 완벽 배율, 가시 수, 판정(fast 시간 몫 · precise 가운데 · flick 휙 · beat 박자)]. 없는 카드는 종류별 기본
const CARD_GLYPH := {
	"slash": ["slash", 24.0, 1.3, 0, {"fast": 0.55, "precise": 0.6, "flick": 0.28}],
	"bash": ["bash", 26.0, 1.3, 0, {"fast": 0.55, "precise": 0.6, "flick": 0.25}],
	"pierce": ["pierce", 20.0, 1.4, 0, {"fast": 0.55, "precise": 0.6, "flick": 0.2}],
	"twin_slash": ["twin", 22.0, 1.5, 1, {"fast": 0.65, "precise": 0.6}],
	"bolt": ["tri", 22.0, 1.5, 0, {"precise": 0.6, "beat": 0.34}],
	"suppress": ["diamond", 20.0, 1.5, 0, {"precise": 0.6, "beat": 0.32}],
	"sigil_burst": ["star", 20.0, 1.8, 1, {"precise": 0.6, "beat": 0.3}],
	"torrent": ["spiral", 18.0, 1.8, 1, {"precise": 0.6, "beat": 0.26}],
	"jab": ["jab", 22.0, 1.3, 0, {"fast": 0.45, "precise": 0.6, "flick": 0.16}],
	"flurry": ["w", 21.0, 1.5, 1, {"fast": 0.65, "precise": 0.6}],
	"storm": ["storm", 20.0, 1.6, 2, {"fast": 0.7, "precise": 0.6}],
	"finisher": ["cross", 24.0, 1.8, 1, {"fast": 0.7, "precise": 0.6}],
	"palm": ["chevron", 24.0, 1.4, 0, {"fast": 0.6, "precise": 0.6, "flick": 0.24}],
	"focus_strike": ["needle", 16.0, 1.7, 0, {"fast": 0.55, "precise": 0.5, "flick": 0.22}],
	"shield_throw": ["arc", 22.0, 1.5, 0, {"fast": 0.6, "precise": 0.6}],
	"volley": ["arrow", 20.0, 1.5, 0, {"fast": 0.55, "precise": 0.6}],
	"weak_point": ["bullseye", 18.0, 1.6, 0, {"fast": 0.7, "precise": 0.5}],
	"mark_amp": ["hex", 20.0, 1.6, 1, {"precise": 0.6, "beat": 0.3}],
	"ember": ["flame", 20.0, 1.6, 0, {"precise": 0.6, "beat": 0.32}],
	"beat_slash": ["note", 22.0, 1.6, 0, {"precise": 0.6, "beat": 0.3}],
	"heal_sigil": ["heart", 22.0, 1.0, 0, {"precise": 0.6, "beat": 0.32}],
	"slam": ["hammer", 26.0, 1.7, 1, {"fast": 0.6, "precise": 0.6}],
	"fireball": ["comet", 22.0, 1.6, 0, {"precise": 0.6, "beat": 0.32}],
	"frost_lance": ["flake", 21.0, 1.6, 0, {"precise": 0.6, "beat": 0.32}],
	"ice_coffin": ["crystal", 20.0, 1.7, 1, {"precise": 0.6, "beat": 0.3}],
	"dark_rift": ["rift", 20.0, 1.9, 1, {"precise": 0.6, "beat": 0.28}],
	"gust": ["gale", 22.0, 1.5, 0, {"precise": 0.6, "beat": 0.32}],
	"bleed_arrows": ["fang", 21.0, 1.5, 1, {"fast": 0.6, "precise": 0.6}],
	"hex_bolt": ["hexa", 22.0, 1.5, 0, {"precise": 0.6, "beat": 0.32}],
	"armor_break": ["breaker", 24.0, 1.5, 0, {"fast": 0.6, "precise": 0.6}],
	"launcher": ["rise", 24.0, 1.4, 0, {"fast": 0.55, "precise": 0.6, "flick": 0.24}],
	"hundred_fists": ["comb", 21.0, 1.6, 1, {"fast": 0.65, "precise": 0.6}],
}
# 연출마다 얹는 소리 [이름, 높낮이]
const SIG_SFX := {"slash": ["swing", 1.45], "shock": ["bash", 0.8], "needle": ["shatter", 1.3], "puff": ["body", 1.4], "vortex": ["burst", 0.7],
	"target": ["crit_ring", 1.2], "flame": ["furnace", 1.15], "notes": ["echo", 1.25], "quake": ["bash", 0.55], "rain": ["arrow", 1.3], "chain": ["arc", 1.3]}
# 카드 고유 연출(P2SkillFx 종류, cut = 공간베기 화면 효과)
const SKILL_SIG := {"jab": "puff", "flurry": "slash", "storm": "slash", "spin_kick": "slash", "twin_slash": "slash", "palm": "shock", "bash": "shock",
	"focus_strike": "needle", "pierce": "needle", "finisher": "cut", "sigil_burst": "sigil", "torrent": "vortex",
	"shield_throw": "shock", "volley": "needle", "weak_point": "target", "mark_amp": "sigil", "ember": "flame", "beat_slash": "notes",
	"slam": "quake", "arrow_rain": "rain", "chain_blast": "chain", "quickshot": "needle", "aimed_shot": "target", "suppress": "puff",
	"slash": "slash", "sweep": "slash", "bolt": "puff", "wave": "puff"}


# 카드 → 문양·순서·크기·시간·완벽 배율(치명 배율 대신). 문양은 적 몸보다 크게(약 300px) 화면 안에 그린다.
# 기본 베기·강타·찌르기 = 한 번 긋기(화살표 방향으로 두 점을 휙: 빠르게 지나가야 완벽).
# 강한 물리 = 순서 지그재그 + 가시, 연속 타격 = V + 가시, 마법 = 박자 문양(속도는 안 봄), 강한 마법 = 박자 + 가시
func _slash_points(card: Card, target: int) -> Dictionary:
	var kind := P2Catalog.kind_of(card)
	var magic := P2Catalog.is_magic(card)
	var strong := card.get_mana_cost() >= 2 or P2Catalog.upgrade_of(card) != "" or P2Catalog.is_x_cost(card)
	var pts: Array[Vector2] = []
	var self_glyph := kind == "heal_sigil"
	if not P2Catalog.is_targeted(card) and not self_glyph:
		var idx := range(battle.monsters.size()).filter(func(i): return battle.monsters[i].is_alive())
		idx.sort_custom(func(a, b): return _enemy_pos(a).x < _enemy_pos(b).x)
		for i in idx:
			var hh := float(_enemy_sprites[i].get_meta("torso_h", 128.0))
			pts.append(_to_ui(_enemy_torso(i) + Vector2(_feel_rng.randf_range(-0.08, 0.08), _feel_rng.randf_range(-0.16, 0.16)) * hh).round())
		var aoe := {"fast": 0.6, "precise": 0.6}
		if magic:
			aoe.beat = 0.36
		return {"points": pts, "radius": 26.0, "limit": 1.2 + 0.3 * pts.size(), "anchor": Vector2.ZERO, "ordered": true, "rune": magic,
			"power": 1.4 if magic else 1.3, "opts": aoe}
	var spec: Array = CARD_GLYPH.get(kind, ["star", 20.0, 1.8, 1, {"precise": 0.6, "beat": 0.3}] if magic and strong else (["tri", 22.0, 1.5, 0, {"precise": 0.6, "beat": 0.34}] if magic else (["zigzag", 22.0, 1.6, 2, {"fast": 0.65, "precise": 0.6}] if strong else CARD_GLYPH.slash)))
	var glyph := String(spec[0])
	var r := float(spec[1])
	var power := float(spec[2])
	var thorn_n := int(spec[3])
	var opts: Dictionary = (spec[4] as Dictionary).duplicate()
	# 강화 사본: 같은 문양에 가시 하나 더(기본 베기는 지그재그)
	if P2Catalog.upgrade_of(card) != "":
		if glyph == "slash":
			glyph = "zigzag"
			r = 22.0
			opts = {"fast": 0.65, "precise": 0.6}
			thorn_n = 2
		else:
			thorn_n += 1
		power += 0.1
	var shape: Array = GLYPHS[glyph]
	var c := _player_body() + Vector2(0, -8) if self_glyph else _enemy_torso(target)
	var gs := 290.0 if self_glyph else clampf(float(_enemy_sprites[target].get_meta("torso_h", 128.0)) * 1.6, 260.0, 340.0)
	var flip := -1.0 if _feel_rng.randf() < 0.5 and glyph in ["slash", "zigzag", "storm", "needle"] else 1.0
	var turn := _feel_rng.randf_range(-0.3, 0.3) if not glyph in ["star", "spiral", "diamond", "cross", "arc", "bullseye", "hex", "flame", "note", "heart"] else 0.0
	for v in shape:
		var o := Vector2(v.x, v.y * flip).rotated(turn) * gs
		var j := Vector2(_feel_rng.randf_range(-6, 6), _feel_rng.randf_range(-6, 6)) if glyph != "star" else Vector2.ZERO
		pts.append(_to_ui(c + o + j).round())
	# 화면 안으로 (위 띠·손패를 피해서)
	var box := Rect2(pts[0], Vector2.ZERO)
	for q in pts:
		box = box.expand(q)
	var room := Rect2(80, 100, 1120, 360)
	var shift := Vector2(maxf(0.0, room.position.x + r - box.position.x) - maxf(0.0, box.end.x + r - room.end.x),
		maxf(0.0, room.position.y + r - box.position.y) - maxf(0.0, box.end.y + r - room.end.y))
	for k in range(pts.size()):
		pts[k] = (pts[k] + shift).round()
	# 가시: 고른 구간의 한가운데(곧게 그으면 닿는다)
	var thorns: Array = []
	var segs := range(pts.size() - 1)
	segs.shuffle()
	for k in range(mini(thorn_n, segs.size())):
		var sg := int(segs[k])
		thorns.append(((pts[sg] + pts[sg + 1]) / 2.0).round())
	opts.thorns = thorns
	var limit := 1.3 if pts.size() == 2 else 0.9 + 0.32 * pts.size()
	return {"points": pts, "radius": r, "limit": limit, "anchor": c, "ordered": true, "rune": magic, "power": power, "opts": opts}


func _slash_input(card: Card, target: int) -> Dictionary:
	var spec := _slash_points(card, target)
	_clear_preview()
	for p in _enemy_panels:
		(p.ring as Panel).visible = false
	var opts: Dictionary = (spec.opts as Dictionary).duplicate()
	opts.reverse = battle.relics.has("reverse_brush") and P2Catalog.is_attack(card)
	opts.eat_thorns = battle.relics.has("thorn_eater")
	var tip := tr("가운데를 빠르게 · 우클릭 취소")
	if float(opts.get("flick", 0.0)) > 0.0:
		tip = tr("화살표 방향으로 휙 · 우클릭 취소")
	elif float(opts.get("beat", 0.0)) > 0.0:
		tip = tr("고리가 닿을 때 차례로 지나가기")
	elif not (opts.get("thorns", []) as Array).is_empty():
		tip = tr("순서대로 · 빨간 가시는 피해서") if not bool(opts.eat_thorns) else tr("순서대로 · 가시는 삼켜도 됨(피해 +3 · 체력 −1)")
	if bool(opts.reverse) and float(opts.get("beat", 0.0)) <= 0.0:
		tip += "\n" + tr("푸른 고리(마지막 점)부터 거꾸로 = 방어")
	_set_prompt(tip)
	var pad := P2SlashPad.new()
	pad.setup(spec.points, float(spec.radius), float(spec.limit), bool(spec.ordered), bool(spec.rune), opts)
	var ch := _charge_begin(card)
	var pts: Array = spec.points
	pad.crossed.connect(func(i: int, n: int) -> void:
		_combo_hit(true)
		_sfx("swing", 1.25 + 0.08 * n)
		if i >= 0 and i < pts.size():
			_charge_step(ch, pts[i], n, pts.size())
		if _music != null:
			_music.step(n - 1)
		elif _beat != null:
			_beat.play("chime", n - 1))
	pad.tick.connect(func(_i: int) -> void:
		if _beat != null:
			_beat.play("stick"))
	pad.held.connect(func(id: Variant, down: bool, label: String) -> void: _keys_node().press(id, down, label))
	_ui.add_child(pad)
	_open_rhythm(pad, false)
	_slowmo(true, [])
	var res: Dictionary = await pad.finished
	_charge_end(ch, String(res.grade))
	if (_rs.sl as Dictionary).has(String(res.grade)):
		_rs.sl[res.grade] = int(_rs.sl[res.grade]) + 1
	if String(res.grade) in ["part", "graze"]:
		_combo_hit(false)
	_slowmo(false)
	_set_prompt("")
	var anchor: Vector2 = spec.anchor
	var rel := PackedVector2Array()
	for q in res.stroke as PackedVector2Array:
		rel.append(q - anchor)
	res.rel = rel
	res.target = target
	res.rune = spec.rune
	res.power = spec.power if String(res.grade) == "perfect" else 1.0
	slash_log.append({"card": P2Catalog.kind_of(card), "grade": res.grade, "crossed": res.crossed, "total": res.total, "precise": res.precise, "quick": res.quick, "power": res.power, "ms": Time.get_ticks_msec()})
	if String(res.grade) == "perfect":
		_sfx("crit_ready", 1.1)
	return res


func _skill_color(kind: String) -> Color:
	if kind in ["sigil_burst", "torrent", "bolt", "mark_amp", "chain_blast"]:
		return C_ARCANE
	if kind == "beat_slash":
		return C_GOLD
	if kind == "ember":
		return Color("#ff8a3c")
	return P2Catalog.CLASS_COLOR.get(String(P2Catalog.CARD_CLASS.get(kind, "")), C_IVORY)


# 힘 모으기: 긋는 동안 주인공 몸에 기운이 감기고, 점을 지날 때마다 그 점에서 몸으로 한 줄씩 빨려 든다. 끝나면 터지거나(맞힘·완벽) 꺼짐
func _charge_begin(card: Card) -> P2SkillFx:
	if _reduce_motion or _fxp == null:
		return null
	return P2SkillFx.spawn(_fxp, "charge", _player_body() + Vector2(0, 12), Vector2.RIGHT, 1.0, _skill_color(P2Catalog.kind_of(card)))


func _charge_step(ch: P2SkillFx, ui_pt: Vector2, n: int, total: int) -> void:
	if ch == null or not is_instance_valid(ch):
		return
	ch.level = clampf(float(n) / maxf(1.0, total), 0.0, 1.0)
	ch.add_thread(_to_world(ui_pt) - ch.position)
	_actor_flash(_player, ch.color, 0.25 + 0.35 * ch.level, 0.03, 0.16)


func _charge_end(ch: P2SkillFx, grade: String) -> void:
	if ch == null or not is_instance_valid(ch):
		return
	if grade == "perfect":
		ch.size = 1.3
	ch.release(grade in ["perfect", "hit"])


# 카드 고유 연출 한 번(맞는 자리 pos, 몇 번째 타격 k)
func _skill_mark(kind: String, pos: Vector2, k: int) -> void:
	var sig := String(SKILL_SIG.get(kind, ""))
	if sig == "" or sig == "cut" or sig == "sigil" or _reduce_motion:
		return
	var col := _skill_color(kind)
	var fx: P2SkillFx
	match sig:
		"slash":
			var a := (-0.62 if k % 2 == 0 else 0.58) + randf_range(-0.22, 0.22)
			if kind == "spin_kick":
				a = randf_range(-0.1, 0.1)
			fx = P2SkillFx.spawn(_fxp, "slash", pos, Vector2.RIGHT.rotated(a), 1.15 if kind == "storm" else 0.9, col)
		"needle":
			fx = P2SkillFx.spawn(_fxp, "needle", pos, _stroke_dir(), 1.0, col)
		"shock":
			fx = P2SkillFx.spawn(_fxp, "shock", pos, _stroke_dir(), 1.0 if kind == "palm" else 0.75, col)
		"quake":
			fx = P2SkillFx.spawn(_fx_back, "quake", Vector2(pos.x, FEET_Y - 2.0), Vector2.RIGHT, 1.35, col)
		"rain":
			if k == 0 and not bool(get_meta("rain_up", false)):
				set_meta("rain_up", true)
				get_tree().create_timer(0.6).timeout.connect(func() -> void: set_meta("rain_up", false))
				for j in range(5):
					P2SkillFx.spawn(_fxp, "streak", _player_body() + Vector2(10, -30), Vector2(0.3 + j * 0.08, -1.0), 1.1, col)
			fx = P2SkillFx.spawn(_fxp, "rain", pos + Vector2(randf_range(-30.0, 30.0), randf_range(-30.0, 30.0)), Vector2.DOWN, 1.1, col)
			for j in range(2):
				P2SkillFx.spawn(_fxp, "rain", pos + Vector2(randf_range(-70.0, 70.0), randf_range(-20.0, 70.0)), Vector2.DOWN, 0.9, col)
		"chain":
			fx = P2SkillFx.spawn(_fxp, "chain", pos, Vector2.RIGHT, 1.2, col)
		_:
			# 불꽃은 발밑에서 몸을 덮을 만큼, 음표·과녁·툭은 조금 크게
			var at := Vector2(pos.x, FEET_Y - 6.0) if sig == "flame" else pos
			fx = P2SkillFx.spawn(_fxp, sig, at, _stroke_dir(), float({"flame": 1.9, "notes": 1.4, "target": 1.2, "puff": 1.3}.get(sig, 1.0)), col)
	skill_log.append({"card": kind, "fx": fx.kind})
	var snd: Array = SIG_SFX.get(sig, [])
	if not snd.is_empty():
		_sfx(String(snd[0]), float(snd[1]), -4.0)
	var feet := Vector2(pos.x, FEET_Y - 4.0)
	match sig:
		"shock":
			_shockwave(pos, 10.0 if kind == "palm" else 7.0)
			P2SkillFx.spawn(_fx_back, "crack", feet, Vector2.RIGHT, 1.0, col)
		"vortex":
			_shockwave_later(pos, 9.0, 0.5)
			P2SkillFx.spawn(_fx_back, "ripple", feet, Vector2.RIGHT, 1.0, col)
		"target":
			_shockwave(pos, 6.0, 700.0, 0.3)
		"flame":
			P2SkillFx.spawn(_fx_back, "scorch", feet, Vector2.RIGHT, 1.0, col)
		"needle":
			_shockwave(pos + _stroke_dir() * 60.0, 4.0, 600.0, 0.25)
		"quake":
			_shockwave(feet, 18.0, 1100.0, 0.55)
			_shockwave_later(feet, 9.0, 0.16)
			P2SkillFx.spawn(_fx_back, "crack", feet, Vector2.RIGHT, 2.2, col)
			P2HitBits.spawn(_fxp, "chunk", feet + Vector2(0, -10), Vector2.UP, 22, [Color("#7a6a58"), Color("#b8ad9e"), Color("#5a4c40"), col], 1.5)
			_camera_kick("heavy", Vector2.DOWN)
		"rain":
			if k == 0:
				P2SkillFx.spawn(_fx_back, "dust", feet, Vector2.RIGHT, 1.2, col)
		"chain":
			_shockwave(pos, 9.0, 800.0, 0.35)


# 맞을 때 튀는 모양 있는 조각: 카드 고유 연출에서 고르고, 없으면 마법 = 룬 · 물리 = 깃털. 음표는 넉넉히
const SIG_BITS := {"slash": "feather", "shock": "chunk", "needle": "shard", "puff": "star", "vortex": "drop", "target": "shard",
	"flame": "ember", "notes": "note", "sigil": "rune", "cut": "shard", "quake": "chunk", "rain": "shard", "chain": "rune"}


func _hit_bits(pos: Vector2, dir: Vector2, big: bool) -> void:
	if _reduce_motion or _fxp == null:
		return
	var sig := String(SKILL_SIG.get(_cur_kind, ""))
	var shape := String(SIG_BITS.get(sig, "rune" if _cur_magic else "feather"))
	var col := _skill_color(_cur_kind)
	var colors: Array = [col, col.lerp(Color.WHITE, 0.45), C_IVORY]
	match shape:
		"chunk":
			colors = [Color("#7a6a58"), Color("#b8ad9e"), Color("#5a4c40"), col]
		"drop":
			colors = [Color("#5fd8cf"), Color("#9ff3ff"), Color.WHITE]
		"ember":
			colors = [Color("#ff8a3c"), Color("#ffd25a"), Color("#ff5a2a")]
		"note":
			colors = [C_GOLD, C_IVORY, Color("#9fd4ff"), Color("#ff9ad0"), Color("#8be08b")]
	var n: int = int({"note": 16, "ember": 16, "drop": 16, "chunk": 12, "star": 8}.get(shape, 10)) + (6 if big else 0)
	P2HitBits.spawn(_fxp, shape, pos, dir, n, colors, 1.2 if big else 1.0)


# 충격파(화면 굴절 원): 세계 자리에서 퍼진다. 최대 넷, 오래된 것부터 밀어냄
func _shockwave(at: Vector2, power := 8.0, speed := 900.0, life := 0.36) -> void:
	if _reduce_motion:
		return
	if _wave_rect == null:
		var layer := CanvasLayer.new()
		layer.layer = 7
		add_child(layer)
		var bb := BackBufferCopy.new()
		bb.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
		layer.add_child(bb)
		_wave_rect = ColorRect.new()
		_wave_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		_wave_rect.size = Vector2(1280, 720)
		_wave_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_wave_mat = ShaderMaterial.new()
		_wave_mat.shader = load("res://p2/p2_shockwave.gdshader")
		_wave_rect.material = _wave_mat
		_wave_rect.visible = false
		layer.add_child(_wave_rect)
	if _show != null and power >= 9.0:
		_show.impact_look(at, power)
	if _waves.size() >= 4:
		_waves.pop_front()
	_waves.append({"at": at, "t": 0.0, "power": power, "speed": speed, "life": life})
	wave_log.append({"at": at, "power": power})
	_wave_rect.visible = true


func _shockwave_later(at: Vector2, power: float, delay: float) -> void:
	var token := _action_token
	await _wait(delay)
	if is_inside_tree() and token == _action_token:
		_shockwave(at, power)


func _tick_waves(delta: float) -> void:
	var keep: Array = []
	for w in _waves:
		w.t = float(w.t) + delta
		if float(w.t) < float(w.life):
			keep.append(w)
	_waves = keep
	if _wave_mat == null:
		return
	_wave_mat.set_shader_parameter("count", _waves.size())
	for i in range(4):
		var v := Vector4.ZERO
		if i < _waves.size():
			var w: Dictionary = _waves[i]
			var u := float(w.t) / float(w.life)
			var c := _to_ui(w.at)
			v = Vector4(c.x, c.y, float(w.speed) * float(w.t), float(w.power) * (1.0 - u) * (1.0 - u))
		_wave_mat.set_shader_parameter("w%d" % i, v)
	_wave_rect.visible = not _waves.is_empty()


# 맞은 방향으로 몸을 뚫고 나가는 잔광 · 몸 뒤로 튀는 파편 · 큰 타격이면 발밑 먼지
func _hit_trail(pos: Vector2, dir: Vector2, big: bool, crit: bool) -> void:
	if _reduce_motion:
		return
	if big or crit:
		P2SkillFx.spawn(_fxp, "streak", pos, dir, 1.2 if crit else 1.0, C_CRIT if crit else C_IVORY)
		P2SkillFx.spawn(_fxp, "dust", Vector2(pos.x + 16.0, FEET_Y - 6.0), dir, 1.0 if big else 0.8)
		_shockwave(pos, 6.0 if crit else 4.5, 800.0, 0.3)
	_sparks(pos + dir * 26.0, dir, 0.35, 10 if big else 5, [Color.WHITE, C_IVORY], false, Vector2(380, 780), 300.0)


# 공간베기(마무리 일격): 세 줄이 차례로 세계를 가르고, 조각이 줄을 따라 미끄러지며 벌어졌다가 한 번에 붙는다. 붙는 순간에 끝난다(그때 피해)
func _space_cut(at: Vector2, dir: Vector2) -> void:
	if _reduce_motion:
		return
	if _cut_rect == null:
		var layer := CanvasLayer.new()
		layer.layer = 6
		add_child(layer)
		var bb := BackBufferCopy.new()
		bb.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
		layer.add_child(bb)
		_cut_rect = ColorRect.new()
		_cut_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		_cut_rect.size = Vector2(1280, 720)
		_cut_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_cut_mat = ShaderMaterial.new()
		_cut_mat.shader = load("res://p2/p2_space_cut.gdshader")
		_cut_rect.material = _cut_mat
		layer.add_child(_cut_rect)
	var m := _cut_mat
	var d := dir.normalized()
	var d1 := d.rotated(1.05)
	var d2 := d.rotated(-0.95)
	m.set_shader_parameter("line0", Vector4(at.x, at.y, d.x, d.y))
	m.set_shader_parameter("line1", Vector4(at.x - 70.0, at.y - 36.0, d1.x, d1.y))
	m.set_shader_parameter("line2", Vector4(at.x + 84.0, at.y + 24.0, d2.x, d2.y))
	m.set_shader_parameter("count", 3)
	for key in ["reveal", "slide", "gap", "tint", "flash"]:
		m.set_shader_parameter(key, 0.0)
	m.set_shader_parameter("glow", 1.0)
	_cut_rect.visible = true
	skill_log.append({"card": "finisher", "fx": "cut"})
	_sfx("swing", 1.6)
	_sfx_later("swing", 0.06)
	_sfx_later("swing", 0.12)
	var spread := func(v: float) -> void:
		m.set_shader_parameter("slide", 40.0 * v)
		m.set_shader_parameter("gap", 16.0 * v)
	var t := create_tween()
	t.tween_method(func(v: float) -> void: m.set_shader_parameter("reveal", v), 0.0, 1.0, 0.2)
	t.parallel().tween_method(func(v: float) -> void: m.set_shader_parameter("tint", v), 0.0, 0.85, 0.12)
	t.tween_callback(func() -> void:
		_sfx("crit_ring", 0.8)
		_sfx("slash_major", 0.7))
	t.tween_method(spread, 0.0, 1.0, 0.16).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.14)
	t.tween_method(spread, 1.0, 0.0, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await t.finished
	if not is_inside_tree():
		return
	_sfx("burst", 0.8)
	_sfx("weight", 0.9)
	_shockwave(_to_world(at), 16.0, 1100.0, 0.45)
	var tail := create_tween()
	tail.tween_method(func(v: float) -> void: m.set_shader_parameter("flash", v), 0.55, 0.0, 0.12)
	tail.parallel().tween_method(func(v: float) -> void:
		m.set_shader_parameter("tint", v * 0.85)
		m.set_shader_parameter("glow", v), 1.0, 0.0, 0.24)
	tail.tween_callback(func() -> void: _cut_rect.visible = false)


# 맞는 순간: 그은 선 그대로 베인 자국 (카드 한 장에 한 번)
func _slash_replay() -> void:
	if _slash_trace.is_empty() or bool(_slash_trace.get("shown", false)) or (_slash_trace.rel as PackedVector2Array).size() < 2:
		return
	_slash_trace.shown = true
	var t := int(_slash_trace.target)
	var trail := P2SlashTrail.new()
	trail.position = _enemy_torso(t) if t >= 0 else Vector2.ZERO
	trail.setup(_slash_trace.rel, String(_slash_trace.grade), bool(_slash_trace.get("rune", false)))
	_fxp.add_child(trail)


# ── 손맛 시험판: 적 공격 악보 ──

# 0 하층 일반 · 1 심층(_h·mid)·미믹 · 2 정예 · 3 보스
func _parry_tier(index: int) -> int:
	var role: String = battle.roles[index]
	var rank := String(P2Catalog.ENEMIES[role].get("rank", ""))
	if rank == "boss":
		return 3
	if rank == "elite":
		return 2
	if role.ends_with("_h") or role.contains("mid") or rank == "mimic":
		return 1
	return 0


# 이번 행동의 악보 계획: 묶음(타격)마다 노트 종류 · 칸(문장만) · 앞 노트와의 반 박 간격 · 강타. 같은 차례·같은 적이면 늘 같다(예고 칸도 이걸 그린다).
# 정예·보스의 고유 문장이 있으면 그것(처음 두 번은 같고 세 번째부터 한 군데 바뀜), 없으면 등급·고유 노트 묶음으로 만든다.
# simple(억제됨): 특수 노트가 짧은 노트가 되고 노트 하나가 빠진다
func _parry_pattern(index: int, hits: Array, simple := false) -> Array:
	var tier := _parry_tier(index)
	var role: String = battle.roles[index]
	var out: Array = []
	var ph: Dictionary = (PHRASES.get(role, {}) as Dictionary).get(hits.size(), {})
	var heavy_at := roundi(10.0 * battle.hit_mult)
	if role == "maek_summoner_low" and int(hits[0]) >= heavy_at:
		ph = {}
	if _music != null and ph.is_empty():
		return _cell_pattern(index, hits, simple, tier)
	if not ph.is_empty():
		var notes: Array = (ph.notes as Array).duplicate(true)
		if int(_phrase_seen.get(role + String(ph.name), 0)) >= 2:
			for k in (ph["var"] as Dictionary):
				var rpl: Array = ph["var"][k]
				notes[int(k)] = [rpl[0], rpl[1], rpl[2], notes[int(k)][3]]
		var split := int(ph.get("split", notes.size()))
		var parts := [notes.slice(0, split)] if hits.size() == 1 else [notes.slice(0, split), notes.slice(split)]
		for gi in range(parts.size()):
			var part: Array = parts[gi]
			out.append({"kinds": part.map(func(q): return String(q[0])), "cells": part.map(func(q): return Vector2i(int(q[1]), int(q[2]))),
				"gaps": part.map(func(q): return int(q[3])), "crush": int(hits[mini(gi, hits.size() - 1)]) >= heavy_at and tier >= 2, "phrase": String(ph.name)})
	else:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([battle.seed_used, battle.turn_number, index, hits.size()])
		var pool: Array = NOTE_POOL.get(role, ["t"])
		for hi in range(hits.size()):
			var raw := int(hits[hi])
			var heavy := raw >= heavy_at
			var n: int = int([1, 2, 3, 4][tier]) + (1 if tier == 0 and raw >= 5 else 0) + (1 if heavy else 0) - (1 if hits.size() > 1 else 0)
			n = maxi(n, 1)
			var kinds: Array = []
			var gaps: Array = []
			for k in range(n):
				kinds.append(String(pool[0]) if hi == 0 and k == 0 else String(pool[rng.randi() % pool.size()]))
				gaps.append(0 if hi == 0 and k == 0 else (3 if k == 0 else 1 + rng.randi() % 3))
			if heavy:
				kinds[n - 1] = "h" if tier < 2 or rng.randf() < 0.5 else "s"
			if kinds[n - 1] == "x":
				kinds[n - 1] = "t"
			out.append({"kinds": kinds, "cells": [], "gaps": gaps, "crush": heavy and tier >= 2, "phrase": ""})
	# 난이도 패턴: 이지는 억제된 적처럼 쉽게, 하드는 엇박 노트 하나 더, 익스트림은 하나 더 + 가운데 노트를 두 번 누르기로. 겹박자 적은 한 단계 더
	var lvl := battle.pattern_level + (1 if battle.affix(index) == "rhythm" else 0)
	if lvl > 0:
		for g in out:
			var gk: Array = g.kinds
			gk.append("t")
			(g.gaps as Array).append(1)
			if not (g.cells as Array).is_empty():
				var lc: Vector2i = (g.cells as Array).back()
				(g.cells as Array).append(Vector2i(clampi(lc.x + (1 if lc.x <= 0 else -1), -2, 2), lc.y))
			if lvl >= 2:
				gk.append("t")
				(g.gaps as Array).append(2)
				if not (g.cells as Array).is_empty():
					var lc2: Vector2i = (g.cells as Array).back()
					(g.cells as Array).append(Vector2i(lc2.x, clampi(lc2.y + (1 if lc2.y <= 0 else -1), -1, 1)))
				var mid := gk.size() / 2
				if String(gk[mid]) == "t":
					gk[mid] = "d"
	if simple or lvl < 0:
		for g in out:
			g.kinds = (g.kinds as Array).map(func(k): return k if k in ["t", "h"] else "t")
		var big := 0
		for gi in range(out.size()):
			if (out[gi].kinds as Array).size() > (out[big].kinds as Array).size():
				big = gi
		var bg: Dictionary = out[big]
		if (bg.kinds as Array).size() > 1:
			var drop := (bg.kinds as Array).size() - 2
			for key in ["kinds", "gaps"]:
				(bg[key] as Array).remove_at(drop)
			if not (bg.cells as Array).is_empty():
				(bg.cells as Array).remove_at(drop)
	return out


# 세계 음악 전투의 악보 계획: 공격 하나가 적어도 두 마디(한 번 치면 그 묶음이 두 마디, 여러 번이면 타격마다 한 마디), 노트 자리는 박 쪼개기 칸(P2MusicMeta.CELLS)을 적 등급 중심으로 섞어 뽑는다
# (묶음끼리 같은 칸은 연달아 안 나옴). 롱·따라가기는 묶음 끝에만, 앞뒤가 좁은 자리의 특수 노트는 짧은 노트로. 같은 차례·같은 적이면 늘 같다
func _cell_pattern(index: int, hits: Array, simple: bool, tier: int) -> Array:
	var role: String = battle.roles[index]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([battle.seed_used, battle.turn_number, index, hits.size(), "cells"])
	var shift := battle.pattern_level + (1 if battle.affix(index) == "rhythm" else 0)
	var mix: Dictionary = P2MusicMeta.MIX[["normal", "deep", "elite", "boss"][clampi(tier + maxi(shift, 0), 0, 3)]]
	var pool: Array = NOTE_POOL.get(role, ["t"])
	var heavy_at := roundi(10.0 * battle.hit_mult)
	var out: Array = []
	var prev := ""
	var sum := 0.0
	for k in mix:
		sum += float(mix[k])
	var span := 2 if hits.size() == 1 else 1
	for hi in range(hits.size()):
		var beats: Array = []
		for b in range(span):
			beats.append_array(_pick_cell(mix, sum, rng, prev).map(func(x): return float(x) + 4.0 * b))
			prev = String(_cell_key)
		if (simple or shift < 0) and beats.size() > 2:
			beats.remove_at(beats.size() - 2)
		var heavy := int(hits[hi]) >= heavy_at
		var kinds: Array = []
		for k in range(beats.size()):
			var after := (float(beats[k + 1]) if k + 1 < beats.size() else 4.0 * span) - float(beats[k])
			var before := float(beats[k]) - (float(beats[k - 1]) if k > 0 else -1.0)
			var kind := String(pool[0]) if hi == 0 and k == 0 else String(pool[rng.randi() % pool.size()])
			if kind in ["h", "s"] or (kind in ["d", "f", "x"] and (after < 1.0 or before < 0.5)) or (simple and kind != "t"):
				kind = "t"
			kinds.append(kind)
		if heavy:
			kinds[kinds.size() - 1] = "h" if tier < 2 or rng.randf() < 0.5 else "s"
		if kinds.back() == "x":
			kinds[kinds.size() - 1] = "t"
		out.append({"kinds": kinds, "cells": [], "gaps": [], "beats": beats, "crush": heavy and tier >= 2, "phrase": ""})
	return out


var _cell_key := ""


# 섞는 비율대로 등급을 뽑고 그 등급 칸 하나(바로 앞 칸 prev와는 다르게)
func _pick_cell(mix: Dictionary, sum: float, rng: RandomNumberGenerator, prev: String) -> Array:
	var pick: Array = []
	for _tries in range(4):
		var lv := String(mix.keys().back())
		var x := rng.randf() * sum
		for k in mix:
			x -= float(mix[k])
			if x < 0.0:
				lv = String(k)
				break
		var cells: Array = P2MusicMeta.CELLS[lv]
		var ci := rng.randi() % cells.size()
		pick = cells[ci]
		_cell_key = "%s%d" % [lv, ci]
		if _cell_key != prev:
			break
	return pick


# 다음 노트 시각: 박 칸 계획(beats)이면 묶음마다 다음 마디 첫 박(origin = 첫 묶음 마디 첫 박)에서 칸 자리대로, 아니면 앞 노트에서 반 박 간격만큼
func _next_t(g: Dictionary, k: int, t: float, beat: float, origin: float) -> float:
	if not g.has("beats"):
		return t + int(g.gaps[k]) * beat / 2.0
	if k == 0:
		var bar := beat * 4.0
		g["bar_at"] = origin + ceilf((t - origin) / bar - 0.001) * bar
	return maxf(t, float(g.bar_at) + float(g.beats[k]) * beat)


# 원거리 적(사수·맥 귀족)의 공격은 언다인식 화살 막기(P2ArrowChart). 리듬(간격·강타·보스 문장 칸)은 같은 계획에서 받고,
# 방향과 화살 종류는 그 장르답게 따로 정한다. --osu-all이면 예전처럼 모두 고리
func _arrow_enemy(index: int) -> bool:
	return _genre_of(index) == "arrow"


# 적 공격의 리듬 장르(P2Catalog.ENEMIES의 parry): osu 고리 · arrow 화살 막기 · drum 북 장단 · dodge 박자 피하기 · echo 부름-응답.
# medley(최종 보스)는 차례마다 돌아가며 바뀐다. --osu-all이면 예전처럼 모두 고리
func _genre_of(index: int) -> String:
	if genre_force != "":
		return genre_force
	if "--osu-all" in OS.get_cmdline_user_args():
		return "osu"
	var g := String(P2Catalog.ENEMIES[battle.roles[index]].get("parry", "osu"))
	if g == "medley":
		return String(["drum", "arrow", "dodge", "osu"][posmod(battle.turn_number, 4)])
	return g


func _plain_chart(node: Node) -> bool:
	return node is P2NoteChart and not (node is P2ArrowChart or node is P2DrumChart or node is P2DodgeChart or node is P2EchoChart)


func _genre_notes(genre: String, index: int, pat: Array, tier: int, beat: float, ap: float, call: float) -> Array:
	match genre:
		"arrow":
			return _arrow_notes(index, pat, tier, beat, ap, call)
		"drum":
			return _drum_notes(index, pat, tier, beat, ap, call)
		"dodge":
			return _dodge_notes(index, pat, beat, ap, call)
	return _echo_notes(pat, beat, ap, call)


# 예고 칸 모양(대략): 화살 ◄ · 북 ●(빨강·파랑)과 노랑 띠 · 피하기 □ · 부름 ◆
func _pip_kinds(genre: String, g: Dictionary, tier: int) -> Array:
	var out: Array = []
	match genre:
		"arrow":
			for shots in _arrow_styles(g, tier):
				out.append_array((shots as Array).map(func(q): return "a:" + String(q)))
		"drum":
			var n := 0
			for k in g.kinds:
				if String(k) in ["h", "s"]:
					out.append("d:roll")
				else:
					out.append("d:don" if n % 3 != 2 else "d:ka")
				if String(k) == "d":
					out.append("d:ka")
				n += 1
		"dodge":
			for k in g.kinds:
				for _i in range({"s": 3, "d": 2, "h": 2}.get(String(k), 1)):
					out.append("z")
		_:
			for k in g.kinds:
				out.append("e")
				if String(k) == "d":
					out.append("e")
	return out


# 북 장단: 첫 북은 둥, 그 뒤로 둥·딱을 섞되 같은 색 세 번 연속은 없음. 길게·따라가기 = 노랑 연타(그 길이),
# 두 번 = 반 박 뒤 반대 색 한 번 더, 강타 = 마지막 큰 북(정예·보스)
func _drum_notes(index: int, pat: Array, tier: int, beat: float, ap: float, call: float) -> Array:
	var half := beat / 2.0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([battle.seed_used, battle.turn_number, index, "drum"])
	var notes: Array = []
	var groups: Array = []
	var t := beat * 2.0 + (call - beat if call > 0.0 else 0.0)
	var origin := t
	var last := ""
	var same := 0
	var prev_t := -99.0
	for g in pat:
		var ids: Array = []
		var gk: Array = g.kinds
		for k in range(gk.size()):
			var kind := String(gk[k])
			t = _next_t(g, k, t, beat, origin)
			var stream := _music != null and t - prev_t < beat * 0.6
			prev_t = t
			var heavy := bool(g.crush) and k == gk.size() - 1
			if kind in ["h", "s"] and not heavy:
				var hold := beat * 1.5 if tier >= 2 else beat
				notes.append({"pos": Vector2.ZERO, "at": t, "approach": ap, "kind": "drum", "drum": "roll", "sub": "roll", "hold": hold, "num": 0})
				ids.append(notes.size() - 1)
				t += hold
				last = ""
				continue
			var side := "don"
			if last != "":
				side = "ka" if rng.randf() < 0.45 else "don"
				if side == last and same >= 1:
					side = "ka" if side == "don" else "don"
				# 세계 음악 전투의 연타(반 박보다 촘촘)는 헷갈리지 않게 같은 색으로 타다닥
				if stream:
					side = last
			same = same + 1 if side == last else 0
			last = side
			var note := {"pos": Vector2.ZERO, "at": t, "approach": ap, "kind": "drum", "drum": side, "sub": side, "hold": 0.0, "num": 0}
			if heavy:
				note.crush = true
			notes.append(note)
			ids.append(notes.size() - 1)
			if kind == "d":
				t += half
				var other := "ka" if side == "don" else "don"
				notes.append({"pos": Vector2.ZERO, "at": t, "approach": ap, "kind": "drum", "drum": other, "sub": other, "hold": 0.0, "num": 0})
				ids.append(notes.size() - 1)
				last = other
				same = 0
		groups.append(ids)
	return [notes, groups]


# 박자 피하기: 짧게 = 가로·세로 한 줄(바로 앞 줄과 다르게) · 두 번 = 가로 한 줄, 반 박 뒤 세로 한 줄 · 길게 = 같은 줄이 반 박 간격 두 번 ·
# 따라가기 = 세로줄이 반 박마다 한쪽 끝에서 쓸고 지나감 · 도망 = 나를 노림(보라) · 페인트 = 십자 · 강타 = 한 칸만 남기고 전부
func _dodge_notes(index: int, pat: Array, beat: float, ap: float, call: float) -> Array:
	var half := beat / 2.0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([battle.seed_used, battle.turn_number, index, "dodge"])
	var notes: Array = []
	var groups: Array = []
	var t := beat * 2.0 + (call - beat if call > 0.0 else 0.0)
	var origin := t
	var prev := ""
	var line := func(row: bool, i: int) -> Array:
		return [0, 1, 2].map(func(j): return Vector2i(j, i) if row else Vector2i(i, j))
	for g in pat:
		var ids: Array = []
		var gk: Array = g.kinds
		for k in range(gk.size()):
			var kind := String(gk[k])
			t = _next_t(g, k, t, beat, origin)
			var strikes: Array = []
			if bool(g.crush) and k == gk.size() - 1:
				var safe := Vector2i(rng.randi() % 3, rng.randi() % 3)
				var all: Array = []
				for y in range(3):
					for x in range(3):
						if Vector2i(x, y) != safe:
							all.append(Vector2i(x, y))
				strikes = [["all", all]]
			else:
				match kind:
					"d":
						strikes = [["row", line.call(true, rng.randi() % 3)], ["col", line.call(false, rng.randi() % 3)]]
					"h":
						var r1 := rng.randi() % 3
						strikes = [["row", line.call(true, r1)], ["row", line.call(true, r1)]]
					"s":
						var lr := rng.randf() < 0.5
						strikes = [["col", line.call(false, 0 if lr else 2)], ["col", line.call(false, 1)], ["col", line.call(false, 2 if lr else 0)]]
					"f":
						strikes = [["chase", []]]
					"x":
						strikes = [["cross", line.call(true, 1) + [Vector2i(1, 0), Vector2i(1, 2)]]]
					_:
						var key := prev
						var row := true
						var i := 0
						while key == prev:
							row = rng.randf() < 0.5
							i = rng.randi() % 3
							key = "%s%d" % ["r" if row else "c", i]
						prev = key
						strikes = [["row" if row else "col", line.call(row, i)]]
			for s in range(strikes.size()):
				if s > 0:
					t += half
				var note := {"pos": Vector2.ZERO, "at": t, "approach": ap, "kind": "dodge", "sub": String(strikes[s][0]), "tiles": strikes[s][1], "hold": 0.0, "num": 0}
				if String(strikes[s][0]) == "all":
					note.crush = true
				notes.append(note)
				ids.append(notes.size() - 1)
		groups.append(ids)
	return [notes, groups]


# 부름-응답: 같은 리듬(간격)으로 응답 노트만 둔다. 부름 소리·빛은 call초 앞에서 난다(P2NoteChart.arrange). 두 번 = 반 박 뒤 한 번 더
func _echo_notes(pat: Array, beat: float, ap: float, call: float) -> Array:
	var half := beat / 2.0
	var notes: Array = []
	var groups: Array = []
	var t := beat * 2.0 + call - beat
	var origin := t
	for g in pat:
		var ids: Array = []
		var gk: Array = g.kinds
		for k in range(gk.size()):
			t = _next_t(g, k, t, beat, origin)
			for s in range(2 if String(gk[k]) == "d" else 1):
				if s > 0:
					t += half
				var note := {"pos": Vector2.ZERO, "at": t, "approach": ap, "kind": "echo", "sub": "", "hold": 0.0, "num": 0}
				if bool(g.crush) and k == gk.size() - 1:
					note.crush = true
				notes.append(note)
				ids.append(notes.size() - 1)
		groups.append(ids)
	return [notes, groups]


const STAGE_C := Vector2(640, 560)
# 점검용: 모든 적의 장르를 하나로(빈 값이면 적 표대로)
static var genre_force := ""


func _arrow_center() -> Vector2:
	var p := _to_ui(_player_body())
	return Vector2(clampf(p.x + 30.0, 190.0, 560.0), clampf(p.y + 30.0, 230.0, 310.0))


# 노트 종류 → 화살: 도망 = 노랑(반대쪽으로 넘어옴, 구간 II부터) · 길게·따라가기 = 빠른 화살(구간 II부터) · 두 번 = 반 박 뒤 옆에서 한 발 더
func _arrow_styles(g: Dictionary, tier: int) -> Array:
	var out: Array = []
	for kind in g.kinds:
		match String(kind):
			"f":
				out.append(["rev" if tier >= 1 else "n"])
			"h", "s":
				out.append(["fast" if tier >= 1 else "n"])
			"d":
				out.append(["n", "n"])
			_:
				out.append(["n"])
	return out


static func _cell_dir(cell: Vector2i) -> int:
	if cell.x != 0 and absi(cell.x) >= absi(cell.y):
		return 1 if cell.x > 0 else 3
	if cell.y != 0:
		return 0 if cell.y < 0 else 2
	return 1


# 방향: 보스 문장은 칸 쪽(늘 같은 무늬), 그 밖은 첫 화살이 적 쪽(오른쪽)에서 오고 그 뒤로 옆으로 돌기 · 반대로 뒤집기 · 같은 쪽 한 번 더(세 번 연속은 없음)
func _arrow_notes(index: int, pat: Array, tier: int, beat: float, ap: float, call: float) -> Array:
	var half := beat / 2.0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([battle.seed_used, battle.turn_number, index, "arrows"])
	var notes: Array = []
	var groups: Array = []
	var t := beat * 2.0 + (call - beat if call > 0.0 else 0.0)
	var origin := t
	var last := -1
	var same := 0
	var prev_t := -99.0
	for g in pat:
		var ids: Array = []
		var styles := _arrow_styles(g, tier)
		var gk: Array = g.kinds
		for k in range(gk.size()):
			t = _next_t(g, k, t, beat, origin)
			var shots: Array = styles[k]
			# 박 칸 계획은 칸 자리마다 화살 하나(여러 발은 다음 칸과 겹친다)
			if g.has("beats"):
				shots = shots.slice(0, 1)
			var stream := _music != null and t - prev_t < beat * 0.6
			prev_t = t
			for s in range(shots.size()):
				if s > 0:
					t += half
				var dir := 1
				if not (g.cells as Array).is_empty() and s == 0:
					dir = _cell_dir(g.cells[k])
				elif last >= 0:
					var r := rng.randf()
					if r < 0.55 or s > 0:
						dir = (last + (1 if rng.randf() < 0.5 else 3)) % 4
					elif r < 0.8:
						dir = (last + 2) % 4
					else:
						dir = last
					if dir == last and same >= 1:
						dir = (last + 1) % 4
					# 세계 음악 전투의 연타는 한 방향에서 우르르
					if stream:
						dir = last
				same = same + 1 if dir == last else 0
				last = dir
				var note := {"pos": Vector2.ZERO, "at": t, "approach": ap * (0.62 if String(shots[s]) == "fast" else 1.0), "kind": "a",
					"lane": dir, "arrow": String(shots[s]), "sub": String(shots[s]), "hold": 0.0, "num": 0}
				if bool(g.crush) and k == gk.size() - 1 and s == shots.size() - 1:
					note.crush = true
				notes.append(note)
				ids.append(notes.size() - 1)
		groups.append(ids)
	return [notes, groups]


# 악보를 전장 가운데 넓은 판(5열 × 3행 격자)에 박자 맞춰 놓는다. 첫 노트는 두 박 뒤(그 앞은 반주로 세기).
# 문장은 먼저 같은 리듬을 빛·음으로 들려준 뒤(부름) 따라 친다. 악보는 화면 층(체력 막대 위, 카메라 흔들림과 무관)에 둔다
func _parry_chart(index: int, hits: Array, simple := false) -> P2NoteChart:
	var pat := _parry_pattern(index, hits, simple)
	var tier := _parry_tier(index)
	# 더블타임: 악보 전체가 25% 빠름. 난이도는 고리가 줄어드는 시간(노트 속도)만 바꾼다
	var beat := _music.beat if _music != null else 60.0 / float(PARRY_BPM[tier]) * (0.8 if battle.mods.has("dt") else 1.0)
	var half := beat / 2.0
	var ap := beat * 1.2 * _approach_k * battle.approach_mult * (P2Catalog.AFFIX_SWIFT if battle.affix(index) == "swift" else 1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([battle.seed_used, battle.turn_number, index, "spots"])
	var home_x := float(_enemy_sprites[index].get_meta("home_x", _enemy_sprites[index].position.x))
	var c := Vector2(clampf((_to_ui(_player_body()).x + home_x) / 2.0, 560.0, 700.0), 250.0)
	var area := Rect2(c - CELL * Vector2(2, 1) - Vector2(10, 10), CELL * Vector2(4, 2) + Vector2(20, 20))
	var phrase := String(pat[0].phrase)
	var span := 0.0
	for g in pat:
		for q in g.gaps:
			span += int(q) * half
	var call := span + beat * 3.0 if phrase != "" else 0.0
	var genre := _genre_of(index)
	if genre == "echo":
		call = span + beat * 3.0
	var notes: Array = []
	var groups: Array = []
	var multi := pat.size() > 1 or (pat[0].kinds as Array).size() > 1
	var t := beat * 2.0 + (call - beat if phrase != "" else 0.0)
	var origin := t
	var last := Vector2i(99, 99)
	var prev_t := -99.0
	var prev_pos := Vector2.ZERO
	var flow := Vector2.ZERO
	var recent: Array = []
	var fresh: Array = []
	var alt := genre != "osu"
	if alt:
		var made := _genre_notes(genre, index, pat, tier, beat, ap, call)
		notes = made[0]
		groups = made[1]
		for key in [genre, "rev", "roll", "chase", "crush"]:
			if not _seen_notes.has(key) and (key == genre or notes.any(func(q): return String(q.get("sub", "")) == key or (key == "crush" and bool(q.get("crush", false))))):
				fresh.append(key)
				_seen_notes[key] = true
	else:
		for g in pat:
			var ids: Array = []
			for k in range((g.kinds as Array).size()):
				var kind := String(g.kinds[k])
				t = _next_t(g, k, t, beat, origin)
				var cell := Vector2i(0, 0)
				if not (g.cells as Array).is_empty():
					cell = g.cells[k]
				else:
					# 앞 노트에서 한두 칸 떨어진 자리(너무 멀거나 겹치지 않게)
					for tries in range(20):
						cell = Vector2i(rng.randi_range(-2, 2), rng.randi_range(-1, 1))
						var d := absi(cell.x - last.x) + absi(cell.y - last.y)
						if last.x == 99 or (d >= 1 and d <= 3 and not recent.has(cell)):
							break
				var pos := c + Vector2(cell) * CELL
				# 세계 음악 전투의 연타(반 박보다 촘촘)는 멀리 흩지 않고 앞 노트 곁에 겹쳐 이어 붙인다(완만하게 휘는 줄)
				if _music != null and t - prev_t < beat * 0.6:
					if flow == Vector2.ZERO:
						flow = (c - prev_pos).normalized().rotated(rng.randf_range(-1.2, 1.2)) if prev_pos.distance_to(c) > 1.0 else Vector2.RIGHT
					flow = flow.rotated(rng.randf_range(-0.3, 0.3))
					var np := prev_pos + flow * NOTE_R * 0.95
					if not area.grow(-NOTE_R * 0.6).has_point(np):
						flow = (c - prev_pos).normalized().rotated(rng.randf_range(-0.5, 0.5))
						np = prev_pos + flow * NOTE_R * 0.95
					pos = np
					cell = Vector2i(clampi(roundi((pos.x - c.x) / CELL.x), -2, 2), clampi(roundi((pos.y - c.y) / CELL.y), -1, 1))
				else:
					flow = Vector2.ZERO
				prev_t = t
				prev_pos = pos
				last = cell
				recent.append(cell)
				if recent.size() > 3:
					recent.pop_front()
				var note := {"pos": pos, "at": t, "approach": ap * (1.6 if kind == "f" else 1.0), "kind": kind, "hold": 0.0, "num": notes.size() + 1 if multi else 0}
				if battle.is_spawn_slot(index) or String(battle.roles[index]) == "maek_spawn_low":
					note.bomb = true
					if not _seen_notes.has("bomb"):
						fresh.append("bomb")
						_seen_notes["bomb"] = true
				if kind == "h" or kind == "s":
					note.hold = (beat * 1.5 if tier >= 2 else beat)
				if kind == "s":
					var dx := CELL.x if cell.x <= 0 else -CELL.x
					note.to = pos + Vector2(dx, 0)
				if bool(g.crush) and k == (g.kinds as Array).size() - 1:
					note.crush = true
				notes.append(note)
				ids.append(notes.size() - 1)
				if not _seen_notes.has(kind) and kind != "t":
					fresh.append(kind)
					_seen_notes[kind] = true
				if note.has("crush") and not _seen_notes.has("crush"):
					fresh.append("crush")
					_seen_notes["crush"] = true
				t += float(note.hold)
				if kind == "d":
					t += ceilf(P2NoteChart.DOUBLE_WIN / half) * half - half
			groups.append(ids)
	if phrase != "":
		var key := battle.roles[index] + phrase
		_phrase_seen[key] = int(_phrase_seen.get(key, 0)) + 1
	# 미러: 노트 자리를 악보 가운데 기준으로 좌우 뒤집기
	if battle.mods.has("mr"):
		for nt in notes:
			if genre == "arrow":
				nt.lane = [0, 3, 2, 1][int(nt.lane)]
			elif genre == "dodge":
				nt.tiles = (nt.tiles as Array).map(func(v): return Vector2i(2 - v.x, v.y))
			nt.pos = Vector2(2.0 * c.x - (nt.pos as Vector2).x, (nt.pos as Vector2).y)
			if nt.has("to"):
				nt.to = Vector2(2.0 * c.x - (nt.to as Vector2).x, (nt.to as Vector2).y)
	var chart := P2NoteChart.new()
	# 고리 말고는 모두 화면 아래 가운데 같은 무대(적 차례엔 손패를 내려 숨긴다). 조이기·결과 한 줄은 전장 쪽(c)으로
	match genre:
		"arrow":
			var ac := P2ArrowChart.new()
			ac.center = STAGE_C + Vector2(0, 12)
			chart = ac
		"dodge":
			var dc := P2DodgeChart.new()
			dc.center = STAGE_C + Vector2(0, -12)
			chart = dc
		"drum":
			var dr := P2DrumChart.new()
			dr.judge_x = 340.0
			dr.lane_y = STAGE_C.y
			dr.spawn_x = 1030.0
			chart = dr
		"echo":
			var ec := P2EchoChart.new()
			ec.lane_y = STAGE_C.y
			ec.show_ghost = battle.judge_mult >= 1.3
			chart = ec
	if alt:
		c = Vector2(640, 300)
	chart.set_meta("enemy", index)
	chart.setup(notes, NOTE_R, _ui_tex("status_shield", 4), battle.get_pending_defense() > 0)
	chart.bounds = area
	# 입문 판정 × 난이도·하드록 판정 (너무 넓거나 좁지 않게)
	chart.ease(clampf(_ease_k() * battle.judge_mult * (1.5 if _music != null else 1.0), 0.5, 2.2))
	chart.hidden_mod = battle.mods.has("hd")
	chart.beat = beat
	chart.call = call
	chart.arrange()
	chart.set_meta("groups", groups)
	chart.set_meta("got", {})
	chart.judged.connect(_on_note_judged.bind(chart))
	_wire_chart(chart)
	if _music != null:
		# 첫 노트는 음악의 반 마디 칸에(붉은 예고가 끝난 뒤), 그 한 박 전에 이 적 세계의 필인
		var world := P2Music.world_of(battle.roles[index])
		var first := beat * 2.0
		if not notes.is_empty():
			first = float(notes[0].at)
			for nt in notes:
				first = minf(first, float(nt.at))
		# 박 칸 계획이면 첫 노트가 마디 첫 박이 아닐 수 있다(엇박 칸): 마디 첫 박을 음악 마디에 맞춘다
		if (pat[0] as Dictionary).has("beats"):
			first -= float(pat[0].beats[0]) * beat
		var at := _music.entry(0.6 + beat)
		chart.follow(_music.clock, at - first)
		chart.set_meta("world", world)
		var phrases: Array = []
		for gr in groups:
			var by_bar := {}
			for x in gr:
				var bi := floori((float(notes[int(x)].at) - first) / (beat * 4.0) + 0.001)
				if not by_bar.has(bi):
					by_bar[bi] = []
				(by_bar[bi] as Array).append(x)
			var keys := by_bar.keys()
			keys.sort()
			for bi in keys:
				phrases.append(by_bar[bi])
		chart.set_meta("semis", _music.pitches(world, phrases, notes.size()))
		_music.enemy(world, at)
		chart.cue.connect(_on_music_cue)
	else:
		chart.cue.connect(_on_cue)
	chart.set_meta("center", c)
	_ui.add_child(chart)
	var again := ""
	for n in notes:
		var kd := String(n.kind)
		if int(_miss_kind.get(kd, 0)) >= 2 and not _hint_again.has(kd) and NOTE_HINT.has(kd):
			again = kd
	if again != "":
		_hint_again[again] = true
		_set_prompt(tr("다시: ") + tr(String(NOTE_HINT[again])))
	elif phrase != "":
		_set_prompt(tr("「%s」 — 먼저 보고 따라 막기") % phrase if genre in ["arrow", "dodge"] else tr("「%s」 — 먼저 듣고 따라 치기") % phrase)
	elif not fresh.is_empty():
		_set_prompt(tr(String(NOTE_HINT[fresh[0]])))
	elif parry_log.size() < 3 and not alt:
		_set_prompt(tr("마우스로 겨누고") + "\n" + tr("고리가 닿을 때 아무 키·클릭"))
	return chart


# 적 공격이 뜨기 전에 뜰 자리를 붉게 깜빡여 눈을 먼저 보낸다(고리 = 가운데 위, 다른 장르 = 아래 무대).
# 장르가 바뀌거나 오랜만이면 길게, 같은 자리가 이어지면 짧게
const GENRE_NAME := {"osu": "고리 막기", "arrow": "화살 막기", "drum": "북 장단", "dodge": "박자 피하기", "echo": "따라 치기"}
const C_CUE := Color("#ff4a3a")
var _cue_last := {"genre": "", "ms": -99999}
var cue_log: Array = []


func _zone_cue(chart: P2NoteChart) -> void:
	var genre := _genre_of(int(chart.get_meta("enemy", 0)))
	var now := Time.get_ticks_msec()
	var long := genre != String(_cue_last.genre) or now - int(_cue_last.ms) > 4000
	var dur := 0.6 if long else 0.3
	chart.visible = false
	chart.process_mode = Node.PROCESS_MODE_DISABLED
	var r := chart.cue_rect().grow(6.0)
	var title := "! " + tr(String(GENRE_NAME.get(genre, "막기")))
	var font := P2Ui.pixel_font(P2Ui.T_BODY)
	var cue := Node2D.new()
	cue.draw.connect(func() -> void:
		var t := (Time.get_ticks_msec() - now) / 1000.0
		var on := 1.0 if _reduce_motion or fmod(t, 0.2) < 0.13 else 0.25
		cue.draw_rect(r, Color(C_CUE, 0.12 * on))
		cue.draw_rect(r.grow(3.0), Color(0.04, 0.03, 0.05, 0.6 * on), false, 2.0)
		cue.draw_rect(r, Color(C_CUE, on), false, 4.0)
		var arm := minf(28.0, minf(r.size.x, r.size.y) * 0.3)
		for k in [[r.position, Vector2(1, 1)], [Vector2(r.end.x, r.position.y), Vector2(-1, 1)], [r.end, Vector2(-1, -1)], [Vector2(r.position.x, r.end.y), Vector2(1, -1)]]:
			var p: Vector2 = k[0]
			var d: Vector2 = k[1]
			cue.draw_line(p, p + Vector2(d.x * arm, 0), Color(1, 0.9, 0.85, on), 6.0)
			cue.draw_line(p, p + Vector2(0, d.y * arm), Color(1, 0.9, 0.85, on), 6.0)
		var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, P2Ui.T_BODY).x
		var tab := Rect2(r.position.x + r.size.x / 2.0 - tw / 2.0 - 12.0, r.position.y - 34.0, tw + 24.0, 30.0)
		if tab.position.y < 4.0:
			tab.position.y = r.end.y + 4.0
		cue.draw_rect(tab, Color(0.16, 0.03, 0.02, 0.92))
		cue.draw_rect(tab, Color(C_CUE, on), false, 2.0)
		cue.draw_string_outline(font, tab.position + Vector2(12, 22), title, HORIZONTAL_ALIGNMENT_LEFT, -1, P2Ui.T_BODY, 4, Color(0.04, 0.03, 0.05))
		cue.draw_string(font, tab.position + Vector2(12, 22), title, HORIZONTAL_ALIGNMENT_LEFT, -1, P2Ui.T_BODY, Color(1, 0.86, 0.8)))
	_ui.add_child(cue)
	var tick := func() -> void: cue.queue_redraw()
	get_tree().process_frame.connect(tick)
	_sfx("prepare", 1.35 if long else 1.6, -2.0 if long else -6.0)
	cue_log.append({"genre": genre, "rect": r, "long": long, "ms": now})
	await _wait(dur)
	get_tree().process_frame.disconnect(tick)
	cue.queue_free()
	_cue_last = {"genre": genre, "ms": Time.get_ticks_msec()}
	if is_instance_valid(chart):
		chart.visible = true
		chart.process_mode = Node.PROCESS_MODE_INHERIT


# 반주 한 박: 연속에 따라 층이 쌓인다(Metal: Hellsinger식) — 5 베이스 · 10 종소리 선율 · 20 스네어. 끊기면 다음 박부터 걷힘.
# 킥마다 화면 가장자리·주인공·맥 숫자가 살짝 뛴다(배경과 다른 적은 시간이 멈춘 주변이라 뛰지 않음)
func _on_cue(key: String, step: int, vol: float) -> void:
	var st := int(_rs.streak)
	if _beat != null and not (_music != null and key == "kick"):
		_beat.play(key, step, vol)
		if key == "kick":
			_beat_n += 1
			if st >= 5:
				_beat.play("bass", [0, 0, 7, 5][_beat_n % 4], -3.0)
			if st >= 20:
				_beat.play("snare", 0, -10.0)
		elif key == "hat" and st >= 10:
			_beat.play("chime", [0, 2, 4, 2, 5, 4, 2, 4][_beat_n % 8], -15.0)
	if key == "kick":
		_vig.pulse = 1.0
		_pp_pulse = 1.0
		if _mana_label != null and not _reduce_motion:
			_mana_label.pivot_offset = _mana_label.size / 2.0
			_mana_label.scale = Vector2.ONE * 1.1
			_mana_label.create_tween().tween_property(_mana_label, "scale", Vector2.ONE, 0.18).set_ease(Tween.EASE_OUT)


func _on_music_cue(key: String, step: int, vol: float) -> void:
	if key == "kick":
		_on_cue(key, step, vol)
	elif key != "hat" and key != "snare" and _beat != null:
		_beat.play(key, step, vol)


func _wire_chart(chart: P2NoteChart) -> void:
	chart.timing.connect(func(d: float, g: String) -> void:
		_hitbar_node().add(d, g)
		_note_offset(d, g, chart.has_meta("practice")))
	chart.held.connect(func(id: Variant, down: bool, label: String) -> void: _keys_node().press(id, down, label))
	_hitbar_node().set_windows(chart.perfect_early, chart.perfect_late, chart.good_early, chart.good_late)
	_hitbar_node().beat_src = chart if chart.beat > 0.0 else null
	_open_rhythm(chart, not (chart is P2ArrowChart or chart is P2DodgeChart))


# 누른 순간의 오차를 모은다(놓침 제외). 최근 40번은 보정 맞춤용(연습 악보 포함), 이번 전투 것은 결과 판용
func _note_offset(d: float, g: String, practice: bool) -> void:
	if g == "miss":
		return
	recent_offsets.append(d)
	if recent_offsets.size() > 40:
		recent_offsets.pop_front()
	if not practice:
		(_rs.offs as Array).append(d)


# 판정 보정을 모은 오차의 가운데 값만큼 옮긴다(늘 늦게 누르면 판정 순간이 그만큼 뒤로)
func _calibrate(ds: Array) -> int:
	if ds.is_empty():
		return roundi(P2NoteChart.offset * 1000.0)
	var v := ds.duplicate()
	v.sort()
	return _set_offset_ms(roundi((P2NoteChart.offset + float(v[v.size() / 2])) * 1000.0))


func _set_offset_ms(ms: int) -> int:
	ms = clampi(ms, -80, 80)
	P2NoteChart.offset = ms / 1000.0
	recent_offsets.clear()
	P2Ui.save_rhythm({"offset_ms": ms})
	return ms


# 입문 판정: 첫 원정의 1·2번째 전투는 판정 창 1.5배, 3·4번째는 1.25배, 그 뒤는 원래대로. 설정 없음
func _ease_k() -> float:
	if ease_force > 0.0:
		return ease_force
	var exps := int((GameState.combat.get("stats", {}) as Dictionary).get("expeditions", 0))
	if battle.source != "expedition":
		return 1.5 if exps == 0 else 1.0
	if exps > 1 or model == null:
		return 1.0
	var n := int(model.run.get("battles", 99))
	return 1.5 if n <= 2 else (1.25 if n <= 4 else 1.0)


func _keys_node() -> P2KeyOverlay:
	if _keys == null:
		_keys = P2KeyOverlay.new()
		_ui.add_child(_keys)
		_ui.move_child(_keys, _overlay.get_index())
		var below := _seal_label.position.y if _seal_label != null else 594.0
		_keys.position = Vector2(1070, below - _keys.size.y - 4)
	return _keys


func _hitbar_node() -> P2HitBar:
	if _hitbar == null:
		_hitbar = P2HitBar.new()
		_hitbar.position = Vector2(640 - 160, 430)
		_ui.add_child(_hitbar)
		_ui.move_child(_hitbar, _overlay.get_index())
	return _hitbar


# 악보·긋기가 떠 있는 동안: 키 표시(둘 다)·판정 오차 막대(악보만)를 켜고 배경음악을 낮춘다. 마지막 것이 닫히면 0.3초 뒤 걷는다
func _open_rhythm(node: Node, chart: bool) -> void:
	_rhythm_open += 1
	_keys_node().on = node is P2SlashPad or _plain_chart(node)
	# 아래 무대가 뜨면 손패를 화면 밖으로 내린다(다음 내 차례에 손패를 다시 만들며 제자리로)
	if node is P2NoteChart and not _plain_chart(node):
		if _fold_tw != null and _fold_tw.is_valid():
			_fold_tw.kill()
		_hand_root.position.y = 330.0
		if _hand_rail != null:
			_hand_rail.modulate.a = 0.0
	if chart:
		_hitbar_node().position.y = 430.0 if _plain_chart(node) else 678.0
		_hitbar_node().on = true
		_fade_intents(0.18)
	_music_duck(true)
	node.tree_exited.connect(func() -> void:
		_rhythm_open -= 1
		if _rhythm_open <= 0 and is_inside_tree():
			get_tree().create_timer(0.3).timeout.connect(_close_rhythm))


# 메뉴의 리듬(시험판) 칸: 누르기 키 · 판정 보정(−/+ 5ms, 맞춤 = 최근 누름의 가운데 값) · 노트 속도 · 연습 악보
func _menu_rhythm(p: Control, y: float) -> float:
	var kb := _button("", Vector2(20, y), Vector2(232, 40), F)
	var keys_text := func() -> String: return tr("키: ") + tr(P2Ui.keys_label(String(P2Ui.load_rhythm().keys)))
	kb.text = keys_text.call()
	kb.tooltip_text = tr("아무 키 → Z·X → 지정한 두 키 순서로 바뀝니다")
	kb.set_meta("keys_cycle", true)
	kb.pressed.connect(func() -> void:
		var rh := P2Ui.load_rhythm()
		var order: Array = ["any", "zx"] + ([String(rh.keys_custom)] if String(rh.keys_custom) != "" else [])
		var i := order.find(String(rh.keys))
		var nxt := String(order[(i + 1) % order.size()])
		P2Ui.save_rhythm({"keys": nxt})
		P2NoteChart.hit_keys = P2Ui.hit_keys_of(nxt)
		kb.text = keys_text.call())
	p.add_child(kb)
	var pick := _button(tr("지정"), Vector2(258, y), Vector2(66, 40), F)
	pick.tooltip_text = tr("누를 키 두 개를 차례로 누르세요 (Esc 취소)")
	pick.set_meta("keys_pick", true)
	pick.pressed.connect(func() -> void:
		_key_capture = []
		_key_capture_on = true
		_key_capture_labels = [kb, pick]
		kb.text = tr("첫 번째 키를 누르세요"))
	p.add_child(pick)
	y += 48
	var minus := _button("−", Vector2(20, y), Vector2(40, 40), F)
	var plus := _button("+", Vector2(216, y), Vector2(40, 40), F)
	var auto := _button(tr("맞춤"), Vector2(260, y), Vector2(64, 40), F)
	var ol := _label("", F, C_TEXT)
	ol.position = Vector2(62, y)
	ol.size = Vector2(152, 40)
	ol.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ol.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ol.set_meta("offset_label", true)
	var refresh_off := func() -> void:
		ol.text = tr("판정 보정 %+dms") % roundi(P2NoteChart.offset * 1000.0)
		auto.disabled = recent_offsets.size() < 8
		auto.tooltip_text = (tr("최근 %d번 누름의 가운데 값으로 맞춥니다") % recent_offsets.size()) if recent_offsets.size() >= 8 else tr("누름이 8번 넘게 쌓이면(연습 악보도 됨) 거기에 맞출 수 있습니다")
	refresh_off.call()
	minus.pressed.connect(func() -> void:
		_set_offset_ms(roundi(P2NoteChart.offset * 1000.0) - 5)
		refresh_off.call())
	plus.pressed.connect(func() -> void:
		_set_offset_ms(roundi(P2NoteChart.offset * 1000.0) + 5)
		refresh_off.call())
	auto.pressed.connect(func() -> void:
		_calibrate(recent_offsets)
		refresh_off.call())
	minus.tooltip_text = tr("일찍 누르는 편이면 −")
	plus.tooltip_text = tr("늦게 누르는 편이면 +")
	for n in [minus, ol, plus, auto]:
		p.add_child(n)
	y += 48
	var speeds := [[1.3, "느리게"], [1.0, "보통"], [0.8, "빠르게"]]
	var sb := _button("", Vector2(20, y), Vector2(304, 40), F)
	var speed_text := func() -> String:
		var nm := "보통"
		for q in speeds:
			if absf(float(q[0]) - _approach_k) < 0.01:
				nm = String(q[1])
		return tr("노트 속도: ") + tr(nm)
	sb.text = speed_text.call()
	sb.tooltip_text = tr("느리게 = 고리가 더 일찍 나타나 천천히 줄어듦 (판정 창은 같음)")
	sb.pressed.connect(func() -> void:
		var i := 1
		for k in range(speeds.size()):
			if absf(float(speeds[k][0]) - _approach_k) < 0.01:
				i = k
		_approach_k = float(speeds[(i + 1) % speeds.size()][0])
		P2Ui.save_rhythm({"approach": _approach_k})
		sb.text = speed_text.call())
	p.add_child(sb)
	y += 48
	var bv := _button("", Vector2(20, y), Vector2(304, 40), F)
	var beat_text := func() -> String: return tr("반주 음량: %d%%") % roundi(P2Beat.gain * 100.0)
	bv.text = beat_text.call()
	bv.tooltip_text = tr("악보 반주(킥·하이햇)와 맞힐 때 나는 소리. 효과음·배경음악과 따로")
	bv.pressed.connect(func() -> void:
		var steps := [1.0, 0.75, 0.5, 0.25, 0.0]
		var i := 0
		for k in range(steps.size()):
			if absf(float(steps[k]) - P2Beat.gain) < 0.01:
				i = k
		P2Beat.gain = float(steps[(i + 1) % steps.size()])
		P2Ui.save_rhythm({"beat": P2Beat.gain})
		bv.text = beat_text.call()
		if _beat != null:
			_beat.play("chime", 4))
	p.add_child(bv)
	y += 48
	var pr := _button(tr("연습 악보 (피해 없음)"), Vector2(20, y), Vector2(304, 40), F)
	pr.disabled = _state != UI.PLAYER
	pr.pressed.connect(practice)
	p.add_child(pr)
	return y + 48


func _close_rhythm() -> void:
	if _rhythm_open > 0 or not is_inside_tree():
		return
	if _keys != null:
		_keys.on = false
	if _hitbar != null:
		_hitbar.on = false
	_fade_intents(1.0)
	_music_duck(false)


# 악보 동안 적 머리 위 예고 칸을 흐리게(위 줄 노트가 덮지 않게), 끝나면 되돌림
func _fade_intents(a: float) -> void:
	for p in _enemy_panels:
		var it: Control = p.intent
		if is_instance_valid(it):
			it.create_tween().tween_property(it, "modulate:a", a, 0.2)


# 배경음악을 낮추고 먹먹하게(저역 통과) 해 박자 반주가 앞에 서게 한다. 음악 버스에 효과 두 개를 이 전투 동안만 끼운다(음량 설정은 그대로)
func _music_duck(on: bool) -> void:
	var bus := AudioServer.get_bus_index(MusicManager.MUSIC_BUS_NAME)
	if bus < 0 or not is_inside_tree() or _music != null:
		return
	if _duck_lp == null:
		_duck_lp = AudioEffectLowPassFilter.new()
		_duck_lp.cutoff_hz = 20000.0
		_duck_lp.db = AudioEffectFilter.FILTER_12DB
		_duck_amp = AudioEffectAmplify.new()
		AudioServer.add_bus_effect(bus, _duck_lp)
		AudioServer.add_bus_effect(bus, _duck_amp)
	if _duck_tw != null and _duck_tw.is_valid():
		_duck_tw.kill()
	var dur := 0.35 if on else 0.6
	_duck_tw = create_tween().set_parallel()
	_duck_tw.tween_method(func(x: float) -> void: _duck_lp.cutoff_hz = pow(2.0, x), log(_duck_lp.cutoff_hz) / log(2.0), log(900.0 if on else 20000.0) / log(2.0), dur)
	_duck_tw.tween_property(_duck_amp, "volume_db", -9.0 if on else 0.0, dur)


func _unduck_bus() -> void:
	if _duck_lp == null:
		return
	var bus := AudioServer.get_bus_index(MusicManager.MUSIC_BUS_NAME)
	if bus >= 0:
		for i in range(AudioServer.get_bus_effect_count(bus) - 1, -1, -1):
			var e := AudioServer.get_bus_effect(bus, i)
			if e == _duck_lp or e == _duck_amp:
				AudioServer.remove_bus_effect(bus, i)
	_duck_lp = null
	_duck_amp = null


func _combo_hit(ok: bool) -> void:
	var before := int(_rs.streak)
	_rs.streak = int(_rs.streak) + 1 if ok else 0
	_rs.best = maxi(int(_rs.best), int(_rs.streak))
	# 연속 회복: 5마다 체력 +1 (한 전투 최대 +5, 규칙은 전투 모델)
	if ok and int(_rs.streak) % 5 == 0 and battle != null:
		var got := battle.combo_heal()
		if got > 0:
			_shown.hp = mini(int(_shown.hp) + got, int(GameState.get_flag("player_max_hp")))
			_render_hud()
			_float_number(tr("연속 회복 +%d") % got, _player_body() + Vector2(0, -96), Color("#8be08b"), F, 26.0, 0.9)
			_sfx("heal", 1.25, -6.0)
			if _combo != null:
				_combo.healed()
	if _music != null:
		# 겹이 꺼지거나 돌아오는 순간을 연속 숫자 곁에 짧게
		var ch := _music.combo(ok, before, int(_rs.streak))
		if ch.has("cut"):
			_float_number(tr("♪ %s 꺼짐") % String(ch.cut), _player_body() + Vector2(-30, -150), Color("#e58b97"), F, 22.0, 0.9)
		elif ch.has("back"):
			_float_number(tr("♪ %s 돌아옴") % String(ch.back), _player_body() + Vector2(-30, -150), C_GOLD, F, 22.0, 0.9)
	if not _juice:
		return
	if _combo == null:
		_combo = P2Combo.new()
		_combo.position = Vector2(4, 360)
		_ui.add_child(_combo)
		_ui.move_child(_combo, _overlay.get_index())
	if ok:
		_combo.add()
		if _combo.count % 5 == 0 and _beat != null and _music == null:
			_beat.play("chime", 7, 2.0)
		if _combo.count % 10 == 0:
			_combo_burst(_combo.count)
	else:
		_combo.reset()


# 연속 10 · 20 · 30…: 화면 가장자리 금빛 테두리(20부터 주황·더 진하게)와 전장 색 분리 펄스. 악보(화면 층)는 그대로 또렷
func _combo_burst(n: int) -> void:
	if _edge == null:
		_edge = ColorRect.new()
		_edge.set_anchors_preset(Control.PRESET_FULL_RECT)
		_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var m := ShaderMaterial.new()
		m.shader = load("res://p2/p2_edge_glow.gdshader")
		_edge.material = m
		_ui.add_child(_edge)
		_ui.move_child(_edge, 0)
	var m := _edge.material as ShaderMaterial
	m.set_shader_parameter("tint", Color("#ffcf4a") if n < 20 else Color("#ff9a3a"))
	var peak := 0.75 if n < 20 else 1.0
	var t := _edge.create_tween()
	t.tween_method(func(x: float) -> void: m.set_shader_parameter("amount", x), peak, 0.0, 0.5).set_ease(Tween.EASE_OUT)
	if _av7_on():
		_av7_fx.center = Vector2(640, 300)
		var tw := create_tween()
		tw.tween_method(func(x: float) -> void: _av7_set("chroma_px", x), 2.6 if n < 20 else 3.6, 0.0, 0.3).set_ease(Tween.EASE_OUT)
	final_log.append({"combo": n, "ms": Time.get_ticks_msec()})


func _on_note_judged(i: int, grade: String, dt: float, chart: P2NoteChart) -> void:
	(chart.get_meta("got") as Dictionary)[i] = grade
	var key := String({"perfect": "p", "good": "g"}.get(grade, "m"))
	_rs[key] = int(_rs[key]) + 1
	_combo_hit(grade != "miss")
	var kind := String(chart.notes[i].kind)
	if grade == "miss" and kind != "x":
		_miss_kind[kind] = int(_miss_kind.get(kind, 0)) + 1
	if _music != null and chart.has_meta("world"):
		var semis: Array = chart.get_meta("semis", [])
		if kind != "x" or grade == "miss":
			_music.tone(String(chart.get_meta("world")), int(semis[i]) if i < semis.size() else 0, grade, chart.t0 + float(chart.notes[i].at))
	elif _beat != null:
		if grade == "perfect":
			_beat.play("chime", i)
		elif grade == "good":
			_beat.play("stick")
		elif kind != "x":
			_beat.play("thud")
	parry_log.append({"grade": grade, "dt": snappedf(dt, 0.001), "ms": Time.get_ticks_msec(), "kind": kind})
	var at: Vector2 = chart.notes[i].to if kind == "s" else chart.notes[i].pos
	if kind == "x":
		if grade == "perfect":
			_sfx("swing", 1.5, -4.0)
		else:
			_sfx("deny", 1.0)
		return
	# 세계 음악 전투에서는 막음도 완벽과 같은 손맛(파랑 불꽃만 다름)
	match "perfect" if grade == "good" and _music != null else grade:
		"perfect":
			_pp_pose(Vector2(0.95, 1.05), 7.0, 0.04, 0.04, 0.2)
			_sfx("crit_ring", 1.15)
			_sfx("block", 1.3)
			_actor_flash(_player, Color.WHITE, 0.35, 0.02, 0.08)
			if _juice:
				_sparks(at, Vector2.RIGHT, 1.1, 10, [C_BLOCK if grade == "good" else C_CRIT, Color.WHITE], true)
		"good":
			_sfx("block", 1.05)
			if _juice:
				_sparks(at, Vector2.RIGHT, 1.0, 5, [C_BLOCK, Color.WHITE], true)


# 악보의 i번 노트가 flight초 남을 때까지 (원거리·주술은 그때 놓아 닫힐 때 닿게)
func _chart_until(chart: P2NoteChart, i: int, flight: float) -> void:
	while is_instance_valid(chart) and chart.time_until(i) > flight and is_inside_tree():
		await get_tree().process_frame


# 동작 그림이 없는 적(SD·옛 그림): 뒤로 젖혔다가 닿는 순간 앞으로
func _lean(sprite: Node2D, back: bool, t: float) -> void:
	if _reduce_motion:
		return
	var base: Vector2 = sprite.get_meta("base_scale", sprite.scale)
	sprite.set_meta("base_scale", base)
	var s0 := sprite.scale / base
	var r0 := sprite.rotation_degrees
	var tw := create_tween()
	if back:
		# 뒤로 젖히며 웅크림(힘 모으기)
		tw.tween_method(func(u: float) -> void: _set_squash(sprite, base, s0.lerp(Vector2(1.07, 0.93), u), lerpf(r0, 8.0, u)),
			0.0, 1.0, clampf(t * 0.5, 0.08, 0.25)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		# 닿는 순간 앞으로 늘어나며 찌르고, 튕기듯 제자리
		tw.tween_method(func(u: float) -> void: _set_squash(sprite, base, s0.lerp(Vector2(0.9, 1.1), u), lerpf(r0, -11.0, u)), 0.0, 1.0, 0.05)
		tw.tween_method(func(u: float) -> void: _set_squash(sprite, base, Vector2(0.9, 1.1).lerp(Vector2.ONE, u), lerpf(-11.0, 0.0, u)),
			0.0, 1.0, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# SD 적 달리기: 그림이 한 장이라 미끄러지지 않게 깡충깡충 뛰며 앞으로 숙인다(돌진 시간 동안)
func _sd_hop(sprite: Node2D, dur: float, forward := true) -> void:
	if _reduce_motion or not String(sprite.get_meta("art", "")).begins_with("sd:"):
		return
	var y0 := sprite.position.y
	var base: Vector2 = sprite.get_meta("base_scale", sprite.scale)
	sprite.set_meta("base_scale", base)
	var hops := maxf(2.0, roundf(dur * 6.0))
	var lean := -7.0 if forward else 5.0
	var tw := create_tween()
	tw.tween_method(func(u: float) -> void:
		var ph := absf(sin(u * PI * hops))
		sprite.position.y = y0 - ph * 10.0 * (1.0 - u * 0.5)
		_set_squash(sprite, base, Vector2(1.0 - 0.05 * ph, 1.0 + 0.06 * ph), lean * (1.0 - u * u)), 0.0, 1.0, maxf(dur, 0.08))
	tw.tween_callback(func() -> void:
		sprite.position.y = y0)


# 다음 노트 전에 다시 들어 올린다(동작 그림: 준비 자세, 없으면 뒤로 젖힘)
func _strike_raise(sprite: AnimatedSprite2D, t_left: float) -> void:
	var atk := String(sprite.get_meta("atk", "attack"))
	var acts := _art_acts(sprite) and sprite.sprite_frames.has_animation(atk)
	if acts and not bool(sprite.get_meta("dying", false)):
		_art_claim(sprite)
		sprite.set_meta("art_busy", true)
		_art_pose(sprite, atk, 1)
	elif not acts:
		_lean(sprite, true, t_left)


func _strike_contact(sprite: AnimatedSprite2D) -> void:
	if _art_winding(sprite):
		_art_contact(sprite)
	elif _spawn_winding(sprite):
		_spawn_contact(sprite)
	elif not _art_acts(sprite):
		_lean(sprite, false, 0.0)


# 묶음 판정: 다 완벽이면 완벽(피해 0, 강타는 절반만), 아니면 노트 점수(완벽 1 · 막음 0.5) 평균의 절반만큼 줄임
func _group_grade(grades: Array, crush := false) -> Dictionary:
	if grades.all(func(g): return g == "perfect"):
		return {"grade": "good", "frac": 0.5} if crush else {"grade": "perfect", "frac": 1.0}
	var score := 0.0
	for g in grades:
		score += 1.0 if g == "perfect" else (0.5 if g == "good" else 0.0)
	var frac := 0.5 * score / grades.size()
	return {"grade": "good" if frac > 0.0 else "miss", "frac": frac}


# 세계 음악 전투의 묶음 판정(노트가 많으니 너그럽게): 놓친 노트가 없으면 다 막는다(막음도 완벽과 같은 대우, 강타는 절반).
# 완벽 보상(필살기 · 철벽 박자 등)은 85% 넘게 완벽일 때만. 놓친 게 있으면 막은 몫을 0.85로 나눈 만큼(최대 95%)
func _cell_grade(grades: Array, crush := false) -> Dictionary:
	var score := 0.0
	var perfect := 0
	for g in grades:
		score += 1.0 if g == "perfect" else (0.75 if g == "good" else 0.0)
		perfect += 1 if g == "perfect" else 0
	if not grades.has("miss"):
		if crush:
			return {"grade": "good", "frac": 0.5}
		return {"grade": "perfect", "frac": 1.0} if perfect >= 0.85 * grades.size() else {"grade": "good", "frac": 1.0}
	var frac := minf(0.95, score / grades.size() / 0.85) * (0.5 if crush else 1.0)
	return {"grade": "good" if frac > 0.0 else "miss", "frac": frac}


# 보류한 적 행동: 타격 묶음마다 노트들(중간 노트 = 칼 부딪힘, 마지막 노트가 실제로 닿는 순간) → 묶음 판정으로 규칙 처리 → 기존 연출
func _anim_parry_hits(index: int, sprite: AnimatedSprite2D, monster: MonsterState, chart: P2NoteChart, ranged: bool) -> void:
	var groups: Array = chart.get_meta("groups")
	var got: Dictionary = chart.get_meta("got")
	var center: Vector2 = chart.get_meta("center")
	var plain := _plain_chart(chart)
	_slowmo_deep(chart.time_until(0))
	for h in range(groups.size()):
		var ids: Array = groups[h]
		for j in range(ids.size()):
			var ni := int(ids[j])
			var first := h == 0 and j == 0
			if not first:
				_strike_raise(sprite, chart.time_until(ni))
			elif not _art_acts(sprite):
				_lean(sprite, true, chart.time_until(ni))
			var raised := false
			var fired := first
			while is_instance_valid(chart) and chart.time_until(ni) > 0.0 and is_inside_tree():
				if not raised and _defend_anim() != "" and (got.has(ni) or bool(chart.notes[ni].holding) or (chart.time_until(ni) <= 0.2 and battle.get_pending_defense() > 0)):
					raised = true
					_actor_play(_defend_anim(), 1)
				if ranged and not fired and chart.time_until(ni) <= 0.16:
					fired = true
					if not _plain_chart(chart):
						_sfx("bow", 1.1, -4.0)
					else:
						_note_shot(sprite)
				await get_tree().process_frame
			if String(chart.notes[ni].kind) == "x":
				# 페인트: 휘두르는 척만 하고 닿지 않는다
				_sfx("enemy_swing", 0.75)
				continue
			_strike_contact(sprite)
			if j < ids.size() - 1:
				_sfx("enemy_swing", 1.2)
		# 묶음의 노트가 다 판정될 때까지(롱노트는 끝까지 누르는 동안 불꽃)
		var grind := 0
		while ids.any(func(x): return not got.has(int(x))) and is_inside_tree() and is_instance_valid(chart):
			grind += 1
			if _juice and grind % 5 == 0 and is_instance_valid(chart):
				for x in ids:
					if bool(chart.notes[int(x)].holding):
						_sparks(chart.notes[int(x)].pos, Vector2(1, -0.4), 0.9, 3, [C_CRIT, Color.WHITE], true)
			await get_tree().process_frame
		var crush := ids.any(func(x): return bool(chart.notes[int(x)].get("crush", false))) if is_instance_valid(chart) else false
		var res := _group_grade(ids.map(func(x): return String(got.get(int(x), "miss"))), crush)
		if not _plain_chart(chart) and res.grade != "perfect":
			# osu 말고는 한 노트마다 같은 몫: 막은 만큼 그대로 줄인다(막음은 반 몫, 강타는 그 절반)
			var score := 0.0
			for x in ids:
				score += {"perfect": 1.0, "good": 0.5}.get(String(got.get(int(x), "")), 0.0)
			var share := score / ids.size() * (0.5 if crush else 1.0)
			res = {"grade": "good" if share > 0.0 else "miss", "frac": share}
		if _music != null:
			res = _cell_grade(ids.map(func(x): return String(got.get(int(x), "miss"))), crush)
		if crush and ids.all(func(x): return String(got.get(int(x), "")) == "perfect"):
			_float_number(tr("강타 — 절반 막음"), _player_body() + Vector2(0, -150), C_GOLD, 24, 24.0, 1.0)
		battle.resolve_parry_hit(String(res.grade), float(res.frac))
		var evs := battle.events.duplicate(true)
		(enemy_action_log.back().events as Array).append_array(evs)
		await _commit("enemy hit")
		for e in evs:
			await _anim_enemy_event(index, e, sprite, monster, true)
		if not battle.parry_pending():
			break
	_set_prompt("")
	# 이번 공격 결과 한 줄
	var tally := {"perfect": 0, "good": 0, "miss": 0}
	for k in got:
		tally[String(got[k])] = int(tally.get(String(got[k]), 0)) + 1
	_float_number(tr("완벽 %d · 막음 %d · 놓침 %d") % [tally.perfect, tally.good, tally.miss], center + Vector2(0, 150 if plain else 80), C_GOLD if tally.miss == 0 else C_INK, 24, 24.0, 1.1)


# 원거리 적의 다음 노트: 화살·마력 한 발이 닫히는 순간 닿게
func _note_shot(sprite: AnimatedSprite2D) -> void:
	var from := _body_center(sprite.position) + Vector2(-20, 0)
	if _art_acts(sprite) and (sprite.has_meta("art") and bool(_ea_or(String(sprite.get_meta("art"))).get("cast_art", false))):
		_sfx("cast", 1.0)
		_core_shot(from, _player_body() + Vector2(14, -4), 0.15, 28.0)
	else:
		_sfx("bow", 1.0)
		_arrow(from, _player_body() + Vector2(18, 0), 0.16)


# 예고 칸 위 작은 표 = 이 적이 공격할 때 내가 막을 노트 미리보기. 앞에 막는 방식 이름, 올리면 줄마다 뜻
const PIP_TAG := {"osu": "고리", "drum": "북", "arrow": "화살", "dodge": "피하기", "echo": "따라"}


func _pip_legend(genre: String) -> String:
	var lines: Array = []
	match genre:
		"arrow":
			lines = ["이 적이 공격할 때 막을 화살 미리보기 (아래 상자에서 막기)", "흰 화살 = 보통", "노란 화살 = 가까이 와서 반대쪽으로 넘어옴", "빨간 화살 = 빠름"]
		"drum":
			lines = ["이 적이 공격할 때 칠 북 미리보기 (아래 띠에서 치기)", "빨간 점 = 왼쪽 클릭", "파란 점 = 오른쪽 클릭", "노란 막대 = 지나가는 동안 여러 번 클릭"]
		"dodge":
			lines = ["이 적이 공격할 때 피할 칸 미리보기 (아래 판에서 피하기)", "빨간 네모 하나 = 터지는 칸 하나"]
		"echo":
			lines = ["이 적이 공격할 때 따라 칠 박자 미리보기 (적이 먼저 치고 따라 치기)", "노란 마름모 하나 = 한 번 치기"]
		_:
			lines = ["이 적이 공격할 때 막을 노트 미리보기 (가운데 위에서 막기)", "흰 네모 = 짧게 클릭", "주황 막대 = 누른 채 버티기", "분홍 = 두 번 클릭", "초록 = 누른 채 공 따라가기",
				"보라 = 다가가면 도망감", "빨강 = 누르지 말기", "빨간 밑줄 = 강한 공격 (완벽해도 절반은 들어옴)"]
	return "\n".join(PackedStringArray(lines.map(func(s): return tr(String(s)))))


func _intent_pips(intent: Control, i: int, act: Dictionary) -> void:
	var pips: Control = intent.get_meta("pips") if intent.has_meta("pips") else null
	if pips == null:
		pips = Control.new()
		pips.mouse_filter = Control.MOUSE_FILTER_STOP
		pips.mouse_default_cursor_shape = Control.CURSOR_HELP
		pips.position = Vector2(0, -16)
		pips.size = Vector2(ENEMY_W, 14)
		intent.add_child(pips)
		intent.set_meta("pips", pips)
		pips.draw.connect(func() -> void:
			var kinds: Array = pips.get_meta("kinds", [])
			if kinds.is_empty():
				return
			var wsum := 0.0
			for k in kinds:
				wsum += (16.0 if k in ["h", "s", "d:roll"] else 8.0) + 4.0
			var tag := String(pips.get_meta("tag", ""))
			var tf := P2Ui.pixel_font(P2Ui.T_SMALL)
			var tw := tf.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, P2Ui.T_SMALL).x + 5.0 if tag != "" else 0.0
			var x := (intent.size.x - wsum - tw + 4.0) / 2.0
			if tag != "":
				pips.draw_string_outline(tf, Vector2(x, 10), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, P2Ui.T_SMALL, 4, Color(0.04, 0.03, 0.05))
				pips.draw_string(tf, Vector2(x, 10), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, P2Ui.T_SMALL, C_DIM)
				x += tw
			for k in kinds:
				match String(k):
					"d:don", "d:ka":
						pips.draw_circle(Vector2(x + 4, 5), 4.0, P2DrumChart.C_KA if k == "d:ka" else P2DrumChart.C_DON)
						x += 12.0
						continue
					"d:roll":
						pips.draw_rect(Rect2(x, 2, 16, 6), P2DrumChart.C_ROLL)
						x += 20.0
						continue
					"z":
						pips.draw_rect(Rect2(x, 1, 8, 8), P2DodgeChart.C_WARN, false, 2.0)
						x += 12.0
						continue
					"e":
						pips.draw_colored_polygon(PackedVector2Array([Vector2(x + 4, 1), Vector2(x + 8, 5), Vector2(x + 4, 9), Vector2(x, 5)]), P2EchoChart.C_CALL)
						x += 12.0
						continue
				if String(k).begins_with("a:"):
					var ac: Color = {"a:rev": P2ArrowChart.C_REV, "a:fast": P2ArrowChart.C_FAST}.get(String(k), P2ArrowChart.C_NORMAL)
					pips.draw_colored_polygon(PackedVector2Array([Vector2(x, 5), Vector2(x + 8, 1), Vector2(x + 8, 9)]), ac)
					x += 12.0
					continue
				var col: Color = P2NoteChart.COLOR.get(k, P2NoteChart.C_APPROACH)
				var wide: bool = k in ["h", "s"]
				pips.draw_rect(Rect2(x, 2 if wide else 1, 16 if wide else 8, 6 if wide else 8), col)
				x += 20.0 if wide else 12.0
			if bool(pips.get_meta("crush", false)):
				pips.draw_rect(Rect2(x - wsum, 11, wsum - 4.0, 2), Color("#c0301c")))
	var hits := _shown_intent(i)
	var kinds: Array = []
	var crush := false
	var tip := ""
	var simple := int((_shown.enemies[i] as Dictionary).get("supp", 0)) > 0
	if act.is_empty() and P2Battle._is_damaging(hits):
		var pat := _parry_pattern(i, hits.map(func(h): return battle.scaled(int(h))), simple)
		for gi in range(pat.size()):
			if _genre_of(i) != "osu":
				kinds.append_array(_pip_kinds(_genre_of(i), pat[gi], _parry_tier(i)))
			else:
				kinds.append_array(pat[gi].kinds)
			if bool(pat[gi].crush):
				crush = true
				# 강타 계산: 완벽해도 절반 → 지금 방어 → 체력 피해
				var raw := battle.scaled(int(hits[mini(gi, hits.size() - 1)]))
				var half := raw - maxi(1, raw / 2)
				var blk := int(_shown.block)
				tip += tr("\n강한 공격 %d → 완벽히 막아도 %d → 방어 %d로 받고 → 체력 −%d") % [raw, half, blk, maxi(0, half - blk)]
		tip = _pip_legend(_genre_of(i)) + "\n\n" + tr("이번에 %d개") % kinds.size() + (tr(" · 이 적만의 박자 「%s」") % String(pat[0].phrase) if String(pat[0].phrase) != "" else "") + (tr(" · 억제로 쉬워짐") if simple else "") + tip
		intent.tooltip_text = String(intent.tooltip_text).get_slice("\n\n", 0) + "\n\n" + tip
	pips.size.x = maxf(48.0, intent.size.x)
	pips.set_meta("kinds", kinds)
	pips.set_meta("tag", tr(String(PIP_TAG.get(_genre_of(i), ""))) if not kinds.is_empty() else "")
	pips.set_meta("crush", crush)
	pips.tooltip_text = tip
	pips.queue_redraw()


# ── 손맛 시험판: 주변 시간 · 타격감 ──

func _vignette_node() -> ColorRect:
	if _vignette == null:
		_vignette = ColorRect.new()
		_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
		_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sh := Shader.new()
		sh.code = VIGNETTE
		var m := ShaderMaterial.new()
		m.shader = sh
		_vignette.material = m
		_ui.add_child(_vignette)
		_ui.move_child(_vignette, 0)
	return _vignette


func _tick_vignette(delta: float) -> void:
	if _vignette == null:
		return
	_vig.pulse = float(_vig.pulse) * exp(-delta * 7.0)
	var danger := 0.0
	if float(_vig.danger) > 0.0:
		# 낮은 체력 심장 박동: 체력이 줄수록 빨라지고(분당 약 70 → 115) 세진다. 박마다 낮은 쿵
		var mhp := maxf(1.0, float(_run_info.get("max_hp", 1)))
		var low := clampf(1.0 - float(_shown.hp) / (mhp * 0.3), 0.0, 1.0)
		_heart_t += delta * lerpf(1.15, 1.9, low)
		var ph := fmod(_heart_t, 1.0)
		var beat := exp(-ph * 14.0) + 0.65 * exp(-absf(ph - 0.24) * 22.0)
		danger = float(_vig.danger) * (0.4 + 0.6 * minf(beat, 1.0)) * lerpf(0.85, 1.3, low)
		if int(_heart_t) != _heart_beat:
			_heart_beat = int(_heart_t)
			if _beat != null and _state != UI.OVER:
				_beat.play("thud", 0, -10.0)
	var m := _vignette.material as ShaderMaterial
	m.set_shader_parameter("dark", float(_vig.dark) + float(_vig.pulse) * 0.14)
	m.set_shader_parameter("danger", danger)
	_vignette.visible = float(_vig.dark) + float(_vig.pulse) + float(_vig.danger) > 0.005


func _set_cam_base_z(z: float) -> void:
	_cam_base_z = z
	if _cam != null:
		_apply_cam(_cam_raw_off, _cam_raw_z)


func _set_cam_base_off(o: Vector2) -> void:
	_cam_base_off = o
	if _cam != null:
		_apply_cam(_cam_raw_off, _cam_raw_z)


# 악보 동안의 긴장: 가장자리가 어두워지고(박마다 살짝 맥박), 주변이 흐려지며, dur 동안 아주 천천히 줌인·쏠림. 끝나면 0.32초에 쑤욱 풀린다
func _tension(on: bool, c := Vector2(640, 360), dur := 1.0) -> void:
	if not _juice:
		return
	_vignette_node()
	if _tension_tw != null and _tension_tw.is_valid():
		_tension_tw.kill()
	_tension_tw = create_tween().set_parallel()
	if on:
		_tension_tw.tween_method(func(x: float) -> void: _vig.dark = x, float(_vig.dark), 0.62, 0.25)
		if not _reduce_motion:
			_tension_tw.tween_method(_set_cam_base_z, _cam_base_z, 1.07, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			_tension_tw.tween_method(_set_cam_base_off, _cam_base_off, (c - Vector2(640, 360)) * 0.2, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		if _av7_on():
			_av7_fx.center = c
			_av7_fx.sharp_a = c
			_av7_fx.sharp_b = _to_ui(_player_body())
			_av7_fx.sharp_r = 300.0
			_av7_mat.set_shader_parameter("sharp_r", 300.0)
			_tension_tw.tween_method(func(x: float) -> void: _av7_set("blur_px", x), float(_av7_fx.blur_px), 2.4, 0.3)
	else:
		_tension_tw.tween_method(func(x: float) -> void: _vig.dark = x, float(_vig.dark), 0.0, 0.3)
		_tension_tw.tween_method(_set_cam_base_z, _cam_base_z, 1.0, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tension_tw.tween_method(_set_cam_base_off, _cam_base_off, Vector2.ZERO, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if _av7_on():
			_tension_tw.tween_method(func(x: float) -> void: _av7_set("blur_px", x), float(_av7_fx.blur_px), 0.0, 0.22)


# 첫 노트가 닿을 때까지 주변 시간을 거의 멈춤(0.06배)까지 늦춘다
func _slowmo_deep(dur: float) -> void:
	if not _juice:
		return
	if _slow_tw != null and _slow_tw.is_valid():
		_slow_tw.kill()
	_slow_tw = create_tween()
	_slow_tw.tween_method(_set_world_speed, _world_speed, 0.06, maxf(0.1, dur)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# 주변만 느리게: 다른 적의 몸 동작·맥 흐름·물·불·맥 수조가 SLOW_SPEED배, keep의 배우와 주인공·판정은 제 속도.
# 배경을 살짝 가라앉히고 시작에 굴절 고리, 끝나면 부드럽게 돌아온다
func _slowmo(on: bool, keep: Array = [], at_w := Vector2.ZERO) -> void:
	if not _juice:
		return
	if _slow_tw != null and _slow_tw.is_valid():
		_slow_tw.kill()
	if on:
		_slow_keep = keep
		_sfx("swing", 0.55, -4.0)
		if _av7_on() and at_w != Vector2.ZERO:
			_av7_fx.center = _to_ui(at_w)
			_av7_ring(5.0, 300.0, 0.4)
	elif _world_speed < 0.99:
		_sfx("swing", 1.6, -6.0)
	var dur := 0.14 if on else 0.32
	if _show != null:
		_show.time_look(on)
	_slow_tw = create_tween()
	_slow_tw.tween_method(_set_world_speed, _world_speed, SLOW_SPEED if on else 1.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT if on else Tween.EASE_IN_OUT)
	if _dim != null:
		_slow_tw.parallel().tween_property(_dim, "color", Color(0.02, 0.03, 0.09, 0.3 if on else 0.0), dur)
	if not on:
		_slow_tw.tween_callback(func() -> void: _slow_keep = [])


func _set_world_speed(v: float) -> void:
	_world_speed = v
	for sp in _enemy_sprites:
		if not is_instance_valid(sp) or _slow_keep.has(sp):
			continue
		if sp.speed_scale > 0.0:
			sp.speed_scale = v
			if not _slowed.has(sp):
				_slowed.append(sp)
	if v >= 0.999:
		for sp in _slowed:
			if is_instance_valid(sp) and sp.speed_scale > 0.0:
				sp.speed_scale = 1.0
		_slowed.clear()


# 맞는 순간(본타): 하얗게 번쩍 · 공격 방향 뒤쪽으로 파편 · 완벽한 긋기는 굴절 고리·색 분리·더 긴 멈춤
func _juice_hit(sprite: AnimatedSprite2D, pos: Vector2, dmg: int, crit: bool, dir := Vector2(1, -0.25)) -> void:
	_actor_flash(sprite, Color.WHITE, 1.0, 0.02, 0.1)
	var n := 8 + mini(dmg, 18) + (12 if crit else 0)
	var maek := sprite.has_meta("art")
	_sparks(pos + Vector2(10, 0), (dir + Vector2(0, -0.25)).normalized(), 0.55, n, [Color.WHITE, C_IVORY, C_ARCANE if maek else Color("#d8cbb4")], false, Vector2(260, 620))
	_sparks(pos, Vector2.RIGHT, 1.2, 6 + (6 if crit else 0), [Color.WHITE, C_CRIT], true, Vector2(160, 380))
	if String(_slash_trace.get("grade", "")) == "perfect" or crit:
		_stop_bonus = 0.05
		if _av7_on():
			_av7_fx.center = _to_ui(pos)
			_av7_ring(7.0, 260.0, 0.35)
			_av7_speed_lines(dir, 0.18)


# 파편 한 묶음. front면 배우 앞, 아니면 배우 뒤(맞은 몸을 뚫고 나가는 느낌)
func _sparks(at: Vector2, dir: Vector2, spread: float, count: int, colors: Array, front: bool, speed := Vector2(200, 520), gravity := 520.0) -> void:
	if _reduce_motion or count <= 0:
		return
	var s := P2Sparks.new()
	s.burst(at, dir.normalized(), spread, count, speed, colors, Vector2i(2, 5), 0.42, gravity)
	(_fxp if front else _fxbp).add_child(s)


# 멈춘 동안 떨기(사쿠라이식): 좌우로 amp px, 점점 약하게. 자세 기준점(offset)에 더했다 그만큼 뺀다
func _vibrate(s: Node2D, dur: float, amp: float) -> void:
	var t := 0.0
	var k := 0
	var applied := Vector2.ZERO
	while t < dur and is_instance_valid(s) and is_inside_tree():
		var d := Vector2(roundf(amp * (1.0 - t / dur)) * (1.0 if k % 2 == 0 else -1.0), 0.0)
		s.set("offset", (s.get("offset") as Vector2) + d - applied)
		applied = d
		k += 1
		await get_tree().process_frame
		t += get_process_delta_time()
	if is_instance_valid(s):
		s.set("offset", (s.get("offset") as Vector2) - applied)


# 고무줄: 뒤로 당겼다가(느리게) 놓는다(빠르게 — 이어지는 돌진이 짧다)
func _pull_back(node: Node2D, dx: float, dur: float) -> void:
	_sfx("swing", 0.7, -8.0)
	var t := create_tween()
	t.tween_property(node, "position:x", node.position.x + dx, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await t.finished


# 돌진 잔상: 지금 프레임 그림을 dur 동안 몇 장 남기고 흐려진다(배우 뒤)
func _afterimages(src: AnimatedSprite2D, dur: float) -> void:
	var steps := 4
	for i in range(steps):
		if not is_instance_valid(src) or src.sprite_frames == null:
			return
		var tex := src.sprite_frames.get_frame_texture(src.animation, src.frame)
		if tex != null:
			var g := Sprite2D.new()
			g.texture = tex
			g.centered = src.centered
			g.offset = src.offset
			g.flip_h = src.flip_h
			g.texture_filter = src.texture_filter
			g.modulate = Color(0.65, 0.85, 1.0, 0.42)
			_fx_back.add_child(g)
			g.global_transform = src.global_transform
			var t := g.create_tween()
			t.tween_property(g, "modulate:a", 0.0, 0.16)
			t.tween_callback(g.queue_free)
		await _wait(dur / steps)


# 룬술사 마력 장막: 방어가 있으면 주인공을 감싼다. 다 깎이면 조각나 흩어진다
func _barrier_sync(block: int) -> void:
	if not _juice or battle == null or battle.class_id != "rune_caster" or _player == null:
		return
	if _barrier == null:
		_barrier = P2Barrier.new()
		_fxp.add_child(_barrier)
	_barrier.position = _player_body()
	var before := _barrier._amount
	_barrier.set_amount(block)
	if before > 0 and block <= 0:
		_sfx("shatter", 0.9)
		_sparks(_barrier.position + Vector2(60, 0), Vector2.RIGHT, 1.4, 22, [C_ARCANE, Color.WHITE, Color("#4fb8c8")], true, Vector2(120, 360), 300.0)


func _record_timing(action: String, feedback_ms: float, t0: int) -> void:
	_timings.append({"action": action, "feedback_ms": snappedf(feedback_ms, 0.1),
		"return_ms": snappedf((Time.get_ticks_usec() - t0) / 1000.0, 0.1),
		"ack_ms": _t_ack, "commit_ms": _t_commit, "contact_ms": _t_contact})
	_update_debug()


func get_timings() -> Array[Dictionary]:
	return _timings.duplicate(true)


# 눌림: 고른 카드(올린 카드면 그 카드)를 6px 내리고 살짝 어둡게. 실패하면 _refresh_card_states가 원래대로 되돌린다
func _ack_press(card: Card) -> void:
	var view: Control = _big if _big != null and _big_card == card else _card_views.get(card)
	if view == null:
		return
	view.position.y += 6.0
	view.modulate = Color(0.82, 0.8, 0.78)


# 바꾼 화면이 실제로 한 번 그려질 때까지(그리는 창) — 창 없는 실행이나 그리기가 멈춘 창에서는 짧은 상한 뒤 진행
func _await_drawn(limit_ms := 120) -> void:
	if DisplayServer.get_name() == "headless":
		await get_tree().process_frame
		return
	var done := [false]
	var cb := func() -> void: done[0] = true
	RenderingServer.frame_post_draw.connect(cb, CONNECT_ONE_SHOT)
	var t0 := Time.get_ticks_msec()
	while not done[0] and Time.get_ticks_msec() - t0 < limit_ms and is_inside_tree():
		await get_tree().process_frame
	if RenderingServer.frame_post_draw.is_connected(cb):
		RenderingServer.frame_post_draw.disconnect(cb)


# 쓴 카드가 날아갈 대상 자리(화면): 지정 적 · 모든 적 · 주인공
func _play_point(card: Card, target: int) -> Vector2:
	if P2Catalog.is_targeted(card) and target >= 0:
		return _to_ui(_enemy_torso(target))
	if P2Catalog.is_attack(card):
		return _enemies_rect().get_center()
	return _player_rect().get_center()


func _fly_card_out(card: Card, from: Vector2, burn := false, to := Vector2.INF) -> void:
	if not _card_views.has(card):
		return
	var view: Control = _card_views[card]
	_card_views.erase(card)
	if _big != null and _big_card == card:
		view.queue_free()
		view = _big
		from = _big.position
		_big = null
		_big_card = null
	view.reparent(_ui)
	view.position = from
	view.rotation_degrees = 0.0
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if burn or P2Catalog.exhausts(card):
		view.modulate = Color(1.6, 0.7, 0.4)
	var t := create_tween()
	if to != Vector2.INF and not burn and not P2Catalog.exhausts(card) and not _reduce_motion:
		# 대상에게 날아가 돌며 작아져 빨려 들어간다
		t.tween_property(view, "scale", view.scale * 1.08, 0.05).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(view, "position", to - view.pivot_offset, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.parallel().tween_property(view, "scale", Vector2.ONE * 0.05, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.parallel().tween_property(view, "rotation", TAU, 0.2)
		t.parallel().tween_property(view, "modulate", Color(2.0, 1.9, 1.6, 0.0), 0.2).set_ease(Tween.EASE_IN)
		var sp := P2Sparks.new()
		sp.gather(to, 100.0, 14, [C_GOLD, Color.WHITE, C_IVORY], 0.24)
		_uip.add_child(sp)
	else:
		t.tween_property(view, "scale", Vector2(0.92, 0.92), 0.05)
		t.tween_property(view, "position", from + Vector2(0, -60), 0.12).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(view, "modulate:a", 0.0, 0.12)
	t.tween_callback(view.queue_free)
	_relayout_hand()


func _relayout_hand() -> void:
	_place_hand()
	_renumber_hand()
	_fit_hand_rail()
	_refresh_card_states()


# 손패 자리: 끄는 카드는 빼고(남은 카드가 자리를 메움), 올린 카드 양옆은 비켜선다(가까울수록 많이). 탄성 있게 옮긴다
func _place_hand() -> void:
	var cards: Array = battle.hand.cards.filter(func(c): return _card_views.has(c) and (_drag.is_empty() or c != _drag.card))
	var lift := cards.find(_big_card) if _big_card != null else -1
	for i in range(cards.size()):
		var view: Control = _card_views[cards[i]]
		var g := _fan(i, cards.size())
		view.set_meta("home", g.pos)
		view.set_meta("rot", g.rot)
		_hand_root.move_child(view, i)
		var x := float(g.pos.x)
		if lift >= 0 and i != lift:
			x += signf(i - lift) * float([0.0, 46.0, 24.0, 10.0][mini(absi(i - lift), 3)])
		if view.get_meta("entering", false):
			view.position.x = x
			view.rotation_degrees = g.rot
			continue
		if absf(view.position.x - x) < 0.5:
			continue
		var old: Tween = view.get_meta("slide") if view.has_meta("slide") else null
		if old != null and old.is_valid():
			old.kill()
		if _reduce_motion:
			view.position.x = x
			continue
		var t := view.create_tween()
		t.tween_property(view, "position:x", x, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		view.set_meta("slide", t)


# 손패 받침선: 지금 손패의 왼쪽 끝 ~ 오른쪽 끝 (카드 수에 따라)
func _fit_hand_rail() -> void:
	if _hand_rail == null:
		return
	var n := battle.hand.cards.size()
	_hand_rail.visible = n > 0
	if n == 0:
		return
	var a: Vector2 = _fan(0, n).pos
	var b: Vector2 = _fan(n - 1, n).pos
	_hand_rail.position.x = a.x - 14.0
	_hand_rail.size.x = b.x + REST.x + 14.0 - _hand_rail.position.x


func _animate_card(card: Card, target: int, events: Array) -> void:
	var kind := P2Catalog.kind_of(card)
	_cur_kind = kind
	_cur_magic = P2Catalog.is_magic(card)
	if _show != null:
		var shown: bool = await _show.anim_card(card, kind, target, events)
		if shown:
			await _anim_followups(events)
			return
	var crit := events.filter(func(e): return String(e.kind) == "crit")
	if not crit.is_empty() and bool(crit[0].forced):
		_anim_prepared_crit()
	if card.effect == Card.EffectType.DEFEND or events.any(func(e): return String(e.kind) == "guard" and bool(e.get("reverse", false))):
		await _anim_guard(events)
	elif card.effect == Card.EffectType.HEAL_HP:
		await _anim_heal(card)
	elif P2Catalog.is_fuel(card):
		await _anim_fuel(events)
	elif P2Catalog.is_draw(card):
		await _anim_focus()
	elif P2Catalog.is_magic(card):
		await _anim_magic(card, events)
	elif battle.class_id == "hunter" and (kind in ["quickshot", "aimed_shot"] or not _dressed):
		await _anim_shot(card, kind, events)
	elif _hires and kind == "slash":
		await _anim_warden_wave(card, events)
	else:
		await _anim_physical(card, kind, target, events)
	await _anim_followups(events)


# 확정 치명타: 쏘기 전에 금빛으로 알린다 (무작위 치명타는 맞는 순간에만 드러난다)
func _anim_prepared_crit() -> void:
	var at := _player_body()
	_sfx("crit_ready")
	_float_number("확정 치명타", at + Vector2(0, -110), C_CRIT, 24, 24.0, 0.8)
	if _crit_glow != null:
		_crit_glow.visible = true
		var t := create_tween()
		t.tween_property(_crit_glow, "scale", _crit_glow.scale * 1.4, 0.1)
		t.tween_property(_crit_glow, "scale", _crit_glow.scale, 0.12)
	_actor_flash(_player, C_CRIT, 0.5, 0.03, 0.12)


func _weapon_to(pos: Vector2, rot: float, dur: float) -> Tween:
	var t := create_tween()
	if _weapon == null:
		t.tween_interval(dur)
		return t
	t.tween_property(_weapon, "position", pos, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_weapon, "rotation_degrees", rot, dur)
	return t


func _weapon_home(dur: float) -> void:
	if _weapon == null:
		return
	_weapon_to(_weapon.get_meta("home"), float(_weapon.get_meta("rot")), dur)


# 연료화: 두 장이 불타 사라지고(뒤따르는 사건에서 소진·마나 표시) 마나 칸이 찬다
func _anim_fuel(events: Array) -> void:
	await _focus_body()
	var at := _player_body()
	_sfx("exhaust")
	_vfx("charge", at, 1.0)
	if _show != null and not _reduce_motion:
		await _show.fuel_garnish()
	await _wait(0.2)


# 사냥꾼: 돌진하지 않고 활을 당겨 화살을 쏜다 (조준 사격은 더 오래 당긴다). 타격마다 화살 하나
func _anim_shot(card: Card, kind: String, events: Array) -> void:
	if _dressed:
		await _anim_bow(kind, events, P2Catalog.upgrade_of(card) != "")
		return
	var hits := events.filter(func(e): return e.kind == "hit")
	var spend := events.filter(func(e): return e.kind == "spend_block")
	if not spend.is_empty():
		_apply_event(spend[0])
	var aimed := kind == "aimed_shot"
	if _weapon != null:
		var home: Vector2 = _weapon.get_meta("home")
		await _weapon_to(home + Vector2(-3, 0), float(_weapon.get_meta("rot")) - 8.0, 0.2 if aimed else 0.1).finished
	_sfx("bow", 0.8 if aimed else 1.1)
	var waves := {}
	for ev in hits:
		var k := int(ev.get("hit_index", 0))
		if not waves.has(k):
			waves[k] = []
		(waves[k] as Array).append(ev)
	var order: Array = waves.keys()
	order.sort()
	var from := _player.position + Vector2(52, -62)
	for k in order:
		var wave: Array = waves[k]
		var flights: Array = []
		for ev in wave:
			flights.append(_arrow(from, _enemy_torso(ev.index), 0.16 if aimed else 0.12))
		for f in flights:
			await f
		for ev in wave:
			var pos := _enemy_torso(ev.index)
			if ev.consumed > 0:
				_mark_burst(ev.index, pos, ev.consumed)
			_vfx("counter" if aimed else "slash", pos, 1.2 if aimed else 0.9)
			_impact_sfx(ev, "aimed" if aimed else "arrow", int(k))
			_enemy_hit_feedback(ev, Color("#ffd2a0"))
		await _hit_stop([_player], 0.04)
		if int(k) != int(order.back()):
			_sfx("bow", 1.25)
			await _wait(0.08)
	_weapon_home(0.14)
	await _wait(0.16)


# 사냥꾼 활 카드: 속사 = shot, 조준 사격 = aim(당긴 채 멈춤이 더 김). 1프레임부터 시작해 발사 프레임(4)에서 시위 소리·화살 출발,
# 표시 피해·표식·치명·처치는 화살이 실제 대상에 닿을 때 한 번. 타격 묶음(hit_index)마다 화살 한 번, 둘째 묶음은 당기는 프레임부터 다시
func _anim_bow(kind: String, events: Array, upgraded := false) -> void:
	var hits := events.filter(func(e): return e.kind == "hit")
	var spend := events.filter(func(e): return e.kind == "spend_block")
	if not spend.is_empty():
		_apply_event(spend[0])
	var aimed := kind == "aimed_shot"
	var av7 := aimed and not hits.is_empty() and _av7_prepare()
	var anim := "aim" if aimed else "shot"
	var release := _contact(anim)
	_actor_play(anim, 1)
	var waves := {}
	for ev in hits:
		var k := int(ev.get("hit_index", 0))
		if not waves.has(k):
			waves[k] = []
		(waves[k] as Array).append(ev)
	var order: Array = waves.keys()
	order.sort()
	if order.is_empty():
		await _await_frame(anim, release)
		_sfx("bow", 0.8 if aimed else 1.1)
	for k in order:
		if int(k) > 0:
			_actor_play(anim, release - 1)
		await _await_frame(anim, release)
		_sfx("bow", 0.8 if aimed else 1.1)
		var from := _player.position + HUNTER_BOW * _ks
		var flights: Array = []
		if av7 and int(k) == int(order[0]):
			_av7_flight(from, _enemy_torso(int(waves[k][0].index)), 0.16)
		for ev in waves[k]:
			flights.append(_arrow(from, _enemy_torso(ev.index), 0.16 if aimed else 0.12))
		for f in flights:
			await f
		var prof := "light"
		var held: Array = [_player]
		for ev in waves[k]:
			var pos := _enemy_torso(ev.index)
			if ev.consumed > 0:
				_mark_burst(ev.index, pos, ev.consumed)
			_vfx("counter" if aimed else "slash", pos, 1.2 if aimed else 0.9)
			_impact_sfx(ev, "aimed" if aimed else "arrow", int(k))
			var ep := _contact_profile(ev, "major" if aimed else "")
			prof = _stronger(prof, ep)
			held.append(_enemy_sprites[ev.index])
			_enemy_hit_feedback(ev, Color("#ffd2a0"), ep)
		var bpos := _enemy_torso(int(waves[k][0].index))
		if not (av7 and int(k) == int(order[0]) and _av7_contact(bpos, "payoff" if _av7_payoff(upgraded, waves[k]) else "enhanced", Vector2.RIGHT, [_player] + held)):
			_camera_kick(prof, Vector2.RIGHT)
			if int(k) == int(order[0]):
				_av7_light(bpos, "basic", Color(1.0, 0.86, 0.6))
		await _hit_stop(held, float(IMPACT[prof].hold))
	await _wait(0.1)


# 사냥꾼 단검: 대상 앞에서 단검 끝이 몸에 닿는 거리까지만 다가간다 (사거리·대상 규칙은 그대로, 몸 전체가 적과 겹치지 않게)
func _dagger_x(target: int) -> float:
	var front := 99999.0
	for i in range(_enemy_sprites.size()):
		if bool(_shown.enemies[i].alive):
			front = minf(front, _enemy_pos(i).x)
	if front > 9999.0:
		return _home_x + 90.0
	var tx := _enemy_pos(target).x if target >= 0 else front
	return maxf(_home_x, tx - float(_art.get("reach", HUNTER_REACH)) * _ks)


func _arrow(from: Vector2, to: Vector2, duration: float) -> Signal:
	var a := Sprite2D.new()
	a.texture = P2Catalog.icon_tex("quickshot")
	a.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	a.scale = Vector2.ONE * 2.4
	a.position = from
	# 아이콘 화살은 끝이 오른쪽 아래(+45°)를 향한다 → 비행 방향에 맞추려면 45° 되돌린다
	a.rotation = (to - from).angle() - PI / 4.0
	_fx.add_child(a)
	var t := create_tween()
	t.tween_property(a, "position", to, duration).set_trans(Tween.TRANS_LINEAR)
	t.tween_callback(a.queue_free)
	return t.finished


# 치유의 문양: 몸에 분홍 하트가 피어오르고 초록 고리가 퍼진다(회복 숫자는 뒤따르는 회복 사건에서)
func _anim_heal(card: Card) -> void:
	await _focus_body()
	var perfect := String(_slash_trace.get("grade", "")) == "perfect"
	_sfx("cast", 1.3)
	if not _reduce_motion:
		P2SkillFx.spawn(_fxp, "heal", _player_body() + Vector2(0, 16), Vector2.UP, 1.3 if perfect else 1.0, Color("#ff7aa8"))
	skill_log.append({"card": P2Catalog.kind_of(card), "fx": "heal"})
	if not _reduce_motion:
		P2HitBits.spawn(_fxp, "heart", _player_body() + Vector2(0, -10), Vector2.UP, 14 if perfect else 10, [Color("#ff7aa8"), Color("#ffb3cf"), Color("#8be08b")], 1.2)
	_actor_flash(_player, Color("#8be08b"), 0.5, 0.04, 0.22)
	await _wait(0.22)


func _anim_focus() -> void:
	await _focus_body()
	var at := _player_body()
	_sfx("cast", 1.5)
	_vfx("charge", at + Vector2(0, -10), 0.9)
	_float_number("집중", at + Vector2(0, -70), Color("#7fd7d0"), 24, 26.0, 0.7)
	if _show != null and not _reduce_motion:
		_show.focus_garnish()
	await _wait(0.22)


func _anim_guard(events: Array) -> void:
	var gi := events.find_custom(func(e): return String(e.kind) == "guard")
	var ev: Dictionary = events[gi] if gi >= 0 else {"kind": "guard", "amount": 0, "counter_added": false}
	for e in events:
		if String(e.kind) != "guard":
			_apply_event(e)
	var def_anim := _defend_anim()
	if def_anim != "":
		_actor_play(def_anim, 1)
		await _await_frame(def_anim, _contact(def_anim))
	_sfx("guard")
	_vfx("guard", _player_body(), 1.2)
	if not _reduce_motion:
		P2SkillFx.spawn(_fxp, "ward", _player_body() + Vector2(40, -6), Vector2.RIGHT, clampf(0.8 + int(ev.amount) / 20.0, 0.8, 1.4), Color("#8fc3e8") if not bool(ev.get("veil", false)) else C_ARCANE)
		P2HitBits.spawn(_fxp, "star", _player_body() + Vector2(40, -20), Vector2.RIGHT, 6, [C_IVORY, Color("#8fc3e8")], 0.8)
	var home := _player.position
	var t := create_tween()
	t.tween_property(_player, "position", home + Vector2(-6, 2), 0.06)
	t.tween_property(_player, "position", home, 0.1)
	# 수호기사: 방패를 앞으로 내밀어 버틴다
	if _art_cid == "warden" and _weapon != null:
		_sfx("brace")
		var wh: Vector2 = _weapon.get_meta("home")
		var bt := create_tween()
		bt.tween_property(_weapon, "position", wh + Vector2(4, 1), 0.08)
		bt.parallel().tween_property(_weapon, "scale", Vector2.ONE * 0.8, 0.08)
		bt.tween_interval(0.14)
		bt.tween_property(_weapon, "position", wh, 0.12)
		bt.parallel().tween_property(_weapon, "scale", Vector2.ONE * 0.6, 0.12)
	_apply_event(ev)
	if _barrier != null:
		var g := P2Sparks.new()
		g.gather(_player_body(), 110.0, 18, [C_ARCANE, Color.WHITE], 0.22)
		_fxp.add_child(g)
		_sfx("shatter", 1.4, -4.0)
	_float_number("%s +%d" % ["마나 장막" if bool(ev.get("veil", false)) else "방어", ev.amount], _player_body() + Vector2(0, -40), C_BLOCK, 24)
	if _show != null and not _reduce_motion:
		_show.guard_garnish(_cur_kind, ev)
	if ev.counter_added:
		_float_number("반격 %d 준비" % int(ev.counter_value), _player_body() + Vector2(0, -80), C_GOLD, F, 30.0, 0.9)
	await _wait(0.2 if _dressed else 0.34)


# 마법: 손·지팡이 끝에 짧은 문양 → 핵이 모였다가 살아 있는 대상에게 날아간다 → 맞는 순간 청록 폭발·작은 반동.
# 표식을 쓰는 마법(각인 파열)은 날아가는 동안 표식이 몸으로 모이고 맞는 순간 함께 터진다. 피해·표식은 사건 그대로 한 번만
func _anim_magic(card: Card, events: Array) -> void:
	var major := P2Catalog.kind_of(card) == "torrent" or P2Catalog.upgrade_of(card) != ""
	var hand_pos := _player.position + Vector2(42, -60) * _ks
	# 룬술사: 보통 마법 = cast, 각인 파열·마력 폭류·강화 마법 = strong_cast(몸 동작만 고름, 효과 크기 규칙은 그대로). 발사 프레임 3에 수정에서 출발
	var rune := _dressed and _art_cid == "rune_caster"
	# 수호기사·사냥꾼: 자기 cast 동작 하나(보통·강화 마법 공용, 효과 크기는 기존 강화 규칙대로). 모으는 핵·문양은 지금 프레임의 칼끝/손을 따라가다 발사 프레임 자리에서 출발
	var caster := _dressed and not rune and (_art.anims as Dictionary).has("cast")
	var body := ""
	if rune:
		body = "strong_cast" if major or P2Catalog.kind_of(card) == "sigil_burst" else "cast"
		_actor_play(body, 1)
		hand_pos = _rune_socket(body)
	elif caster:
		body = "cast_strong" if major and (_art.anims as Dictionary).has("cast_strong") else "cast"
		_actor_play(body, 1)
		hand_pos = _cast_socket()
	else:
		_player.play("idle")
		var lean := create_tween()
		lean.tween_property(_player, "position:x", _home_x + 8, 0.06)
	# 룬술사: 지팡이를 치켜들고 끝에서 쏜다
	if _art_cid == "rune_caster" and _weapon != null:
		_sfx("staff", 1.1)
		_weapon_to((_weapon.get_meta("home") as Vector2) + Vector2(2, -4), -55.0, 0.08)
		hand_pos = _player.position + Vector2(52, -104)
	for ev in events:
		if String(ev.kind) == "x_paid":
			_apply_event(ev)
			_float_number("X = %d" % int(ev.x), MANA_ORB + Vector2(60, -44), Color("#9fd4ff"), 24, 20.0, 0.8)
	_sfx("cast", 0.85 if major else 1.0)
	var ckind := P2Catalog.kind_of(card)
	if String(SKILL_SIG.get(ckind, "")) == "sigil" and not _reduce_motion:
		var seen := {}
		for ev in events:
			if String(ev.kind) == "hit" and not seen.has(int(ev.index)):
				seen[int(ev.index)] = true
				P2SkillFx.spawn(_fxp, "sigil", _enemy_torso(int(ev.index)), Vector2.RIGHT, 1.0, _skill_color(ckind))
				skill_log.append({"card": ckind, "fx": "sigil"})
				_sfx("mark", 0.8, -4.0)
				_shockwave_later(_enemy_torso(int(ev.index)), 11.0, 0.45)
	var marked := {}
	var sigil := _sigil_flash(hand_pos, 112.0 if major else 80.0, 0.3 if major else 0.24)
	var core_px := 50.0 if major else 34.0
	if _juice:
		var g := P2Sparks.new()
		g.gather(hand_pos, 90.0 if major else 64.0, 22 if major else 14, [C_ARCANE, Color.WHITE, C_MARK], 0.24)
		_fxp.add_child(g)
	var core := _arcane_sprite("core", hand_pos, core_px)
	var full := core.scale
	core.scale = full * 0.35
	var gather := create_tween()
	gather.tween_property(core, "scale", full, 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if rune:
		await _await_frame(body, _contact(body))
	elif caster:
		var t0 := Time.get_ticks_msec()
		while _player.animation == body and _player.frame < _contact(body) and Time.get_ticks_msec() - t0 < 1000:
			await get_tree().process_frame
			var follow := _cast_socket()
			if is_instance_valid(core):
				core.position = follow
			if is_instance_valid(sigil):
				sigil.position = follow
		hand_pos = _cast_socket()
		cast_log.append({"class": battle.class_id, "frame": "%s:%d" % [_player.animation, _player.frame], "socket": hand_pos})
	else:
		await _wait(0.09)
	var hits := events.filter(func(e): return e.kind == "hit")
	var count := 0
	var av7 := major and not hits.is_empty() and _av7_prepare()
	for ev in hits:
		var target := _enemy_torso(ev.index)
		var travel := 0.13 if count == 0 else 0.1
		if int(ev.consumed) > 0:
			_mark_converge(ev.index, target, int(ev.consumed), 0.09, travel - 0.09)
		if av7 and count == 0:
			_av7_flight(hand_pos, target, travel)
		await _core_shot(hand_pos, target, travel, core_px, core if count == 0 else null)
		_vfx("magic", target, 1.25 if major else 1.0)
		if _juice:
			_sparks(target, (target - hand_pos).normalized(), 0.8, 14 + (10 if major else 0), [C_ARCANE, Color.WHITE, C_MARK], true)
		if int(ev.consumed) > 0:
			_mark_burst(ev.index, target, int(ev.consumed))
		_impact_sfx(ev, "magic", count)
		var mp := _contact_profile(ev, "major" if major else "")
		_enemy_hit_feedback(ev, C_MARK, mp)
		if not marked.has(int(ev.index)):
			marked[int(ev.index)] = true
			_skill_mark(ckind, target, count)
		if not (av7 and count == 0 and _av7_contact(target, "payoff" if _av7_payoff(P2Catalog.upgrade_of(card) != "", [ev]) else "enhanced", Vector2.RIGHT, [_player, _enemy_sprites[ev.index]])):
			_camera_kick(mp, Vector2.RIGHT)
			if count == 0:
				_av7_light(target, "basic", Color(0.55, 0.9, 1.0))
		count += 1
		if card.is_aoe:
			continue
		await _hit_stop([_player, _enemy_sprites[ev.index]], float(IMPACT[mp].hold))
	if hits.is_empty() and is_instance_valid(core):
		core.queue_free()
	create_tween().tween_property(_player, "position:x", _home_x, 0.12)
	_pp_pose(Vector2(0.97, 1.03), -4.0, 0.08, 0.0, 0.32)
	_weapon_home(0.12)
	await _wait(0.12)


# 시전 문양: 짧게 커졌다 사라지는 강조 (계속 도는 회전 없음 — 픽셀이 기어다니지 않게)
func _sigil_flash(pos: Vector2, px: float, life: float) -> Sprite2D:
	var sg := _arcane_sprite("sigil", pos, px)
	var full := sg.scale
	sg.scale = full * 0.8
	sg.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(sg, "modulate:a", 1.0, 0.05)
	t.parallel().tween_property(sg, "scale", full, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_interval(maxf(0.0, life - 0.2))
	t.tween_property(sg, "modulate:a", 0.0, 0.15)
	t.tween_callback(sg.queue_free)
	return sg


# 마력 핵이 날아간다: 짧은 청록 꼬리 + 핵 그림. use가 있으면 모아 둔 핵을 그대로 쏜다
func _core_shot(from: Vector2, to: Vector2, duration: float, px: float, use: Sprite2D = null) -> void:
	var core := use if use != null and is_instance_valid(use) else _arcane_sprite("core", from, px)
	core.position = from
	var trail := Line2D.new()
	trail.width = maxf(3.0, px * 0.16)
	trail.default_color = Color(C_ARCANE, 0.55)
	trail.add_point(from)
	trail.add_point(from)
	_fxp.add_child(trail)
	var t := create_tween()
	t.tween_property(core, "position", to, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_method(func(p: Vector2) -> void:
		trail.set_point_position(1, p)
		trail.set_point_position(0, p.lerp(from, 0.3))
		if _juice and randf() < 0.6:
			_sparks(p, (from - to).normalized(), 0.5, 1, [C_ARCANE, Color.WHITE], false, Vector2(30, 90), 0.0), from, to, duration)
	await t.finished
	core.queue_free()
	var fade := create_tween()
	fade.tween_property(trail, "modulate:a", 0.0, 0.08)
	fade.tween_callback(trail.queue_free)


func _projectile(from: Vector2, to: Vector2, color: Color, duration: float) -> void:
	var dot := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(8):
		var a := TAU * i / 8.0
		pts.append(Vector2(cos(a), sin(a)) * (7.0 if i % 2 == 0 else 3.5))
	dot.polygon = pts
	dot.color = color
	dot.position = from
	_fxp.add_child(dot)
	var trail := Line2D.new()
	trail.width = 4.0
	trail.default_color = Color(color, 0.5)
	trail.add_point(from)
	trail.add_point(from)
	_fxp.add_child(trail)
	var t := create_tween()
	t.tween_property(dot, "position", to, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_method(func(p: Vector2) -> void:
		trail.set_point_position(1, p)
		trail.set_point_position(0, p.lerp(from, 0.35)), from, to, duration)
	await t.finished
	dot.queue_free()
	var fade := create_tween()
	fade.tween_property(trail, "modulate:a", 0.0, 0.08)
	fade.tween_callback(trail.queue_free)


# 물리 돌진: 앞줄(가장 가까운 살아 있는 적) 앞에서 멈춘다 — 뒤쪽 대상에게 달려가며 앞 적과 겹치지 않게
func _dash_x(kind: String, target: int) -> float:
	var front := 99999.0
	for i in range(_enemy_sprites.size()):
		if bool(_shown.enemies[i].alive):
			front = minf(front, _enemy_pos(i).x)
	if front > 9999.0:
		return _home_x + 90.0
	var stop := front - 132.0
	if target >= 0:
		stop = _enemy_pos(target).x - 132.0
	elif kind == "sweep":
		stop = front - 150.0
	return maxf(_home_x, stop)


# 물리: 기본 베기 = 짧은 준비 → 상아색 한 줄 베기 → 작은 반동 → 빠른 복귀.
# 얻은 강화(가르기·추격 등) = 무기를 한 번 들어 올리는 준비, 더 넓은 두 겹 호와 몸통 있는 소리. 가르기의 옆 타격은 실제 cleave 사건에서만
func _anim_physical(card: Card, kind: String, target: int, events: Array) -> void:
	var upgraded := P2Catalog.upgrade_of(card) != ""
	var ckind := P2Catalog.kind_of(card)
	var cut: bool = String(SKILL_SIG.get(ckind, "")) == "cut"
	var hits := events.filter(func(e): return e.kind == "hit")
	var spend := events.filter(func(e): return e.kind == "spend_block")
	# 사냥꾼 단검 · 룬술사 지팡이 끝: 둘 다 임시 공통 근접 동작 melee (접촉 3), 접촉 거리는 직업마다
	var dagger := _dressed and _art_cid in ["hunter", "rune_caster"]
	if kind in ["bash", "slam"] and not spend.is_empty():
		_apply_event(spend[0])
		if int(spend[0].amount) > 0:
			_sfx("guard", 0.8)
			_vfx("guard", _player_body(), 0.9)
			_float_number("방어 −%d" % spend[0].amount, _player_body() + Vector2(0, -40), C_BLOCK, 24, 30.0, 0.6)
			# 수호기사 방패 강타는 방어 소비를 먼저 보인 채 바로 준비 동작·접근으로 이어진다(기다림 대신 겹침). 다른 직업은 기존처럼 잠깐 멈춤
			if not _hires:
				await _wait(0.14)
	# 수호기사 방패 강타 = bash, 세 직업 휩쓸기 = sweep (무기 자리 표가 있는 동작). 나머지는 기존 동작
	var body_anim := ""
	if _hires:
		# 방패 강타·휩쓸기는 전용 동작, 그 밖의 한 대상 근접은 반격과 같은 검 타격(counter)
		body_anim = "bash" if kind == "slam" else (kind if kind in ["bash", "sweep"] else "counter")
	elif dagger:
		body_anim = "sweep" if kind == "sweep" else "melee"
	var socketed := body_anim != "" and _melee_socket(body_anim, _contact(body_anim)) != Vector2.INF
	var dest_x := _dagger_x(target) if dagger else _dash_x(kind, target)
	if socketed:
		# 접촉 프레임의 무기 자리가 실제 대상(휩쓸기는 맨 앞 실제 피격자) 몸 앞면에 오도록. 발은 바닥 그대로
		var first := target
		if first < 0 and not hits.is_empty():
			first = int(hits[0].index)
			for ev in hits:
				if _enemy_pos(int(ev.index)).x < _enemy_pos(first).x:
					first = int(ev.index)
		if first >= 0:
			dest_x = maxf(_home_x, _target_front(first).x - _melee_socket(body_anim, _contact(body_anim)).x)
	if upgraded and _weapon != null:
		var wh: Vector2 = _weapon.get_meta("home")
		_weapon_to(wh + Vector2(-4, -6), float(_weapon.get_meta("rot")) - 35.0, 0.07)
		await _wait(0.07)
	var sword := body_anim != ""
	var lead := 0.13
	if sword:
		lead = maxf(0.13, _actor_play(body_anim, 1 if dagger and body_anim == "melee" else 0))
	elif not _dressed:
		_player.play("thrust")
	_sfx("swing", 0.85 if upgraded or socketed else 1.0)
	var keep: Array = hits.map(func(e): return int(e.index))
	if target >= 0:
		keep.append(target)
	var pg := _pass_begin(_player, keep)
	var travel := clampf(absf(dest_x - _home_x) / 2600.0, 0.12, 0.18)
	if _juice and not _reduce_motion:
		var wind := String(_slash_trace.get("grade", "")) == "perfect" or cut
		_pp_pose(Vector2(1.1, 0.9) if wind else Vector2(1.06, 0.94), -13.0 if wind else -9.0, 0.13 if wind else 0.1, 0.0, 0.0)
		await _pull_back(_player, -30.0 if wind else -18.0, 0.13 if wind else 0.1)
		travel *= 0.7
		_afterimages(_player, travel + 0.04)
	var dash := _route_tween(_player, dest_x, travel, true)
	_pp_pose(Vector2(0.94, 1.06), 8.0, travel, 0.0, 0.0)
	route_log.append({"actor": "player", "anim": body_anim, "from": _home_x, "to": dest_x, "target": target, "pass": pg})
	# 표식이 있으면 맞기 직전(약 90ms)에 몸으로 모인다
	for ev in hits:
		if int(ev.get("hit_index", 0)) == 0 and int(ev.consumed) > 0:
			_mark_converge(ev.index, _enemy_torso(ev.index), int(ev.consumed), 0.09, maxf(0.0, maxf(lead, travel) - 0.09))
	if socketed:
		# 준비 자세(1)로 들어 올린 채 다가가고, 닿는 자리에 도착하면 접촉 프레임(2)
		await _await_frame(body_anim, 1, 0.3)
		if _player.animation == body_anim:
			_player.pause()
		if dash.is_running():
			await dash.finished
		if _player.animation == body_anim and not _player_down:
			_player.play(body_anim)
			if _art.has("sockets"):
				# 새 수호기사: 준비 자세에서 그대로 이어 접촉 프레임까지 (접촉 프레임은 동작마다 다름)
				await _await_frame(body_anim, _contact(body_anim))
			else:
				_player.frame = 2
	elif sword:
		await _wait(0.12)
		if dash.is_running():
			await dash.finished
		await _await_frame(body_anim, _contact(body_anim))
	else:
		await _wait(lead)
		if dash.is_running():
			await dash.finished
	# 연속 타격(쌍격)은 타격마다 따로 보여 준다: 첫 타가 표식을 터뜨리고, 둘째 타는 그다음
	var waves := {}
	for ev in hits:
		var k := int(ev.get("hit_index", 0))
		if not waves.has(k):
			waves[k] = []
		(waves[k] as Array).append(ev)
	var order: Array = waves.keys()
	order.sort()
	for k in order:
		var wave: Array = waves[k]
		if int(k) > 0:
			var again := 0.09
			if sword:
				again = _actor_play(body_anim, 2 if dagger else 1)
			elif not _dressed:
				_player.play("thrust")
				_player.frame = 2
			_sfx("swing", 1.2)
			for ev in wave:
				if int(ev.consumed) > 0:
					_mark_converge(ev.index, _enemy_torso(ev.index), int(ev.consumed), 0.08, maxf(0.0, again - 0.08))
			if sword:
				await _await_frame(body_anim, _contact(body_anim))
			else:
				await _wait(again)
		_pp_pose(Vector2(1.09, 0.92), 15.0, 0.04, 0.0, 0.0)
		var hit_sprites: Array = [_player]
		var prof := "light"
		if body_anim == "sweep" and socketed:
			_sweep_trail(wave)
		for ev in wave:
			var pos := _enemy_torso(ev.index)
			if ev.consumed > 0:
				_mark_burst(ev.index, pos, ev.consumed)
			if bool(ev.get("pierce", false)):
				_vfx("counter", pos, 1.1)
			if body_anim == "bash" and socketed:
				# 방패 앞면이 닿는 둔탁한 접촉 (칼 호·베기 그림 대신)
				hit_sprites.append(_contact_fx("body_contact", pos))
			elif body_anim == "sweep" and socketed:
				hit_sprites.append(_contact_fx("slash_contact", pos, false, 0.8))
			else:
				_strike_arc(pos, upgraded or kind in ["bash", "slam"], int(k) % 2 == 1)
				_vfx("slash_major" if upgraded else "slash", pos, 1.4 if upgraded or kind in ["bash", "slam"] else 1.05, int(k) % 2 == 0)
			var ep := _contact_profile(ev, "major" if upgraded or kind in ["bash", "slam"] or cut else "")
			prof = _stronger(prof, ep)
			hit_sprites.append(_enemy_sprites[ev.index])
			if cut:
				cut = false
				_hit_stop([_player, _enemy_sprites[ev.index]], 0.54)
				await _space_cut(_to_ui(pos), _stroke_dir())
			_enemy_hit_feedback(ev, Color("#ffd2a0"), ep)
			_skill_mark(ckind, pos, int(k))
		melee_log.append({"anim": body_anim, "frame": "%s:%d" % [_player.animation, _player.frame], "x": _player.position.x, "y": _player.position.y,
			"socket": (_player.position + _melee_socket(body_anim, _contact(body_anim))) if socketed else Vector2.INF, "victims": wave.map(func(e): return int(e.index)), "f": Engine.get_process_frames()})
		_impact_sfx(wave[0], "bash" if kind in ["bash", "slam"] else ("major" if upgraded else "basic"), int(k))
		_camera_kick(prof, Vector2.RIGHT)
		if int(k) == int(order[0]):
			_av7_light(_enemy_torso(int(wave[0].index)), "basic", Color(1.0, 0.86, 0.6))
		await _hit_stop(hit_sprites, float(IMPACT[prof].hold))
		await _wait(0.13 if k == order.back() else 0.1)
	if not sword:
		_player.play("idle")
	_weapon_home(0.12)
	var back := _route_tween(_player, _home_x, clampf(absf(_player.position.x - _home_x) / 3000.0, 0.12, 0.18), false)
	await back.finished
	_player.position = Vector2(_home_x, FEET_Y)
	_pass_end(pg)


# 지금 동작의 근접 무기 자리(화면 px, 발 기준). 표가 없으면 Vector2.INF
func _melee_socket(anim: String, f: int) -> Vector2:
	var t: Dictionary = ((_art.sockets as Dictionary) if _art.has("sockets") else (MELEE_SOCKETS.get(_art_cid, {}) as Dictionary)).get(anim, {})
	if not t.has(f):
		return Vector2.INF
	return (t[f] as Vector2) * _player.scale.x


# 실제 대상 몸의 가까운 앞면(몸통 높이): 몸통 x에서 그린 너비의 1/4 앞
func _target_front(i: int) -> Vector2:
	return _enemy_torso(i) - Vector2(_visible_size(i).x * 0.25, 0.0)


# 가는 길(x0 → x1) 사이에 서 있는 살아 있는 다른 적. skip은 대상(그 몸에는 닿아야 하므로 비켜 가지 않음)
# 바닥 줄을 따라 곧게 움직이기(표현만). 트윈은 이 화면의 것이라 게임 멈춤·저장 창에서 함께 멈추고, 장면을 나가면 사라진다
func _route_tween(node: Node2D, x1: float, dur: float, ease_out: bool, trans := Tween.TRANS_QUAD) -> Tween:
	node.position.y = FEET_Y
	var t := create_tween()
	t.tween_property(node, "position:x", x1, dur).set_trans(trans).set_ease(Tween.EASE_OUT if ease_out else Tween.EASE_IN)
	return t


# 지나가기 표현의 주인 하나(세대 번호): 공격자 앞 그림(z)과 겹친 몸의 흐림을 함께 가진다.
# 흐림은 self_modulate 알파에만 곱해 쓰므로 쓰러짐(modulate)·번쩍임(재질)·맥 흐름과 섞이고, 끝나면 처음 값으로 돌린다
func _pass_begin(mover: Node2D, keep: Array) -> int:
	_pass_drop("superseded")
	_pass_gen += 1
	_pass = {"gen": _pass_gen, "mover": mover, "keep": keep, "live": true, "fade": {}, "base": {}, "low": {}}
	mover.z_index = 1
	return _pass_gen


# 움직임이 끝남: 앞 그림은 바로 내려놓고, 흐린 몸은 _tick_pass가 짧게 되돌린 뒤 주인을 비운다
func _pass_end(gen: int) -> void:
	if _pass.is_empty() or int(_pass.gen) != gen:
		return
	_pass.live = false
	var m: Node2D = _pass.mover
	if is_instance_valid(m):
		m.z_index = 0


# 끊김(새 주인·씬 정리): 가진 것만 즉시 원래대로
func _pass_drop(why: String) -> void:
	if _pass.is_empty():
		return
	for i in (_pass.fade as Dictionary).keys():
		if i < _enemy_sprites.size() and is_instance_valid(_enemy_sprites[i]):
			_enemy_sprites[i].self_modulate.a = float(_pass.base[i])
	var m: Node2D = _pass.mover
	if is_instance_valid(m):
		m.z_index = 0
	pass_log.append({"gen": int(_pass.gen), "end": why, "low": (_pass.low as Dictionary).duplicate()})
	_pass = {}


func _pass_candidate(i: int, mover: Node2D) -> bool:
	var sp := _enemy_sprites[i]
	return is_instance_valid(sp) and sp != mover and sp.visible and not (_pass.keep as Array).has(i) and bool(_shown.enemies[i].alive) \
		and not bool(sp.get_meta("dying", false)) and not bool(sp.get_meta("consumed", false)) and not bool(sp.get_meta("dashing", false))


# 지금 몸이 칠해진 가로 범위(화면 px). 맥 그림은 그림표 left/right, 주인공은 body_l/body_r, 옛 그림은 칠해진 너비(처음 한 번 재서 보관)
func _body_span(node: Node2D) -> Vector2:
	var x := node.position.x
	if node == _player:
		if _dressed and _art.has("body_l"):
			return Vector2(x + float(_art.body_l) * _player.scale.x, x + float(_art.body_r) * _player.scale.x)
		return Vector2(x - 40.0, x + 40.0)
	if node.has_meta("art"):
		var a: Dictionary = _ea(node.get_meta("art"))
		var fx := float((a.foot as Vector2).x)
		var k := absf(node.scale.x)
		return Vector2(x + (float(a.left) - fx) * k, x + (float(a.right) - fx) * k)
	if not node.has_meta("pass_w"):
		node.set_meta("pass_w", _visible_size(_enemy_sprites.find(node)).x)
	var w := float(node.get_meta("pass_w"))
	return Vector2(x - w * 0.5, x + w * 0.5)


func _tick_pass(delta: float) -> void:
	if _pass.is_empty():
		return
	var m: Node2D = _pass.mover
	var moving := bool(_pass.live) and is_instance_valid(m) and not bool(m.get_meta("dying", false))
	var span := _body_span(m) if moving else Vector2.ZERO
	var fade: Dictionary = _pass.fade
	for i in range(_enemy_sprites.size()):
		var sp := _enemy_sprites[i]
		var cand := moving and _pass_candidate(i, m)
		if not cand and not fade.has(i):
			continue
		if not is_instance_valid(sp):
			fade.erase(i)
			continue
		var want := 1.0
		if cand:
			var o := _body_span(sp)
			if minf(span.y, o.y) - maxf(span.x, o.x) > PASS_MIN:
				want = PASS_ALPHA
		if not fade.has(i):
			if want == 1.0:
				continue
			fade[i] = 1.0
			_pass.base[i] = sp.self_modulate.a
		var cur := move_toward(float(fade[i]), want, delta * (1.0 - PASS_ALPHA) / (PASS_FADE_IN if want < float(fade[i]) else PASS_FADE_OUT))
		# 흐린 채 쓰러지는 몸은 다시 밝히지 않고 사라질 때까지 둔다
		if bool(sp.get_meta("dying", false)) and sp.visible and sp.modulate.a > 0.01:
			cur = float(fade[i])
		fade[i] = cur
		_pass.low[i] = minf(float(_pass.low.get(i, 1.0)), cur)
		sp.self_modulate.a = float(_pass.base[i]) * cur
		if cur >= 1.0:
			sp.self_modulate.a = float(_pass.base[i])
			fade.erase(i)
	if not bool(_pass.live) and fade.is_empty():
		pass_log.append({"gen": int(_pass.gen), "end": "done", "low": (_pass.low as Dictionary).duplicate()})
		_pass = {}


# 휩쓸기 궤적: 무기 자리(프레임 1 → 2)에서 시작해 실제 피격자들의 몸통 줄을 지나 조금 더. 코드로 그린 상아색 선(마법 색 아님)
func _sweep_trail(wave: Array) -> void:
	var base := _player.position
	var hit := _melee_socket("sweep", _contact("sweep"))
	var s1 := _melee_socket("sweep", 1)
	var s2 := _melee_socket("sweep", 2)
	if s2 == Vector2.INF:
		s2 = hit
	if s1 == Vector2.INF:
		s1 = s2 + Vector2(-50, -46)
	var a := base + s1
	var b := base + s2
	var c := (a + b) * 0.5 + Vector2(-10, -70)
	var pts := PackedVector2Array()
	for i in range(8):
		var t := i / 7.0
		pts.append(a.lerp(c, t).lerp(c.lerp(b, t), t))
	var vs: Array = wave.map(func(e): return _enemy_torso(int(e.index)))
	vs.sort_custom(func(p, q): return p.x < q.x)
	for p in vs:
		var last: Vector2 = pts[pts.size() - 1]
		if (p as Vector2).x > last.x:
			# 피격자 사이는 곧은 광선처럼 보이지 않게 살짝 처지는 호
			pts.append(last.lerp(p, 0.5) + Vector2(0, 9))
			pts.append(p)
	pts.append(pts[pts.size() - 1] + Vector2(46, 16))
	var tint: Color = {"warden": C_GOLD, "hunter": Color(0.82, 0.9, 0.96), "rune_caster": Color(0.95, 0.9, 0.78)}.get(_art_cid, C_GOLD)
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.25))
	curve.add_point(Vector2(0.45, 1.0))
	curve.add_point(Vector2(1.0, 0.35))
	for layer in [[tint, 10.0, 0.45], [C_IVORY, 4.0, 0.95]]:
		var line := Line2D.new()
		line.points = pts
		line.width = float(layer[1])
		line.width_curve = curve
		line.default_color = Color(layer[0], float(layer[2]))
		line.joint_mode = Line2D.LINE_JOINT_ROUND
		line.antialiased = true
		_fxp.add_child(line)
		var tw := line.create_tween()
		tw.tween_interval(0.05)
		tw.tween_property(line, "modulate:a", 0.0, 0.14)
		tw.tween_callback(line.queue_free)
	melee_log.append({"trail": pts.size(), "from": a, "to": pts[pts.size() - 1]})


# 수호기사 베기(kind == "slash"만): 배우는 제자리에서 1자세부터 베고, 검 접촉 프레임(2)에 칼끝에서 파동이 출발해
# 실제 대상의 몸 중심까지 날아간다(비행 중 그림이 바뀜). 도착 순간에만 접촉 그림 + 기존 타격 처리(피해·표식·치명·처치)를 한 번.
# 강화 사본(upgrade_of != "")은 major, 아니면 basic. 가르기·추격 같은 후속은 기존 _anim_followups 그대로
func _anim_warden_wave(card: Card, events: Array) -> void:
	var tier := "major" if P2Catalog.upgrade_of(card) != "" else "basic"
	var token := _action_token
	var hits := events.filter(func(e): return e.kind == "hit")
	var waves := {}
	for ev in hits:
		var k := int(ev.get("hit_index", 0))
		if not waves.has(k):
			waves[k] = []
		(waves[k] as Array).append(ev)
	var order: Array = waves.keys()
	order.sort()
	_blade_tier = tier
	var av7 := tier == "major" and not order.is_empty() and _av7_prepare()
	if order.is_empty():
		_warden_pose(1)
		_sfx("swing", 0.85 if tier == "major" else 1.0)
		await _wait(WAVE_PREP + WAVE_RELEASE)
		_finish_wave(token)
		return
	for k in order:
		var wave: Array = waves[k]
		_trail_cut = false
		# 대상 위치·비행 시간은 출발 전에 정한다 (맞고 쓰러지면 패널·그림이 사라지므로). 뒤쪽 적도 실제 대상 그대로
		var to := _enemy_torso(int(wave[0].index))
		var tip := _player.position + (_art.get("tip", WARDEN_TIP) as Vector2) * _player.scale.x
		var dist := to.x - tip.x
		var travel := 0.18 + clampf((dist - 300.0) / 400.0, 0.0, 1.0) * 0.03
		for ev in wave:
			if int(ev.consumed) > 0:
				_mark_converge(ev.index, _enemy_torso(ev.index), int(ev.consumed), 0.09, maxf(0.0, WAVE_PREP + travel - 0.09))
		_warden_pose(1)
		_sfx("swing", 0.85 if tier == "major" else (1.2 if int(k) > 0 else 1.0))
		await _wait(WAVE_PREP)
		if not _wave_alive(token):
			return
		_warden_pose(2)
		var crest := _spawn_crescent(tier, tip, to)
		if av7 and int(k) == int(order[0]):
			_av7_flight(tip, to, travel)
		_cut_trail_later(token, float(WAVE_TRAIL_CLEAR[tier]))
		var fly := create_tween()
		fly.tween_property(crest, "position", to, travel).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		await _wait(WAVE_RELEASE)
		if not _wave_alive(token):
			return
		_warden_pose(3)
		await fly.finished
		if not _wave_alive(token):
			return
		# 도착: 비행 파동은 바로 지우고, 그 자리에 새 접촉 + 실제 타격 표시를 먼저 → 그다음 짧은 정지
		if is_instance_valid(crest):
			crest.queue_free()
		var prof := "light"
		var focus := false
		var held: Array = [_player]
		for ev in wave:
			var i := int(ev.index)
			var pos := _enemy_torso(i)
			var ep := _contact_profile(ev, tier)
			prof = _stronger(prof, ep)
			if tier == "major":
				held.append(_contact_fx("slash_major_contact", pos, true))
				held.append(_contact_fx("slash_contact", pos, false, 0.6))
			else:
				held.append(_contact_fx("slash_contact", pos))
			if int(ev.consumed) > 0:
				_mark_burst(i, pos, int(ev.consumed))
				focus = focus or tier == "major"
			if bool(ev.dead) and _is_boss_index(i):
				focus = true
			held.append(_enemy_sprites[i])
			_enemy_hit_feedback(ev, Color("#ffd2a0"), ep)
		_impact_sfx(wave[0], tier, int(k))
		var cpos := _enemy_torso(int(wave[0].index))
		if not (av7 and int(k) == int(order[0]) and _av7_contact(cpos, "payoff" if _av7_payoff(true, wave) else "enhanced", Vector2.RIGHT, [_player] + held)):
			_camera_kick(prof, Vector2.RIGHT, focus)
			if int(k) == int(order[0]):
				_av7_light(cpos, "basic", Color(1.0, 0.86, 0.6))
		await _hit_stop(held, float(IMPACT[prof].hold))
		if not _wave_alive(token):
			return
		_warden_pose(4)
		await _wait(WAVE_RECOVER)
	_finish_wave(token)


func _warden_pose(f: int) -> void:
	if _player_down:
		return
	if _player.animation != "slash":
		_player.play("slash")
	_player.pause()
	_player.frame = f
	# SD 몸짓: 1 칼을 뒤로 당겨 웅크림 → 2 앞으로 늘어나며 내려 벰 → 3 휘두른 끝에서 튕기듯 바로 섬
	match f:
		1:
			_pp_pose(Vector2(1.07, 0.93), -11.0, 0.1, 0.0, 0.0)
		2:
			_pp_pose(Vector2(0.91, 1.09), 15.0, 0.05, 0.0, 0.0)
		3:
			_pp_pose(Vector2(1.03, 0.97), 9.0, 0.06, 0.05, 0.32)


func _wave_alive(token: int) -> bool:
	return is_inside_tree() and token == _action_token and not _player_down


func _finish_wave(token: int) -> void:
	_blade_tier = ""
	_trail_cut = false
	if token == _action_token and not _player_down and is_inside_tree():
		_player.play("idle")


# 잔상 지우기(따라가기 자세는 그대로) — 다음 행동의 겹침을 숨기지 않도록 행동 표식으로 막는다
func _cut_trail_later(token: int, delay: float) -> void:
	await _wait(delay)
	if is_inside_tree() and token == _action_token and _player.animation == "slash":
		_trail_cut = true
		_update_blade_overlay()


# 지금 동작의 접촉 프레임까지 남은 시간(초) — 표식이 도착 순간에 맞춰 모이도록
func _contact_time_left(anim: String) -> float:
	var times: Array = _art.anims[anim][0]
	var t := 0.0
	for i in range(_player.frame, _contact(anim)):
		t += float(times[i]) / 1000.0
	return t


# 파동 하나: 앞날 기준점을 위치로 쓰고(텍스처 가운데가 아님) 대상 쪽으로 돌린다. 발사 그림이 끝나면 비행 그림을 반복, 접촉 그림이 끝나면 스스로 사라짐
func _spawn_crescent(tier: String, from: Vector2, to: Vector2) -> AnimatedSprite2D:
	var w := AnimatedSprite2D.new()
	w.sprite_frames = _crescent_frames_for(tier)
	w.centered = false
	w.offset = -CRESCENT_ANCHOR
	w.scale = Vector2.ONE * float(CRESCENT[tier].scale)
	w.rotation = (to - from).angle()
	w.position = from
	w.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_fx.add_child(w)
	w.animation_finished.connect(func() -> void:
		if not is_instance_valid(w):
			return
		if w.animation == "launch":
			w.play("flight")
		elif w.animation == "contact":
			w.queue_free())
	w.play("launch")
	crescent_log.append({"tier": tier, "from": from, "to": to})
	return w


# 맞는 순간의 소리: 주된 타격 하나 + (강화·치명·방패 강타일 때) 몸통 하나. 크기보다 음색으로 구분한다
func _impact_sfx(ev: Dictionary, family: String, k := 0) -> void:
	var crit := bool(ev.get("crit", false))
	var p := 1.0 + 0.08 * k
	var weight := false
	match family:
		"magic":
			_sfx("magic_hit", p * (0.9 if crit else 1.0))
		"bash":
			_sfx("bash", p)
		"major", "aimed":
			_sfx("slash_major", p)
			weight = true
		_:
			_sfx("crit" if crit else "sword_hit", p)
			weight = crit
	if weight or (crit and family == "magic"):
		_sfx("weight", 1.0)
	if int(ev.get("consumed", 0)) > 0:
		_sfx_later("mark", MARK_PEAK_OFFSET, -2.0)


func _sfx_later(key: String, delay: float, volume_offset := 0.0) -> void:
	var token := _action_token
	await _wait(delay)
	if is_inside_tree() and token == _action_token:
		_sfx(key, 1.0, volume_offset)


# 무기 호: 맞는 자리를 지나는 짧은 상아색 호(코드로 그림). 강화는 더 넓고 금빛 테두리가 한 겹 더
func _strike_arc(pos: Vector2, major: bool, flip: bool) -> void:
	var r := 46.0 if major else 34.0
	var a0 := deg_to_rad(-60.0 if not flip else 60.0)
	var a1 := deg_to_rad(70.0 if not flip else -70.0)
	var pts := PackedVector2Array()
	for i in range(9):
		var a := lerpf(a0, a1, i / 8.0)
		pts.append(pos + Vector2(cos(a) * r * 0.55 - 6.0, sin(a) * r))
	for layer in ([C_GOLD, C_IVORY] if major else [C_IVORY]):
		var line := Line2D.new()
		line.points = pts
		line.width = (9.0 if major else 5.0) if layer == C_GOLD else (5.0 if major else 4.0)
		line.default_color = layer
		line.begin_cap_mode = Line2D.LINE_CAP_NONE
		line.end_cap_mode = Line2D.LINE_CAP_NONE
		line.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_fxp.add_child(line)
		var t := create_tween()
		t.tween_interval(0.05)
		t.tween_property(line, "modulate:a", 0.0, 0.12)
		t.tween_callback(line.queue_free)


# 표식 터짐 1: 표식 칸의 표식 그림이 몸으로 모인다 (delay 뒤 dur 동안). 실제 개수는 맞는 순간 사건으로만 바뀐다
func _mark_converge(index: int, to: Vector2, count: int, dur: float, delay: float) -> void:
	var panel: Dictionary = _enemy_panels[index]
	var icon: Control = (panel.marks as Control).get_meta("icon")
	var origin: Vector2 = icon.get_global_rect().get_center()
	for i in range(mini(count, 3)):
		var em := _arcane_sprite("mark", origin + Vector2((i - (mini(count, 3) - 1) / 2.0) * 14.0, 0), 20.0, true)
		var t := create_tween()
		if delay > 0.0:
			t.tween_interval(delay)
		t.tween_property(em, "position", to, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_property(em, "scale", em.scale * 0.45, 0.04)
		t.tween_callback(em.queue_free)


# 표식 터짐 2 (맞는 순간): 안으로 접혔다가 청록 조각이 바깥으로 튄다. 피해 숫자는 타격 사건에서 한 번만
func _mark_burst(index: int, pos: Vector2, count: int) -> void:
	# 실제 소모는 타격 순간 한 번 반영됨. 청록 빈 고리의 최고점만 약 45ms 뒤 몸 뒤에 (숫자·피해와 무관한 겉모습)
	_contact_fx_later("mark_rupture", pos, MARK_PEAK_OFFSET, true)


# 표식이 실제로 늘어난 순간: 표식 그림이 잠깐 커지고 맑은 소리 하나
func _mark_pulse(index: int) -> void:
	var icon: Control = (_enemy_panels[index].marks as Control).get_meta("icon")
	icon.scale = Vector2.ONE * 1.5
	icon.modulate = Color(1.8, 1.8, 1.8)
	var t := create_tween()
	t.tween_property(icon, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(icon, "modulate", Color.WHITE, 0.18)
	_sfx("mark", 1.0)


func _enemy_hit_feedback(ev: Dictionary, color: Color, profile := "") -> void:
	var i := int(ev.index)
	var sprite := _enemy_sprites[i]
	var prof := profile if profile != "" else _contact_profile(ev)
	var pos := _enemy_torso_now(i) if sprite.get_meta("dashing", false) else _enemy_torso(i)
	var crit_hit := String(ev.kind) == "hit" and bool(ev.get("crit", false))
	var p: Dictionary = IMPACT[prof]
	_actor_flash(sprite, C_CRIT if crit_hit else Color(1.0, 0.97, 0.9), float(p.get("flash", 0.6)), float(p.get("fpeak", 0.02)), float(p.get("fclear", 0.05)))
	var main_hit := String(ev.kind) == "hit"
	var hdir := _stroke_dir() if main_hit else Vector2.RIGHT
	_victim_react(sprite, prof, hdir, bool(ev.dead))
	if int(ev.damage) > 0:
		_art_hurt(sprite, bool(ev.dead), int(ev.get("shield_left", -1)))
	elif int(ev.get("shield_block", 0)) > 0:
		_shield_absorb(sprite, int(ev.shield_left))
	if prof == "secondary":
		_camera_kick("secondary", Vector2.RIGHT)
	if _t_contact < 0.0 and _t_play > 0:
		_t_contact = Time.get_ticks_msec() - _t_play
	var main := String(ev.kind) == "hit"
	if main:
		_slash_replay()
		if _juice:
			_juice_hit(sprite, pos, int(ev.damage), crit_hit, hdir)
		_hit_trail(pos, hdir, prof == "heavy" or bool(ev.dead), crit_hit)
		_hit_bits(pos, hdir, crit_hit or bool(ev.dead))
		if _show != null and not _reduce_motion:
			_show.garnish(ev, pos, hdir)
	# 흑백 임팩트 프레임: 처치의 주 타격이면 행동당 한 번. 긋기 전투에서는 완벽 긋기가 곧 치명이라 매번 뜨면 카드마다 다른 연출을 덮으므로
	# 치명만으로는 띄우지 않는다(긋기 없는 전투는 예전처럼 치명에도). 강화 payoff 경로와 같은 표식으로 중복 없음
	if main and (bool(ev.dead) or int(ev.damage) >= BIG_IMPACT or (crit_hit and _slash_trace.is_empty())) and _av7_on() and _av7_payoff_token != _action_token:
		_av7_payoff_token = _action_token
		_av7_payoff_beat([_player, sprite], pos)
	var big := prof == "heavy" or int(ev.damage) >= DMG_BIG
	var tone := "zero" if int(ev.damage) <= 0 else ("magic" if bool(ev.get("magic", false)) else "phys") if main else String(DMG_TONE_OF.get(String(ev.kind), "phys"))
	if crit_hit:
		_vfx("crit", pos, 0.9)
		if _crit_label_token != _action_token:
			_crit_label_token = _action_token
			_world_number(("확정 치명타!" if bool(ev.get("forced", false)) else (("완벽한 문양!" if bool(_slash_trace.get("rune", false)) else ({"hunter": "완벽한 사격!", "combo": "완벽한 타격!"}.get(battle.class_id, "완벽한 베기!"))) if String(_slash_trace.get("grade", "")) == "perfect" else "치명타!")), pos + Vector2(0, -150), C_CRIT, 24, 24.0, 0.9)
		_damage_number(str(ev.damage), pos + Vector2(0, -56), "crit", 72 if big else 60, 1.8)
		_display_log.append({"frame": Engine.get_process_frames(), "kind": "crit_shown", "index": i, "damage": int(ev.damage), "forced": bool(ev.get("forced", false))})
	elif main:
		_damage_number(str(ev.damage), pos + Vector2(0, -56), tone, 48 if big and tone != "zero" else 36, 1.45 if big else 1.2)
	else:
		# 딸린 타격 숫자는 작게, 본타 숫자와 겹치지 않게 옆으로
		_damage_number(str(ev.damage), pos + Vector2(40, -12), tone, 24)
	if int(ev.get("shield_block", 0)) > 0:
		_world_number(tr("방패 −%d") % int(ev.shield_block), pos + Vector2(-60, -60), C_BLOCK, F, 24.0, 0.9)
	if int(ev.get("consumed", 0)) > 0:
		# 표식 피해는 위 실제 피해 숫자에 이미 들어 있다 → 두 번째 큰 숫자 대신 작은 청록 표시만
		_world_number(tr("표식 %d 터짐") % int(ev.consumed), pos + Vector2(0, -78), C_MARK, F, 30.0, 0.9)
	elif bool(ev.get("pierce", false)):
		_world_number(tr("갑옷 무시"), pos + Vector2(50, -8), Color("#ffd2a0"), F, 24.0, 0.7)
	elif int(ev.get("armor", 0)) > 0 and main:
		_world_number(tr("갑옷 −%d") % int(ev.armor), pos + Vector2(50, -8), Color("#c9d2da"), F, 24.0, 0.7)
	_apply_event(ev)


func _enemy_death(index: int) -> void:
	var sprite := _enemy_sprites[index]
	if sprite.get_meta("dying", false):
		return
	sprite.set_meta("dying", true)
	if sprite.has_meta("art"):
		(sprite.material as ShaderMaterial).set_shader_parameter("flow_amount", 0.0)
	var p: Dictionary = _enemy_panels[index]
	(p.root as Control).visible = false
	# 지원자가 쓰러지면 다른 적 예고의 지원 +N을 이 순간 다시 그린다 (_shown_aura는 화면에 옮겨진 생존만 본다)
	if int(P2Catalog.ENEMIES[battle.roles[index]].get("aura", 0)) > 0:
		for k in range(_enemy_panels.size()):
			if k != index:
				_render_enemy(k, false)
	var art_d: Dictionary = _ea_or(String(sprite.get_meta("art", "")))
	_sfx(String(art_d.get("death_sfx", "death_" + battle.monsters[index].monster_type)))
	if _art_acts(sprite) and (art_d.actions as Dictionary).has("defeat"):
		_art_defeat(sprite)
	elif _art_acts(sprite):
		# 쓰러짐 그림이 없으므로 피격 자세로 멈춘 채 흐려짐 (대기 원본으로 돌아가지 않음)
		_art_claim(sprite)
		sprite.set_meta("art_busy", false)
		if not (sprite.animation == "hurt" and sprite.frame == 1):
			_art_pose(sprite, "hurt", 1)
	else:
		_set_enemy_anim(sprite, "death")
	var t := create_tween()
	t.tween_interval(0.55)
	t.tween_property(sprite, "modulate:a", 0.0, 0.3)
	if not _final_done and battle.battle_over and int(GameState.get_flag("player_hp")) > 0:
		_final_done = true
		_final_blow(index)


# 마지막 적이 쓰러지는 순간(한 전투에 한 번): 상아색 실루엣 한순간 → 세계 시간 0.3배로 실제 0.45초, 그 적 쪽 줌 1.1,
# 충격파 고리 · 색 분리 · 큰 파편과 빛. 시간 배율은 원래 값으로 되돌린다(점검 봇이 2배로 돌려도)
func _final_blow(index: int) -> void:
	if not _juice or _stage == null:
		return
	var at := _enemy_torso(index)
	final_log.append({"final": index, "ms": Time.get_ticks_msec()})
	if _av7_on():
		_av7_mono = _av7_silhouettes([_player, _enemy_sprites[index]])
		var mono: Node2D = _av7_mono
		get_tree().create_timer(0.09, true, false, true).timeout.connect(func() -> void:
			if is_instance_valid(mono):
				mono.queue_free())
		_av7_fx.center = _to_ui(at)
		_av7_ring(6.0, 320.0, 0.8)
		var tw := create_tween()
		tw.tween_method(func(x: float) -> void: _av7_set("chroma_px", x), 3.2, 0.0, 0.5).set_ease(Tween.EASE_OUT)
	var prev := Engine.time_scale
	Engine.time_scale = prev * 0.3
	get_tree().create_timer(0.45, true, false, true).timeout.connect(func() -> void: Engine.time_scale = prev)
	if _cam != null:
		if _tension_tw != null and _tension_tw.is_valid():
			_tension_tw.kill()
		_tension_tw = create_tween()
		var off := (at - Vector2(640, 360)) * 0.22
		_tension_tw.tween_method(_set_cam_base_z, _cam_base_z, 1.1, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_tension_tw.parallel().tween_method(_set_cam_base_off, _cam_base_off, off, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_tension_tw.tween_interval(0.25)
		_tension_tw.tween_method(_set_cam_base_z, 1.1, 1.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_tension_tw.parallel().tween_method(_set_cam_base_off, off, Vector2.ZERO, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_av7_light(at, "payoff", Color(1.0, 0.92, 0.7))
	var s := P2Sparks.new()
	s.burst(at, Vector2.UP, PI, 48, Vector2(160.0, 560.0), [Color.WHITE, C_GOLD, C_IVORY, Color("#ffcf4a")], Vector2i(2, 6), 1.0, 640.0)
	_fxp.add_child(s)
	_shake(6.0)


func _anim_followups(events: Array) -> void:
	for ev in events:
		match String(ev.kind):
			"slam_splash":
				var qpos := _enemy_torso(ev.index)
				_sfx("bash", 0.9, -4.0)
				P2SkillFx.spawn(_fx_back, "quake", Vector2(qpos.x, FEET_Y - 2.0), Vector2.RIGHT, 0.8, P2Catalog.CLASS_COLOR.warden)
				P2HitBits.spawn(_fxp, "chunk", Vector2(qpos.x, FEET_Y - 12.0), Vector2.UP, 10, [Color("#7a6a58"), Color("#b8ad9e"), Color("#5a4c40")], 1.1)
				_enemy_hit_feedback(ev, C_GOLD)
				_float_number(tr("여파 %d") % int(ev.damage), qpos + Vector2(0, -96), C_GOLD, F, 20.0, 0.7)
				await _wait(0.08)
			"chain":
				var from := _enemy_torso(ev.origin)
				var cpos2 := _enemy_torso(ev.index)
				_lightning(from, cpos2)
				_sfx("arc", 1.5, -4.0)
				P2SkillFx.spawn(_fxp, "chain", cpos2, Vector2.RIGHT, 0.7, C_ARCANE)
				_enemy_hit_feedback(ev, C_MARK)
				_float_number(tr("연쇄 %d") % int(ev.damage), cpos2 + Vector2(0, -96), C_MARK, F, 20.0, 0.7)
				await _wait(0.1)
			"arc":
				_relic_pulse("arc")
				var from := _enemy_torso(ev.origin)
				var to := _enemy_torso(ev.index)
				_lightning(from, to)
				_sfx("arc", 1.7)
				await _wait(0.1)
				_vfx("arc", to, 0.8)
				_enemy_hit_feedback(ev, C_BLOCK)
				_float_number("방전 고리", to + Vector2(0, -92), C_BLOCK, F, 20.0, 0.7)
				await _wait(0.16)
			"arc_skip":
				_log_display(ev)
			"cleave":
				var cpos := _enemy_torso(ev.index)
				if int(ev.get("origin", -1)) >= 0:
					_follow_through(_enemy_torso(int(ev.origin)), cpos)
					await _wait(0.06)
				if _hires:
					_contact_fx("slash_contact", cpos, false, 0.8)
				else:
					_strike_arc(cpos, false, true)
					_vfx("slash", cpos, 0.8, false)
				_sfx("sword_hit", 1.3, -3.0)
				_enemy_hit_feedback(ev, Color("#ffd2a0"))
				_float_number("가르기", cpos + Vector2(0, -92), Color("#ffd2a0"), F, 20.0, 0.7)
				await _wait(0.12)
			"inscribe":
				var ipos := _enemy_torso(ev.index)
				_vfx("magic", ipos, 0.6)
				_apply_event(ev)
				_float_number("이중 각인 +1", ipos + Vector2(0, -96), C_MARK, F, 22.0, 0.8)
				await _wait(0.12)
			"suppress":
				var upos := _enemy_torso(ev.index)
				_sfx("suppress", 1.2)
				_vfx("prepare", upos, 0.8)
				_apply_event(ev)
				_float_number("억제 −%d" % ev.amount, upos + Vector2(0, -110), C_BLOCK, 24, 26.0, 1.0)
				await _wait(0.18)
			"lens":
				_relic_pulse("hunter_lens")
				var lpos := _enemy_torso(ev.index)
				await _projectile(_player.position + Vector2(42, -70), lpos, C_GOLD, 0.12)
				_enemy_hit_feedback(ev, C_GOLD)
				_float_number("사냥꾼 렌즈", lpos + Vector2(0, -96), C_GOLD, F, 20.0, 0.8)
				await _wait(0.14)
			"echo":
				_trait_pulse()
				var epos := _enemy_torso(ev.index)
				_sfx("echo", 1.1)
				await _projectile(_player.position + Vector2(42, -60) * _ks, epos, Color("#e0b0ff"), 0.14)
				_vfx("magic", epos, 1.1)
				_sfx("magic_hit", 1.3)
				_enemy_hit_feedback(ev, C_MARK)
				_float_number("잔향 추격" + (" · 표식" if bool(ev.mark_added) else ""), epos + Vector2(0, -110), Color("#e0b0ff"), 24, 26.0, 1.0)
				await _wait(0.18)
			"absorb":
				_relic_pulse("absorb")
				_sfx("guard", 1.3)
				_vfx("guard", _player_body(), 0.8)
				_apply_event(ev)
				_float_number("흡수 +%d" % ev.amount, _player_body() + Vector2(0, -60), C_BLOCK, 24, 30.0, 0.7)
				await _wait(0.18)
			"chalice":
				_relic_pulse("blood_chalice")
				_sfx("guard", 1.2)
				_apply_event(ev)
				_float_number(tr("피의 성배 +%d") % int(ev.amount), _player_body() + Vector2(0, -100), C_BLOCK, 24, 30.0, 0.7)
				await _wait(0.12)
			"ember_jar":
				_relic_pulse("ember_jar")
				_sfx("guard", 1.4)
				_vfx("guard", _player_body(), 0.8)
				_apply_event(ev)
				_float_number("잿불 +%d" % ev.amount, _player_body() + Vector2(0, -84), C_BLOCK, 24, 30.0, 0.7)
				await _wait(0.14)
			"blade":
				_relic_pulse("blade_rhythm")
				_sfx("guard", 1.5)
				_vfx("guard", _player_body(), 0.8)
				_apply_event(ev)
				_float_number("철편 +%d" % ev.amount, _player_body() + Vector2(0, -84), C_BLOCK, 24, 30.0, 0.7)
				await _wait(0.16)
			"transfer":
				var tpos := _enemy_torso(ev.index)
				await _core_shot(_enemy_torso(ev.origin), tpos, 0.12, 26.0)
				_vfx("magic", tpos, 0.9)
				_sfx("magic_hit", 1.2)
				_enemy_hit_feedback(ev, C_MARK)
				_float_number("전이", tpos + Vector2(0, -92), C_MARK, F, 20.0, 0.7)
				await _wait(0.12)
			"echo_string":
				_relic_pulse("echo_string")
				var spos2 := _enemy_torso(ev.index)
				_sfx("echo", 1.4)
				await _projectile(_enemy_torso(ev.origin) + Vector2(0, -20), spos2, C_CRIT, 0.12)
				_vfx("counter", spos2, 0.9)
				_enemy_hit_feedback(ev, C_CRIT)
				_float_number("메아리 줄", spos2 + Vector2(0, -92), C_CRIT, F, 20.0, 0.8)
				await _wait(0.14)
			"echo_string_skip":
				_log_display(ev)
			"mark_chain":
				_trait_pulse()
				var mpos := _enemy_torso(ev.index)
				_sfx("echo", 1.2)
				await _core_shot(_enemy_torso(ev.origin) + Vector2(0, -20), mpos, 0.12, 26.0)
				_vfx("magic", mpos, 1.0)
				_enemy_hit_feedback(ev, C_MARK)
				_float_number("표식 연쇄", mpos + Vector2(0, -92), C_MARK, F, 20.0, 0.8)
				await _wait(0.14)
			"first_bonus":
				if (ev.get("parts", {}) as Dictionary).has("armory"):
					_trait_pulse("armory")
					_world_number(tr("무기고 +%d") % int(ev.parts.armory), _player_body() + Vector2(0, -120), C_GOLD, 20, 22.0, 0.8)
				_log_display(ev)
			"shield_expire":
				_apply_event(ev)
				_float_number("방패 사라짐", _enemy_torso(ev.index) + Vector2(0, -120), C_BLOCK, F, 20.0, 0.8)
			"burn_endure":
				_trait_pulse()
				_sfx("guard", 1.3)
				_apply_event(ev)
				_float_number("태워서 버티기 +%d" % ev.amount, _player_body() + Vector2(0, -84), C_BLOCK, 24, 30.0, 0.8)
				await _wait(0.12)
			"heal":
				_sfx("heal")
				_apply_event(ev)
				_float_number("체력 +%d" % int(ev.amount), _player_body() + Vector2(0, -60), Color("#8be08b"), 24)
				await _wait(0.1)
			"self_hurt":
				var pact := String(ev.get("source", "")) == "blood_pact"
				if not pact:
					_relic_pulse("thorn_eater")
				_sfx("hurt", 1.3, -8.0)
				_apply_event(ev)
				_actor_flash(_player, Color("#ff5a4a"), 0.5, 0.03, 0.12)
				_float_number((tr("피의 계약 −%d") if pact else tr("가시 −%d")) % int(ev.amount), _player_body() + Vector2(0, -60), Color("#ff7a6a"), 24)
				await _wait(0.1)
			"furnace":
				_relic_pulse("furnace_seal")
				var fpos := _enemy_torso(ev.index)
				_sfx("furnace")
				_vfx("burst", fpos, 1.0)
				_enemy_hit_feedback(ev, C_FIRE)
				_float_number("소각로 문장", fpos + Vector2(0, -92), C_FIRE, F, 20.0, 0.8)
				await _wait(0.14)
			"exhaust":
				_sfx("exhaust")
				_float_number("소진: " + " · ".join(PackedStringArray(ev.names)), Vector2(640, HAND_Y - 36), C_FIRE, 24, 26.0, 1.0)
				_log_display(ev)
				_render_hud()
			"mana_refund":
				if String(ev.source) == "crit_capacitor":
					_relic_pulse("crit_capacitor")
				_apply_event(ev)
				_sfx("mana", 1.3)
				_float_number("마나 +%d · %s" % [int(ev.amount), _source_name(String(ev.source))], MANA_ORB + Vector2(60, -44), Color("#9fd4ff"), F, 20.0, 1.0)
				await _wait(0.12)
			"prep":
				_apply_event(ev)
				if int(ev.after) >= P2Catalog.HUNTER_PREP_NEEDED:
					_sfx("crit_ready", 1.1)
					_float_number("다음 공격 확정 치명타!", _player_body() + Vector2(0, -130), C_CRIT, 24, 24.0, 1.1)
				elif int(ev.after) > 0:
					_float_number("준비 %d/%d" % [int(ev.after), P2Catalog.HUNTER_PREP_NEEDED], _player_body() + Vector2(0, -130), C_CRIT, F, 20.0, 0.8)
				await _wait(0.08)
			"resonance":
				_apply_event(ev)
				_sfx("echo", 0.9 + 0.15 * int(ev.level))
				_float_number(tr("귀족 적중 %d · 이번 턴 공격 ×%s") % [int(ev.level), str(snappedf(float(ev.mult), 0.1))], _player_body() + Vector2(0, -120), Color("#9fd4ff"), 24, 24.0, 1.0)
				await _wait(0.12)
			"noble_unseal":
				_seal_badge(_card_views.get(_hand_card(String(ev.uid))), "break")
				_apply_event(ev)
				if String(ev.why) == "resonance":
					_float_number(tr("봉인 해제"), Vector2(640, HAND_Y - 40), C_GOLD, 24, 24.0, 0.9)
				await _wait(0.1)
			"unwind":
				var upos := _enemy_torso(ev.index)
				_apply_event(ev)
				_sfx("weaken")
				_float_number(tr("힘 풀림 · 강타 %d") % int(ev.hit), upos + Vector2(0, -78), C_GOLD, 24, 24.0, 1.1)
				_art_stagger(_enemy_sprites[int(ev.index)])
				await _wait(0.16)
			"boss_weakened":
				var bpos := _enemy_torso(ev.index)
				_sfx("weaken")
				_vfx("burst", bpos, 1.6)
				_apply_event(ev)
				_shake(5.0)
				_float_number("강타 약화! → %d" % ev.hit, bpos + Vector2(0, -150), C_GOLD, 36, 30.0, 1.3)
				await _wait(0.3)
			"draw":
				if String(ev.source) == "satchel":
					_relic_pulse("satchel")
				var n := _add_drawn_cards()
				if n > 0:
					_sfx("draw")
					_float_number("+%d장" % n, Vector2(640, HAND_Y - 20), Color("#7fd7d0"), 24, 26.0, 0.8)
				if int(ev.count) < int(ev.requested):
					_float_number("손패 가득 / 더미 없음", Vector2(640, HAND_Y - 50), C_DIM, F, 20.0, 0.9)
				_render_hud()
				_log_display(ev)
				await _wait(0.16)
			_:
				if _show != null and _show.followup(ev):
					await _wait(0.08 if String(ev.kind) in ["react", "status", "freeze", "dot", "shard", "link"] else 0.0)


func _trait_pulse(id := "") -> void:
	if _trait_icon == null or not _trait_icon.visible:
		return
	if id != "" and P2Catalog.TRAITS.has(id):
		_trait_icon.texture = P2Catalog.icon_tex(id)
	_trait_icon.pivot_offset = _trait_icon.size / 2.0
	var t := create_tween()
	t.tween_property(_trait_icon, "scale", Vector2.ONE * 1.5, 0.08)
	t.tween_property(_trait_icon, "scale", Vector2.ONE, 0.18)
	_flash(_trait_icon, Color(2.2, 2.0, 1.4))


func _relic_pulse(id: String) -> void:
	for ic in _hud_relics.get_children():
		if ic.get_meta("relic", "") == id:
			ic.pivot_offset = ic.size / 2.0
			var t := create_tween()
			t.tween_property(ic, "scale", Vector2.ONE * 1.5, 0.08)
			t.tween_property(ic, "scale", Vector2.ONE, 0.18)
			_flash(ic, Color(2.2, 2.2, 1.6))


# 실제 후속 타격의 연결선: 출발점에서 대상까지 짧게 그어졌다 사라진다 (가르기 이어 베기 · 반격)
func _follow_through(from: Vector2, to: Vector2, color := C_IVORY) -> void:
	var line := Line2D.new()
	line.width = 4.0
	line.default_color = color
	line.add_point(from)
	line.add_point(from)
	_fxp.add_child(line)
	var t := create_tween()
	t.tween_method(func(p: Vector2) -> void: line.set_point_position(1, p), from, to, 0.06)
	t.tween_property(line, "modulate:a", 0.0, 0.1)
	t.tween_callback(line.queue_free)


func _lightning(from: Vector2, to: Vector2) -> void:
	var line := Line2D.new()
	line.width = 3.0
	line.default_color = Color("#bfe8ff")
	var steps := 7
	for i in range(steps + 1):
		var p := from.lerp(to, float(i) / steps)
		if i > 0 and i < steps:
			p += Vector2(randf_range(-6, 6), randf_range(-14, 14))
		line.add_point(p)
	_fxp.add_child(line)
	var t := create_tween()
	t.tween_interval(0.12)
	t.tween_property(line, "modulate:a", 0.0, 0.1)
	t.tween_callback(line.queue_free)


# ── 턴 종료 · 적 단계 ────────────────────────────────────────────────────────

func _on_end_turn_pressed() -> void:
	await end_turn()


func end_turn() -> bool:
	if _state != UI.PLAYER:
		return false
	_cancel_gesture("end_turn")
	var t0 := Time.get_ticks_usec()
	if not battle.begin_round_resolution():
		return false
	var evs := battle.events.duplicate(true)
	_state = UI.ENEMY
	_selected = null
	await _commit("enemy phase")
	_clear_preview()
	for p in _enemy_panels:
		(p.ring as Panel).visible = false
	_refresh_card_states()
	_sfx("select", 0.8)
	for view in _card_views.values():
		create_tween().tween_property(view, "modulate:a", 0.35, 0.12)
	if not _reduce_motion:
		_fold_tw = create_tween().set_parallel()
		_fold_tw.tween_property(_hand_root, "position:y", 110.0, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		_fold_tw.tween_property(_hand_rail, "modulate:a", 0.25, 0.24)
	await get_tree().process_frame
	await _anim_round_open(evs)
	if battle.battle_over:
		_record_timing("턴 종료", 0.0, t0)
		await _on_battle_over()
		return true
	await _run_enemy_phase(t0)
	return true


# 턴 종료 순간: 비축 인장 방어, 보스 강타 값 고정
func _anim_round_open(evs: Array) -> void:
	for ev in evs:
		match String(ev.kind):
			"unwind_lock", "noble_lock":
				_apply_event(ev)
			"seal":
				if int(ev.amount) > 0:
					_relic_pulse("reserve_seal")
					_sfx("guard", 1.2)
					_vfx("guard", _player_body(), 0.9)
					_apply_event(ev)
					_float_number("비축 인장 +%d" % ev.amount, _player_body() + Vector2(0, -70), C_BLOCK, 24, 28.0, 0.8)
					await _wait(0.2)
				else:
					_log_display(ev)
			"poison_tick":
				var at := _player_body()
				_sfx("hurt", 0.8)
				_apply_event(ev)
				_flash(_player, Color(0.8, 2.0, 0.8))
				_damage_number(str(int(ev.damage)), at + Vector2(10, -40), "poison", 36, 1.2)
				_float_number("독", at + Vector2(-46, -56), DMG_TONE.poison[0], 24, 30.0, 0.8)
				await _wait(0.3)
			"boss_lock":
				_apply_event(ev)
				var pos := _enemy_torso(ev.index)
				_sfx("lock", 0.9)
				var weak := int(ev.hit) < int(battle.charge_info(int(ev.index)).full)
				_float_number(("약화된 강타 %d" if weak else "강타 %d 준비") % int(ev.hit), pos + Vector2(0, -150), C_GOLD if weak else C_HP, 24, 20.0, 0.9)
				await _wait(0.24)
			_:
				if _show != null and _show.followup(ev):
					await _wait(0.22 if String(ev.kind) in ["dot", "react"] else 0.04)


func _run_enemy_phase(t0: int) -> void:
	var feedback_ms := (Time.get_ticks_usec() - t0) / 1000.0
	if battle.parry_pending():
		var pe := battle.pending_hits_event()
		await _anim_enemy_action(int(pe.index), [pe])
		_reconcile("enemy")
	while not battle.battle_over:
		var r := battle.take_next_monster_action()
		if not bool(r.acted):
			break
		var evs := battle.events.duplicate(true)
		await _commit("enemy action")
		await _anim_enemy_action(int(r.index), evs)
		_reconcile("enemy")
		if battle.battle_over:
			break
	if battle.battle_over:
		_record_timing("턴 종료", feedback_ms, t0)
		await _on_battle_over()
		return
	battle.finish_round_resolution()
	var round_evs := battle.events.duplicate(true)
	await _commit("round end")
	if battle.battle_over:
		_reconcile("round end")
		await _on_battle_over()
		return
	var seal_before := String(_shown.get("seal_uid", ""))
	_sync_shown_from_battle()
	_shown.seal_uid = seal_before
	for ev in round_evs:
		if String(ev.kind) == "carry" or String(ev.kind) == "glove":
			_shown.block = int(_shown.block) - int(ev.amount)
	var kept := _discard_hand_views()
	_build_hand(true, kept, 0.0 if _reduce_motion else 0.16)
	for c in battle.hand.cards:
		if battle.aim_charged.has(P2Catalog.uid_of(c)) and _card_views.has(c):
			var cv: Control = _card_views[c]
			_float_number("충전 %d" % battle.card_base_value(c), cv.position + Vector2(REST.x / 2.0, -10), C_CRIT, F, 22.0, 1.0)
	_render_all()
	_float_number("%d턴" % battle.turn_number, Vector2(640, 250), C_TEXT, 24, 20.0, 0.6)
	for ev in round_evs:
		match String(ev.kind):
			"carry":
				_sfx("guard", 1.1)
				_vfx("guard", _player_body(), 0.8)
				_apply_event(ev)
				_float_number("이월 방어 +%d" % ev.amount, _player_body() + Vector2(0, -70), C_BLOCK, 24, 28.0, 0.9)
			"glove":
				_relic_pulse("patient_glove")
				_sfx("guard", 1.3)
				_apply_event(ev)
				_float_number("인내 장갑 +%d" % ev.amount, _player_body() + Vector2(0, -90), C_BLOCK, 24, 28.0, 0.9)
			"block_strike_ready":
				_trait_pulse()
				_sfx("echo", 0.8)
				_float_number("막고 치기: 첫 공격 +%d" % ev.amount, _player_body() + Vector2(0, -110), C_GOLD, 24, 26.0, 1.1)
				_log_display(ev)
			"hex_active":
				_float_number("주술: 이번 턴 방어 카드 −%d" % ev.amount, _player_body() + Vector2(0, -140), C_MARK, 24, 26.0, 1.2)
				_log_display(ev)
			"noble_unseal":
				_seal_badge(_card_views.get(_hand_card(String(ev.uid))), "break")
				_apply_event(ev)
			"noble_seal":
				_seal_badge(_card_views.get(_hand_card(String(ev.uid))), "form")
				_apply_event(ev)
				_sfx("lock", 1.1)
				_float_number(tr("봉인: %s") % String(ev.name), Vector2(640, HAND_Y - 40), C_MARK, 24, 24.0, 1.1)
			"noble_seal_skip":
				_log_display(ev)
	_sync_shown_from_battle()
	_render_all()
	_focus_attacker(-1)
	if _music != null:
		_music.mine()
	await _wait(0.32)
	await _camera_settled()
	_state = UI.PLAYER
	_record_timing("턴 종료", feedback_ms, t0)
	_refresh_card_states()
	_refresh_targeting()


# 적 차례 시선: 행동하는 적 쪽으로 쏠림 · 줌 1.025(0.3초), index < 0이면 원위치. 악보 긴장과 같은 트윈을 써서 서로 이어진다
func _focus_attacker(index: int) -> void:
	if not _juice or _cam == null:
		return
	if _tension_tw != null and _tension_tw.is_valid():
		_tension_tw.kill()
	_tension_tw = create_tween().set_parallel()
	var off := Vector2.ZERO
	var z := 1.0
	if index >= 0 and index < _enemy_sprites.size() and is_instance_valid(_enemy_sprites[index]):
		off = (Vector2(_enemy_sprites[index].position.x, 330.0) - Vector2(640, 360)) * 0.1
		z = 1.025
	_tension_tw.tween_method(_set_cam_base_z, _cam_base_z, z, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tension_tw.tween_method(_set_cam_base_off, _cam_base_off, off, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _anim_enemy_action(index: int, events: Array) -> void:
	enemy_action_log.append({"index": index, "events": events.duplicate(true)})
	_focus_attacker(index)
	var sprite := _enemy_sprites[index]
	# 얼어붙음·덫에 걸림(행동 없음) · 공격 직전 덫·출혈
	if _show != null and not events.is_empty() and String(events[0].kind) in ["frozen_skip", "trap_stop"]:
		for ev in events:
			_show.followup(ev)
			await _wait(0.12)
		await _wait(0.4)
		return
	if _show != null:
		var pre_dead := false
		for ev in events:
			if String(ev.kind) in ["trap_snap", "dot", "status", "react", "trap_stop"]:
				_show.followup(ev)
				pre_dead = pre_dead or (String(ev.kind) in ["trap_snap", "dot"] and int(ev.get("index", -1)) == index and bool(ev.get("dead", false)))
				await _wait(0.18 if String(ev.kind) != "status" else 0.02)
		# 공격 전에 덫·출혈로 쓰러졌을 때만 공격 연출을 건너뛴다(전투는 이미 끝까지 계산돼 있어 지금 상태로 보면 반격에 쓰러진 것도 잡힘)
		if pre_dead:
			await _wait(0.3)
			return
	var role: String = battle.roles[index]
	var monster: MonsterState = battle.monsters[index]
	var home := sprite.position
	if not events.is_empty() and String(events[0].kind) in ["hex", "poison", "rebuild"]:
		await _anim_special(index, events[0])
		return
	if not events.is_empty() and String(events[0].kind) == "summon":
		await _anim_summon(index, events[0])
		return
	if not events.is_empty() and events[0].kind == "prepare" and sprite.has_meta("steady_frames"):
		# 거완 강타 준비: 팔을 드는 전환 1 → 2 → 준비 자세 유지 (다음 내 차례 내내)
		_sfx("prepare")
		_float_number("강타 준비", _enemy_torso(index) + Vector2(0, -60), C_DIM, F, 26.0, 0.7)
		var cg := _art_claim(sprite)
		sprite.set_meta("art_busy", true)
		_steady_set(sprite, "charged")
		var cms: Array = _ea(sprite.get_meta("art")).actions.charge_s
		_art_pose(sprite, "charge", 1)
		if await _art_hold(sprite, float(cms[1]), cg):
			_art_pose(sprite, "charge", 2)
			if await _art_hold(sprite, float(cms[2]), cg):
				sprite.set_meta("art_busy", false)
				if not bool(sprite.get_meta("dying", false)):
					_set_enemy_anim(sprite, "idle")
		_log_display(events[0])
		return
	if not events.is_empty() and events[0].kind == "prepare" and _art_acts(sprite) and bool(_ea(sprite.get_meta("art")).get("ranged_art", false)):
		_sfx("prepare")
		_float_number("준비", _enemy_torso(index) + Vector2(0, -60), C_DIM, F, 26.0, 0.7)
		var pg := _art_claim(sprite)
		sprite.set_meta("art_busy", true)
		_art_pose(sprite, "attack", 1)
		if await _art_hold(sprite, 0.34, pg):
			sprite.set_meta("art_busy", false)
			if not bool(sprite.get_meta("dying", false)):
				_set_enemy_anim(sprite, "idle")
		_log_display(events[0])
		return
	if not events.is_empty() and events[0].kind == "prepare":
		_sfx("prepare")
		_vfx("prepare", _body_center(home), 0.9)
		_float_number("쉼" if role == "hard_boss" else "준비", _body_center(home) + Vector2(0, -60), C_DIM, F, 26.0, 0.7)
		var t := create_tween()
		t.tween_property(sprite, "position:x", home.x + 8, 0.12)
		t.tween_property(sprite, "position:x", home.x, 0.12)
		await t.finished
		_log_display(events[0])
		return
	for ev in events:
		if String(ev.kind) == "aura":
			_float_number("기수 지원 +%d" % int(ev.amount), _below_panel(index, 22.0), C_HP, F, 22.0, 0.9)
			_log_display(ev)
		if String(ev.kind) == "suppressed":
			_sfx("suppress", 0.9)
			_vfx("prepare", _body_center(home), 0.7)
			_apply_event(ev)
			_float_number("억제됨 −%d" % ev.amount, _body_center(home) + Vector2(0, -120), C_BLOCK, 24, 22.0, 0.9)
			await _wait(0.22)
	var pend := events.filter(func(e): return String(e.kind) == "enemy_hits_pending")
	var chart: P2NoteChart = _parry_chart(index, pend[0].hits, events.any(func(e): return String(e.kind) == "suppressed")) if not pend.is_empty() else null
	if chart != null:
		await _zone_cue(chart)
		if _music != null:
			# 반 마디 칸을 기다린 만큼 달려들기를 늦춘다(첫 노트까지 남은 거리는 예전과 같게)
			await _chart_until(chart, 0, 1.4)
	var rush := 0.0
	if chart != null:
		_slowmo(true, [sprite], _player_body() + Vector2(94, -6))
		_tension(true, chart.get_meta("center"), chart.remaining())
		if _juice and not _reduce_motion:
			rush = clampf(chart.time_until(0) - 0.3, 0.16, 1.1)
	var caster := (battle.is_summoner(index) or bool(_ea_or(String(sprite.get_meta("art", ""))).get("cast_art", false))) and _art_acts(sprite)
	var spawn := battle.is_spawn_slot(index) and _art_acts(sprite)
	var ranged: bool = bool(P2Catalog.ENEMIES[role].get("ranged", false)) or String(P2Catalog.ENEMIES[role].get("rank", "")) == "device" or caster
	if _dressed and events.any(func(e): return String(e.kind) == "enemy_hit" and int(e.absorbed) > 0):
		await _wait(maxf(0.0, _actor_play(_defend_anim(), 1) - 0.16))
	if caster:
		await _art_cast_in(sprite, events, chart)
	elif spawn:
		await _spawn_burst_in(sprite)
	elif ranged and _art_acts(sprite) and bool(_ea(sprite.get_meta("art")).get("ranged_art", false)):
		await _art_shot_in(sprite, chart)
	elif ranged:
		if chart != null:
			await _chart_until(chart, 0, 0.16)
		var r := create_tween()
		r.tween_property(sprite, "position:x", home.x + 10, 0.08)
		r.tween_property(sprite, "position:x", home.x, 0.1)
		_sfx("arrow")
		await _projectile(_body_center(home) + Vector2(-20, 0), _player_body() + Vector2(20, 0), Color("#e8e0c8"), 0.16)
	elif _art_acts(sprite):
		# 거완: 턴 종료 때 굳힌 실제 강타 값(사건)이 강타/약타를 정한다. 그 밖의 공격은 짧은 주먹
		var strike := ""
		if sprite.has_meta("steady_frames"):
			var ul := int(_shown.enemies[index].get("ulock", -1))
			if ul >= 0:
				strike = "weak_slam" if ul == int(battle.unwind_info(index).weak) else "slam"
			sprite.set_meta("atk", strike if strike != "" else "attack")
		await _art_attack_in(sprite, rush)
		if strike != "":
			_steady_set(sprite, "idle")
	else:
		_set_enemy_anim(sprite, "run")
		_sfx("enemy_swing")
		sprite.set_meta("dashing", true)
		_sd_hop(sprite, rush if rush > 0.0 else 0.16)
		var dash := create_tween()
		if rush > 0.0:
			dash.tween_property(sprite, "position:x", _player.position.x + 128 * _ks, rush).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
			_afterimages(sprite, rush * 0.5)
		else:
			dash.tween_property(sprite, "position:x", _player.position.x + 128 * _ks, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await dash.finished
		_set_enemy_anim(sprite, "idle")
	for ev in events:
		if String(ev.kind) == "enemy_hits_pending":
			await _anim_parry_hits(index, sprite, monster, chart, ranged)
			_slowmo(false)
			_tension(false)
		else:
			await _anim_enemy_event(index, ev, sprite, monster)
	if _art_winding(sprite):
		# 실제 공격 사건이 없었다(취소 등): 허공 접촉 없이 회복으로
		_art_attack_out(sprite, int(sprite.get_meta("art_gen", 0)), false)
	if monster.is_alive() and not ranged:
		if _art_acts(sprite):
			await _art_settle(sprite)
		_kill_react(sprite)
		_set_enemy_anim(sprite, "run")
		if _art_acts(sprite):
			var back_r := _route_tween(sprite, home.x, 0.16, true)
			await back_r.finished
			if monster.is_alive():
				sprite.position = Vector2(home.x, FEET_Y)
		else:
			_sd_hop(sprite, 0.2, false)
			var back := create_tween()
			back.tween_property(sprite, "position:x", home.x, 0.2)
			await back.finished
		_set_enemy_anim(sprite, "idle")
	_pass_end(int(sprite.get_meta("pass_gen", -1)))
	sprite.set_meta("dashing", false)


# 적 행동 사건 하나의 연출. contacted면 공격자 접촉 자세는 이미 보였다(패링 원이 닫힌 순간)
func _anim_enemy_event(index: int, ev: Dictionary, sprite: AnimatedSprite2D, monster: MonsterState, contacted := false) -> void:
	match String(ev.kind):
		"enemy_hit":
			var absorbed := int(ev.absorbed)
			var dmg := int(ev.damage)
			if not contacted:
				if _dressed and absorbed > 0:
					await _await_frame(_defend_anim(), _contact(_defend_anim()), 0.3)
				if _art_winding(sprite):
					_art_contact(sprite)
				elif _spawn_winding(sprite):
					_spawn_contact(sprite)
				elif int(ev.get("hit_index", 0)) > 0 and _art_rewinds(sprite):
					await _art_rewind(sprite)
					_art_contact(sprite)
			var at := _player_body()
			if _barrier != null and (absorbed > 0 or String(ev.get("parry", "")) == "perfect"):
				_barrier.ripple(at + Vector2(34, -4) * _ks - _barrier.position)
			if String(ev.get("parry", "")) == "perfect":
				# 완벽 패링: 방패에 튕겨 나간다 (피해 0 · 방어 그대로). 사건 적용은 아래 한 번
				_sfx("block", 1.2)
				if _juice:
					_sparks(at + Vector2(48, -6), Vector2.RIGHT, 0.9, 16, [C_CRIT, Color.WHITE, C_IVORY], true)
				var pc: Node = _contact_fx("shield_contact", at + Vector2(34, -4) * _ks) if _dressed else null
				if not _dressed:
					_vfx("guard", at, 1.1)
				_av7_light(at + Vector2(34, -4) * _ks, "basic", Color(1.0, 0.9, 0.5))
				_player_nudge("block")
				_camera_kick("block", Vector2.LEFT)
				await _hit_stop([_player, sprite, pc], 0.09)
			if absorbed > 0:
				# 방패 박자: 방패 접촉 · 막은 양 · 버티기. 완전 흡수면 여기서 사건 전체를 한 번 적용 (몸 그림·피격 없음)
				_sfx("block")
				var sc: Node = _contact_fx("shield_contact", at + Vector2(34, -4) * _ks) if _dressed else null
				if not _dressed:
					_vfx("guard", at, 1.0)
				_world_number(tr("막음 %d") % absorbed, at + Vector2(-50, -40), C_BLOCK, 24, 30.0, 0.7)
				_av7_light(at + Vector2(34, -4) * _ks, "basic", Color(1.0, 0.85, 0.45))
				if dmg <= 0:
					_apply_event(ev)
				else:
					# 일부 흡수: 남은 방어만 먼저 보여 줌(표시만, 모델은 그대로). 사건 전체는 몸 박자에서 한 번
					_shown.block = int(ev.block)
					_render_hud()
				_player_nudge("block")
				_camera_kick("block", Vector2.LEFT)
				await _hit_stop([_player, sprite, sc], float(IMPACT.block.hold))
				if dmg > 0:
					await _wait(maxf(0.0, PARTIAL_BODY_OFFSET - float(IMPACT.block.hold)))
			if dmg > 0:
				# 몸 박자: 몸 접촉 · 실제 체력 감소 · 피격(또는 쓰러짐) · 번쩍임을 같은 순간에
				if absorbed == 0:
					_vfx("enemy_" + monster.monster_type, at, 0.8, true)
				var bc: Node = _contact_fx("body_contact", at + Vector2(10, 0)) if _dressed else null
				_av7_light(at + Vector2(10, 0), "basic", Color(1.0, 0.5, 0.42))
				_apply_event(ev)
				_sfx("hurt")
				if int(ev.hp) <= 0:
					_actor_death()
				else:
					_actor_hurt()
				_actor_flash(_player, Color(1.0, 0.45, 0.4), float(IMPACT.player_hurt.flash), float(IMPACT.player_hurt.fpeak), float(IMPACT.player_hurt.fclear))
				if _show != null:
					_show.hurt_look(dmg)
				if _juice:
					_sparks(at + Vector2(10, -10), Vector2.LEFT, 0.7, 8 + mini(dmg, 12), [Color.WHITE, C_HP, C_IVORY], false)
				var hard := dmg >= DMG_BIG
				_damage_number(str(dmg), at + (Vector2(-44, -34) if ev.has("parry") else Vector2(10, -40)), "hurt", 48 if hard else 36, 1.45 if hard else 1.2)
				_camera_kick("player_hurt", Vector2.LEFT)
				await _hit_stop([_player, sprite, bc], float(IMPACT.player_hurt.hold))
			elif absorbed == 0:
				_apply_event(ev)
			await _wait(0.14)
			if int(ev.hp) > 0 and not _dressed:
				_player.play("idle")
		"counter":
			var pos := _body_center(sprite.position)
			# 반격 동작(수호기사 counter · 사냥꾼 단검 근접): 접촉 프레임에서 되받아치기 선 끝 · 소리 · 피해
			var cnt_anim := _counter_anim()
			if cnt_anim != "":
				_actor_play(cnt_anim, 1)
				await _await_frame(cnt_anim, _contact(cnt_anim) - 1)
			var cs := _melee_socket(cnt_anim, _contact(cnt_anim)) if cnt_anim != "" else Vector2.INF
			_follow_through(_player.position + cs if cs != Vector2.INF else _player_body() + Vector2(24, 0), pos, Color("#bfe9e2"))
			if cnt_anim != "":
				await _await_frame(cnt_anim, _contact(cnt_anim))
			else:
				await _wait(0.05)
			# 실제 반격 한 번: 지금 돌진해 와 있는 공격자 몸통에 접촉, 반격 무게(정지 40ms)
			pos = _enemy_torso_now(index)
			_sfx("counter", 1.1)
			_sfx("weight", 1.05)
			var cc: Node = _contact_fx("slash_contact", pos) if _hires else null
			if not _hires:
				_vfx("counter", pos, 1.1)
			if _show != null and not _reduce_motion:
				_show.counter_flash(pos)
			_enemy_hit_feedback(ev, C_GOLD, "counter")
			_av7_light(pos, "basic", Color(1.0, 0.86, 0.6))
			_world_number(tr("반격 %d") % int(ev.raw), pos + Vector2(0, -90), C_GOLD, F, 20.0, 0.7)
			_camera_kick("counter", Vector2.RIGHT)
			await _hit_stop([_player, sprite, cc], float(IMPACT.counter.hold))
			await _wait(0.16)
		"thorn":
			_relic_pulse("thorn")
			var pos2 := _body_center(sprite.position)
			_sfx("thorn")
			_vfx("thorn", pos2, 0.9)
			_enemy_hit_feedback(ev, C_GOLD)
			_float_number("가시", pos2 + Vector2(0, -90), C_GOLD, F, 20.0, 0.7)
			await _wait(0.18)
		"drum_echo":
			# 되치는 북: 완벽으로 친 북이 그 적에게 되돌아간다
			_relic_pulse("drum_echo")
			var pos4 := _body_center(sprite.position)
			_sfx("bash", 1.4, -6.0)
			P2SkillFx.spawn(_fxp, "shock", pos4, Vector2.LEFT, 0.6, Color("#e0644a"))
			_enemy_hit_feedback(ev, C_GOLD)
			_float_number(tr("되치기"), pos4 + Vector2(0, -90), C_GOLD, F, 20.0, 0.5)
			await _wait(0.08)
		"shield_counter":
			# 수호기사: 완벽으로 막은 방패가 그대로 되받아친다 (방패 번쩍 · 공격자에게 충격)
			var pos5 := _enemy_torso_now(index)
			_sfx("bash", 1.25, -3.0)
			_vfx("guard", _player_body(), 0.7)
			P2SkillFx.spawn(_fxp, "shock", pos5 + Vector2(-20, 0), Vector2.RIGHT, 0.7, P2Catalog.CLASS_COLOR.warden)
			P2HitBits.spawn(_fxp, "chunk", pos5, Vector2.RIGHT, 8, [P2Catalog.CLASS_COLOR.warden, C_IVORY, Color("#b8ad9e")], 1.0)
			_enemy_hit_feedback(ev, C_GOLD)
			_world_number(tr("반격 %d") % int(ev.damage), pos5 + Vector2(0, -90), C_GOLD, F, 20.0, 0.5)
			await _wait(0.06)
		"echo_edge":
			# 메아리 칼끝: 완벽 패링의 되울림이 공격자에게 작게 꽂힌다
			_relic_pulse("echo_edge")
			var pos3 := _body_center(sprite.position)
			_sfx("thorn", 1.3)
			_vfx("thorn", pos3, 0.75)
			_enemy_hit_feedback(ev, C_GOLD)
			_float_number(tr("메아리"), pos3 + Vector2(0, -90), C_GOLD, F, 20.0, 0.6)
			await _wait(0.12)
		"iron_tempo":
			_relic_pulse("iron_tempo")
			_apply_event(ev)
			_world_number(tr("방어 +%d") % int(ev.amount), _player_body() + Vector2(-40, -76), C_BLOCK, 20, 20.0, 0.6)
		"thorn_skip", "hit_cancelled":
			_log_display(ev)
		"noble_seal_cast":
			await _wait(0.225)
			_float_number(tr("다음 손패 1장 봉인"), _enemy_torso(index) + Vector2(0, -110), C_MARK, F, 22.0, 0.9)
			await _art_seal_cast(sprite)
			_log_display(ev)
		"spawn_consumed":
			# 폭발한 소환수: 물보라로 끝나고 사라진다 (처치 그림·대기 복귀 없음)
			_spawn_consumed_fx(index)
			_apply_event(ev)
		_:
			if _show != null and String(ev.kind) not in ["trap_snap", "dot", "status", "react", "trap_stop"] and _show.followup(ev):
				await _wait(0.05)


# ── 전투 종료 ─────────────────────────────────────────────────────────────────

func _on_battle_over() -> void:
	_state = UI.OVER
	_camera_neutral()
	_dismiss_spawns()
	_use_button.visible = false
	_end_button.disabled = true
	_close_popups()
	_set_prompt("")
	var won := int(GameState.get_flag("player_hp")) > 0
	if _music != null:
		_music.finish(won)
	await _wait(0.45)
	if won:
		_sfx("victory")
		if battle.victory_heal > 0:
			_relic_pulse("bandage")
			_sfx("heal")
			_float_number("붕대 +%d" % battle.victory_heal, _player_body() + Vector2(0, -50), Color("#8be08b"), 24)
		_reconcile("battle_end")
		_banner_text("보스 격파!" if _is_boss() else "승리", 36)
	else:
		_sfx("defeat")
		_actor_death()
		_banner_text("패배", 36)
	_banner.visible = true
	_banner.modulate.a = 1.0
	await _wait(0.8)
	_banner.visible = false
	if won:
		await _show_results()
	finished.emit("won" if won else "lost")


# 전투 결과(시험판): 패링·긋기 성적과 정확도 등급, 최대 연속, 평균 오차. 오차가 한쪽으로 몰렸으면 보정 단추.
# 아무 키·클릭으로 넘기고, 가만두면 result_hold초 뒤 저절로 넘어간다
func _show_results() -> void:
	var sl: Dictionary = _rs.sl
	var np := int(_rs.p) + int(_rs.g) + int(_rs.m)
	var ns := int(sl.perfect) + int(sl.hit) + int(sl.part) + int(sl.graze)
	if np + ns == 0:
		return
	var score := (float(_rs.p) + 0.5 * float(_rs.g) + float(sl.perfect) + 0.7 * float(sl.hit) + 0.4 * float(sl.part) + 0.15 * float(sl.graze)) / float(np + ns)
	var grade := "S" if score >= 0.95 else ("A" if score >= 0.85 else ("B" if score >= 0.7 else ("C" if score >= 0.5 else "D")))
	var gcol: Color = {"S": Color("#ffe04a"), "A": Color("#8fe08b"), "B": Color("#8fc3e8"), "C": Color("#f3ead7"), "D": Color("#b3a58c")}[grade]
	var record := ""
	var practice := model != null and model.practice_ended()
	if RunModel.is_boss(String(enc_id)) or practice:
		var old: Dictionary = (GameState.combat.get("boss_best", {}) as Dictionary).get(RunModel.boss_key(String(enc_id), String(model.run.get("diff", "normal")) if model != null else "normal"), {})
		if practice:
			var lr: Dictionary = GameState.combat.get("last_result", {})
			old = (GameState.combat.get("practice_best", {}) as Dictionary).get(RunModel.practice_key(String(lr.group), String(lr.diff)), {})
		if RunModel.rhythm_better({"grade": grade, "acc": roundi(score * 100.0)}, old):
			record = tr("새 기록!") if not old.is_empty() else tr("첫 기록")
	if model != null and (model.active() or practice) and not model.has_pending():
		model.record_rhythm({"enc": String(enc_id), "grade": grade, "acc": roundi(score * 100.0), "best": int(_rs.best), "heal": battle.combo_heals})
	var panel := _stone_panel(_overlay, Vector2(390, 110), Vector2(500, 330))
	var dim: ColorRect = panel.get_parent().get_parent()
	dim.color.a = 0.35
	var title := _label("전투 결과", 24, C_GOLD)
	title.position = Vector2(20, 12)
	panel.add_child(title)
	if record != "":
		var rl := _label(record, F, Color("#ffe04a"))
		rl.position = Vector2(150, 18)
		rl.set_meta("record", record)
		panel.add_child(rl)
	var gl := _label(grade, 48, gcol)
	gl.position = Vector2(panel.size.x - 110, 2)
	gl.size = Vector2(90, 56)
	gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gl.add_theme_font_override("font", P2Ui.bold_font(48))
	gl.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02))
	gl.add_theme_constant_override("outline_size", 8)
	gl.set_meta("grade", grade)
	panel.add_child(gl)
	var acc := _label(tr("정확도 %d%%") % roundi(score * 100.0), 12, C_DIM)
	acc.position = Vector2(panel.size.x - 110, 58)
	acc.size = Vector2(90, 16)
	acc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(acc)
	var lines: Array[String] = []
	if np > 0:
		lines.append(tr("패링  완벽 %d · 막음 %d · 놓침 %d") % [int(_rs.p), int(_rs.g), int(_rs.m)])
	if ns > 0:
		lines.append(tr("긋기  완벽 %d · 정확 %d · 일부 %d · 스침 %d") % [int(sl.perfect), int(sl.hit), int(sl.part), int(sl.graze)])
	lines.append(tr("최대 연속 %d") % int(_rs.best) + (tr(" · 연속 회복 +%d") % battle.combo_heals if battle.combo_heals > 0 else ""))
	var offs: Array = _rs.offs
	var med := 0.0
	if offs.size() >= 3:
		var mean := 0.0
		for d in offs:
			mean += float(d)
		mean /= offs.size()
		var dev := 0.0
		for d in offs:
			dev += pow(float(d) - mean, 2.0)
		dev = sqrt(dev / offs.size())
		var v := offs.duplicate()
		v.sort()
		med = float(v[v.size() / 2])
		var side := tr("딱 맞음") if absf(mean) < 0.005 else (tr("%dms 늦게") % roundi(mean * 1000.0) if mean > 0.0 else tr("%dms 이르게") % roundi(-mean * 1000.0))
		lines.append(tr("평균 오차 %s · 흔들림 %dms") % [side, roundi(dev * 1000.0)])
	var body := _label("\n".join(lines), F, C_TEXT, 460)
	body.position = Vector2(20, 70)
	body.add_theme_constant_override("line_spacing", 6)
	panel.add_child(body)
	if offs.size() >= 6 and absf(med) >= 0.012:
		var now := roundi(P2NoteChart.offset * 1000.0)
		var to := clampi(roundi((P2NoteChart.offset + med) * 1000.0), -80, 80)
		var cal := _button(tr("판정 보정 %+dms → %+dms 적용") % [now, to], Vector2(20, 226), Vector2(300, 40), F)
		cal.set_meta("calibrate", true)
		cal.pressed.connect(func() -> void:
			var ms := _calibrate(offs)
			cal.text = tr("판정 보정 %+dms 적용함") % ms
			cal.disabled = true)
		panel.add_child(cal)
	var foot := _label(tr("아무 키·클릭으로 계속"), 12, C_DIM)
	foot.position = Vector2(20, panel.size.y - 26)
	panel.add_child(foot)
	_skin_children(panel)
	_result_open = true
	var click := func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			_result_open = false
	dim.gui_input.connect(click)
	panel.gui_input.connect(click)
	var t := 0.0
	while _result_open and t < result_hold and is_inside_tree():
		await get_tree().process_frame
		t += get_process_delta_time()
	_result_open = false
	dim.queue_free()


# 연습 악보(시험판 메뉴): 피해 없이 노트 종류를 한 번씩 쳐 보고 판정 막대로 보정을 맞춰 보는 짧은 악보(120 BPM)
func practice(first := false) -> void:
	if _state != UI.PLAYER or not battle.parry_mode:
		return
	_close_popups()
	_cancel_gesture("practice")
	_state = UI.BUSY
	_refresh_card_states()
	var beat := 0.5
	var c := Vector2(640, 250)
	var seq := [["t", -1, 0], ["t", 1, 0], ["t", 0, -1], ["h", 0, 1], ["d", -2, 0], ["s", -1, -1], ["f", 2, 1], ["x", 0, 0], ["t", -1, 1], ["t", 1, 1]]
	var notes: Array = []
	var t := beat * 2.0
	for k in range(seq.size()):
		var q: Array = seq[k]
		var kind := String(q[0])
		var pos := c + Vector2(int(q[1]), int(q[2])) * CELL
		var n := {"pos": pos, "at": t, "approach": beat * 1.2 * _approach_k * (1.6 if kind == "f" else 1.0), "kind": kind, "hold": 0.0, "num": k + 1}
		if kind == "h" or kind == "s":
			n.hold = beat
		if kind == "s":
			n.to = pos + Vector2(CELL.x, 0)
		notes.append(n)
		t += beat * 2.0 + float(n.hold) + (P2NoteChart.DOUBLE_WIN if kind == "d" else 0.0)
	var chart := P2NoteChart.new()
	chart.setup(notes, NOTE_R, _ui_tex("status_shield", 4), false)
	chart.bounds = Rect2(c - CELL * Vector2(2, 1) - Vector2(10, 10), CELL * Vector2(4, 2) + Vector2(20, 20))
	chart.beat = beat
	chart.arrange()
	chart.set_meta("practice", true)
	chart.cue.connect(_on_cue)
	chart.judged.connect(func(i: int, g: String, _d: float) -> void:
		if _beat == null:
			return
		if g == "perfect":
			_beat.play("chime", i)
		elif g == "good":
			_beat.play("stick")
		elif String(chart.notes[i].kind) != "x":
			_beat.play("thud"))
	_ui.add_child(chart)
	_wire_chart(chart)
	_set_prompt(tr("연습 악보 · 피해 없음") + "\n" + tr("흰 화살표가 가운데 오게"))
	_tension(true, c, chart.end_time())
	await chart.tree_exited
	if not is_inside_tree():
		return
	_tension(false)
	_set_prompt("")
	_state = UI.PLAYER
	_refresh_card_states()
	if first:
		var ds := recent_offsets.duplicate()
		if ds.size() >= 5:
			ds.sort()
			var med := float(ds[ds.size() / 2])
			if absf(med) >= 0.012:
				var ms := _calibrate(ds)
				_notice(tr("판정 보정을 %+dms로 맞췄습니다 (평균 %dms %s)") % [ms, roundi(absf(med) * 1000.0), tr("늦게") if med > 0.0 else tr("이르게")], 4.0)
			else:
				_notice(tr("박자가 잘 맞습니다. 시작합니다"), 2.5)


func _ask_retreat() -> void:
	if _state != UI.PLAYER:
		return
	_cancel_gesture("modal")
	_state = UI.BUSY
	_refresh_card_states()
	var panel := _stone_panel(_overlay, Vector2(290, 170), Vector2(700, 350), C_HP)
	var dim: Control = panel.get_parent().get_parent()
	var title := _label("연습을 그만둘까요?" if _practice() else "후퇴하면 이번 원정을 포기합니다", 24, C_HP)
	title.position = Vector2(24, 18)
	panel.add_child(title)
	var lines: Array[String] = []
	if _practice():
		lines.append("메인 메뉴로 돌아갑니다. 그만두면 이번 연습 성적은 남지 않습니다.")
	else:
		var risk := model.at_risk_summary()
		lines.append("전투만 다시 시작하는 기능이 아닙니다. 메인 메뉴로 돌아가며 이번 원정이 끝납니다.")
		if int(risk.get("banked_gold", 0)) > 0:
			lines.append("남는 것: 지금까지의 점수 · 기록 (확정된 구간 금화 %d)" % int(risk.banked_gold))
		else:
			lines.append("남는 것: 지금까지의 점수 · 기록")
		lines.append("잃는 것 (이번 구간 미확정): 금화 %d" % int(risk.get("pending_gold", 0)))
		lines.append("이번 원정의 덱·강화·유물·특성은 원정이 끝나면 사라집니다.")
	var body := _label("\n".join(lines), F, C_TEXT, 652)
	body.position = Vector2(24, 64)
	panel.add_child(body)
	var yes := _button("그만두기" if _practice() else "원정 포기", Vector2(80, 262), Vector2(240, 48), F)
	var no := _button("계속 싸우기", Vector2(380, 262), Vector2(240, 48), F)
	panel.add_child(yes)
	panel.add_child(no)
	_skin_children(panel)
	no.pressed.connect(func() -> void:
		dim.queue_free()
		_state = UI.PLAYER
		_refresh_card_states()
		_refresh_targeting())
	yes.pressed.connect(func() -> void:
		dim.queue_free()
		confirm_retreat())


func confirm_retreat() -> bool:
	if _practice():
		if not model.field_retreat():
			if model.has_pending() and gate != null and await gate.run():
				_state = UI.OVER
				finished.emit("retreat")
				return true
			return false
		_state = UI.OVER
		finished.emit("retreat")
		return true
	if not model.abandon():
		if model.has_pending() and gate != null and await gate.run():
			_state = UI.OVER
			finished.emit("abandoned")
			return true
		return false
	_state = UI.OVER
	finished.emit("abandoned")
	return true


# ── 물약 · 특수 행동 · 장치 재가동 ─────────────────────────────────────────────

func _potion_count(item: String) -> int:
	if _practice():
		return 0
	return model.potion_count(item)


func _render_potions() -> void:
	if _potion_button == null or battle == null:
		return
	var hp_n := _potion_count("hp_potion")
	var mp_n := _potion_count("mana_potion")
	var heal := int(_run_info.get("potion_heal", P5Campaign.POTION_HEAL))
	_potion_button.tooltip_text = tr("회복약 [Q]: 체력 +%d, 독·주술 해제. 자기 턴에 턴당 하나, 마나 비용 없음.") % heal
	_potion_button.visible = hp_n > 0
	_potion_button.disabled = _state != UI.PLAYER or model.can_use_battle_potion("hp_potion") != ""
	_mana_potion_button.tooltip_text = "마나 +%d (최대 마나까지). 자기 턴에 턴당 하나 (회복약과 합쳐서)." % P5Campaign.MANA_POTION_AMOUNT
	_mana_potion_button.visible = mp_n > 0
	_mana_potion_button.disabled = _state != UI.PLAYER or model.can_use_battle_potion("mana_potion") != ""


func _use_potion(item: String) -> void:
	if _state != UI.PLAYER:
		return
	_cancel_gesture("potion")
	var why := model.can_use_battle_potion(item)
	if why != "":
		_sfx("deny")
		_guide.text = why
		_notice(why)
		return
	_state = UI.BUSY
	_selected = null
	var ok := model.use_battle_potion(item)
	if not ok and model.has_pending() and gate != null:
		await gate.run()
	var evs := battle.events.duplicate(true)
	for ev in evs:
		match String(ev.kind):
			"potion":
				_sfx("heal")
				_apply_event(ev)
				_float_number("회복약 +%d%s" % [int(ev.amount), " · 해제" if bool(ev.cleansed) else ""], _player_body() + Vector2(0, -60), Color("#8be08b"), 24)
			"mana_refund":
				_sfx("mana", 1.3)
				_float_number("마나 +%d" % int(ev.amount), MANA_ORB + Vector2(60, -44), Color("#9fd4ff"), F, 20.0, 1.0)
	_sync_shown_from_battle()
	_render_all()
	await _wait(0.2)
	_state = UI.PLAYER
	_refresh_card_states()
	_refresh_targeting()


func _anim_special(index: int, ev: Dictionary) -> void:
	var sprite := _enemy_sprites[index]
	var pos := _body_center(sprite.position)
	var hex_art := String(ev.kind) == "hex" and _art_acts(sprite) and (_ea(sprite.get_meta("art")).actions as Dictionary).has("hex")
	if hex_art:
		var acts: Dictionary = _ea(sprite.get_meta("art")).actions
		var gen := _art_claim(sprite)
		sprite.set_meta("art_busy", true)
		_art_pose(sprite, "hex", 0)
		if await _art_hold(sprite, float(acts.hex_s[0]), gen):
			_art_pose(sprite, "hex", 1)
		if await _art_hold(sprite, float(acts.hex_s[1]), gen):
			_art_pose(sprite, "hex", 2)
		_vfx("prepare", sprite.position + (acts.hex_socket as Vector2) * sprite.scale.x, 0.6)
		_art_cast_out(sprite, gen, "hex")
	match String(ev.kind):
		"hex":
			_sfx("suppress", 0.7)
			_vfx("magic", _player_body(), 1.0)
			_float_number("주술: 다음 턴 방어 카드 −%d" % int(ev.amount), _player_body() + Vector2(0, -120), C_MARK, 24, 24.0, 1.2)
		"poison":
			_sfx("suppress", 0.9)
			_vfx("prepare", _player_body(), 1.0)
			_float_number("독 %d × %d회 (내 턴 종료)" % [int(ev.amount), int(ev.ticks)], _player_body() + Vector2(0, -120), Color("#8be08b"), 24, 24.0, 1.2)
		"rebuild":
			_sfx("lock", 0.8)
			_vfx("charge", pos, 1.4)
			_apply_event(ev)
			var n := (ev.devices as Array).size()
			_float_number("장치 %d개 재가동" % n if n > 0 else "재가동할 장치 없음", pos + Vector2(0, -150), C_GOLD, 24, 24.0, 1.1)
	if not hex_art:
		var t := create_tween()
		t.tween_property(sprite, "position:x", sprite.position.x + 8, 0.12)
		t.tween_property(sprite, "position:x", sprite.position.x, 0.12)
		await t.finished
	_log_display(ev)
	_render_hud()
	await _wait(0.2)


func _revive_enemy(index: int) -> void:
	if index >= _enemy_sprites.size():
		return
	var sprite := _enemy_sprites[index]
	sprite.set_meta("dying", false)
	sprite.visible = true
	sprite.modulate.a = 1.0
	_set_enemy_anim(sprite, "idle")
	(_enemy_panels[index].root as Control).visible = true


func _update_debug() -> void:
	if not _debug.visible:
		return
	var lines: Array[String] = ["FPS %d · 소리 지연 %.0fms" % [Engine.get_frames_per_second(), AudioServer.get_output_latency() * 1000.0]]
	for t in _timings.slice(-6):
		lines.append("%s  내부 처리(입력 처리→다음 프레임) %.1fms · 입력 복귀 %.0fms" % [t.action, t.feedback_ms, t.return_ms])
	_debug.text = "\n".join(lines)


# 새 전투 연출 켬/끔 (표현만, 사용자 설정 파일에 저장). 행동 사이에만 바뀐다(메뉴는 내 차례에 열림)
func set_new_fx(on: bool) -> void:
	_new_fx = on
	var st := P2Ui.load_settings()
	st.battle_fx = on
	P2Ui.save_settings(st)
	_camera_neutral()
	if on:
		_av7_warm()


func current_state() -> String:
	return UI.keys()[_state]


func end_button_enabled() -> bool:
	return not _end_button.disabled


func visible_target_rings() -> int:
	var n := 0
	for p in _enemy_panels:
		if (p.ring as Panel).visible and (p.root as Control).visible:
			n += 1
	return n


func select_for_test(card: Card, target: int) -> void:
	_selected = card
	_target = target
	_refresh_targeting()


# 연료화 입력 경로를 실제 손잡이로: 고르기 → (다른 카드 고르기) → 취소 또는 확정
func fuel_select_for_test(fuel: Card) -> void:
	_select_card(fuel)


func fuel_pick_for_test(card: Card) -> void:
	_pick_fuel(card)


func fuel_cancel_for_test() -> void:
	_cancel_selection()


func fuel_confirm_for_test() -> void:
	await _confirm_selected()


func guide_text() -> String:
	return _guide.text


func card_tag_text(card: Card) -> String:
	if not _card_views.has(card):
		return ""
	return ((_card_views[card] as Control).get_meta("tag") as Label).text


# ── 점검용 좌표·상태 (1280×720 설계 좌표) ──────────────────────────────────

func hand_point(card: Card) -> Vector2:
	var view: Control = _card_views[card]
	var pivot: Vector2 = (view.get_meta("home") as Vector2) + Vector2(REST.x / 2.0, REST.y)
	return pivot + Vector2(0, -REST.y * 0.45).rotated(deg_to_rad(float(view.get_meta("rot"))))


func enemy_point(i: int) -> Vector2:
	return (_enemy_panels[i].root as Control).get_meta("body_center")


func self_point() -> Vector2:
	return _player_body()


func field_point() -> Vector2:
	return ALL_ZONE.get_center() + Vector2(0, 60)


func raised_card() -> Card:
	return _big_card


func raised_rect() -> Rect2:
	return Rect2(_big.position, BIG * _big.scale) if _big != null else Rect2()


# 끄는 동안 마우스를 따라오는 작은 카드의 화면 자리(기울기 무시)
func drag_ghost_rect() -> Rect2:
	if _drag_ghost == null or not is_instance_valid(_drag_ghost):
		return Rect2()
	var s := _drag_ghost.scale.x
	return Rect2(_drag_ghost.position + _drag_ghost.pivot_offset * (1.0 - s), REST * s)


func end_button_rect() -> Rect2:
	return Rect2(_end_button.position, _end_button.size)


func guide_rect() -> Rect2:
	return Rect2()


func top_module_rects() -> Array:
	return [PLAYER_MODULE, TURN_BANNER, MENU_RECT]


func pred_detail(i: int) -> String:
	var p: Dictionary = _enemy_panels[i]
	return ((p.pred as Control).get_meta("detail") as Label).text if (p.pred as Control).visible else ""


func hint_rect() -> Rect2:
	return _prompt_box.get_global_rect() if _prompt_box.visible else Rect2()


# 적마다 머리 위 예고 칸(실제 크기)과, 떠 있으면 예상 칸
func enemy_column_rects() -> Array:
	var out: Array = []
	for p in _enemy_panels:
		var r: Control = p.root
		if r.visible:
			out.append(Rect2(r.position + (p.intent as Control).position, (p.intent as Control).size))
	return out


func _vis_cached(i: int) -> Vector2:
	var s := _enemy_sprites[i]
	if not s.has_meta("vis"):
		s.set_meta("vis", _visible_size(i))
	return s.get_meta("vis")


func enemy_body_rect(i: int) -> Rect2:
	var o := _vis_cached(i)
	return Rect2(float(_slots()[i]) - o.x / 2.0, FEET_Y - o.y, o.x, o.y)


func prompt_text() -> String:
	return _prompt_label.text if _prompt_box.visible else ""


func popup_open() -> String:
	return "menu" if _menu != null else ("info" if _info != null else "")


func open_menu_for_test() -> void:
	_toggle_menu()


func close_popups_for_test() -> void:
	_close_popups()


func pred_text(i: int) -> String:
	var p: Dictionary = _enemy_panels[i]
	return (p.preview as Label).text if (p.pred as Control).visible else ""


func pred_rect(i: int) -> Rect2:
	return (_enemy_panels[i].pred as Control).get_global_rect()


func intent_rects() -> Array:
	var out: Array = []
	for p in _enemy_panels:
		if (p.root as Control).visible:
			out.append(Rect2((p.root as Control).position + (p.intent as Control).position, (p.intent as Control).size))
	return out


# 점검: 카드 앞면의 마나 배지 글자 · 단축키 글자와 두 칸의 화면 위치
func card_face_info(card: Card) -> Dictionary:
	var view: Control = _big if _big != null and _big_card == card else _card_views[card]
	var key: Label = view.get_meta("key")
	return {"cost": (view.get_meta("cost") as Label).text, "key": key.text,
		"badge_rect": (view.get_meta("badge") as Control).get_global_rect(), "key_rect": (key.get_parent() as Control).get_global_rect(),
		"rot": view.rotation_degrees, "key_tip": (key.get_parent() as Control).tooltip_text}


func enemy_hp_text(i: int) -> String:
	return (_enemy_panels[i].hp_label as Label).text


func enemy_marks_shown(i: int) -> int:
	var m: Control = _enemy_panels[i].marks
	return int(m.get_meta("count", 0)) if m.visible else 0


func mana_pred_text() -> String:
	return _mana_pred.text if bool(_mana_label.get_meta("pred", false)) else ""


func player_pred_text() -> String:
	return (_player_pred.get_meta("label") as Label).text if _player_pred.visible else ""


func av4_wave_count() -> int:
	return _fx.get_children().filter(func(c): return c is AnimatedSprite2D and (c as AnimatedSprite2D).sprite_frames in _crescent_frames.values()).size()


func gesture_state() -> Dictionary:
	return {"drag": not _drag.is_empty(), "press": not _press.is_empty(), "arrow": _aim_fx.visible or _drag_ghost != null,
		"zone_self": _zone_self.visible, "zone_all": _zone_all.visible}
