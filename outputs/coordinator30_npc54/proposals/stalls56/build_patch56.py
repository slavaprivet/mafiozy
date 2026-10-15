from pathlib import Path
import hashlib, json
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
BASE = ROOT / 'outputs/coordinator30_release55/game'

def build():
    changes = []
    def change(file, before, after):
        source = (BASE / file).read_text(encoding='utf-8-sig')
        assert source.count(before) == 1, (file, before)
        changes.append(dict(file=file, before=before, after=after))
    change('scripts/shop/npc_local_account.gd',
        '\tif visit._kind != kind or visit._phase != "INBOUND" or visit._route == null: return _fail("physical_route_required")',
        '\t# Reservation owns a genuine queued journey; only settle_economy28 can debit.\n'
        '\tif visit._kind != kind or visit._phase not in ["INBOUND", "WAITING"] or visit._route == null: return _fail("physical_route_required")\n'
        '\tif not visit._route.admission_current56(_token.body, str(_token.source_id), kind, visit._phase): return _fail("current_physical_route_required")')
    change('scripts/hospital/npc_restaurant_visit28.gd', 'func _prepare_wait() -> bool:',
        '## Account admission checks the real current registry claim, never a success receipt.\n'
        'func admission_current56(body: CharacterBody3D, id: String, kind: String, phase: String) -> bool:\n'
        '\tif body != _body or id != _id or kind != _kind or phase != _phase or _registry == null: return false\n'
        '\tif not is_instance_valid(body) or not body.is_inside_tree() or body.is_queued_for_deletion(): return false\n'
        '\tif not _registry.owns(_key, self): return false\n'
        '\tvar claim: Dictionary = _registry.ledger.requests.get(_key, {})\n'
        '\treturn claim.get("kind") == kind and claim.get("state") == ("waiting" if phase == "WAITING" else "reserved")\n\n'
        'func _prepare_wait() -> bool:')
    change('scripts/shop/npc_economy_visit28.gd', 'func active() -> bool:',
        '## A discretionary purchase may be retried after ordinary activities; hunger/bank cannot.\n'
        'func optional_purchase56() -> bool:\n'
        '\treturn _pending.get("kind") == "shop" and not bool(_pending.get("restore_energy", false)) and int(_account._account.get("cash", 0)) >= required_cash()\n\n'
        'func optional_retry56(now_ms: float) -> bool:\n'
        '\treturn not active() and now_ms < _retry_at and optional_purchase56()\n\n'
        'func active() -> bool:')
    change('scripts/shop/npc_economy_visit28.gd',
        '\t_phase = "WAITING" if _route.snapshot().phase == "WAITING" else "INBOUND"\n\tvar reserved: Dictionary = _account.begin_economy28(self, kind, now_ms)',
        '\t_phase = "WAITING" if _route.snapshot().phase == "WAITING" else "INBOUND"\n'
        '\tif _phase == "WAITING" and optional_purchase56():\n'
        '\t\t# No entry/money has occurred. Keep this exact purchase, release the capacity\n'
        '\t\t# request and browse the city until a staggered retry instead of standing 120s.\n'
        '\t\t_route.cancel(); _route = null; _phase = "IDLE"\n'
        '\t\t_reason = "optional_capacity_deferred"; _retry_at = now_ms + RETRY_MS + _rng.randf_range(0.0, 4000.0)\n'
        '\t\t_log("deferred", _reason); return false\n'
        '\tvar reserved: Dictionary = _account.begin_economy28(self, kind, now_ms)')
    change('scripts/npc_daily_life.gd',
        '\treturn _economy28_active() or (_economy28 != null and _economy28.has_pending_need())',
        '\treturn _economy28_active() or (_economy28 != null and _economy28.has_pending_need() and not _economy28.optional_retry56(_now))')
    change('scripts/npc_daily_life.gd', '\tif kind.is_empty():\n\t\t_phase = "RESTING"; _next_decision = maxf(_now + 250.0, float(_economy28.snapshot().retry_at))',
        '\tif kind.is_empty():\n\t\tif _economy28.optional_retry56(_now): return false\n\t\t_phase = "RESTING"; _next_decision = maxf(_now + 250.0, float(_economy28.snapshot().retry_at))')
    change('scripts/npc_daily_life.gd',
        '\tif not _economy28.begin(kind, _now):\n\t\t_goal = {}; _phase = "RESTING"; _next_decision = _now + 1000.0\n\t\treturn true',
        '\tif not _economy28.begin(kind, _now):\n\t\t_goal = {}; _phase = "RESTING"; _next_decision = _now + 1000.0\n\t\treturn not _economy28.optional_retry56(_now)')
    change('scripts/npc_city_daily.gd',
        '\t\t\t\tvar dsh_left: float=float(dsh_life._next_decision)-float(dsh_life._now)',
        '\t\t\t\tvar dsh_left: float=maxf(0.0, (float(dsh_life._next_decision)-float(dsh_life._now))/1000.0)')
    files = sorted(set(c['file'] for c in changes))
    spec = dict(schema='stalls56/exact-hunks-v1', baseline=str(BASE), changes=changes,
                baseline_sha256={f: hashlib.sha256((BASE/f).read_bytes()).hexdigest() for f in files})
    (HERE/'PATCH56.json').write_text(json.dumps(spec, ensure_ascii=False, indent=2), encoding='utf-8')
    for f in files:
        text=(BASE/f).read_text(encoding='utf-8-sig')
        for c in changes:
            if c['file']==f: text=text.replace(c['before'],c['after'],1)
        dest=HERE/'patch'/f;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_text(text,encoding='utf-8')
    print(json.dumps({'files':files,'hunks':len(changes)}))

if __name__=='__main__': build()
