// 오르시아 효과 레시피: pixelfx 원본(고정 커밋) + 우리 색 · 크기 · 길이. 크기는 배우 원본 px 기준(수호자 몸 40, 강아지 · 고양이 32).
// 색: 청록 · 민트 · 크림이 바탕, 타격엔 작은 따뜻한 색(마법은 보라). speed > 1이면 원본 움직임을 그대로 짧게, until은 원본 시간에서 자르는 끝.
// contact: 접촉 장(입력 결과 · 피해 시점에 맞출 장). role: 베기 slash · 맞는 순간 hit · 완벽 패링 parry

export const PIXELFX_COMMIT = "a84159688af3ca37a4be05a0d422b94451b2e24e";

const TEAL = ["#0b2530", "#14505a", "#1f8a8c", "#3cc4b4", "#8fe8d0", "#eef6dc", "#ffffff"];
const WARM = ["#fff3c4", "#ffd98a", "#ffa860", "#e8704a"];
const HIT = ["#14303a", "#2a6a6a", "#c86a44", "#ffa860", "#ffe2b0", "#fff8e8", "#ffffff"];
const PARRY = ["#0b2530", "#17606a", "#2aa6a0", "#6fe0c8", "#c8f4dc", "#f6fbea", "#ffffff"];
const CREAM = ["#14262e", "#2c4a50", "#5e8a86", "#a8cfc0", "#e6efd8", "#fbf6e6", "#ffffff"];

// 비교 후보(수호자 · 강아지 옆에서 보고 고른다)
export const CANDIDATES = [
  { name: "slash_a", role: "slash", src: "melee/sword-slash", fps: 30, speed: 1.6, contact: 2, options: { palette: TEAL, sparks: WARM, radius: 28, seed: 2 } },
  { name: "slash_b", role: "slash", src: "melee/double-slash", fps: 30, speed: 1.6, contact: 4, options: { palette: TEAL, sparks: WARM, seed: 6 } },
  { name: "hit_a", role: "hit", src: "impacts/hit-spark", fps: 30, speed: 1.25, contact: 0, options: { palette: HIT, height: 24, aim: 0.1, seed: 4 } },
  { name: "hit_b", role: "hit", src: "impacts/blunt-hit", fps: 30, speed: 1.5, contact: 0, options: { palette: CREAM, warm: "#ffc98a", dust: "#8fa8a2", clod: "#3a5a5a", height: 24, seed: 9 } },
  { name: "parry_a", role: "parry", src: "impacts/parry", fps: 30, speed: 1.8, contact: 0, options: { palette: PARRY, height: 32, seed: 11 } },
  { name: "parry_b", role: "parry", src: "impacts/shield-block", fps: 30, speed: 2.0, contact: 0, options: { palette: PARRY, sparks: WARM, seed: 12 } },
];

// 고른 세 개(assets/fx_px/로 굽는 것). 후보 비교: 베기는 한 줄 초승달(a), 겹십자(b)는 연격용으로 남김 · 맞는 순간은 십자 섬광(a),
// 둔탁한 덩어리(b)는 첫 장이 강아지를 다 덮음 · 완벽 패링은 별 + 깨진 고리(a), 반구 방패(b)는 막음 · 방어용 후보로 남김.
// 빛은 첫 장 흰 광채가 배우를 삼키지 않게 줄이고(lightK), 패링은 불꽃 여운을 원본 0.8초에서 자른다
export const RECIPES = [
  { name: "slash_basic", role: "slash", src: "melee/sword-slash", fps: 30, speed: 1.6, contact: 2, lightK: 0.8, options: { palette: TEAL, sparks: WARM, radius: 28, seed: 2 } },
  { name: "hit_spark", role: "hit", src: "impacts/hit-spark", fps: 30, speed: 1.25, contact: 0, lightK: 0.55, options: { palette: HIT, height: 24, aim: 0.1, seed: 4 } },
  { name: "parry_perfect", role: "parry", src: "impacts/parry", fps: 30, speed: 1.8, until: 0.8, contact: 0, lightK: 0.5, options: { palette: PARRY, height: 32, seed: 11 } },
];
