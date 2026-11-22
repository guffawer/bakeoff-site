// Orbital Dance look test: a seamless 5 s loop of the hook moment.
// This is an analytic animation for choosing art. The game itself uses velocity Verlet.
(() => {
  'use strict';

  const LOOP = 5, W = 360, H = 640, TAU = Math.PI * 2;
  const CENTRE = { x: 150, y: 276 };          // inside the Shorts/Reels safe area
  const BINARY = { x: 72, y: 436, orbit: 22 };
  const NEUTRON = { x: 236, y: 92 };
  const LAUNCH = 0.4, COMPLETE = 3.6, BURST = 0.7;
  const POINTS = 600, SPARKS = 120, BOX = 284;

  const look = document.body.dataset.look;
  const query = new URLSearchParams(location.search);
  const frozen = query.has('t') ? Number(query.get('t')) : null;
  const canvas = document.querySelector('canvas');
  const ctx = canvas.getContext('2d', { alpha: false });
  const trail = document.createElement('canvas'), tc = trail.getContext('2d');
  const back = document.createElement('canvas'), bc = back.getContext('2d', { alpha: false });
  const fpsLabel = document.querySelector('output');
  const credit = document.querySelector('.credit');
  const calm = matchMedia('(prefers-reduced-motion: reduce)').matches;
  const clamp = (v) => Math.max(0, Math.min(1, v));
  const ease = (v) => 1 - (1 - clamp(v)) ** 3;

  // Precessing orbit r = p / (1 + e cos(7θ/4)). It closes after four turns with seven petals.
  // Time follows r² dθ, so the probe whips round the black hole and slows at each petal tip.
  const path = [];
  let total = 0;
  for (let i = 0; i < POINTS; i++) {
    const a = (i / (POINTS - 1)) * 4 * TAU;
    const r = 63 / (1 - 0.5 * Math.cos(1.75 * a));
    if (i) total += r * r;
    path.push({ x: CENTRE.x + r * Math.cos(a + Math.PI / 2), y: CENTRE.y + r * Math.sin(a + Math.PI / 2), at: total });
  }
  for (const p of path) p.at /= total;

  const sparks = Array.from({ length: SPARKS }, (_, i) => {
    const from = path[i * 5], a = i * 2.399963;
    return { x: from.x, y: from.y, dx: Math.cos(a), dy: Math.sin(a), far: 30 + ((i * 37) % 90), size: 14 + ((i * 13) % 22), warm: i % 3 === 0 };
  });

  const art = {};
  let dpr = Math.min(devicePixelRatio || 1, 2);
  let width, height, scale, ox, oy, drawn = 0, epoch = 0, previous = 0;
  let frames = 0, elapsed = 0, slow = 0, trial = null, locked = false;

  function resize() {
    width = innerWidth; height = innerHeight;
    canvas.width = back.width = Math.round(width * dpr);
    canvas.height = back.height = Math.round(height * dpr);
    scale = Math.min(width / W, height / H);
    ox = (width - W * scale) / 2;
    oy = (height - H * scale) / 2;

    // The photograph is scaled once here, then copied 1:1 every frame.
    const cover = Math.max(back.width / art.bg.width, back.height / art.bg.height);
    const w = art.bg.width * cover, h = art.bg.height * cover;
    bc.drawImage(art.bg, (back.width - w) / 2, (back.height - h) / 2, w, h);

    trail.width = trail.height = Math.ceil(BOX * scale * dpr);
    drawn = 0;
  }

  function clearTrail() {
    tc.setTransform(1, 0, 0, 1, 0, 0);
    tc.clearRect(0, 0, trail.width, trail.height);
    drawn = 0;
  }

  // Trail segments are baked into a layer. 'lighten' stops the halo beading at the joins.
  function extendTrail(progress) {
    let end = drawn;
    while (end + 1 < POINTS && path[end + 1].at <= progress) end++;
    if (end === drawn) return;
    const k = trail.width / BOX;
    tc.setTransform(k, 0, 0, k, -(CENTRE.x - BOX / 2) * k, -(CENTRE.y - BOX / 2) * k);
    tc.globalCompositeOperation = 'lighten';
    tc.lineCap = tc.lineJoin = 'round';
    tc.beginPath();
    tc.moveTo(path[drawn].x, path[drawn].y);
    for (let i = drawn + 1; i <= end; i++) tc.lineTo(path[i].x, path[i].y);
    for (const [w, colour] of [[14, '#02151B'], [10, '#05252E'], [6.5, '#0B4454'], [4, '#1A86A0'], [2.3, '#A5F2FF']]) {
      tc.lineWidth = w; tc.strokeStyle = colour; tc.stroke();
    }
    drawn = end;
  }

  function probeAt(progress) {
    let i = drawn;
    while (i + 1 < POINTS && path[i + 1].at < progress) i++;
    const a = path[i], b = path[Math.min(i + 1, POINTS - 1)];
    const k = b.at > a.at ? clamp((progress - a.at) / (b.at - a.at)) : 0;
    return { x: a.x + (b.x - a.x) * k, y: a.y + (b.y - a.y) * k };
  }

  function sprite(img, x, y, w, h = w) { ctx.drawImage(img, x - w / 2, y - h / 2, w, h); }

  function turned(img, x, y, w, h, angle) {
    ctx.save(); ctx.translate(x, y); ctx.rotate(angle);
    ctx.drawImage(img, -w / 2, -h / 2, w, h);
    ctx.restore();
  }

  function discHalf(front, angle) {
    ctx.save();
    ctx.translate(CENTRE.x, CENTRE.y); ctx.rotate(-0.22); ctx.scale(1, 0.42);
    ctx.beginPath(); ctx.rect(-80, front ? 0 : -80, 160, 80); ctx.clip();
    ctx.rotate(angle);
    ctx.drawImage(art.disc, -76, -76, 152, 152);
    ctx.restore();
  }

  function blackHole(t) {
    const spin = (t / LOOP) * TAU;
    ctx.globalCompositeOperation = 'lighter'; ctx.globalAlpha = 0.2;
    sprite(art['glow-disc'], CENTRE.x, CENTRE.y, 158);
    ctx.globalAlpha = 1; ctx.globalCompositeOperation = 'source-over';
    if (look === 'a') return sprite(art.hole, CENTRE.x, CENTRE.y, 146);
    discHalf(false, spin);
    sprite(art.hole, CENTRE.x, CENTRE.y, 80);
    discHalf(true, spin);
  }

  function stars(t) {
    const turn = (t / LOOP) * TAU * 2;
    for (const [sign, size] of [[1, 42], [-1, 30]]) {
      const x = BINARY.x + Math.cos(turn) * BINARY.orbit * sign;
      const y = BINARY.y + Math.sin(turn) * BINARY.orbit * 0.65 * sign;
      ctx.globalCompositeOperation = 'lighter'; ctx.globalAlpha = 0.6;
      sprite(art['glow-gold'], x, y, size * 2.4);
      ctx.globalCompositeOperation = 'source-over'; ctx.globalAlpha = 1;
      sprite(art.sun, x, y, size);
    }
    ctx.globalCompositeOperation = 'lighter';
    if (look === 'a') {
      turned(art.neutron, NEUTRON.x, NEUTRON.y, 72, 72, (t / LOOP) * TAU);
    } else {
      turned(art.jet, NEUTRON.x, NEUTRON.y, 34, 100, (t / LOOP) * TAU * 2);
      sprite(art.neutron, NEUTRON.x, NEUTRON.y, 64);
    }
  }

  function supernova(t) {
    const u = (t - COMPLETE) / BURST;
    if (u < 0 || u >= 1) return;
    const out = ease(u), left = 1 - u;
    ctx.globalAlpha = left * left * (calm ? 0.3 : 1);
    sprite(art.flare, CENTRE.x, CENTRE.y, 90 + out * 300);
    ctx.globalAlpha = left * 0.8;
    sprite(art.ring, CENTRE.x, CENTRE.y, 60 + out * 360);
    ctx.globalAlpha = left * 0.5;
    sprite(art.cloud, CENTRE.x, CENTRE.y, 100 + out * 190);
    ctx.globalAlpha = left;
    // The flare, ring and cloud count towards the 120-sprite budget.
    for (let i = 0; i < SPARKS - 3; i++) {
      const s = sparks[i];
      sprite(art[s.warm ? 'spark-gold' : 'spark-cyan'], s.x + s.dx * s.far * out, s.y + s.dy * s.far * out, s.size * (1 - u * 0.5));
    }
  }

  function render(t) {
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.globalCompositeOperation = 'source-over'; ctx.globalAlpha = 1;
    ctx.drawImage(back, 0, 0);
    ctx.setTransform(scale * dpr, 0, 0, scale * dpr, ox * dpr, oy * dpr);

    blackHole(t);
    stars(t);

    const progress = clamp((t - LAUNCH) / (COMPLETE - LAUNCH));
    if (drawn && path[drawn].at > progress) clearTrail();
    extendTrail(progress);
    ctx.globalCompositeOperation = 'lighter';
    const flash = t > COMPLETE && t < COMPLETE + 0.2;
    ctx.globalAlpha = 1 - clamp((t - 4.05) / 0.85);
    ctx.drawImage(trail, CENTRE.x - BOX / 2, CENTRE.y - BOX / 2, BOX, BOX);
    if (flash) ctx.drawImage(trail, CENTRE.x - BOX / 2, CENTRE.y - BOX / 2, BOX, BOX);

    ctx.globalAlpha = 1;
    if (t < LAUNCH) {
      // Pull back, release, launch.
      const pull = ease(t / 0.32) * (t < 0.32 ? 1 : (LAUNCH - t) / 0.08);
      const x = path[0].x + 56 * pull, y = path[0].y + 10 * pull;
      ctx.globalAlpha = pull;
      turned(art.pull, (x + path[0].x) / 2, (y + path[0].y) / 2, 22, 20 + 80 * pull, Math.PI / 2 + 0.18);
      ctx.globalAlpha = clamp(t / 0.12);
      sprite(art['glow-cyan'], x, y, 28);
      sprite(art['spark-cyan'], x, y, 32);
    } else if (t < COMPLETE) {
      const p = probeAt(progress);
      sprite(art['glow-cyan'], p.x, p.y, 30);
      sprite(art['spark-cyan'], p.x, p.y, 36);
    }

    supernova(t);
    ctx.globalAlpha = 1;
    if (credit) credit.classList.toggle('on', t >= COMPLETE);
  }

  function measure(now) {
    const dt = now - previous;
    previous = now;
    if (dt <= 0 || dt > 250) return;
    frames++; elapsed += dt;
    if (elapsed < 1000) return;
    const fps = (frames * 1000) / elapsed;
    fpsLabel.value = `${Math.round(fps)} fps`;
    frames = elapsed = 0;
    adapt(fps);
  }

  // Shed resolution only when that buys frames. Low Power Mode caps at 30 fps,
  // and dropping resolution there would just blur the picture.
  function adapt(fps) {
    if (locked) return;
    if (trial) {
      if (++trial.seconds < 3) return;
      if (fps < trial.fps + 3) { dpr = trial.dpr; locked = true; resize(); }
      trial = null; slow = 0;
      return;
    }
    slow = fps < 54 ? slow + 1 : 0;
    if (slow < 3 || dpr <= 1) return;
    trial = { fps, dpr, seconds: 0 };
    dpr = Math.max(1, dpr - 0.5);
    resize();
  }

  function frame(now) {
    measure(now);
    render(frozen ?? ((now - epoch) / 1000) % LOOP);
    requestAnimationFrame(frame);
  }

  function setClip(on) {
    document.body.classList.toggle('clip', on);
    epoch = performance.now();
    clearTrail();
  }

  async function start() {
    const own = look === 'a' ? ['bg', 'sun', 'hole', 'neutron'] : ['bg', 'sun', 'hole', 'neutron', 'disc', 'jet'];
    const common = ['glow-gold', 'glow-cyan', 'glow-disc', 'spark-gold', 'spark-cyan', 'flare', 'ring', 'cloud', 'pull'];
    const sources = [...own.map((n) => [n, `assets/${n}.webp`]), ...common.map((n) => [n, `../shared/assets/${n}.webp`])];
    await Promise.all(sources.map(([name, src]) => new Promise((done, fail) => {
      const img = new Image();
      img.onload = () => { art[name] = img; done(); };
      img.onerror = () => fail(new Error(`Could not load ${src}`));
      img.src = src;
    })));
    resize();
    addEventListener('resize', resize);
    document.querySelector('[data-clip]').addEventListener('click', (e) => { e.stopPropagation(); setClip(true); });
    document.addEventListener('click', () => { if (document.body.classList.contains('clip')) setClip(false); });
    setClip(query.has('clip'));
    previous = epoch;
    requestAnimationFrame(frame);
    document.body.dataset.ready = '1';
  }

  start().catch((error) => { document.querySelector('.title p').textContent = error.message; });
})();
