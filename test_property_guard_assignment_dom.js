'use strict';

// Execute the production guard-assignment UI in a deterministic tiny DOM.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const world = fs.readFileSync('world.html', 'utf8');
const helperStart = world.indexOf('function _canAssignPropertyGuards(');
const helperEnd = world.indexOf('function openBrigadirActionCardFrom3D(', helperStart);
const dialogStart = world.indexOf('function _openPropertyGuardAssignment(');
const dialogEnd = world.indexOf("_businessActionCard.addEventListener('click'", dialogStart);
assert(helperStart >= 0 && helperEnd > helperStart && dialogStart >= 0 && dialogEnd > dialogStart);
const production = world.slice(helperStart, helperEnd) + world.slice(dialogStart, dialogEnd);

class FakeControl {
  constructor(value = '') { this.value = String(value); this.textContent = ''; this.disabled = false; }
}
class FakeModal {
  constructor() { this.style = {display: 'none'}; this.controls = {}; this._html = ''; }
  set innerHTML(value) {
    this._html = String(value);
    const range = this._html.match(/data-pga-range[^>]*max="(\d+)"[^>]*value="(\d+)"/);
    this.controls.range = new FakeControl(range?.[2] || 0);
    this.controls.range.max = range?.[1] || '0';
    this.controls.count = new FakeControl();
    this.controls.save = new FakeControl();
    this.controls.cancel = new FakeControl();
  }
  get innerHTML() { return this._html; }
  querySelector(selector) {
    return ({'[data-pga-range]': this.controls.range, '[data-pga-count]': this.controls.count,
      '[data-pga-save]': this.controls.save, '[data-pga-cancel]': this.controls.cancel})[selector] || null;
  }
}

const modal = new FakeModal();
const toasts = [];
const responses = [];
let apartmentLoads = 0;
const context = vm.createContext({
  console,
  QP: {uid: '101', api: 'https://test.invalid'},
  _myGang: Array.from({length: 9}, (_, i) => ({id: i + 1, hp: 100})),
  _playerBuildingProperties: [],
  _propertyGuardAssignmentBusy: false,
  _npcBuildingActionDialog: () => modal,
  showToast: message => toasts.push(message),
  loadNpcEmpireState: async () => {},
  loadApartmentState: async () => { apartmentLoads++; },
  fetch: async (_url, options) => {
    context.lastBody = JSON.parse(options.body);
    const response = responses.shift();
    return {ok: response.ok, json: async () => response.body};
  },
  encodeURIComponent,
});
vm.runInContext(production, context, {filename: 'world.html#property-guards'});

const operations = ['beer_bar', 'pawnshop', 'bookmaker', 'strip_club', 'gun_shop',
  'chop_shop', 'poker_club', 'print_shop'];
for (const operation_type of operations) {
  const property = {property_kind: 'business', operation_type, building_key: `b-${operation_type}`,
    owner_uid: '101', owned: true, defender_count: 0, guard_total: 6, guard_free: 6};
  assert.equal(context._canAssignPropertyGuards(property), true, operation_type);
  assert.equal(context._openPropertyGuardAssignment(property), true);
  assert.equal(modal.controls.range.value, '0');
  assert.equal(modal.controls.range.max, '6');
}

// Explicit zero is authoritative and must never fall back to the local roster.
assert.deepEqual({...context._propertyGuardCounts({defender_count: 2, guard_total: 9, guard_free: 0})},
  {here: 2, total: 9, free: 0, max: 2});
assert.deepEqual({...context._propertyGuardCounts({defender_count: 3, guard_total: 20, guard_free: 20})},
  {here: 3, total: 20, free: 17, max: 12});

const hq = {property_kind: 'hq', building_key: 'hq', owner_uid: '101', owned: true};
assert.equal(context._canAssignPropertyGuards(hq), false, 'HQ is not supported by server targets');
assert.equal(context._openPropertyGuardAssignment(hq), false);
assert.equal(context._canAssignPropertyGuards({property_kind: 'business', building_key: 'sold', owner_uid: '202'}), false);
assert.equal(context._canAssignPropertyGuards({property_kind: 'business', building_key: 'captured', npc_owned: true, owner_uid: 'npc:x'}), false);

const property = {property_kind: 'business', building_key: '0,3', owner_uid: '101', owned: true,
  defender_count: 2, guard_total: 6, guard_free: 4};
context._playerBuildingProperties = [property];
assert.equal(context._openPropertyGuardAssignment(property), true);
assert.match(modal.innerHTML, /width:min\(440px,calc\(100vw - 24px\)\)/);
assert.match(modal.innerHTML, /max-height:min\(560px,calc\(100dvh - 24px\)\)/);
assert.match(modal.innerHTML, /overflow:auto/);

(async () => {
  // 0 and current+free are both accepted; the request is bounded to the server cap.
  responses.push({ok: true, body: {ok: true, total: 6, assigned: 0, free: 6, holding_guards: 0}});
  assert.equal(await context._assignPropertyGuards(property, 0, modal), true);
  assert.deepEqual(context.lastBody, {holding_ref: 'building:0,3', count: 0});
  assert.equal(property.holding_guards, 0);

  property.defender_count = 2; property.holding_guards = 2; property.guard_free = 20; property.guard_total = 20;
  responses.push({ok: true, body: {ok: true, total: 20, assigned: 12, free: 8, holding_guards: 12}});
  assert.equal(await context._assignPropertyGuards(property, 99, modal), true);
  assert.equal(context.lastBody.count, 12);

  // Insufficient roster refreshes authoritative counts and leaves a usable dialog.
  responses.push({ok: false, body: {ok: false, error: 'insufficient free roster'}});
  assert.equal(await context._assignPropertyGuards(property, 12, modal), false);
  assert.match(toasts.at(-1), /Недостаточно/);
  assert.equal(modal.style.display, 'flex');

  // Generic server errors do not strand the busy flag or disabled save button.
  responses.push({ok: false, body: {ok: false, error: 'database busy'}});
  assert.equal(await context._assignPropertyGuards(property, 2, modal), false);
  assert.equal(context._propertyGuardAssignmentBusy, false);
  assert.equal(modal.controls.save.disabled, false);

  // Ownership races close the modal; the reloaded snapshot makes the action disappear.
  context.loadApartmentState = async () => { apartmentLoads++; context._playerBuildingProperties = []; };
  responses.push({ok: false, body: {ok: false, error: 'holding not owned'}});
  assert.equal(await context._assignPropertyGuards(property, 1, modal), false);
  assert.equal(modal.style.display, 'none');
  assert(apartmentLoads >= 5);

  // Authoritative sessions spawn the concrete defender roster once and no legacy staff layer.
  assert.match(world, /hasAssignedRoster=Array\.isArray\(activity\.defender_roster\)/);
  assert.match(world, /legacyFrontCount=rosterBacked\?0:/);
  assert.match(world, /guard_down_ids\.length\?\{guard_down_ids\}:\{\}/);
  console.log('property guard DOM/contract: 8 operations, 0/max, errors, reconnect ownership, responsive modal and concrete roster OK');
})().catch(error => { console.error(error); process.exitCode = 1; });
