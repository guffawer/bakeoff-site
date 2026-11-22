(() => {
  'use strict';

  const T = window.Timeline, Sound = window.Sound;
  const W = 360, H = 640, RAIL = 72, REACH = 288, FLASH = 0.25, SPARKS = 60, SPARK_LIFE = 0.45;
  const clamp = (v) => Math.max(0, Math.min(1, v));

  // Sprite sizes in stage units. The two packs have different proportions.
  const LOOKS = {
    a: {
      bumper: [T.BUMPER * 2.4, T.BUMPER * 2], bar: [62, 17.2], well: [80, 80], cup: [62, 25.8],
      booster: { w: 60, h: 52.5, dx: 30, dy: 23, flip: true },
    },
    b: {
      bumper: [T.BUMPER * 2, T.BUMPER * 2], bar: [62, 17.2], well: [80, 80], cup: [46, 27],
      booster: { w: 64, h: 22.4, dx: 32, dy: 0, flip: false },
    },
  };

  const look = document.body.dataset.look, size = LOOKS[look];
  const query = new URLSearchParams(location.search);
  const frozen = query.has('t') ? Number(query.get('t')) : null;
  const canvas = document.querySelector('canvas'), ctx = canvas.getContext('2d', { alpha: false });
  const back = document.createElement('canvas'), bc = back.getContext('2d', { alpha: false });
  const fpsLabel = document.querySelector('output'), soundButton = document.querySelector('[data-sound]');
  const art = {};

  let dpr = Math.min(devicePixelRatio || 1, 2);
  let width, height, scale, ox, oy, epoch = 0, previous = 0;
  let frames = 0, elapsed = 0, slow = 0, trial = null, locked = false;

  function draw(g, name, x, y, w, h = w, angle = 0, flip = false) {
    if (!angle && !flip) return g.drawImage(art[name], x - w / 2, y - h / 2, w, h);
    g.save(); g.translate(x, y); g.rotate(angle);
    if (flip) g.scale(-1, 1);
    g.drawImage(art[name], -w / 2, -h / 2, w, h);
    g.restore();
  }

  // Shadow sprites carry 28 px of padding around the full-size part.
  function shadow(g, kind, name, x, y, w, h, angle = 0, flip = false) {
    const img = art[name];
    draw(g, `shadow-${kind}`, x + 4, y + 7, w * (1 + 56 / img.width), h * (1 + 56 / img.height), angle, flip);
  }

  function fixed(g, kind, x, y, w, h, angle = 0, flip = false) {
    shadow(g, kind, kind, x, y, w, h, angle, flip);
    draw(g, kind, x, y, w, h, angle, flip);
  }

  function resize() {
    width = innerWidth; height = innerHeight;
    canvas.width = back.width = Math.round(width * dpr);
    canvas.height = back.height = Math.round(height * dpr);
    // Keep every part clear of the 72 px that Shorts and Reels use on the right, even on 320 px phones.
    scale = Math.min(width / W, height / H, (width - RAIL) / REACH);
    ox = Math.min((width - W * scale) / 2, width - RAIL - REACH * scale); oy = (height - H * scale) / 2;

    // Everything that never moves is baked into one layer, soft shadows included.
    bc.setTransform(1, 0, 0, 1, 0, 0);
    const cover = Math.max(back.width / art.bg.width, back.height / art.bg.height);
    const w = art.bg.width * cover, h = art.bg.height * cover;
    bc.drawImage(art.bg, (back.width - w) / 2, (back.height - h) / 2, w, h);
    bc.setTransform(scale * dpr, 0, 0, scale * dpr, ox * dpr, oy * dpr);

    // The route preview is UI, so Clip Mode bakes the layer without it.
    if (!document.body.classList.contains('clip')) {
      bc.globalAlpha = 0.28;
      for (const p of T.guide) draw(bc, 'glow-w', p.x, p.y, 7);
      bc.globalAlpha = 1;
    }

    for (const p of T.parts) {
      if (p.t === 0.5) continue; // the part that gets placed at the start of the loop
      const name = `${p.part}-${p.note}`, [pw, ph] = size[p.part];
      shadow(bc, p.part, name, p.x, p.y, pw, ph, p.angle);
      draw(bc, name, p.x, p.y, pw, ph, p.angle);
    }
    const b = size.booster;
    fixed(bc, 'booster', T.NOZZLE.x + b.dx, T.NOZZLE.y + b.dy, b.w, b.h, 0, b.flip);
    shadow(bc, 'well', 'well', T.WELL.x, T.WELL.y, ...size.well);

    const c = T.CRADLE, mid = c.x + ((c.count - 1) * c.gap) / 2, span = (c.count - 1) * c.gap + 44;
    for (const x of [mid - span / 2 + 3, mid + span / 2 - 3]) fixed(bc, 'post', x, c.pivot + 38, 7, 86);
    fixed(bc, 'beam', mid, c.pivot, span + 8, (span + 8) * 0.12);
    shadow(bc, 'bumper', 'bumper-c', T.FINALE.x, T.FINALE.y, size.bumper[0] * 0.8, size.bumper[1] * 0.8);
    draw(bc, 'bumper-c', T.FINALE.x, T.FINALE.y, size.bumper[0] * 0.8, size.bumper[1] * 0.8);
  }

  function placedPart(t) {
    const p = T.parts[0], [w, h] = size.bumper, u = clamp(t / 0.3), away = (1 - u) ** 3;
    const x = p.x + away * 48, y = p.y + away * 34, grow = 1 + away * 0.3;
    ctx.globalAlpha = Math.min(clamp(t / 0.1), clamp((T.LOOP - t) / 0.15));
    shadow(ctx, 'bumper', 'bumper-c', x, y, w * grow, h * grow, p.angle * u);
    draw(ctx, 'bumper-c', x, y, w * grow, h * grow, p.angle * u);
    ctx.globalAlpha = 1;
  }

  function cradle(t) {
    const c = T.CRADLE, d = T.BALL * 2;
    for (let i = 0; i < c.count; i++) {
      const a = T.swing(i, t), x0 = c.x + i * c.gap, x = x0 + Math.sin(a) * c.length, y = c.pivot + Math.cos(a) * c.length;
      draw(ctx, 'wire', (x0 + x) / 2, (c.pivot + y) / 2, 2, c.length, -a);
      shadow(ctx, 'ball', 'ball', x, y, d, d);
      draw(ctx, 'ball', x, y, d, d);
    }
  }

  function ball(t) {
    const d = T.BALL * 2;
    let p = T.ball(t);
    if (!p) return;
    ctx.globalCompositeOperation = 'lighter';
    for (let i = 8; i > 0; i--) {
      const q = T.ball(t - i * 0.016);
      if (t - i * 0.016 < 0 || !q) continue;
      ctx.globalAlpha = 0.16 * (1 - i / 9);
      draw(ctx, 'glow-w', q.x, q.y, d * 1.5);
    }
    ctx.globalCompositeOperation = 'source-over';
    ctx.globalAlpha = clamp(t / 0.15);
    shadow(ctx, 'ball', 'ball', p.x, p.y, d, d);
    draw(ctx, 'ball', p.x, p.y, d, d);
    ctx.globalAlpha = 1;
  }

  function effects(t) {
    ctx.globalCompositeOperation = 'lighter';
    let left = SPARKS;
    // Newest first, so the 60-spark budget goes to the latest hit.
    for (let h = T.hits.length - 1; h >= 0; h--) {
      const hit = T.hits[h], u = t - hit.t;
      if (u < 0 || u >= SPARK_LIFE) continue;
      const notes = hit.chord ? ['c', 'e', 'g'] : [hit.note];
      if (u < FLASH) {
        const k = u / FLASH;
        notes.forEach((n, i) => {
          // Normal blending keeps each pitch its own colour. Additive glows wash out to white.
          ctx.globalCompositeOperation = 'source-over';
          ctx.globalAlpha = (1 - k) * 0.8;
          if (!hit.chord) draw(ctx, `glow-${n}`, hit.x, hit.y, 46 + k * 40);
          ctx.globalAlpha = 1 - k;
          draw(ctx, `ring-${n}`, hit.x, hit.y, 28 + i * 34 + k * (90 + i * 50));
          ctx.globalCompositeOperation = 'lighter';
        });
      }
      const count = Math.min(left, hit.chord ? 48 : 14), k = u / SPARK_LIFE;
      left -= count;
      ctx.globalAlpha = (1 - k) ** 1.4;
      for (let i = 0; i < count; i++) {
        const a = i * 2.399963 + h, far = (22 + ((i * 19) % 38)) * (hit.chord ? 1.9 : 1) * (1 - (1 - k) ** 3);
        draw(ctx, `spark-${notes[i % notes.length]}`, hit.x + Math.cos(a) * far, hit.y + Math.sin(a) * far + 45 * k * k, 10 + (i % 4) * 3);
      }
    }
    ctx.globalAlpha = 1; ctx.globalCompositeOperation = 'source-over';
  }

  function render(t) {
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.drawImage(back, 0, 0);
    ctx.setTransform(scale * dpr, 0, 0, scale * dpr, ox * dpr, oy * dpr);
    placedPart(t);
    const whirl = t >= 3 && t < 3.5 ? -(t - 3) * Math.PI * 8 : 0;
    draw(ctx, 'well', T.WELL.x, T.WELL.y, size.well[0], size.well[1], whirl);
    cradle(t);
    ball(t);
    // Drawn over the ball, so it drops inside.
    draw(ctx, 'cup', T.CUP.x - 14, T.CUP.y + 2, ...size.cup);
    effects(t);
  }

  function adapt(fps) {
    if (locked) return;
    if (trial) {
      if (++trial.seconds < 3) return;
      if (fps < trial.fps + 3) { dpr = trial.dpr; locked = true; resize(); } // a frame cap, not a slow GPU
      trial = null; slow = 0;
      return;
    }
    slow = fps < 54 ? slow + 1 : 0;
    if (slow < 3 || dpr <= 1) return;
    trial = { fps, dpr, seconds: 0 };
    dpr = Math.max(1, dpr - 0.5);
    resize();
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

  function frame(now) {
    measure(now);
    const seconds = frozen ?? Sound.time() ?? Math.max(0, (now - epoch) / 1000);
    render(seconds % T.LOOP);
    requestAnimationFrame(frame);
  }

  function restart() {
    epoch = performance.now();
    Sound.restart();
  }

  async function sound(on) {
    try {
      if (on) await Sound.enable(); else Sound.disable();
      epoch = performance.now();
      soundButton.textContent = Sound.on ? 'Mute' : 'Sound';
    } catch (error) {
      soundButton.textContent = 'No audio';
      console.error(error);
    }
  }

  function controls() {
    soundButton.addEventListener('click', (e) => { e.stopPropagation(); sound(!Sound.on); });
    document.querySelector('[data-clip]').addEventListener('click', async (e) => {
      e.stopPropagation();
      document.body.classList.add('clip');
      resize();
      if (!Sound.on) await sound(true); // clips need the music
      restart();
    });
    document.addEventListener('click', () => {
      if (!document.body.classList.contains('clip')) return;
      document.body.classList.remove('clip');
      resize();
      restart();
    });
  }

  // Mobile connections drop requests. One lost sprite must not stop the game loading.
  async function image(src) {
    for (let attempt = 0; attempt < 4; attempt++) {
      if (attempt) await new Promise((r) => setTimeout(r, 250 * 2 ** attempt));
      const img = new Image();
      const ok = await new Promise((r) => {
        img.onload = () => r(true);
        img.onerror = () => r(false);
        img.src = attempt ? `${src}?retry=${attempt}` : src;
      });
      if (ok) return img;
    }
    throw new Error(`Could not load ${src}. Reload the page.`);
  }

  async function start() {
    const own = ['bg', 'ball', 'well', 'booster', 'beam', 'post', 'cup'];
    for (const n of 'ceg') own.push(`bumper-${n}`, `bar-${n}`);
    for (const k of ['ball', 'well', 'booster', 'beam', 'post', 'bumper', 'bar']) own.push(`shadow-${k}`);
    const common = ['wire'];
    for (const k of ['glow', 'spark', 'ring']) for (const n of 'cegw') common.push(`${k}-${n}`);
    const all = [...own.map((n) => [n, `assets/${n}.webp`]), ...common.map((n) => [n, `../shared/assets/${n}.webp`])];
    await Promise.all(all.map(async ([name, src]) => { art[name] = await image(src); }));
    Sound.preload();
    if (query.has('clip')) document.body.classList.add('clip');
    resize();
    addEventListener('resize', resize);
    controls();
    epoch = previous = performance.now();
    requestAnimationFrame(frame);
    document.body.dataset.ready = '1';
  }

  start().catch((error) => { document.querySelector('.head p').textContent = error.message; });
})();
