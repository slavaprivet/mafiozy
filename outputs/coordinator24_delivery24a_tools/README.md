#24a post-promotion tools — PREPARED, NOT RUN

`inspect_guards.py` only reads the four current shared paths, frozen candidate20
integration/export receipt and other receipt inputs, then saves its report here.
Unscoped differences are explicitly listed for preservation, not copied.

`test_shared_startup24a.gd` adapts the earlier23h ordinary-startup check. It starts
the unchanged default scene and verifies24a main/notes, five real visible update
labels without a restart notice,14original weapons,3hit owners/registered NPC,
8buildings/377collision bodies/shapes, two36x44cursor imports and scope texture.
No fixture flags, simulated input, placements or gameplay-state injection.

Only after Root promotion and a scheduled CPU slot, invoke
`run_shared_startup.py --out <fresh folder inside this directory>`.
The runner refuses before launching an engine unless all four shared after-SHA
guards already match candidate20. It uses the normal shared project and existing
imports; it does not run an editor import or write production source.

Prepared checks are not acceptance. This is headless startup only, not GPU,
performance or the user's intermittent focused-input acceptance.
