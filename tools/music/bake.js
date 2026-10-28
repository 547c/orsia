// 게임용 소리 굽기: engine.js를 헤드리스 크로미움에서 오프라인 렌더링해 assets/music/ 에 ogg로, p2/p2_music_meta.gd를 만든다.
// node tools/music/bake.js [세계들=gye] [빠르기들=112,124,136]   (playwright · ffmpeg 필요)
// 겹(E.STEMS)은 8마디 고리(변주 0~3을 두 마디씩): 끝을 넘는 꼬리는 앞으로 접어 이음매가 없다
const { chromium } = require("playwright");
const fs = require("fs");
const path = require("path");
const { execFileSync } = require("child_process");

const ROOT = path.resolve(__dirname, "../..");
const OUT = path.join(ROOT, "assets/music");
const SR = 44100, PRE = 0.06, BARS = 8, TAIL = 3.0;
const worlds = (process.argv[2] || "gye").split(",");
const bpms = (process.argv[3] || "112,124,136").split(",").map(Number);

function writeOgg(file, L, R) {
  const n = L.length, b = Buffer.alloc(44 + n * 4);
  b.write("RIFF", 0); b.writeUInt32LE(36 + n * 4, 4); b.write("WAVE", 8); b.write("fmt ", 12);
  b.writeUInt32LE(16, 16); b.writeUInt16LE(1, 20); b.writeUInt16LE(2, 22); b.writeUInt32LE(SR, 24); b.writeUInt32LE(SR * 4, 28); b.writeUInt16LE(4, 32); b.writeUInt16LE(16, 34);
  b.write("data", 36); b.writeUInt32LE(n * 4, 40);
  let pk = 0;
  for (let i = 0; i < n; i++) for (const [c, x] of [[0, L[i]], [1, R[i]]]) { pk = Math.max(pk, Math.abs(x)); b.writeInt16LE(Math.max(-32768, Math.min(32767, Math.round(x * 32767))), 44 + i * 4 + c * 2); }
  fs.mkdirSync(path.dirname(file), { recursive: true });
  const tmp = file.replace(/\.ogg$/, ".tmp.wav");
  fs.writeFileSync(tmp, b);
  execFileSync("ffmpeg", ["-loglevel", "error", "-y", "-i", tmp, "-c:a", "libvorbis", "-q:a", "3", file]);
  fs.unlinkSync(tmp);
  return 20 * Math.log10(pk + 1e-9);
}
// 고리: t0부터 len만큼, 그 뒤 꼬리와 t0 앞 조각을 둘레로 접음
function fold(ch, t0, len) {
  const a = Math.round(t0 * SR), n = Math.round(len * SR), out = new Float32Array(n);
  for (let i = a; i < ch.length; i++) out[(i - a) % n] += ch[i];
  for (let i = 0; i < a; i++) out[(n - a + i) % n] += ch[i];
  return out;
}
// 막기 음은 음마다 줄 뜯기가 달라 크기가 들쭉날쭉: 첫 0.4초 RMS를 맞춤(완벽 −27dB · 막음 −39dB)
function level(L, R, db) {
  const a = Math.round(PRE * SR), n = Math.round(0.4 * SR);
  let ss = 0;
  for (let i = a; i < a + n; i++) ss += L[i] * L[i] + R[i] * R[i];
  const k = Math.pow(10, db / 20) / Math.sqrt(ss / (2 * n) + 1e-12);
  return [L.map(x => x * k), R.map(x => x * k)];
}
// 드론: 끝 xf초를 처음에 겹쳐 이음매 없이
function xfadeLoop(ch, start, len, xf) {
  const s = Math.round(start * SR), n = Math.round(len * SR), x = Math.round(xf * SR), out = new Float32Array(n);
  for (let i = 0; i < n; i++) out[i] = ch[s + i];
  for (let i = 0; i < x; i++) { const k = i / x; out[i] = ch[s + i] * k + ch[s + n + i] * (1 - k); }
  return out;
}

(async () => {
  const engine = fs.readFileSync(path.join(__dirname, "engine.js"), "utf8");
  const br = await chromium.launch();
  const pg = await br.newPage();
  pg.setDefaultTimeout(0);
  pg.on("pageerror", e => console.error("[page]", e.message));
  await pg.setContent("<script>" + engine + "</script>");
  const render = (sec, bpm, code) => pg.evaluate(async ([sec, bpm, code, SR]) => {
    const buf = await E.render(sec, bpm, (G, t0) => { E.reseed(7); new Function("G", "E", code)(G, E); }, SR, true);
    const enc = a => { const u = new Uint8Array(a.buffer.slice(0)); let s = ""; for (let i = 0; i < u.length; i += 0x8000) s += String.fromCharCode.apply(null, u.subarray(i, i + 0x8000)); return btoa(s); };
    return [enc(buf.getChannelData(0)), enc(buf.getChannelData(1))];
  }, [sec, bpm, code, SR]).then(([l, r]) => [new Float32Array(Buffer.from(l, "base64").buffer.slice(0)), new Float32Array(Buffer.from(r, "base64").buffer.slice(0))]);

  const info = await pg.evaluate(ws => ws.map(id => {
    const w = E.WORLDS[id], tones = [...new Set(w.motifG.concat(w.motifC))].sort((a, b) => a - b);
    return { id: id, motif_g: w.motifG, motif_c: w.motifC, tones: tones, stems: E.STEMS };
  }), worlds);

  const log = (f, db) => console.log(path.relative(ROOT, f).padEnd(40), "peak", db.toFixed(1), "dB");
  for (const wi of info) {
    const W = JSON.stringify(wi.id);
    for (const bpm of bpms) {
      const bar = 240 / bpm, len = BARS * bar, dir = path.join(OUT, wi.id, String(bpm));
      for (const st of wi.stems) {
        const [L, R] = await render(PRE + len + TAIL, bpm, `const w = E.WORLDS[${W}]; G.width = 0.8; for (let v = 0; v < 4; v++) E.stem(G, w, ${JSON.stringify(st)}, ${PRE} + v * 2 * G.bar, v);`);
        const f = path.join(dir, st + ".ogg");
        log(f, writeOgg(f, fold(L, PRE, len), fold(R, PRE, len)));
      }
      const beat = 60 / bpm;
      let [L, R] = await render(PRE + beat + 2.5, bpm, `const w = E.WORLDS[${W}]; E.fill(G, w, ${PRE}); E.riser(G, w, ${PRE}, G.beat);`);
      let f = path.join(dir, "fill.ogg"); log(f, writeOgg(f, L, R));
      [L, R] = await render(PRE + beat + 4, bpm, `const w = E.WORLDS[${W}]; G.width = 0.8; E.ending(G, w, ${PRE} + G.beat);`);
      f = path.join(dir, "end.ogg"); log(f, writeOgg(f, L, R));
    }
    for (const kind of ["perfect", "block"]) for (const semi of wi.tones) {
      const [L, R] = level(...await render(PRE + 2.2, 124, `E.parry(G, E.WORLDS[${W}], ${PRE}, ${semi}, ${JSON.stringify(kind)});`), kind === "block" ? -39 : -27);
      const f = path.join(OUT, wi.id, "tone", `${kind}_${semi < 0 ? "m" + -semi : semi}.ogg`);
      log(f, writeOgg(f, L, R));
    }
  }
  let [L, R] = await render(24, 124, "E.droneTo(G, 0, 1);");
  let f = path.join(OUT, "common", "drone.ogg"); log(f, writeOgg(f, xfadeLoop(L, 4, 16, 1.5), xfadeLoop(R, 4, 16, 1.5)));
  for (const nm of ["thud", "crack"]) {
    [L, R] = await render(PRE + 0.9, 124, `E.${nm}(G, ${PRE});`);
    f = path.join(OUT, "common", nm + ".ogg"); log(f, writeOgg(f, L, R));
  }
  await br.close();

  // 이미 구운 세계는 남기고 이번 것만 덮어씀
  const metaFile = path.join(ROOT, "p2/p2_music_meta.gd");
  const old = {};
  if (fs.existsSync(metaFile)) for (const m of fs.readFileSync(metaFile, "utf8").matchAll(/^\t"(\w+)": (\{.*\}),$/gm)) old[m[1]] = m[2];
  for (const wi of info) old[wi.id] = JSON.stringify({ motif_g: wi.motif_g, motif_c: wi.motif_c, tones: wi.tones, bpms: bpms }).replace(/,/g, ", ").replace(/:/g, ": ");
  const body = Object.keys(old).sort().map(k => `\t"${k}": ${old[k]},`).join("\n");
  fs.writeFileSync(metaFile, `class_name P2MusicMeta
# tools/music/bake.js가 만드는 파일: 구운 세계 · 빠르기 · 막기 음 동기(반음, C5 기준). 손으로 고치지 말고 다시 구울 것

const PRE := ${PRE}
const BARS := ${BARS}
const STEMS := ${JSON.stringify(info[0].stems).replace(/,/g, ", ")}
const WORLDS := {
${body}
}
`);
  console.log("meta", path.relative(ROOT, metaFile));
})();
