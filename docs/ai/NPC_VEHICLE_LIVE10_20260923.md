# NPC vehicle LIVE10 — 23 September 2026

One existing browser1/tab3, local preview18538, Easton S (`compact_sedan`).
Loaded base f30d6dc with the complete 0bec159 occupant/lifecycle checkpoint.
The temporary gun READY candidate bc6d220 was also loaded for bounded review.
No extra game tab or authenticated-server test was used.

## Accepted observations

- Actual E hold seated the hero as `front_left`. Three crew members boarded;
  X enabled defense and the published eligibility count was three.
- QA explosion used the existing vehicle damage owner. Published receipt:
  `accepted:true`, `duplicate:false`, `targets:4`, `delivered:4`.
- Hero health became zero with confirmed source death and blocked inputs.
- The three crew members (Елена Конти, София Моретти, София Манчини) were
  subsequently listed as hospitalized with the normal five-minute return timer.
- Hero subsequently recovered at the hospital: health100, deadfalse,
  inputsBlockedfalse, on_foot, occupiedSeatnull. No JavaScript errors were recorded.
- This establishes the local-preview explosion and hospitalization path. It does
  not establish authenticated damage, every crash severity, or later seat reuse.

## Gun candidate rejected

The ordinary rear view of Easton still showed mostly the rear-left passenger's
head; the small visible gun fragment was not a satisfactory fix. A street lamp
obscured the right side, so that side was not judged from the screenshot.

Independent expanded CPU checks also found a physical regression for compact /
male / front_right / Uzi: working grip segment -0.11773m behind the turned chest,
receiver and trigger inside, and eight body/frame intersections. The exact patch
was reversed from production; the baseline helper has no remaining Git diff.
The browser still contained that temporary candidate until its next reload.
Author is preparing a new coordinated torso/hand pose in isolated outputs.

## Main and performance

main/origin06a8035cb99f1e01f7b92688cd4cbbfcf2230c6e was published after this load.
It adds building-shadow default ON together with mandatory nested-render cleanup,
never the default change alone. Root repeated 76,320 actual-Three geometry checks,
nested/dispose/manual-map checks, and 30 render-freeze checks successfully.
The current browser had not loaded that pair yet. No current whole-scene FPS
improvement is claimed; concurrent CPU checks precluded comparable timing.
