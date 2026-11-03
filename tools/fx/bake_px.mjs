// pixelfx 효과를 오르시아 시트로 굽는다: 1배 논리 픽셀(배우 원본 1px = 효과 1px), 본체 색 시트 + 부드러운 빛 마스크 시트 + Aseprite식 JSON.
// node tools/fx/bake_px.mjs [이름...]          recipes.mjs의 효과(없으면 전부) → assets/fx_px/<이름>/
// node tools/fx/bake_px.mjs --candidates       비교용 후보 전부 → tools/fx/out/candidates/<이름>/ (저장소에 넣지 않음)
// 본체: 효과의 color 버퍼를 레시피 팔레트 몇 색으로 맞춰 알파를 0/1로 자른다(연결된 픽셀 면, 미세색 · 블러 없음).
// 빛: light 버퍼를 따로(더하기로 얹는 마스크). 모든 장을 같은 크기로 자르고(전 장의 합 영역) 기준점을 그 안 좌표로 적어 흔들리지 않게 한다

import { writeFileSync, mkdirSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { createFrame, clearFrame, createFx } from "./pixelfx/src/core/index.js";
import { encodePNG } from "./pixelfx/tools/lib/png.mjs";
import { RECIPES, CANDIDATES, PIXELFX_COMMIT } from "./recipes.mjs";

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = join(HERE, "..", "..");

const rgbOf = (hex) => { const v = parseInt(hex.slice(1), 16); return [(v >> 16) & 255, (v >> 8) & 255, v & 255]; };

async function load(id) {
  const mod = await import(pathToFileURL(join(HERE, "pixelfx", "src", "fx", id + ".js")).href);
  return { ...mod, meta: { fps: 30, loop: false, duration: 1, options: {}, ...mod.meta } };
}

// 효과 하나를 장마다: 원래 시간 t = k · speed / fps (speed > 1이면 같은 움직임을 짧게)
function frames(mod, r) {
  const [W, H] = mod.meta.size, [OX, OY] = mod.meta.origin, pad = r.pad ?? 24;
  const w = W + pad * 2, h = H + pad * 2, fps = r.fps, speed = r.speed ?? 1;
  const n = Math.max(1, Math.round(((r.until ?? mod.meta.duration) / speed) * fps) + 1);
  const f = createFrame(w, h, -pad, -pad);
  const inst = createFx(mod, { x: OX, y: OY, ...(r.options ?? {}) });
  const out = [];
  for (let i = 0; i < n; i++) {
    if (i > 0) inst.update(speed / fps);
    clearFrame(f);
    inst.draw(f);
    out.push({ color: f.color.slice(), light: f.light.slice() });
  }
  return { w, h, ox: OX + pad, oy: OY + pad, list: out };
}

// 본체 색을 팔레트에 맞추고 알파를 자른다(0.5 아래 투명). 빛은 그대로
function cleanColor(c, pal) {
  const a = c >>> 24;
  if (a < 128) return 0;
  const r = c & 255, g = (c >>> 8) & 255, b = (c >>> 16) & 255;
  let best = pal[0], bd = 1e9;
  for (const p of pal) {
    const d = (p[0] - r) ** 2 + (p[1] - g) ** 2 + (p[2] - b) ** 2;
    if (d < bd) { bd = d; best = p; }
  }
  return best;
}

export async function bake(r, outDir) {
  const mod = await load(r.src);
  const fr = frames(mod, r);
  const pal = [...(r.options.palette ?? []), ...(r.options.sparks ?? []), ...(r.extra ?? []), "#ffffff"].map(rgbOf);
  const lightK = r.lightK ?? 1;
  // 전 장의 합 영역(본체 또는 빛이 있는 곳)
  let x0 = fr.w, y0 = fr.h, x1 = -1, y1 = -1;
  const cooked = fr.list.map(({ color, light }) => {
    const C = new Array(fr.w * fr.h), L = new Uint8Array(fr.w * fr.h * 3);
    for (let i = 0; i < fr.w * fr.h; i++) {
      C[i] = cleanColor(color[i], pal);
      const l = light[i];
      L[i * 3] = Math.min(255, (l & 255) * lightK); L[i * 3 + 1] = Math.min(255, ((l >>> 8) & 255) * lightK); L[i * 3 + 2] = Math.min(255, ((l >>> 16) & 255) * lightK);
      if (C[i] || L[i * 3] + L[i * 3 + 1] + L[i * 3 + 2] > 6) {
        const x = i % fr.w, y = (i / fr.w) | 0;
        x0 = Math.min(x0, x); x1 = Math.max(x1, x); y0 = Math.min(y0, y); y1 = Math.max(y1, y);
      }
    }
    return { C, L };
  });
  if (x1 < 0) throw new Error(r.name + ": 빈 효과");
  x0 = Math.max(0, x0 - 1); y0 = Math.max(0, y0 - 1); x1 = Math.min(fr.w - 1, x1 + 1); y1 = Math.min(fr.h - 1, y1 + 1);
  const w = x1 - x0 + 1, h = y1 - y0 + 1, n = cooked.length, cols = Math.min(n, 8), rows = Math.ceil(n / cols);
  const color = new Uint8Array(cols * w * rows * h * 4), light = new Uint8Array(cols * w * rows * h * 4);
  const json = { frames: [], meta: {} }, ms = Math.round(1000 / r.fps);
  // 장마다 빛 양(최대 장 = 1)과 빛의 평균 색: 실제 3D 순간 광원을 쓸 때 세기 · 색을 여기 맞춘다
  const glow = [], gsum = [0, 0, 0];
  cooked.forEach(({ L }) => {
    let s = 0;
    for (let i = 0; i < L.length; i += 3) { s += L[i] + L[i + 1] + L[i + 2]; gsum[0] += L[i]; gsum[1] += L[i + 1]; gsum[2] += L[i + 2]; }
    glow.push(s);
  });
  const gmax = Math.max(1, ...glow), gtot = Math.max(1, gsum[0], gsum[1], gsum[2]);
  cooked.forEach(({ C, L }, k) => {
    const fx = (k % cols) * w, fy = Math.floor(k / cols) * h;
    for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
      const si = (y + y0) * fr.w + (x + x0), di = ((fy + y) * cols * w + (fx + x)) * 4;
      const c = C[si];
      if (c) { color[di] = c[0]; color[di + 1] = c[1]; color[di + 2] = c[2]; color[di + 3] = 255; }
      const lr = L[si * 3], lg = L[si * 3 + 1], lb = L[si * 3 + 2];
      if (lr + lg + lb > 6) { light[di] = lr; light[di + 1] = lg; light[di + 2] = lb; light[di + 3] = 255; }
    }
    json.frames.push({ filename: `${r.name} ${k}`, frame: { x: fx, y: fy, w: w, h: h }, rotated: false, trimmed: false,
      spriteSourceSize: { x: 0, y: 0, w: w, h: h }, sourceSize: { w: w, h: h }, duration: ms });
  });
  json.meta = {
    app: "orsia tools/fx/bake_px.mjs", version: "1", image: `${r.name}.png`, light: `${r.name}_light.png`, format: "RGBA8888",
    size: { w: cols * w, h: rows * h }, scale: "1", frameTags: [{ name: r.name, from: 0, to: n - 1, direction: "forward" }],
    // pivot: 장 안 기준점(효과의 바닥 기준점 = 배우 발 또는 맞는 자리의 바닥). contact: 접촉 장(이 장이 입력 결과 · 피해 시점에 맞춰짐)
    pivot: [fr.ox - x0, fr.oy - y0], loop: false, fps: r.fps, contact: r.contact ?? 0, role: r.role,
    glow: glow.map((v) => Math.round((v / gmax) * 1000) / 1000), glow_color: gsum.map((v) => Math.round((v / gtot) * 1000) / 1000),
    source: { pixelfx: PIXELFX_COMMIT, id: r.src, options: r.options, speed: r.speed ?? 1, until: r.until ?? null, license: "MIT (tools/fx/pixelfx/LICENSE, NOTICE.md)" },
  };
  mkdirSync(outDir, { recursive: true });
  writeFileSync(join(outDir, `${r.name}.png`), encodePNG(cols * w, rows * h, color));
  writeFileSync(join(outDir, `${r.name}_light.png`), encodePNG(cols * w, rows * h, light));
  writeFileSync(join(outDir, `${r.name}.json`), JSON.stringify(json, null, 1));
  console.log(`${r.name}: ${n}장 ${w}×${h} · pivot ${json.meta.pivot} · ${(n * ms) / 1000}초 → ${outDir}`);
}

const args = process.argv.slice(2);
if (args[0] === "--candidates") {
  for (const r of CANDIDATES) await bake(r, join(HERE, "out", "candidates", r.name));
} else {
  for (const r of RECIPES.filter((q) => !args.length || args.includes(q.name))) await bake(r, join(ROOT, "assets", "fx_px", r.name));
}
