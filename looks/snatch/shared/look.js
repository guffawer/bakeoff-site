// Snatch Block look test: a scripted 5 s loop of the snap. It is a design artefact, not game code.
(() => {
  'use strict';

  const LOOP = 5, SNAP = 3.2, WHIP = 0.4, SPLATS = 24, SEGMENTS = 12, RAIL = 72;
  const WORLD = { x: -60, y: -180, w: 460, h: 980 };   // area covered by the baked terrain
  const SCENE = { top: 120, bottom: 414, right: 288 };  // what must stay inside the safe area
  const clamp = (v) => Math.max(0, Math.min(1, v));
  const mix = (a, b, k) => a + (b - a) * k;
  const ease = (v) => 1 - (1 - clamp(v)) ** 3;

  const look = document.body.dataset.look;
  const anchor = look === 'a'
    ? { x: 242, y: 176, w: 84, h: 54, eye: { x: 238, y: 163 } }
    : { x: 244, y: 166, w: 79, h: 51, eye: { x: 234, y: 160 } };
  const query = new URLSearchParams(location.search);
  const frozen = query.has('t') ? Number(query.get('t')) : null;
  const stage = document.querySelector('.stage'), canvas = document.querySelector('canvas');
  const ctx = canvas.getContext('2d', { alpha: false });
  const back = document.createElement('canvas'), bc = back.getContext('2d', { alpha: false });
  const gauge = document.querySelector('.gauge'), bar = gauge.querySelector('i');
  const loadText = gauge.querySelector('[data-load]'), stateText = gauge.querySelector('.state');
  const fpsText = document.querySelector('.fps'), soundButton = document.querySelector('[data-sound]');
  const art = {};

  let dpr = Math.min(devicePixelRatio || 1, 2);
  let width, height, scale, ox, oy, epoch = 0, previous = 0, frames = 0, elapsed = 0, shown = '';
  let ac = null, source = null, soundFile = null, buffer = null, origin = 0, skew = null, on = false;

  function tension(t) {
    const keys = [[0, 0.06], [0.3, 0.16], [1.2, 0.55], [2.2, 0.88], [3.0, 0.985], [SNAP, 1.03]];
    if (t >= SNAP) return t > 4.6 ? 0.06 * ((t - 4.6) / 0.4) : 0;
    let i = 0;
    while (t > keys[i + 1][0]) i++;
    const [t0, v0] = keys[i], [t1, v1] = keys[i + 1];
    return mix(v0, v1, (t - t0) / (t1 - t0));
  }

  function diggerPose(t, load) {
    const pulled = t < SNAP ? load : 1.03 * (1 - ease((t - SNAP) / 0.3));
    const shake = t < SNAP ? Math.max(0, load - 0.6) * 3.2 : 0;
    const drop = t >= SNAP && t < SNAP + 0.5 ? Math.sin(((t - SNAP) / 0.5) * Math.PI) * 4 : 0;
    return {
      x: 190 - pulled * 11 + Math.sin(t * 61) * shake * 0.6,
      y: 349 - pulled * 4 + drop + Math.cos(t * 53) * shake * 0.5,
      angle: 0.12 - pulled * 0.07, w: 190, h: 100,
    };
  }

  // A point on a sprite, given as fractions of its width and height.
  function spritePoint(pose, u, v) {
    const dx = (u - 0.5) * pose.w, dy = (v - 0.5) * pose.h, c = Math.cos(pose.angle), s = Math.sin(pose.angle);
    return { x: pose.x + dx * c - dy * s, y: pose.y + dx * s + dy * c };
  }

  function put(g, name, x, y, w, h = w, angle = 0) {
    if (!angle) return g.drawImage(art[name], x - w / 2, y - h / 2, w, h);
    g.save(); g.translate(x, y); g.rotate(angle);
    g.drawImage(art[name], -w / 2, -h / 2, w, h);
    g.restore();
  }

  function span(a, b, sag) {
    const points = [];
    for (let i = 0; i <= SEGMENTS; i++) {
      const k = i / SEGMENTS;
      points.push({ x: mix(a.x, b.x, k), y: mix(a.y, b.y, k) + sag * 4 * k * (1 - k) });
    }
    return points;
  }

  // A broken end recoils to the hanging position, with a wave running along it.
  function broken(fixed, loose, rest, u) {
    const k = ease(u / WHIP), wave = Math.max(0, 1 - u / WHIP);
    const end = { x: mix(loose.x, rest.x, k), y: mix(loose.y, rest.y, k) - Math.sin(k * Math.PI) * 48 };
    const length = Math.hypot(end.x - fixed.x, end.y - fixed.y) || 1;
    const nx = -(end.y - fixed.y) / length, ny = (end.x - fixed.x) / length;
    return span(fixed, end, 12 * k).map((p, i) => {
      const f = i / SEGMENTS, amp = wave * f * 17 * Math.sin(f * 5.2 - u * 28);
      return { x: p.x + nx * amp, y: p.y + ny * amp };
    });
  }

  function line(points, dx = 0, dy = 0) {
    ctx.beginPath();
    ctx.moveTo(points[0].x + dx, points[0].y + dy);
    for (let i = 1; i < points.length; i++) ctx.lineTo(points[i].x + dx, points[i].y + dy);
  }

  // Three layers, as in the Godot Line2D spec: shadow, base, scrolling lay pattern.
  function rope(points, scroll, thick = 4.5) {
    ctx.lineCap = 'round'; ctx.lineJoin = 'round';
    line(points, 1.8, 3.2);
    ctx.lineWidth = thick + 1; ctx.strokeStyle = 'rgba(0,0,0,.42)'; ctx.stroke();
    line(points);
    ctx.lineWidth = thick; ctx.strokeStyle = '#E8601C'; ctx.stroke();

    const img = art.rope, period = img.width / 2, k = img.height / thick;
    let along = 0;
    for (let i = 0; i < points.length - 1; i++) {
      const a = points[i], b = points[i + 1], dx = b.x - a.x, dy = b.y - a.y, length = Math.hypot(dx, dy);
      if (length < 0.5) continue;
      const from = (((along - scroll) * k) % period + period) % period;
      ctx.save(); ctx.translate(a.x, a.y); ctx.rotate(Math.atan2(dy, dx));
      ctx.drawImage(img, from, 0, Math.min(length * k, period), img.height, 0, -thick / 2, length + 0.4, thick);
      ctx.restore();
      along += length;
    }
  }

  function rigging(t, load, pose) {
    const slack = t < SNAP ? Math.max(0, 1 - load / 0.45) : 1;
    const winch = { x: 72, y: 277 }, bucket = spritePoint(pose, 0.07, 0.62);
    const boom = spritePoint(pose, 0.22, 0.22), rear = spritePoint(pose, 0.9, 0.62);
    const hitch = { x: 134, y: 180 }, scroll = t < SNAP ? t * 5 + load * 14 : 0;
    const block = { x: 176, y: 250 - Math.min(1, load) * 6 };
    const top = { x: block.x, y: block.y - 12 };

    rope(span(winch, bucket, 4 + slack * 26), scroll);       // winch line
    rope(span(anchor.eye, rear, 22 + slack * 10), 0, 4);     // holdback line

    const rerig = clamp((t - 4.6) / 0.4);
    if (t < SNAP) {
      rope(span(hitch, top, slack * 20), scroll);            // main line, rove 2:1 through the block
      rope(span(top, anchor.eye, slack * 20), scroll);
      rope(span({ x: block.x, y: block.y + 21 }, boom, slack * 8), 0);
      put(ctx, 'block', block.x, block.y + 2, 24, 48, (load > 0.85 ? Math.sin(t * 70) * 0.03 : 0));
      return;
    }
    const u = t - SNAP, fall = ease(u / WHIP);
    ctx.globalAlpha = 1 - rerig;
    rope(broken(hitch, top, { x: 116, y: 250 }, u), 0);
    rope(broken(anchor.eye, top, { x: 250, y: 226 }, u), 0);
    const fallen = { x: mix(block.x, boom.x + 14, fall), y: mix(block.y, boom.y + 18, fall) };
    rope(broken(boom, { x: block.x, y: block.y + 21 }, fallen, u), 0);
    put(ctx, 'block', fallen.x, fallen.y, 24, 48, fall * 1.9);

    if (rerig > 0) {
      ctx.globalAlpha = rerig;
      const reset = { x: 176, y: 250 }, resetTop = { x: 176, y: 238 };
      rope(span(hitch, resetTop, 18), 0);
      rope(span(resetTop, anchor.eye, 18), 0);
      rope(span({ x: 176, y: 271 }, boom, 7), 0);
      put(ctx, 'block', reset.x, reset.y + 2, 24, 48);
    }
    ctx.globalAlpha = 1;
  }

  function mud(t) {
    const u = t - SNAP - 0.08;
    if (u < 0 || u > 0.9) return;
    for (let i = 0; i < SPLATS; i++) {
      const a = -Math.PI * (0.12 + 0.76 * ((i * 0.618034) % 1)), speed = 120 + ((i * 37) % 150);
      ctx.globalAlpha = clamp((0.9 - u) / 0.35);
      put(ctx, `splat${i % 3}`, 222 + (i % 7) * 11 - 33 + Math.cos(a) * speed * u, 388 + Math.sin(a) * speed * u + 260 * u * u, 9 + (i % 5) * 3.5, undefined, i);
    }
    ctx.globalAlpha = 1;
  }

  function exhaust(t, load) {
    for (let i = 0; i < 5; i++) {
      const u = (t * 1.2 + i / 5) % 1;
      ctx.globalAlpha = (1 - u) * (0.2 + load * 0.35);
      put(ctx, 'smoke', 119 + u * 16, 148 - u * 48, 8 + u * 30);
    }
    ctx.globalAlpha = 1;
  }

  function hud(load) {
    const kind = load >= 0.9 ? 'limit' : load >= 0.7 ? 'warn' : '';
    bar.style.transform = `scaleX(${Math.min(1, load)})`;
    const snapped = kind === '' && load === 0;
    const key = `${(load * 12).toFixed(1)}|${kind}|${snapped}`;
    if (key === shown) return;
    shown = key;
    loadText.textContent = (load * 12).toFixed(1);
    gauge.classList.toggle('warn', kind === 'warn');
    gauge.classList.toggle('limit', kind === 'limit');
    stateText.textContent = snapped ? 'LINE PARTED' : kind === 'limit' ? 'NEAR LIMIT' : kind === 'warn' ? 'HIGH LOAD' : 'TAKING UP';
  }

  function render(t) {
    const load = tension(t), u = t - SNAP;
    const kick = u >= 0 && u < 0.3 ? (1 - u / 0.3) * 4 : 0;
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.drawImage(back, 0, 0);
    ctx.setTransform(scale * dpr, 0, 0, scale * dpr, (ox + Math.sin(t * 90) * kick) * dpr, (oy + Math.cos(t * 77) * kick) * dpr);

    const idle = Math.sin(t * Math.PI * 14) * 0.35;
    put(ctx, 'loader', 76 - (t < SNAP ? load * 3 : 3 * (1 - ease(u / 0.5))), 175 + idle, 126, 54, t < SNAP ? -load * 0.025 : 0);
    exhaust(t, load);
    const pose = diggerPose(t, load);
    put(ctx, 'digger', pose.x, pose.y, pose.w, pose.h, pose.angle);
    ctx.drawImage(art.pit, 120, 350, 230, 110);
    rigging(t, load, pose);
    mud(t);
    hud(load);
  }

  function resize() {
    width = stage.clientWidth; height = stage.clientHeight;
    canvas.width = back.width = Math.round(width * dpr);
    canvas.height = back.height = Math.round(height * dpr);

    const clip = document.body.classList.contains('clip'), sceneHeight = SCENE.bottom - SCENE.top;
    const top = clip ? height * 0.06 : gauge.offsetTop + gauge.offsetHeight + 4;
    const bottom = clip ? height * 0.75 : height * 0.75 - 68;
    scale = Math.min((width - RAIL) / SCENE.right, (bottom - top) / sceneHeight);
    ox = Math.max(0, (width - RAIL - SCENE.right * scale) / 2);
    // Sit the action low, next to the rig buttons, with sky above it.
    oy = top + (bottom - top - sceneHeight * scale) * 0.7 - SCENE.top * scale;

    bc.setTransform(1, 0, 0, 1, 0, 0);
    bc.fillStyle = getComputedStyle(document.body).getPropertyValue('--mud');
    bc.fillRect(0, 0, back.width, back.height);
    bc.setTransform(scale * dpr, 0, 0, scale * dpr, ox * dpr, oy * dpr);
    bc.drawImage(art.bg, WORLD.x, WORLD.y, WORLD.w, WORLD.h);
    put(bc, 'shadow', 78, 200, 136, 20);
    put(bc, 'shadow', 40, 297, 84, 16);
    put(bc, 'shadow', anchor.x, 191, 100, 18);
    put(bc, 'winch', 40, 275, 72, 43.2);
    put(bc, 'anchor', anchor.x, anchor.y, anchor.w, anchor.h);
  }

  // The audio clock moves in steps on Android, so follow it with a smoothed offset.
  function seconds(now) {
    if (!on || ac.state !== 'running') return Math.max(0, (now - epoch) / 1000);
    const measured = now / 1000 - (ac.currentTime - origin - (ac.outputLatency || ac.baseLatency || 0));
    skew = skew === null || Math.abs(measured - skew) > 0.08 ? measured : skew + (measured - skew) * 0.05;
    return Math.max(0, now / 1000 - skew);
  }

  function restart() {
    epoch = performance.now();
    if (!on) return;
    source?.stop();
    source = ac.createBufferSource();
    source.buffer = buffer; source.loop = true;
    source.connect(ac.destination);
    origin = ac.currentTime + 0.06; skew = null;
    source.start(origin);
  }

  async function sound(wanted) {
    try {
      if (wanted) {
        if (navigator.audioSession) navigator.audioSession.type = 'playback';
        if (!ac) {
          ac = new (window.AudioContext || window.webkitAudioContext)();
          document.addEventListener('visibilitychange', () => {
            if (document.hidden) ac.suspend();
            else if (on) ac.resume();
          });
        }
        await ac.resume();
        soundFile ||= fetch('../shared/assets/hook.wav').then((r) => { if (!r.ok) throw new Error(r.status); return r.arrayBuffer(); });
        buffer ||= await ac.decodeAudioData((await soundFile).slice(0));
        on = true;
      } else {
        on = false; source?.stop(); source = null;
      }
      restart();
      soundButton.textContent = on ? 'Mute' : 'Sound';
    } catch (error) {
      soundFile = null; soundButton.textContent = 'No audio';
      console.error(error);
    }
  }

  function controls() {
    soundButton.addEventListener('click', (e) => { e.stopPropagation(); sound(!on); });
    document.querySelector('[data-clip]').addEventListener('click', async (e) => {
      e.stopPropagation();
      document.body.classList.add('clip');
      resize();
      if (on) restart(); else await sound(true);
    });
    document.addEventListener('click', () => {
      if (!document.body.classList.contains('clip')) return;
      document.body.classList.remove('clip');
      resize(); restart();
    });
    addEventListener('resize', resize);
  }

  function frame(now) {
    const dt = now - previous;
    previous = now;
    if (dt > 0 && dt < 250) {
      frames++; elapsed += dt;
      if (elapsed >= 1000) { fpsText.value = `${Math.round((frames * 1000) / elapsed)} fps`; frames = elapsed = 0; }
    }
    render((frozen ?? seconds(now)) % LOOP);
    requestAnimationFrame(frame);
  }

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
    const own = ['bg', 'pit', 'digger', 'loader', 'winch', 'block', 'anchor', 'splat0', 'splat1', 'splat2'];
    const all = [...own.map((n) => [n, `assets/${n}.webp`]), ...['rope', 'shadow', 'smoke'].map((n) => [n, `../shared/assets/${n}.webp`])];
    await Promise.all([document.fonts.ready, ...all.map(async ([name, src]) => { art[name] = await image(src); })]);
    if (query.has('clip')) document.body.classList.add('clip');
    resize(); controls();
    epoch = previous = performance.now();
    requestAnimationFrame(frame);
    document.body.dataset.ready = '1';
  }

  start().catch((error) => { document.querySelector('.dock p').textContent = error.message; });
})();
