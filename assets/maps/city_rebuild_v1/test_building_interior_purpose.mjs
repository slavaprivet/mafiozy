import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {registerHooks} from 'node:module';
import {fileURLToPath, pathToFileURL} from 'node:url';
import {resolveBuildingPurpose} from './building_interior_purpose.mjs';
import {createWindowedBuildingEntry} from './building_window_integration.mjs';
import {BUILDING_STOREY_PROFILES} from './building_storey_profiles.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, '../../..');
const placementPath = path.join(here, 'buildings_placement.v1.json');
const originalPlacement = fs.readFileSync(placementPath, 'utf8');
const instances = JSON.parse(originalPlacement).instances;
const expected = {
  civic_hall: 'civic', hospital: 'hospital', nightclub: 'nightclub',
  pawnshop: 'pawnshop', print_shop: 'print_shop', gun_shop: 'gun_shop',
  bookmaker: 'bookmaker', strip_club: 'strip_club', glass_pavilion_small_v1: 'retail',
  old_town_narrow_townhouse_v1: 'residential', eastside_garden_walkup_v1: 'residential',
  eastside_stepped_apartment_v1: 'residential', coastal_orchard_house_v1: 'residential',
  garden_lane_house_v1: 'residential', hillstep_chalet_v1: 'residential',
  pine_ridge_cottage_v1: 'residential', veranda_bungalow_v1: 'residential',
  woodland_crosswing_house_v1: 'residential', compact_podium_glass_tower_v1: 'residential',
  bank_small_shell_v1: 'bank', bank_medium_shell_v1: 'bank', bank_large_shell_v1: 'bank',
};

test('all 75 current building labels retain the intended purpose across 22 assets', () => {
  assert.equal(instances.length, 75);
  assert.deepEqual([...new Set(instances.map(i => i.assetId))].sort(), Object.keys(expected).sort());
  for (const instance of instances) {
    const before = structuredClone(instance);
    const resolved = resolveBuildingPurpose(instance);
    assert.equal(resolved.kind, expected[instance.assetId], instance.id);
    assert.ok(resolved.label.trim().length, instance.id + ' has a visible label');
    assert.equal(resolved.buildingId, instance.id);
    assert.equal(resolved.gameplayId, instance.gameplayId ?? null);
    // The same name shown at the entrance must keep the same room purpose.
    const named = {...structuredClone(instance), displayName: resolved.label};
    assert.equal(resolveBuildingPurpose(named).kind, resolved.kind, instance.id + ' named label');
    assert.equal(resolveBuildingPurpose(named).label, resolved.label);
    assert.deepEqual(instance, before, instance.id + ' metadata is read only');
  }
  assert.equal(instances.filter(i => resolveBuildingPurpose(i).kind === 'hotel').length, 0,
    'the current map has no hotel; hotel checks below are isolated metadata fixtures');
});

test('Hotel and Отель labels override residential shells without changing their identities', () => {
  for (const assetId of ['old_town_narrow_townhouse_v1', 'compact_podium_glass_tower_v1']) {
    const original = instances.find(i => i.assetId === assetId);
    for (const displayName of ['Hotel Belvedere', 'Отель «Белведер»', 'Гостиница «Северная»']) {
      const fixture = {...structuredClone(original), displayName};
      const before = structuredClone(fixture);
      const resolved = resolveBuildingPurpose(fixture);
      assert.equal(resolved.kind, 'hotel', assetId + ' / ' + displayName);
      assert.equal(resolved.label, displayName);
      assert.equal(resolved.source, 'declared-name-or-type');
      assert.equal(resolved.buildingId, original.id);
      assert.equal(resolved.gameplayId, original.gameplayId ?? null);
      assert.deepEqual(fixture, before);
    }
  }
});

const vendor = process.env.MAFIOZY_THREE_VENDOR || 'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/';
registerHooks({resolve(specifier, context, next) {
  return next(specifier === 'three' ? pathToFileURL(path.join(vendor, 'build/three.module.js')).href : specifier, context);
}});
const T = await import(pathToFileURL(path.join(vendor, 'build/three.module.js')));
const {GLTFLoader} = await import(pathToFileURL(path.join(vendor, 'addons/loaders/GLTFLoader.js')));
const contained = (a, b, e = 1e-6) => a[0] >= b[0] - e && a[1] >= b[1] - e && a[2] <= b[2] + e && a[3] <= b[3] + e;

async function withActualHotel(assetId, inspect) {
  const original = instances.find(i => i.assetId === assetId);
  const fixture = {...structuredClone(original), displayName: 'Отель «Белведер»'};
  const before = structuredClone(fixture);
  const bytes = fs.readFileSync(path.join(root, fixture.binding.url.slice(1)));
  // Geometry and transforms are the real GLB. A CPU-only texture placeholder
  // avoids creating a browser, image decoder or competing GPU QA scene.
  const loader = new GLTFLoader().register(() => ({
    name: 'PURPOSE_AUDIT_TEXTURE_ONLY', loadTexture: () => Promise.resolve(new T.Texture()),
  }));
  const source = (await loader.parseAsync(bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength), '')).scene;
  const visual = source.clone(true), group = new T.Group(), transform = fixture.transform;
  visual.position.fromArray(transform.modelLocalOffsetM);
  group.position.fromArray(transform.positionM);
  group.rotation.y = transform.yawDegrees * Math.PI / 180;
  group.scale.setScalar(transform.uniformScale);
  group.add(visual);
  group.updateMatrixWorld(true);
  visual.traverse(node => {
    if (/^(COLLISION|SOCKET|CLEARANCE|NAV_|COL_)/i.test(node.name) ||
      (fixture.hideNodeNames ?? []).some(name => name.replace(/\./g, '') === node.name)) node.visible = false;
  });
  let applied;
  try {
    applied = createWindowedBuildingEntry({THREE: T, visual, instance: fixture});
    assert.ok(applied.entry?.interiorDesign, assetId + ' builds the actual integrated interior');
    assert.deepEqual(fixture, before, 'building identity, transform, binding and gameplay metadata remain unchanged');
    assert.equal(fixture.id, original.id);
    assert.deepEqual(fixture.binding, original.binding);
    await inspect(applied.entry);
  } finally {
    applied?.roomReveals.dispose();
    applied?.entry?.dispose();
    applied?.windows?.dispose();
    group.removeFromParent();
    const geometries = new Set(), materials = new Set(), textures = new Set();
    source.traverse(node => {
      if (node.geometry) geometries.add(node.geometry);
      for (const material of [].concat(node.material ?? [])) materials.add(material);
    });
    for (const material of materials) {
      for (const value of Object.values(material)) if (value?.isTexture) textures.add(value);
      material.dispose();
    }
    for (const geometry of geometries) geometry.dispose();
    for (const texture of textures) texture.dispose();
  }
}

for (const assetId of ['hospital', 'compact_podium_glass_tower_v1']) {
  test('actual ' + assetId + ' GLB furnished as a hotel has bedrooms, reception, dining and kitchen', async t => {
    await withActualHotel(assetId, entry => {
      const {rooms, purpose} = entry.interiorDesign;
      assert.equal(purpose.kind, 'hotel');
      assert.equal(entry.storeys.floors.length, BUILDING_STOREY_PROFILES[assetId].floors.length);
      assert.ok(entry.storeys.floors.length >= 3);
      assert.equal(entry.storeys.stairs.length, entry.storeys.floors.length - 1);
      const problems = [];
      for (const room of rooms) {
        const floor = entry.storeys.floors[room.level];
        if (room.purpose !== 'hotel') problems.push(room.id + ': incorrect purpose ' + room.purpose);
        if (!contained(room.rect, floor.rect)) problems.push(room.id + ': room extends beyond its actual floor');
        for (const item of room.placements) {
          if (!contained(item.bounds, room.rect)) problems.push(room.id + ': ' + item.kind + ' extends beyond room');
          if (item.y < floor.y - 1e-6 || item.y + item.height > floor.ceiling + 1e-6) problems.push(room.id + ': ' + item.kind + ' crosses floor/ceiling');
        }
      }
      const ground = rooms.filter(r => r.level === 0);
      const has = (list, role, kinds) => list.some(r => r.role === role && r.items.some(k => kinds.includes(k)));
      if (!has(ground, 'hotel_lobby', ['reception'])) problems.push('ground floor lacks a furnished hotel reception');
      if (!has(ground, 'dining_room', ['dining_set'])) problems.push('ground floor lacks a furnished dining room');
      if (!has(ground, 'kitchen', ['kitchen_counter'])) problems.push('ground floor lacks a furnished kitchen');
      const upstairs = rooms.filter(r => r.level > 0);
      if (!has(upstairs, 'guest_bedroom', ['bed', 'single_bed'])) problems.push('upstairs has no furnished guest bedroom');
      for (const bedroom of upstairs.filter(r => r.role === 'guest_bedroom')) {
        if (!bedroom.items.some(kind => kind === 'bed' || kind === 'single_bed'))
          problems.push('floor ' + bedroom.level + ' designated guest bedroom has no bed');
      }
      t.diagnostic(JSON.stringify({assetId, floors: entry.storeys.floors.length,
        rooms: rooms.map(r => ({level: r.level, role: r.role, rect: r.rect, items: r.items, rejected: r.rejected, omitted: r.omitted})), problems}));
      assert.deepEqual(problems, [], 'actual hotel room semantics and placed essential furniture');
    });
  });
}

test('semantic QA leaves the placement file byte-for-byte unchanged', () => {
  assert.equal(fs.readFileSync(placementPath, 'utf8'), originalPlacement);
});
