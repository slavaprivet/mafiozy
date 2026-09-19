import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

// Execute the real source-world combat loop, not a copy of its steering rules.
const world = fs.readFileSync(new URL('../../../world.html', import.meta.url), 'utf8');
const start = world.indexOf('function _updateGang(dt) {');
const end = world.indexOf('// Персистентность охраны банка:', start);
assert(start > 0 && end > start);
const updateSource = world.slice(start, end);

function fixture({ neighbor = false, armed = false, passable = false, neighborC = 0, memberC = .01 } = {}) {
  const target = { id: 'enemy', r: 0, c: armed ? 4 : 1, hp: 100 };
  const member = { id: 'mercenary', r: 0, c: memberC, hp: 100, weapon: armed ? 'pistol' : null, targetKind: 'street_npc', targetRef: target, targetId: target.id, ang: 0, walkPhase: 0, _nextShootAt: Infinity };
  const other = { id: 'other', r: 0, c: neighborC, hp: 100 };
  let collisionChecks = 0;
  const blocked = () => { collisionChecks++; return passable; };
  const api = {
    tick() {}, ownsUpdate: m => m === other,
    isMercenary: () => true, isDefending: () => true, stats: () => ({}),
    canMoveMember: blocked,
  };
  const ctx = {
    window: { MafioziMercenaries: api, MafioziMercenaryMelee: { step() {} }, MAFIOZI_RENDERER_CONFIG: { worldScale: 4.1 } },
    performance: { now: () => 1000 }, Math,
    _myGang: neighbor ? [member, other] : [member], _gangFormation: [], _gangFormationAng: 0,
    _updateFormerGang() {}, _tickGangChatter() {}, _saveGang() {}, _gangSay() {},
    player: { r: 0, c: 0, ang: 0 }, myDead: false, _bankInt: null, _buildingInt: null,
    _businessInteriorMovementBlocked: () => false,
    _npcPathPassable: blocked, _npcBodyPassable: blocked, npcPassableForSnitch() {},
    lockedTargets: new Set(), NPCS: [target], _majorRaidLocal: null, _majorInteriorObjectId: null,
    _gangTargetPos: (kind, ref) => ({ r: ref.r, c: ref.c }), GANG_ENGAGE_R: 10,
    _interiorGuardWeaponAi: () => ({ ideal: 2, retreat: 1 }),
  };
  vm.createContext(ctx);
  vm.runInContext(updateSource, ctx);
  return { member, update: () => ctx._updateGang(.05), checks: () => collisionChecks };
}

test('defending specialist separation cannot push through a blocked world path', () => {
  const f = fixture({ neighbor: true });
  const before = [f.member.r, f.member.c];
  f.update();
  assert.deepEqual([f.member.r, f.member.c], before, 'Separation must preserve collision boundaries');
  assert(f.checks() > 0, 'Separation consults the live movement contract');
});

test('armed specialist combat pursuit cannot walk through a blocked world path', () => {
  const f = fixture({ armed: true });
  const before = [f.member.r, f.member.c];
  f.update();
  assert.deepEqual([f.member.r, f.member.c], before, 'Combat pursuit must preserve collision boundaries');
  assert(f.checks() > 0, 'Combat movement consults the live movement contract');
});

test('armed specialist still advances in open space', () => {
  const f = fixture({ armed: true, passable: true });
  f.update();
  assert(f.member.c > .01);
  assert(f.checks() > 0);
});

test('specialists separated by two metres are not pushed apart by legacy formation spacing', () => {
  const f = fixture({ neighbor: true, passable: true, memberC: 2 / 4.1 });
  f.update();
  assert.equal(f.member.c, 2 / 4.1);
});

test('exactly overlapping specialists separate outward with a bounded step', () => {
  const f = fixture({ neighbor: true, passable: true, memberC: 0 });
  f.update();
  const distance = Math.hypot(f.member.r, f.member.c);
  assert(distance > 0 && distance <= .08);
  assert(f.member.r > 0 && f.member.c < 0, 'First formation slot uses the outward deterministic direction');
});
