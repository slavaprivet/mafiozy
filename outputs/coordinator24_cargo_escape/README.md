# Narrow F → Escape regression — prepared, not executed

test_escape.gd loads whichever exact compiled pack Root selects via --main-pack. It never overrides game scripts or manually steps gameplay/door/NPC owners. Original3NPC,8buildings,377collision objects/shapes, player, transport and attached camera remain enabled. The sole setup relocation places the player behind the real hatch; all tested contents opens use actual F dispatch, never open_window(). Setup stores one exact TT through real F/G, then returns through Q and holds a Nagan.

Arguments after `--`:

- Baseline20: omit --expect-fixed. Assertions must prove modal ESC leaves logical movement suspended and requires one neutral reacquire click.
- Candidate22: add --expect-fixed. Assertions must prove actual F → ESC immediately restores logical capture/physically held W and real motion without any click. Same held ESC echo and matching release must not toggle capture again; a second distinct ESC in ordinary gameplay must release the cursor.
- Optional --gpu requires a normal native focused window and actual MOUSE_MODE_CAPTURED immediately after fixed modal ESC. No offscreen/NO_FOCUS flags or logical focus bypass.
- --qa-out=<new directory>, --exact-pack=<absolute PCK>, --expected-sha=<64hex> provide a JSON result and optional exact-pack verification. Root's bounded launcher should guard the process/window and validate its receipt.

All original UIDs, all owned weapon magazine/reserve counts, exact cargo contents and equipped identity must remain equal across the ESC sequence; shots/held fire remain unchanged. Lid and seat are unchanged. This is Godot input injection, not manual OS keyboard evidence, full-city performance or a blanket intermittent-freeze fix. No engine or GPU was run by the author while preparing this harness.
