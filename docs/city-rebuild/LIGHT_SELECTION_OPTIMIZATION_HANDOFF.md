# Street-light selection and material preservation — 2026-09-09

`street_lighting.mjs` now retains the nearest fixed light slots in a small
ordered scratch array. Each fixture distance is evaluated once. Equal-distance
fixtures retain insertion order, exactly matching the former stable full sort.
Light count, cutoff, falloff, intensity, positions and frame frequency are
unchanged. Static placement no longer walks fixtures just to build a sort array.

Tests: 2500 comparisons against the original sort, 120 Three-manager updates
checking exact position/intensity with day/night, removal, slot reuse and
placement invalidation. Real GLB lighting suite passes for 128 lamp assets /
176 luminaires. Node selection-only benchmark (192 fixtures, nearest 8,
20000 calls): full sort 573.74 ms; selection 37.50 ms. This is NOT a full-game
FPS measurement.

Review also found a regression from the earlier clipping optimization:
`building_entry.mjs` read material ranges from the output array under
construction instead of `source.groups`. Fixed the source reference; unordered
or overlapping groups use original first-match lookup. 456 clipped vertices
verified against source material assignments, plus 43-room / 675-pane suite.

HTTP 18538 serves the updated light module. Visual browser QA remains pending:
CUA discovery still reports `Unable to load browser request-header policy`.
User tab was not closed/refreshed. Reload is required for updated JS.
