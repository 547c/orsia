class_name P2Catalog
extends RefCounted
# 자료표: 직업 · 카드 · 강화 · 유물 · 특성 · 세 구간의 적과 편성 · 보상 일정 · 상점/선택 지점 가격

const CATALOG_VERSION := 5

# 직업. 체력·마나는 P5Campaign.CLASS_BASE와 같은 값 (파생 공식은 P5Campaign 한 곳)
const CLASSES := {
	"rune_caster": {"name": "원소술사", "hp": 34, "mana_bonus": 1, "weapon": "staff", "icon": "wand_02.png",
		"motto": "불·얼음·바람·빛·어둠을 섞어 터뜨린다", "passive": "최대 마나 4 · 원소를 섞으면 반응 (얼림 + 물리 = 쇄빙, 얼림 + 불 = 녹아내림, 독 + 불 = 유독 폭발, 바람 = 확산)",
		"example": "빙결의 관으로 얼림 → 다음 적 차례 공격 없음 → 화염구로 녹아내림(피해 ×2)",
		"deck": ["slash", "slash", "guard", "guard", "bolt", "bolt", "poison_cloud", "focus", "gust", "fireball", "frost_lance"], "anchors": ["fireball", "frost_lance"]},
	"warden": {"name": "수호기사", "hp": 38, "mana_bonus": 0, "weapon": "shield", "icon": "wooden_shield.png",
		"motto": "막을수록 세진다", "passive": "적 공격을 완벽으로 막으면 그 적에게 2 (적 차례마다 6번까지) · 카드 반격 +1",
		"example": "수호 5 + 결사 방어 8 → 방패 내려찍기: 4 + 방어 13 × 2 = 30, 다른 적에게 6 · 방어 13은 그대로",
		"deck": ["slash", "slash", "guard", "guard", "riposte", "bash", "fortify", "suppress", "slam"], "anchors": ["riposte", "bash"], "recommended": true},
	"hunter": {"name": "사냥꾼", "hp": 36, "mana_bonus": 0, "weapon": "bow", "icon": "bow_01.png",
		"motto": "쏟아붓고 급소를 꿰뚫는다", "passive": "치명 아닌 공격 카드 2번 → 다음 공격 카드는 반드시 치명 · 사냥꾼 치명 피해 +50%",
		"example": "속사 → 베기 → 화살비: 모든 적에게 2 × 5, 다섯 발 모두 치명",
		"deck": ["slash", "slash", "guard", "guard", "quickshot", "twin_slash", "aimed_shot", "focus", "arrow_rain"], "anchors": ["quickshot", "aimed_shot"]},
	"combo": {"name": "콤보술사", "hp": 36, "mana_bonus": 0, "weapon": "fist", "icon": "glove_01.png", "art": "warden",
		"motto": "같은 적을 몰아쳐 연격을 쌓는다",
		"passive": "연격 = 같은 적을 이어 때린 횟수 (최대 6), 1당 그 적에게 타격 피해 +1 · 다른 적을 치거나 턴이 끝나면 0 · 적 공격을 완벽으로 2번 막을 때마다 다음 턴 연격 +1로 시작",
		"example": "연타 2 × 3 → 2 · 3 · 4 (연격 3) → 마무리 일격 6 + 연격 3 × 2 + 3 = 15",
		"deck": ["jab", "jab", "guard", "guard", "flurry", "finisher", "flow", "focus"], "anchors": ["flurry", "finisher"]},
	"shaman": {"name": "주술사", "hp": 38, "mana_bonus": 0, "weapon": "staff", "icon": "wand_02.png", "art": "rune_caster",
		"motto": "저주를 쌓아 시간차로 터뜨린다", "passive": "저주가 터질 때마다 체력 1 회복",
		"example": "파멸의 낙인 4 → 2턴 뒤 12 폭발 · 쇠약으로 취약이면 18",
		"deck": ["slash", "guard", "guard", "hex_bolt", "hex_bolt", "doom_brand", "enfeeble", "blood_pact", "soul_drain"], "anchors": ["hex_bolt", "doom_brand"]},
}
const CLASS_ORDER := ["rune_caster", "warden", "hunter", "combo", "shaman"]
const COMBO_MAX := 6
const COMBO_CARRY_MAX := 3

const MANA_BASE := 3
const MANA_CAP := 6
const CRIT_BASE_CHANCE := 10
const CRIT_CHANCE_CAP := 50
const CRIT_BASE_MULT := 2.0
const CRIT_MULT_CAP := 3.0
const HUNTER_PREP_NEEDED := 2
const HUNTER_CRIT_BONUS := 0.5
const WARDEN_PARRY_DAMAGE := 2
const WARDEN_PARRY_MAX := 6
const RUNE_MARK_CAP := 5
const SLAM_MULT := 2
const CHAIN_PER := 4
const CHAIN_NEED := 3
const CHAIN_SPLASH := 3

# 저장용 안정 매핑: 종류 → 고정 번호 + 복제 원본(CardLibrary id). 번호는 바꾸지 않는다
const CARD_KINDS := {
	"slash": {"code": 1, "library_id": "wooden_sword_slash"},
	"bolt": {"code": 2, "library_id": "magic_bolt"},
	"guard": {"code": 3, "library_id": "guard"},
	"sweep": {"code": 4, "library_id": "spin_slash"},
	"bash": {"code": 5, "library_id": "wooden_sword_slash"},
	"wave": {"code": 6, "library_id": "magic_bolt"},
	"twin_slash": {"code": 7, "library_id": "wooden_sword_slash"},
	"pierce": {"code": 8, "library_id": "stab"},
	"suppress": {"code": 9, "library_id": "ice_arrow"},
	"focus": {"code": 10, "library_id": "haste"},
	"sigil_burst": {"code": 11, "library_id": "judgment"},
	"fuel": {"code": 12, "library_id": "mana_draught"},
	"torrent": {"code": 13, "library_id": "meteor_drop"},
	"mana_veil": {"code": 14, "library_id": "reflect_shield"},
	"riposte": {"code": 15, "library_id": "counter_slash"},
	"fortify": {"code": 16, "library_id": "seal"},
	"quickshot": {"code": 17, "library_id": "swift"},
	"aimed_shot": {"code": 18, "library_id": "lightning_spear"},
	"jab": {"code": 19, "library_id": "wooden_sword_slash"},
	"flurry": {"code": 20, "library_id": "wooden_sword_slash"},
	"finisher": {"code": 21, "library_id": "wooden_sword_slash"},
	"flow": {"code": 22, "library_id": "guard"},
	"palm": {"code": 23, "library_id": "wooden_sword_slash"},
	"breather": {"code": 24, "library_id": "haste"},
	"storm": {"code": 25, "library_id": "wooden_sword_slash"},
	"spin_kick": {"code": 26, "library_id": "spin_slash"},
	"parry_stance": {"code": 27, "library_id": "guard"},
	"focus_strike": {"code": 28, "library_id": "stab"},
	"shield_throw": {"code": 29, "library_id": "wooden_sword_slash"},
	"iron_beat": {"code": 30, "library_id": "guard"},
	"volley": {"code": 31, "library_id": "wooden_sword_slash"},
	"weak_point": {"code": 32, "library_id": "stab"},
	"mark_amp": {"code": 33, "library_id": "magic_bolt"},
	"ember": {"code": 34, "library_id": "magic_bolt"},
	"beat_slash": {"code": 35, "library_id": "wooden_sword_slash"},
	"heal_sigil": {"code": 36, "library_id": "magic_bolt"},
	"slam": {"code": 37, "library_id": "wooden_sword_slash"},
	"arrow_rain": {"code": 38, "library_id": "wooden_sword_slash"},
	"chain_blast": {"code": 39, "library_id": "magic_bolt"},
	"fireball": {"code": 40, "library_id": "magic_bolt"},
	"fire_wall": {"code": 41, "library_id": "magic_bolt"},
	"frost_lance": {"code": 42, "library_id": "magic_bolt"},
	"ice_coffin": {"code": 43, "library_id": "magic_bolt"},
	"dark_rift": {"code": 44, "library_id": "magic_bolt"},
	"light_rain": {"code": 45, "library_id": "magic_bolt"},
	"gust": {"code": 46, "library_id": "magic_bolt"},
	"poison_cloud": {"code": 47, "library_id": "magic_bolt"},
	"focus_shot": {"code": 48, "library_id": "wooden_sword_slash"},
	"barrage": {"code": 49, "library_id": "wooden_sword_slash"},
	"bear_trap": {"code": 50, "library_id": "haste"},
	"mark_target": {"code": 51, "library_id": "haste"},
	"bleed_arrows": {"code": 52, "library_id": "wooden_sword_slash"},
	"shield_boomerang": {"code": 53, "library_id": "wooden_sword_slash"},
	"rampart": {"code": 54, "library_id": "guard"},
	"war_cry": {"code": 55, "library_id": "haste"},
	"iron_counter": {"code": 56, "library_id": "guard"},
	"launcher": {"code": 57, "library_id": "wooden_sword_slash"},
	"hundred_fists": {"code": 58, "library_id": "wooden_sword_slash"},
	"ki_blast": {"code": 59, "library_id": "wooden_sword_slash"},
	"hex_bolt": {"code": 60, "library_id": "magic_bolt"},
	"doom_brand": {"code": 61, "library_id": "haste"},
	"enfeeble": {"code": 62, "library_id": "haste"},
	"armor_break": {"code": 63, "library_id": "wooden_sword_slash"},
	"soul_link": {"code": 64, "library_id": "haste"},
	"blood_pact": {"code": 65, "library_id": "haste"},
	"soul_drain": {"code": 66, "library_id": "magic_bolt"},
	"plague": {"code": 67, "library_id": "haste"},
	"expose": {"code": 68, "library_id": "haste"},
	"disarm": {"code": 69, "library_id": "haste"},
	"war_shout": {"code": 70, "library_id": "haste"},
	"poison_coat": {"code": 71, "library_id": "haste"},
	"first_aid": {"code": 72, "library_id": "magic_bolt"},
	"smoke_bomb": {"code": 73, "library_id": "haste"},
	"ult_rune_caster": {"code": 74, "library_id": "magic_bolt"},
	"ult_hunter": {"code": 75, "library_id": "wooden_sword_slash"},
	"ult_warden": {"code": 76, "library_id": "wooden_sword_slash"},
	"ult_combo": {"code": 77, "library_id": "wooden_sword_slash"},
	"ult_shaman": {"code": 78, "library_id": "magic_bolt"},
}
const UPGRADE_KINDS := {
	"split": {"code": 1, "from": "bolt"},
	"counter": {"code": 2, "from": "guard"},
	"cleave_slash": {"code": 3, "from": "slash"},
	"double_inscription": {"code": 4, "from": "wave"},
	"carry_guard": {"code": 5, "from": "guard"},
	"pursuit_slash": {"code": 6, "from": "slash"},
	"transfer_burst": {"code": 7, "from": "sigil_burst"},
	"reflux_burst": {"code": 8, "from": "sigil_burst"},
	"fierce_riposte": {"code": 9, "from": "riposte"},
	"layered_riposte": {"code": 10, "from": "riposte"},
	"instant_aim": {"code": 11, "from": "aimed_shot"},
	"full_aim": {"code": 12, "from": "aimed_shot"},
	"twin_jab": {"code": 13, "from": "jab"},
	"gale_flurry": {"code": 14, "from": "flurry"},
	"final_blow": {"code": 15, "from": "finisher"},
	"flow_guard": {"code": 16, "from": "flow"},
	"wave_palm": {"code": 17, "from": "palm"},
	"deep_breath": {"code": 18, "from": "breather"},
	"tempest": {"code": 19, "from": "storm"},
	"whirlwind": {"code": 20, "from": "spin_kick"},
	"counter_stance": {"code": 21, "from": "parry_stance"},
	"piercing_focus": {"code": 22, "from": "focus_strike"},
	"heavy_bash": {"code": 23, "from": "bash"},
	"bastion": {"code": 24, "from": "fortify"},
	"dominate": {"code": 25, "from": "suppress"},
	"boomerang": {"code": 26, "from": "shield_throw"},
	"steel_beat": {"code": 27, "from": "iron_beat"},
	"earthshaker": {"code": 28, "from": "slam"},
	"rapid_fire": {"code": 29, "from": "quickshot"},
	"triple_strike": {"code": 30, "from": "twin_slash"},
	"storm_volley": {"code": 31, "from": "volley"},
	"deep_point": {"code": 32, "from": "weak_point"},
	"arrow_storm": {"code": 33, "from": "arrow_rain"},
	"mana_shift": {"code": 34, "from": "fuel"},
	"tidal_torrent": {"code": 35, "from": "torrent"},
	"arcane_wall": {"code": 36, "from": "mana_veil"},
	"mark_surge": {"code": 37, "from": "mark_amp"},
	"ember_burst": {"code": 38, "from": "ember"},
	"grand_chain": {"code": 39, "from": "chain_blast"},
	"eternal_coffin": {"code": 40, "from": "ice_coffin"},
	"sun_rain": {"code": 41, "from": "light_rain"},
	"tempest_gust": {"code": 42, "from": "gust"},
	"terror_roar": {"code": 43, "from": "war_cry"},
	"soul_chain": {"code": 44, "from": "soul_link"},
	"smoke_screen": {"code": 45, "from": "smoke_bomb"},
	"fire_bounce": {"code": 46, "from": "fireball"},
	"pyre_burst": {"code": 47, "from": "fire_wall"},
	"frost_pierce": {"code": 48, "from": "frost_lance"},
	"hex_chain": {"code": 49, "from": "hex_bolt"},
	"swift_doom": {"code": 50, "from": "doom_brand"},
	"thousand_fists": {"code": 51, "from": "hundred_fists"},
}
# 보상·상인에 나오는 강화(아이디어·연출이 분명한 것만). 여기서 뺀 강화도 정의는 남겨 예전 저장의 카드는 그대로 동작
const UPGRADE_ORDER := ["instant_aim", "full_aim", "flow_guard", "wave_palm", "deep_breath", "whirlwind", "counter_stance", "piercing_focus", "dominate", "rapid_fire", "mana_shift", "eternal_coffin", "tempest_gust", "fire_bounce", "pyre_burst", "frost_pierce", "hex_chain", "swift_doom", "thousand_fists"]

# [이름, 마나, 수치, 색(0 물리/1 마법/2 공용), 광역, 효과(damage/defend/draw/fuel), 타수]
const CARDS := {
	"slash": ["베기", 1, 5, 0, false, "damage", 1],
	"bolt": ["마력탄", 1, 3, 1, false, "damage", 1],
	"guard": ["수호", 1, 5, 2, false, "defend", 0],
	"sweep": ["휩쓸기", 2, 4, 0, true, "damage", 1],
	"bash": ["방패 강타", 1, 4, 0, false, "damage", 1],
	"wave": ["마력 파동", 2, 5, 1, true, "damage", 1],
	"twin_slash": ["연속 타격", 1, 3, 0, false, "damage", 2],
	"pierce": ["관통 찌르기", 1, 4, 0, false, "damage", 1],
	"suppress": ["억제탄", 1, 2, 1, false, "damage", 1],
	"focus": ["집중", 1, 2, 2, false, "draw", 0],
	"sigil_burst": ["각인 파열", 2, 6, 1, false, "damage", 1],
	"fuel": ["연료화", 0, 2, 2, false, "fuel", 0],
	"torrent": ["마력 폭류", 1, 6, 1, false, "damage", 1],
	"mana_veil": ["마나 장막", 1, 4, 2, false, "defend", 0],
	"riposte": ["맞받아치기", 1, 4, 2, false, "defend", 0],
	"fortify": ["결사 방어", 1, 8, 2, false, "defend", 0],
	"quickshot": ["속사", 1, 5, 0, false, "damage", 1],
	"aimed_shot": ["조준 사격", 2, 8, 0, false, "damage", 1],
	"jab": ["잽", 0, 2, 0, false, "damage", 1],
	"flurry": ["연타", 1, 2, 0, false, "damage", 3],
	"finisher": ["마무리 일격", 2, 6, 0, false, "damage", 1],
	"flow": ["흐름 유지", 1, 5, 2, false, "defend", 0],
	"palm": ["반동 장타", 1, 4, 0, false, "damage", 1],
	"breather": ["숨 고르기", 0, 1, 2, false, "draw", 0],
	"storm": ["폭풍 연타", 2, 2, 0, false, "damage", 5],
	"spin_kick": ["회전 차기", 2, 3, 0, true, "damage", 2],
	"parry_stance": ["받아넘기기", 1, 4, 2, false, "defend", 0],
	"focus_strike": ["겨눈 일격", 1, 3, 0, false, "damage", 1],
	"shield_throw": ["방패 투척", 1, 2, 0, false, "damage", 1],
	"iron_beat": ["철벽 박자", 1, 5, 2, false, "defend", 0],
	"volley": ["연발 사격", 2, 2, 0, false, "damage", 3],
	"weak_point": ["급소 노리기", 0, 3, 0, false, "damage", 1],
	"mark_amp": ["표식 증폭", 1, 2, 1, false, "damage", 1],
	"ember": ["잔불", 0, 2, 1, false, "damage", 1],
	"beat_slash": ["박자 베기", 1, 3, 0, false, "damage", 1],
	"heal_sigil": ["치유의 문양", 1, 4, 1, false, "heal", 0],
	"slam": ["방패 내려찍기", 2, 4, 0, false, "damage", 1],
	"arrow_rain": ["화살비", 2, 2, 0, true, "damage", 5],
	"chain_blast": ["연쇄 폭발", 2, 2, 1, true, "damage", 1],
	"fireball": ["화염구", 1, 4, 1, false, "damage", 1],
	"fire_wall": ["업화의 벽", 2, 2, 1, true, "damage", 1],
	"frost_lance": ["서리 창", 1, 3, 1, false, "damage", 1],
	"ice_coffin": ["빙결의 관", 2, 2, 1, false, "damage", 1],
	"dark_rift": ["어둠의 균열", 2, 6, 1, false, "damage", 1],
	"light_rain": ["빛의 창", 2, 2, 1, true, "damage", 8],
	"gust": ["돌풍", 1, 2, 1, false, "damage", 1],
	"poison_cloud": ["맹독 구름", 1, 1, 1, true, "damage", 1],
	"focus_shot": ["집중 사격", 2, 6, 0, true, "damage", 1],
	"barrage": ["폭풍 연사", 2, 2, 0, false, "damage", 10],
	"bear_trap": ["사냥용 덫", 1, 5, 2, false, "debuff", 0],
	"mark_target": ["표적 지정", 0, 2, 2, false, "debuff", 0],
	"bleed_arrows": ["출혈 화살", 1, 2, 0, false, "damage", 3],
	"shield_boomerang": ["방패 부메랑", 2, 2, 0, true, "damage", 1],
	"rampart": ["성벽", 2, 10, 2, false, "defend", 0],
	"war_cry": ["위압의 함성", 1, 2, 2, true, "debuff", 0],
	"iron_counter": ["철벽 반격", 1, 4, 2, false, "defend", 0],
	"launcher": ["올려 차기", 1, 3, 0, false, "damage", 1],
	"hundred_fists": ["백열권", 2, 1, 0, false, "damage", 15],
	"ki_blast": ["기공파", 2, 6, 0, false, "damage", 1],
	"hex_bolt": ["저주탄", 1, 3, 1, false, "damage", 1],
	"doom_brand": ["파멸의 낙인", 1, 4, 1, false, "debuff", 0],
	"enfeeble": ["쇠약", 1, 2, 1, false, "debuff", 0],
	"armor_break": ["갑옷 부수기", 1, 3, 0, false, "damage", 1],
	"soul_link": ["고통 연결", 1, 0, 1, false, "debuff", 0],
	"blood_pact": ["피의 계약", 0, 3, 2, false, "buff", 0],
	"soul_drain": ["영혼 흡수", 2, 2, 1, true, "damage", 1],
	"plague": ["역병 전파", 1, 2, 1, true, "debuff", 0],
	"expose": ["약점 폭로", 1, 2, 2, false, "debuff", 0],
	"disarm": ["무력화", 1, 2, 2, false, "debuff", 0],
	"war_shout": ["전투 함성", 1, 3, 2, false, "buff", 0],
	"poison_coat": ["독 바르기", 1, 2, 2, false, "buff", 0],
	"first_aid": ["응급 처치", 1, 5, 2, false, "heal", 0],
	"smoke_bomb": ["연막", 1, 0, 2, false, "buff", 0],
	"ult_rune_caster": ["오원소 연사", 0, 3, 1, true, "damage", 1],
	"ult_hunter": ["천궁 일제사격", 0, 2, 0, true, "damage", 12],
	"ult_warden": ["심판의 방패", 0, 10, 0, true, "damage", 1],
	"ult_combo": ["만화 칸 연격", 0, 10, 0, false, "damage", 1],
	"ult_shaman": ["심판의 눈", 0, 4, 1, true, "damage", 1],
}
# 원소(반응용) · 카드가 거는 상태(맞은 뒤 살아 있는 대상마다) · 피해 없이 상태만 거는 카드
const CARD_ELEM := {"fireball": "fire", "fire_wall": "fire", "ember": "fire", "frost_lance": "ice", "ice_coffin": "ice", "gust": "wind",
	"light_rain": "light", "dark_rift": "dark", "poison_cloud": "poison", "ult_rune_caster": "all"}
const CARD_STATUS := {"fireball": {"burn": 3}, "fire_wall": {"burn": 4}, "frost_lance": {"chill": 2}, "ice_coffin": {"chill": 3},
	"dark_rift": {"vuln": 2, "umbra": 2}, "light_rain": {"lumen": 2}, "poison_cloud": {"poison": 3}, "hex_bolt": {"doom": 1}, "doom_brand": {"doom": 4}, "enfeeble": {"weak": 2, "vuln": 1},
	"expose": {"vuln": 2}, "disarm": {"weak": 2}, "war_cry": {"weak": 2}, "mark_target": {"vuln": 2}, "bear_trap": {"trap": 5}, "plague": {"doom": 2}}
const ULT_KINDS := {"rune_caster": "ult_rune_caster", "hunter": "ult_hunter", "warden": "ult_warden", "combo": "ult_combo", "shaman": "ult_shaman"}
const BURN_TICK_KEEP := 0.5
const CHILL_FREEZE := 3
const DOOM_TURNS := 2
const DOOM_MULT := 3
const VULN_MULT := 1.5
const WEAK_MULT := 0.75
const AIR_BONUS := 3
const FIRE_BOUNCE := 3
# 여덟 번 넘게 때리는 연타 기술은 타격마다 붙는 고정 보너스(분노·공중)를 1/3만 받는다
const RAPID_HITS := 8
const WALL_DEFAULT := 10
const IRON_COUNTER_DAMAGE := 5
const TRAP_BLEED := 3
const BARRAGE_DEFAULT := 10
const BARRAGE_MAX := 16
const BARRAGE_BLEED_EVERY := 5
const CHARGE_DEFAULT := 1.5
const CHARGE_MAX := 3.0
const RAIN_SPEARS := 8
const RAIN_SPEARS_PERFECT := 12
const GUST_SUPP := 3
const COAT_HITS := 3
const BLOOD_PACT_MULT := 1.5
const DRAIN_BONUS := 4
const DRAIN_HEAL_CAP := 8
const RAMPART_MAX := 10
const ULT_MAX := 100
const ULT_GAIN := {"vary": 3, "perfect_glyph": 6, "perfect_parry": 4, "reaction": 8}
const REACTION_NAME := {"shatter": "쇄빙!", "melt": "녹아내림!", "toxic": "유독 폭발!", "spread": "확산!", "doom": "저주 폭발!",
	"steam": "증기 폭발!", "pcrys": "독 결정!", "eclipse": "일식!"}
# 증기 폭발 = 소모한 얼음(냉기 + 얼어붙음 3) 또는 화상 × 3, 옆 적에게 절반 · 독 결정 = 독이 두 턴 줄지 않음 · 일식 = 대상 8 + 모든 적 취약 2
const STEAM_MULT := 3
const PCRYS_TURNS := 2
const ECLIPSE_DAMAGE := 8
const ECLIPSE_VULN := 2
# 원소술사 필살: 원소 빔 다섯 발(이 차례로), 발마다 모든 적에게 피해 + 그 원소를 묻힘 → 묻힌 원소끼리 차례로 반응
const ULT_BEAMS := [["fire", {"burn": 2}], ["ice", {"chill": 2}], ["poison", {"poison": 2}], ["light", {"lumen": 1}], ["dark", {"umbra": 1}]]
# 빌드 넓히기 카드 수치: 박자 베기·철벽 박자는 지난 적 차례 완벽 수, 잔불은 이번 전투 소진 수, 연발은 치명 확률을 받는다
const BEAT_SLASH_PER := 2
const BEAT_SLASH_CAP := 10
const IRON_BEAT_CAP := 5
const VOLLEY_MAX := 6
const MARK_AMP_CAP := 3
const EMBER_PER := 2
const HEAL_SIGIL_PERFECT := 3
const SPUR_STEP := 2
const SPUR_CAP := 6
const EMBER_JAR_BLOCK := 2
const EMBER_JAR_MAX := 2
const BRUSH_POWER := 0.2
const FORK_NEED := 3
const FORK_BONUS := 4
# 데이터로 붙이는 카드 효과(콤보술사부터): combo 연격 더하기 · per_combo 연격 1당 기본 피해 · spend 다 쓴 뒤 연격 0 ·
# keep 이번 턴이 끝나도 연격 유지 · need + draw 연격이 그 이상이면 뽑기 · cost 연격을 그만큼 써서 mana 얻기
const CARD_FX := {
	"jab": {"combo": 1},
	"finisher": {"per_combo": 2, "spend": true},
	"flow": {"keep": true},
	"palm": {"need": 3, "draw": 1},
	"breather": {"cost": 2, "mana": 1},
	"parry_stance": {"combo": 2},
	"focus_strike": {"per_combo": 1},
}
# 데이터 카드 글: [앞면 핵심(%d = 수치), 앞면 조건, 긴 설명]
const FX_TEXT := {
	"jab": ["물리 %d", "비용 0 · 연격 +1 더", "대상에게 물리 2. 연격이 한 번 더 오릅니다 (같은 적이면 +2)."],
	"flurry": ["물리 %d × 3", "같은 대상 세 번 · 연격이 쌓임", "같은 대상에게 물리 2를 세 번. 타격마다 연격이 오르고, 연격만큼 피해가 붙습니다."],
	"finisher": ["물리 %d + 연격×2", "연격을 모두 써서 더함 · 그 뒤 0", "대상에게 물리 6 + 지금 연격 1당 2. 친 뒤 연격은 0이 됩니다."],
	"flow": ["방어 %d", "이번 턴이 끝나도 연격 유지", "방어 5. 이번 턴이 끝나도 연격이 사라지지 않고 다음 턴으로 넘어갑니다."],
	"palm": ["물리 %d", "연격 3 이상이면 1장 뽑기", "대상에게 물리 4. 치기 전 연격이 3 이상이면 1장 뽑습니다."],
	"breather": ["카드 %d장 뽑기", "연격 2를 써서 마나 1", "1장 뽑습니다. 연격이 2 이상이면 2를 써서 마나 1을 얻습니다."],
	"storm": ["물리 %d × 5", "같은 대상 다섯 번", "같은 대상에게 물리 2를 다섯 번. 연격이 빠르게 쌓입니다."],
	"spin_kick": ["모든 적 물리 %d × 2", "광역은 연격을 쌓지도 깨지도 않음", "살아 있는 모든 적에게 물리 3을 두 번. 연격은 그대로입니다."],
	"parry_stance": ["방어 %d", "연격 +2", "방어 4. 연격이 2 오릅니다 (마지막으로 친 적 기준)."],
	"focus_strike": ["물리 %d + 연격", "연격은 그대로 남음", "대상에게 물리 3 + 지금 연격 1당 1. 연격은 쓰지 않습니다."],
	"shield_throw": ["물리 %d+방어½", "쌓인 방어의 절반을 더함 · 방어는 그대로", "대상에게 물리 2 + 지금 방어의 절반. 방어는 쓰지 않고 그대로 남습니다."],
	"iron_beat": ["방어 %d+완벽", "지난 적 차례 완벽 1번마다 방어 +1 (최대 +5)", "방어 5. 지난 적 차례에 완벽으로 막은 수만큼 방어가 더 붙습니다 (최대 +5)."],
	"volley": ["물리 %d×연발", "기본 3발 · 치명 확률 10%p마다 1발 더 (최대 6)", "대상에게 물리 2를 여러 번. 치명 확률 10%p마다 한 발 (기본 10%면 3발, 최대 6발)."],
	"weak_point": ["확정치명 %d", "비용 0 · 소진", "대상에게 물리 3. 반드시 치명타. 쓰면 이번 전투에서 사라집니다."],
	"mark_amp": ["마법 %d·표식×2", "살아남으면 표식이 지금만큼 더 (최대 +3)", "대상에게 마법 2. 살아남으면 대상의 표식이 지금 수만큼 더 붙습니다 (한 번에 최대 +3, 표식 한도까지)."],
	"ember": ["마법 %d+소진", "비용 0 · 소진 · 이번 전투 소진 1장당 +2", "대상에게 마법 2 + 이번 전투에서 소진된 카드 1장당 2. 쓰면 이 카드도 소진."],
	"beat_slash": ["물리 %d+완벽×2", "지난 적 차례 완벽 1번마다 +2 (최대 +10)", "대상에게 물리 3 + 지난 적 차례에 완벽으로 막은 수 × 2 (최대 +10)."],
	"heal_sigil": ["회복 %d", "하트를 그림 · 완벽이면 +3 · 소진", "주인공 위에 하트 문양을 그려 체력 4 회복 (완벽 문양이면 7). 쓰면 이번 전투에서 사라집니다."],
	"fireball": ["마법 %d + 화상 3", "불 · 화상은 턴을 끝낼 때 피해, 그 뒤 절반", "대상에게 마법 4, 화상 3. 화상은 내가 턴을 끝낼 때마다 그 수만큼 피해를 주고 절반으로 줄어듭니다. 냉기나 얼음이 있는 적이면 증기 폭발, 독이 있는 적이면 유독 폭발."],
	"fire_wall": ["모든 적 마법 %d + 화상 4", "불 · 이미 타는 적은 화상 8", "모든 적에게 마법 2, 화상 4. 이미 화상이 있는 적에게는 화상 8."],
	"frost_lance": ["마법 %d + 냉기 2", "얼음 · 냉기 3이면 얼어붙음 · 타는 적은 증기 폭발", "대상에게 마법 3, 냉기 2. 냉기가 3이 되면 얼어붙어 다음 적 차례에 공격하지 못합니다. 화상이 있는 적이면 증기 폭발, 독이 있는 적이면 독 결정."],
	"ice_coffin": ["마법 %d + 얼어붙음", "얼음 · 물리로 치면 쇄빙 · 불이면 증기 폭발", "대상에게 마법 2, 냉기 3: 바로 얼어붙어 다음 적 차례에 공격하지 못합니다. 얼어 있는 적을 물리 공격으로 치면 얼음이 깨지며 피해 ×2, 파편이 옆 적에게도 튑니다(대신 얼음이 풀림)."],
	"dark_rift": ["마법 %d + 어둠 기운", "어둠 · 취약 2 · 빛 기운이 있으면 일식", "대상에게 마법 6과 취약 2(2턴 동안 받는 피해 +50%), 어둠 기운을 남깁니다. 빛 기운이 있는 적이면 일식: 그 적에게 8, 모든 적 취약 2."],
	"light_rain": ["빛의 창 8개 × %d", "빛 · 빛 기운 · 어둠 기운이 있으면 일식", "하늘에서 빛의 창 8개가 적들에게 고루 떨어져 하나에 마법 2(완벽 문양이면 12개), 맞은 적에게 빛 기운을 남깁니다. 어둠 기운이 있는 적이면 일식: 그 적에게 8, 모든 적 취약 2."],
	"gust": ["마법 %d + 날려 버림", "바람 · 다음 공격 타격 −3 · 상태를 옆 적들에게", "대상을 날려 버려 마법 2, 그 적의 다음 공격은 타격마다 3 약해집니다. 대상의 화상·독·냉기가 다른 적 모두에게 똑같이 번집니다(확산)."],
	"poison_cloud": ["모든 적 마법 %d + 독 3", "독은 턴을 끝낼 때 피해, 그 뒤 1 줄어듦", "모든 적에게 마법 1, 독 3. 독은 내가 턴을 끝낼 때마다 그 수만큼 피해를 주고 1 줄어듭니다. 타는 적이면 유독 폭발, 냉기나 얼음이 있는 적이면 독 결정(두 턴 동안 독이 줄지 않음)."],
	"focus_shot": ["모든 적 관통 %d · 모으면 ×3", "누른 채 버티다 놓기 · 갑옷 무시", "카드를 내고 누른 채 버티면 힘이 모입니다(최대 ×3, 금빛 구간에서 놓으면 치명). 놓으면 일직선의 모든 적을 꿰뚫어 물리 6 × 모은 배율, 갑옷 무시."],
	"barrage": ["물리 %d × 누른 만큼", "1.5초 동안 빠르게 클릭(최대 16발) · 5발마다 출혈 1", "카드를 내고 1.5초 동안 클릭(아무 키)하는 만큼 화살을 쏩니다(최대 16발, 너무 빠른 연속 입력은 세지 않음). 한 발에 물리 2, 5발마다 출혈 1."],
	"bear_trap": ["덫 %d", "그 적이 공격하러 오면 닫힘: 피해 + 출혈 3 · 첫 타격 사라짐", "대상 앞에 덫을 놓습니다. 그 적이 다음에 공격하러 오면 덫이 닫혀 5 피해, 출혈 3, 그 공격의 첫 타격이 사라집니다."],
	"mark_target": ["취약 %d · 다음 공격 확정 치명", "비용 0", "대상에게 취약 2(받는 피해 +50%). 내 다음 공격 카드는 반드시 치명."],
	"bleed_arrows": ["물리 %d × 3 + 출혈", "맞을 때마다 출혈 1", "대상에게 물리 2를 세 번, 맞을 때마다 출혈 1. 출혈은 그 적이 공격할 때마다 그만큼 피해를 주고 1 줄어듭니다."],
	"shield_boomerang": ["모든 적 %d+방어½, 튕길수록 +2", "적 사이를 튕기고 돌아옴 · 방어는 그대로", "방패가 모든 적을 차례로 튕기며 물리 2 + 방어의 절반, 다음 적으로 튕길 때마다 +2. 방어는 쓰지 않습니다."],
	"rampart": ["성벽 %d", "이번 적 차례: 먼저 받는 피해 10 흡수 · 막은 만큼 되돌림", "앞에 빛의 성벽을 세웁니다. 이번 적 차례에 들어오는 피해를 먼저 10까지 막고, 막은 만큼 공격한 적에게 되돌립니다."],
	"war_cry": ["모든 적 약화 %d", "약화: 적이 주는 피해 −25%", "모든 적에게 약화 2: 2턴 동안 적이 주는 피해 −25%."],
	"iron_counter": ["방어 %d · 완벽 반격 5", "이번 적 차례 완벽 막기 반격이 5로", "방어 4. 이번 적 차례에 완벽으로 막을 때마다 그 적에게 5."],
	"launcher": ["물리 %d · 공중에 띄움", "띄운 적에게 이번 턴 타격마다 +3 (연타 기술은 +1)", "대상을 공중에 띄웁니다(물리 3). 이번 턴 동안 그 적에게 들어가는 타격마다 +3. 여덟 번 넘게 때리는 연타 기술은 타격마다 +1."],
	"hundred_fists": ["물리 %d × 15", "연격을 가득 채움 · 이 기술엔 연격 피해 없음", "같은 대상에게 물리 1을 열다섯 번, 타격마다 연격 +1. 이 기술 자체에는 연격 피해가 붙지 않습니다(다음 기술을 위한 준비)."],
	"ki_blast": ["물리 %d · 모으면 ×3", "누른 채 버티다 놓기", "카드를 내고 누른 채 버티면 기가 모입니다(최대 ×3, 금빛 구간에서 놓으면 치명). 놓으면 대상에게 물리 6 × 모은 배율."],
	"hex_bolt": ["마법 %d + 저주 1", "저주: 2턴 뒤 쌓인 만큼 × 3 폭발", "대상에게 마법 3, 저주 1. 저주는 처음 걸린 지 2턴 뒤(턴을 끝낼 때) 쌓인 양 × 3 피해로 터집니다."],
	"doom_brand": ["저주 %d", "2턴 뒤 쌓인 저주 × 3 폭발", "대상에게 저주 4. 처음 걸린 지 2턴 뒤 턴을 끝낼 때 쌓인 저주 × 3 피해로 터집니다."],
	"enfeeble": ["약화 %d + 취약 1", "약화: 주는 피해 −25% · 취약: 받는 피해 +50%", "대상에게 약화 2(적이 주는 피해 −25%)와 취약 1(받는 피해 +50%)."],
	"armor_break": ["갑옷 0 + 물리 %d", "갑옷·방패를 이번 전투 동안 없앰", "대상의 갑옷과 방패를 이번 전투 동안 없앤 뒤 물리 3."],
	"soul_link": ["고통 연결", "두 적을 묶음: 한쪽 피해의 절반이 다른 쪽에도", "대상과, 다른 적 중 체력이 가장 높은 적을 사슬로 묶습니다. 한쪽이 카드 피해를 받으면 절반이 다른 쪽에도 들어갑니다."],
	"blood_pact": ["체력 −%d → 이번 턴 공격 ×1.5", "비용 0", "체력 3을 바쳐 이번 턴 공격 피해 ×1.5."],
	"soul_drain": ["모든 적 마법 %d + 저주받은 적 +4", "저주받은 적에게 준 만큼 회복 (최대 8)", "모든 적에게 마법 2. 저주가 걸린 적에게는 4 더, 그 적들에게 준 피해만큼 체력 회복(최대 8)."],
	"plague": ["모든 적 저주 %d", "저주: 2턴 뒤 쌓인 만큼 × 3 폭발", "모든 적에게 저주 2."],
	"expose": ["취약 %d", "받는 피해 +50% (2턴)", "대상에게 취약 2: 2턴 동안 받는 피해 +50%."],
	"disarm": ["약화 %d", "적이 주는 피해 −25% (2턴)", "대상에게 약화 2: 2턴 동안 적이 주는 피해 −25%."],
	"war_shout": ["이번 턴 타격마다 +%d", "자신 강화 · 연타 기술은 +1", "이번 턴 동안 공격 카드 타격마다 +3. 여덟 번 넘게 때리는 연타 기술은 타격마다 +1."],
	"poison_coat": ["물리 3타에 독 %d씩", "다음 물리 타격 3번", "다음 물리 공격 타격 3번에 독 2씩을 묻힙니다."],
	"first_aid": ["회복 %d", "소진", "체력 5 회복. 쓰면 이번 전투에서 사라집니다."],
	"smoke_bomb": ["연막", "이번 적 차례 첫 타격 빗나감", "연막을 터뜨립니다. 이번 적 차례에 처음 들어오는 타격 하나가 빗나갑니다."],
	"ult_rune_caster": ["원소 빔 다섯 발 × %d", "필살 · 불 → 얼음 → 독 → 빛 → 어둠", "원소 빔 다섯 발을 차례로 쏩니다. 발마다 모든 적에게 마법 3과 그 원소(화상 · 냉기 · 독 · 빛 기운 · 어둠 기운)를 묻혀, 묻힌 원소끼리 차례로 반응합니다(증기 폭발 · 독 결정 · 일식 등)."],
	"ult_hunter": ["모든 적 물리 %d × 12", "필살 · 맞을 때마다 출혈", "하늘을 덮는 화살비: 모든 적에게 물리 2를 열두 번, 맞을 때마다 출혈 1."],
	"ult_warden": ["모든 적 %d + 방어×2", "필살 · 모든 적 갑옷 0", "하늘에서 거대한 방패가 내리꽂힘: 모든 적에게 물리 10 + 방어 × 2, 모든 적의 갑옷이 이번 전투 동안 0."],
	"ult_combo": ["물리 %d + 연격×6", "필살 · 연격을 모두 씀", "대상에게 물리 10 + 연격 1당 6. 연격은 0이 됩니다."],
	"ult_shaman": ["모든 저주 즉시 ×2", "필살", "모든 적의 저주가 바로 두 배로 터지고, 그 뒤 모든 적에게 저주 3."],
	"slam": ["물리 %d + 방어×2", "방어는 그대로 · 다른 적 모두에게 방어의 절반", "대상에게 물리 4 + 지금 방어 × 2. 다른 적 모두에게는 방어의 절반. 방어는 쓰지 않고 그대로 남습니다."],
	"arrow_rain": ["모든 적 물리 %d × 5", "적마다 다섯 발 · 치명이면 다섯 발 모두", "살아 있는 모든 적에게 물리 2를 다섯 번씩 쏟아붓습니다. 치명이면 모든 화살이 치명입니다."],
	"chain_blast": ["모든 적 마법 %d + 표식×4", "표식을 모두 터뜨림 · 3개 이상 터진 적은 다른 적 모두에게 3", "모든 적에게 마법 2 + 그 적의 표식 1개당 4 (표식은 모두 터짐). 표식이 3개 이상 터진 적은 다른 적 모두에게 3을 더 줍니다."],
}
# 강화 사본의 수치는 기본 카드 조정과 무관하게 명시한다 (얻은 강화를 약하게 만들지 않는다)
const UPGRADE_VALUE := {"split": 3, "counter": 7, "cleave_slash": 6, "carry_guard": 7, "pursuit_slash": 7,
	"transfer_burst": 9, "reflux_burst": 9, "layered_riposte": 8, "instant_aim": 12,
	"final_blow": 8, "flow_guard": 8, "wave_palm": 6, "deep_breath": 2, "counter_stance": 6, "piercing_focus": 5,
	"heavy_bash": 7, "bastion": 12, "steel_beat": 7, "earthshaker": 6,
	"rapid_fire": 4, "deep_point": 7,
	"tidal_torrent": 8, "arcane_wall": 7, "mark_surge": 3, "ember_burst": 3, "grand_chain": 3,
	"eternal_coffin": 4, "sun_rain": 2, "tempest_gust": 3, "terror_roar": 3, "fire_bounce": 4, "pyre_burst": 2, "frost_pierce": 3, "hex_chain": 3}
# 새 강화 사본: 타수 바꿈 · 데이터 효과 덮어쓰기(연격) · 모든 적으로 · 앞면 두 줄
const UPGRADE_HITS := {"twin_jab": 2, "gale_flurry": 4, "tempest": 7, "whirlwind": 3, "boomerang": 2, "rapid_fire": 2, "triple_strike": 3, "arrow_storm": 8}
const UPGRADE_FX := {"final_blow": {"per_combo": 3}, "wave_palm": {"draw": 2}, "counter_stance": {"combo": 3}, "piercing_focus": {"per_combo": 2}}
const UPGRADE_AOE := ["dominate", "tempest_gust", "frost_pierce"]
const UPGRADE_COST := {"soul_chain": 0}
# 강화가 거는 상태(없으면 원래 카드 것)
const UPGRADE_STATUS := {"eternal_coffin": {"chill": 3, "vuln": 1}, "terror_roar": {"weak": 3, "vuln": 1}}
const UPGRADE_FACE := {
	"twin_jab": ["물리 %d × 2", "비용 0 · 연격 +1 더"],
	"gale_flurry": ["물리 %d × 4", "같은 대상 네 번 · 연격이 쌓임"],
	"final_blow": ["물리 %d + 연격×3", "연격을 모두 써서 더함 · 그 뒤 0"],
	"flow_guard": ["방어 %d", "이번 턴이 끝나도 연격 유지"],
	"wave_palm": ["물리 %d", "연격 3 이상이면 2장 뽑기"],
	"deep_breath": ["카드 %d장 뽑기", "연격 2를 써서 마나 1"],
	"tempest": ["물리 %d × 7", "같은 대상 일곱 번"],
	"whirlwind": ["모든 적 물리 %d × 3", "광역은 연격을 쌓지도 깨지도 않음"],
	"counter_stance": ["방어 %d", "연격 +3"],
	"piercing_focus": ["물리 %d + 연격×2", "연격은 그대로 남음"],
	"heavy_bash": ["물리 %d + 방어×2", "모아 둔 방어를 최대 4 써서 더함"],
	"bastion": ["방어 %d", "이번 전투에서 소진"],
	"dominate": ["모든 적 마법 %d · 억제 2", "적마다 다음 공격 타격 −2"],
	"boomerang": ["(물리 %d+방어½) × 2", "갔다가 돌아오며 두 번 · 방어는 그대로"],
	"steel_beat": ["방어 %d+완벽×2", "지난 적 차례 완벽 1번마다 +2 (최대 +10)"],
	"earthshaker": ["물리 %d + 방어×3", "방어는 그대로 · 다른 적 모두에게 방어만큼"],
	"rapid_fire": ["물리 %d × 2", "이번 턴 첫 공격이면 1장 뽑기"],
	"triple_strike": ["물리 %d × 3", "같은 대상 세 번"],
	"storm_volley": ["물리 %d×연발+2", "기본 5발 · 치명 확률 10%p마다 1발 더 (최대 8)"],
	"deep_point": ["확정치명 %d", "비용 0 · 소진"],
	"arrow_storm": ["모든 적 물리 %d × 8", "적마다 여덟 발"],
	"mana_shift": ["마나 +3", "손패의 다른 카드 1장과 함께 소진"],
	"tidal_torrent": ["마법 %d × X", "마나를 전부(X) 씀 · 살아남으면 표식 1"],
	"arcane_wall": ["방어 %d + 마나×2", "남은 마나 1당 +2 (최대 +6)"],
	"mark_surge": ["마법 %d·표식×2", "살아남으면 표식이 지금만큼 더 (최대 +5)"],
	"ember_burst": ["마법 %d+소진×3", "비용 0 · 소진 · 이번 전투 소진 1장당 +3"],
	"grand_chain": ["모든 적 마법 %d + 표식×6", "표식을 모두 터뜨림 · 3개 이상 터진 적은 다른 적 모두에게 3"],
	"eternal_coffin": ["마법 %d + 얼어붙음 + 취약 1", "얼음 · 얼린 적을 물리로 치면 쇄빙(×2)"],
	"sun_rain": ["빛의 창 12개 × %d", "빛 · 적들에게 고루 · 완벽 문양이면 16개"],
	"tempest_gust": ["모든 적 마법 %d + 날려 버림", "바람 · 모든 적 다음 공격 타격 −3 · 상태 확산"],
	"fire_bounce": ["마법 %d + 화상 3, 옆 적에 튐", "튀어서 다른 적에게 3 + 화상 3"],
	"pyre_burst": ["모든 적 마법 %d + 화상 4", "타는 적은 화상 × 2를 바로 터뜨림"],
	"frost_pierce": ["모든 적 마법 %d + 냉기 2", "일직선으로 모두 꿰뚫음"],
	"hex_chain": ["마법 %d + 저주 1", "저주 걸린 적이면 다른 적 모두에게도 저주 1"],
	"swift_doom": ["저주 %d", "이번 턴을 끝낼 때 바로 폭발"],
	"thousand_fists": ["물리 %d × 15", "마지막 한 방에 연격 × 2"],
	"terror_roar": ["모든 적 약화 %d + 취약 1", "약화: 적이 주는 피해 −25%"],
	"soul_chain": ["고통 연결", "비용 0 · 한쪽 피해의 절반이 다른 쪽에도"],
	"smoke_screen": ["짙은 연막", "이번 적 차례 첫 두 타격 빗나감"],
}
const STEEL_BEAT_PER := 2
const STEEL_BEAT_CAP := 10
const MARK_SURGE_CAP := 5
const EMBER_BURST_PER := 3
const SHIFT_MANA := 3
const STORM_VOLLEY_EXTRA := 2
const EARTH_MULT := 3
const GRAND_CHAIN_PER := 6
const EXHAUST_KINDS := ["fuel", "fortify", "weak_point", "ember", "heal_sigil", "first_aid"]
const X_COST_KINDS := ["torrent"]
const COUNTER_VALUES := {"counter": 4, "riposte": 2, "fierce_riposte": 6, "layered_riposte": 3}
const WARDEN_COUNTER_BONUS := 1
const BASH_MAX_SPEND := 4
const AIM_CHARGED := 12
const FULL_AIM_CHARGED := 18
const CARRY_GUARD_CAP := 3
const FUEL_MANA := 2
const VEIL_BONUS_CAP := 6
const HEX_AMOUNT := 2
const UPGRADES := {
	"split": {"name": "분열 마력탄", "text": "마력탄 사본 한 장: 대상에게 마법 3을 두 번. 피해가 들어가고 살아남으면 타격마다 표식 1."},
	"counter": {"name": "반격 수호", "text": "수호 사본 한 장: 방어 7. 이번 적 단계에 방어로 막아 내면 공격자에게 반격 4 (한 번, 수호기사 5)."},
	"cleave_slash": {"name": "가르기", "text": "베기 사본 한 장: 대상에게 물리 6, 그 뒤 다른 살아 있는 적마다 2 (갑옷 적용, 표식 무관)."},
	"double_inscription": {"name": "이중 각인", "text": "마력 파동 사본 한 장: 모든 적에게 마법 5. 살아남은 적마다 표식이 1개 더 붙습니다."},
	"carry_guard": {"name": "남겨둔 방패", "text": "수호 사본 한 장: 방어 7. 이 카드를 쓴 턴의 적 단계가 끝나면 남은 방어를 3까지 다음 턴으로 넘깁니다 (잔류 방패와 합치지 않고 큰 값)."},
	"pursuit_slash": {"name": "추격 베기", "text": "베기 사본 한 장: 물리 7. 이 카드로 적을 직접 쓰러뜨리면 마나 1 (턴마다 한 번)."},
	"transfer_burst": {"name": "전이 파열", "text": "각인 파열 사본 한 장: 마법 9 + 표식 1개당 3. 그 뒤 다른 살아 있는 적마다 소비한 표식 수 × 2 (갑옷 적용)."},
	"reflux_burst": {"name": "역류 파열", "text": "각인 파열 사본 한 장: 마법 9 + 표식 1개당 3. 표식을 2개 이상 소비하면 마나 1 (턴마다 한 번)."},
	"fierce_riposte": {"name": "매서운 응수", "text": "맞받아치기 사본 한 장: 방어 4. 막아 내면 반격 6 한 번 (수호기사 7)."},
	"layered_riposte": {"name": "두 겹 응수", "text": "맞받아치기 사본 한 장: 방어 8. 막아 내면 반격 3 한 번 (수호기사 4)."},
	"instant_aim": {"name": "즉응 사격", "text": "조준 사격 사본 한 장: 곧바로 물리 12. 손에 남지 않고 충전되지 않습니다."},
	"full_aim": {"name": "완전 조준", "text": "조준 사격 사본 한 장: 물리 8. 쓰지 않고 손에 남긴 채 턴을 넘기면 18이 됩니다 (보존)."},
	"twin_jab": {"name": "쌍잽", "text": "잽 사본 한 장: 대상에게 물리 2를 두 번. 연격이 한 번 더 오릅니다."},
	"gale_flurry": {"name": "질풍 연타", "text": "연타 사본 한 장: 같은 대상에게 물리 2를 네 번."},
	"final_blow": {"name": "끝장 일격", "text": "마무리 일격 사본 한 장: 대상에게 물리 8 + 지금 연격 1당 3. 친 뒤 연격은 0."},
	"flow_guard": {"name": "흐름 잇기", "text": "흐름 유지 사본 한 장: 방어 8. 이번 턴이 끝나도 연격이 다음 턴으로 넘어갑니다."},
	"wave_palm": {"name": "파동 장타", "text": "반동 장타 사본 한 장: 대상에게 물리 6. 치기 전 연격이 3 이상이면 2장 뽑습니다."},
	"deep_breath": {"name": "깊은 호흡", "text": "숨 고르기 사본 한 장: 2장 뽑습니다. 연격이 2 이상이면 2를 써서 마나 1."},
	"tempest": {"name": "폭풍 난무", "text": "폭풍 연타 사본 한 장: 같은 대상에게 물리 2를 일곱 번."},
	"whirlwind": {"name": "선풍각", "text": "회전 차기 사본 한 장: 모든 적에게 물리 3을 세 번. 연격은 그대로입니다."},
	"counter_stance": {"name": "받아치기 자세", "text": "받아넘기기 사본 한 장: 방어 6. 연격이 3 오릅니다."},
	"piercing_focus": {"name": "꿰뚫는 일격", "text": "겨눈 일격 사본 한 장: 대상에게 물리 5 + 지금 연격 1당 2. 연격은 쓰지 않습니다."},
	"heavy_bash": {"name": "묵직한 강타", "text": "방패 강타 사본 한 장: 모아 둔 방어를 최대 4 써서 대상에게 물리 7 + 쓴 방어 × 2."},
	"bastion": {"name": "철벽", "text": "결사 방어 사본 한 장: 방어 12. 이번 전투에서 소진됩니다."},
	"dominate": {"name": "위압", "text": "억제탄 사본 한 장: 모든 적에게 마법 2. 적마다 다음 공격 타격이 2씩 줄어듭니다."},
	"boomerang": {"name": "되돌아오는 방패", "text": "방패 투척 사본 한 장: 대상에게 (물리 2 + 지금 방어의 절반)을 두 번. 방어는 그대로 남습니다."},
	"steel_beat": {"name": "강철 박자", "text": "철벽 박자 사본 한 장: 방어 7 + 지난 적 차례에 완벽으로 막은 수 × 2 (최대 +10)."},
	"earthshaker": {"name": "대지 붕괴", "text": "방패 내려찍기 사본 한 장: 대상에게 물리 6 + 지금 방어 × 3, 다른 적 모두에게 방어만큼. 방어는 그대로."},
	"rapid_fire": {"name": "연속 속사", "text": "속사 사본 한 장: 대상에게 물리 4를 두 번. 이번 턴 첫 공격 카드면 1장 뽑습니다."},
	"triple_strike": {"name": "삼연 타격", "text": "연속 타격 사본 한 장: 같은 대상에게 물리 3을 세 번."},
	"storm_volley": {"name": "폭풍 연발", "text": "연발 사격 사본 한 장: 연발 사격보다 2발 더 쏩니다 (기본 5발, 최대 8발)."},
	"deep_point": {"name": "깊은 급소", "text": "급소 노리기 사본 한 장: 대상에게 물리 7, 반드시 치명. 쓰면 이번 전투에서 사라집니다."},
	"arrow_storm": {"name": "화살 폭우", "text": "화살비 사본 한 장: 모든 적에게 물리 2를 여덟 번씩."},
	"mana_shift": {"name": "마력 전환", "text": "연료화 사본 한 장: 손패의 다른 카드 1장과 함께 이번 전투에서 소진하고 마나 +3."},
	"tidal_torrent": {"name": "마력 해일", "text": "마력 폭류 사본 한 장: 마나를 전부(X) 써서 대상에게 마법 8 × X. 살아남으면 표식 1."},
	"arcane_wall": {"name": "마력 방벽", "text": "마나 장막 사본 한 장: 방어 7 + 비용을 낸 뒤 남은 마나 × 2 (추가 최대 6)."},
	"mark_surge": {"name": "표식 폭증", "text": "표식 증폭 사본 한 장: 대상에게 마법 3. 살아남으면 표식이 지금 수만큼 더 붙습니다 (최대 +5)."},
	"ember_burst": {"name": "잿불 폭발", "text": "잔불 사본 한 장: 대상에게 마법 3 + 이번 전투에서 소진된 카드 1장당 3. 쓰면 이 카드도 소진."},
	"grand_chain": {"name": "대연쇄", "text": "연쇄 폭발 사본 한 장: 모든 적에게 마법 3 + 표식 1개당 6. 표식 3개 이상 터진 적은 다른 적 모두에게 3."},
	"eternal_coffin": {"name": "영원의 관", "text": "빙결의 관 사본 한 장: 대상에게 마법 4, 냉기 3으로 바로 얼어붙고 취약 1(받는 피해 +50%)."},
	"sun_rain": {"name": "태양의 창", "text": "빛의 창 사본 한 장: 빛의 창 12개가 적들에게 고루 떨어져 하나에 마법 2. 완벽 문양이면 16개."},
	"tempest_gust": {"name": "폭풍", "text": "돌풍 사본 한 장: 모든 적을 날려 버려 마법 3, 적마다 다음 공격 타격이 3 약해집니다. 화상·독·냉기가 다른 적에게 번집니다."},
	"fire_bounce": {"name": "튀는 화염구", "text": "화염구 사본 한 장: 대상에게 마법 4 + 화상 3, 그 뒤 불덩이가 체력이 가장 낮은 다른 적에게 튀어 3 + 화상 3."},
	"pyre_burst": {"name": "불기둥 폭발", "text": "업화의 벽 사본 한 장: 이미 화상이 있는 적은 그 화상의 두 배만큼 바로 피해를 받고(화상은 사라짐), 그 뒤 모든 적에게 마법 2와 화상 4."},
	"frost_pierce": {"name": "꿰뚫는 서리", "text": "서리 창 사본 한 장: 창이 일직선으로 모든 적을 꿰뚫어 마법 3과 냉기 2."},
	"hex_chain": {"name": "번지는 저주", "text": "저주탄 사본 한 장: 마법 3과 저주 1. 이미 저주가 걸린 적을 맞히면 다른 적 모두에게도 저주 1이 옮겨 붙습니다."},
	"swift_doom": {"name": "급속 파멸", "text": "파멸의 낙인 사본 한 장: 저주 4. 2턴을 기다리지 않고 이번 턴을 끝낼 때 바로 터집니다."},
	"thousand_fists": {"name": "천열권", "text": "백열권 사본 한 장: 물리 1을 열다섯 번, 마지막 한 방에는 지금 연격 × 2가 실립니다."},
	"terror_roar": {"name": "공포의 함성", "text": "위압의 함성 사본 한 장: 모든 적에게 약화 3과 취약 1."},
	"soul_chain": {"name": "영혼 사슬", "text": "고통 연결 사본 한 장: 비용 0. 대상과 체력이 가장 높은 다른 적을 사슬로 묶습니다."},
	"smoke_screen": {"name": "연막 장막", "text": "연막 사본 한 장: 이번 적 차례에 처음 들어오는 타격 둘이 빗나갑니다."},
}

# ── 카드 획득 (보스 외 승리마다 3후보 중 1장 또는 건너뛰기) ──────────────────────────
# 보상에 나오는 직업 카드(기본 카드 베기 · 수호 · 집중 · 마력탄은 빼고, 원소술사의 표식 카드도 뺌)
const CLASS_CARD_POOL := {
	"rune_caster": ["wave", "fuel", "torrent", "mana_veil", "ember", "fireball", "fire_wall", "frost_lance", "ice_coffin", "dark_rift", "light_rain", "gust", "poison_cloud"],
	"warden": ["bash", "riposte", "fortify", "suppress", "pierce", "shield_throw", "iron_beat", "slam", "shield_boomerang", "rampart", "war_cry", "iron_counter"],
	"hunter": ["quickshot", "twin_slash", "aimed_shot", "pierce", "volley", "weak_point", "arrow_rain", "focus_shot", "barrage", "bear_trap", "mark_target", "bleed_arrows"],
	"combo": ["jab", "flurry", "finisher", "flow", "palm", "breather", "storm", "spin_kick", "parry_stance", "focus_strike", "launcher", "hundred_fists", "ki_blast"],
	"shaman": ["hex_bolt", "doom_brand", "enfeeble", "armor_break", "soul_link", "blood_pact", "soul_drain", "plague"],
}
const COMMON_CARD_POOL := ["sweep", "pierce", "beat_slash", "heal_sigil", "expose", "disarm", "war_shout", "poison_coat", "first_aid", "smoke_bomb"]
const REWARD_COUNT := 4
# 카드 주인 직업(앞면 문장 · 도움말). 없으면 공용
const CARD_CLASS := {"bolt": "rune_caster", "wave": "rune_caster", "sigil_burst": "rune_caster", "fuel": "rune_caster", "torrent": "rune_caster", "mana_veil": "rune_caster",
	"bash": "warden", "riposte": "warden", "fortify": "warden", "suppress": "warden", "shield_throw": "warden", "iron_beat": "warden",
	"quickshot": "hunter", "twin_slash": "hunter", "aimed_shot": "hunter", "volley": "hunter", "weak_point": "hunter", "mark_amp": "rune_caster", "ember": "rune_caster",
	"jab": "combo", "flurry": "combo", "finisher": "combo", "flow": "combo", "palm": "combo", "breather": "combo", "storm": "combo",
	"spin_kick": "combo", "parry_stance": "combo", "focus_strike": "combo", "slam": "warden", "arrow_rain": "hunter", "chain_blast": "rune_caster",
	"fireball": "rune_caster", "fire_wall": "rune_caster", "frost_lance": "rune_caster", "ice_coffin": "rune_caster", "dark_rift": "rune_caster", "light_rain": "rune_caster",
	"gust": "rune_caster", "poison_cloud": "rune_caster", "focus_shot": "hunter", "barrage": "hunter", "bear_trap": "hunter", "mark_target": "hunter", "bleed_arrows": "hunter",
	"shield_boomerang": "warden", "rampart": "warden", "war_cry": "warden", "iron_counter": "warden", "launcher": "combo", "hundred_fists": "combo", "ki_blast": "combo",
	"hex_bolt": "shaman", "doom_brand": "shaman", "enfeeble": "shaman", "armor_break": "shaman", "soul_link": "shaman", "blood_pact": "shaman", "soul_drain": "shaman", "plague": "shaman",
	"ult_rune_caster": "rune_caster", "ult_hunter": "hunter", "ult_warden": "warden", "ult_combo": "combo", "ult_shaman": "shaman"}
const CLASS_COLOR := {"rune_caster": Color("#4fb8e8"), "warden": Color("#e0ad4a"), "hunter": Color("#6aa84f"), "combo": Color("#e2643c"), "shaman": Color("#b05ad8")}
# 다른 직업 종류(다리 후보)는 덱에 전제가 있을 때만: 표식을 쓰는 카드는 표식 원천, 방어를 쓰는 카드는 방어 원천
const MARK_SOURCES := ["bolt", "wave", "suppress", "torrent"]
const DEFENSE_SOURCES := ["guard", "fortify", "mana_veil", "riposte"]
const BRIDGE_PREREQ := {"sigil_burst": "mark", "bash": "defense", "riposte": "defense", "slam": "defense", "chain_blast": "mark"}
const BASIC_KINDS := ["slash", "guard", "bolt"]
const BASIC_COPY_MAX := 3
const COPY_MAX := 2
const FUEL_CAP := 1
const RETAIN_CAP := 2
const CARD_ROLES := {
	"slash": "attack", "bolt": "attack", "sweep": "attack", "wave": "attack", "twin_slash": "attack", "pierce": "attack",
	"sigil_burst": "attack", "torrent": "attack", "quickshot": "attack", "aimed_shot": "attack", "bash": "attack",
	"guard": "defense", "riposte": "defense", "fortify": "defense", "mana_veil": "defense",
	"focus": "tool", "fuel": "tool", "suppress": "tool",
	"jab": "attack", "flurry": "attack", "finisher": "attack", "palm": "attack", "storm": "attack", "spin_kick": "attack", "focus_strike": "attack",
	"flow": "defense", "parry_stance": "defense", "breather": "tool",
	"slam": "attack", "arrow_rain": "attack", "chain_blast": "attack",
	"fireball": "attack", "fire_wall": "attack", "frost_lance": "attack", "ice_coffin": "attack", "dark_rift": "attack", "light_rain": "attack", "gust": "attack", "poison_cloud": "attack",
	"focus_shot": "attack", "barrage": "attack", "bear_trap": "tool", "mark_target": "tool", "bleed_arrows": "attack", "shield_boomerang": "attack", "rampart": "defense",
	"war_cry": "tool", "iron_counter": "defense", "launcher": "attack", "hundred_fists": "attack", "ki_blast": "attack", "hex_bolt": "attack", "doom_brand": "tool",
	"enfeeble": "tool", "armor_break": "attack", "soul_link": "tool", "blood_pact": "tool", "soul_drain": "attack", "plague": "tool", "expose": "tool", "disarm": "tool",
	"war_shout": "tool", "poison_coat": "tool", "first_aid": "tool", "smoke_bomb": "defense",
}
const DECK_VALIDATE_CAP := 32
const DECK_SCROLL_AT := 22
const MIN_DECK := 6
# 모아 둔 방어 없이 피해를 주는 카드 (구성 규칙 검사용)
const DIRECT_KINDS := ["slash", "bolt", "sweep", "wave", "twin_slash", "pierce", "suppress", "sigil_burst", "torrent", "quickshot", "aimed_shot",
	"jab", "flurry", "finisher", "palm", "storm", "spin_kick", "focus_strike", "slam", "arrow_rain", "chain_blast",
	"fireball", "fire_wall", "frost_lance", "ice_coffin", "dark_rift", "light_rain", "gust", "poison_cloud", "focus_shot", "barrage", "bleed_arrows",
	"shield_boomerang", "launcher", "hundred_fists", "ki_blast", "hex_bolt", "armor_break", "soul_drain"]
const CLASS_UPGRADE_PREF := {
	"rune_caster": ["fire_bounce", "pyre_burst", "frost_pierce", "eternal_coffin", "tempest_gust", "mana_shift"],
	"warden": ["dominate"],
	"hunter": ["instant_aim", "full_aim", "rapid_fire"],
	"combo": ["thousand_fists", "flow_guard", "wave_palm", "deep_breath", "whirlwind", "counter_stance", "piercing_focus"],
	"shaman": ["hex_chain", "swift_doom"],
}
const CLASS_RELIC_LINK := {
	"rune_caster": ["arc", "rift_heart", "furnace_seal", "ember_jar", "ember_heart", "frost_crown", "eclipse_ring", "spread_fan"],
	"warden": ["thorn", "absorb", "furnace_seal", "shield_spur", "cruel_eye"],
	"hunter": ["crit_capacitor", "echo_string", "obsidian_lens", "patient_glove", "hunter_lens", "red_sun", "trapper_jaw", "cruel_eye"],
	"combo": ["blade_rhythm", "satchel", "echo_edge", "beat_pendulum", "hunter_lens", "combo_glove", "cruel_eye"],
	"shaman": ["thorn", "bandage", "furnace_seal", "ember_jar", "reserve_seal", "doom_skull", "blood_chalice", "spread_fan", "cruel_eye"],
}
const BRIDGE_RELICS := ["bandage", "reserve_seal", "blade_rhythm", "satchel", "absorb"]
const RELIC_SLOTS := 5
const HAND_MAX := 7

const HEAL_BASE := 6
const FINAL_HEAL := 6
const CONTINUE_HEAL := 6
const FIELD_VICTORY_HEAL := 0.25

# 구간별 금화·경험치 (미정산 → 구간 보스 승리 때 한 번 정산)
const PAY := {
	"normal": {"fight": [3, 3], "boss": [8, 8]},
	"hard": {"fight": [6, 2], "boss": [16, 8]},
	"extreme": {"fight": [8, 4], "boss": [24, 12]},
}
const OPT_GOLD := 5
const OPT_XP := 0
const FIELD_PAY := {"ORC": [3, 3], "SKELETON": [4, 4], "MUMMY": [6, 6], "RUINS_BOSS": [24, 16]}
const FIELD_GROUP := {"ORC": "field_orc", "SKELETON": "field_skeleton", "MUMMY": "field_mummy", "RUINS_BOSS": "field_ruins"}

# 서비스 지점(상인)과 선택 지점. 상인은 현재 구간의 미정산 금화만 쓴다
const SHOP_CARD := 6
const SHOP_UPGRADE := 6
const SHOP_HEAL := 4
const SHOP_HEAL_FRACTION := 0.25
const SHOP_REMOVE := 6
const SHOP_REMOVE_STEP := 2
const CHEST_GOLD := 3
const SACRIFICE_HP := 8
const RISK_ATTACK := 2
const POTION_CAP := 2
# 사건(지도의 ? 칸): 구간마다 시드로 하나, 한 원정 안에서는 겹치지 않음. 선택지는 하나만 · 한 번
const EVENTS := {
	"supply": {"name": "버려진 보급품", "text": "무너진 야영지에 상자 두 개가 남아 있다. 하나만 들고 갈 수 있다.", "col": Color("#e0c27a"), "opts": ["chest_gold", "chest_potion"]},
	"forge": {"name": "피의 대장간", "text": "아직 식지 않은 모루. 값은 피로도, 금화로도 치를 수 있다.", "col": Color("#ff8a6a"), "opts": ["sacrifice", "forge_gold"]},
	"challenge": {"name": "도전장", "text": "곁길의 강적이 남긴 도전장이 꽂혀 있다. 받아들이면 그 싸움이 거칠어진다.", "col": Color("#ff6a6a"), "opts": ["risk", "tear"]},
	"altar": {"name": "부서진 제단", "text": "균열에 잠긴 제단이 피를 원한다. 기도만 올려도 몸은 가벼워진다.", "col": Color("#c58cff"), "opts": ["altar_relic", "altar_pray"]},
	"library": {"name": "잊힌 서고", "text": "젖은 책장 사이로 쓸 만한 기술과 버릴 버릇이 함께 보인다.", "col": Color("#8fc3e8"), "opts": ["burn_card", "copy_card"]},
	"echo": {"name": "균열 메아리", "text": "맥이 몸속에서 울린다. 몸을 맡기면 무언가 깨어나지만 대가가 따른다.", "col": Color("#5fd8cf"), "opts": ["echo_stat", "echo_xp"]},
}
const EVENT_ORDER := ["supply", "forge", "challenge", "altar", "library", "echo"]
const FORGE_GOLD := 3
const TEAR_GOLD := 2
const ALTAR_MAXHP := 5
const ALTAR_HEAL := 10
const ECHO_HP := 6
const ECHO_XP := 6

const RAVEN := "res://assets/items/Free - Raven Fantasy Icons/Full Spritesheet/32x32.png"
const ITEM_DIR := "res://assets/items/Free RPG asset Pack/separate files/"

const ICONS := {
	"mirror_slab": Rect2(32, 640, 32, 32), "wedge_slab": Rect2(160, 640, 32, 32), "bridge_slab": Rect2(352, 640, 32, 32), "seal_slab": Rect2(96, 640, 32, 32),
	"glass_cannon": Rect2(64, 1536, 32, 32), "mad_drum": Rect2(96, 672, 32, 32), "reverse_brush": Rect2(192, 576, 32, 32), "thorn_eater": Rect2(128, 512, 32, 32),
	"arrow_quiver": Rect2(0, 800, 32, 32), "drum_echo": Rect2(128, 672, 32, 32),
	"ember_heart": Rect2(448, 1984, 32, 32), "frost_crown": Rect2(480, 2016, 32, 32), "spread_fan": Rect2(352, 1632, 32, 32), "trapper_jaw": Rect2(160, 1600, 32, 32),
	"blood_chalice": Rect2(480, 1888, 32, 32), "eclipse_ring": Rect2(320, 1952, 32, 32), "doom_skull": Rect2(384, 1632, 32, 32), "cruel_eye": Rect2(448, 1408, 32, 32),
	"slam": Rect2(96, 2272, 32, 32), "arrow_rain": Rect2(448, 2240, 32, 32), "chain_blast": Rect2(320, 2240, 32, 32),
	"fireball": Rect2(0, 1984, 32, 32), "fire_wall": Rect2(160, 1984, 32, 32), "frost_lance": Rect2(256, 2016, 32, 32), "ice_coffin": Rect2(0, 2016, 32, 32),
	"dark_rift": Rect2(288, 2080, 32, 32), "light_rain": Rect2(160, 1952, 32, 32), "gust": Rect2(384, 1440, 32, 32), "poison_cloud": Rect2(256, 1600, 32, 32),
	"focus_shot": Rect2(288, 2048, 32, 32), "barrage": Rect2(480, 2240, 32, 32), "bear_trap": Rect2(448, 1568, 32, 32), "mark_target": Rect2(320, 1952, 32, 32),
	"bleed_arrows": Rect2(416, 2112, 32, 32), "shield_boomerang": Rect2(192, 2240, 32, 32), "rampart": Rect2(288, 1696, 32, 32), "war_cry": Rect2(352, 2368, 32, 32),
	"iron_counter": Rect2(192, 1696, 32, 32), "launcher": Rect2(96, 1728, 32, 32), "hundred_fists": Rect2(416, 1504, 32, 32), "ki_blast": Rect2(416, 1536, 32, 32),
	"hex_bolt": Rect2(96, 1472, 32, 32), "doom_brand": Rect2(256, 2080, 32, 32), "enfeeble": Rect2(384, 1760, 32, 32), "armor_break": Rect2(384, 1696, 32, 32),
	"soul_link": Rect2(448, 2080, 32, 32), "blood_pact": Rect2(160, 1472, 32, 32), "soul_drain": Rect2(160, 2144, 32, 32), "plague": Rect2(352, 2112, 32, 32),
	"expose": Rect2(448, 1408, 32, 32), "disarm": Rect2(96, 1760, 32, 32), "war_shout": Rect2(32, 1792, 32, 32), "poison_coat": Rect2(288, 2112, 32, 32),
	"first_aid": Rect2(32, 2080, 32, 32), "smoke_bomb": Rect2(64, 1536, 32, 32),
	"ult_rune_caster": Rect2(160, 1536, 32, 32), "ult_hunter": Rect2(128, 1952, 32, 32), "ult_warden": Rect2(64, 2080, 32, 32), "ult_combo": Rect2(192, 2080, 32, 32), "ult_shaman": Rect2(288, 2144, 32, 32),
	"shaman": Rect2(256, 2080, 32, 32),
	"st_burn": Rect2(0, 1984, 32, 32), "st_poison": Rect2(288, 2112, 32, 32), "st_chill": Rect2(256, 2016, 32, 32), "st_frozen": Rect2(0, 2016, 32, 32),
	"st_bleed": Rect2(416, 2112, 32, 32), "st_vuln": Rect2(448, 1408, 32, 32), "st_weak": Rect2(384, 1760, 32, 32), "st_doom": Rect2(256, 2080, 32, 32),
	"st_trap": Rect2(448, 1568, 32, 32), "st_link": Rect2(448, 2080, 32, 32), "st_air": Rect2(96, 1728, 32, 32),
	"st_umbra": Rect2(288, 2080, 32, 32), "st_lumen": Rect2(160, 1952, 32, 32), "st_pcrys": Rect2(352, 2112, 32, 32),
	"shield_throw": Rect2(160, 2240, 32, 32), "iron_beat": Rect2(64, 1888, 32, 32), "volley": Rect2(64, 2016, 32, 32), "weak_point": Rect2(320, 2304, 32, 32),
	"mark_amp": Rect2(128, 1472, 32, 32), "ember": Rect2(160, 1984, 32, 32), "beat_slash": Rect2(96, 1888, 32, 32), "heal_sigil": Rect2(32, 2080, 32, 32),
	"whetstone": Rect2(192, 1824, 32, 32), "silver_quill": Rect2(448, 1888, 32, 32), "red_sun": Rect2(480, 2048, 32, 32), "ember_jar": Rect2(480, 1984, 32, 32),
	"combo_glove": Rect2(480, 1952, 32, 32), "steady_brush": Rect2(64, 2240, 32, 32), "tuning_fork": Rect2(448, 2048, 32, 32), "shield_spur": Rect2(416, 2048, 32, 32),
	"slash": Rect2(448, 1312, 32, 32), "bolt": Rect2(160, 1536, 32, 32), "guard": Rect2(128, 1184, 32, 32),
	"sweep": Rect2(256, 1440, 32, 32), "bash": Rect2(384, 1216, 32, 32), "wave": Rect2(384, 1536, 32, 32),
	"twin_slash": Rect2(288, 1440, 32, 32), "pierce": Rect2(96, 1600, 32, 32), "suppress": Rect2(32, 1216, 32, 32),
	"focus": Rect2(448, 1408, 32, 32),
	"split": Rect2(160, 1536, 32, 32), "counter": Rect2(256, 1312, 32, 32), "cleave_slash": Rect2(96, 1440, 32, 32),
	"double_inscription": Rect2(128, 1536, 32, 32),
	"arc": Rect2(0, 2048, 32, 32), "absorb": Rect2(416, 1312, 32, 32), "thorn": Rect2(448, 1568, 32, 32),
	"bandage": Rect2(64, 1312, 32, 32), "blade_rhythm": Rect2(384, 2016, 32, 32), "satchel": Rect2(448, 1376, 32, 32),
	"reserve_seal": Rect2(192, 1952, 32, 32), "hunter_lens": Rect2(320, 1920, 32, 32),
	"mark_chain": Rect2(32, 1568, 32, 32), "block_strike": Rect2(96, 2080, 32, 32), "mana_cycle": Rect2(0, 1536, 32, 32),
	"chain_kill": Rect2(192, 1440, 32, 32), "waited_shot": "quiver.png", "burn_endure": Rect2(192, 1984, 32, 32),
	"chain_react": Rect2(448, 1504, 32, 32), "elem_cycle": Rect2(32, 1568, 32, 32), "doom_interest": Rect2(448, 1696, 32, 32), "doom_echo": Rect2(480, 1696, 32, 32),
	"flow_keep": Rect2(128, 1440, 32, 32), "combo_burst": Rect2(192, 1312, 32, 32), "flawless": Rect2(256, 1312, 32, 32), "riposte_beat": Rect2(480, 1312, 32, 32),
	"ult_double": Rect2(256, 1248, 32, 32), "ult_after": Rect2(224, 1664, 32, 32), "wide_pack": Rect2(160, 0, 32, 32), "collector": Rect2(480, 0, 32, 32),
	"thin_deck": Rect2(256, 192, 32, 32), "armory": Rect2(0, 1440, 32, 32), "blood_price": Rect2(32, 512, 32, 32), "last_stand": Rect2(352, 1312, 32, 32),
	"sigil_burst": Rect2(224, 1536, 32, 32), "fuel": Rect2(0, 1984, 32, 32), "torrent": Rect2(32, 1536, 32, 32),
	"mana_veil": Rect2(224, 1696, 32, 32), "riposte": Rect2(224, 1312, 32, 32), "fortify": Rect2(128, 1696, 32, 32),
	"quickshot": "arrow.png", "aimed_shot": "bow_01.png",
	"carry_guard": Rect2(96, 1280, 32, 32), "pursuit_slash": Rect2(192, 1440, 32, 32), "transfer_burst": Rect2(128, 1568, 32, 32),
	"reflux_burst": Rect2(0, 1536, 32, 32), "fierce_riposte": Rect2(320, 1696, 32, 32), "layered_riposte": Rect2(288, 1696, 32, 32),
	"instant_aim": "bow_02.png", "full_aim": "quiver.png",
	"jab": Rect2(192, 1312, 32, 32), "flurry": Rect2(128, 2080, 32, 32), "finisher": Rect2(192, 2080, 32, 32), "flow": Rect2(64, 1632, 32, 32),
	"palm": Rect2(0, 1312, 32, 32), "breather": Rect2(448, 1344, 32, 32), "storm": Rect2(64, 1952, 32, 32), "spin_kick": Rect2(32, 1312, 32, 32),
	"parry_stance": Rect2(352, 1696, 32, 32), "focus_strike": Rect2(32, 2016, 32, 32), "combo": "glove_01.png",
	"rift_heart": Rect2(128, 1312, 32, 32), "crit_capacitor": Rect2(480, 1376, 32, 32), "obsidian_lens": "glasses.png",
	"echo_string": Rect2(32, 1888, 32, 32), "furnace_seal": Rect2(192, 1984, 32, 32), "patient_glove": "glove_01.png",
	"rune_caster": "wand_02.png", "warden": "wooden_shield.png", "hunter": "bow_01.png",
	"beat_pendulum": "compass.png", "echo_edge": "sword_02.png", "iron_tempo": "arm_guard.png", "rhythm_heart": "necklace_02.png",
	"chest": "wooden_box.png", "merchant": "bag_coins.png", "potion": "hp_potion.png", "mana_potion": "mana_potion.png",
}

const RELICS := {
	"arc": {"name": "방전 고리", "new": false,
		"text": "턴마다 한 번: 그 턴 두 번째 마법이 맞으면, 다른 적 중 체력이 가장 낮은 적에게 번개 2."},
	"absorb": {"name": "흡수 문장", "new": false, "text": "턴마다 한 번: 물리 공격으로 표식을 처음 터뜨리면 방어 3."},
	"thorn": {"name": "가시 버클", "new": false, "text": "적 차례마다 한 번: 방어로 처음 막아 낸 공격자에게 3."},
	"bandage": {"name": "전투 붕대", "new": false, "text": "원정 전투에서 이기면 체력 2 회복 (최대 체력까지)."},
	"blade_rhythm": {"name": "철편 부적", "new": false, "text": "턴마다 한 번: 그 턴 물리 공격이 두 번째로 맞으면 방어 3."},
	"satchel": {"name": "예비 주머니", "new": false, "text": "전투마다 한 번: 첫 카드를 낸 뒤 1장 뽑기."},
	"reserve_seal": {"name": "비축 인장", "new": false, "text": "턴을 끝낼 때 남은 마나 1당 방어 2 (최대 4)."},
	"hunter_lens": {"name": "사냥꾼 렌즈", "new": false, "text": "턴마다 한 번: 카드로 적을 쓰러뜨리면 체력이 가장 낮은 적에게 3."},
	"rift_heart": {"name": "균열 심장", "new": false, "text": "최대 마나 +1, 최대 체력 −6 (최대 마나는 6까지)."},
	"crit_capacitor": {"name": "섬광 축전기", "new": false, "text": "턴마다 한 번: 치명타가 들어가면 마나 1."},
	"obsidian_lens": {"name": "흑요석 렌즈", "new": false, "text": "치명타 확률 +10%, 치명 피해 +25%."},
	"echo_string": {"name": "되울림 현", "new": false, "text": "턴마다 한 번: 치명타가 들어가면 다른 적 중 체력이 가장 낮은 적에게 4."},
	"furnace_seal": {"name": "소각로 문장", "new": false, "text": "턴마다 한 번: 카드가 처음 소진될 때 체력이 가장 낮은 적에게 4."},
	"patient_glove": {"name": "인내 장갑", "new": false, "text": "턴 시작 때 손에 남겨 둔 조준 사격이 있으면 방어 3."},
	"beat_pendulum": {"name": "공명 추", "new": true, "rhythm": true, "text": "적 공격을 완벽으로 3번 막을 때마다 다음 내 턴에 1장 더 뽑기 (최대 2장)."},
	"echo_edge": {"name": "메아리 칼끝", "new": true, "rhythm": true, "text": "적 공격을 완벽으로 막으면 그 적에게 2 (적 차례마다 3번까지)."},
	"iron_tempo": {"name": "강철 박자", "new": true, "rhythm": true, "text": "적 공격을 막을 때마다(완벽·막음) 방어 1 (적 차례마다 4까지)."},
	"rhythm_heart": {"name": "리듬 심장", "new": true, "rhythm": true, "text": "연속으로 막고 맞힐 때 체력 회복을 더 많이 (5연속마다 체력 1, 전투마다 최대 5 → 8)."},
	"whetstone": {"name": "숫돌", "new": true, "stat": {"str": 2}, "text": "힘 +2 (물리 공격 카드 타격마다 +2)."},
	"silver_quill": {"name": "은빛 깃펜", "new": true, "stat": {"focus": 10}, "text": "집중 +10 (막기·긋기 판정이 10% 넉넉해짐)."},
	"red_sun": {"name": "붉은 태양", "new": true, "stat": {"cdmg": 30}, "text": "치명 피해 +30% (치명타·완벽 긋기 배율 +0.3)."},
	"ember_jar": {"name": "잿불 단지", "new": true, "text": "카드가 소진될 때마다 방어 2 (턴마다 두 번까지)."},
	"combo_glove": {"name": "연격 장갑", "new": true, "text": "콤보술사: 턴을 시작할 때 연격 +1."},
	"steady_brush": {"name": "흔들림 없는 붓", "new": true, "text": "완벽 긋기 피해 배율 +0.2."},
	"tuning_fork": {"name": "소리굽쇠", "new": true, "rhythm": true, "text": "지난 적 차례에 완벽으로 3번 이상 막았으면 이번 턴 첫 공격 +4."},
	"shield_spur": {"name": "방패 박차", "new": true, "text": "방어 카드를 낼 때마다 다음 물리 공격 +2 (최대 +6, 쓰면 0)."},
	"mirror_slab": {"name": "거울 석판", "new": true, "slab": true, "text": "오른쪽 칸 유물이 한 단계 강해짐 (Ⅱ = 효과 ×2, Ⅲ = ×3)."},
	"wedge_slab": {"name": "쐐기 석판", "new": true, "slab": true, "text": "오른쪽 칸 유물이 두 단계 강해짐. 대신 왼쪽 칸 유물은 꺼짐."},
	"bridge_slab": {"name": "다리 석판", "new": true, "slab": true, "text": "양옆 칸 유물이 한 단계 강해짐. 가지고 있는 동안 최대 체력 −8."},
	"seal_slab": {"name": "봉인 석판", "new": true, "slab": true, "text": "양옆 칸 유물은 꺼짐. 대신 힘·마력·수비 +3."},
	"glass_cannon": {"name": "유리 대포", "new": true, "text": "주는 피해 ×1.5, 받는 피해도 ×1.5 (올림)."},
	"mad_drum": {"name": "광기의 북", "new": true, "rhythm": true, "text": "적 노트가 더 어려워지는 대신, 완벽으로 막은 횟수를 두 번으로 셈 (완벽 수를 쓰는 카드·유물 효과가 두 배)."},
	"reverse_brush": {"name": "거꾸로 붓", "new": true, "text": "공격 문양을 마지막 점부터 거꾸로 그으면 공격 대신 그 피해만큼 방어."},
	"thorn_eater": {"name": "가시 삼키기", "new": true, "text": "빨간 가시를 지나도 긋기가 끊기지 않고, 삼킨 가시마다 그 카드 피해 +3 · 체력 −1."},
	"arrow_quiver": {"name": "화살 줍기", "new": true, "rhythm": true, "text": "화살을 완벽으로 막을 때마다 다음 내 턴 첫 공격 +1 (최대 +6)."},
	"drum_echo": {"name": "되치는 북", "new": true, "rhythm": true, "text": "북을 완벽으로 칠 때마다 그 적에게 1 (적 차례마다 6번까지)."},
	"ember_heart": {"name": "불씨 심장", "new": true, "text": "화상이 턴을 끝낼 때 절반으로 줄지 않고 1만 줄어듦."},
	"frost_crown": {"name": "서리 왕관", "new": true, "text": "얼어붙은 적은 적 차례를 두 번 쉼 (Ⅱ = 세 번)."},
	"spread_fan": {"name": "확산의 부채", "new": true, "text": "적이 쓰러지면 그 적의 화상·독·저주가 살아 있는 다른 적 모두에게 옮겨 붙음."},
	"trapper_jaw": {"name": "덫꾼의 이빨", "new": true, "text": "덫이 닫혀도 같은 덫이 한 번 더 놓임."},
	"blood_chalice": {"name": "피의 성배", "new": true, "text": "스스로 체력을 잃을 때마다(피의 계약·가시 삼키기) 방어 3."},
	"eclipse_ring": {"name": "일식 반지", "new": true, "text": "원소 반응이 날 때마다 필살 게이지 +10 더."},
	"doom_skull": {"name": "파멸의 두개골", "new": true, "text": "저주가 터질 때 쌓인 양 × 3이 아니라 × 4."},
	"cruel_eye": {"name": "잔혹한 눈", "new": true, "text": "취약한 적이 받는 피해 +50% → +100%."},
}
# 석판: 옆 칸 유물의 단계를 올리거나 재운다(세피리아 석판처럼 배치가 퍼즐). 단계 2·3 = 그 유물 수치 ×2·×3, 잠듦 = 꺼짐.
# 석판끼리는 단계를 주고받지 않고, 균열 심장(최대 마나)은 단계가 없다
const SLABS := ["mirror_slab", "wedge_slab", "bridge_slab", "seal_slab"]
const NO_LEVEL := ["rift_heart", "ember_heart", "spread_fan", "trapper_jaw"]
const CHALICE_BLOCK := 3
const ECLIPSE_ULT := 10
const LEVEL_MAX := 3
const BRIDGE_HP := 8
const SEAL_STAT := 3
const GLASS_MULT := 1.5
const QUIVER_MAX := 6
const DRUM_ECHO_MAX := 6
const THORN_EAT_DAMAGE := 3
const RELIC_ORDER := ["arc", "absorb", "thorn", "bandage", "blade_rhythm", "satchel", "reserve_seal", "hunter_lens",
	"rift_heart", "crit_capacitor", "obsidian_lens", "echo_string", "furnace_seal", "patient_glove",
	"beat_pendulum", "echo_edge", "iron_tempo", "rhythm_heart",
	"whetstone", "silver_quill", "red_sun", "ember_jar", "combo_glove", "steady_brush", "tuning_fork", "shield_spur",
	"mirror_slab", "wedge_slab", "bridge_slab", "seal_slab", "glass_cannon", "mad_drum", "reverse_brush", "thorn_eater", "arrow_quiver", "drum_echo",
	"ember_heart", "frost_crown", "spread_fan", "trapper_jaw", "blood_chalice", "eclipse_ring", "doom_skull", "cruel_eye"]
const RIFT_HP := 6

# 능력치: 원정 레벨업으로 고른다(판 안). cdmg는 치명 배율 +0.01 단위, focus는 판정 창 % 단위
const STATS := {
	"str": {"name": "힘", "step": 1, "icon": "intent_attack", "text": "물리 공격 카드 타격마다 +%d"},
	"arc": {"name": "마력", "step": 1, "icon": "status_mark", "text": "마법 공격 카드 타격마다 +%d"},
	"def": {"name": "수비", "step": 1, "icon": "intent_defend", "text": "방어 카드마다 방어 +%d"},
	"crit": {"name": "치명", "step": 5, "icon": "status_crit", "text": "치명타 확률 +%d%%p
(긋기는 '맞힘'도 이 확률로 치명)"},
	"cdmg": {"name": "치명 피해", "step": 20, "icon": "intent_heavy", "text": "치명타·완벽 긋기 배율 +%d%%"},
	"vit": {"name": "체력", "step": 6, "icon": "hud_heart", "text": "최대 체력 +%d (그만큼 회복)"},
	"focus": {"name": "집중", "step": 8, "icon": "status_resonance", "text": "패링·긋기 판정 창 +%d%%"},
}
const STAT_ORDER := ["str", "arc", "def", "crit", "cdmg", "vit", "focus"]
const STAT_CAP := {"crit": 40, "cdmg": 100, "focus": 40}
const CLASS_STAT_WEIGHT := {
	"warden": {"def": 3, "str": 2, "vit": 2},
	"rune_caster": {"arc": 3, "vit": 2, "focus": 2},
	"hunter": {"crit": 3, "cdmg": 2, "str": 2},
	"combo": {"str": 3, "focus": 2, "vit": 2},
	"shaman": {"arc": 3, "vit": 2, "def": 2},
}
const STAT_RARE_CHANCE := 20
const RUN_XP := {"fight": 4, "opt": 7, "boss": 10}

# 카드 얼굴에 더해 보일 능력치 (전투 화면·원정 창이 열려 있는 동안만 채운다)
static var view_stats: Dictionary = {}


# 능력치 유물을 더한 능력치(전투·카드 얼굴·능력치 판이 같은 값을 쓴다). 단계만큼 배, 잠든 것은 빼고, 깨어 있는 봉인 석판은 힘·마력·수비 +3
static func stats_with_relics(st: Dictionary, relics: Array) -> Dictionary:
	var out := st.duplicate()
	var lv := relic_levels(relics)
	for id in relics:
		var n := int(lv.get(String(id), 1))
		if n <= 0:
			continue
		var add: Dictionary = (RELICS.get(String(id), {}) as Dictionary).get("stat", {})
		for k in add:
			out[k] = int(out.get(k, 0)) + int(add[k]) * n
		if String(id) == "seal_slab":
			for k in ["str", "arc", "def"]:
				out[k] = int(out.get(k, 0)) + SEAL_STAT
	return out


# 유물 칸 순서(왼쪽 → 오른쪽)로 단계: 1 기본 · 0 잠듦 · 최대 3. 쐐기·봉인의 재우기를 먼저(오른쪽부터, 잠든 석판은 재우지 않음), 그다음 깨어 있는 석판이 올린다
static func relic_levels(relics: Array) -> Dictionary:
	var lv := {}
	for id in relics:
		lv[String(id)] = 1
	var n := relics.size()
	for i in range(n - 1, -1, -1):
		var id := String(relics[i])
		if int(lv[id]) <= 0:
			continue
		if id == "wedge_slab" and i > 0:
			lv[String(relics[i - 1])] = 0
		elif id == "seal_slab":
			if i > 0:
				lv[String(relics[i - 1])] = 0
			if i + 1 < n:
				lv[String(relics[i + 1])] = 0
	for i in range(n):
		var id := String(relics[i])
		if int(lv[id]) <= 0:
			continue
		match id:
			"mirror_slab":
				_lv_add(lv, relics, i + 1, 1)
			"wedge_slab":
				_lv_add(lv, relics, i + 1, 2)
			"bridge_slab":
				_lv_add(lv, relics, i - 1, 1)
				_lv_add(lv, relics, i + 1, 1)
	return lv


static func _lv_add(lv: Dictionary, relics: Array, j: int, add: int) -> void:
	if j < 0 or j >= relics.size():
		return
	var t := String(relics[j])
	if int(lv[t]) <= 0 or SLABS.has(t) or NO_LEVEL.has(t):
		return
	lv[t] = mini(LEVEL_MAX, int(lv[t]) + add)


# 적 공격 장르(전투 화면과 같은 규칙, 점검용 강제 없음): 최종 보스(medley)는 차례마다 바뀜
static func genre_for(role: String, turn: int) -> String:
	var g := String(ENEMIES[role].get("parry", "osu"))
	if g == "medley":
		return String(["drum", "arrow", "dodge", "osu"][posmod(turn, 4)])
	return g


static func lv_need(lv: int) -> int:
	return 6 + 2 * lv


static func stat_text(id: String, amount: int) -> String:
	return String(STATS[id].text) % amount


static func stat_add(c: Card, st: Dictionary) -> int:
	if c.effect == Card.EffectType.DEFEND:
		return int(st.get("def", 0))
	if not is_attack(c):
		return 0
	if is_physical(c):
		return int(st.get("str", 0))
	return int(st.get("arc", 0)) if is_magic(c) else 0

# 원정 난이도: 새 원정 창에서 고른다. 모든 전투에 걸린다(판정 창 · 노트 속도 · 패턴 · 적 체력 · 적 피해).
# 이지·노멀은 처음부터, 하드는 노멀을, 익스트림은 하드를 끝까지(최종 보스) 깨면 열린다. 난이도마다 최종 보스를 잡으면 배지
const DIFFS := ["easy", "normal", "hard", "extreme"]
const DIFF := {
	"easy": {"name": "이지", "judge": 1.4, "approach": 1.25, "pattern": -1, "hp": 0.85, "hit": 0.8, "score": 0.6, "affix": 0, "heal_cap": 5,
		"rule": "판정 넓게 · 노트 느리게 · 패턴 쉽게 · 적 체력 −15% · 피해 −20%"},
	"normal": {"name": "노멀", "judge": 1.0, "approach": 1.0, "pattern": 0, "hp": 1.0, "hit": 1.0, "score": 1.0, "affix": 0, "rank_hp": {"normal": 1.1, "elite": 1.3, "boss": 1.8}, "heal_cap": 5,
		"rule": "적 체력: 잡몹 +10% · 정예 +30% · 보스 +80%"},
	"hard": {"name": "하드", "judge": 0.85, "approach": 0.85, "pattern": 1, "hp": 1.15, "hit": 1.15, "score": 1.4, "affix": 1, "rank_hp": {"normal": 1.2, "elite": 1.5, "boss": 2.0}, "heal_cap": 4,
		"rule": "판정 −15% · 노트 빠르게 · 엇박 노트 하나 더 · 적 피해 +15% · 적 체력 잡몹 +38% · 정예 +73% · 보스 +130%"},
	"extreme": {"name": "익스트림", "judge": 0.7, "approach": 0.72, "pattern": 2, "hp": 1.3, "hit": 1.3, "score": 1.8, "affix": 2, "rank_hp": {"normal": 1.3, "elite": 1.6, "boss": 2.1}, "heal_cap": 3,
		"rule": "판정 −30% · 노트 더 빠르게 · 노트 더 · 두 번 누르기 섞임 · 적 피해 +30% · 적 체력 잡몹 +69% · 정예 +108% · 보스 +173%"},
}
const DIFF_NEEDS := {"hard": "normal", "extreme": "hard"}

# osu식 모드: 난이도와 따로 켜고 끈다. 켠 모드마다 금화 +10%
const MODS := ["hd", "hr", "dt", "mr"]
const MOD := {
	"hd": {"name": "히든", "short": "HD", "rule": "다가오는 고리가 중간에 사라짐"},
	"hr": {"name": "하드록", "short": "HR", "rule": "판정 창 −20%"},
	"dt": {"name": "더블타임", "short": "DT", "rule": "악보 전체가 25% 빠름"},
	"mr": {"name": "미러", "short": "MR", "rule": "노트 자리 좌우 뒤집기"},
}
const MOD_GOLD := 0.1
# 적 성향: 하드는 일반 전투의 적 하나, 익스트림은 일반 전투의 적 모두 + 정예 전투의 적 하나(보스·상자는 없음). 원정 시드로 정해진다
const AFFIXES := ["swift", "tough", "fierce", "rhythm"]
const AFFIX := {
	"swift": {"name": "날쌘", "rule": "노트가 15% 빨리 다가옴", "col": Color("#8fe0ff")},
	"tough": {"name": "단단한", "rule": "체력 +25%", "col": Color("#d8c08a")},
	"fierce": {"name": "사나운", "rule": "타격마다 피해 +1", "col": Color("#ff8a6a")},
	"rhythm": {"name": "겹박자", "rule": "타격마다 노트 하나 더", "col": Color("#d9a0ff")},
}
const AFFIX_TOUGH := 1.25
const AFFIX_SWIFT := 0.85
# 도전과제(기록실): [id, 이름, 조건, 아이콘]. 저장된 기록으로 보거나 그 순간의 사건으로 연다(RunModel.unlock_achievements)
const ACHIEVEMENTS := [
	["first_run", "첫 발걸음", "원정을 한 번 마침", "status_resonance"],
	["sector1", "수문을 넘어", "구간 I 보스를 쓰러뜨림", "intent_attack"],
	["clear_normal", "노멀 정복", "노멀로 세 구간을 정복", "status_crit"],
	["clear_hard", "하드 정복", "하드로 세 구간을 정복", "status_crit"],
	["clear_extreme", "익스트림 정복", "익스트림으로 세 구간을 정복", "status_crit"],
	["rank_s", "완벽한 원정", "원정 랭크 S", "status_mark"],
	["boss_s", "보스 앞의 박자", "보스전 성적 S", "status_mark"],
	["no_hit_boss", "털끝 하나", "보스를 피해 없이 쓰러뜨림", "status_armor"],
	["combo_50", "끊기지 않는 박자", "한 전투에서 연속 50", "intent_multi"],
	["mods_clear", "덤으로 더", "모드를 켜고 세 구간을 정복", "intent_heavy"],
	["all_classes", "세 갈래 길", "세 직업 모두로 구간 I 보스를 쓰러뜨림", "status_resonance"],
	["daily_first", "오늘의 원정", "오늘의 원정을 한 번 마침", "hud_coin"],
	["daily_week", "일곱 날의 기록", "오늘의 원정 기록 7일", "hud_coin"],
	["practice_s", "연습의 끝", "연습에서 성적 S", "intent_multi"],
]


# 연습실: 원정에서 만난 보스·정예를 다시(그 구간 배율·고른 난이도로). 피해·보상 없이 기록만
const PRACTICE := [["boss", "normal"], ["elite", "normal"], ["hboss", "hard"], ["elite_h", "hard"], ["xboss", "extreme"], ["elite_x", "extreme"]]
const REGULAR_GROUPS := ["n1", "n2", "n3", "n4", "h1a", "h1b", "h2", "x1", "x2"]
const ELITE_GROUPS := ["elite", "elite_h", "elite_x"]


static func diff_of(id: String) -> Dictionary:
	return DIFF.get(id, DIFF.normal)


static func practice_sector(gid: String) -> String:
	for p in PRACTICE:
		if String(p[0]) == gid:
			return String(p[1])
	return ""


static func diff_unlocked(cleared: Dictionary, id: String) -> bool:
	return dev_open() or not DIFF_NEEDS.has(id) or bool(cleared.get(String(DIFF_NEEDS[id]), false))


# 시험용: 에디터에서 실행하면 모든 난이도 · 연습 무리가 열린다(내보낸 게임 · 점검 드라이버 · --locked는 그대로)
static func dev_open() -> bool:
	if not OS.has_feature("editor"):
		return false
	for a in OS.get_cmdline_user_args():
		if String(a) == "--locked" or String(a).begins_with("--p5-smoke"):
			return false
	return true


const OBSIDIAN_CHANCE := 10
const OBSIDIAN_MULT := 0.25
const ECHO_STRING_DAMAGE := 4
const FURNACE_DAMAGE := 4
const PATIENT_BLOCK := 3
const BANDAGE_HEAL := 2

# 특성: 구간 Ⅰ·Ⅱ 보스 뒤 계속할 때, 그리고 정예를 이길 때 후보 3개 중 1개 (서로 중복 불가, 공용 후보 최소 1).
# needs: 덱·직업 조건(mark · retain · exhaust · doom · combo · elem). 표식 연쇄 · 기다린 한 발은 옛 세이브용으로만 남김
const TRAITS := {
	"mark_chain": {"name": "표식 연쇄", "common": false, "needs": "mark",
		"text": "턴마다 한 번: 한 타격으로 표식을 2개 이상 소비하면, 다른 적 중 체력이 가장 낮은 적에게 추가 4 (다른 적이 없으면 살아 있는 원래 대상, 갑옷 적용). 물리·마법 모두."},
	"block_strike": {"name": "막고 치기", "common": true, "needs": "",
		"text": "적 단계에 방어로 막아 낸 피해가 합계 6 이상이면, 다음 턴 첫 공격 카드의 첫 타격 +4 (물리·마법 모두, 그 턴에만)."},
	"mana_cycle": {"name": "마나 순환", "common": true, "needs": "",
		"text": "턴마다 한 번: 이번 턴 실제로 마나를 낸 카드가 3장이 되면 마나 1 (최대 마나까지)."},
	"chain_kill": {"name": "연속 처치", "common": true, "needs": "",
		"text": "턴마다 한 번: 카드의 직접 타격으로 처음 적을 쓰러뜨리면 마나 1 + 1장 뽑기."},
	"waited_shot": {"name": "기다린 한 발", "common": false, "needs": "retain",
		"text": "턴마다 한 번: 손에 남겨 충전된 조준 사격을 쓰면 마나 1."},
	"burn_endure": {"name": "태워서 버티기", "common": false, "needs": "exhaust",
		"text": "턴마다 한 번: 카드가 처음 소진될 때 방어 3 + 1장 뽑기 (연료화가 두 장을 태워도 한 번)."},
	"chain_react": {"name": "연쇄 반응", "common": false, "needs": "elem",
		"text": "턴마다 두 번: 원소 반응이 터지면 가장 가까운 다른 적에게 같은 반응이 절반 위력으로 한 번 더 (확산 제외)."},
	"elem_cycle": {"name": "원소 순환", "common": false, "needs": "elem",
		"text": "턴마다 한 번: 이번 턴 서로 다른 원소 3가지(불 · 얼음 · 독 · 빛 · 어둠)를 묻히면 마나 1 + 1장 뽑기."},
	"doom_interest": {"name": "저주 이자", "common": false, "needs": "doom",
		"text": "저주가 터지지 않고 턴을 넘길 때마다 그 저주 +1."},
	"doom_echo": {"name": "파멸의 메아리", "common": false, "needs": "doom",
		"text": "저주 폭발로 적이 쓰러지면 그 저주의 절반(올림)이 체력이 가장 낮은 다른 적에게 옮겨 붙음."},
	"flow_keep": {"name": "끊기지 않는 흐름", "common": false, "needs": "combo",
		"text": "턴이 바뀌어도 연격이 0이 되지 않고 절반(내림) 남음."},
	"combo_burst": {"name": "연격 폭주", "common": false, "needs": "combo",
		"text": "턴마다 한 번: 공격 카드를 낸 뒤 연격이 최대(6)면 연격을 모두 쓰고 모든 적에게 연격 × 3."},
	"flawless": {"name": "무결", "common": true, "needs": "",
		"text": "적 차례의 공격을 하나도 맞지 않으면(방어·막기로 다 막음) 다음 턴 마나 +1(최대를 넘어도) · 1장 더 뽑기."},
	"riposte_beat": {"name": "받아치기", "common": true, "needs": "",
		"text": "적 공격을 완벽으로 막으면 그 공격 피해의 절반(올림)을 그 적에게 되돌림 (적 차례마다 합계 15까지)."},
	"ult_double": {"name": "두 겹 필살", "common": true, "needs": "",
		"text": "필살 게이지가 200까지 참. 100마다 한 번씩 필살을 쓸 수 있음."},
	"ult_after": {"name": "필살 여운", "common": true, "needs": "",
		"text": "필살을 쓴 턴에는 손패 카드 비용 −1 (최소 0, 그 턴에 뽑는 카드도)."},
	"wide_pack": {"name": "넓은 배낭", "common": true, "needs": "",
		"text": "유물 칸 +1 (5 → 6)."},
	"collector": {"name": "수집가", "common": true, "needs": "",
		"text": "가진 유물 하나마다 최대 체력 +2 (얻을 때 체력도 함께 오름), 전투 시작 때 방어 +1."},
	"thin_deck": {"name": "얇은 덱", "common": true, "needs": "",
		"text": "덱이 15장 이하면 턴마다 1장 더 뽑기."},
	"armory": {"name": "무기고", "common": true, "needs": "",
		"text": "덱 10장마다 턴의 첫 공격 카드 첫 타격 +2."},
	"blood_price": {"name": "피의 값", "common": true, "needs": "",
		"text": "체력이 절반 이하면 공격 카드 타격마다 +2, 30% 이하면 +4 (8타 이상 연타 카드는 1/3)."},
	"last_stand": {"name": "질긴 목숨", "common": true, "needs": "",
		"text": "원정마다 한 번: 쓰러질 피해를 받으면 체력 1로 버팀."},
}
const TRAIT_ORDER := ["block_strike", "mana_cycle", "chain_kill", "burn_endure", "chain_react", "elem_cycle", "doom_interest", "doom_echo", "flow_keep", "combo_burst",
	"flawless", "riposte_beat", "ult_double", "ult_after", "wide_pack", "collector", "thin_deck", "armory", "blood_price", "last_stand"]
const CHAIN_REACT_MAX := 2
const ELEM_CYCLE_NEED := 3
const COMBO_BURST_MULT := 3
const RIPOSTE_CAP := 15
const THIN_DECK_MAX := 15
const ARMORY_PER := 10
const ARMORY_BONUS := 2
const BLOOD_HALF := 2
const BLOOD_LOW := 4
const COLLECTOR_HP := 2
const COLLECTOR_BLOCK := 1
const LEGACY_TRAIT_MAP := {"echo": "mark_chain", "reprisal": "block_strike"}

# 적 표. rank: normal/elite/boss/device/mimic (종족 처치 수는 normal·elite만). moves 한 칸 = 타격 배열 또는 특수 행동 사전
const ENEMIES := {
	"scout": {"name": "척후병", "hp": 14, "armor": 0, "type": "ORC", "variant": 1, "rank": "normal",
		"moves": [[5]], "role": "매 턴 공격 5"},
	"archer": {"name": "사수", "hp": 18, "armor": 0, "type": "SKELETON", "variant": 2, "rank": "normal", "ranged": true, "parry": "arrow",
		"moves": [[], [9]], "role": "준비 → 공격 9"},
	"breaker": {"parry": "drum", "name": "파괴자", "hp": 26, "armor": 0, "type": "ORC", "variant": 3, "rank": "normal",
		"moves": [[8], [], [12]], "role": "공격 8 → 준비 → 공격 12"},
	"shieldbearer": {"name": "방패병", "hp": 22, "armor": 0, "type": "SKELETON", "variant": 3, "rank": "normal", "shield": 8,
		"moves": [[6]], "role": "매 턴 공격 6 · 방패 8: 다음 공격 카드 한 장의 피해 합계 8을 막고 사라짐", "badge": "방패"},
	"banner": {"name": "기수", "hp": 14, "armor": 0, "type": "ORC", "variant": 2, "rank": "normal", "aura": 2,
		"moves": [[3]], "role": "매 턴 공격 3 · 살아 있는 동안 다른 적의 공격 타격마다 +2", "badge": "지원"},
	"hexer": {"parry": "dodge", "name": "해골 저주꾼", "hp": 18, "armor": 0, "type": "SKELETON", "variant": 1, "rank": "normal",
		"moves": [{"act": "hex"}, [4]], "role": "주술(다음 내 턴 방어 카드 −2) → 공격 4 반복", "badge": "주술"},
	"poisoner": {"parry": "dodge", "name": "독침병", "hp": 22, "armor": 0, "type": "MUMMY", "variant": 1, "rank": "normal",
		"moves": [{"act": "poison", "amount": 2, "ticks": 2}, [5]], "role": "독 2 (내 턴 종료 2번) → 공격 5 반복", "badge": "독"},
	"elite": {"parry": "drum", "name": "정예 돌격대장", "hp": 30, "armor": 2, "type": "ORC", "variant": 3, "rank": "elite",
		"moves": [[6, 6], [], [14]], "role": "공격 6×2 → 준비 → 공격 14 · 갑옷 2", "tint": Color(1.25, 0.8, 0.7), "scale": 1.15},
	# 구간 I 선택 정예 전용 '맥 거완'(시험 수치는 옛 정예와 같음). 옛 'elite'는 진행 중이던 저장본을 옛 규칙으로 잇기 위해 남긴다.
	# unwind: 강타 준비 뒤 내 차례(moves의 strike 칸 차례)에 이 적의 체력을 실제로 줄인 카드 직접 타격 need번이면 그 강타만 weak
	"maek_elite_low": {"parry": "drum", "name": "맥 거완", "hp": 30, "armor": 2, "type": "ORC", "variant": 3, "rank": "elite",
		"moves": [[6, 6], [], [14]], "role": "공격 6×2 → 강타 준비 → 강타 14 · 갑옷 2 · 준비 뒤 내 차례에 카드 직접 공격으로 3번 맞히면 그 강타는 6",
		"tint": Color(1.25, 0.8, 0.7), "scale": 1.15, "unwind": {"strike": 2, "need": 3, "weak": 6}},
	"boss": {"name": "균열 수문장", "hp": 72, "armor": 0, "type": "RUINS_BOSS", "variant": 0, "rank": "boss", "shield": 8,
		"moves": [[5, 5], [], [16]], "role": "보스 · 시작 방패 8 · 공격 5×2 → 준비 → 공격 16 반복", "tint": Color(1.2, 0.85, 1.25), "scale": 1.7},
	# 구간 I 보스 전투 전용. 소환사(본체)만 쓰러뜨리면 승리. 소환수 자리 둘은 처음엔 비어 있고(체력 0) 소환 때 새 개체로 채운다.
	# 실제 행동 순서·기한은 P2Battle이 적 단계 번호로 정한다(아래 moves는 첫 줄 안내용)
	"maek_summoner_low": {"parry": "echo", "name": "맥 소환사", "hp": 72, "armor": 0, "type": "RUINS_BOSS", "variant": 0, "rank": "boss", "main": true, "summoner": true,
		"moves": [{"act": "summon", "count": 2}, [5], [10]], "role": "소환수 2마리 → 공격 5 → 공격 10 반복 (소환은 두 번까지, 그 뒤 5·10 번갈아)"},
	"maek_spawn_low": {"name": "맥 소환수", "hp": 5, "armor": 0, "type": "SKELETON", "variant": 0, "rank": "summon", "summon_slot": true,
		"moves": [[6]], "role": "소환된 다음 적 차례에 폭발 6 한 번 (방어로 막을 수 있음 · 먼저 처치하면 폭발 안 함)"},
	"guard_h": {"parry": "drum", "name": "철갑 수비병", "hp": 28, "armor": 3, "type": "SKELETON", "variant": 3, "rank": "normal",
		"moves": [[7], [], [11]], "role": "공격 7 → 준비 → 공격 11 · 갑옷 3", "tint": Color(0.8, 0.9, 1.15), "scale": 1.1},
	"archer_h": {"name": "심층 사수", "hp": 20, "armor": 0, "type": "SKELETON", "variant": 2, "rank": "normal", "ranged": true, "parry": "arrow",
		"moves": [[], [10]], "role": "준비 → 공격 10", "tint": Color(0.85, 0.95, 1.2)},
	"scout_h": {"name": "추격 척후", "hp": 16, "armor": 0, "type": "ORC", "variant": 1, "rank": "normal",
		"moves": [[5]], "role": "매 턴 공격 5", "tint": Color(0.9, 1.0, 1.15)},
	"leader": {"parry": "drum", "name": "돌파 대장", "hp": 32, "armor": 2, "type": "ORC", "variant": 3, "rank": "elite",
		"moves": [[6, 6], [], [14]], "role": "공격 6×2 → 준비 → 공격 14 · 갑옷 2", "tint": Color(0.95, 0.85, 1.25), "scale": 1.2},
	"hard_boss": {"name": "심층 파수자", "hp": 108, "armor": 1, "type": "SKELETON", "variant": 1, "rank": "boss",
		"moves": [[6, 6], [20], []], "role": "보스 · 공격 6×2 → 강타 20(이번 턴 피해 14를 주면 10) → 쉼 반복 · 갑옷 1",
		"tint": Color(0.7, 1.05, 1.3), "scale": 1.75, "charge": {"round": 1, "full": 20, "weak": 10, "threshold": 14}},
	# 구간 II 보스 '맥 귀족'(시험값). 옛 hard_boss는 진행 중이던 저장본을 옛 규칙으로 잇기 위해 남긴다.
	# noble: 내 공명 0/1/2 → 카드 직접 배율 mult, 보스 물창 lance. seal_acts번째 실제 행동 뒤 다음 손패 1장 한 차례 봉인(최대 2번)
	"maek_noble_mid": {"name": "맥 귀족", "hp": 108, "armor": 1, "type": "SKELETON", "variant": 1, "rank": "boss", "ranged": true, "parry": "arrow",
		"moves": [[8]], "role": "보스 · 물창 8 (이번 턴 맞힌 카드 1·2장이면 11·14) · 첫·세 번째 행동 뒤 다음 손패 1장 묶음 · 갑옷 1",
		"tint": Color(0.7, 1.05, 1.3), "scale": 1.75, "noble": {"lance": [8, 11, 14], "mult": [1.0, 1.5, 2.0], "seal_acts": [1, 3]}},
	"cannon": {"parry": "dodge", "name": "포격 장치", "hp": 14, "armor": 0, "type": "SKELETON", "variant": 0, "rank": "device",
		"moves": [[8]], "role": "장치 · 매 턴 공격 8 · 파괴해도 보상 없음", "tint": Color(0.75, 0.75, 0.85), "scale": 0.95, "badge": "장치"},
	"curse": {"name": "저주 장치", "hp": 14, "armor": 0, "type": "SKELETON", "variant": 1, "rank": "device",
		"moves": [{"act": "hex"}, {"act": "wait"}], "role": "장치 · 주술(다음 내 턴 방어 카드 −2) → 대기 반복 · 파괴해도 보상 없음",
		"tint": Color(0.7, 0.6, 0.95), "scale": 0.95, "badge": "장치"},
	"x_boss": {"parry": "medley", "name": "균열의 핵", "hp": 150, "armor": 0, "type": "MUMMY", "variant": 2, "rank": "boss", "main": true,
		"moves": [[8, 8], [22], {"act": "rebuild"}], "role": "최종 보스 · 공격 8×2 → 강타 22 → 파괴된 장치 재가동 반복. 본체를 쓰러뜨리면 승리",
		"tint": Color(1.3, 0.75, 0.75), "scale": 1.8},
	"mimic_n": {"parry": "echo", "name": "상자 미믹", "hp": 26, "armor": 0, "type": "MUMMY", "variant": 0, "rank": "mimic",
		"moves": [[5, 5], [], [10]], "role": "미믹 · 공격 5×2 → 준비 → 공격 10", "tint": Color(1.25, 1.05, 0.6), "scale": 1.1},
	"mimic_h": {"parry": "echo", "name": "심층 미믹", "hp": 34, "armor": 0, "type": "MUMMY", "variant": 0, "rank": "mimic",
		"moves": [[6, 6], [], [12]], "role": "미믹 · 공격 6×2 → 준비 → 공격 12", "tint": Color(1.2, 0.95, 0.55), "scale": 1.15},
	"mimic_x": {"parry": "echo", "name": "균열 미믹", "hp": 42, "armor": 0, "type": "MUMMY", "variant": 0, "rank": "mimic",
		"moves": [[7, 7], [], [14]], "role": "미믹 · 공격 7×2 → 준비 → 공격 14", "tint": Color(1.3, 0.85, 0.5), "scale": 1.2},
	"ruins_boss": {"name": "폭주한 근원체", "hp": 108, "armor": 1, "type": "RUINS_BOSS", "variant": 0, "rank": "boss",
		"moves": [[6, 6], [20], []], "role": "유적 보스 · 공격 6×2 → 강타 20(이번 턴 피해 14를 주면 10) → 쉼 반복 · 갑옷 1",
		"tint": Color(0.85, 0.7, 1.0), "scale": 1.75, "charge": {"round": 1, "full": 20, "weak": 10, "threshold": 14}},
}

const GROUPS := {
	"n1": {"name": "척후 둘", "enemies": ["scout", "scout"], "offsets": [0, 0], "teach": "기본: 의도를 보고 막거나 먼저 쓰러뜨리기"},
	"n2": {"name": "방패병과 사수", "enemies": ["shieldbearer", "archer"], "offsets": [0, 0], "teach": "방패: 약한 카드로 먼저 벗기면 강한 카드가 온전히 들어갑니다"},
	"n3": {"name": "기수와 척후", "enemies": ["banner", "scout"], "offsets": [0, 0], "teach": "기수: 먼저 쓰러뜨리면 척후의 공격이 5로 돌아갑니다"},
	"n4": {"name": "저주꾼과 파괴자", "enemies": ["hexer", "breaker"], "offsets": [0, 0], "teach": "주술: 다음 턴 방어 카드가 2씩 약해집니다"},
	"elite": {"name": "맥 거완과 사수", "enemies": ["maek_elite_low", "archer"], "offsets": [0, 1]},
	"boss": {"name": "맥 소환사", "enemies": ["maek_summoner_low", "maek_spawn_low", "maek_spawn_low"], "offsets": [0, 0, 0],
		"teach": "소환수는 다음 적 차례에 폭발 6. 먼저 처치하면 폭발하지 않고, 폭발은 방어로 막을 수 있습니다. 소환사를 쓰러뜨리면 바로 승리합니다."},
	"h1a": {"name": "방패 통로", "enemies": ["shieldbearer", "banner"], "offsets": [0, 0],
		"pressure": "첫 턴 공격 7+2 = 9 · 3 · 방패 8", "reward": "카드 + 사본 강화"},
	"h1b": {"name": "주술 통로", "enemies": ["hexer", "scout_h"], "offsets": [0, 0],
		"pressure": "첫 턴 주술 + 공격 6", "reward": "카드 + 유물"},
	"h2": {"name": "포격 진지", "enemies": ["guard_h", "cannon"], "offsets": [0, 0], "teach": "장치: 부술 수 있고, 보상은 없습니다"},
	"hboss": {"name": "맥 귀족", "enemies": ["maek_noble_mid"], "offsets": [0]},
	"elite_h": {"name": "돌파 대장과 척후", "enemies": ["leader", "scout_h"], "offsets": [0, 0]},
	"x1": {"name": "독과 철갑", "enemies": ["poisoner", "guard_h"], "offsets": [0, 0], "teach": "독: 내 턴 종료에 방어를 무시하고 2씩 두 번"},
	"x2": {"name": "기수의 사격대", "enemies": ["banner", "archer_h", "scout"], "offsets": [0, 0, 0]},
	"xboss": {"name": "균열의 핵", "enemies": ["cannon", "x_boss", "curse"], "offsets": [0, 0, 0]},
	"elite_x": {"name": "돌파 대장과 심층 사수", "enemies": ["leader", "archer_h"], "offsets": [0, 1]},
	"mimic_n": {"name": "수상한 상자", "enemies": ["mimic_n"], "offsets": [0]},
	"mimic_h": {"name": "수상한 상자", "enemies": ["mimic_h"], "offsets": [0]},
	"mimic_x": {"name": "수상한 상자", "enemies": ["mimic_x"], "offsets": [0]},
	"field_orc": {"name": "오크 척후 둘", "enemies": ["scout", "scout"], "offsets": [0, 0]},
	"field_skeleton": {"name": "스켈레톤 방패병과 사수", "enemies": ["shieldbearer", "archer"], "offsets": [0, 0]},
	"field_mummy": {"name": "미라 기수와 파괴자", "enemies": ["banner", "breaker"], "offsets": [0, 0]},
	"field_ruins": {"name": "폭주한 근원체", "enemies": ["ruins_boss"], "offsets": [0]},
}
const OPT_GROUPS := {"normal": {"elite": "elite", "mimic": "mimic_n"}, "hard": {"elite": "elite_h", "mimic": "mimic_h"},
	"extreme": {"elite": "elite_x", "mimic": "mimic_x"}}
const SECTORS := ["normal", "hard", "extreme"]
const SECTOR_NAMES := {"normal": "구간 I · 일반", "hard": "구간 II · 하드", "extreme": "구간 III · 익스트림"}
const SECTOR_FIGHTS := {"normal": ["n1", "n2", "n3", "n4"], "hard": ["h1", "h2"], "extreme": ["x1", "x2"]}
const SECTOR_BOSS := {"normal": "boss", "hard": "hboss", "extreme": "xboss"}
# 구간별 적 타격 배율(2026-10-16 원정 봇 측정 뒤): 일반 전투도 조금씩 깎이게. 기본 타격에 곱하고 반올림한 뒤 위험·기수 지원·억제를 더하고 뺀다
const SECTOR_HIT_MULT := {"normal": 1.0, "hard": 1.15, "extreme": 1.3}
# 상인은 이 전투를 이긴 뒤에 열린다
const SERVICE_AFTER := {"normal": "n2", "hard": "h1", "extreme": "x1"}

# 기본 카드 선택(보스 외 승리마다) 말고 더 주는 보상
const REWARD_PLAN := {
	"n1": [], "n2": ["upgrade"], "n3": ["relic"], "n4": ["upgrade_or_heal"], "boss": ["relic"],
	"h1a": ["upgrade"], "h1b": ["relic"], "h2": ["relic"], "hboss": [],
	"x1": ["upgrade"], "x2": ["relic"], "xboss": [], "opt": ["upgrade_or_relic"],
}
const REWARD_TEXT := {
	"card": "카드 3장 중 1장 (건너뛰기 가능)", "upgrade": "사본 강화 1", "relic": "유물 1 (5칸)", "upgrade_or_heal": "강화 또는 회복 6 중 하나",
	"upgrade_or_relic": "강화 또는 유물 중 하나", "settle": "구간 정산", "trait": "특성 3개 중 1개",
}
const PART_TITLES := {"trait": "특성", "card": "새 카드", "upgrade": "사본 강화", "relic": "유물", "upgrade_or_heal": "강화 또는 회복", "upgrade_or_relic": "강화 또는 유물"}


static func enemy(role: String) -> Dictionary:
	return ENEMIES[role]


static func variant_for(role: String, visual_type := "", visual_index := -1) -> Dictionary:
	var d: Dictionary = ENEMIES[role]
	var t := String(d.type) if visual_type == "" else visual_type
	var list: Array = BattleData.MONSTER_VARIANTS[t]
	var idx := int(d.variant) if visual_index < 0 else clampi(visual_index, 0, list.size() - 1)
	if visual_type != "" and visual_index < 0:
		idx = mini(int(d.variant), list.size() - 1)
	var v: Dictionary = (list[idx] as Dictionary).duplicate(true)
	var base_path: String = v.get("base", BattleData.MOB_SHEET_BASE) + v["folder"] + "/"
	v["idle_path"] = base_path + "Idle/Idle-Sheet.png"
	v["run_path"] = base_path + "Run/Run-Sheet.png"
	v["death_path"] = base_path + "Death/Death-Sheet.png"
	v["idle_frame_size"] = v.get("idle_frame_size", BattleData.MOB_IDLE_FRAME_SIZE)
	v["idle_frame_count"] = v.get("idle_frame_count", BattleData.MOB_IDLE_FRAME_COUNT)
	v["run_frame_size"] = v.get("run_frame_size", BattleData.MOB_RUN_FRAME_SIZE)
	v["run_frame_count"] = v.get("run_frame_count", BattleData.MOB_RUN_FRAME_COUNT)
	return v


# 야외 조우의 시각 변종(폴더 이름)을 저장 가능한 번호로 바꾼다
static func variant_index(monster_type: String, variant: Dictionary) -> int:
	var list: Array = BattleData.MONSTER_VARIANTS.get(monster_type, [])
	for i in range(list.size()):
		if String(list[i].folder) == String(variant.get("folder", "")):
			return i
	return -1


static func move_text(hits) -> String:
	if hits is Dictionary:
		match String(hits.get("act", "")):
			"hex":
				return "주술 (다음 내 턴 방어 −%d)" % HEX_AMOUNT
			"poison":
				return "독 %d × %d회" % [int(hits.get("amount", 2)), int(hits.get("ticks", 2))]
			"rebuild":
				return "장치 재가동"
			"summon":
				return "소환수 %d마리" % int(hits.get("count", 2))
			"wait":
				return "대기"
		return "준비"
	if (hits as Array).is_empty():
		return "준비"
	if hits.size() > 1:
		return "공격 %d × %d" % [int(hits[0]), hits.size()]
	return "공격 %d" % int(hits[0])


static func group_lines(group_id: String) -> Array[String]:
	var lines: Array[String] = []
	var g: Dictionary = GROUPS[group_id]
	for i in range(g.enemies.size()):
		var d: Dictionary = ENEMIES[g.enemies[i]]
		if bool(d.get("summon_slot", false)):
			if i == g.enemies.find(g.enemies[i]):
				lines.append("%s  체력 %d · %s (처음엔 없음, 소환으로 등장)" % [d.name, int(d.hp), d.role])
			continue
		var first := move_text(d.moves[int(g.offsets[i]) % d.moves.size()])
		lines.append("%s  체력 %d%s · %s (첫 턴: %s)" % [d.name, int(d.hp), " · 갑옷 %d" % int(d.armor) if int(d.armor) > 0 else "", d.role, first])
	return lines


static func threat(group_id: String) -> int:
	var total := 0
	for role in GROUPS[group_id].enemies:
		if not bool(ENEMIES[role].get("summon_slot", false)):
			total += int(ENEMIES[role].hp)
	return total


static func icon_tex(key: String) -> Texture2D:
	var v = ICONS.get(key, ICONS.slash)
	if v is String:
		return load(ITEM_DIR + String(v)) as Texture2D
	var at := AtlasTexture.new()
	at.atlas = load(RAVEN)
	at.region = v
	return at


# ── 직업 ───────────────────────────────────────────────────────────────────

static func class_max_mana(class_id: String) -> int:
	return MANA_BASE + int(CLASSES.get(class_id, {}).get("mana_bonus", 0))


static func class_deck(class_id: String) -> Array:
	return (CLASSES[class_id].deck as Array).duplicate()


static func relic_capacity(run: Dictionary = {}) -> int:
	return RELIC_SLOTS + (1 if (run.get("traits", []) as Array).has("wide_pack") else 0)


# 원정 전투 최대 마나: 직업 + 균열 심장 (최대 6)
static func run_max_mana(class_id: String, relics: Array) -> int:
	var m := class_max_mana(class_id) + (1 if relics.has("rift_heart") else 0)
	return mini(MANA_CAP, m)


# ── 카드 ───────────────────────────────────────────────────────────────────

static func card_name(kind: String, upgrade: String = "") -> String:
	if upgrade != "" and UPGRADES.has(upgrade):
		return String(UPGRADES[upgrade].name)
	return String(CARDS[kind][0])


static func make_card(entry: Dictionary) -> Card:
	return build_card(String(entry.kind), String(entry.uid), String(entry.get("upgrade", "")))


# 캠페인 .tres를 복제한 로컬 사본을 만든다(원본 리소스는 수정하지 않는다)
static func build_card(kind: String, uid: String, upgrade: String = "") -> Card:
	var d: Array = CARDS[kind]
	var c := (load("res://battle/cards/%s.tres" % CARD_KINDS[kind].library_id) as Card).duplicate(true) as Card
	c.card_name = d[0]
	c.mana_cost = d[1]
	c.value = d[2]
	c.color = d[3]
	c.is_aoe = d[4]
	match String(d[5]):
		"heal":
			c.effect = Card.EffectType.HEAL_HP
		"defend":
			c.effect = Card.EffectType.DEFEND
		"draw":
			c.effect = Card.EffectType.DRAW_CARDS
		"fuel":
			c.effect = Card.EffectType.RESTORE_MANA
		"debuff":
			c.effect = Card.EffectType.STATUS_PACKAGE
		"buff":
			c.effect = Card.EffectType.BUFF_ATTACK_SELF
		_:
			c.effect = Card.EffectType.DAMAGE
	c.damage_trait = ""
	c.status_package = ""
	c.hp_cost = 0
	c.switch_mark = 0
	c.on_use_set_gauge = 0
	c.secondary_value = 0
	c.tier = Card.CardTier.TIER_1
	c.set_meta("kind", kind)
	c.set_meta("uid", uid)
	c.set_meta("upgrade", upgrade)
	if UPGRADE_VALUE.has(upgrade):
		c.value = int(UPGRADE_VALUE[upgrade])
	if UPGRADE_AOE.has(upgrade):
		c.is_aoe = true
	if UPGRADE_COST.has(upgrade):
		c.mana_cost = int(UPGRADE_COST[upgrade])
	if upgrade != "":
		c.card_name = UPGRADES[upgrade].name
	return c


static func status_of(c: Card) -> Dictionary:
	return UPGRADE_STATUS.get(upgrade_of(c), CARD_STATUS.get(kind_of(c), {}))


static func kind_of(c: Card) -> String:
	return String(c.get_meta("kind", ""))


static func upgrade_of(c: Card) -> String:
	return String(c.get_meta("upgrade", ""))


static func uid_of(c: Card) -> String:
	return String(c.get_meta("uid", ""))


static func hits_of(c: Card) -> int:
	if upgrade_of(c) == "split":
		return 2
	if UPGRADE_HITS.has(upgrade_of(c)):
		return int(UPGRADE_HITS[upgrade_of(c)])
	return int(CARDS[kind_of(c)][6]) if CARDS.has(kind_of(c)) else 1


static func is_magic(c: Card) -> bool:
	return c.color == Card.CardColor.MAGIC


static func is_physical(c: Card) -> bool:
	return c.color == Card.CardColor.PHYSICAL


static func is_targeted(c: Card) -> bool:
	return (c.effect == Card.EffectType.DAMAGE or c.effect == Card.EffectType.STATUS_PACKAGE) and not c.is_aoe


# 피해 없이 적에게 상태만 거는 카드 · 나에게 거는 강화 카드
static func is_debuff(c: Card) -> bool:
	return c.effect == Card.EffectType.STATUS_PACKAGE


static func is_buff(c: Card) -> bool:
	return c.effect == Card.EffectType.BUFF_ATTACK_SELF


static func elem_of(c: Card) -> String:
	return String(CARD_ELEM.get(kind_of(c), "phys" if is_physical(c) else ""))


static func is_ult(c: Card) -> bool:
	return kind_of(c).begins_with("ult_")


static func is_draw(c: Card) -> bool:
	return c.effect == Card.EffectType.DRAW_CARDS


static func is_fuel(c: Card) -> bool:
	return kind_of(c) == "fuel"


static func is_attack(c: Card) -> bool:
	return c.effect == Card.EffectType.DAMAGE


static func exhausts(c: Card) -> bool:
	return EXHAUST_KINDS.has(kind_of(c))


static func retains(c: Card) -> bool:
	return kind_of(c) == "aimed_shot" and upgrade_of(c) != "instant_aim"


static func retains_entry(entry: Dictionary) -> bool:
	return String(entry.get("kind", "")) == "aimed_shot" and String(entry.get("upgrade", "")) != "instant_aim"


static func is_x_cost(c: Card) -> bool:
	return X_COST_KINDS.has(kind_of(c))


static func counter_value(c: Card) -> int:
	var up := upgrade_of(c)
	if COUNTER_VALUES.has(up):
		return int(COUNTER_VALUES[up])
	if kind_of(c) == "riposte":
		return int(COUNTER_VALUES.riposte)
	return 0


# 사본 수 규칙: 기본 3종 최대 3 · 그 외 최대 2 · 연료화 1 · 보존(조준 사격, 즉응 제외) 합계 2
static func copy_cap(kind: String) -> int:
	if kind == "fuel":
		return FUEL_CAP
	return BASIC_COPY_MAX if BASIC_KINDS.has(kind) else COPY_MAX


static func deck_errors(entries: Array) -> Array:
	var errors: Array = []
	var counts := {}
	var retain := 0
	for e in entries:
		var kind := String(e.get("kind", ""))
		if not CARDS.has(kind):
			errors.append("알 수 없는 카드 " + kind)
			continue
		counts[kind] = int(counts.get(kind, 0)) + 1
		if retains_entry(e):
			retain += 1
	for kind in counts:
		if int(counts[kind]) > copy_cap(String(kind)):
			errors.append("%s는 덱에 최대 %d장입니다" % [card_name(String(kind)), copy_cap(String(kind))])
	if retain > RETAIN_CAP:
		errors.append("보존 카드(조준 사격)는 덱에 최대 %d장입니다" % RETAIN_CAP)
	if entries.size() > DECK_VALIDATE_CAP:
		errors.append("덱이 %d장을 넘습니다" % DECK_VALIDATE_CAP)
	return errors


static func has_mark_source(entries: Array) -> bool:
	return entries.any(func(e): return MARK_SOURCES.has(String(e.kind)) or String(e.get("upgrade", "")) == "split")


static func has_defense_source(entries: Array) -> bool:
	return entries.any(func(e): return DEFENSE_SOURCES.has(String(e.kind)))


static func text(c: Card) -> String:
	match upgrade_of(c):
		"split":
			return "마법 3 × 2\n타격마다 표식 1"
		"counter":
			return "방어 7\n막으면 반격 4"
		"cleave_slash":
			return "물리 6\n다른 적마다 2"
		"double_inscription":
			return "모든 적 마법 5\n표식 1 + 추가 1"
		"carry_guard":
			return "방어 7\n남은 방어 3까지 이월"
		"pursuit_slash":
			return "물리 7\n처치하면 마나 1"
		"transfer_burst":
			return "마법 9 + 표식×3\n다른 적에 표식×2"
		"reflux_burst":
			return "마법 9 + 표식×3\n2개↑ 소비 시 마나 1"
		"fierce_riposte":
			return "방어 4\n막으면 반격 6"
		"layered_riposte":
			return "방어 8\n막으면 반격 3"
		"instant_aim":
			return "물리 12\n손에 남지 않음"
		"full_aim":
			return "물리 8 · 손에 남음\n한 턴 뒤 18"
	match kind_of(c):
		"slash":
			return "물리 5\n표식 1개당 +3"
		"bolt":
			return "마법 3\n살아남으면 표식 1"
		"guard":
			return "방어 5\n적 단계 뒤 사라짐"
		"sweep":
			return "모든 적 물리 4\n표식 터뜨림"
		"bash":
			return "방어 최대 4 사용\n물리 4 + 사용 × 2"
		"wave":
			return "모든 적 마법 5\n적마다 표식 1"
		"twin_slash":
			return "물리 3 × 2\n같은 적 두 번"
		"pierce":
			return "물리 4\n갑옷 무시"
		"suppress":
			return "마법 2 · 표식 1\n다음 공격 타당 −2"
		"focus":
			return "카드 2장 뽑기\n(손패 최대 7)"
		"sigil_burst":
			return "마법 6\n표식 소비 1개당 +3"
		"fuel":
			return "다른 카드 1장과 소진\n마나 +2"
		"torrent":
			return "마나 전부(X) 사용\n마법 6 × X"
		"mana_veil":
			return "방어 4\n+ 남은 마나 × 2 (최대 6)"
		"riposte":
			return "방어 4\n막으면 반격 2"
		"fortify":
			return "방어 8\n이번 전투 소진"
		"quickshot":
			return "물리 5\n그 턴 첫 공격이면 1장"
		"aimed_shot":
			return "물리 8 · 손에 남음\n한 턴 뒤 12"
	return ""


# 카드 앞면: [핵심 한 줄, 대상·조건·지속]. 수치는 카드 값에서 읽고 수호기사 반격 보정만 더한다 (규칙은 long_text와 같음)
static func flat_share(n: int, hits: int) -> int:
	return ceili(n / 3.0) if hits >= RAPID_HITS else n


static func face(c: Card, class_id := "") -> Array:
	var plus := stat_add(c, view_stats)
	var f := _face(c, class_id, plus)
	f.append(plus)
	return f


static func _face(c: Card, class_id: String, plus: int) -> Array:
	var v := c.value + plus
	var cb := WARDEN_COUNTER_BONUS if class_id == "warden" else 0
	if FX_TEXT.has(kind_of(c)) and upgrade_of(c) == "":
		var ft: Array = FX_TEXT[kind_of(c)]
		return [String(ft[0]) % v if String(ft[0]).contains("%d") else String(ft[0]), String(ft[1])]
	if UPGRADE_FACE.has(upgrade_of(c)):
		var uf: Array = UPGRADE_FACE[upgrade_of(c)]
		return [String(uf[0]) % v if String(uf[0]).contains("%d") else String(uf[0]), String(uf[1])]
	match upgrade_of(c):
		"split":
			return ["마법 %d × 2" % v, "대상 하나 · 타격마다 살아남으면 표식 1"]
		"counter":
			return ["방어 %d" % v, "이번 적 단계에 막아 내면 반격 %d (한 번)" % (int(COUNTER_VALUES.counter) + cb)]
		"cleave_slash":
			return ["물리 %d" % v, "대상 하나, 그 뒤 다른 적마다 2 (갑옷 적용)"]
		"double_inscription":
			return ["모든 적 마법 %d" % v, "살아남은 적마다 표식 2"]
		"carry_guard":
			return ["방어 %d" % v, "적 단계 뒤 남은 방어를 %d까지 다음 턴으로" % CARRY_GUARD_CAP]
		"pursuit_slash":
			return ["물리 %d" % v, "이 카드로 쓰러뜨리면 마나 1 (턴마다 한 번)"]
		"transfer_burst":
			return ["마법 %d + 표식×3" % v, "표식을 모두 소비 · 다른 적마다 소비 수×2"]
		"reflux_burst":
			return ["마법 %d + 표식×3" % v, "표식 2개 이상 소비하면 마나 1 (턴마다 한 번)"]
		"fierce_riposte":
			return ["방어 %d" % v, "막아 내면 반격 %d (한 번)" % (int(COUNTER_VALUES.fierce_riposte) + cb)]
		"layered_riposte":
			return ["방어 %d" % v, "막아 내면 반격 %d (한 번)" % (int(COUNTER_VALUES.layered_riposte) + cb)]
		"instant_aim":
			return ["물리 %d" % v, "곧바로 쏨 · 손에 남지 않고 충전 없음"]
		"full_aim":
			return ["물리 %d" % v, "쓰지 않고 턴을 넘기면 %d로 충전 (보존)" % FULL_AIM_CHARGED]
	match kind_of(c):
		"slash":
			return ["물리 %d" % v, "대상 하나 · 표식을 모두 터뜨려 1개당 +3"]
		"bolt":
			return ["마법 %d" % v, "대상 하나 · 살아남으면 표식 1"]
		"guard":
			return ["방어 %d" % v, "이번 적 단계가 끝나면 남은 방어는 사라짐"]
		"sweep":
			return ["모든 적 물리 %d" % v, "적마다 표식을 터뜨림"]
		"bash":
			return ["물리 %d + 방어×2" % v, "모아 둔 방어를 최대 %d 써서 더함" % BASH_MAX_SPEND]
		"wave":
			return ["모든 적 마법 %d" % v, "살아남은 적마다 표식 1"]
		"twin_slash":
			return ["물리 %d × 2" % v, "같은 대상 두 번 · 타격마다 갑옷 적용"]
		"pierce":
			return ["물리 %d" % v, "대상 하나 · 갑옷 무시"]
		"suppress":
			return ["마법 %d · 억제 2" % v, "살아남으면 표식 1 · 그 적의 다음 공격 타격마다 −2"]
		"focus":
			return ["카드 %d장 뽑기" % v, "손패 최대 %d장 (빈 자리만)" % HAND_MAX]
		"sigil_burst":
			return ["마법 %d + 표식×3" % v, "대상의 표식을 모두 소비 · 새 표식 없음"]
		"fuel":
			return ["마나 +%d" % FUEL_MANA, "손패의 다른 카드 1장과 함께 이번 전투에서 소진"]
		"torrent":
			return ["마법 %d × X" % c.value + ("+%d" % plus if plus > 0 else ""), "마나를 전부(X, 최소 1) 씀 · 살아남으면 표식 1"]
		"mana_veil":
			return ["방어 %d + 마나×2" % v, "비용을 낸 뒤 남은 마나 1당 +2 (최대 +%d)" % VEIL_BONUS_CAP]
		"riposte":
			return ["방어 %d" % v, "이번 적 단계에 막아 내면 반격 %d (한 번)" % (int(COUNTER_VALUES.riposte) + cb)]
		"fortify":
			return ["방어 %d" % v, "이번 전투에서 소진 (다음 전투엔 돌아옴)"]
		"quickshot":
			return ["물리 %d" % v, "이번 턴 첫 공격 카드면 1장 뽑기"]
		"aimed_shot":
			return ["물리 %d" % v, "쓰지 않고 턴을 넘기면 %d로 충전 (보존)" % AIM_CHARGED]
	var t := text(c).split("\n")
	return [t[0], " ".join(t.slice(1))]


# 카드 틀 색: 물리 공격 빨강 · 마법 파랑 · 방어 회색 · 도구 초록
static func frame_color(c: Card) -> String:
	if is_draw(c) or is_fuel(c) or is_buff(c):
		return "green"
	if is_debuff(c):
		return "blue"
	if c.effect == Card.EffectType.DEFEND:
		return "grey"
	return "blue" if is_magic(c) else "red"


static func long_text(kind: String, upgrade: String = "") -> String:
	if upgrade != "" and UPGRADES.has(upgrade):
		return String(UPGRADES[upgrade].text)
	if FX_TEXT.has(kind):
		return String(FX_TEXT[kind][2])
	match kind:
		"slash":
			return "대상에게 물리 5. 대상의 표식을 모두 터뜨려 1개당 +3 (갑옷 무시, 치명타 미적용)."
		"bolt":
			return "대상에게 마법 3. 살아남으면 표식 1. 표식은 물리 공격이나 터뜨리는 카드에 맞을 때 1개당 3씩 더 들어갑니다."
		"guard":
			return "방어 5. 이번 적 단계가 끝나면 남은 방어는 사라집니다."
		"sweep":
			return "살아 있는 모든 적에게 물리 4. 적마다 표식을 터뜨립니다."
		"bash":
			return "모아 둔 방어를 최대 4 써서 대상에게 물리 4 + 쓴 방어 × 2 (방어 4를 쓰면 12)."
		"wave":
			return "살아 있는 모든 적에게 마법 5. 피해가 들어가고 살아남은 적마다 표식 1."
		"twin_slash":
			return "같은 대상에게 물리 3을 두 번. 타격마다 갑옷 적용. 표식은 첫 타가 터뜨리고, 대상이 쓰러지면 둘째 타는 취소됩니다. 치명타 판정은 카드당 한 번."
		"pierce":
			return "대상에게 물리 4, 갑옷을 무시합니다. 표식은 평소처럼 터뜨립니다."
		"suppress":
			return "대상에게 마법 2 (살아남으면 표식 1). 억제 2: 그 적의 다음 공격 행동은 타격마다 2 줄어듭니다 (갱신만, 중첩 없음)."
		"focus":
			return "카드 2장을 뽑습니다 (손패 최대 7장, 빈 자리만)."
		"sigil_burst":
			return "대상에게 마법 6 + 대상의 표식을 모두 소비해 1개당 3. 새 표식은 남기지 않습니다."
		"fuel":
			return "손패의 다른 카드 1장을 골라 이 카드와 함께 이번 전투에서 소진하고 마나 +2 (최대 마나까지). 덱에 최대 1장."
		"torrent":
			return "현재 마나를 전부(최소 1) 써서 대상에게 마법 6 × X. 살아남으면 표식 1."
		"mana_veil":
			return "방어 4 + 비용을 낸 직후 남은 마나 × 2 (추가분 최대 6)."
		"riposte":
			return "방어 4 + 이번 적 단계에 반격 기회 1회 (피해 2, 수호기사 3). 방어가 실제로 막은 적 타격 하나마다 먼저 얻은 기회부터 씁니다."
		"fortify":
			return "방어 8. 이번 전투에서 소진됩니다 (다음 전투에는 돌아옴)."
		"quickshot":
			return "대상에게 물리 5. 이번 턴에 처음 내는 공격 카드였다면 효과가 끝난 뒤 1장을 뽑습니다."
		"aimed_shot":
			return "대상에게 물리 8. 턴이 끝나도 손에 남고, 남긴 채 턴을 넘기면 12로 충전됩니다. 내거나 버려지면 충전이 사라집니다. 덱에 보존 카드는 최대 2장."
	return ""


static func tint(c: Card) -> Color:
	match kind_of(c):
		"focus", "fuel":
			return Color("#3f8f94")
		"suppress":
			return Color("#5a6fd6")
		"pierce":
			return Color("#b6773a")
		"twin_slash":
			return Color("#c65a4a")
		"sigil_burst", "torrent":
			return Color("#8a4fd6")
		"quickshot", "aimed_shot":
			return Color("#5f8a3a")
		"riposte", "fortify", "mana_veil":
			return Color("#3f7f8f")
	if CARD_CLASS.get(kind_of(c), "") == "shaman" or is_debuff(c):
		return Color("#8a3fb0")
	match elem_of(c):
		"fire":
			return Color("#d9582a")
		"ice":
			return Color("#3f9fd6")
		"wind":
			return Color("#4fa88a")
		"light":
			return Color("#d6b13f")
		"dark":
			return Color("#5a3a8a")
		"poison":
			return Color("#5f9a3a")
	if c.color == Card.CardColor.MAGIC:
		return Color("#6f5bd6")
	if c.color == Card.CardColor.PHYSICAL:
		return Color("#c8683a")
	return Color("#4f8f6a")


static func type_label(c: Card) -> String:
	if is_draw(c) or is_fuel(c):
		return "도구"
	if is_debuff(c):
		return "방해"
	if is_buff(c):
		return "강화"
	if is_ult(c):
		return "필살"
	if kind_of(c) in ["quickshot", "aimed_shot"]:
		return "사격"
	if c.color == Card.CardColor.MAGIC:
		return "마법"
	if c.color == Card.CardColor.PHYSICAL:
		return "물리"
	return "방어"


static func card_icon_key(c: Card) -> String:
	var up := upgrade_of(c)
	return up if up != "" and ICONS.has(up) else kind_of(c)
