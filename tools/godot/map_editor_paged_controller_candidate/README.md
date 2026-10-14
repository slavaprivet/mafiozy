# Setup-only paged Controller adapter + explicit source selection

New opt-in adapter extends the reviewed original native Controller. Frozen core
Controller, base Panel and frozen paged Panel are unchanged.

`setup(...)` has the same arguments/defaults as original. On first construction
it calls inherited setup exactly: document/source admission, registry binding,
camera, outline, owner edit/play callbacks and inactive state remain original.
Before returning success (no await or external workspace callback), it disconnects
and frees **only its newly constructed owned base panel**, constructs PagedPanel,
sets the supplied catalog and connects one inherited action handler. Existing,
active or atomic sessions cannot be replaced by another setup call.

The new owned panel receives a separate Russian **Выбрать на карте** button after
Add. It emits `select_existing` with `catalog_id`; it does not add or ray-pick an
object. Public `select_existing(id)` requires active, non-atomic editor, an existing
current document record, admitted registry identity, edit permission and actual
AABB bounds. Only after all checks does it update original `selected_id`, panel
selection and original bounds outline. It never teleports camera or modifies
the world/picking geometry. Invalid/deleted/absent/protected IDs preserve prior
selection. All other actions delegate directly to original Controller.

Original Workspace.setup replaces that single panel action handler with its own,
and its existing default dispatch delegates select_existing to the adapter. The
original panel mode signal is bound once. Therefore Add, Select, Move and Save
cannot acquire a second mutation/persistence handler during integration.

## Explicit owner integration

Stage `paged_editor_controller.gd` and frozen `paged_editor_panel.gd` at res://
alongside their original base files. Host opts in explicitly:

```gdscript
const Controller = preload("res://paged_editor_controller.gd")
var editor = Controller.new()
# Existing setup(...) first; Workspace.setup(editor, ...) only after success.
```

Do not copy this adapter over its original base path. Do not swap panels after
workspace signals/input owners are already attached. No package action modifies
core, production, main/player, viewport, gameplay authority or root stager.

## Fresh output-only native verification

```powershell
node tools/godot/map_editor_paged_controller_candidate/stage.mjs --check
node tools/godot/map_editor_paged_controller_candidate/stage.mjs --stage
& 'C:/Users/Слава/AppData/Local/MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --editor --path '<printed destination>' --import
& 'C:/Users/Слава/AppData/Local/MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path '<printed destination>' --quit-after 1200 --script res://test_paged_editor_controller.gd
```

The fixture uses original verified196 source GLBs, actual242 source placements,
actual native factory/registry/colliders and full9,901 catalog. Only236 actually
admitted source objects are available; protected banks/detention6 and missing
generated objects are not unlocked. Inherited outline/camera/doc compare with an
original Controller setup. A real page2 planter with duplicate labels is selected,
moved and undone; native source house is cloned and undone/redone; real bank,
absent, deleted clone and atomic selection are refused. Single handler before and
after original Workspace, inherited K, text/pointer guards, top/fly and one Save
dispatch are checked. Save-source admission uses original full-precision JSON.

Ground update/resume and persistence callbacks are explicitly test owner fixtures;
the actual native authored objects/registry/admission are not synthetic. This
bounded test does not claim full9,901 gameplay interaction or ground persistence
acceptance. Root independently adopts into the already verified unified fixture.
Headless tests do not replace LIVE/GPU/layout acceptance by the scene owner.

Final native regression: **703 checks PASS**, process exits0 normally. Original
pre-tree setup is preserved: panel substitution is synchronous; the single owned
button/hint decoration runs at that panel's ready signal after inherited UI build.
The newly owned hint accurately distinguishes map-click selection, explicit
catalog selection, and Add-copy creation in front of the camera. Existing input
hints are retained; no LMB-placement promise remains. Runtime and test hashes,
reviewed base Controller/Panel and frozen paged Panel pins are in receipt.json.
