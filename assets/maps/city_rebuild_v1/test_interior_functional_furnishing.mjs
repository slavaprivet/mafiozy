import assert from 'node:assert/strict';
import { test } from 'node:test';
import { performance } from 'node:perf_hooks';
import { planFunctionalRoom, functionalFurnitureBounds, functionalFurnishingCacheStats } from './interior_functional_furnishing.mjs';
import { planResidentialRoom } from './residential_furnishing.mjs';
import { planCommercialRoom } from './commercial_furnishing.mjs';
import { planPublicRoom } from './public_furnishing.mjs';
import { INTERIOR_SAFE_DIMENSIONS } from './interior_interactive_safe.mjs';

const overlaps = (a, b, gap = 0) => a[0] < b[2] + gap - 1e-7 && a[2] > b[0] - gap + 1e-7 && a[1] < b[3] + gap - 1e-7 && a[3] > b[1] - gap + 1e-7;
const roles = ['living_room', 'banquet_hall', 'hotel_lobby', 'hotel_lounge', 'hotel_guestroom', 'hospital_reception', 'hospital_ward', 'dining_hall', 'club_hall', 'vip_lounge', 'civic_hall', 'meeting_hall', 'print_hall', 'workshop', 'shop_floor', 'office', 'bedroom', 'study', 'kitchen', 'dining_room', 'guest_bedroom', 'treatment_room', 'nurse_station', 'pharmacy', 'manager_office', 'security_office', 'stockroom', 'archive', 'backstage', 'cash_office', 'police_duty', 'fire_ready_room', 'warehouse', 'vault'];
const purposes = ['residential', 'hotel', 'hospital', 'civic', 'nightclub', 'strip_club', 'pawnshop', 'print_shop', 'gun_shop', 'bookmaker', 'retail', 'bank', 'police', 'fire_station', 'workshop', 'warehouse', 'restaurant'];
const kinds = plan => plan.furniture.map(f => f.kind);
const has = (plan, ...expected) => { for (const kind of expected) assert.ok(kinds(plan).includes(kind), `${plan.purpose}/${plan.role} is missing ${kind}: ${kinds(plan).join(',')}`); };

test('named uses receive their own functional furniture, at realistic human scale', () => {
  const p = (purpose, role, width = 9, depth = 10) => planFunctionalRoom({ purpose, role, width, depth, seed: 1 });
  has(p('hotel', 'hotel_guestroom', 4, 5), 'bed', 'nightstand_lamp', 'wardrobe');
  has(p('hotel', 'hotel_lobby'), 'reception', 'luggage_cart', 'sofa');
  has(p('hotel', 'dining_hall'), 'dining_set', 'sideboard');
  has(p('hotel', 'kitchen'), 'kitchen_counter', 'refrigerator');
  has(p('hospital', 'hospital_reception'), 'reception', 'bench', 'medicine_cabinet', 'medicine_trolley');
  has(p('hospital', 'hospital_ward', 4, 5), 'hospital_bed', 'iv_stand', 'bedside_cabinet', 'medicine_trolley');
  has(p('hospital', 'treatment_room'), 'hospital_bed', 'iv_stand', 'medicine_cabinet');
  has(p('nightclub', 'club_hall'), 'bar_counter', 'bottle_shelf', 'sofa', 'dining_set', 'music_console');
  has(p('print_shop', 'print_hall'), 'printing_press', 'paper_rolls', 'workbench');
  has(p('gun_shop', 'shop_floor'), 'weapon_cabinet', 'display_counter');
  has(p('bookmaker', 'shop_floor'), 'reception', 'desk', 'chair');
  has(p('fire_station', 'fire_ready_room'), 'locker', 'bench', 'dining_set', 'kitchen_counter');
  has(p('police', 'police_duty'), 'reception', 'desk', 'archive', 'locker');
  has(p('residential', 'living_room'), 'sofa', 'coffee_table', 'bookcase');
  has(p('residential', 'living_room'), 'kitchen_counter', 'refrigerator', 'dining_set');
  has(p('residential', 'kitchen', 4, 5), 'kitchen_counter', 'refrigerator');
  for (const purpose of purposes) {
    const plan = p(purpose, undefined);
    assert.ok(plan.name && plan.finish && plan.floorFinish);
    if (purpose === 'hospital') assert.ok(!kinds(plan).includes('bar_counter'));
    if (purpose === 'gun_shop') assert.ok(!kinds(plan).includes('bed'));
  }
});

test('all roles, 3 room sizes and rotated door sides have finite contained parts and unblocked reserved space', () => {
  let rooms = 0, objects = 0, components = 0;
  const sideDoors = (w, d) => [{ x: 0, z: d / 2, width: 1.7 }, { x: w / 2, z: 0, width: 1.7 }, { x: 0, z: -d / 2, width: 1.7 }, { x: -w / 2, z: 0, width: 1.7 }];
  for (const [width, depth] of [[3, 4], [6, 7], [12, 13]]) for (const [ri, role] of roles.entries()) for (const door of sideDoors(width, depth)) {
    const plan = planFunctionalRoom({ purpose: purposes[ri % purposes.length], role, width, depth, level: ri % 3, roomIndex: ri, seed: ri + 2, door });
    assert.ok(plan.statistics.parts <= (width * depth >= 100 ? 280 : width * depth >= 45 ? 220 : 170));
    assert.equal(plan.statistics.parts, plan.furniture.reduce((sum, item) => sum + item.parts.length, 0));
    const bounds = plan.furniture.map(functionalFurnitureBounds);
    for (const [i, item] of plan.furniture.entries()) {
      const b = bounds[i]; objects++;
      assert.ok([item.x, item.z, item.yaw, item.width, item.depth, item.height].every(Number.isFinite));
      assert.ok(item.width > 0 && item.depth > 0 && item.height > 0);
      assert.ok(b[0] >= -width / 2 + .129999 && b[2] <= width / 2 - .129999 && b[1] >= -depth / 2 + .129999 && b[3] <= depth / 2 - .129999, `${role}/${item.kind} outside room`);
      for (let j = 0; j < i; j++) assert.ok(!overlaps(b, bounds[j], .1299), `${role} overlaps ${item.kind}/${plan.furniture[j].kind}`);
      for (const reserved of plan.reserved) {
        if (reserved === item.interactionClearance || item.kind === 'functional_safe' && item.interactionClearance?.every((n, idx) => n === reserved[idx])) continue;
        assert.ok(!overlaps(b, reserved, .0549), `${role}/${item.kind} blocks doorway or stairs`);
      }
      for (const part of item.parts) {
        components++;
        assert.ok(['box', 'cylinder', 'sphere'].includes(part.shape));
        assert.ok(part.position.every(Number.isFinite) && part.size.every(n => Number.isFinite(n) && n > 0));
        const c = Math.abs(Math.cos(part.yaw || 0)), s = Math.abs(Math.sin(part.yaw || 0));
        assert.ok(Math.abs(part.position[0]) + (part.size[0] * c + part.size[2] * s) / 2 <= item.width / 2 + 1e-7, `${item.kind} x bounds`);
        assert.ok(Math.abs(part.position[2]) + (part.size[2] * c + part.size[0] * s) / 2 <= item.depth / 2 + 1e-7, `${item.kind} z bounds`);
        assert.ok(part.position[1] - part.size[1] / 2 >= -1e-7 && part.position[1] + part.size[1] / 2 <= item.height + 1e-7, `${item.kind} height bounds`);
        assert.ok(!('light' in part) && !('texture' in part));
      }
      for (const body of item.collisionParts) {
        assert.ok(body.rect.every(Number.isFinite) && body.rect[0] < body.rect[2] && body.rect[1] < body.rect[3]);
        assert.ok(body.minY >= -1e-7 && body.maxY > body.minY && body.maxY <= item.height + 1e-7, `${item.kind} body y`);
        assert.ok(body.rect[0] >= -item.width / 2 - 1e-7 && body.rect[2] <= item.width / 2 + 1e-7 && body.rect[1] >= -item.depth / 2 - 1e-7 && body.rect[3] <= item.depth / 2 + 1e-7, `${item.kind} body footprint`);
      }
    }
    rooms++;
  }
  console.log(`Geometry/clearance audit: ${rooms} rooms, ${objects} furniture items, ${components} primitive parts.`);
});

test('door-to-door and staircase circulation remains traversable by a .36m capsule', () => {
  const width = 12, depth = 14, reserved = [[-1, -7, 1, 7], [-6, -1, 6, 1], [3.2, -6.6, 5.8, -3.6]], connections = [{ x: 0, z: 7, width: 2 }, { x: -6, z: 0, width: 2 }, { x: 6, z: 0, width: 2 }, { x: 0, z: -7, width: 2 }];
  for (const role of ['club_hall', 'hospital_ward', 'dining_hall', 'shop_floor', 'hotel_lobby']) {
    const plan = planFunctionalRoom({ purpose: 'hotel', role, width, depth, seed: 12, reserved, connections });
    const bodies = plan.furniture.map(functionalFurnitureBounds);
    const free = (x, z) => Math.abs(x) < 5.64 && Math.abs(z) < 6.64 && !bodies.some(r => x > r[0] - .36 && x < r[2] + .36 && z > r[1] - .36 && z < r[3] + .36);
    for (let i = 0; i <= 100; i++) { const t = i / 100; assert.ok(free(0, -6.5 + 13 * t), `${role} north/south aisle blocked`); assert.ok(free(-5.5 + 11 * t, 0), `${role} east/west aisle blocked`); }
    assert.ok(plan.furniture.length >= 3, 'Preserving routes must still leave useful furniture');
    assert.ok(!bodies.some(r => overlaps(r, reserved[2], .05)), 'Stair flight reserved');
  }
});

test('tables, chairs, IVs and covers use actual separate surfaces; safe is a dynamic descriptor', () => {
  const dining = planFunctionalRoom({ purpose: 'hotel', role: 'dining_hall', width: 10, depth: 11, seed: 1 });
  const table = dining.furniture.find(f => f.kind === 'dining_set');
  assert.ok(table && table.parts.length >= 30);
  assert.equal(table.collisionParts.filter(b => b.kind === 'tabletop').length, 1);
  assert.equal(table.collisionParts.filter(b => b.kind === 'leg').length, 4);
  assert.equal(table.collisionParts.filter(b => b.kind === 'seat').length, 4);
  assert.ok(!table.collisionParts.some(b => b.rect[0] <= -.2 && b.rect[2] >= .2 && b.rect[1] <= -.2 && b.rect[3] >= .2 && b.minY < .1 && b.maxY > .6), 'Open legroom must not be a solid table-and-chairs box');
  assert.ok(table.collisionParts.find(b => b.kind === 'tabletop').cover);
  const ward = planFunctionalRoom({ purpose: 'hospital', role: 'hospital_ward', width: 7, depth: 8 });
  const iv = ward.furniture.find(f => f.kind === 'iv_stand');
  assert.ok(iv && iv.height >= 1.8);
  assert.ok(iv.collisionParts.filter(b => b.maxY > .2).every(b => b.rect[2] - b.rect[0] < .1), 'No invisible half-metre-wide IV pole');
  const office = planFunctionalRoom({ purpose: 'bank', role: 'manager_office', width: 7, depth: 8 });
  const safe = office.furniture.find(f => f.kind === 'functional_safe');
  assert.ok(safe && safe.dynamic && safe.interactionClearance);
  assert.equal(safe.width, INTERIOR_SAFE_DIMENSIONS.width); assert.equal(safe.height, INTERIOR_SAFE_DIMENSIONS.height);
  assert.equal(safe.depth, 2 * Math.max(Math.abs(INTERIOR_SAFE_DIMENSIONS.front), Math.abs(INTERIOR_SAFE_DIMENSIONS.rear)));
  assert.equal(safe.parts.length, 0); assert.equal(safe.collisionParts.length, 0);
  assert.ok(office.furniture.filter(f => f !== safe).every(f => !overlaps(functionalFurnitureBounds(f), safe.interactionClearance, .02)));
});

test('determinism, metadata aliases, immutable recipes, bounded cache and invalid inputs', () => {
  const args = { purpose: { kind: 'hotel' }, role: 'guestroom', width: 5, depth: 6, seed: 'building:12', level: 2, roomIndex: 3 };
  const a = planFunctionalRoom(args);
  for (const purpose of purposes) for (let seed = 0; seed < 8; seed++) planFunctionalRoom({ purpose, width: 9, depth: 10, seed });
  const b = planFunctionalRoom(args);
  assert.deepEqual(a, b, 'Calling other recipes must not change a plan');
  const c = planFunctionalRoom(args);
  assert.equal(b.furniture[0].parts, c.furniture[0].parts, 'Share already-generated immutable primitives');
  assert.ok(Object.isFrozen(c.furniture[0].parts) && Object.isFrozen(c.furniture[0].parts[0].position));
  assert.ok(functionalFurnishingCacheStats().entries <= functionalFurnishingCacheStats().limit);
  for (const width of [0, -1, NaN, Infinity]) assert.throws(() => planFunctionalRoom({ width, depth: 4 }));
  assert.throws(() => planFunctionalRoom({ width: 4, depth: 5, level: -1 }));
  assert.throws(() => planFunctionalRoom({ width: 4, depth: 5, roomIndex: .5 }));
  const tiny = planFunctionalRoom({ purpose: 'hotel', role: 'hotel_guestroom', width: .9, depth: .8 });
  assert.equal(tiny.furniture.length, 0);
  assert.ok(tiny.statistics.omitted.some(v => v.kind === 'single_bed'), 'Undersized bedrooms expose a layout defect instead of silently receiving an office console');
});

test('essential beds find actual free pockets between stair/path edges rather than only room-wall slots', () => {
  const reserved = [[-5, -4, -3.6, 4], [3.3, -4, 5, 4], [-5, 2.1, 5, 4], [-5, -4, 5, -2.3], [-.7, -4, .7, .5]];
  const plan = planFunctionalRoom({ purpose: 'residential', role: 'bedroom', width: 10, depth: 8, reserved, seed: 2 });
  has(plan, 'bed'); assert.ok(plan.statistics.edgeCandidates > 0);
  const bed = plan.furniture.find(item => item.kind === 'bed');
  assert.ok(reserved.every(rect => !overlaps(functionalFurnitureBounds(bed), rect, .055)));
  assert.ok(bed.width >= 1.5 && bed.depth >= 2.1, 'The bed keeps adult dimensions');
  const blocked = planFunctionalRoom({ purpose: 'residential', role: 'bedroom', width: 10, depth: 8, reserved: [[-5, -4, 5, 4]], seed: 2 });
  assert.equal(blocked.furniture.length, 0); assert.ok(blocked.statistics.edgeCandidates <= 2 * 4 * 256, 'Double/single essential fallback is strictly bounded');
});

test('bank vault deposit furniture stays static; access room does not create a second hackable safe', () => {
  const vault = planFunctionalRoom({ purpose: 'bank', role: 'vault', width: 4.08, depth: 4.4 });
  assert.equal(vault.name, 'Хранилище'); assert.equal(vault.furniture.filter(item => item.kind === 'deposit_cabinet').length, 2); has(vault, 'desk');
  for (const cabinet of vault.furniture.filter(item => item.kind === 'deposit_cabinet')) {
    assert.equal(cabinet.width, 1); assert.equal(cabinet.depth, .36); assert.equal(cabinet.height, 1.85);
    assert.equal(cabinet.parts.length, 55); assert.equal(cabinet.dynamic, undefined); assert.equal(cabinet.id, undefined); assert.ok(cabinet.collisionParts[0].cover);
  }
  const security = planFunctionalRoom({ purpose: 'bank', role: 'security_office', width: 7, depth: 7 });
  has(security, 'desk', 'archive'); assert.ok(!kinds(security).includes('functional_safe'));
  const lounge = planFunctionalRoom({ purpose: 'bank', role: 'living_room', width: 7, depth: 7 });
  assert.ok(!kinds(lounge).includes('kitchen_counter'));
});

if (process.env.INTERIOR_FURNISHING_PERF === '1') {
  // CPU construction only, on identical representative room dimensions. This
  // is not a loaded city FPS result, and neither old nor new planner updates
  // furniture per frame. GPU/calls/triangles must be measured by the integrator.
  const scenarios = [
    ['residential', 'living_room', 'small_house', 6, 7, planResidentialRoom],
    ['hotel', 'hotel_guestroom', 'old_town_house', 5, 6, planResidentialRoom],
    ['hospital', 'hospital_ward', 'hospital', 9, 10, planPublicRoom],
    ['nightclub', 'club_hall', 'nightclub', 12, 13, planCommercialRoom],
    ['retail', 'shop_floor', 'glass_pavilion', 9, 10, planCommercialRoom],
    ['print_shop', 'print_hall', 'print_shop', 10, 11, planPublicRoom],
    ['bank', 'manager_office', 'bank_branch', 6, 7, planPublicRoom],
  ];
  const percentile = (numbers, p) => numbers.sort((a, b) => a - b)[Math.floor((numbers.length - 1) * p)];
  const rows = [];
  for (const [purpose, role, assetId, width, depth, previous] of scenarios) {
    const args = { purpose, role, assetId, width, depth, seed: 17, level: role === 'hospital_ward' || role === 'hotel_guestroom' ? 1 : 0, roomIndex: 1 };
    const measure = fn => { for (let i = 0; i < 150; i++) fn(args); const samples = []; for (let repeat = 0; repeat < 90; repeat++) { const start = performance.now(); for (let i = 0; i < 25; i++) fn(args); samples.push((performance.now() - start) / 25); } const plan = fn(args); return { p50Ms: +percentile(samples, .5).toFixed(4), p95Ms: +percentile(samples, .95).toFixed(4), items: plan.furniture.length, parts: plan.furniture.reduce((n, item) => n + item.parts.length, 0) }; };
    rows.push({ purpose, role, width, depth, before: measure(previous), after: measure(planFunctionalRoom) });
  }
  console.log(JSON.stringify({ scenario: 'CPU construction, warmed recipes, 90x25 plans per function; no loaded scene or GPU', updateCostMs: 0, rows }, null, 2));
}
