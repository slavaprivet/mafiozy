# Candidate58 all-services acceptance

merged58_services_graphical02 PASS37/37. The native shared scene completed all
four services in407.701s after startup (445.393s total child wall time): bank
resident2, hospital resident7, restaurant resident8, shop resident10. All four
entered, received actual staffed service, completed the transaction/treatment,
and physically exited. Two native TT hits reduced resident7 to12HP; actual
hospital treatment restored60HP. Ten original residents and twelve staff stayed
present, other residents continued moving, and account checks passed.

Exact1135 source pins before/after equal extended31/stage58_02/CANDIDATE58.json,
SHA4a00c3c85b4d705ce917c60a7d0b92deb634d24eb57b41cff2664d24e2cfb70e.
Source/control/harness drift is empty, stderr0, errors[]. The user's release57
game was preserved. This simultaneous functional run makes no FPS claim and
does not replace root's1200-second spatial soak.

The four native observer/entry/checker files are byte-identical to the historical
services_regression31 harness. Only the new run_services58 adapter adds exact
candidate validation, engine/scheduler/control before/after pins and immutable
whole-harness archive. Production, historical harness and old receipts are not
modified. The archived harness has five files and matches HARNESS_PINS.json.

Release evidence role:

- run: outputs/coordinator31_npc57/proposals/qa58_services/runs/merged58_services_graphical02
- harness_root: outputs/coordinator31_npc57/proposals/qa58_services
- entry: entry_services56.gd
- entry_sha256: c43c71419ffc469cd16d1b53129728bd1bff93f673afea7f4186d039a2e5d1dc
- checker: accept_services56.py
- checker_sha256: df62eda3bce3cdad6824e3ed897a331aba6545649abaf05540d2fb39213b0006
- pins_file: HARNESS_PINS.json
- archive: HARNESS.zip (SHAfd52684438f9393c26e1e5034628ef748ee2eae8cede852ca6538c6207eeffcf)

SERVICES58_RESULT.json independently rechecks raw source/control/archive pins.
The earlier headless merged58_services01 remains FAIL30/37 at its240s deadline:
three services completed, restaurant resident10 was still physically walking
after415.24m. Graphical02 is a separate420s-bounded run, not a relabelled result.
Graphical01 launched no engine: a new adapter variable shadowed expected source
pins, so its prelaunch guard stopped. Its error receipt/archive remain intact.
