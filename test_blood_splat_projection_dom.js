'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const world = fs.readFileSync('world.html', 'utf8');
const start = world.indexOf('function drawBloodSplats() {');
const end = world.indexOf('// ── Коробка над головой/машиной', start);
assert(start >= 0 && end > start, 'drawBloodSplats source not found');
const candidate = world.slice(start, end);
assert(!candidate.includes('w2s('), 'blood splats still call allocating projection');
assert(candidate.indexOf('if (s.life <= 0) continue;') < candidate.indexOf("document.getElementById('stage')"),
  'stage lookup must stay lazy after the first living splat');
assert(candidate.includes('for (let i = bloodSplats.length - 1; i >= 0; i--)'),
  'reverse draw order changed');

// Reconstruct the old projection-only shape from the production body. This
// leaves every Canvas operation byte-for-byte identical and changes only the
// coordinate source used by the parity fixture below.
const reference = candidate
  .replace('function drawBloodSplats() {\n  let centerX = 0, centerY = 0, stageReady = false;',
    'function drawBloodSplats() {')
  .replace(/    if \(!stageReady\) \{[\s\S]*?      stageReady = true;\n    \}\n/, '')
  .replace(/    const sr = s\.r \+ 0\.5, sc = s\.c \+ 0\.5;\n    const px =[^\n]+\n    const py =[^\n]+\n/,
    '    const p = w2s(s.r + 0.5, s.c + 0.5);\n')
  .replaceAll('ctx.translate(px, py);', 'ctx.translate(p.x, p.y);');
assert(reference.includes('const p = w2s('), 'reference reconstruction failed');

function makeHarness(source, splats) {
  const trace = [];
  const counts = {dom: 0, dims: 0, w2s: 0, objects: 0};
  const stage = {};
  Object.defineProperties(stage, {
    clientWidth: {get() { counts.dims++; return 1280; }},
    clientHeight: {get() { counts.dims++; return 720; }},
  });
  const gradient = {addColorStop(...args) { trace.push(['stop', ...args]); }};
  const methods = ['save', 'restore', 'translate', 'rotate', 'beginPath', 'ellipse',
    'fill', 'stroke', 'arc', 'setLineDash'];
  const canvas = {};
  for (const method of methods) canvas[method] = (...args) => trace.push([method, ...args]);
  canvas.createRadialGradient = (...args) => {
    trace.push(['gradient', ...args]); return gradient;
  };
  const ctx = new Proxy(canvas, {
    set(target, key, value) {
      trace.push(['set', String(key), value === gradient ? '<gradient>' : value]);
      target[key] = value;
      return true;
    },
  });
  const context = vm.createContext({
    bloodSplats: splats, ctx, TS: 64, ISO_Y: 0.52, cam: {x: 37.25, y: -18.5},
    document: {getElementById(id) { assert.equal(id, 'stage'); counts.dom++; return stage; }},
    w2s(r, c) {
      counts.w2s++;
      counts.dom++;
      const cx = stage.clientWidth / 2, cy = stage.clientHeight / 2;
      counts.objects++;
      return {x: cx + (c - r) * 64 * 0.5 - 37.25,
        y: cy + (c + r) * 64 * 0.5 * 0.52 + 18.5};
    },
  });
  vm.runInContext(source, context, {filename: 'world.html#drawBloodSplats'});
  vm.runInContext('drawBloodSplats()', context);
  return {trace, counts};
}

const live = Array.from({length: 48}, (_, i) => ({
  r: (i * 7) % 23 + i / 100, c: (i * 11) % 29 - i / 90,
  radius: 3 + i % 9, life: 500 + i * 13, max: 1600, rot: i / 17,
  _isSoot: i % 3 === 0, _isCrater: i % 7 === 0,
}));
const before = makeHarness(reference, live);
const after = makeHarness(candidate, live);
assert.equal(after.trace.length, before.trace.length, 'Canvas trace length changed');
const firstMismatch = after.trace.findIndex((item, index) =>
  JSON.stringify(item) !== JSON.stringify(before.trace[index]));
assert.equal(firstMismatch, -1, firstMismatch < 0 ? 'trace length changed' :
  `trace mismatch ${firstMismatch}: ${JSON.stringify(before.trace[firstMismatch])} != ${JSON.stringify(after.trace[firstMismatch])}`);
assert.deepEqual(before.counts, {dom: 48, dims: 96, w2s: 48, objects: 48});
assert.deepEqual(after.counts, {dom: 1, dims: 2, w2s: 0, objects: 0});
assert.deepEqual(makeHarness(candidate, []).counts, {dom: 0, dims: 0, w2s: 0, objects: 0});
assert.deepEqual(makeHarness(candidate, live.map(s => ({...s, life: 0}))).counts,
  {dom: 0, dims: 0, w2s: 0, objects: 0});

// Pin exact IEEE-754 operation order over a large deterministic coordinate set.
let seed = 0x9e3779b9;
const random = () => ((seed = Math.imul(seed ^ seed >>> 15, 2246822519) >>> 0) / 2 ** 32);
for (let i = 0; i < 50000; i++) {
  const r = random() * 200 - 60, c = random() * 200 - 60;
  const ts = 16 + random() * 96, iso = 0.35 + random() * 0.5;
  const centerX = random() * 1600, centerY = random() * 1000;
  const camX = random() * 800 - 400, camY = random() * 800 - 400;
  const oldX = centerX + ((c + 0.5) - (r + 0.5)) * ts * 0.5 - camX;
  const oldY = centerY + ((c + 0.5) + (r + 0.5)) * ts * 0.5 * iso - camY;
  const sr = r + 0.5, sc = c + 0.5;
  const newX = centerX + (sc - sr) * ts * 0.5 - camX;
  const newY = centerY + (sc + sr) * ts * 0.5 * iso - camY;
  assert(Object.is(newX, oldX) && Object.is(newY, oldY), `projection drift at ${i}`);
}

console.log('blood splat projection: 50k exact parity; live48 DOM 48→1, dims 96→2, w2s/objects 48→0');
