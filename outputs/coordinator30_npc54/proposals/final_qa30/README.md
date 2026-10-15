# Final54 functional acceptance

Prepared; no native launch before root GO after medic merge/import.

```powershell
python -B outputs/coordinator30_npc54/proposals/final_qa30/run_final30.py final01 --go
```

Without `--go`, the adapter only reports readiness and external fixture hashes. It never imports, stages, copies or edits game54. It uses the locked engine directly and the current scheduler `Lease` API; each engine is the registered direct child of its read lease, with a bounded watchdog. Only its own child can be terminated. Root graphical reads may coexist. Fresh scheduler probe is performed before every case; an unavailable lane or a failure stops the sequence rather than repeatedly timing out.

All seven cases run against `outputs/coordinator30_npc54/game` through absolute external script paths: staff cycle, service guard, route/attention integration, daily policy, staff world, avoidance proxies and native avoidance. Every case compares all source pins, including `.uid`, before and after against one baseline. `.godot` cache is excluded. A change between cases aborts before starting another engine. Receipts, stdout/stderr, fixture archive and source hashes remain in the new run directory.

The cycle observer is the exact cycle03 `staff_cycle30.gd` plus read-only composition fields. `observer_delta.patch` describes all additions; `PROVENANCE.json` pins the original and derivative. `accept_cycle14.py` is the original 14-check acceptance function extracted unchanged. The cycle03 launch flags are reused with a fresh exact `--qa-out` and duration. HP, energy and wallet are initialized only by their existing launch flags; the observer does not move the resident, change HP, trigger transactions, fake arrivals or skip service/exit. Eight additional checks verify one live resident body, twelve live staff, eight new sites, eighteen unique activity definitions, physical site binding, successful staff setup, hospital→bank→restaurant order and observer-only operation. It does not claim all eighteen activities were performed during that one cycle; ambient's separate all-activity proof covers that behavior.

The staff-world fixture intentionally disables roaming residents and uses its existing explicit fixture bodies/destruction scenarios. It supplements the cycle composition proof; it does not replace it. Daily policy and avoidance proxies retain their original documented test doubles. None of these headless results is a rendered FPS or visual acceptance. Root/injury owns final graphical death and root owns comparable performance and freeze/delivery.
