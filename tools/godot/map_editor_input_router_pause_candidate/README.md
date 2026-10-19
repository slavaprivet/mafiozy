# Editor K route survives a real SceneTree pause — tools-only candidate

Original `editor_input_router.gd` SHA256
`ade622caa30ea58a787bbe2071d718235997d702c1245ee74d00d5ad03785573`
requires router as child of the current game owner. Its existing fixture disables
four per-node process flags but does not pause the whole SceneTree. Under a real
tree pause, an inheriting router stops receiving input along with its game
parent. This narrow candidate keeps exactly the router in PROCESS_MODE_ALWAYS;
the game parent remains PAUSABLE. It also refuses a queued owner/router.

Root built a fresh isolated stage `outputs/editor-router-pause-c1iyvy` and ran
official Godot4.7.2 headless: **7 checks PASS**, failures=[], no engine errors.
The engine's `root.push_input(K)` enters a real tree pause, four process-always
timer frames leave game callbacks stopped, `W` does not reach the game's
unhandled-input handler, and the same router receives `K` to exit while its
parent was paused. Queued-owner K is refused. No second GPU game was launched.

Source SHA256: router_v2
`a8d11469e463bd9f710e4832d19c8ec705f8c5f5ad44d1bd99491752c9574bbb`;
test `8da792c618fe207a03d6a9e0ff590291b9e94bd91188e03081b134c7de67b0ee`;
stage `c9339163936ab4cffbbcbef5b46b41d666a1606db5a8547032b2e899870dd2af`.

Reproduce: `node tools/godot/map_editor_input_router_pause_candidate/stage.mjs`,
then run Godot `--headless --path <new-output> --script res://test_router_pause.gd`.
All callbacks in the fixture are synthetic input-state toggles; no gameplay
authority, melee/input cooldown restoration, navigation/job quiescence, water,
terrain, actual main K hook, user map save, renderer visuals or full editor
readiness is conferred. A real main owner must gate its own input/action polling
even if a UI callback returns false. Only Coordinator22 may wire this into main
and manage the sole LIVE game.
