# Получено Astra14 — 26 сентября 2026

Точный доступный ответ. truncated=false. Sandbox-only/обрезанный текст не полный пакет.

Художник21 — **конкретный S00 independent package готов**. Проверял опубликованный `main@fcfed9ce6e29ebd780d08d486b84dade1a08e569`; commit — первый Godot Walk preview, при этом его собственный контракт прямо оставляет businesses/ownership/police/NPC/persistence вне текущего gameplay-preview. :chatgpt-content-reference{index="0"}

**Runtime:** Godot `NOT_RUN`; GPU `NOT_RUN`; production/main/server/saves не изменялись. Dirty service WIP исключён из доказательств.

### `world_mechanics_regression.v1.json`
SHA256 `1bd4f43f6d138f96cc08c4dc79ad70bf9ed717c35cb347d8d4675f4bbb31b922`

```json
{
  "schema":"mafiozi.s00.regression-ledger/v1",
  "baseline":"fcfed9ce6e29ebd780d08d486b84dade1a08e569",
  "runtime":{"godot":"NOT_RUN","gpu":"NOT_RUN"},
  "rules":{
    "unknown_is_implemented":false,
    "dirty_pilot_is_golden":false,
    "presentation_id_is_save_id":false
  },
  "flows":[
    {
      "id":"lowhp_hospital_return",
      "status":"IMPLEMENTED_SOURCE",
      "owner":"mafiozi_bot.py+npc_empire.py",
      "writers":["SQLite character/empire medical state"],
      "save_ids":["telegram_id","leader_id","hospital_id"],
      "sources":[
        "mafiozi_bot.py",
        "npc_empire.py",
        "assets/maps/city_rebuild_v1/test_npc_hospital_actual.mjs"
      ],
      "golden":[
        "low HP/medical admission",
        "hospital identity preserved",
        "return/recovery uses authoritative state"
      ],
      "limits":[
        "Godot gameplay not accepted",
        "old MERCENARY_HOSPITAL_RETURN26 proposal is NOT applied"
      ]
    },
    {
      "id":"robbery_police_bank",
      "status":"PARTIAL_IMPLEMENTED",
      "owner":"npc_robbery_receipts.py+mafiozi_bot.py+world.html",
      "writers":[
        "characters.cash",
        "characters.wanted_stars",
        "npc_robberies",
        "npc_robbery_receipts"
      ],
      "save_ids":["telegram_id","npc_id","robbery_id"],
      "sources":[
        "npc_robbery_receipts.py",
        "test_npc_robbery_receipts23.py",
        "test_npc_hold_up_cash18.mjs"
      ],
      "golden":[
        "E starts authoritative robbery",
        "cash receipt is idempotent",
        "victim/witness report precedes police case"
      ],
      "unproven":["bank deposit/withdraw leg after police"],
      "limits":[
        "receipt helper does not own wanted-level mutation",
        "bank shell/interior is not proof of personal-bank economy"
      ]
    },
    {
      "id":"business_property_owner",
      "status":"IMPLEMENTED_SOURCE",
      "owner":"mafiozi_bot.py+npc_empire.py+SQLite",
      "writers":[
        "apartments_owned",
        "player_businesses",
        "npc_empire_holdings",
        "npc_empire_building_closures"
      ],
      "save_ids":[
        "telegram_id","apt_key","biz_id","holding_id","leader_id"
      ],
      "sources":[
        "test_owned_property_respawn.py",
        "test_owned_business_income_progression.py",
        "test_npc_business_reload.py"
      ],
      "golden":[
        "owner survives reconnect",
        "income/closure survives reload",
        "capture transfers authority once"
      ],
      "limits":[
        "Godot must consume IDs; never infer owner from scene node"
      ]
    },
    {
      "id":"resident_service_commerce",
      "status":"IMPLEMENTED_SESSION_PILOT",
      "owner":"world.html+npc_resident_commerce_source.js",
      "writers":["resident object session wallet/inventory/receipts"],
      "save_ids":["resident object/id session only"],
      "sources":[
        "assets/maps/city_rebuild_v1/npc_resident_commerce_source.js",
        "docs/city-rebuild/NPC_RESIDENT_COMMERCE_20260919_HANDOFF.md"
      ],
      "golden":[
        "physical print_shop checkout",
        "no debit before interior arrival",
        "dead/panic/fight interruption prevents payment"
      ],
      "limits":[
        "not authenticated server commerce",
        "not saved across reload",
        "does not credit player business",
        "pawnshop checkout not accepted"
      ]
    },
    {
      "id":"dead_checkout_stockroom60",
      "status":"UNVERIFIED_REQUIRED_GOLDEN",
      "owner":"UNKNOWN_ON_PUBLISHED_MAIN",
      "writers":[],
      "save_ids":[],
      "sources":[],
      "golden":[
        "dead actor cannot checkout",
        "stockroom door lifecycle 60s"
      ],
      "limits":[
        "no immutable published-main source evidence located; do not promote dirty service WIP"
      ]
    },
    {
      "id":"personal_bank_budget",
      "status":"CONCEPT_OR_UNVERIFIED",
      "owner":"NONE_PROVEN",
      "writers":[],
      "save_ids":[],
      "sources":[
        "docs/city-rebuild/BUSINESSES_BANKS_INVENTORY.md",
        "bank shell/interior assets"
      ],
      "golden":[],
      "limits":[
        "bank geometry is not economy authority",
        "requires explicit transaction/save contract before migration"
      ]
    },
    {
      "id":"service_pilot_dirty",
      "status":"DIRTY_WIP_EXCLUDED",
      "owner":"external dirty service WIP",
      "writers":[],
      "save_ids":[],
      "sources":[],
      "golden":[],
      "limits":[
        "not evidence for published main",
        "may only enter ledger after immutable source+tests"
      ]
    }
  ],
  "known_defects":[
    "service inventory contains index-derived IDs; index must not become a durable save ID",
    "published Godot preview has gameplayActive=false for world gameplay systems",
    "dead_checkout_stockroom60 has no verified immutable owner in this review",
    "personal bank/budget has geometry evidence but no proven authoritative economy contract"
  ]
}
```

### `validate_world_mechanics_regression.py`
SHA256 `fe140a6c33a4283c7338fbc210529e492f7a9fd32382570ff06b8bda07b579bb`

```python
import json,sys

d=json.load(open(sys.argv[1],encoding="utf-8"))
assert d["schema"]=="mafiozi.s00.regression-ledger/v1"
assert len(d["baseline"])==40

ids=set()
allowed={
 "IMPLEMENTED_SOURCE","PARTIAL_IMPLEMENTED",
 "IMPLEMENTED_SESSION_PILOT","UNVERIFIED_REQUIRED_GOLDEN",
 "CONCEPT_OR_UNVERIFIED","DIRTY_WIP_EXCLUDED"
}

for f in d["flows"]:
    assert f["id"] not in ids
    ids.add(f["id"])
    assert f["status"] in allowed
    assert isinstance(f["sources"],list)
    assert isinstance(f["save_ids"],list)

    if f["status"]=="IMPLEMENTED_SOURCE":
        assert f["sources"] and f["save_ids"] and f["writers"]

    if f["status"] in {
        "CONCEPT_OR_UNVERIFIED",
        "DIRTY_WIP_EXCLUDED",
        "UNVERIFIED_REQUIRED_GOLDEN"
    }:
        assert not f["writers"]

assert d["runtime"]=={"godot":"NOT_RUN","gpu":"NOT_RUN"}
print("PASS",len(ids),"flows")
```

### `test_world_mechanics_regression.py`
SHA256 `80c04a0b1a2d7c1d53c558077a86900ceb53f60b85fadfd6dd3a7e37bbf96a4c`

```python
import json,unittest
from pathlib import Path

D=json.loads(
 Path("world_mechanics_regression.v1.json").read_text(encoding="utf-8")
)
F={x["id"]:x for x in D["flows"]}

class Ledger(unittest.TestCase):
 def test_baseline(self):
  self.assertEqual(
   D["baseline"],
   "fcfed9ce6e29ebd780d08d486b84dade1a08e569"
  )

 def test_no_false_promotion(self):
  self.assertEqual(
   F["personal_bank_budget"]["status"],"CONCEPT_OR_UNVERIFIED"
  )
  self.assertEqual(
   F["service_pilot_dirty"]["status"],"DIRTY_WIP_EXCLUDED"
  )
  self.assertEqual(
   F["dead_checkout_stockroom60"]["status"],
   "UNVERIFIED_REQUIRED_GOLDEN"
  )

 def test_save_id_continuity(self):
  self.assertEqual(
   F["business_property_owner"]["save_ids"],
   ["telegram_id","apt_key","biz_id","holding_id","leader_id"]
  )
  self.assertIn("robbery_id",F["robbery_police_bank"]["save_ids"])

 def test_reload_contract(self):
  g=" ".join(F["business_property_owner"]["golden"])
  self.assertIn("survives reconnect",g)
  self.assertIn("survives reload",g)

 def test_session_pilot_not_persistence(self):
  self.assertIn(
   "not saved across reload",
   F["resident_service_commerce"]["limits"]
  )

if __name__=="__main__":
 unittest.main()
```

**Independent save/reload suite:** property ownership must preserve `telegram_id + apt_key`; business identity `biz_id`; NPC holding `leader_id + holding_id`; robbery `telegram_id + npc_id + robbery_id`. Godot scene/node IDs are never allowed to replace these canonical identities. `test_npc_business_reload.py` already supplies strong source-side reload evidence; the new test above makes preservation of those IDs an explicit S00 migration gate.

**Known HOLD:** requested `dead checkout → 60s stockroom door` cannot honestly be classified implemented from immutable `fcfed9c`; I found no published-main owner/evidence for that complete contract. Treat it as required golden behavior awaiting the dirty-service package, not as something Godot may invent. Likewise `personal bank budget` remains concept/unverified: bank GLBs, layouts and interiors prove spatial content, not an authoritative personal-bank transaction model.

**Dependencies:** Python stdlib for proposed validator/tests; existing source regression suites additionally require their current project dependencies (`aiosqlite`, Node where applicable). No Godot dependency for this independent package.

**Verdict to Художник21:** **READY FOR S00 COLLECTION / HOLD only on the two explicitly unverified flows.** The package is fail-closed: it prevents concept/dirty pilots from silently becoming migration canon while giving Root20 exact save-ID continuity gates.
