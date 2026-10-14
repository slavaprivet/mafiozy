# Optional full-catalogue UI costs (source only)

This folder contains two **separate** opt-in changes. It does not replace the
frozen editor, modify the live Godot project, or authorize any gameplay owner.
The source assembly must still use its genuine 9901 original records and
registry-derived editability. The two candidates should be measured and
reviewed independently.

## A. Match-index cache

`paged_filter_panel.gd` extends the frozen paged panel. It caches only the
integer indices of catalogue rows matching the current catalogue generation,
query and category. Page changes reuse that array and redraw at most 160 rows.
`set_catalog` increments the generation and invalidates matches. Each redraw
reads `available`, `reason`, labels, current selection and tooltips from the
panel's current catalogue; no permission or owner receipt is cached. As in the
base panel, the caller must call `set_catalog` when a registry admission changes.

`test_paged_filter_cache.gd` inherits the full paged assembly tests, then
compares base and candidate panel output for all pages, queries, categories,
permission-text changes and same-size catalogue replacement. It reports one
warmup plus five interleaved same-catalogue page-sweep CPU pairs. The source
family geometry, materials and collision are not modified by this candidate.

## B. Populate the final panel once

`paged_setup_once_controller.gd` extends the frozen paged controller. The
inherited setup creates a temporary base panel and immediately replaces it.
This opt-in passes an empty catalogue through that temporary construction,
then supplies all records once to the final frozen paged panel. It changes no
source document, owner gate or panel class.

`test_paged_setup_once.gd` inherits the full paged assembly tests with this
controller, compares the final document/catalogue/panel against the base
controller, then reports one warmup plus three interleaved setup CPU pairs.
Filtering remains the frozen panel in this test, so its times are separate
from candidate A.

## Later CPU window

From the repository root, after the coordinator releases a CPU slot:

1. `node tools/godot/map_editor_paged_filter_cache_candidate/stage.mjs --check`
2. `node tools/godot/map_editor_paged_filter_cache_candidate/stage.mjs --stage`
3. Run Godot 4.7.2 headless editor import on the returned destination.
4. Run `res://test_paged_filter_cache.gd` and
   `res://test_paged_setup_once.gd` sequentially, headless, on that stage.

The stage script admits the same SHA-pinned full assembly and writes the four
optional files plus a separate receipt into a unique output project. The
frozen assembly and production tree remain unchanged. These tests still use
the assembly's fixture owner callbacks: even a pass does not prove actual
`main.gd` K integration, original GPU pixels, full-scene frame time or
gameplay authority. The full source assembly still has protected special and
railway records; UI speed must never turn those into editable native owners.

## Verified isolated runs, 29 September

Godot 4.7.2 headless imports and tests were run sequentially after the CPU
slot was released. Neither stage touched production or the visible game.

- Filter test, final stage `outputs/map_editor_source_assembly_cka77Q`:
  80,528 checks, zero failures, original 9901/fresh 9904 objects, exit 0;
  import and test logs contain no engine error/failed/parse messages. One
  warmup and five full **62-page** sweeps gave baseline p50/p95
  132,706/144,154 µs and cached 44,821/46,983 µs. This measures ItemList
  refresh plus filtering in headless Godot, not frame time.
- Setup-once test, earlier stage `outputs/map_editor_source_assembly_7GBfKA`:
  80,463 checks, zero failures, original 9901/fresh 9904 objects, exit 0;
  import and test logs contain no engine error/failed/parse messages. One
  warmup and three paired setups gave baseline p50/p95
  1,540,161/1,575,296 µs and once 1,525,246/1,557,035 µs. The small
  apparent saving is within plausible desktop timing noise; this test does
  not establish a meaningful startup improvement.

The first filter-test run on stage `7GBfKA` passed semantic checks but its
timing retained a search query and covered one page. That timing is invalid;
the test-only query reset produced the final `cka77Q` 62-page result.
`cka77Q/source_receipt.json` SHA256 is
`d140adcc44c92f7606852425346318f02ac9a35c10eeb2e5078e302229acf5b9`;
its `filter_cache_receipt.json` SHA256 is
`47712e3f04d4b2919121ee456391c1894e0f42b2279c42c0e56b0cf6f5fd5e23`.
