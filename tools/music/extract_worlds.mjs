// 음악 엔진(engine.js)의 세계 데이터 중 화면이 쓰는 것만 JSON으로 뽑는다(음원 · 음악 구조는 건드리지 않음).
// node tools/music/extract_worlds.mjs → p2/scale_ring/worlds.json
// 세계마다 음계(도 = 0인 음 자리) · 색 · 이름 · 곳. common = 모든 세계 음계에 다 들어 있는 음(데이터로 셈)
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import vm from "node:vm";

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = join(HERE, "..", "..");
const box = { window: {} };
vm.runInNewContext(readFileSync(join(HERE, "engine.js"), "utf8"), box);
const E = box.window.E;
const worlds = {};
for (const id of E.ORDER) {
  const w = E.WORLDS[id];
  worlds[id] = { name: w.name, where: w.where, scale: [...w.scale], color: w.color };
}
const common = [...Array(12).keys()].filter((pc) => E.ORDER.every((id) => E.WORLDS[id].scale.includes(pc)));
const out = { source: "tools/music/engine.js", names: [...E.NAMES], order: [...E.ORDER], common: common, worlds: worlds };
mkdirSync(join(ROOT, "p2", "scale_ring"), { recursive: true });
writeFileSync(join(ROOT, "p2", "scale_ring", "worlds.json"), JSON.stringify(out, null, 1));
console.log("common", common.map((pc) => E.NAMES[pc]).join(" · "), "· worlds", E.ORDER.join(" "));
