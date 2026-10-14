# Opt-in paged Russian catalog panel

Additive source-only UI subclass. Frozen core `editor_panel.gd` is unchanged.
All 9,901 current original map IDs are reachable on 62 pages, with at most160
ItemList entries. Russian previous/next buttons, page count, result range and
ID tooltips; case-insensitive substring search accepts labels **or IDs**.
Existing category/default-category semantics and matching order are unchanged.
Only normalized label/ID strings are cached once per `set_catalog`; availability
and refusal reasons are read afresh while displaying each page. The host remains
the only authority admitting additions. This UI never unlocks source objects.

Selection stays selected only if it is still available on the current page.
Changing page clears off-page selection so Add cannot accidentally add an unseen
entry. Add signal and payload remain `action_requested("add", {catalog_id: id})`.
The inherited edit selection label, movement controls, mode/action signals,
pointer guard, text-focus guard and inactive behavior are unchanged. Navigation
buttons use FOCUS_NONE, matching existing action buttons. Labels/IDs must be
updated through set_catalog; the normalized cache is rebuilt each time.

## Explicit opt-in constructor substitution

Stage `paged_editor_panel.gd` as `res://paged_editor_panel.gd` alongside the
unchanged `res://scripts/map_editor/editor_panel.gd`. An integrating owner may
explicitly change its controller's panel preload/constructor to this subclass:

```gdscript
const EditorPanel = preload("res://paged_editor_panel.gd")
# Existing panel = EditorPanel.new(), signals and setup stay unchanged.
```

The package does NOT apply that substitution to core, production or a viewport.
Do not replace the base file with the subclass (it extends that original path).

## Isolated check

```powershell
node tools/godot/map_editor_paged_panel_candidate/stage.mjs --check
node tools/godot/map_editor_paged_panel_candidate/stage.mjs --stage
& 'C:/Users/Слава/AppData/Local/MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path '<printed destination>' --script res://test_paged_editor_panel.gd
```

The stager creates a new isolated output-only project without any GLBs/imports,
pins original core UI/catalog source hashes and never overwrites production.
Native tests cover pre-ready catalog setup, duplicate labels, original label and
category behavior, late-ID search/add, unavailable refusal text, refreshed
availability, cache invalidation, selection, previous/next signals, all9,901 IDs
exactly once, empty/negative/out-of-range pages and inherited focus/pointer guards.
The actual inventory test uses an explicitly synthetic registry admission fixture
to exercise UI reachability, not a claim of all-object gameplay authority.

Final native run: **9,996 checks PASS**, all9,901 IDs /62 pages traversed in141,114µs
total (UI construction/CPU only; not frame time/FPS). Runtime/test source hashes
are frozen in receipt.json and verified by the stager. Headless verification is not LIVE visual/layout
or gameplay integration acceptance; GPU work remains with the scene owner.
