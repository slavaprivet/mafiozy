# Candidate20 independent final source/export audit

**Verified: 209 source pins and all 316 embedded payload MD5s**, exact pack `634b9d3b48e4502538331da9b9e9efdb1641cfc83f04c40c65bd592bd4db7dd5`. Both EXE/PCK hashes match the export receipt. No engine, tests, GPU or candidate changes by this auditor.

Exactly four authored files differ from accepted16: cargo integration, optional camera reset in weapons, main revision constant, and notes. Main contains only the constant change. Default camera cancellation remains unchanged at all other call sites. Main/notes agree on `s01-20260930-quality24a`; five notes accurately keep RPG blast damage unavailable. Source review found no additional blocker in the composed held-movement return and stable-aim transaction fixes.

Packed comparison:304 payloads remain byte-identical;4 intentional runtime/notes payloads changed, plus the UID cache and7 internal scene metadata payloads. The latter were independently decoded, with exact byte offsets, lengths, hashes and before/after values saved in `CARGO20_METADATA_DRIFT.json`:

- Six imported GLB scenes differ **only** in PackedScene `node_ids` array values. Geometry, materials, skeleton, animation and every other decompressed serialized byte are identical.
- Exported main scene differs **only** in its one4-byte node_id plus the8-byte external resource UID following `res://scripts/main.gd`; all remaining bytes match.
- Authored gameplay IDs and the original source GLB/import configuration bytes are unchanged. These internal import identifiers are not a change to game entity IDs.

This is closure with declared, nonvisual import-ID drift; it is not a claim that all assets are raw-byte identical. Root chose to keep this exact20 export immutable and validate its actual compiled behavior. `CARGO20_FINAL_AUDIT.json` is the final machine-readable verdict; `CARGO20_CLOSURE.json` deliberately preserves the initial unexplained-drift finding and is superseded by the decoded proof.

Functional, focused input and performance acceptance remain with Root24. The earlier focus-loss quarantine hypothesis was withdrawn: existing cargo `_process` already clears those maps when access is invalid. No focus-policy change is part of candidate20.
