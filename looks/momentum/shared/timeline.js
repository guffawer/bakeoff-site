// The 5 s hook at 120 BPM. All times are seconds from the top of the loop and sit on the eighth-note grid.
// This is a choreographed look test. The game will simulate in Box2D at a fixed timestep.
window.Timeline = (() => {
  'use strict';

  const LOOP = 5, STEP = 0.25, GRAVITY = 700, BALL = 10, BUMPER = 25, BAR = 8.6;
  const START = { x: 36, y: 30 };
  const NOZZLE = { x: 228, y: 279 };
  const WELL = { x: 62, y: 398, r: 30 };
  const CRADLE = { x: 130, gap: 20, count: 5, pivot: 350, length: 60, swing: 0.45 };
  const CUP = { x: 124, y: 466 };
  const BELL_ANGLE = CRADLE.swing;
  const LAST = CRADLE.x + CRADLE.gap * (CRADLE.count - 1);
  const FINALE = { x: LAST + Math.sin(BELL_ANGLE) * CRADLE.length + 30, y: CRADLE.pivot + Math.cos(BELL_ANGLE) * CRADLE.length };

  const route = [
    { t: 0.00, ...START },
    { t: 0.50, x: 64, y: 132, note: 'c', part: 'bumper' },
    { t: 1.00, x: 148, y: 135, note: 'e', part: 'bumper' },
    { t: 1.50, x: 229, y: 108, note: 'g', part: 'bumper' },
    { t: 2.00, ...NOZZLE, note: 'c', part: 'booster' },
    { t: 2.25, x: 182, y: 289, note: 'c', part: 'bar', slide: 4 },
    { t: 2.50, x: 124, y: 303, note: 'e', part: 'bar', slide: -14 },
    { t: 2.75, x: 56, y: 310, note: 'g', part: 'bar', slide: 13 },
    { t: 3.00, x: WELL.x, y: WELL.y - WELL.r, note: 'e', part: 'well' },
    { t: 3.50, x: WELL.x, y: WELL.y + WELL.r, part: 'release' },
    { t: 3.75, x: CRADLE.x - 20, y: CRADLE.pivot + CRADLE.length, note: 'g', part: 'cradle' },
    { t: 4.00, x: CUP.x - 14, y: CUP.y - 8, part: 'cup' },
  ];

  const flights = route.slice(0, -1).map((a, i) => {
    const b = route[i + 1], d = b.t - a.t;
    return { a, b, d, vx: (b.x - a.x) / d, vy: (b.y - a.y) / d - 0.5 * GRAVITY * d };
  });

  // Put each bumper and bar exactly where it must be to give the bounce that is drawn.
  const parts = [];
  for (let i = 1; i < flights.length; i++) {
    const p = route[i];
    if (p.part !== 'bumper' && p.part !== 'bar') continue;
    const before = flights[i - 1], after = flights[i];
    let nx = after.vx - before.vx, ny = after.vy - (before.vy + GRAVITY * before.d);
    const n = Math.hypot(nx, ny);
    nx /= n; ny /= n;
    const reach = BALL + (p.part === 'bumper' ? BUMPER : BAR);
    // A bar can be struck off-centre: slide moves it along its own length, clear of the next flight.
    const slide = p.slide || 0;
    parts.push({ part: p.part, note: p.note, t: p.t, x: p.x - nx * reach - ny * slide, y: p.y - ny * reach + nx * slide, angle: Math.atan2(nx, -ny) });
  }

  const hits = route.filter((p) => p.note).map((p) => ({ t: p.t, note: p.note, x: p.x, y: p.y, voice: p.part === 'bar' || p.part === 'booster' ? 'marimba' : 'bell' }));
  hits.push(
    { t: 4.00, note: 'c', x: FINALE.x - 20, y: FINALE.y, voice: 'bell', chord: true },
    { t: 4.25, note: 'e', x: LAST, y: CRADLE.pivot + CRADLE.length, voice: 'marimba' },
    { t: 4.75, note: 'g', x: CRADLE.x, y: CRADLE.pivot + CRADLE.length, voice: 'marimba' },
  );

  function ball(t) {
    if (t >= route[route.length - 1].t) return null;
    let i = 0;
    while (i < flights.length - 1 && t >= flights[i].b.t) i++;
    const f = flights[i], u = t - f.a.t;
    if (f.a.part === 'well') {
      // One and a half turns, pulled in towards the centre and flung out.
      const k = u / f.d, a = -Math.PI / 2 - k * Math.PI * 3, r = WELL.r * (1 - 0.6 * Math.sin(k * Math.PI));
      return { x: WELL.x + Math.cos(a) * r, y: WELL.y + Math.sin(a) * r };
    }
    return { x: f.a.x + f.vx * u, y: f.a.y + f.vy * u + 0.5 * GRAVITY * u * u };
  }

  // Positive angles swing right. Only the end balls move, as in a real cradle.
  function swing(i, t) {
    if (i === CRADLE.count - 1 && t > 3.75 && t < 4.25) return Math.sin(((t - 3.75) / 0.5) * Math.PI) * CRADLE.swing;
    if (i === 0 && t > 4.25 && t < 4.75) return -Math.sin(((t - 4.25) / 0.5) * Math.PI) * CRADLE.swing * 0.8;
    return 0;
  }

  // A dotted preview of the route, as the builder will show before the drop.
  const guide = [];
  for (let s = 0.03; s < 4; s += 0.045) if (s < 3 || s > 3.5) guide.push(ball(s));

  return { LOOP, STEP, BALL, BUMPER, START, NOZZLE, WELL, CRADLE, CUP, FINALE, guide, parts, hits, ball, swing };
})();
