'use strict';

// Execute the production district-card renderer in a tiny deterministic DOM.
// No browser tab, network, jsdom dependency or duplicate game runtime is used.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const world = fs.readFileSync('world.html', 'utf8');
const rendererStart = world.indexOf('function _ensureDistrictRepUi()');
const rendererEnd = world.indexOf('function _openDistrictInfo(', rendererStart);
assert(rendererStart >= 0 && rendererEnd > rendererStart);
const productionRenderer = world.slice(rendererStart, rendererEnd);

class FakeStyle {
  constructor() { this.values = new Map(); }
  setProperty(name, value) { this.values.set(name, String(value)); }
  getPropertyValue(name) { return this.values.get(name) || ''; }
}

class FakeElement {
  constructor(tagName) {
    this.tagName = String(tagName).toUpperCase();
    this.style = new FakeStyle();
    this.dataset = {};
    this.classList = { values: new Set(), add: (...names) => names.forEach(
      name => this.classList.values.add(name)) };
    this.children = [];
    this._html = '';
    this._canvases = [];
    this.textContent = '';
  }
  appendChild(child) { this.children.push(child); return child; }
  set innerHTML(value) {
    this._html = String(value);
    this._canvases = [...this._html.matchAll(
      /<canvas[^>]*data-ne-portrait="([^"]+)"[^>]*>/g
    )].map(match => ({dataset: {nePortrait: match[1]}, paintedLeader: ''}));
  }
  get innerHTML() { return this._html; }
  querySelectorAll(selector) {
    return selector === 'canvas[data-ne-portrait]' ? this._canvases : [];
  }
}

const document = {
  head: new FakeElement('head'), body: new FakeElement('body'),
  createElement: tag => new FakeElement(tag),
};
const paintCalls = [];
const context = vm.createContext({
  console, document,
  _districtRepUi: null,
  _districtRep: {northside: 0},
  _districtRepValue: id => context._districtRep[id] || 0,
  _districtRepTier: () => ({icon: '◆', name: 'Нейтрально', color: '#b9c3d2'}),
  _npcEmpireEsc: value => String(value ?? '').replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;'),
  _npcEmpireDistricts: [],
  _npcEmpireById: new Map(),
  _npcEmpires: [],
  _paintNpcEmpireUiPortraits: root => {
    for (const canvas of root.querySelectorAll('canvas[data-ne-portrait]')) {
      canvas.paintedLeader = canvas.dataset.nePortrait;
      paintCalls.push(canvas.dataset.nePortrait);
    }
  },
});
vm.runInContext(productionRenderer, context, {filename: 'world.html#district-card'});

const district = {id: 'northside', name: 'Норт-Сайд', icon: '🏪'};
const leila = {
  leader_id: 'leila', leader_name: 'Лейла аль-Масри-Абдельрахманова',
  gang_name: 'Семья Золотого Полумесяца и Северных Кварталов',
  emblem: '☾', color: '#641f38', accent: '#e5ba55',
};
const rustam = {
  leader_id: 'rustam', leader_name: 'Рустам Караев',
  gang_name: 'Волки Каспия', emblem: '🐺', color: '#243d56', accent: '#7fc8e8',
};
const vera = {
  leader_id: 'vera', leader_name: 'Вера Оболенская',
  gang_name: 'Белая Корона', emblem: '♕', color: '#4b315d', accent: '#d7a7ff',
};
context._npcEmpires = [leila, rustam, vera];
context._npcEmpireById = new Map(context._npcEmpires.map(empire => [empire.leader_id, empire]));

const field = (html, className) => {
  const match = html.match(new RegExp(
    `<([a-z]+)[^>]*class="${className}"[^>]*>([\\s\\S]*?)<\\/\\1>`
  ));
  assert(match, `missing .${className}`);
  return match[2].replace(/<[^>]+>/g, '');
};
const currentCanvas = () => context._districtRepUi
  .querySelectorAll('canvas[data-ne-portrait]')[0] || null;

// 1. Neutral district: no inherited boss, portrait or emblem.
context._npcEmpireDistricts = [{
  district_id: 'northside', leader_id: '', runner_up_id: '', score: 0,
  runner_up_score: 0, contested: false, control_state: 'neutral', control_percent: 0,
}];
context._renderDistrictRep(district, true);
assert.equal(context._districtRepUi.dataset.controlState, 'neutral');
assert.equal(currentCanvas(), null);
assert.equal(field(context._districtRepUi.innerHTML, 'dr-state'), 'НЕЙТРАЛЬНАЯ ТЕРРИТОРИЯ');
assert.equal(field(context._districtRepUi.innerHTML, 'dr-boss'), 'Власть не определена');

// 2. Exact tie: authoritative leader portrait is present, rival is explicit.
context._npcEmpireDistricts = [{
  district_id: 'northside', leader_id: 'leila', runner_up_id: 'rustam',
  score: 10, runner_up_score: 10, contested: true,
  control_state: 'contested', control_percent: 50,
}];
context._renderDistrictRep(district, false);
assert.equal(context._districtRepUi.dataset.controlState, 'contested');
assert.equal(context._districtRepUi.dataset.controlPercent, '50');
assert.equal(field(context._districtRepUi.innerHTML, 'dr-state'), 'ВЛАСТЬ ОСПАРИВАЕТСЯ');
assert.equal(field(context._districtRepUi.innerHTML, 'dr-boss'), leila.leader_name);
assert.match(context._districtRepUi.innerHTML, /class="dr-emblem"[^>]*>☾<\/span>/);
assert.equal(currentCanvas().dataset.nePortrait, 'leila');
assert.equal(currentCanvas().paintedLeader, 'leila');
assert.match(field(context._districtRepUi.innerHTML, 'dr-rival'), /Рустам Караев · 10/);

// 3. Clear leader: same DOM node is replaced with current authoritative data.
context._npcEmpireDistricts = [{
  district_id: 'northside', leader_id: 'leila', runner_up_id: 'rustam',
  score: 21, runner_up_score: 10, contested: false,
  control_state: 'leader', control_percent: 68,
}];
context._renderDistrictRep(district, false);
assert.equal(context._districtRepUi.dataset.controlState, 'leader');
assert.equal(context._districtRepUi.dataset.controlPercent, '68');
assert.equal(field(context._districtRepUi.innerHTML, 'dr-boss'), leila.leader_name);
assert.equal(currentCanvas().dataset.nePortrait, 'leila');

// 4. Takeover without reload: boss, family seal, colours and portrait all flip.
context._npcEmpireDistricts = [{
  district_id: 'northside', leader_id: 'rustam', runner_up_id: 'leila',
  score: 28, runner_up_score: 17, contested: false,
  control_state: 'leader', control_percent: 62,
}];
context._renderDistrictRep(district, false);
assert.equal(field(context._districtRepUi.innerHTML, 'dr-boss'), rustam.leader_name);
assert.equal(field(context._districtRepUi.innerHTML, 'dr-gang'), rustam.gang_name);
assert.match(context._districtRepUi.innerHTML, /class="dr-emblem"[^>]*>🐺<\/span>/);
assert.equal(currentCanvas().dataset.nePortrait, 'rustam');
assert.equal(currentCanvas().paintedLeader, 'rustam');
assert.equal(context._districtRepUi.style.getPropertyValue('--dr-boss'), rustam.color);
assert.equal(context._districtRepUi.style.getPropertyValue('--dr-accent'), rustam.accent);
assert.deepEqual(paintCalls.slice(-2), ['leila', 'rustam']);

// 5. Rival-only change must not resurrect the previous rival or repaint a stale boss.
context._npcEmpireDistricts = [{
  district_id: 'northside', leader_id: 'rustam', runner_up_id: 'vera',
  score: 30, runner_up_score: 19, contested: false,
  control_state: 'leader', control_percent: 61,
}];
context._renderDistrictRep(district, false);
assert.equal(field(context._districtRepUi.innerHTML, 'dr-boss'), rustam.leader_name);
assert.equal(currentCanvas().dataset.nePortrait, 'rustam');
const rivalText = field(context._districtRepUi.innerHTML, 'dr-rival');
assert.match(rivalText, /Вера Оболенская · 19/);
assert.doesNotMatch(rivalText, /Лейла|Рустам Караев/);

// 6. Returning to neutral clears the last leader canvas and family identity.
const paintCountBeforeNeutral = paintCalls.length;
context._npcEmpireDistricts = [{
  district_id: 'northside', leader_id: '', runner_up_id: '', score: 0,
  runner_up_score: 0, contested: false, control_state: 'neutral', control_percent: 0,
}];
context._renderDistrictRep(district, false);
assert.equal(context._districtRepUi.dataset.controlState, 'neutral');
assert.equal(currentCanvas(), null);
assert.equal(paintCalls.length, paintCountBeforeNeutral);
assert.equal(field(context._districtRepUi.innerHTML, 'dr-boss'), 'Власть не определена');
assert.doesNotMatch(field(context._districtRepUi.innerHTML, 'dr-gang'),
  /Волки Каспия|Белая Корона|Золотого Полумесяца/);

const css = document.head.children[0].textContent;
assert.match(css, /width:min\(306px,calc\(100vw - 28px\)\)/);
assert.match(css, /grid-template-columns:50px minmax\(0,1fr\) auto/);
assert.match(css, /\.dr-boss\{[^}]*overflow:hidden[^}]*text-overflow:ellipsis/);
assert.match(css, /\.dr-gang\{[^}]*overflow:hidden[^}]*text-overflow:ellipsis/);
assert.match(css, /\.dr-state,[^}]*overflow:hidden;white-space:nowrap;text-overflow:ellipsis/);
assert.match(css, /\.dr-rival b\{min-width:0;max-width:54%\}/);
assert(306 < 1366 && 306 < 1920);

console.log('npc empire district DOM: neutral -> tie -> leader -> takeover -> rival -> neutral, '
  + 'portrait/emblem ownership, stale-state reset and 306px clamp OK');
