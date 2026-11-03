# 픽셀 효과 굽기 (pixelfx → 오르시아 시트)

원본: https://github.com/patch-gg/pixelfx 커밋 `a84159688af3ca37a4be05a0d422b94451b2e24e` (MIT).
`pixelfx/`에는 쓰는 것만 원본 그대로 옮겨 두었다: `src/core/`, 고른 효과(`melee/sword-slash`, `melee/double-slash`, `impacts/hit-spark`, `blunt-hit`, `parry`, `shield-block`과 각 `_lib`), `tools/lib/png.mjs`, `LICENSE`, `NOTICE.md`. `gallery/fonts`의 Patch Pixel 폰트(MIT 아님)는 가져오지 않았다.

## 다시 만들기

```bash
node tools/fx/bake_px.mjs
```

```bash
python3 tools/fx/preview_px.py assets/fx_px/slash_basic assets/fx_px/hit_spark assets/fx_px/parry_perfect --out tools/fx/previews --scale 3
```

후보 비교(저장소에 넣지 않음): `node tools/fx/bake_px.mjs --candidates` → `tools/fx/out/candidates/`.

## 결과물 (`assets/fx_px/<이름>/`)

- `<이름>.png`: 본체. 레시피 팔레트 몇 색 + 알파 0/1(연결된 픽셀 면, 미세색 · 블러 없음)
- `<이름>_light.png`: 부드러운 빛 마스크(같은 배치). 더하기로 얹는다
- `<이름>.json`: Aseprite식(`frames[].frame` 영역 · `duration` 장별 ms, `meta.frameTags`) + `meta.pivot`(장 안 바닥 기준점) · `loop` · `fps` · `contact`(접촉 장) · `role` · `source`(원본 id · 옵션 · 속도 · 커밋)

1배 논리 픽셀이다(배우 원본 1px = 효과 1px). 화면 배율은 재생하는 쪽(3D 원근)에 맡기고, 미리보기(`tools/fx/previews/`)만 정수배로 키웠다.

| 이름 | 원본 | 길이 | 크기(접촉 장 본체) | 바닥 기준점 |
|---|---|---|---|---|
| slash_basic | melee/sword-slash, radius 28, 1.6배속 | 15장 0.5초 | 49×49 | 공격자 발 |
| hit_spark | impacts/hit-spark, 높이 24, 1.25배속 | 13장 0.43초 | 십자 섬광 중심 높이 27 | 맞는 쪽 발 |
| parry_perfect | impacts/parry, 높이 32, 1.8배속 · 원본 0.8초까지 | 14장 0.46초 | 44×33, 중심 높이 33 | 막는 쪽 앞 바닥 |
