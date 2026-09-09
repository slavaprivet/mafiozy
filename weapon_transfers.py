"""Atomic persistent weapon transfers. No auth, networking or simulation owner.

The host injects an already-authenticated actor and its server-owned geometry.
Reserve ammunition stays in the owner's pockets. A last weapon of an ammo
family carries that family's loaded magazine; duplicate-family guns do not
duplicate the shared magazine. Picking up never changes equipped weapon,
current magazine or reload when the recipient already has that family.
"""
from __future__ import annotations

import json
import math
import re
import secrets
import time

import aiosqlite

TTL_SECONDS = 300
WORLD_METERS_PER_CELL = 4.1
PICKUP_DISTANCE_METERS = 2.2
VISIBLE_DISTANCE_METERS = 100
_REQUEST_ID = re.compile(r"^[A-Za-z0-9_.:-]{1,96}$")


async def ensure_schema(db):
    await db.execute("""CREATE TABLE IF NOT EXISTS weapon_ground_drops (
      drop_id TEXT PRIMARY KEY, owner_uid INTEGER NOT NULL, item_id TEXT NOT NULL,
      weapon_key TEXT NOT NULL, magazine INTEGER NOT NULL CHECK(magazine>=0),
      next_fire_at REAL NOT NULL DEFAULT 0, r REAL NOT NULL, c REAL NOT NULL,
      elevation REAL NOT NULL, space TEXT NOT NULL, layer TEXT NOT NULL,
      created_at REAL NOT NULL, expires_at REAL NOT NULL)""")
    await db.execute("CREATE INDEX IF NOT EXISTS ix_weapon_ground_expiry ON weapon_ground_drops(expires_at)")
    await db.execute("""CREATE TABLE IF NOT EXISTS weapon_transfer_receipts (
      uid INTEGER NOT NULL, request_id TEXT NOT NULL, binding TEXT NOT NULL,
      result_json TEXT NOT NULL, created_at REAL NOT NULL,
      PRIMARY KEY(uid,request_id))""")
    # Owner demo-loadout restoration must not mint another copy after a drop.
    await db.execute("""CREATE TABLE IF NOT EXISTS weapon_transfer_loadout_suppressed (
      uid INTEGER NOT NULL, item_id TEXT NOT NULL, PRIMARY KEY(uid,item_id))""")


def live_exterior_actor(world, uid, now=None):
    """Use accepted world x/y only; never HTTP coordinates/height.

    Current source world has no authoritative walk floor/elevation contract.
    Interior/explicit non-ground layers fail closed instead of crossing floors.
    The walk client additionally gates upper-floor transfers until that API lands.
    """
    now = time.time() if now is None else float(now)
    uid = str(uid)
    live = getattr(world, 'players', {}).get(uid) if world else None
    if not live:
        return {'ok': False, 'error': 'player_not_in_world'}
    if now - float(live.get('last_seen') or 0) > 10:
        return {'ok': False, 'error': 'player_position_stale'}
    if live.get('dead') or float(live.get('hp') or 0) <= 0:
        return {'ok': False, 'error': 'dead'}
    if (float(live.get('_jail_until') or 0) > now or live.get('_police_cuffed_by')
            or live.get('_police_downed_by') or float(live.get('_melee_stunned_until') or 0) > now
            or float(live.get('_emergency_transport_until') or 0) > now):
        return {'ok': False, 'error': 'custody_or_incapacitated'}
    if live.get('_in_interior') or live.get('_business_interior'):
        return {'ok': False, 'error': 'unsupported_surface'}
    if live.get('_walk_layer') not in (None, '', 'ground') or float(live.get('_walk_elevation') or 0) != 0:
        return {'ok': False, 'error': 'unsupported_surface'}
    if live.get('_swimming'):
        return {'ok': False, 'error': 'swimming'}
    for car in getattr(world, 'quest_cars', {}).values():
        if str(car.get('driver_uid') or '') == uid or uid in [str(p) for p in car.get('passenger_uids', [])]:
            return {'ok': False, 'error': 'transport'}
    try:
        r, c = float(live['y']), float(live['x'])
    except (KeyError, TypeError, ValueError):
        return {'ok': False, 'error': 'bad_server_position'}
    if not all(math.isfinite(v) for v in (r, c)):
        return {'ok': False, 'error': 'bad_server_position'}
    return {'ok': True, 'r': r, 'c': c, 'elevation': 0.0, 'space': 'world', 'layer': 'ground'}


class WeaponTransfers:
    def __init__(self, *, db_path, items, item_classes, mag_sizes, ammo_types,
                 ammo_limits, ammo_snapshot, bump_ammo_version, actor_provider,
                 line_of_sight=lambda actor, drop: True, clock=time.time):
        self.db_path = db_path
        self.items, self.classes, self.mag_sizes = items, item_classes, mag_sizes
        self.ammo_types, self.ammo_limits = ammo_types, ammo_limits
        self.ammo_snapshot, self.bump_ammo_version = ammo_snapshot, bump_ammo_version
        self.actor_provider, self.line_of_sight, self.clock = actor_provider, line_of_sight, clock

    def _key(self, item_id):
        key = self.classes.get(item_id, item_id)
        return key if self.items.get(item_id, {}).get('type') == 'weapon' and key in self.mag_sizes else None

    def _actor(self, uid, now):
        actor = self.actor_provider(uid, now)
        if not actor or not actor.get('ok'):
            return actor or {'ok': False, 'error': 'player_not_in_world'}
        try:
            valid = all(math.isfinite(float(actor[k])) for k in ('r', 'c', 'elevation'))
        except (KeyError, TypeError, ValueError):
            valid = False
        if not valid or not actor.get('space') or not actor.get('layer'):
            return {'ok': False, 'error': 'bad_server_position'}
        return actor

    @staticmethod
    def _public_drop(row):
        return {key: row[key] for key in ('drop_id', 'item_id', 'weapon_key', 'magazine',
                'r', 'c', 'elevation', 'space', 'layer', 'created_at', 'expires_at')}

    async def _inventory(self, db, uid):
        return await (await db.execute('SELECT item_id,quantity FROM inventory WHERE telegram_id=? AND quantity>0', (uid,))).fetchall()

    async def _state(self, db, uid):
        char = await (await db.execute('SELECT weapon,combat_version FROM characters WHERE telegram_id=?', (uid,))).fetchone()
        rows = await self._inventory(db, uid)
        return {'equipped_weapon': char['weapon'] if char else None,
                'combat_version': int(char['combat_version'] or 0) if char else 0,
                'inventory': [{'id': r['item_id'], 'qty': r['quantity']} for r in rows],
                'weapon_classes': sorted({self._key(r['item_id']) for r in rows if self._key(r['item_id'])}),
                'ammo_state': await self.ammo_snapshot(db, uid)}

    async def ground(self, uid):
        uid, now = int(uid), float(self.clock())
        actor = self._actor(uid, now)
        if not actor.get('ok'):
            return {**actor, 'server_now': now, 'drops': []}
        async with aiosqlite.connect(self.db_path) as db:
            db.row_factory = aiosqlite.Row
            await db.execute('PRAGMA busy_timeout=5000')
            await db.execute('BEGIN IMMEDIATE')
            await ensure_schema(db)
            now = float(self.clock())
            actor = self._actor(uid, now)
            if not actor.get('ok'):
                return {**actor, 'server_now': now, 'drops': []}
            await db.execute('DELETE FROM weapon_ground_drops WHERE expires_at<=?', (now,))
            radius = VISIBLE_DISTANCE_METERS / WORLD_METERS_PER_CELL
            rows = await (await db.execute('''SELECT * FROM weapon_ground_drops
              WHERE space=? AND layer=? AND r BETWEEN ? AND ? AND c BETWEEN ? AND ?
              ORDER BY created_at DESC LIMIT 256''', (actor['space'], actor['layer'],
                actor['r']-radius, actor['r']+radius, actor['c']-radius, actor['c']+radius))).fetchall()
            await db.commit()
        return {'ok': True, 'server_now': now, 'ttl_seconds': TTL_SECONDS,
                'drops': [self._public_drop(row) for row in rows]}

    async def drop(self, uid, request_id, item_id=None):
        return await self._transfer('drop', uid, request_id, item_id)

    async def pickup(self, uid, request_id, drop_id):
        return await self._transfer('pickup', uid, request_id, drop_id)

    async def _transfer(self, action, uid, request_id, target):
        uid, now = int(uid), float(self.clock())
        if not isinstance(request_id, str) or not _REQUEST_ID.fullmatch(request_id):
            return {'ok': False, 'error': 'bad_request_id'}
        if target is not None and (not isinstance(target, str) or len(target) > 96):
            return {'ok': False, 'error': 'bad_target'}
        binding = json.dumps([action, target], separators=(',', ':'))
        async with aiosqlite.connect(self.db_path) as db:
            db.row_factory = aiosqlite.Row
            await db.execute('PRAGMA busy_timeout=5000')
            await db.execute('BEGIN IMMEDIATE')
            await ensure_schema(db)
            now = float(self.clock())
            receipt = await (await db.execute('SELECT binding,result_json FROM weapon_transfer_receipts WHERE uid=? AND request_id=?', (uid, request_id))).fetchone()
            if receipt:
                if receipt['binding'] != binding:
                    return {'ok': False, 'error': 'request_conflict'}
                result = json.loads(receipt['result_json'])
                result.update(await self._state(db, uid))
                await db.commit()
                return {**result, 'replayed': True, 'server_now': now}
            actor = self._actor(uid, now)
            if not actor.get('ok'):
                return actor
            char = await (await db.execute('SELECT hp,weapon,jail_until FROM characters WHERE telegram_id=?', (uid,))).fetchone()
            if not char:
                return {'ok': False, 'error': 'no_character'}
            if int(char['hp'] or 0) <= 0 or float(char['jail_until'] or 0) > now:
                return {'ok': False, 'error': 'dead_or_jailed'}
            await db.execute('DELETE FROM weapon_ground_drops WHERE expires_at<=?', (now,))
            # Reconcile pre-existing legacy ammo on the same transaction first.
            await self.ammo_snapshot(db, uid)
            rows = await self._inventory(db, uid)
            if action == 'drop':
                result = await self._drop(db, uid, char, rows, actor, target, now)
            else:
                result = await self._pickup(db, uid, char, rows, actor, target, now)
            if not result.get('ok'):
                await db.rollback()
                return result
            result.update(await self._state(db, uid))
            result['server_now'] = now
            await db.execute('INSERT INTO weapon_transfer_receipts(uid,request_id,binding,result_json,created_at) VALUES(?,?,?,?,?)',
                             (uid, request_id, binding, json.dumps(result, separators=(',', ':')), now))
            await db.commit()
            return result

    async def _drop(self, db, uid, char, rows, actor, requested_item, now):
        item_id = str(char['weapon'] or '')
        key = self._key(item_id)
        if not key or requested_item not in (None, item_id):
            return {'ok': False, 'error': 'not_equipped_weapon'}
        owned = next((r for r in rows if r['item_id'] == item_id), None)
        if not owned:
            return {'ok': False, 'error': 'not_owned'}
        counts = await (await db.execute('SELECT COUNT(*),SUM(owner_uid=?) FROM weapon_ground_drops', (uid,))).fetchone()
        if counts[0] >= 2048 or (counts[1] or 0) >= 64:
            return {'ok': False, 'error': 'ground_full'}
        same_family_remains = any(self._key(r['item_id']) == key and (r['item_id'] != item_id or r['quantity'] > 1) for r in rows)
        ammo = await (await db.execute('SELECT magazine,next_fire_at FROM weapon_ammo WHERE telegram_id=? AND weapon_key=?', (uid, key))).fetchone()
        magazine = int(ammo['magazine'] or 0) if ammo and not same_family_remains else 0
        next_fire = float(ammo['next_fire_at'] or 0) if ammo else 0
        version = await self.bump_ammo_version(db, uid)
        # Switching away cancels only this family's reload, never consumes its reserve.
        await db.execute('UPDATE weapon_ammo SET magazine=?,reload_id=\'\',reload_ready_at=0,version=? WHERE telegram_id=? AND weapon_key=?',
                         (int(ammo['magazine'] or 0) if ammo and same_family_remains else 0, version, uid, key))
        await db.execute('UPDATE inventory SET quantity=quantity-1 WHERE telegram_id=? AND item_id=?', (uid, item_id))
        await db.execute('UPDATE characters SET weapon=NULL,combat_version=combat_version+1 WHERE telegram_id=?', (uid,))
        await db.execute('INSERT OR IGNORE INTO weapon_transfer_loadout_suppressed(uid,item_id) VALUES(?,?)', (uid, item_id))
        drop_id = secrets.token_urlsafe(18)
        await db.execute('''INSERT INTO weapon_ground_drops
          (drop_id,owner_uid,item_id,weapon_key,magazine,next_fire_at,r,c,elevation,space,layer,created_at,expires_at)
          VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)''', (drop_id,uid,item_id,key,magazine,next_fire,
            actor['r'],actor['c'],actor['elevation'],actor['space'],actor['layer'],now,now+TTL_SECONDS))
        row = await (await db.execute('SELECT * FROM weapon_ground_drops WHERE drop_id=?', (drop_id,))).fetchone()
        return {'ok': True, 'action': 'drop', 'drop': self._public_drop(row)}

    async def _pickup(self, db, uid, char, rows, actor, drop_id, now):
        drop = await (await db.execute('SELECT * FROM weapon_ground_drops WHERE drop_id=?', (drop_id,))).fetchone()
        if not drop or drop['expires_at'] <= now:
            return {'ok': False, 'error': 'drop_unavailable'}
        if drop['space'] != actor['space'] or drop['layer'] != actor['layer'] or abs(drop['elevation']-actor['elevation']) > .75:
            return {'ok': False, 'error': 'different_surface'}
        distance = math.hypot(drop['r']-actor['r'],drop['c']-actor['c']) * WORLD_METERS_PER_CELL
        if distance > PICKUP_DISTANCE_METERS or not self.line_of_sight(actor, dict(drop)):
            return {'ok': False, 'error': 'out_of_reach'}
        item_id, key, magazine = drop['item_id'], drop['weapon_key'], int(drop['magazine'])
        if self._key(item_id) != key:
            return {'ok': False, 'error': 'unsupported_weapon'}
        ammo = await (await db.execute('SELECT * FROM weapon_ammo WHERE telegram_id=? AND weapon_key=?', (uid,key))).fetchone()
        existing_family = any(self._key(r['item_id']) == key for r in rows)
        preserve_magazine = existing_family or self._key(str(char['weapon'] or '')) == key or bool(ammo and (ammo['reload_id'] or ammo['magazine']))
        version = await self.bump_ammo_version(db, uid)
        if magazine and preserve_magazine:
            ammo_type = self.ammo_types[key]
            reserve = await (await db.execute('SELECT rounds FROM ammo_reserve WHERE telegram_id=? AND ammo_type=?', (uid,ammo_type))).fetchone()
            total = int(reserve[0] or 0) + magazine if reserve else magazine
            if total > self.ammo_limits[ammo_type]:
                return {'ok': False, 'error': 'ammo_full'}
            await db.execute('''INSERT INTO ammo_reserve(telegram_id,ammo_type,rounds,version) VALUES(?,?,?,?)
              ON CONFLICT(telegram_id,ammo_type) DO UPDATE SET rounds=excluded.rounds,version=excluded.version''', (uid,ammo_type,total,version))
        elif not preserve_magazine:
            await db.execute('''INSERT INTO weapon_ammo(telegram_id,weapon_key,magazine,next_fire_at,version) VALUES(?,?,?,?,?)
              ON CONFLICT(telegram_id,weapon_key) DO UPDATE SET magazine=excluded.magazine,
              next_fire_at=MAX(next_fire_at,excluded.next_fire_at),version=excluded.version''', (uid,key,magazine,drop['next_fire_at'],version))
        await db.execute('''INSERT INTO inventory(telegram_id,item_id,quantity) VALUES(?,?,1)
          ON CONFLICT(telegram_id,item_id) DO UPDATE SET quantity=quantity+1''', (uid,item_id))
        await db.execute('DELETE FROM weapon_ground_drops WHERE drop_id=?', (drop_id,))
        # No characters.weapon, reload, or current-magazine changes here.
        return {'ok': True, 'action': 'pickup', 'pickup': {'drop_id': drop_id, 'item_id': item_id, 'quantity': 1}}
