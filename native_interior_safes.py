"""Native room safe authority; adapters must bind HTTP identity before calling.

No client money, position, profession or registry is accepted. The optional
authority resolver must read a server-owned mercenary roster and live poses.
Until it exists, new unlocks return mercenary_not_authorized. Old raid/bank
systems are deliberately separate.
"""
from __future__ import annotations

import asyncio
from dataclasses import dataclass
import inspect
import json
import math
from pathlib import Path
import re
import sqlite3
import time
from types import MappingProxyType
from typing import Callable, Mapping

MANIFEST_PATH = Path(__file__).parent / "assets/maps/city_rebuild_v1/interior_safe_manifest.v1.json"
PURPOSES = frozenset({"hotel", "hospital", "civic", "police", "fire_station", "bank",
    "nightclub", "strip_club", "restaurant", "pawnshop", "gun_shop", "bookmaker",
    "print_shop", "workshop", "warehouse", "retail", "residential", "office"})


def _position(value):
    if isinstance(value, Mapping):
        value = [value.get("x"), value.get("y"), value.get("z")]
    if not isinstance(value, (list, tuple)) or len(value) != 3:
        raise ValueError("world position requires three metres coordinates")
    if any(isinstance(v, bool) or not isinstance(v, (int, float)) or not math.isfinite(v)
           for v in value):
        raise ValueError("non-finite world position")
    return tuple(float(v) for v in value)


def canonical_safe_id(building_id: str, room_id: str) -> str:
    if (not isinstance(building_id, str) or not building_id or len(building_id) > 160
            or not isinstance(room_id, str)
            or not re.fullmatch(re.escape(building_id) + r":floor:\d+:(?:main|room:\d+)", room_id)):
        raise ValueError("invalid canonical building/room identity")
    return "interior-safe:" + room_id


def default_safe_reward(safe_id: str) -> int:
    value = 2166136261
    for byte in safe_id.encode("utf-8"):
        value = ((value ^ byte) * 16777619) & 0xFFFFFFFF
    return 15 + value % 66


@dataclass(frozen=True)
class NativeSafeDefinition:
    id: str
    building_id: str
    room_id: str
    purpose: str
    position: tuple[float, float, float]
    reward: int


def load_safe_registry(manifest=MANIFEST_PATH) -> Mapping[str, NativeSafeDefinition]:
    """Read only a server-controlled manifest, never an HTTP request body."""
    if isinstance(manifest, (str, Path)):
        manifest = json.loads(Path(manifest).read_text(encoding="utf-8-sig"))
    if not isinstance(manifest, Mapping) or manifest.get("version") != 1:
        raise ValueError("unsupported safe manifest")
    rows = manifest.get("safes")
    if not isinstance(rows, list) or len(rows) > 1024:
        raise ValueError("invalid safe manifest rows")
    registry = {}
    for row in rows:
        if not isinstance(row, Mapping):
            raise ValueError("invalid safe row")
        building_id, room_id = row.get("buildingId"), row.get("roomId")
        safe_id = canonical_safe_id(building_id, room_id)
        if row.get("id") != safe_id or safe_id in registry:
            raise ValueError("duplicate or mismatched safe id")
        purpose = row.get("purpose")
        if purpose not in PURPOSES:
            raise ValueError("unknown building purpose")
        # The default stays in the established ordinary-building find range.
        # Its stable value is generated server-side, never from a client roll.
        reward = row.get("reward", default_safe_reward(safe_id))
        if isinstance(reward, bool) or not isinstance(reward, int) or not 0 <= reward <= 5000:
            raise ValueError("invalid server safe reward")
        registry[safe_id] = NativeSafeDefinition(safe_id, building_id, room_id, purpose,
                                                 _position(row.get("position")), reward)
    return MappingProxyType(registry)


@dataclass(frozen=True)
class NativeSafeAuthority:
    """A trusted server adapter constructs this from its roster and live state.

    HTTP JSON/dicts are intentionally not sufficient. observed_at must be the
    freshness timestamp of those authoritative poses, not the request timestamp.
    """
    user_id: str
    player_alive: bool
    player_position: tuple[float, float, float]
    mercenary_id: str
    mercenary_authorized: bool
    mercenary_alive: bool
    mercenary_profession: str
    mercenary_position: tuple[float, float, float]
    mercenary_building_id: str
    mercenary_room_id: str
    clear_path: bool
    observed_at: float


SCHEMA = """
CREATE TABLE IF NOT EXISTS native_interior_safe_states (
  safe_id TEXT PRIMARY KEY, building_id TEXT NOT NULL, room_id TEXT NOT NULL,
  opened_by TEXT NOT NULL, opened_at REAL NOT NULL, reward INTEGER NOT NULL,
  revision INTEGER NOT NULL DEFAULT 1, request_id TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS native_interior_safe_rewards (
  safe_id TEXT PRIMARY KEY REFERENCES native_interior_safe_states(safe_id),
  character_id INTEGER NOT NULL, amount INTEGER NOT NULL,
  awarded_at REAL NOT NULL, request_id TEXT NOT NULL
);
"""


class NativeInteriorSafeService:
    def __init__(self, db_path, *, registry=None, resolve_authority: Callable | None = None):
        self.db_path = str(db_path)
        self.registry = load_safe_registry() if registry is None else registry
        if not isinstance(self.registry, Mapping) or any(
                not isinstance(v, NativeSafeDefinition) or k != v.id
                for k, v in self.registry.items()):
            raise TypeError("registry must come from load_safe_registry")
        self.registry = MappingProxyType(dict(self.registry))
        self.resolve_authority = resolve_authority

    @staticmethod
    def _uid(user_id):
        value = str(user_id)
        if not re.fullmatch(r"[1-9]\d{0,17}", value):
            raise ValueError("invalid bound character id")
        return value

    def _connect(self):
        db = sqlite3.connect(self.db_path, timeout=10)
        db.row_factory = sqlite3.Row
        db.execute("PRAGMA foreign_keys=ON")
        db.executescript(SCHEMA)
        return db

    def _state(self, safe, row=None):
        return {"id": safe.id, "targetId": safe.id, "buildingId": safe.building_id,
                "roomId": safe.room_id, "opened": bool(row), "locked": not bool(row),
                "collected": bool(row), "revision": int(row["revision"]) if row else 0}

    def _hydrate(self, safe_ids):
        db = self._connect()
        try:
            rows = {r["safe_id"]: r for r in db.execute(
                "SELECT * FROM native_interior_safe_states WHERE safe_id IN ("
                + ",".join("?" for _ in safe_ids) + ")", safe_ids)} if safe_ids else {}
            return {"ok": True, "safes": [self._state(self.registry[s], rows.get(s)) for s in safe_ids]}
        finally:
            db.close()

    async def hydrate(self, user_id, *, safe_ids=None):
        try:
            self._uid(user_id)
        except ValueError:
            return {"ok": False, "reason": "unauthorized"}
        ids = list(self.registry) if safe_ids is None else safe_ids
        if (not isinstance(ids, list) or len(ids) > 128 or any(
                not isinstance(s, str) or s not in self.registry for s in ids)):
            return {"ok": False, "reason": "unknown_safe"}
        return await asyncio.to_thread(self._hydrate, list(dict.fromkeys(ids)))

    async def _authorize(self, uid, safe):
        if not callable(self.resolve_authority):
            return "mercenary_not_authorized"
        try:
            authority = self.resolve_authority(uid, safe)
            if inspect.isawaitable(authority):
                authority = await authority
        except Exception:
            return "mercenary_not_authorized"
        now = time.time()
        if (not isinstance(authority, NativeSafeAuthority) or authority.user_id != uid
                or authority.mercenary_authorized is not True
                or authority.mercenary_profession != "safecracker"
                or not isinstance(authority.mercenary_id, str) or not authority.mercenary_id):
            return "mercenary_not_authorized"
        if authority.player_alive is not True or authority.mercenary_alive is not True:
            return "actor_unavailable"
        if (not isinstance(authority.observed_at, (int, float))
                or not math.isfinite(authority.observed_at)
                or not 0 <= now - authority.observed_at <= 3):
            return "stale_authority"
        if (authority.mercenary_building_id != safe.building_id
                or authority.mercenary_room_id != safe.room_id or authority.clear_path is not True):
            return "safe_not_reachable"
        try:
            player, mercenary = _position(authority.player_position), _position(authority.mercenary_position)
        except ValueError:
            return "position_not_authorized"
        if (math.dist(player, safe.position) > 12
                or math.dist(mercenary, safe.position) > 1.8
                or abs(mercenary[1] - safe.position[1]) > .75):
            return "too_far"
        return None

    def _commit(self, uid, safe, request_id, now, *, authorized):
        db = self._connect()
        try:
            db.execute("BEGIN IMMEDIATE")
            character = db.execute("SELECT cash FROM characters WHERE telegram_id=?", (int(uid),)).fetchone()
            if not character:
                db.rollback()
                return {"ok": False, "reason": "no_character"}
            existing = db.execute("SELECT * FROM native_interior_safe_states WHERE safe_id=?", (safe.id,)).fetchone()
            if existing:
                db.commit()
                return {"ok": True, **self._state(safe, existing), "duplicate": True,
                        "gained": 0, "cash": int(character["cash"] or 0),
                        "awardedTo": existing["opened_by"]}
            if not authorized:
                db.rollback()
                return {"ok": False, "reason": "locked"}
            db.execute("""INSERT INTO native_interior_safe_states
                (safe_id,building_id,room_id,opened_by,opened_at,reward,request_id)
                VALUES(?,?,?,?,?,?,?)""", (safe.id, safe.building_id, safe.room_id,
                    uid, now, safe.reward, request_id))
            db.execute("""INSERT INTO native_interior_safe_rewards
                (safe_id,character_id,amount,awarded_at,request_id) VALUES(?,?,?,?,?)""",
                (safe.id, int(uid), safe.reward, now, request_id))
            db.execute("UPDATE characters SET cash=COALESCE(cash,0)+? WHERE telegram_id=?",
                       (safe.reward, int(uid)))
            cash = int(db.execute("SELECT cash FROM characters WHERE telegram_id=?", (int(uid),)).fetchone()[0])
            db.commit()
            return {"ok": True, **self._state(safe, {"revision": 1}), "duplicate": False,
                    "gained": safe.reward, "cash": cash, "awardedTo": uid}
        except Exception:
            db.rollback()
            raise
        finally:
            db.close()

    async def unlock(self, user_id, *, safe_id, building_id, room_id, request_id, now=None):
        try:
            uid = self._uid(user_id)
        except ValueError:
            return {"ok": False, "reason": "unauthorized"}
        safe = self.registry.get(safe_id) if isinstance(safe_id, str) else None
        if not safe or safe.building_id != building_id or safe.room_id != room_id:
            return {"ok": False, "reason": "unknown_safe"}
        if request_id != safe.id + ":unlock":
            return {"ok": False, "reason": "invalid_request_id"}
        now = time.time() if now is None else float(now)
        # Read an existing confirmed result before requiring a new profession
        # action. Replay is free and still returns this actor's current cash.
        existing = await asyncio.to_thread(self._commit, uid, safe, request_id, now, authorized=False)
        if existing.get("ok") or existing.get("reason") != "locked":
            return existing
        reason = await self._authorize(uid, safe)
        if reason:
            return {"ok": False, "reason": reason}
        return await asyncio.to_thread(self._commit, uid, safe, request_id, now, authorized=True)

    async def collect(self, user_id, *, safe_id, building_id, room_id, request_id):
        try:
            uid = self._uid(user_id)
        except ValueError:
            return {"ok": False, "reason": "unauthorized"}
        safe = self.registry.get(safe_id) if isinstance(safe_id, str) else None
        if not safe or safe.building_id != building_id or safe.room_id != room_id:
            return {"ok": False, "reason": "unknown_safe"}
        if request_id != safe.id + ":collect":
            return {"ok": False, "reason": "invalid_request_id"}
        # Unlock already committed the complete reward atomically.
        return await asyncio.to_thread(self._commit, uid, safe, request_id, time.time(), authorized=False)

    async def handle(self, bound_user_id, payload):
        """Route adapter after resolve_request_identity(expected_character=uid).

        Only these fields are read; client cash, coordinates, profession and
        mercenary claims have no authority. The route does not expose `now`.
        """
        if not isinstance(payload, Mapping):
            return {"ok": False, "reason": "invalid_request"}
        action = payload.get("action")
        if action == "hydrate":
            return await self.hydrate(bound_user_id, safe_ids=payload.get("safeIds"))
        if not isinstance(action, str) or action not in {"unlock", "collect"}:
            return {"ok": False, "reason": "invalid_action"}
        return await getattr(self, action)(bound_user_id, safe_id=payload.get("safeId"),
            building_id=payload.get("buildingId"), room_id=payload.get("roomId"),
            request_id=payload.get("requestId"))
