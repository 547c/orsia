// 오르시아 전투 음악 엔진 (WebAudio). 실시간 재생과 오프라인 렌더링이 같은 함수를 쓴다.
// 뼈대: 으뜸음 C · 딸림음 G에 머무는 바닥음/베이스, G 받침 음, 킥·하이햇은 늘 같은 박. 나라마다 음계·주 악기·부선율 악기·타악기만 바뀜
window.E = (function () {
  const E = {};
  E.WORLDS = {
    hijaz:  { name: "히자즈", where: "아랍 마캄", scale: [0, 1, 4, 5, 7, 8, 10], color: "#3fb5a8", lead: "oud", counter: "qanun", perc: "darbuka", sixth: 8, leadName: "우드", counterName: "카눈", percName: "다르부카" },
    dorian: { name: "도리안", where: "유럽 옛 선법", scale: [0, 2, 3, 5, 7, 9, 10], color: "#b48cff", lead: "fiddle", counter: "harp", perc: "frame", sixth: 9, leadName: "피들", counterName: "하프", percName: "프레임 북" },
    gong:   { name: "궁조", where: "중국 5음", scale: [0, 2, 4, 7, 9], color: "#ff6b5a", lead: "erhu", counter: "zheng", perc: "china", sixth: 9, leadName: "얼후", counterName: "고쟁", percName: "목탁 · 바라" },
    inn:    { name: "인 음계", where: "일본 미야코부시", scale: [0, 1, 5, 7, 8], color: "#f2a7c3", lead: "koto", counter: "shaku", perc: "taiko", sixth: 8, leadName: "고토", counterName: "샤쿠하치", percName: "타이코 · 카네" },
    degung: { name: "데궁", where: "순다 가믈란", scale: [0, 1, 3, 7, 8], color: "#e8a64a", lead: "bonang", counter: "suling", perc: "kendang", sixth: 8, leadName: "보낭(가믈란 종)", counterName: "술링 피리", percName: "끈당 · 징" },
  };
  E.ORDER = ["hijaz", "dorian", "gong", "inn", "degung"];
  // 2마디 선율 [16분 자리, 음계 몇 번째, 길이(16분)] — 정박을 당기고 미는 자리 섞음
  const MAIN = [[0, 4, 2], [3, 5, 1], [4, 4, 3], [7, 2, 1], [8, 3, 2], [10, 4, 2], [12, 2, 3], [15, 1, 1],
                [16, 0, 4], [22, 1, 1], [23, 2, 2], [26, 4, 2], [28, 3, 1], [29, 2, 3]];
  // 부선율: 주선율이 길게 끌거나 쉴 때만 빈 곳을 채움 (높게)
  const COUNTER = [[5, 7, 1], [6, 6, 1], [13, 6, 1], [14, 5, 1], [18, 7, 1], [19, 8, 1], [20, 7, 2], [24, 5, 1], [31, 6, 1]];

  let seed = 12345;
  function rnd() { seed = (seed * 1103515245 + 12345) & 0x7fffffff; return seed / 0x7fffffff; }
  E.reseed = function (s) { seed = s; };
  function deg(scale, d) { const n = scale.length; const o = Math.floor(d / n); const i = ((d % n) + n) % n; return scale[i] + 12 * o; }
  E.deg = deg;
  function hz(m) { return 440 * Math.pow(2, (m - 69) / 12); }

  E.build = function (c, bpm) {
    const G = { c: c, bpm: bpm || 128, ks: {}, ducks: [], buses: {} };
    G.beat = 60 / G.bpm; G.s16 = G.beat / 4; G.bar = G.beat * 4;
    const comp = c.createDynamicsCompressor(); comp.threshold.value = -14; comp.ratio.value = 3; comp.attack.value = 0.004; comp.release.value = 0.18; comp.knee.value = 8;
    const clip = c.createWaveShaper(); const cv = new Float32Array(1024);
    for (let i = 0; i < 1024; i++) { const x = i / 511.5 - 1; cv[i] = Math.tanh(1.4 * x) / Math.tanh(1.4); }
    clip.curve = cv;
    const out = c.createGain(); out.gain.value = 0.85;
    G.master = c.createGain(); G.master.gain.value = 0.7;
    const air = c.createBiquadFilter(); air.type = "highshelf"; air.frequency.value = 5000; air.gain.value = 5;
    const lowTrim = c.createBiquadFilter(); lowTrim.type = "lowshelf"; lowTrim.frequency.value = 90; lowTrim.gain.value = -2;
    G.master.connect(air); air.connect(lowTrim); lowTrim.connect(comp); comp.connect(clip); clip.connect(out); out.connect(c.destination);
    // 울림: 짧은 초기 반사 + 2.6초 꼬리, 좌우 따로 → 넓게
    const len = Math.floor(c.sampleRate * 2.6), ir = c.createBuffer(2, len, c.sampleRate);
    for (let ch = 0; ch < 2; ch++) {
      const d = ir.getChannelData(ch); let lp = 0;
      for (let i = 0; i < len; i++) { const n = Math.random() * 2 - 1; lp += (n - lp) * (0.55 - 0.45 * i / len); d[i] = lp * Math.pow(1 - i / len, 3.2); }
      for (const ms of [11, 19, 29, 37, 53]) { const k = Math.floor(c.sampleRate * (ms + ch * 3) / 1000); if (k < len) d[k] += 0.6 * (Math.random() < 0.5 ? -1 : 1); }
    }
    G.rev = c.createConvolver(); G.rev.buffer = ir;
    const revLP = c.createBiquadFilter(); revLP.type = "lowpass"; revLP.frequency.value = 9000;
    const revHP = c.createBiquadFilter(); revHP.type = "highpass"; revHP.frequency.value = 180;
    const revOut = c.createGain(); revOut.gain.value = 0.62;
    G.rev.connect(revHP); revHP.connect(revLP); revLP.connect(revOut); revOut.connect(G.master);
    // 메아리: 점8분 핑퐁
    G.dly = c.createGain();
    const dl = c.createDelay(2), dr = c.createDelay(2), fb = c.createGain(), dlp = c.createBiquadFilter();
    dl.delayTime.value = G.beat * 0.75; dr.delayTime.value = G.beat * 0.75; fb.gain.value = 0.34; dlp.type = "lowpass"; dlp.frequency.value = 3200;
    const pl = c.createStereoPanner(), pr = c.createStereoPanner(); pl.pan.value = -0.75; pr.pan.value = 0.75;
    const dOut = c.createGain(); dOut.gain.value = 0.5;
    G.dly.connect(dl); dl.connect(pl); pl.connect(dOut); dl.connect(dlp); dlp.connect(dr); dr.connect(pr); pr.connect(dOut); dr.connect(fb); fb.connect(dl);
    dOut.connect(G.master); dOut.connect(G.rev);
    G.setDelay = function (bpm) { const b = 60 / bpm; dl.delayTime.setValueAtTime(b * 0.75, c.currentTime); dr.delayTime.setValueAtTime(b * 0.75, c.currentTime); };
    function bus(name, gain, pan, rev, dly, duck) {
      const g = c.createGain(); g.gain.value = gain;
      const mute = c.createGain(); mute.gain.value = 1;
      let tail = g;
      if (duck) { const dk = c.createGain(); dk.gain.value = 1; g.connect(dk); tail = dk; G.ducks.push(dk.gain); }
      tail.connect(mute);
      const p = c.createStereoPanner(); p.pan.value = pan; mute.connect(p); p.connect(G.master);
      if (name === "lead" || name === "pad" || name === "perc") {
        const hd = c.createDelay(0.05); hd.delayTime.value = name === "perc" ? 0.017 : 0.012; const hg = c.createGain(); hg.gain.value = 0.3;
        const hp = c.createStereoPanner(); hp.pan.value = 0.85; p.pan.value = pan - 0.35;
        mute.connect(hd); hd.connect(hg); hg.connect(hp); hp.connect(G.master);
      }
      if (rev) { const s = c.createGain(); s.gain.value = rev; mute.connect(s); s.connect(G.rev); }
      if (dly) { const s = c.createGain(); s.gain.value = dly; mute.connect(s); s.connect(G.dly); }
      G.buses[name] = { in: g, mute: mute.gain };
      return g;
    }
    G.kick = bus("kick", 0.95, 0, 0, 0, false);
    G.drum = bus("drum", 0.6, 0.1, 0.14, 0, false);
    G.perc = bus("perc", 0.5, 0, 0.28, 0.06, false);
    G.bass = bus("bass", 0.62, 0, 0, 0, true);
    G.pad = bus("pad", 0.24, 0, 0.45, 0, true);
    G.ost = bus("ost", 0.19, -0.55, 0.25, 0.25, true);
    G.lead = bus("lead", 0.5, 0.04, 0.32, 0.18, false);
    G.counter = bus("counter", 0.34, 0.55, 0.4, 0.22, true);
    G.fx = bus("fx", 0.3, 0, 0.7, 0.3, false);
    G.parry = bus("parry", 0.5, 0, 0.4, 0.14, false);
    const nb = c.createBuffer(1, c.sampleRate, c.sampleRate), nd = nb.getChannelData(0);
    for (let i = 0; i < nd.length; i++) nd[i] = Math.random() * 2 - 1;
    G.noise = nb;
    return G;
  };
  E.setMute = function (G, name, on) { if (G.buses[name]) G.buses[name].mute.setTargetAtTime(on ? 0 : 1, G.c.currentTime, 0.05); };

  // ── 기본 소리 조각 ──
  function env(G, t, out, a, peak, dec) {
    const n = G.c.createGain(); n.gain.setValueAtTime(0.0001, t);
    n.gain.exponentialRampToValueAtTime(Math.max(0.0002, peak), t + a); n.gain.exponentialRampToValueAtTime(0.0001, t + a + dec);
    n.connect(out); return n;
  }
  function sus(G, t, out, a, peak, hold, rel) {
    const n = G.c.createGain(); n.gain.setValueAtTime(0.0001, t);
    n.gain.exponentialRampToValueAtTime(Math.max(0.0002, peak), t + a); n.gain.setValueAtTime(peak, t + a + hold); n.gain.exponentialRampToValueAtTime(0.0001, t + a + hold + rel);
    n.connect(out); return n;
  }
  function osc(G, t, type, f, out, a, peak, dec) { const o = G.c.createOscillator(); o.type = type; o.frequency.value = f; o.connect(env(G, t, out, a, peak, dec)); o.start(t); o.stop(t + a + dec + 0.05); return o; }
  function nz(G, t, type, f, q, out, peak, dec, a) {
    const s = G.c.createBufferSource(), fl = G.c.createBiquadFilter(); s.buffer = G.noise; fl.type = type; fl.frequency.value = f; fl.Q.value = q;
    s.playbackRate.value = 0.9 + rnd() * 0.2;
    s.connect(fl); fl.connect(env(G, t, out, a || 0.002, peak, dec)); s.start(t, rnd() * 0.5); s.stop(t + (a || 0.002) + dec + 0.05); return fl;
  }
  function duck(G, t, depth) {
    for (const p of G.ducks) { p.setValueAtTime(1, t); p.linearRampToValueAtTime(depth, t + 0.012); p.setTargetAtTime(1, t + 0.04, 0.07); }
  }
  function ks(G, midi, bright, decay) {
    const key = midi + ":" + bright + ":" + decay;
    if (G.ks[key]) return G.ks[key];
    const sr = G.c.sampleRate, n = Math.max(2, Math.round(sr / hz(midi))), len = Math.round(sr * decay);
    const buf = G.c.createBuffer(1, len, sr), d = buf.getChannelData(0), ring = new Float32Array(n);
    for (let i = 0; i < n; i++) ring[i] = Math.random() * 2 - 1;
    let idx = 0;
    for (let i = 0; i < len; i++) { const nx = (idx + 1) % n; const v = ring[idx]; ring[idx] = (v * bright + ring[nx] * (1 - bright)) * 0.9975; d[i] = v; idx = nx; }
    return (G.ks[key] = buf);
  }
  function pluck(G, t, midi, vel, out, bright, decay, cut, bend, body) {
    const s = G.c.createBufferSource(); s.buffer = ks(G, midi, bright, decay);
    if (bend) { s.playbackRate.setValueAtTime(bend, t); s.playbackRate.exponentialRampToValueAtTime(1, t + 0.06); }
    const f = G.c.createBiquadFilter(); f.type = "lowpass"; f.frequency.value = cut;
    let last = f; s.connect(f);
    for (const [fq, gn] of (body || [])) { const pk = G.c.createBiquadFilter(); pk.type = "peaking"; pk.frequency.value = fq; pk.Q.value = 1.4; pk.gain.value = gn; last.connect(pk); last = pk; }
    last.connect(env(G, t, out, 0.002, vel, decay)); s.start(t); s.stop(t + decay + 0.05);
  }
  function bell(G, t, midi, vel, out, dec, partials, beatHz) {
    const f = hz(midi);
    (partials || [[1, 1], [2.756, 0.42], [5.404, 0.22], [8.93, 0.1]]).forEach(([r, a], i) => {
      osc(G, t, "sine", f * r, out, 0.002, vel * a, dec / (1 + i * 0.7));
      if (beatHz && i === 0) osc(G, t, "sine", f * r + beatHz, out, 0.002, vel * a * 0.8, dec);
    });
  }
  function bowed(G, t, midi, vel, out, dur, o) {
    const c = G.c, f0 = hz(midi);
    const v = c.createOscillator(); v.type = "sawtooth";
    if (o.slide) { v.frequency.setValueAtTime(f0 * Math.pow(2, -o.slide / 12), t); v.frequency.exponentialRampToValueAtTime(f0, t + 0.07); } else v.frequency.value = f0;
    const lfo = c.createOscillator(), lg = c.createGain(); lfo.frequency.value = o.vibHz || 5.6;
    lg.gain.setValueAtTime(0, t); lg.gain.linearRampToValueAtTime(f0 * (o.vib || 0.008), t + Math.min(dur * 0.6, 0.18)); lfo.connect(lg); lg.connect(v.frequency);
    let last = v;
    for (const [type, fq, q, gn] of o.filters) { const fl = c.createBiquadFilter(); fl.type = type; fl.frequency.value = fq; fl.Q.value = q; if (gn !== undefined) fl.gain.value = gn; last.connect(fl); last = fl; }
    const a = o.attack || 0.05;
    last.connect(sus(G, t, out, a, vel, Math.max(0.01, dur - a), o.rel || 0.12));
    v.start(t); lfo.start(t); v.stop(t + dur + (o.rel || 0.12) + 0.05); lfo.stop(t + dur + (o.rel || 0.12) + 0.05);
    if (o.bowNoise) nz(G, t, "bandpass", 3000, 1.2, out, vel * o.bowNoise, Math.min(dur, 0.25), 0.03);
  }
  function flute(G, t, midi, vel, out, dur, breath, drop) {
    const c = G.c, f0 = hz(midi);
    const v = c.createOscillator(); v.type = "sine"; v.frequency.value = f0;
    if (drop) { v.frequency.setValueAtTime(f0, t + dur * 0.7); v.frequency.exponentialRampToValueAtTime(f0 * 0.97, t + dur); }
    const lfo = c.createOscillator(), lg = c.createGain(); lfo.frequency.value = 4.8; lg.gain.setValueAtTime(0, t); lg.gain.linearRampToValueAtTime(f0 * 0.009, t + Math.min(0.25, dur * 0.7));
    lfo.connect(lg); lg.connect(v.frequency);
    const h = c.createOscillator(); h.type = "triangle"; h.frequency.value = f0 * 2; const hg = c.createGain(); hg.gain.value = 0.12; h.connect(hg);
    const sum = c.createGain(); v.connect(sum); hg.connect(sum);
    sum.connect(sus(G, t, out, 0.06, vel, Math.max(0.02, dur - 0.06), 0.15));
    v.start(t); h.start(t); lfo.start(t); v.stop(t + dur + 0.25); h.stop(t + dur + 0.25); lfo.stop(t + dur + 0.25);
    nz(G, t, "bandpass", f0 * 2.2, 2.5, out, vel * (breath || 0.3), dur * 0.8, 0.04);
  }

  // ── 악기 ──
  E.inst = function (G, kind, t, midi, vel, dur, out) {
    out = out || G.lead;
    switch (kind) {
      case "oud": pluck(G, t, midi, vel * 1.3, out, 0.5, 1.0, 5200, 0.985, [[260, 4], [1250, 3], [3200, 3]]); break;
      case "qanun": for (let k = 0; k < 3; k++) pluck(G, t + k * G.s16 / 2, midi + 12, vel * (0.9 - k * 0.22), out, 0.78, 0.7, 9000, 0, [[2400, 3], [5000, 3]]); break;
      case "fiddle": bowed(G, t, midi, vel * 0.55, out, dur, { filters: [["lowpass", 7500, 0.7], ["peaking", 520, 1.2, 3], ["peaking", 1600, 1.4, 3], ["peaking", 3200, 1.6, 5]], vib: 0.006, attack: 0.04, bowNoise: 0.15 }); break;
      case "harp": pluck(G, t, midi + 12, vel * 1.05, out, 0.68, 1.4, 7000, 0, [[900, 2], [3500, 3]]); break;
      case "erhu": bowed(G, t, midi, vel * 0.6, out, dur, { filters: [["highpass", 320, 0.7], ["peaking", 1150, 1.2, 7], ["peaking", 2600, 1.5, 4], ["lowpass", 7000, 0.7]], vib: 0.011, vibHz: 6.2, slide: 1, attack: 0.06, bowNoise: 0.25 }); break;
      case "zheng": pluck(G, t, midi + 12, vel * 1.1, out, 0.84, 1.2, 9500, 0.94, [[1800, 3], [4500, 3]]); break;
      case "koto": pluck(G, t, midi, vel * 1.2, out, 0.78, 1.5, 7500, 0.97, [[700, 3], [2200, 4], [4800, 3]]); break;
      case "shaku": flute(G, t, midi + 12, vel * 0.5, out, Math.max(dur, 0.25), 0.55, true); break;
      case "bonang": bell(G, t, midi + 12, vel * 0.55, out, 1.3, [[1, 1], [2.01, 0.35], [3.0, 0.18], [4.12, 0.08]], 4.5); break;
      case "suling": flute(G, t, midi + 12, vel * 0.45, out, Math.max(dur, 0.2), 0.35, false); break;
    }
  };

  // ── 박 뼈대 (늘 같음) ──
  function kick(G, t, v) {
    const o = G.c.createOscillator(); o.type = "sine"; o.frequency.setValueAtTime(170, t); o.frequency.exponentialRampToValueAtTime(48, t + 0.09);
    o.connect(env(G, t, G.kick, 0.002, v, 0.34)); o.start(t); o.stop(t + 0.4);
    const sb = G.c.createOscillator(); sb.type = "sine"; sb.frequency.setValueAtTime(62, t); sb.frequency.exponentialRampToValueAtTime(44, t + 0.3);
    sb.connect(env(G, t, G.kick, 0.004, v * 0.75, 0.42)); sb.start(t); sb.stop(t + 0.5);
    nz(G, t, "highpass", 2500, 0.7, G.kick, v * 0.4, 0.012);
    duck(G, t, 0.42);
  }
  function clap(G, t, v) {
    for (const d of [0, 0.011, 0.024]) nz(G, t + d, "bandpass", 1700, 0.9, G.drum, v * (d ? 0.55 : 0.8), 0.022);
    nz(G, t + 0.03, "bandpass", 1500, 0.7, G.drum, v * 0.45, 0.16);
    osc(G, t, "triangle", 210, G.drum, 0.002, v * 0.2, 0.06);
  }
  function hat(G, t, v, open) { nz(G, t, "highpass", 6800, 0.8, G.drum, v * 1.5, open ? 0.22 : 0.04); nz(G, t, "bandpass", 10500, 1.2, G.drum, v * 0.9, open ? 0.16 : 0.03); }
  function shaker(G, t, v) { nz(G, t, "bandpass", 7000, 1.2, G.drum, v * 1.6, 0.05, 0.008); }
  function hum(G) { return (rnd() - 0.5) * 0.008; }

  E.groove = function (G, t, kind, intensity) {
    for (let s = 0; s < 16; s++) {
      const ts = t + s * G.s16, j = s % 4 === 0 ? 0 : hum(G), acc = 0.85 + rnd() * 0.3;
      if (kind === "A") {
        if (s === 0 || s === 8) kick(G, ts, 0.95);
        if (s === 10 && intensity > 0) kick(G, ts, 0.55);
        if (s === 8 && intensity > 0) clap(G, ts, 0.55);
        if (s % 2 === 0) hat(G, ts + j, (s % 4 === 0 ? 0.1 : 0.16) * acc, false);
      } else if (kind === "B") {
        if (s % 4 === 0) kick(G, ts, 1.0);
        if (s === 4 || s === 12) clap(G, ts, 0.75);
        if (s % 4 === 2) hat(G, ts + j, 0.17 * acc, true);
        if (s % 2 === 1) hat(G, ts + j, 0.06 * acc, false);
        shaker(G, ts + j, (s % 4 === 2 ? 0.1 : 0.05) * acc);
      } else if (kind === "break") {
        if (s % 2 === 0) hat(G, ts + j, 0.07 * acc, false);
      }
    }
  };

  // ── 나라 타악기 (마디 하나) · 필인 ──
  E.perc = function (G, w, t, fill) {
    const P = G.perc, step = s => t + s * G.s16 + (s % 4 ? hum(G) : 0);
    const doum = (ts, v) => { const o = osc(G, ts, "sine", 115, P, 0.002, v, 0.22); o.frequency.exponentialRampToValueAtTime(68, ts + 0.12); nz(G, ts, "lowpass", 400, 1, P, v * 0.2, 0.05); };
    const tek = (ts, v) => nz(G, ts, "bandpass", 4300, 2.2, P, v * 1.3, 0.05);
    const ka = (ts, v) => nz(G, ts, "bandpass", 2400, 2, P, v, 0.035);
    if (w.perc === "darbuka") { doum(step(0), 0.55); tek(step(2), 0.32); tek(step(6), 0.3); doum(step(8), 0.5); tek(step(12), 0.32); for (const s of [3, 5, 10, 14, 15]) ka(step(s), 0.13); }
    if (w.perc === "frame") { for (const s of [0, 3, 6, 8, 11, 14]) { nz(G, step(s), "lowpass", 260, 1, P, s % 8 === 0 ? 0.6 : 0.32, 0.14); nz(G, step(s), "bandpass", 2900, 1.2, P, 0.2, 0.04); } }
    if (w.perc === "china") { for (const s of [0, 4, 8, 12, 14]) { osc(G, step(s), "sine", 920, P, 0.001, 0.26, 0.05); osc(G, step(s), "sine", 1860, P, 0.001, 0.08, 0.03); } nz(G, step(8), "bandpass", 6800, 0.9, P, 0.3, 0.42); }
    if (w.perc === "taiko") {
      for (const s of [0, 7, 8]) { const ts = step(s), o = osc(G, ts, "sine", 78, P, 0.003, s === 0 ? 0.85 : 0.55, 0.5); o.frequency.exponentialRampToValueAtTime(52, ts + 0.3); nz(G, ts, "lowpass", 320, 1, P, 0.3, 0.16); }
      for (const s of [4, 12]) nz(G, step(s), "bandpass", 2600, 3, P, 0.2, 0.03);
      for (const s of [2, 6, 10, 14]) bell(G, step(s), 90, 0.1, P, 0.14, [[1, 1], [2.4, 0.5], [3.9, 0.3]]);
    }
    if (w.perc === "kendang") {
      for (const s of [0, 5, 8, 13]) { const ts = step(s), o = osc(G, ts, "sine", 150, P, 0.002, 0.42, 0.2); o.frequency.exponentialRampToValueAtTime(95, ts + 0.1); }
      for (const s of [4, 12]) nz(G, step(s), "bandpass", 2700, 1.6, P, 0.32, 0.05);
    }
    if (fill) {
      for (let s = 8; s < 16; s++) {
        const v = 0.15 + 0.4 * (s - 8) / 8, ts = step(s);
        if (w.perc === "darbuka") (s % 2 ? tek : doum)(ts, v);
        else if (w.perc === "taiko") { const o = osc(G, ts, "sine", 82, P, 0.003, v * 1.2, 0.3); o.frequency.exponentialRampToValueAtTime(55, ts + 0.2); }
        else if (w.perc === "china") osc(G, ts, "sine", 900 + (s - 8) * 40, P, 0.001, v * 0.8, 0.05);
        else if (w.perc === "kendang") { const o = osc(G, ts, "sine", 160, P, 0.002, v, 0.15); o.frequency.exponentialRampToValueAtTime(100, ts + 0.08); }
        else nz(G, ts, "lowpass", 300, 1, P, v * 1.1, 0.12);
      }
    }
  };

  // ── 바닥음 · 베이스 · 받침 음 ──
  E.pad = function (G, w, t, bars, level) {
    const notes = [48, 55, 60, 48 + deg(w.scale, 2) + (deg(w.scale, 2) < 3 ? 12 : 0)];
    const dur = bars * G.bar;
    notes.forEach((m, i) => {
      for (const det of [-7, 0, 7]) {
        const o = G.c.createOscillator(); o.type = "sawtooth"; o.frequency.value = hz(m); o.detune.value = det + (rnd() - 0.5) * 3;
        const f = G.c.createBiquadFilter(); f.type = "lowpass"; f.frequency.setValueAtTime(900, t); f.frequency.linearRampToValueAtTime(2800, t + dur * 0.5); f.frequency.linearRampToValueAtTime(1200, t + dur);
        const p = G.c.createStereoPanner(); p.pan.value = det === 0 ? 0 : (det < 0 ? -0.85 : 0.85);
        o.connect(f); f.connect(p); p.connect(sus(G, t, G.pad, 0.35, (i === 3 ? 0.05 : 0.08) * level, dur - 0.35, 0.5));
        o.start(t); o.stop(t + dur + 0.6);
      }
    });
  };
  E.drone = function (G, t, bars) {
    const dur = bars * G.bar;
    for (const [m, typ, v] of [[36, "sine", 0.22], [36, "sawtooth", 0.08], [43, "sawtooth", 0.05]]) {
      const o = G.c.createOscillator(); o.type = typ; o.frequency.value = hz(m);
      const f = G.c.createBiquadFilter(); f.type = "lowpass"; f.frequency.value = 240;
      o.connect(f); f.connect(sus(G, t, G.bass, 0.08, v, dur - 0.1, 0.12)); o.start(t); o.stop(t + dur + 0.3);
    }
  };
  E.riff = function (G, w, t) {
    const seq = [36, 43, 36, 36 + w.sixth - 12];
    for (let b = 0; b < 4; b++) {
      for (const off of [0, 2]) {
        const ts = t + b * G.beat + off * G.s16, m = seq[b] + (off ? 12 : 0);
        const o = G.c.createOscillator(); o.type = "sawtooth"; o.frequency.value = hz(m);
        const sub = G.c.createOscillator(); sub.type = "sine"; sub.frequency.value = hz(m - (off ? 12 : 0));
        const f = G.c.createBiquadFilter(); f.type = "lowpass"; f.Q.value = 4; f.frequency.setValueAtTime(900, ts); f.frequency.exponentialRampToValueAtTime(160, ts + 0.22);
        const e = env(G, ts, G.bass, 0.003, off ? 0.22 : 0.42, 0.3);
        o.connect(f); f.connect(e); const sg = G.c.createGain(); sg.gain.value = off ? 0 : 1.4; sub.connect(sg); sg.connect(e);
        o.start(ts); sub.start(ts); o.stop(ts + 0.4); sub.stop(ts + 0.4);
      }
    }
  };
  E.ost = function (G, t, level) {
    for (let e = 0; e < 8; e++) {
      const ts = t + e * 2 * G.s16 + hum(G), v = (e % 2 ? 0.55 : 0.85) * level * (0.9 + rnd() * 0.2);
      osc(G, ts, "sine", hz(67), G.ost, 0.002, v, 0.22); osc(G, ts, "sine", hz(67) * 3, G.ost, 0.001, v * 0.3, 0.07); osc(G, ts, "sine", hz(67) * 4, G.ost, 0.001, v * 0.2, 0.05); nz(G, ts, "bandpass", 4200, 2, G.ost, v * 0.35, 0.012);
    }
  };
  // 선율 2마디 (half: 0 = 앞 마디, 1 = 뒤 마디)
  E.melody = function (G, w, t, half, vel, kind) {
    for (const [p, d, l] of MAIN) {
      if (Math.floor(p / 16) !== half) continue;
      E.inst(G, kind || w.lead, t + (p % 16) * G.s16 + hum(G) * 0.5, 72 + deg(w.scale, d) - 12, vel * (0.85 + rnd() * 0.25), l * G.s16 * 1.1, G.lead);
    }
  };
  E.counterLine = function (G, w, t, half, vel) {
    for (const [p, d, l] of COUNTER) {
      if (Math.floor(p / 16) !== half) continue;
      E.inst(G, w.counter, t + (p % 16) * G.s16 + hum(G) * 0.5, 72 + deg(w.scale, d) - 12, vel * (0.85 + rnd() * 0.25), l * G.s16 * 1.2, G.counter);
    }
  };
  E.sparkle = function (G, w, t, density) {
    for (let e = 0; e < 8; e++) if (rnd() < density) bell(G, t + e * 2 * G.s16 + G.s16 * (rnd() < 0.5 ? 0 : 1), 84 + deg(w.scale, Math.floor(rnd() * 5)), 0.06, G.fx, 0.6, [[1, 1], [3.0, 0.2]]);
  };
  // 라이저: 걸러진 바람 소리가 차오름 (dur초 동안) · 임팩트: 낮은 쿵 + 울림
  E.riser = function (G, t, dur, peak) {
    const s = G.c.createBufferSource(); s.buffer = G.noise; s.loop = true;
    const f = G.c.createBiquadFilter(); f.type = "bandpass"; f.Q.value = 2.5; f.frequency.setValueAtTime(350, t); f.frequency.exponentialRampToValueAtTime(7000, t + dur);
    const g = G.c.createGain(); g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(peak, t + dur * 0.97); g.gain.linearRampToValueAtTime(0.0001, t + dur);
    s.connect(f); f.connect(g); g.connect(G.fx); s.start(t); s.stop(t + dur + 0.05);
    const o = G.c.createOscillator(); o.type = "sine"; o.frequency.setValueAtTime(hz(55), t); o.frequency.exponentialRampToValueAtTime(hz(79), t + dur);
    const og = G.c.createGain(); og.gain.setValueAtTime(0.0001, t); og.gain.exponentialRampToValueAtTime(peak * 0.25, t + dur * 0.97); og.gain.linearRampToValueAtTime(0.0001, t + dur);
    o.connect(og); og.connect(G.fx); o.start(t); o.stop(t + dur + 0.05);
  };
  // 막기 소리: 거친 현·활 소리 대신 부드러운 말렛(칼림바 같은) 한 음. 그 나라 음계 음만 쓰고, 뜯는 악기 나라면 그 악기 색을 아주 살짝 섞음
  E.parryVoice = function (G, w, t, midi, vel) {
    const f = hz(midi), lp = G.c.createBiquadFilter(); lp.type = "lowpass"; lp.frequency.value = 2600; lp.Q.value = 0.5; lp.connect(G.parry);
    osc(G, t, "sine", f, lp, 0.004, vel, 0.55);
    osc(G, t, "sine", f * 2, lp, 0.003, vel * 0.16, 0.2);
    osc(G, t, "sine", f * 4.01, lp, 0.002, vel * 0.05, 0.07);
    if (w.lead === "oud" || w.lead === "koto" || w.lead === "bonang") E.inst(G, w.lead, t, midi - 12, vel * 0.16, G.s16 * 2, lp);
  };
  E.thud = function (G, t) { nz(G, t, "lowpass", 260, 1, G.fx, 0.6, 0.12); osc(G, t, "square", 90, G.fx, 0.002, 0.1, 0.08); };
  E.impact = function (G, t, v) {
    const o = G.c.createOscillator(); o.type = "sine"; o.frequency.setValueAtTime(90, t); o.frequency.exponentialRampToValueAtTime(34, t + 0.6);
    o.connect(env(G, t, G.fx, 0.003, v, 1.4)); o.start(t); o.stop(t + 1.5);
    nz(G, t, "lowpass", 1200, 0.7, G.fx, v * 0.5, 0.9);
    bell(G, t, 43, v * 0.25, G.fx, 2.5);
  };

  // ── 다섯 나라 한 곡: 앞 절반(킥 1·3) → 드럼 빔 + 라이저 → 뒤 절반(킥 4박 · 베이스 반복 · 부선율 · 반짝이) → 다섯 섞임 ──
  E.SECTIONS = [];
  E.scheduleTrack = function (G, t0, onWorld) {
    E.reseed(777);
    const B = G.bar, sec = [];
    let t = t0;
    E.ORDER.forEach((id, i) => {
      const w = E.WORLDS[id];
      sec.push({ t: t, world: id, part: "앞 절반" });
      E.pad(G, w, t, 2, 0.9); E.drone(G, t, 2);
      for (let h = 0; h < 2; h++) {
        const tb = t + h * B;
        E.groove(G, tb, "A", i > 0 ? 1 : 0); E.ost(G, tb, i > 0 ? 1 : 0.6); E.melody(G, w, tb, h, 0.8); E.sparkle(G, w, tb, 0.12);
        const nxt = E.WORLDS[E.ORDER[(i + 1) % 5]];
        E.perc(G, h === 1 && i < 4 ? nxt : w, tb, h === 1 && i < 4);
      }
      t += 2 * B;
    });
    // 드럼 빔 2마디: 킥 없음, 바닥음 · 받침 음 · 선율만, 둘째 마디 라이저
    const wb = E.WORLDS.degung;
    sec.push({ t: t, world: "degung", part: "드럼 빔" });
    E.pad(G, wb, t, 2, 1.1); E.drone(G, t, 2); E.ost(G, t, 0.5); E.ost(G, t + B, 0.7);
    E.groove(G, t, "break", 0); E.groove(G, t + B, "break", 0);
    E.melody(G, wb, t, 0, 0.6, "suling"); E.melody(G, wb, t + B, 1, 0.6, "suling");
    E.riser(G, t + B, B, 0.5); E.perc(G, E.WORLDS.hijaz, t + B, true);
    t += 2 * B;
    E.impact(G, t, 0.8);
    E.ORDER.forEach((id, i) => {
      const w = E.WORLDS[id];
      sec.push({ t: t, world: id, part: "뒤 절반" });
      E.pad(G, w, t, 2, 1.0);
      for (let h = 0; h < 2; h++) {
        const tb = t + h * B;
        E.groove(G, tb, "B", 1); E.riff(G, w, tb); E.ost(G, tb, 0.9);
        E.melody(G, w, tb, h, 0.85); E.counterLine(G, w, tb, h, 0.7); E.sparkle(G, w, tb, 0.3);
        const nxt = E.WORLDS[E.ORDER[(i + 1) % 5]];
        E.perc(G, h === 1 && i < 4 ? nxt : w, tb, h === 1 && i < 4);
        if (h === 1 && i < 4) E.riser(G, tb + B * 0.5, B * 0.5, 0.22);
      }
      t += 2 * B;
    });
    // 다섯 섞임 4마디: 한 박마다 다른 나라 악기가 선율을 이어받음, 타악기 겹침
    sec.push({ t: t, world: "mix", part: "다섯 섞임" });
    E.WORLDS.mix = E.WORLDS.mix || { name: "다섯 섞임", where: "모든 나라", scale: [0, 1, 2, 3, 4, 5, 7, 8, 9, 10], color: "#ffffff", leadName: "다섯 악기", counterName: "", percName: "모두" };
    for (let b = 0; b < 4; b++) {
      const tb = t + b * B;
      E.groove(G, tb, "B", 1); E.riff(G, E.WORLDS.hijaz, tb); E.ost(G, tb, 1);
      E.perc(G, E.WORLDS[E.ORDER[b % 5]], tb, false); E.perc(G, E.WORLDS[E.ORDER[(b + 2) % 5]], tb, false);
      if (b % 2 === 0) E.pad(G, E.WORLDS[E.ORDER[b]], tb, 2, 1.0);
      for (const [p, d, l] of MAIN) {
        if (Math.floor(p / 16) !== b % 2) continue;
        const w = E.WORLDS[E.ORDER[(Math.floor((p % 16) / 4) + b) % 5]];
        E.inst(G, w.lead, tb + (p % 16) * G.s16, 72 + deg(w.scale, d) - 12, 0.8, l * G.s16, G.lead);
      }
      E.sparkle(G, E.WORLDS.degung, tb, 0.45);
    }
    t += 4 * B;
    E.impact(G, t, 0.9);
    for (const id of E.ORDER) E.inst(G, E.WORLDS[id].lead, t + rnd() * 0.03, 72, 0.5, G.bar, G.lead);
    sec.push({ t: t, world: "mix", part: "끝" });
    E.SECTIONS = sec;
    return t + 3;
  };
  return E;
})();
