// 오르시아 전투 음악 엔진 (WebAudio). 실시간 재생과 오프라인 렌더링(소리 굽기)이 같은 함수를 쓴다.
// 일곱 세계 모두 도·솔을 가져서, 끊기지 않는 공통 바닥음(C·G) 위에서 적이 바뀔 때마다 이어 넘어간다
window.E = (function () {
  const E = {};
  E.NAMES = ["도", "레♭", "레", "미♭", "미", "파", "파#", "솔", "라♭", "라", "시♭", "시"];
  // mel: 앞 악기 2마디 [16분 자리, C4에서 반음, 길이] · ctr: 맞받는 선율 [자리, C5에서, 길이] · riff: 베이스 [자리, C2에서, 길이]
  E.WORLDS = {
    gye: {
      name: "계면", where: "한국", scale: [0, 3, 5, 7, 10], color: "#ec6a4f", orn: "gye",
      lead: "gayageum", counter: "daegeum", perc: "janggu", bed: "saeng", spark: "pungyeong", parry: "gayageum",
      leadName: "가야금", counterName: "대금", percName: "장구", bedName: "생황풍 화음", sparkName: "풍경",
      bright: 0.5, dens: 0.55, swing: 0.06, bedTones: [0, 7, 12, 15],
      mel: [[0, 7, 4], [4, 10, 1], [5, 12, 1], [6, 10, 2], [8, 7, 3], [11, 5, 1], [12, 3, 4],
            [16, 0, 3], [19, 3, 1], [20, 5, 2], [22, 7, 2], [24, 5, 1], [25, 3, 3], [28, 0, 4]],
      ctr: [[2, 7, 6], [10, 10, 2], [12, 12, 4], [18, 10, 4], [22, 7, 3], [26, 3, 6]],
      riff: [[0, 0, 3], [3, 0, 1], [6, 7, 3], [9, 7, 1], [12, 10, 2], [14, 5, 2]],
    },
    lyd: {
      name: "리디안", where: "유리 하늘", scale: [0, 2, 4, 6, 7, 9, 11], color: "#8fd8ff", orn: null,
      lead: "glassharp", counter: "handpan", perc: "handdrum", bed: "glass", spark: "glint", parry: "handpan",
      leadName: "유리 하프", counterName: "핸드팬", percName: "손북", bedName: "유리 공명", sparkName: "유리 반짝임",
      bright: 0.85, dens: 0.3, swing: 0, bedTones: [0, 7, 14, 18],
      mel: [[0, 4, 6], [6, 6, 2], [8, 7, 8], [16, 11, 4], [20, 9, 2], [22, 6, 2], [24, 7, 8]],
      ctr: [[2, 0, 2], [4, 7, 2], [7, 4, 1], [10, 11, 2], [14, 6, 2], [18, 0, 2], [20, 9, 2], [23, 7, 1], [26, 4, 2], [30, 2, 2]],
      riff: [[0, 0, 4], [6, 7, 2], [8, 0, 2], [11, 6, 1], [12, 7, 4]],
    },
    tez: {
      name: "테제타", where: "에티오피아", scale: [0, 2, 3, 7, 8], color: "#e2b04a", orn: null,
      lead: "krar", counter: "masenqo", perc: "kebero", bed: "warm", spark: "tsenatsel", parry: "krar",
      leadName: "크라르", counterName: "마센코", percName: "케베로 북", bedName: "따뜻한 현", sparkName: "체나첼 방울",
      bright: 0.55, dens: 0.8, swing: 0.2, bedTones: [0, 7, 15, 20],
      mel: [[0, 0, 2], [2, 7, 1], [3, 8, 1], [4, 7, 2], [6, 3, 2], [8, 2, 1], [9, 3, 1], [10, 7, 2], [12, 12, 2], [14, 8, 2],
            [16, 7, 2], [18, 3, 2], [20, 2, 1], [21, 3, 1], [22, 2, 2], [24, 0, 3], [27, -5, 1], [28, -4, 2], [30, -5, 2]],
      ctr: [[2, 3, 4], [6, 2, 2], [8, 0, 6], [18, 8, 4], [22, 7, 2], [24, 3, 4], [28, 2, 4]],
      riff: [[0, 0, 3], [3, 0, 1], [4, 7, 2], [6, 8, 2], [8, 7, 3], [11, 3, 1], [12, 0, 2], [14, -5, 2]],
    },
    bhv: {
      name: "바이라브", where: "인도", scale: [0, 1, 4, 5, 7, 8, 11], color: "#3fc9a0", orn: "bhv",
      lead: "sitar", counter: "bansuri", perc: "tabla", bed: "tanpura", spark: "manjira", parry: "sitar",
      leadName: "시타르", counterName: "반수리", percName: "타블라", bedName: "탄푸라", sparkName: "만지라",
      bright: 0.6, dens: 0.65, swing: 0.04, bedTones: [7, 12, 12, 0],
      mel: [[0, 0, 2], [2, 1, 4], [6, 0, 2], [8, 4, 2], [10, 5, 2], [12, 7, 4],
            [16, 8, 4], [20, 7, 2], [22, 5, 1], [23, 4, 1], [24, 5, 2], [26, 1, 3], [29, 0, 3]],
      ctr: [[4, 1, 4], [8, 0, 4], [18, 8, 4], [22, 7, 6], [30, 11, 2]],
      riff: [[0, 0, 4], [4, 7, 2], [6, 8, 2], [8, 7, 4], [12, 1, 2], [14, 0, 2]],
    },
    hun: {
      name: "헝가리 단조", where: "초원 너머", scale: [0, 2, 3, 6, 7, 8, 11], color: "#d0609f", orn: null, esztam: true,
      lead: "cimbalom", counter: "violin", perc: "frame", bed: "strings", spark: "cimb", parry: "cimbalom",
      leadName: "침발롬", counterName: "바이올린", percName: "프레임 북", bedName: "현악 받침", sparkName: "침발롬 잔음",
      bright: 0.65, dens: 0.75, swing: 0, bedTones: [0, 7, 11, 15],
      mel: [[0, -5, 2], [2, -4, 1], [3, -5, 1], [4, -6, 2], [6, -5, 2], [8, -1, 1], [9, 0, 1], [10, 2, 2], [12, 3, 4],
            [16, 2, 2], [18, 0, 2], [20, -1, 2], [22, -4, 2], [24, -5, 6], [30, -6, 2]],
      ctr: [[0, 7, 4], [4, 8, 2], [6, 11, 2], [8, 12, 6], [14, 11, 2], [16, 8, 4], [20, 7, 4], [24, 6, 4], [28, 7, 4]],
      riff: [[0, 0, 2], [4, 7, 2], [8, 0, 2], [12, -5, 2]],
    },
    mac: {
      name: "기계", where: "정거장", scale: [0, 2, 3, 5, 7, 8, 10], color: "#a7b6c8", orn: null,
      lead: "chip", counter: "steelpan", perc: "metal", bed: "pulse", spark: "bleep", parry: "steelpan",
      leadName: "칩 사각파", counterName: "강철 팬", percName: "금속 타악", bedName: "전원 웅웅", sparkName: "삑 소리",
      bright: 0.7, dens: 0.9, swing: 0, bedTones: [0, 7, 10, 15],
      mel: [[0, 0, 2], [2, 7, 1], [3, 3, 1], [4, 0, 2], [6, 10, 2], [8, 8, 1], [9, 7, 1], [10, 5, 2], [12, 3, 1], [13, 2, 1], [14, 3, 2],
            [16, 7, 3], [19, 8, 1], [20, 7, 2], [22, 3, 2], [24, 0, 4], [28, -2, 2], [30, -5, 2]],
      ctr: [[2, 0, 2], [6, 3, 2], [10, 7, 2], [14, 5, 2], [18, 3, 2], [22, 0, 2], [26, 2, 2], [30, -2, 2]],
      riff: [[0, 0, 2], [2, 12, 1], [4, 0, 2], [6, 12, 1], [8, 8, 2], [10, 20, 1], [12, 7, 2], [14, 19, 1]],
    },
    core: {
      name: "핵", where: "균열 한가운데", scale: [0, 1, 3, 4, 6, 7, 9, 10], color: "#b28cff", orn: null,
      lead: "glassbell", counter: "tremble", perc: "heart", bed: "choir", spark: "shard", parry: "glassbell",
      leadName: "유리종", counterName: "떠는 합성음", percName: "심장 북", bedName: "낮은 합창", sparkName: "유리 조각",
      bright: 0.35, dens: 0.5, swing: 0, bedTones: [0, 7, 10, 16],
      mel: [[0, 0, 6], [6, 6, 2], [8, 3, 4], [12, 1, 4], [16, 4, 6], [22, 10, 2], [24, 9, 4], [28, 7, 4]],
      ctr: [[0, 6, 8], [8, 7, 8], [16, 3, 8], [24, 4, 8]],
      riff: [[0, 0, 6], [6, 6, 2], [8, 7, 6], [14, 1, 2]],
    },
  };
  E.ORDER = ["gye", "lyd", "tez", "bhv", "hun", "mac", "core"];
  for (const id of E.ORDER) E.WORLDS[id].id = id;

  // 메아리: 바로 앞 세계를 흉내. 같은 악기·음계지만 앞 악기가 8분 늦게 따라 부르고, 음은 살짝 낮게 들어갔다가 맞춰 감
  const echoes = {};
  E.echoOf = function (baseId) {
    const b = E.WORLDS[baseId] || E.WORLDS.gye;
    if (!echoes[b.id]) echoes[b.id] = Object.assign({}, b, {
      id: "echo", base: b, mirror: true, name: "메아리", where: b.name + " 흉내",
      color: mix(b.color, "#d8d4e4", 0.55), bright: b.bright * 0.75,
    });
    return echoes[b.id];
  };
  function mix(a, b, k) {
    const p = h => [1, 3, 5].map(i => parseInt(h.slice(i, i + 2), 16)), x = p(a), y = p(b);
    return "#" + x.map((v, i) => Math.round(v + (y[i] - v) * k).toString(16).padStart(2, "0")).join("");
  }

  // 적 → 세계 (게임 P2Catalog.ENEMIES 열쇠)
  E.ENEMY_WORLD = {
    scout: "gye", scout_h: "gye",
    archer: "lyd", archer_h: "lyd",
    breaker: "tez", guard_h: "tez", elite: "tez", maek_elite_low: "tez", leader: "tez",
    hexer: "bhv", poisoner: "bhv",
    shieldbearer: "hun", banner: "hun", boss: "hun", hard_boss: "hun", maek_noble_mid: "hun", ruins_boss: "hun",
    cannon: "mac", curse: "mac",
    x_boss: "core",
    maek_summoner_low: "echo", mimic_n: "echo", mimic_h: "echo", mimic_x: "echo",
  };

  // 전투가 무르익을수록 얹히는 겹(쌓이는 순서, 들어오는 진행도 = 적 체력을 깎은 비율). 게임 P2Music.PARTS와 같음
  E.PARTS = [["hat", "하이햇", 0.1], ["perc", "세계 타악", 0.25], ["kick4", "킥 4박", 0.4], ["bass", "베이스", 0.55], ["counter", "맞받는 선율", 0.7], ["spark", "반짝이", 0.85]];
  E.earnedFor = x => E.PARTS.filter(p => x >= p[2] - 1e-6).length;

  // 음악에서 뽑은 막기 악보: 8마디 고리의 slot번째 마디(변주 slot>>1의 앞 · 뒤 마디)에서 실제로 울리는 소리를 노트로.
  // 앞 악기 선율 음이 뼈대이고, tier(0 일반 · 1 심층 · 2 정예 · 3 보스)가 오를수록 짧은 꾸밈음 → 맞받는 선율 → 킥 → 세계 타악까지 더한다
  // (등급마다 적어도 TIER_MIN개가 되도록 채움. 게임은 이 공격 동안 쓰인 겹을 켜서 노트마다 들리는 소리가 있게 한다).
  // 노트마다 { b 박 자리, semi 막기 음(C5 기준 반음, 선율 음의 한 옥타브 위), len 16분 길이, src lead|counter|kick|perc }
  E.TIER_MIN = [4, 6, 7, 9];
  E.TIER_CAP = [6, 8, 10, 12];
  E.chartBar = function (w, slot, tier) {
    const v = slot >> 1, half = slot & 1, sw = w.swing || 0, at = s => (s + (s % 2 ? sw : 0)) / 4, lag = w.mirror ? 2 : 0;
    const lead = [];
    for (const [p, semi, len] of E.phrase(w, v)) {
      if (Math.floor(p / 16) !== half || p % 16 + lag >= 16) continue;
      let pitch = semi + (v === 3 && half === 0 ? 12 : 0);
      while (pitch > 19) pitch -= 12;
      lead.push({ b: at(p % 16 + lag), semi: pitch, len: len, src: "lead" });
    }
    const near = (list, b, d) => list.some(n => Math.abs(n.b - b) < d - 1e-6);
    let out = [];
    if (tier === 0) { for (const n of lead) if ((n.len >= 2 || !out.length) && !near(out, n.b, 0.5)) out.push(n); }
    else out = lead.slice();
    const add = (list, d, acc) => { for (const n of list) if ((n.acc || 1) >= acc && !near(out, n.b, d)) out.push(n); };
    const short = () => out.length < E.TIER_MIN[tier];
    if (tier >= 2 || short()) add(w.ctr.filter(([p]) => Math.floor(p / 16) === half).map(([p, semi, len]) => ({ b: at(p % 16), semi: semi, len: len, src: "counter" })), 0.45, 0);
    if (tier >= 2 || short()) add([{ b: 0, semi: 0, len: 2, src: "kick" }, { b: 2, semi: -5, len: 2, src: "kick" }], 0.45, 0);
    if (tier >= 3 || short()) {
      const kit = KIT[w.perc], tail = half === 1 && v % 2 === 1, perc = [];
      for (const [s, , a] of kit.pat) if (!(tail && s >= 12)) perc.push({ b: at(s), semi: a >= 0.7 ? 7 : 12, len: 1, src: "perc", acc: a });
      if (tail) for (const [f, , a] of kit.fill) perc.push({ b: 3 + f, semi: 12, len: 1, src: "perc", acc: a });
      add(perc, 0.24, short() ? 0.15 : 0.45);
    }
    out.sort((x, y) => x.b - y.b);
    const weight = n => n.src === "kick" ? 3 : n.src === "perc" ? n.acc : (n.src === "counter" ? 0.8 : 1) + n.len / 4 + (Number.isInteger(n.b) ? 0.5 : 0);
    while (out.length > E.TIER_CAP[tier]) {
      let k = 1;
      for (let i = 2; i < out.length; i++) if (weight(out[i]) < weight(out[k])) k = i;
      out.splice(k, 1);
    }
    return out.map(n => ({ b: n.b, semi: n.semi, len: n.len, src: n.src }));
  };
  // 솎기: 서로 gap박보다 가까운 음은 센 자리(2 · 4박 > 정박 > 반 박 > 그 밖, 같으면 앞 악기 · 앞 음) 하나만. 화살 · 피하기는 손이 따라갈 만큼 듬성하게
  E.thin = function (notes, gap) {
    const on = (b, q) => Math.abs(b / q - Math.round(b / q)) < 1e-3;
    const st = n => (on(n.b, 2) ? 4 : on(n.b, 1) ? 3 : on(n.b, 0.5) ? 2 : 1) + (n.src === "lead" ? 0.5 : 0);
    const keep = [];
    for (const n of notes.slice().sort((x, y) => st(y) - st(x) || x.b - y.b)) if (!keep.some(k => Math.abs(k.b - n.b) < gap - 1e-6)) keep.push(n);
    return keep.sort((x, y) => x.b - y.b);
  };

  // 북 장단 악보(북으로 막는 적): 그 마디 북 소리 그대로. 킥(1 · 3박)과 세계 타악의 낮은 소리 = 둥(막기 음 0), 높은 소리 = 딱(7 · 12).
  // 등급이 오를수록 약한 타악 → 2 · 4박 킥(킥 4박 겹) → 꼬리 마디(변주 둘째 마디) 마지막 박 필인 = 노랑 길게(필인 타는 누르는 동안 저절로)
  E.DRUM_MIN = [4, 5, 6, 7];
  E.DRUM_CAP = [5, 7, 9, 11];
  const LOW = new Set(["deong", "kung", "bass", "dum", "dha", "ge", "dhin", "lub", "dub", "clank", "tone"]);
  E.drumBar = function (w, slot, tier) {
    const v = slot >> 1, half = slot & 1, sw = w.swing || 0, at = s => (s + (s % 2 ? sw : 0)) / 4;
    const kit = KIT[w.perc], tail = half === 1 && v % 2 === 1 && tier >= 1;
    const out = [{ b: 0, semi: 0, len: 4, src: "kick", w: 9 }, { b: 2, semi: 0, len: 4, src: "kick", w: 9 }];
    if (tier >= 2) for (const b of tail ? [1] : [1, 3]) out.push({ b: b, semi: 0, len: 4, src: "kick4", w: 2 });
    const gap = tier === 0 ? 0.5 : 0.25, base = out.length;
    // 센 타부터 넣되 등급 최소 수에 못 미치면 더 약한 타까지
    for (let minAcc = [0.6, 0.45, 0.3, 0][tier]; ; minAcc -= 0.15) {
      out.length = base;
      for (const [s, nm, a] of kit.pat) {
        const b = at(s);
        if (a < minAcc || (tail && s >= 12) || out.some(n => Math.abs(n.b - b) < gap - 1e-6)) continue;
        out.push({ b: b, semi: LOW.has(nm) ? 0 : a >= 0.6 ? 7 : 12, len: 1, src: "perc", w: a });
      }
      if (out.length >= E.DRUM_MIN[tier] - (tail ? 1 : 0) || minAcc <= 0) break;
    }
    while (out.length > E.DRUM_CAP[tier]) {
      let k = -1;
      for (let i = 0; i < out.length; i++) if (out[i].src !== "kick" && (k < 0 || out[i].w < out[k].w)) k = i;
      out.splice(k, 1);
    }
    if (tail) {
      out.push({ b: 3, semi: 7, len: 3, src: "roll" });
      for (const [f] of kit.fill) if (f > 0 && f < 0.75) out.push({ b: 3 + f, semi: 12, len: 1, src: "rollhit" });
    }
    return out.sort((x, y) => x.b - y.b).map(n => ({ b: n.b, semi: n.semi, len: n.len, src: n.src }));
  };


  let seed = 12345;
  function rnd() { seed = (seed * 1103515245 + 12345) & 0x7fffffff; return seed / 0x7fffffff; }
  E.reseed = function (s) { seed = s; };
  function hz(m) { return 440 * Math.pow(2, (m - 69) / 12); }
  function hum(ms) { return (rnd() - 0.5) * ms / 500; }
  function vary(v, k) { return v * (1 - k + rnd() * 2 * k); }
  function sw(G, w, s) { return s % 2 === 1 ? (w.swing || 0) * G.s16 : 0; }

  // bake: 굽기용(겹마다 따로 렌더해 게임에서 더하므로 압축 · 깎기 없이 선형으로, 여유 있게 작게)
  E.build = function (c, bpm, bake) {
    const G = { c: c, bpm: bpm || 124, ks: {}, ducks: [], buses: {}, waves: {}, width: 0.5 };
    G.beat = 60 / G.bpm; G.s16 = G.beat / 4; G.bar = G.beat * 4;
    G.master = c.createGain(); G.master.gain.value = bake ? 0.42 : 0.56;
    const tilt = c.createBiquadFilter(); tilt.type = "highshelf"; tilt.frequency.value = 6500; tilt.gain.value = -2.5;
    const comp = c.createDynamicsCompressor(); comp.threshold.value = -15; comp.knee.value = 10; comp.ratio.value = 2.5; comp.attack.value = 0.012; comp.release.value = 0.22;
    const clip = c.createWaveShaper(), cv = new Float32Array(2048);
    for (let i = 0; i < 2048; i++) { const x = i / 1023.5 - 1; cv[i] = Math.tanh(1.15 * x) / Math.tanh(1.15); }
    clip.curve = cv;
    const out = c.createGain(); out.gain.value = 0.92;
    if (bake) { G.master.connect(tilt); tilt.connect(out); } else { G.master.connect(tilt); tilt.connect(comp); comp.connect(clip); clip.connect(out); }
    out.connect(c.destination);
    // 울림: 짧은 초기 반사 + 2.4초 꼬리(뒤로 갈수록 어두워짐), 좌우 따로
    const sr = c.sampleRate, len = Math.floor(sr * 2.4), ir = c.createBuffer(2, len, sr);
    for (let ch = 0; ch < 2; ch++) {
      const d = ir.getChannelData(ch); let lp = 0;
      for (let i = 0; i < len; i++) { const k = i / len; lp += (Math.random() * 2 - 1 - lp) * (0.5 - 0.42 * k); d[i] = lp * Math.pow(1 - k, 3.4) * Math.min(1, i / (sr * 0.012)); }
      for (const ms of [9, 17, 23, 31, 43]) { const k = Math.floor(sr * (ms + ch * 2.5) / 1000); d[k] += 0.35 * (Math.random() < 0.5 ? -1 : 1); }
    }
    G.rev = c.createConvolver(); G.rev.buffer = ir;
    const revHP = c.createBiquadFilter(); revHP.type = "highpass"; revHP.frequency.value = 170;
    const revLP = c.createBiquadFilter(); revLP.type = "lowpass"; revLP.frequency.value = 6000;
    const revOut = c.createGain(); revOut.gain.value = 0.5;
    G.rev.connect(revHP); revHP.connect(revLP); revLP.connect(revOut); revOut.connect(G.master);
    // 메아리 틈: 점8분 핑퐁
    G.dly = c.createGain();
    const dl = c.createDelay(2), dr = c.createDelay(2), fb = c.createGain(), dlp = c.createBiquadFilter();
    dl.delayTime.value = G.beat * 0.75; dr.delayTime.value = G.beat * 0.75; fb.gain.value = 0.32; dlp.type = "lowpass"; dlp.frequency.value = 2600;
    const pl = c.createStereoPanner(), pr = c.createStereoPanner(); pl.pan.value = -0.7; pr.pan.value = 0.7;
    const dOut = c.createGain(); dOut.gain.value = 0.45;
    G.dly.connect(dl); dl.connect(pl); pl.connect(dOut); dl.connect(dlp); dlp.connect(dr); dr.connect(pr); pr.connect(dOut); dr.connect(fb); fb.connect(dl);
    dOut.connect(G.master); dOut.connect(G.rev);
    // 음악 버스는 G.mus를 거쳐 마스터로(놓칠 때 휘청). 막기 음 · 놓침 소리는 곧장 마스터로
    G.mus = c.createGain(); G.musLP = c.createBiquadFilter(); G.musLP.type = "lowpass"; G.musLP.frequency.value = 18000; G.musLP.Q.value = 0.5;
    G.mus.connect(G.musLP); G.musLP.connect(G.master);
    G.gates = {}; G.gateOpen = {}; G.cutEnd = {};
    function bus(name, gain, rev, dly, o) {
      o = o || {};
      const g = c.createGain(); g.gain.value = gain;
      const mute = c.createGain(); mute.gain.value = 1;
      let tail = g;
      if (o.duck) { const dk = c.createGain(); g.connect(dk); tail = dk; G.ducks.push(dk.gain); }
      if (o.part) {
        const d = c.createDelay(1), lp = c.createBiquadFilter(), gg = c.createGain();
        d.delayTime.value = 0; lp.type = "lowpass"; lp.frequency.value = 18000; lp.Q.value = 0.7;
        tail.connect(d); d.connect(lp); lp.connect(gg); tail = gg;
        (G.gates[o.part] = G.gates[o.part] || []).push({ d: d, lp: lp, g: gg.gain }); G.gateOpen[o.part] = true;
      }
      tail.connect(mute); mute.connect(o.dry ? G.master : G.mus);
      if (rev) { const s = c.createGain(); s.gain.value = rev; mute.connect(s); s.connect(G.rev); }
      if (dly) { const s = c.createGain(); s.gain.value = dly; mute.connect(s); s.connect(G.dly); }
      (G.buses[name] = G.buses[name] || []).push(mute);
      return g;
    }
    G.kick = bus("kick", 0.7, 0, 0);
    G.kick4 = bus("kick", 0.7, 0, 0, { part: "kick4" });
    G.hat = bus("hat", 1, 0.1, 0, { part: "hat" });
    G.perc = bus("perc", 0.6, 0.2, 0.04, { part: "perc" });
    G.percEcho = bus("perc", 0.5, 0.3, 0.45, { part: "perc" });
    G.fill = bus("perc", 0.6, 0.2, 0.04);
    G.bass = bus("bass", 0.55, 0, 0, { duck: true, part: "bass" });
    G.droneBus = bus("drone", 0.11, 0.15, 0, { duck: true });
    G.bed = bus("bed", 0.32, 0.5, 0, { duck: true });
    G.lead = bus("lead", 0.5, 0.3, 0.12);
    G.mirror = bus("lead", 0.42, 0.45, 0.55);
    G.counter = bus("counter", 0.36, 0.42, 0.2, { duck: true, part: "counter" });
    G.spark = bus("fx", 0.45, 0.6, 0.2, { part: "spark" });
    G.fx = bus("fx", 0.45, 0.6, 0.2);
    G.parry = bus("parry", 0.62, 0.28, 0.06, { dry: true });
    G.parryEcho = bus("parry", 0.55, 0.32, 0.5, { dry: true });
    G.thudBus = bus("parry", 0.7, 0.06, 0, { dry: true });
    const nb = c.createBuffer(1, sr * 2, sr), nd = nb.getChannelData(0);
    for (let i = 0; i < nd.length; i++) nd[i] = Math.random() * 2 - 1;
    G.noise = nb;
    makeDrone(G);
    return G;
  };
  E.setMute = function (G, name, on) { for (const m of G.buses[name] || []) m.gain.setTargetAtTime(on ? 0 : 1, G.c.currentTime, 0.05); };

  // 공통 바닥음: 처음부터 끝까지 한 벌의 발진기라 세계가 바뀌어도 위상이 끊기지 않음
  function makeDrone(G) {
    const c = G.c, g = c.createGain(); g.gain.value = 0.0001; g.connect(G.droneBus);
    const lp = c.createBiquadFilter(); lp.type = "lowpass"; lp.frequency.value = 240; lp.Q.value = 0.5; lp.connect(g);
    const lfo = c.createOscillator(), lg = c.createGain(); lfo.frequency.value = 0.07; lg.gain.value = 70; lfo.connect(lg); lg.connect(lp.frequency); lfo.start();
    for (const [m, type, v, det] of [[36, "sine", 0.55, 0], [24, "sine", 0.12, 0], [43, "sine", 0.16, 1.5], [36, "sawtooth", 0.07, -3], [48, "triangle", 0.05, 2]]) {
      const o = c.createOscillator(); o.type = type; o.frequency.value = hz(m); o.detune.value = det;
      const gg = c.createGain(); gg.gain.value = v; o.connect(gg); gg.connect(lp); o.start();
    }
    G.droneLevel = g.gain;
  }
  E.droneTo = function (G, t, level) { G.droneLevel.setTargetAtTime(Math.max(0.0001, level), t, 0.3); };

  // ── 기본 조각 ──
  function env(G, t, out, a, peak, dec) {
    const n = G.c.createGain(); n.gain.setValueAtTime(0, t);
    n.gain.linearRampToValueAtTime(Math.max(0.0002, peak), t + a); n.gain.exponentialRampToValueAtTime(0.0001, t + a + dec);
    n.connect(out); return n;
  }
  function sus(G, t, out, a, peak, hold, rel) {
    const n = G.c.createGain(); n.gain.setValueAtTime(0, t);
    n.gain.linearRampToValueAtTime(Math.max(0.0002, peak), t + a); n.gain.setValueAtTime(Math.max(0.0002, peak), t + a + hold); n.gain.exponentialRampToValueAtTime(0.0001, t + a + hold + rel);
    n.connect(out); return n;
  }
  function osc(G, t, type, f, out, a, peak, dec) { const o = G.c.createOscillator(); o.type = type; o.frequency.value = f; o.connect(env(G, t, out, a, peak, dec)); o.start(t); o.stop(t + a + dec + 0.05); return o; }
  function nz(G, t, type, f, q, out, peak, dec, a) {
    const s = G.c.createBufferSource(), fl = G.c.createBiquadFilter(); s.buffer = G.noise; fl.type = type; fl.frequency.value = f; fl.Q.value = q;
    s.playbackRate.value = 0.9 + rnd() * 0.2;
    s.connect(fl); fl.connect(env(G, t, out, a || 0.002, peak, dec)); s.start(t, rnd() * 1.5); s.stop(t + (a || 0.002) + dec + 0.05); return fl;
  }
  function pan(G, out, p) { const n = G.c.createStereoPanner(); n.pan.value = Math.max(-1, Math.min(1, p)); n.connect(out); return n; }
  function lpf(G, out, f, q) { const n = G.c.createBiquadFilter(); n.type = "lowpass"; n.frequency.value = f; n.Q.value = q || 0.5; n.connect(out); return n; }
  function duck(G, t, depth) {
    for (const p of G.ducks) { p.cancelScheduledValues(t); p.setValueAtTime(1, t); p.linearRampToValueAtTime(depth, t + 0.015); p.setTargetAtTime(1, t + 0.05, 0.08); }
  }
  function drum(G, t, out, f0, f1, drop, v, dec) {
    const o = G.c.createOscillator(); o.type = "sine"; o.frequency.setValueAtTime(f0, t); o.frequency.exponentialRampToValueAtTime(f1, t + drop);
    o.connect(env(G, t, out, 0.002, v, dec)); o.start(t); o.stop(t + dec + 0.08); return o;
  }
  function partials(G, t, f, out, list, vel, a) {
    for (const [r, g, dec, beat] of list) {
      if (f * r > G.c.sampleRate * 0.45) continue;
      osc(G, t, "sine", f * r, out, a || 0.003, vel * g, dec);
      if (beat) osc(G, t, "sine", f * r + beat, out, a || 0.003, vel * g * 0.7, dec);
    }
  }

  // 뜯는 줄: 카플러스-스트롱. 같은 음도 세 가지로 번갈아(손으로 뜯은 듯 매번 조금 다름)
  function ks(G, midi, bright, decay, buzz, exc) {
    const v = Math.floor(rnd() * 3), key = [midi, bright, decay, buzz, exc, v].join(":");
    if (G.ks[key]) return G.ks[key];
    let s = 0;
    for (let i = 0; i < key.length; i++) s = (s * 31 + key.charCodeAt(i)) & 0x7fffffff;
    const r = () => { s = (s * 1103515245 + 12345) & 0x7fffffff; return s / 0x7fffffff * 2 - 1; };
    const sr = G.c.sampleRate, f = hz(midi), P = sr / f, a = 0.5 + 0.5 * bright;
    const D = P - (1 - a), N = Math.floor(D), fr = D - N;
    const len = Math.ceil(sr * decay), buf = G.c.createBuffer(1, len, sr), d = buf.getChannelData(0);
    const g = Math.pow(0.001, 1 / (f * decay));
    const ex = new Float32Array(N + 2); let lp = 0, mean = 0;
    for (let i = 0; i < N + 2; i++) { lp += (r() - lp) * (0.12 + 0.88 * exc); ex[i] = lp; mean += lp; }
    mean /= N + 2; let pk = 0;
    for (let i = 0; i < N + 2; i++) { ex[i] -= mean; pk = Math.max(pk, Math.abs(ex[i])); }
    for (let i = 0; i < N + 2; i++) ex[i] /= pk || 1;
    const th = 0.3;
    let px = 0;
    for (let i = 0; i < len; i++) {
      let y;
      if (i < N + 2) y = ex[i];
      else {
        const x = (1 - fr) * d[i - N] + fr * d[i - N - 1];
        y = g * (a * x + (1 - a) * px); px = x;
        if (buzz && y > th) y = th + (y - th) * (1 - buzz);
      }
      d[i] = y;
    }
    return (G.ks[key] = buf);
  }
  // 메아리 세계에서는 음이 살짝 낮게 들어갔다가 맞춰 감
  let dip = 0;
  function pitchMove(G, params, t, dur, o) {
    const stops = [], base = params.map(p => p.value);
    const at = (fn) => params.forEach((p, i) => fn(p, base[i]));
    const c0 = o.from !== undefined && o.from !== null ? (o.from - o.midi) * 100 : 0;
    if (c0 && Math.abs(c0) <= 700) at((p, b) => { p.setValueAtTime(b + c0, t); p.linearRampToValueAtTime(b, t + (o.slideT || 0.08)); });
    else if (dip) at((p, b) => { p.setValueAtTime(b + dip, t); p.linearRampToValueAtTime(b, t + 0.14); });
    else if (o.scoop) at((p, b) => { p.setValueAtTime(b - o.scoop, t); p.linearRampToValueAtTime(b, t + 0.07); });
    const lfo = (rate, depth, start, ramp) => {
      const l = G.c.createOscillator(), lg = G.c.createGain(); l.frequency.value = rate * (0.94 + rnd() * 0.12);
      lg.gain.setValueAtTime(0, t); lg.gain.setValueAtTime(0, t + start); lg.gain.linearRampToValueAtTime(depth, t + start + ramp);
      l.connect(lg); params.forEach(p => lg.connect(p)); l.start(t); l.stop(t + dur + 1); stops.push(l);
    };
    if (o.orn === "tremble") lfo(5.2, 42, 0.1, 0.22);
    else if (o.orn === "bend") {
      const h = Math.min(0.2, dur * 0.4);
      at((p, b) => { p.setValueAtTime(b, t + 0.02); p.linearRampToValueAtTime(b + 60, t + 0.08); p.setValueAtTime(b + 60, t + h); p.linearRampToValueAtTime(b - 100, t + h + 0.1); });
    } else if (o.orn === "andolan") { at((p, b) => p.setValueAtTime(b - 12, t + 0.1)); lfo(1.5, 26, 0.12, 0.3); }
    if (o.vib) lfo(o.vibHz || 5.5, o.vib, o.vibAt || 0.15, 0.2);
    return stops;
  }
  E.ornFor = function (w, midi, len) {
    const pc = ((midi % 12) + 12) % 12;
    if (w.orn === "gye") { if (pc === 7 && len >= 2) return "tremble"; if (pc === 3 && len >= 3) return "bend"; }
    if (w.orn === "bhv" && (pc === 1 || pc === 8) && len >= 3) return "andolan";
    return null;
  };
  function pluck(G, t, midi, vel, out, o) {
    const c = G.c, strings = o.strings || [0], sum = c.createGain(); sum.gain.value = 1 / Math.sqrt(strings.length);
    const hp = c.createBiquadFilter(); hp.type = "highpass"; hp.frequency.value = 45; sum.connect(hp);
    let last = hp;
    for (const [fq, gn] of (o.body || [])) { const pk = c.createBiquadFilter(); pk.type = "peaking"; pk.frequency.value = fq; pk.Q.value = 1.3; pk.gain.value = gn; last.connect(pk); last = pk; }
    const l = c.createBiquadFilter(); l.type = "lowpass"; l.frequency.value = o.cut || 6000; l.Q.value = 0.6; last.connect(l);
    l.connect(env(G, t, o.pan !== undefined ? pan(G, out, o.pan) : out, o.attack || 0.002, vel, o.decay * 1.6));
    const srcs = strings.map(cents => {
      const s = c.createBufferSource(); s.buffer = ks(G, midi, o.bright, o.decay, o.buzz || 0, o.exc === undefined ? 0.6 : o.exc);
      s.detune.value = cents + (o.detune || 0); s.connect(sum); s.start(t); s.stop(t + o.decay + 0.1); return s;
    });
    pitchMove(G, srcs.map(s => s.detune), t, o.decay, Object.assign({ midi: midi }, o));
  }
  function bowed(G, t, midi, vel, out, dur, o) {
    const c = G.c, f0 = hz(midi), voices = o.voices || [0], sum = c.createGain(); sum.gain.value = 1 / voices.length;
    const cents0 = voices.map(cents => cents + (rnd() - 0.5) * 4);
    const oscs = cents0.map(cents => { const v = c.createOscillator(); v.type = "sawtooth"; v.frequency.value = f0; v.detune.value = cents; v.connect(sum); return v; });
    const rel = o.rel || 0.14, end = t + dur + rel + 0.1;
    const st = pitchMove(G, oscs.map(v => v.detune), t, dur, Object.assign({ midi: midi }, o));
    if (o.sob && dur > 0.3) oscs.forEach((v, i) => { v.detune.setValueAtTime(cents0[i], t + dur - 0.08); v.detune.linearRampToValueAtTime(cents0[i] - 35, t + dur + rel); });
    let last = sum;
    for (const [type, fq, q, gn] of o.filters) { const fl = c.createBiquadFilter(); fl.type = type; fl.frequency.value = fq; fl.Q.value = q; if (gn !== undefined) fl.gain.value = gn; last.connect(fl); last = fl; }
    const a = o.attack || 0.06, dest = o.pan !== undefined ? pan(G, out, o.pan) : out;
    last.connect(sus(G, t, dest, a, vel, Math.max(0.01, dur - a), rel));
    oscs.forEach(v => { v.start(t); v.stop(end); });
    if (o.noise) nz(G, t, "bandpass", 2800, 1.1, dest, vel * o.noise, Math.min(dur, 0.3), 0.04);
    return st;
  }
  function flute(G, t, midi, vel, out, dur, o) {
    const c = G.c, f0 = hz(midi), sum = c.createGain();
    const parts = [["sine", 1, 1], ["triangle", 2, 0.1], ["sine", 3, 0.035]].map(([type, r, g]) => {
      const v = c.createOscillator(); v.type = type; v.frequency.value = f0 * r; const gg = c.createGain(); gg.gain.value = g; v.connect(gg); gg.connect(sum); return v;
    });
    pitchMove(G, parts.map(v => v.detune), t, dur, Object.assign({ midi: midi, scoop: 35, vib: o.vib || 14, vibHz: 4.8, vibAt: 0.18 }, o));
    const rel = 0.18, dest = o.pan !== undefined ? pan(G, out, o.pan) : out, e = sus(G, t, dest, 0.07, vel, Math.max(0.02, dur - 0.07), rel);
    const l = lpf(G, e, o.cut || 4200, 0.5); sum.connect(l);
    if (o.buzz) {
      const ws = c.createWaveShaper(), cv = new Float32Array(256);
      for (let i = 0; i < 256; i++) { const x = i / 127.5 - 1; cv[i] = Math.max(-1, Math.min(1, x * 5)); }
      ws.curve = cv; const hp = c.createBiquadFilter(); hp.type = "highpass"; hp.frequency.value = 1800;
      const bp = c.createBiquadFilter(); bp.type = "bandpass"; bp.frequency.value = 3200; bp.Q.value = 0.8;
      const bg = c.createGain(); bg.gain.value = o.buzz; sum.connect(ws); ws.connect(hp); hp.connect(bp); bp.connect(bg); bg.connect(e);
    }
    parts.forEach(v => { v.start(t); v.stop(t + dur + rel + 0.1); });
    nz(G, t, "bandpass", f0 * 2.1, 1.6, dest, vel * (o.breath || 0.3), dur * 0.85, 0.05);
    nz(G, t, "bandpass", 2400, 1.2, dest, vel * 0.18, 0.035, 0.004);
  }
  function pulseWave(G, duty) {
    const key = "p" + duty;
    if (G.waves[key]) return G.waves[key];
    const n = 40, re = new Float32Array(n), im = new Float32Array(n);
    for (let k = 1; k < n; k++) { const soft = Math.pow(1 - k / n, 1.2); re[k] = Math.sin(2 * Math.PI * k * duty) / (k * Math.PI) * soft; im[k] = (1 - Math.cos(2 * Math.PI * k * duty)) / (k * Math.PI) * soft; }
    return (G.waves[key] = G.c.createPeriodicWave(re, im));
  }
  function stepTri(G) {
    if (G.waves.tri) return G.waves.tri;
    const n = 48, re = new Float32Array(n), im = new Float32Array(n), steps = 32;
    for (let j = 0; j < steps; j++) {
      const v = (j < 16 ? 15 - j : j - 16) / 7.5 - 1, a0 = 2 * Math.PI * j / steps, a1 = 2 * Math.PI * (j + 1) / steps;
      for (let k = 1; k < n; k++) { re[k] += v * (Math.sin(k * a1) - Math.sin(k * a0)) / (k * Math.PI); im[k] += v * (Math.cos(k * a0) - Math.cos(k * a1)) / (k * Math.PI); }
    }
    return (G.waves.tri = G.c.createPeriodicWave(re, im));
  }
  // 칩 소리 크기는 1/60초마다 계단으로 줄어듦(옛 게임기처럼)
  function stepEnv(G, t, out, peak, dur, rel) {
    const g = G.c.createGain(); g.gain.setValueAtTime(0, t);
    const frames = Math.max(1, Math.round((dur + rel) * 60));
    for (let f = 0; f <= frames; f++) {
      const k = f / 60 < dur ? 1 - 0.35 * f / (dur * 60) : 0.65 * (1 - (f / 60 - dur) / rel);
      g.gain.setValueAtTime(peak * Math.max(0, Math.round(Math.max(0, k) * 15) / 15), t + f / 60);
    }
    g.gain.setValueAtTime(0, t + (frames + 1) / 60);
    g.connect(out); return g;
  }

  // ── 악기 ──
  E.inst = function (G, w, kind, t, midi, vel, dur, out, prev) {
    const orn = E.ornFor(w, midi, dur / G.s16 + 0.01), wide = G.width;
    switch (kind) {
      case "gayageum":
        pluck(G, t, midi, vel * 2, out, { bright: 0.42, decay: 1.6, exc: 0.45, body: [[220, 4], [900, 2], [2600, -3]], cut: 3800 + 1800 * w.bright, attack: 0.003, orn: orn, vib: orn ? 0 : 6, vibHz: 4.6, vibAt: 0.3, pan: -0.15 * wide });
        break;
      case "daegeum":
        flute(G, t, midi, vel * 0.8, out, Math.max(dur, 0.25), { breath: 0.32, buzz: 0.16, orn: orn, vib: orn ? 0 : 16, cut: 5200, pan: 0.5 * wide });
        break;
      case "glassharp": {
        const f = hz(midi), dest = pan(G, out, (rnd() - 0.5) * 0.4 * wide), d = Math.max(dur, 0.4);
        for (const [r, g, b] of [[1, 1, 0.7], [2, 0.07, 0], [3, 0.025, 0]]) {
          for (const det of b ? [0, b] : [0]) {
            const o = G.c.createOscillator(); o.type = "sine"; o.frequency.value = f * r + det;
            o.connect(sus(G, t, dest, 0.16, vel * 0.32 * g * (det ? 0.7 : 1), d - 0.16, 0.6)); o.start(t); o.stop(t + d + 0.8);
          }
        }
        const s = G.c.createBufferSource(); s.buffer = G.noise; s.loop = true;
        const bp = G.c.createBiquadFilter(); bp.type = "bandpass"; bp.frequency.value = f; bp.Q.value = 30;
        const am = G.c.createGain(); am.gain.value = 0.5; const l = G.c.createOscillator(); l.frequency.value = 8 + rnd() * 3; const lg = G.c.createGain(); lg.gain.value = 0.5; l.connect(lg); lg.connect(am.gain);
        s.connect(bp); bp.connect(am); am.connect(sus(G, t, dest, 0.12, vel * 0.32, d - 0.12, 0.4)); s.start(t, rnd()); s.stop(t + d + 0.6); l.start(t); l.stop(t + d + 0.6);
        break;
      }
      case "handpan": handpan(G, t, midi, vel * 0.8, pan(G, out, (rnd() - 0.5) * 0.9 * wide), 1); break;
      case "krar":
        pluck(G, t, midi, vel * 1.6, out, { bright: 0.8, decay: 1.0, exc: 0.92, buzz: 0.22, body: [[380, 4], [2300, 3]], cut: 6200, pan: -0.1 * wide });
        break;
      case "masenqo":
        bowed(G, t, midi, vel * 0.75, out, dur, { filters: [["highpass", 260, 0.7], ["peaking", 950, 2, 8], ["peaking", 2400, 2, 4], ["lowpass", 5000, 0.7]], vib: 22, vibHz: 5.2, vibAt: 0.12, from: prev === undefined ? midi - 1.5 : prev, slideT: 0.11, attack: 0.07, noise: 0.32, pan: 0.45 * wide });
        break;
      case "sitar": {
        const meend = prev !== undefined && prev !== null && Math.abs(prev - midi) <= 2 && prev !== midi;
        pluck(G, t, midi, vel * 1.9, out, { bright: 0.9, decay: 1.7, exc: 0.95, buzz: 0.55, body: [[1100, 4], [3000, 2]], cut: 6800, orn: orn, from: meend ? prev : undefined, slideT: 0.07, pan: -0.1 * wide });
        pluck(G, t + 0.03, midi + 12, vel * 0.18, out, { bright: 0.6, decay: 2.2, exc: 0.4, cut: 5000, attack: 0.05, pan: 0.4 * wide });
        break;
      }
      case "chikari": for (let k = 0; k < 3; k++) pluck(G, t + k * 0.012, [72, 84, 79][k], vel * 0.35, out, { bright: 0.85, decay: 0.5, exc: 0.9, buzz: 0.4, cut: 7000, pan: 0.3 * wide }); break;
      case "bansuri":
        flute(G, t, midi, vel * 0.9, out, Math.max(dur, 0.25), { breath: 0.5, orn: orn, vib: orn ? 0 : 12, cut: 3800, pan: 0.45 * wide });
        break;
      case "cimbalom": {
        const o = { bright: 0.9, decay: 2.2, exc: 1.0, strings: [-3, 0, 3.5], body: [[2500, 3]], cut: 7000, pan: -0.1 * wide };
        if (dur >= G.s16 * 3.9) {
          const n = Math.floor(dur / (G.s16 / 2));
          for (let k = 0; k < n; k++) pluck(G, t + k * G.s16 / 2 + hum(3), midi, vel * (k % 2 ? 0.55 : 0.75) * (1 - k / (n * 2.5)), out, Object.assign({}, o, { decay: 1.2 }));
        } else pluck(G, t, midi, vel * 1.05, out, o);
        break;
      }
      case "violin":
        bowed(G, t, midi, vel * 1.0, out, dur, { voices: [-4, 4], filters: [["highpass", 190, 0.7], ["peaking", 290, 1.4, 4], ["peaking", 1200, 1.6, 3], ["peaking", 2900, 1.8, 5], ["lowpass", 7500, 0.7]], vib: 16, vibHz: 6.2, vibAt: 0.1, from: prev, slideT: 0.09, attack: 0.05, noise: 0.14, sob: true, pan: 0.5 * wide });
        break;
      case "chip": {
        const c = G.c, o = c.createOscillator(); o.setPeriodicWave(pulseWave(G, 0.25)); o.frequency.value = hz(midi);
        o.detune.setValueAtTime(100 + (rnd() - 0.5) * 8, t); o.detune.linearRampToValueAtTime((rnd() - 0.5) * 8, t + 0.018);
        const l = c.createOscillator(), lg = c.createGain(); l.frequency.value = 6; lg.gain.setValueAtTime(0, t); lg.gain.setValueAtTime(0, t + 0.2); lg.gain.linearRampToValueAtTime(18, t + 0.3); l.connect(lg); lg.connect(o.detune);
        const d = Math.max(dur * 0.9, 0.06);
        o.connect(lpf(G, stepEnv(G, t, pan(G, out, -0.1 * wide), vel * 0.55, d, 0.08), 4200, 0.7));
        o.start(t); o.stop(t + d + 0.2); l.start(t); l.stop(t + d + 0.2);
        break;
      }
      case "steelpan": steelpan(G, t, midi, vel * 2.5, pan(G, out, (0.3 + rnd() * 0.3) * wide), 1); break;
      case "glassbell": glassbell(G, t, midi, vel, pan(G, out, (rnd() - 0.5) * 0.6 * wide), 1); break;
      case "tremble": {
        const c = G.c, f = hz(midi), sum = c.createGain(), d = Math.max(dur, 0.4);
        const vs = [-9, 0, 9].map(cents => { const v = c.createOscillator(); v.type = "sawtooth"; v.frequency.value = f; v.detune.value = cents; v.connect(sum); return v; });
        pitchMove(G, vs.map(v => v.detune), t, d, { midi: midi, vib: 8, vibHz: 5, vibAt: 0.2 });
        const fl = c.createBiquadFilter(); fl.type = "lowpass"; fl.Q.value = 2; fl.frequency.setValueAtTime(700, t); fl.frequency.linearRampToValueAtTime(1800, t + d * 0.6); fl.frequency.linearRampToValueAtTime(900, t + d);
        const trem = c.createGain(); trem.gain.value = 0.55; const tl = c.createOscillator(); tl.frequency.value = 6.4; const tg = c.createGain(); tg.gain.value = 0.45; tl.connect(tg); tg.connect(trem.gain);
        sum.connect(fl); fl.connect(trem); trem.connect(sus(G, t, pan(G, out, 0.5 * wide), 0.2, vel * 0.9, d - 0.2, 0.5));
        vs.forEach(v => { v.start(t); v.stop(t + d + 0.7); }); tl.start(t); tl.stop(t + d + 0.7);
        break;
      }
    }
  };
  function handpan(G, t, midi, vel, out, k) {
    const f = hz(midi), l = lpf(G, out, 3400, 0.5);
    partials(G, t, f, l, [[1, 1, 2.2 * k, 0.45], [2, 0.42, 1.3 * k, 0.6], [3, 0.16, 0.6 * k, 0]], vel * 0.45, 0.004);
    nz(G, t, "lowpass", 900, 0.6, l, vel * 0.25, 0.02);
  }
  function steelpan(G, t, midi, vel, out, k) {
    const f = hz(midi), l = lpf(G, out, 4200, 0.5), c = G.c;
    osc(G, t, "sine", f, l, 0.003, vel * 0.42, 1.3 * k);
    const o2 = c.createOscillator(); o2.type = "sine"; o2.frequency.setValueAtTime(f * 2 * 1.006, t); o2.frequency.exponentialRampToValueAtTime(f * 2, t + 0.08);
    o2.connect(env(G, t, l, 0.018, vel * 0.3, 0.9 * k)); o2.start(t); o2.stop(t + 1.2 * k);
    osc(G, t, "sine", f * 3.003, l, 0.003, vel * 0.12, 0.45 * k);
    osc(G, t, "sine", f * 4.07, l, 0.002, vel * 0.04, 0.2 * k);
    nz(G, t, "lowpass", 1400, 0.6, l, vel * 0.18, 0.015);
  }
  function glassbell(G, t, midi, vel, out, k) {
    const f = hz(midi), l = lpf(G, out, 5600, 0.5);
    partials(G, t, f, l, [[1, 1, 3.2 * k, 0.6], [2.32, 0.32, 1.9 * k, 0], [4.25, 0.16, 1.0 * k, 0], [6.63, 0.06, 0.5 * k, 0]], vel * 0.4, 0.004);
  }

  // ── 박 뼈대 ──
  function kick(G, t, v, out) {
    drum(G, t, out, 118, 46, 0.1, v, 0.34);
    nz(G, t, "lowpass", 1400, 0.7, out, v * 0.22, 0.012);
    duck(G, t, 0.62);
  }
  function hat(G, t, v, open) {
    const p = pan(G, G.hat, 0.15 + (rnd() - 0.5) * 0.4 * G.width);
    nz(G, t, "highpass", 7200, 0.7, p, v * 5, open ? 0.16 : 0.03, 0.001);
    nz(G, t, "bandpass", 10000, 1.0, p, v * 2.5, open ? 0.12 : 0.02, 0.001);
  }
  function shaker(G, t, v, out) { nz(G, t, "bandpass", 6500, 1.3, pan(G, out, -0.2 * G.width), v, 0.05, 0.012); }
  E.hats = function (G, w, t, L, cut) {
    for (let s = 0; s < cut * 4; s++) {
      const ts = t + s * G.s16 + sw(G, w, s) + (s % 4 ? hum(6) : 0), acc = vary(1, 0.15);
      if (s % 2 === 0) {
        if (L >= 2 && s % 4 === 2) hat(G, ts, 0.09 * acc, true);
        else hat(G, ts, (s % 4 === 0 ? 0.05 : 0.1) * acc, false);
      } else if (L >= 2) hat(G, ts, 0.03 * acc, false);
    }
  };

  // ── 세계 타악: 소리(stroke) · 한 마디 장단(pat) · 가벼운 장단(light) · 넘어가기 필인(fill, 한 박 안의 자리) ──
  const KIT = {
    janggu: {
      gain: 1,
      pan: { kung: -0.35, deok: 0.35 },
      s: {
        kung: (G, t, v, o) => { drum(G, t, o, 105, 72, 0.08, v, 0.32); nz(G, t, "lowpass", 350, 0.7, o, v * 0.25, 0.05); },
        deok: (G, t, v, o) => { nz(G, t, "bandpass", 2600, 1.4, o, v * 1.1, 0.045); drum(G, t, o, 430, 380, 0.04, v * 0.3, 0.05); nz(G, t, "highpass", 5000, 0.7, o, v * 0.3, 0.006); },
      },
      combo: { deong: ["kung", "deok"], gideok: [["deok", -0.035, 0.45], "deok"] },
      pat: [[0, "deong", 1], [2, "deok", 0.3], [3, "deok", 0.6], [6, "kung", 0.75], [8, "deong", 0.75], [10, "gideok", 0.6], [12, "kung", 0.6], [14, "deok", 0.5], [15, "deok", 0.28]],
      light: [[0, "kung", 0.5], [6, "deok", 0.28], [8, "kung", 0.38], [12, "deok", 0.3]],
      fill: [[0, "gideok", 0.5], [0.25, "deok", 0.5], [0.5, "kung", 0.7], [0.75, "deok", 0.55], [0.875, "deok", 0.62]],
    },
    handdrum: {
      gain: 1.6,
      pan: { bass: 0, tone: -0.3, slap: 0.3, tap: 0.4 },
      s: {
        bass: (G, t, v, o) => { drum(G, t, o, 82, 56, 0.1, v, 0.3); nz(G, t, "lowpass", 300, 0.7, o, v * 0.2, 0.04); },
        tone: (G, t, v, o) => { drum(G, t, o, 230, 205, 0.05, v * 0.6, 0.14); nz(G, t, "bandpass", 600, 1, o, v * 0.3, 0.03); },
        slap: (G, t, v, o) => { nz(G, t, "bandpass", 2200, 1.3, o, v, 0.05); drum(G, t, o, 330, 300, 0.03, v * 0.25, 0.03); },
        tap: (G, t, v, o) => nz(G, t, "bandpass", 3200, 2, o, v * 0.8, 0.02),
      },
      pat: [[0, "bass", 0.8], [3, "tap", 0.3], [6, "tone", 0.55], [8, "bass", 0.5], [10, "slap", 0.55], [13, "tap", 0.3], [14, "tone", 0.45]],
      light: [[0, "bass", 0.5], [10, "tap", 0.3]],
      fill: [[0, "tap", 0.35], [0.25, "tap", 0.45], [0.5, "tone", 0.55], [0.75, "slap", 0.65]],
    },
    kebero: {
      gain: 1.1,
      pan: { dum: 0, tone: -0.25, slap: 0.3 },
      s: {
        dum: (G, t, v, o) => { drum(G, t, o, 72, 48, 0.12, v, 0.42); nz(G, t, "lowpass", 280, 0.7, o, v * 0.3, 0.06); },
        tone: (G, t, v, o) => { drum(G, t, o, 160, 130, 0.06, v * 0.7, 0.16); nz(G, t, "bandpass", 700, 1, o, v * 0.3, 0.03); },
        slap: (G, t, v, o) => { nz(G, t, "bandpass", 1900, 1.2, o, v, 0.06); drum(G, t, o, 280, 250, 0.03, v * 0.25, 0.03); },
      },
      pat: [[0, "dum", 1], [3, "slap", 0.4], [4, "tone", 0.5], [6, "slap", 0.7], [8, "dum", 0.8], [10, "slap", 0.4], [11, "tone", 0.5], [12, "slap", 0.7], [14, "tone", 0.45], [15, "slap", 0.3]],
      light: [[0, "dum", 0.6], [6, "slap", 0.35], [12, "slap", 0.3]],
      fill: [[0, "slap", 0.45], [1 / 3, "slap", 0.55], [2 / 3, "tone", 0.6], [5 / 6, "slap", 0.75]],
    },
    tabla: {
      gain: 1,
      pan: { na: 0.3, tin: 0.3, te: 0.3, ge: -0.3, ka: -0.3 },
      s: {
        na: (G, t, v, o) => { partials(G, t, 261.6, o, [[1, 1, 0.45], [2, 0.55, 0.3], [3, 0.35, 0.2], [4, 0.18, 0.12]], v * 0.4, 0.002); nz(G, t, "bandpass", 3500, 1.5, o, v * 0.4, 0.008); },
        tin: (G, t, v, o) => partials(G, t, 261.6, o, [[1, 1, 0.55], [2, 0.2, 0.25]], v * 0.4, 0.003),
        te: (G, t, v, o) => { nz(G, t, "bandpass", 1600, 1, o, v * 0.8, 0.025); osc(G, t, "sine", 262, o, 0.002, v * 0.15, 0.03); },
        ge: (G, t, v, o) => { const x = G.c.createOscillator(); x.type = "sine"; x.frequency.setValueAtTime(88, t); x.frequency.linearRampToValueAtTime(118, t + 0.18); x.connect(env(G, t, o, 0.003, v * 0.9, 0.55)); x.start(t); x.stop(t + 0.65); nz(G, t, "lowpass", 220, 0.7, o, v * 0.25, 0.03); },
        ka: (G, t, v, o) => { nz(G, t, "lowpass", 600, 0.8, o, v * 0.8, 0.035); osc(G, t, "sine", 110, o, 0.002, v * 0.2, 0.03); },
      },
      combo: { dha: ["ge", "na"], dhin: ["ge", "tin"] },
      pat: [[0, "dha", 0.9], [2, "ge", 0.55], [4, "na", 0.6], [6, "te", 0.45], [7, "te", 0.25], [8, "na", 0.6], [10, "ka", 0.5], [12, "dhin", 0.75], [14, "na", 0.55], [15, "te", 0.25]],
      light: [[0, "ge", 0.45], [8, "tin", 0.3], [12, "ge", 0.3]],
      fill: [[0, "te", 0.5], [0.25, "te", 0.45], [0.5, "ka", 0.5], [0.75, "na", 0.7]],
    },
    frame: {
      gain: 1.3,
      pan: { dum: 0, tek: 0.3, jing: -0.35 },
      s: {
        dum: (G, t, v, o) => { drum(G, t, o, 66, 48, 0.12, v, 0.4); nz(G, t, "lowpass", 240, 0.7, o, v * 0.3, 0.05); },
        tek: (G, t, v, o) => { nz(G, t, "bandpass", 2500, 1.1, o, v, 0.05); drum(G, t, o, 360, 330, 0.03, v * 0.25, 0.03); },
        jing: (G, t, v, o) => { for (const [d, k] of [[0, 0.6], [0.012, 0.4], [0.026, 0.28]]) { nz(G, t + d, "highpass", 7000, 0.8, o, v * k, 0.05); nz(G, t + d, "bandpass", 9000, 2, o, v * k * 0.5, 0.04); } },
      },
      combo: { tekj: ["tek", "jing"] },
      pat: [[0, "dum", 0.9], [2, "tekj", 0.5], [4, "tek", 0.35], [6, "tekj", 0.6], [8, "dum", 0.7], [10, "tekj", 0.5], [12, "tek", 0.35], [14, "tekj", 0.6], [15, "tek", 0.2]],
      light: [[0, "dum", 0.5], [6, "jing", 0.3], [14, "jing", 0.3]],
      fill: [[0, "tek", 0.4], [0.25, "tek", 0.5], [0.5, "tek", 0.55], [0.625, "tek", 0.45], [0.75, "dum", 0.65], [0.875, "tekj", 0.6]],
    },
    metal: {
      gain: 3,
      pan: { clank: -0.2, pipe: 0.35, tick: 0.25, hiss: -0.4 },
      s: {
        clank: (G, t, v, o) => { nz(G, t, "bandpass", 1100, 3, o, v * 0.8, 0.07); partials(G, t, 380, o, [[1, 0.5, 0.18], [2.745, 0.3, 0.1], [5.81, 0.2, 0.06]], v * 0.5, 0.001); },
        pipe: (G, t, v, o) => { partials(G, t, 620, o, [[1, 0.35, 0.6], [2.757, 0.2, 0.3], [5.4, 0.1, 0.14]], v * 0.6, 0.002); nz(G, t, "bandpass", 4000, 2, o, v * 0.2, 0.01); },
        tick: (G, t, v, o) => { partials(G, t, 2650, o, [[1, 0.3, 0.035], [2.3, 0.15, 0.025]], v, 0.001); nz(G, t, "highpass", 6000, 0.7, o, v * 0.3, 0.01); },
        hiss: (G, t, v, o) => nz(G, t, "highpass", 4500, 0.7, o, v * 0.6, 0.18, 0.05),
      },
      pat: [[0, "clank", 0.75], [3, "tick", 0.3], [4, "pipe", 0.5], [6, "tick", 0.35], [8, "clank", 0.6], [10, "tick", 0.35], [11, "tick", 0.2], [12, "pipe", 0.5], [14, "tick", 0.35], [15, "hiss", 0.25]],
      light: [[0, "tick", 0.3], [8, "tick", 0.25], [12, "hiss", 0.15]],
      fill: [[0, "tick", 0.2], [0.125, "tick", 0.26], [0.25, "tick", 0.32], [0.375, "tick", 0.38], [0.5, "tick", 0.44], [0.625, "tick", 0.5], [0.75, "clank", 0.7]],
    },
    heart: {
      gain: 1,
      pan: { lub: 0, dub: 0, shard: 0.45 },
      s: {
        lub: (G, t, v, o) => { drum(G, t, o, 58, 38, 0.12, v, 0.38); nz(G, t, "lowpass", 160, 0.7, o, v * 0.3, 0.05); },
        dub: (G, t, v, o) => drum(G, t, o, 52, 36, 0.1, v * 0.7, 0.28),
        shard: (G, t, v, o) => partials(G, t, 3100, o, [[1, 0.5, 0.15], [1.571, 0.3, 0.09], [2.265, 0.2, 0.05]], v, 0.002),
      },
      pat: [[0, "lub", 0.9], [2, "dub", 0.6], [5, "shard", 0.2], [8, "lub", 0.8], [10, "dub", 0.55], [13, "shard", 0.18]],
      light: [[0, "lub", 0.5], [2, "dub", 0.3]],
      fill: [[0, "lub", 0.5], [0.375, "dub", 0.4], [0.625, "lub", 0.6], [0.8125, "dub", 0.6]],
    },
  };
  function stroke(G, kit, name, t, v, out) {
    const list = (kit.combo && kit.combo[name]) || [name];
    for (const it of list) {
      const [nm, dt, k] = typeof it === "string" ? [it, 0, 1] : it;
      kit.s[nm](G, t + dt, vary(v * k * kit.gain, 0.1), pan(G, out, (kit.pan[nm] || 0) * (0.4 + 0.6 * G.width)));
    }
  }
  // o.light: 내 차례용 가벼운 장단(겹과 상관없이 울림) · o.tail: 마지막 박을 작은 필인으로 바꿈(변주)
  E.perc = function (G, w, t, o) {
    const kit = KIT[w.perc], out = o.light ? G.fill : w.mirror ? G.percEcho : G.perc, cut = o.cut === undefined ? 4 : o.cut, end = o.tail ? 12 : cut * 4;
    for (const [s, nm, v] of (o.light ? kit.light : kit.pat)) {
      if (s >= end) continue;
      stroke(G, kit, nm, t + s * G.s16 + sw(G, w, s) + (s % 4 ? hum(7) : hum(2)), v * (o.light ? 0.75 : 1), out);
    }
    if (o.tail) for (const [f, nm, v] of kit.fill) stroke(G, kit, nm, t + (3 + f) * G.beat + hum(3), v * 0.7, out);
    if (o.light) for (let s = 2; s < cut * 4; s += 4) shaker(G, t + s * G.s16 + hum(6), vary(0.2, 0.2), out);
    if (w.lead === "sitar" && !o.light) for (const s of [7, 15]) if (s < end) E.inst(G, w, "chikari", t + s * G.s16 + hum(4), 72, 0.5, G.s16, out);
  };
  E.fill = function (G, w, t) {
    const kit = KIT[w.perc];
    for (const [f, nm, v] of kit.fill) stroke(G, kit, nm, t + f * G.beat + hum(3), v, G.fill);
  };

  // ── 바닥 위 받침(세계 색) · 베이스 반복 ──
  E.bed = function (G, w, t, dur, level) {
    const c = G.c, cut = (w.mirror ? 0.6 : 1), a = w.mirror ? 1.2 : 0.5, wide = 0.3 + 0.6 * G.width;
    if (w.bed === "tanpura") {
      for (let b = 0; b < Math.round(dur / G.beat); b++) {
        const m = 48 + w.bedTones[b % 4];
        pluck(G, t + b * G.beat + 0.02 + rnd() * 0.04, m, 1.1 * level, G.bed, { bright: 0.75, decay: 3.2, exc: 0.5, buzz: 0.6, body: [[600, 3]], cut: 3800 * cut, attack: 0.01, pan: ((b % 2) - 0.5) * wide });
      }
      return;
    }
    w.bedTones.forEach((semi, i) => {
      const m = 48 + semi, f = hz(m), side = i % 2 ? 1 : -1;
      const lv = { saeng: 1, glass: 1.1, warm: 1.5, strings: 1.5, pulse: 1.2, choir: 1 }[w.bed];
      const g = sus(G, t, pan(G, G.bed, side * wide * (i === 0 ? 0.3 : 1)), a, (i === 0 ? 0.09 : 0.07) * level * lv, Math.max(0.1, dur - a), 0.9);
      if (w.bed === "choir") {
        const sum = c.createGain(); sum.gain.value = 0.5;
        for (let v = 0; v < 3; v++) {
          const o = c.createOscillator(); o.type = "sawtooth"; o.frequency.value = f; o.detune.value = (rnd() - 0.5) * 16;
          const l = c.createOscillator(), lg = c.createGain(); l.frequency.value = 4 + rnd() * 1.5; lg.gain.value = 6; l.connect(lg); lg.connect(o.detune);
          o.connect(sum); o.start(t); o.stop(t + dur + 1.2); l.start(t); l.stop(t + dur + 1.2);
        }
        for (const [f1, f2, q, gn] of [[300, 650, 6, 1], [870, 1080, 8, 0.5], [2240, 2650, 10, 0.18]]) {
          const bp = c.createBiquadFilter(); bp.type = "bandpass"; bp.Q.value = q;
          bp.frequency.setValueAtTime(f1, t); bp.frequency.linearRampToValueAtTime(f2, t + dur * 0.55); bp.frequency.linearRampToValueAtTime((f1 + f2) / 2, t + dur);
          const gg = c.createGain(); gg.gain.value = gn * 9; sum.connect(bp); bp.connect(gg); gg.connect(g);
        }
        return;
      }
      const type = { saeng: "square", glass: "sine", warm: "sawtooth", strings: "sawtooth", pulse: "pulse" }[w.bed] || "sawtooth";
      const fc = { saeng: 1300, glass: 5000, warm: 850, strings: 1300, pulse: 1500 }[w.bed] * cut * (0.7 + 0.6 * w.bright);
      const fl = lpf(G, g, fc, 0.6);
      for (const det of [-5, 5]) {
        const o = c.createOscillator();
        if (type === "pulse") o.setPeriodicWave(pulseWave(G, det < 0 ? 0.125 : 0.4)); else o.type = type;
        o.frequency.value = f; o.detune.value = det + (rnd() - 0.5) * 3;
        o.connect(fl); o.start(t); o.stop(t + dur + 1.1);
      }
      if (w.bed === "glass") { const o = c.createOscillator(); o.frequency.value = f * 2.002; const gg = c.createGain(); gg.gain.value = 0.25; o.connect(gg); gg.connect(fl); o.start(t); o.stop(t + dur + 1.1); }
      if (w.bed === "saeng" || w.bed === "strings") {
        const l = c.createOscillator(), lg = c.createGain(); l.frequency.value = w.bed === "saeng" ? 0.35 : 0.2; lg.gain.value = 260; l.connect(lg); lg.connect(fl.frequency); l.start(t); l.stop(t + dur + 1.1);
      }
    });
    if (w.bed === "pulse") osc(G, t + rnd() * G.bar, "square", 1800 + rnd() * 900, lpf(G, G.fx, 3000), 0.001, 0.02 * level, 0.02);
  };
  function bassNote(G, w, t, m, dur, v) {
    const c = G.c;
    if (w.lead === "chip") {
      const o = c.createOscillator(); o.setPeriodicWave(stepTri(G)); o.frequency.value = hz(m);
      o.connect(stepEnv(G, t, G.bass, v * 0.9, Math.max(0.05, dur * 0.8), 0.05)); o.start(t); o.stop(t + dur + 0.2);
      return;
    }
    if (w.lead === "glassbell" || w.lead === "glassharp") {
      const o = c.createOscillator(); o.type = w.lead === "glassbell" ? "sawtooth" : "sine"; o.frequency.value = hz(m);
      const sub = c.createOscillator(); sub.type = "sine"; sub.frequency.value = hz(m);
      const g = sus(G, t, G.bass, 0.02, v * 0.35, Math.max(0.05, dur - 0.05), 0.15), l = lpf(G, g, w.lead === "glassbell" ? 260 : 900, 0.7);
      o.connect(l); sub.connect(g); o.start(t); sub.start(t); o.stop(t + dur + 0.3); sub.stop(t + dur + 0.3);
      return;
    }
    pluck(G, t, m, v * 1.3, G.bass, { bright: 0.35, decay: Math.min(1.2, dur + 0.35), exc: 0.5, body: [[110, 3]], cut: 1200, attack: 0.004 });
    const sub = c.createOscillator(); sub.type = "sine"; sub.frequency.value = hz(m);
    sub.connect(sus(G, t, G.bass, 0.005, v * 0.7, Math.max(0.04, dur - 0.04), 0.1)); sub.start(t); sub.stop(t + dur + 0.2);
  }
  E.riff = function (G, w, t, cut, v) {
    w.riff.forEach(([s, semi, len], i) => {
      if (s >= cut * 4) return;
      const up = v >= 2 && i === w.riff.length - 1 ? 12 : 0;
      bassNote(G, w, t + s * G.s16 + sw(G, w, s) + hum(3), 36 + semi + up, len * G.s16, vary(0.5, 0.1));
    });
    if (w.esztam) for (const s of [2, 6, 10, 14]) {
      if (s >= cut * 4) continue;
      const ch = s < 8 ? [51, 55, 60] : [47, 50, 55];
      ch.forEach((m, k) => pluck(G, t + s * G.s16 + k * 0.006 + hum(3), m, 0.16, G.bass, { bright: 0.85, decay: 0.28, exc: 0.9, cut: 4200, pan: (k - 1) * 0.3 * G.width }));
    }
  };

  // ── 앞 악기 · 맞받는 선율 · 반짝이 ──
  // 변주(같은 세계가 다시 나올 때 돌아가며): 0 원래 · 1 앞 마디를 음계 두 칸 위로(모방) · 2 앞 마디 솎고 뒷 마디 한 칸 아래
  // · 3 앞 마디는 맞받는 악기가 한 옥타브 위에서 부르고 앞 악기가 받음
  E.VARIS = ["원래", "모방", "솎음", "주고받기"];
  function degOf(w, semi) {
    const n = w.scale.length, o = Math.floor(semi / 12), pc = semi - 12 * o, i = w.scale.indexOf(pc);
    return o * n + (i >= 0 ? i : w.scale.filter(x => x < pc).length);
  }
  function semiOf(w, d) { const n = w.scale.length; return w.scale[((d % n) + n) % n] + 12 * Math.floor(d / n); }
  E.phrase = function (w, v) {
    const m = w.mel;
    if (v === 1) return m.map(([p, s, l]) => [p, p < 16 ? semiOf(w, degOf(w, s) + 2) : s, l]);
    if (v === 2) {
      const last = m[m.length - 1][0];
      return m.filter(([p, , l], i) => p >= 16 || i === 0 || l >= 2).map(([p, s, l]) => [p, p >= 16 && p !== last ? semiOf(w, degOf(w, s) - 1) : s, l]);
    }
    return m;
  };
  E.lead = function (G, w, t, half, cut, vel, v) {
    const lag = w.mirror ? 2 : 0, out = w.mirror ? G.mirror : G.lead, swap = v === 3 && half === 0;
    let prev;
    for (const [p, semi, len] of E.phrase(w, v || 0)) {
      if (Math.floor(p / 16) !== half) continue;
      const s = (p % 16) + lag;
      if (s >= cut * 4) continue;
      const ts = t + s * G.s16 + sw(G, w, s) + hum(5), m = 60 + semi + (swap ? 12 : 0);
      dip = w.mirror ? -30 : 0;
      E.inst(G, w, swap ? w.counter : w.lead, ts, m, vary((vel || 0.62) * (swap ? 0.85 : 1), 0.12), len * G.s16, out, prev);
      dip = 0;
      prev = m;
    }
  };
  E.counter = function (G, w, t, half, cut) {
    let prev;
    for (const [p, semi, len] of w.ctr) {
      if (Math.floor(p / 16) !== half) continue;
      const s = p % 16;
      if (s >= cut * 4) continue;
      const m = 72 + semi;
      E.inst(G, w, w.counter, t + s * G.s16 + sw(G, w, s) + hum(6), m, vary(0.55, 0.12), len * G.s16, G.counter, prev);
      prev = m;
    }
  };
  E.sparkle = function (G, w, t, cut) {
    const out = pan(G, G.spark, 0), sc = w.scale, n = sc.length, top = s => 84 + sc[s % n] + 12 * Math.floor(s / n);
    const end = cut * 4;
    switch (w.spark) {
      case "pungyeong":
        for (let k = 0; k < 3; k++) { const ts = t + rnd() * G.bar * cut / 4; if (rnd() < 0.8) partials(G, ts, hz(top(Math.floor(rnd() * n * 1.5))), pan(G, G.spark, (rnd() - 0.5) * 1.6 * G.width), [[1, 1, 1.6], [2.4, 0.3, 0.8], [4.1, 0.12, 0.4]], 0.15, 0.003); }
        break;
      case "glint":
        for (let s = 2; s < end; s += 4) if (rnd() < 0.6) partials(G, t + s * G.s16, hz(top(Math.floor(rnd() * n))), pan(G, G.spark, (rnd() - 0.5) * 1.8 * G.width), [[1, 1, 1.2], [2, 0.2, 0.5]], 0.15, 0.01);
        break;
      case "tsenatsel":
        for (let s = 0; s < end; s += 2) { const ts = t + s * G.s16 + sw(G, w, s); for (let k = 0; k < 4; k++) nz(G, ts + k * 0.009, "highpass", 6000, 0.8, out, (s % 4 ? 0.35 : 0.2) * (1 - k * 0.2), 0.03); }
        break;
      case "manjira":
        for (let s = 0; s < end; s += 4) partials(G, t + s * G.s16 + hum(4), s % 8 ? 2100 : 1800, pan(G, G.spark, (s % 8 ? 0.4 : -0.4) * G.width), [[1, 1, s % 8 ? 0.08 : 0.7], [2.76, 0.4, 0.3], [5.4, 0.2, 0.15]], 0.18, 0.001);
        break;
      case "cimb":
        for (let s = 4; s < end; s += 8) if (rnd() < 0.8) { const m = top(Math.floor(rnd() * n)); pluck(G, t + s * G.s16 - G.s16 / 2, m, 0.5, G.spark, { bright: 0.9, decay: 0.8, exc: 1, cut: 7000 }); pluck(G, t + s * G.s16, m + (rnd() < 0.5 ? -1 : 2), 0.65, G.spark, { bright: 0.9, decay: 1.0, exc: 1, cut: 7000 }); }
        break;
      case "bleep":
        for (let s = 1; s < end; s += 2) if (rnd() < 0.35) { const o = G.c.createOscillator(); o.setPeriodicWave(pulseWave(G, 0.125)); o.frequency.value = hz(top(Math.floor(rnd() * n))); o.connect(stepEnv(G, t + s * G.s16, lpf(G, out, 5000), 0.3, 0.05, 0.03)); o.start(t + s * G.s16); o.stop(t + s * G.s16 + 0.15); }
        break;
      case "shard":
        for (let k = 0; k < 4; k++) if (rnd() < 0.7) glassbell(G, t + Math.floor(rnd() * end) * G.s16, top(Math.floor(rnd() * n) + n), 0.25, pan(G, G.spark, (rnd() - 0.5) * 1.8 * G.width), 0.3);
        break;
    }
  };

  // 차오르는 소리: 다음 세계 밝기만큼 열리는 바람 + 솔에서 솔로 오르는 낮은 음
  E.riser = function (G, w, t, dur) {
    const c = G.c, s = c.createBufferSource(); s.buffer = G.noise; s.loop = true;
    const f = c.createBiquadFilter(); f.type = "bandpass"; f.Q.value = 1.6; f.frequency.setValueAtTime(350, t); f.frequency.exponentialRampToValueAtTime(2200 + 4500 * w.bright, t + dur);
    const g = c.createGain(); g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(0.14, t + dur * 0.92); g.gain.linearRampToValueAtTime(0.0001, t + dur + 0.02);
    s.connect(f); f.connect(g); g.connect(G.fx); s.start(t, rnd()); s.stop(t + dur + 0.05);
    const o = c.createOscillator(); o.type = "triangle"; o.frequency.setValueAtTime(hz(55), t); o.frequency.exponentialRampToValueAtTime(hz(67), t + dur);
    const og = c.createGain(); og.gain.setValueAtTime(0.0001, t); og.gain.exponentialRampToValueAtTime(0.035, t + dur * 0.92); og.gain.linearRampToValueAtTime(0.0001, t + dur + 0.02);
    o.connect(og); og.connect(lpf(G, G.fx, 1200)); o.start(t); o.stop(t + dur + 0.05);
  };

  // 막기 음: 무딘 시작(8~12ms) · 높은 소리 깎음 · 잔향 조금. 완벽 = 온음, 막음 = 작고 짧게
  E.parry = function (G, w, t, semi, kind) {
    const b = w.mirror ? w.base : w, full = kind !== "block", midi = 72 + semi;
    const vel = full ? 0.85 : 0.32, k = full ? 1 : 0.3, out = w.mirror ? G.parryEcho : G.parry;
    const l = lpf(G, out, (full ? 2500 : 1600) * (0.85 + 0.3 * b.bright), 0.45);
    const dest = l;
    const core = G.c.createOscillator(); core.type = "sine"; core.frequency.value = hz(midi);
    if (w.mirror) { core.detune.setValueAtTime(-30, t); core.detune.linearRampToValueAtTime(0, t + 0.12); }
    core.connect(env(G, t, dest, 0.012, vel * 0.3, 0.55 * k)); core.start(t); core.stop(t + 0.7 * k + 0.1);
    const orn = full ? E.ornFor(b, midi, 4) : null;
    dip = w.mirror ? -30 : 0;
    switch (b.parry) {
      case "gayageum": pluck(G, t, midi, vel * 1.9, dest, { bright: 0.28, decay: 1.3 * k, exc: 0.3, body: [[250, 3], [900, 2]], cut: 2600, attack: 0.009, orn: orn }); break;
      case "handpan": handpan(G, t, midi, vel * 0.42, dest, k); break;
      case "krar": pluck(G, t, midi, vel * 1.8, dest, { bright: 0.5, decay: 1.0 * k, exc: 0.45, body: [[380, 3]], cut: 2800, attack: 0.008 }); break;
      case "sitar": pluck(G, t, midi, vel * 1.6, dest, { bright: 0.6, decay: 1.2 * k, exc: 0.45, buzz: 0.12, body: [[1000, 2]], cut: 2600, attack: 0.009, orn: orn, scoop: 40 }); break;
      case "cimbalom": pluck(G, t, midi, vel * 1.2, dest, { bright: 0.55, decay: 1.5 * k, exc: 0.3, strings: [-3, 0, 3.5], cut: 2700, attack: 0.008 }); break;
      case "steelpan": steelpan(G, t, midi, vel * 0.75, dest, k); break;
      case "glassbell": glassbell(G, t, midi, vel * 0.5, dest, k * 0.6); break;
    }
    dip = 0;
  };
  E.thud = function (G, t) {
    nz(G, t, "lowpass", 230, 0.6, G.thudBus, 0.55, 0.11, 0.003);
    const o = G.c.createOscillator(); o.type = "sine"; o.frequency.setValueAtTime(105, t); o.frequency.exponentialRampToValueAtTime(45, t + 0.05);
    o.connect(env(G, t, lpf(G, G.thudBus, 300), 0.002, 0.32, 0.07)); o.start(t); o.stop(t + 0.15);
    nz(G, t, "bandpass", 520, 0.9, G.thudBus, 0.12, 0.03);
  };
  // 연속이 부서지는 소리: 잘게 금 가는 소리 + 짧은 유리 울림
  E.crack = function (G, t) {
    for (const [d, f, v] of [[0, 3300, 0.5], [0.007, 5200, 0.32], [0.016, 2500, 0.3], [0.029, 4200, 0.22], [0.047, 6000, 0.12]]) nz(G, t + d, "bandpass", f, 3.5, G.thudBus, v, 0.025 + d * 0.6);
    partials(G, t + 0.012, 1870, G.thudBus, [[1, 1, 0.25], [2.32, 0.6, 0.16], [3.9, 0.35, 0.1]], 0.06, 0.001);
  };
  // 한 번 놓침: 음악 전체가 잠깐 휘청(먹먹해졌다 돌아옴), 겹은 그대로
  E.stumble = function (G, t) {
    const f = G.musLP.frequency, g = G.mus.gain;
    f.cancelScheduledValues(t); g.cancelScheduledValues(t);
    f.setValueAtTime(18000, t); f.exponentialRampToValueAtTime(650, t + 0.05); f.exponentialRampToValueAtTime(18000, t + 0.5);
    g.setValueAtTime(1, t); g.linearRampToValueAtTime(0.6, t + 0.04); g.linearRampToValueAtTime(1, t + 0.45);
  };
  // 겹 끄기: 그 겹만 테이프가 멈추듯 음이 처지며(지연 시간을 늘려 도플러) 닫힘 · 켜기: 필터가 열리며 돌아옴
  E.cut = function (G, part, t) {
    const T = 0.42, curve = new Float32Array(24);
    for (let i = 0; i < 24; i++) curve[i] = T * 0.5 * Math.pow(i / 23, 2);
    for (const g of G.gates[part] || []) {
      for (const p of [g.d.delayTime, g.lp.frequency, g.g]) p.cancelScheduledValues(t);
      g.d.delayTime.setValueCurveAtTime(curve, t, T);
      g.lp.frequency.setValueAtTime(16000, t); g.lp.frequency.exponentialRampToValueAtTime(320, t + T);
      g.g.setValueAtTime(1, t); g.g.setValueAtTime(1, t + T * 0.4); g.g.linearRampToValueAtTime(0, t + T);
    }
    G.gateOpen[part] = false; G.cutEnd[part] = t + T + 0.02;
  };
  E.open = function (G, part, t) {
    t = Math.max(t, G.cutEnd[part] || 0);
    for (const g of G.gates[part] || []) {
      for (const p of [g.d.delayTime, g.lp.frequency, g.g]) p.cancelScheduledValues(t);
      g.d.delayTime.setValueAtTime(0, t);
      g.lp.frequency.setValueAtTime(600, t); g.lp.frequency.exponentialRampToValueAtTime(18000, t + 0.6);
      g.g.setValueAtTime(0, t); g.g.linearRampToValueAtTime(1, t + 0.3);
    }
    G.gateOpen[part] = true;
  };

  // ── 한 마디 짜기 ──
  // sp: { w 세계, kind "enemy" | "mine", half 0|1(두 마디 중), on 켜진 겹 이름들(E.PARTS), vari 변주 0~3,
  //      fill 다음 세계(마지막 박에 필인 + 차오름, 킥·앞 악기는 비움) }
  E.bar = function (G, sp, t) {
    const w = sp.w, mine = sp.kind === "mine", cut = sp.fill ? 3 : 4, on = mine ? [] : sp.on || [], has = p => on.includes(p), v = sp.vari || 0;
    const L = has("counter") || has("spark") ? 3 : has("kick4") || has("bass") ? 2 : has("hat") || has("perc") ? 1 : 0;
    G.width = mine ? 0.45 : 0.35 + 0.65 * on.length / E.PARTS.length;
    for (const p of on) if (!G.gateOpen[p]) E.open(G, p, t);
    E.droneTo(G, t, mine ? 0.85 : has("bass") ? 0.5 : 1);
    if (sp.half === 0) E.bed(G, w, t, 2 * G.bar, mine ? 0.9 : 0.55 + 0.15 * L);
    if (!mine) for (let b = 0; b < cut; b++) {
      if (b % 2 === 0) kick(G, t + b * G.beat, b === 0 ? 0.9 : vary(0.76, 0.06), G.kick);
      else if (has("kick4")) kick(G, t + b * G.beat, vary(0.76, 0.06), G.kick4);
    }
    if (has("hat")) E.hats(G, w, t, L, cut);
    if (mine) E.perc(G, w, t, { light: true, cut: cut });
    else if (has("perc")) E.perc(G, w, t, { cut: cut, tail: sp.half === 1 && !sp.fill && v % 2 === 1 });
    if (has("bass")) E.riff(G, w, t, cut, v);
    if (!mine) E.lead(G, w, t, sp.half, cut, 0, v);
    if (has("counter")) E.counter(G, w, t, sp.half, cut);
    if (has("spark")) E.sparkle(G, w, t, cut);
    if (sp.fill) { E.fill(G, sp.fill, t + 3 * G.beat); E.riser(G, sp.fill, t + 3 * G.beat, G.beat); }
  };

  // 게임용 겹(STEMS) 두 마디: 변주 v. 하이햇은 기본 8분만, 킥 4박 겹은 2 · 4박 킥과 열린 하이햇 · 16분 잔박을 함께 가짐
  E.STEMS = ["bed", "light", "kick", "lead", "hat", "perc", "kick4", "bass", "counter", "spark"];
  E.stem = function (G, w, name, t, v) {
    for (let h = 0; h < 2; h++) {
      const tb = t + h * G.bar;
      switch (name) {
        case "bed": if (h === 0) E.bed(G, w, tb, 2 * G.bar, 1); break;
        case "light": E.perc(G, w, tb, { light: true }); break;
        case "kick": for (const b of [0, 2]) kick(G, tb + b * G.beat, b === 0 ? 0.9 : vary(0.76, 0.06), G.kick); break;
        case "lead": E.lead(G, w, tb, h, 4, 0, v); break;
        case "hat": E.hats(G, w, tb, 1, 4); break;
        case "perc": E.perc(G, w, tb, { tail: h === 1 && v % 2 === 1 }); break;
        case "kick4":
          for (const b of [1, 3]) kick(G, tb + b * G.beat, vary(0.76, 0.06), G.kick4);
          for (let s = 1; s < 16; s++) {
            const ts = tb + s * G.s16 + sw(G, w, s) + hum(6), acc = vary(1, 0.15);
            if (s % 4 === 2) hat(G, ts, 0.09 * acc, true);
            else if (s % 2 === 1) hat(G, ts, 0.03 * acc, false);
          }
          break;
        case "bass": E.riff(G, w, tb, 4, v); break;
        case "counter": E.counter(G, w, tb, h, 4); break;
        case "spark": E.sparkle(G, w, tb, 4); break;
      }
    }
  };
  // 전투 끝맺음(이김): 한 박 앞 꾸밈음(솔)에서 첫 박 도로. 앞 악기 두 옥타브 · 맞받는 악기 · 낮은 북 · 종
  E.ending = function (G, w, t) {
    E.inst(G, w, w.lead, t - G.beat / 2, 67, 0.5, G.beat / 2, G.lead);
    E.inst(G, w, w.lead, t, 60, 0.7, G.bar, G.lead);
    E.inst(G, w, w.lead, t + 0.012, 72, 0.6, G.bar, G.lead);
    E.inst(G, w, w.counter, t + G.beat / 4, 84, 0.45, G.beat * 2, G.counter);
    kick(G, t, 0.9, G.kick);
    drum(G, t, G.perc, 70, 40, 0.3, 0.6, 1.2);
    partials(G, t, hz(96), G.fx, [[1, 1, 2.2], [2.4, 0.3, 1.2], [4.1, 0.12, 0.5]], 0.12, 0.004);
  };

  // 오프라인 굽기: schedule(G, t0)로 짠 것을 그대로 렌더링해 AudioBuffer로
  E.render = function (seconds, bpm, schedule, sr, bake) {
    const oc = new OfflineAudioContext(2, Math.ceil(seconds * (sr || 44100)), sr || 44100);
    const G = E.build(oc, bpm, bake);
    schedule(G, 0.05);
    return oc.startRendering();
  };
  return E;
})();
