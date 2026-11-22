// Notes are queued ahead on the Web Audio clock. The picture follows that same clock.
window.Sound = (() => {
  'use strict';

  const { LOOP, hits } = window.Timeline;
  const AHEAD = 0.18, VOICES = ['bell', 'marimba'], NOTES = ['c', 'e', 'g'];
  const files = {}, buffers = {};
  let ac = null, bus = null, origin = 0, queuedTo = 0, on = false, live = [], timer = null;

  async function fetchFile(name) {
    for (let attempt = 0; ; attempt++) {
      try {
        const r = await fetch(`../shared/assets/${name}.wav`);
        if (!r.ok) throw new Error(`${r.status} for ${name}`);
        return await r.arrayBuffer();
      } catch (error) {
        if (attempt >= 3) throw error;
        await new Promise((done) => setTimeout(done, 400 * 2 ** attempt));
      }
    }
  }

  function preload() {
    for (const v of VOICES) for (const n of NOTES) {
      const name = `${v}-${n}`;
      files[name] = fetchFile(name);
      files[name].catch(() => {});
    }
  }

  function play(name, when, gain) {
    const source = ac.createBufferSource(), level = ac.createGain();
    source.buffer = buffers[name]; level.gain.value = gain;
    source.connect(level).connect(bus);
    source.start(when);
    live.push(source);
    source.onended = () => { live = live.filter((s) => s !== source); level.disconnect(); };
  }

  function queue() {
    if (!on || ac.state !== 'running') return;
    const from = Math.max(queuedTo, ac.currentTime), to = ac.currentTime + AHEAD;
    for (let loop = Math.max(0, Math.floor((from - origin) / LOOP)); origin + loop * LOOP < to; loop++) {
      for (const hit of hits) {
        const when = origin + loop * LOOP + hit.t;
        if (when < from || when >= to) continue;
        if (hit.chord) {
          for (const n of NOTES) play(`bell-${n}`, when, 0.36);
          for (const n of NOTES) play(`marimba-${n}`, when, 0.3);
        } else {
          play(`${hit.voice}-${hit.note}`, when, hit.voice === 'bell' ? 0.45 : 0.75);
        }
      }
    }
    queuedTo = to;
  }

  function restart() {
    if (!ac) return;
    for (const s of live) s.stop();
    live = [];
    origin = ac.currentTime + 0.12;
    queuedTo = origin;
  }

  // Must be called from a tap: both iOS and Android block audio otherwise.
  async function enable() {
    if (navigator.audioSession) navigator.audioSession.type = 'playback';
    if (!ac) {
      ac = new (window.AudioContext || window.webkitAudioContext)({ latencyHint: 'interactive' });
      bus = ac.createDynamicsCompressor();
      bus.threshold.value = -8; bus.ratio.value = 6;
      bus.connect(ac.destination);
      timer = setInterval(queue, 25);
      document.addEventListener('visibilitychange', () => {
        if (document.hidden) ac.suspend();
        else if (on) ac.resume();
      });
    }
    await ac.resume();
    for (const name of Object.keys(files)) {
      if (buffers[name]) continue;
      try { await files[name]; } catch { files[name] = fetchFile(name); }
      buffers[name] = await ac.decodeAudioData((await files[name]).slice(0));
    }
    restart();
    on = true;
    queue();
  }

  function disable() {
    on = false;
    for (const s of live) s.stop();
    live = [];
    ac?.suspend();
  }

  // What the listener hears right now, in loop time. Null while audio is not running.
  function time() {
    if (!on || ac.state !== 'running') return null;
    return Math.max(0, ac.currentTime - origin - (ac.outputLatency || ac.baseLatency || 0));
  }

  return { preload, enable, disable, restart, time, get on() { return on; } };
})();
