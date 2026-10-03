# Private weapon restore49 — native PASS, not a production release

Actual native process A saved and exited; fresh native process B restored the same local weapon domain. Final native09: 22 save + 41 restore + 32 late-failure checks PASS (95), stderr0 for all three bounded children. Total 27.210 s. Source PID38224, successful restore PID9612, independent negative child PID32448. Parent replay rejection also PASS.

## Preserved state

14 identical item UIDs: 12 owned, one Nagan ground drop, one TT in cargo. All ownership/life references, drop UID/serial, item serial, cargo revision/serial, geometry and finite ammunition survived. Two actual shots consumed two cartridges: 896 → 894, and restore remained 894. TT cargo holds 11/36, sequence1. Equipped AK holds 29/90, sequence1, active reload2.0166666666666666 s; exact cooldown, recoil, heat and spray fields survived. Reload progressed normally after three fresh native ticks. No equip/configure normalization was used for adoption.

Real gameplay actions included TT equip, shot, drop and pickup; native backward movement to leave the new-session spawn clear; Nagan drop; one declared QA placement at the actual rear access point; actual F/G trunk window/store; AK equip, shot and reload. Both processes used the actual accepted48 main scene and retained its three NPCs.

Resume minted zero item UIDs and bypassed the new-session vehicle factory. Logical session ID/generation and actor/vehicle life identities were preserved explicitly. Native bodies, physics/effect bindings and opaque capabilities were fresh. The same coordinator rejects admission replay and postcommit replay. Parent ledger rejects a second use of its one-shot grant.

Clock policy is explicit LOCAL_OFFLINE_FREEZE: inventory clock resumes at captured simulation time. Ground TTL was 298076.036 ms before exit and 298075.171 ms immediately after adoption: 0.865 ms of fresh postcommit clock, no offline TTL loss. Active reload/cooldown are frozen over downtime; no offline heal, income or reward is granted.

## Failure behavior

Corrupt/truncated bytes cannot reuse the externally issued parent digest. Malformed checkpoint types, depth19, duplicate keys, unknown schema, cross-session byte substitution, pending transaction, duplicate UID, missing owner, stale vehicle life, server authority and unknown fire fields are rejected. The fresh local capability is not deserialized from JSON.

The independent negative child deliberately unbound the staged renderer's trunk before commit. Both owners passed preparation, renderer preparation then failed. Inventory and cargo remained byte-for-byte empty, mint count stayed zero and preview_ready stayed false. Prepared visuals belong only to an unpublished scene discarded by the fixture. Commit uses synchronous owner assignments after all fallible validation/render preparation, with no await or external callback between owners.

## Queue and preserved user windows

Scheduler0194 headless read leases needed 0.624 s (save), 0.638 s (restore), 0.579 s (negative child) in the queue. No manual GO. Each native child was immediately registered, limited to two logical CPUs and bounded by the 65 s fixture/85 s parent watchdog; only owned children were eligible for cleanup. Final scheduler inventory retains user editor25808 and game34540, with no active/pending test lease or registered child.

## Scope and review boundaries

This is a private weapon-only component implementation on accepted48. It does not save/restore NPC or player HP, player pose, vehicle damage/tyres, economy, buildings, server transactions or server identity. Its complete14-item fixture is deliberately bounded; it is not an arbitrary production inventory/save implementation. No real save keys, credentials, DB, browser storage, production source, launcher or current-version pointer were read or changed.

Parent provenance is an in-process trusted test service: after checking native source capture/exit/pins, it pins bytes and issues a one-shot nonce outside the document. JSON hashes are integrity checks, not ownership authority. A hostile OS/local file rollback across parent restarts is not solved; no server ACK is inferred. A production root service needs durable anti-replay/adoption policy before integration.

Five private patches are in patches/: main readiness gate; transport resume/fresh native binding; empty inventory startup in preview_weapons; exact owner inventory prepare/commit; fresh cargo geometry/identity prepare/commit. Review these exact diffs with transport owner before integration. Transport IDs are installed before weapon/effect configuration and before preview_ready, compatible with the owner's future condition-addon ordering requirement.

481 of 486 accepted source pins remain byte-identical; all486 original source pins were verified before/after every run. Engine SHAab1824f…2424, accepted48 SHA51484885…12b7, scheduler SHA0194f00d…cdc4 are pinned in RUN.json. Copied checkpointv2 SHA217669b4…bb11b is adapted only to the explicit local simulation clock; the original frozen v2 package is untouched.

## Evidence / replay

Final runs/native09/RUN.json and child RESULT.json are the acceptance evidence. Native08 is the first successful two-process proof. Native01–07 failures remain frozen: get_meta/null reporting; numeric dictionary origin comparison; and a QA PROCESS_MODE_DISABLED mistake that removed colliders from the native space. Diagnostic07 contains four empty floor rays and no adoption. Final fixture freezes script callbacks while retaining native collisions; no threshold or physics mask was relaxed.

runner.py stage creates a fresh isolated copy; import imports it; run launches the bounded three-child proof. sync is a private write-lease restaging operation only. build.py records how the patches were generated from accepted48 and initially adapted the pinned v2 checkpoint; rerunning that preparation requires an unmodified v2 helper copy. Existing run directories cannot be overwritten.

Functional evidence is not comparable FPS/memory or visual acceptance. Production acceptance remains false.
