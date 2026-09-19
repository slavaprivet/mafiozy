# Overhead speech and selected-member greeting — 20 September 2026

Presentation owner `/root/safe_operator_clearance18`; chatter/voice/greeting source owner `/root/crew_follow_routes18`. Source contract: [MERCENARY_CHATTER_20260920_HANDOFF.md](MERCENARY_CHATTER_20260920_HANDOFF.md).

## Delivered

- `mercenary_speech_bubble.mjs` keeps one noninteractive subtitle over the actual speaker. NPC placement and hiding reuse the existing friendly badge's projected anchor, same actor-ID aliases, and existing bounded wall-occlusion result. It adds **no occlusion rays and no 3D draw calls**. Camera-only motion repositions/hides it each render. The bubble is not tagged `data-walk-hud`, avoiding a circular HUD mask over its own badge.
- Hero speech uses an optional `getHero` object and a cached head node; crouch/animation moves the anchor. Without that optional hook it falls back to the hero focus point + standing head height. Root should supply `getHero:()=>hero?.object` beside `getFocus` in the `createMercenaryWalk` call.
- `createMercenaryChatter` receives `onCaption`; its generic fixed caption is suppressed. The bubble follows line/null callbacks and has no independent expiration, so a real voice can finish before its text disappears. Source/chatter still owns speech queueing, actual voice duration, genders, mute and fallback behavior.
- The current badge-selected own member must remain selected for at least .45 s, be within 2.5 m, visible, alive and outside active work/defense. Then walk invokes `host.greetMember(id)` once per uninterrupted hover. Looking away resets the dwell. Source additionally validates group combat, availability and cooldown and turns the idle member toward the hero; UI does not rotate or stop actors itself.

## Verification / limits

New bubble/greeting cases plus existing badge regressions: **23/23 PASS**. Covers canonical speaker identity, wall hiding, first-frame camera turn, hero animated head, no additional rays after 100 bubble updates, null-caption removal, selected-member dwell, no continuous-hover spam, and suppression during work/battle/distance.

One DOM node, no new meshes. NPC per-render work reads an already computed badge anchor; only nearby selection gating runs at the existing 5 Hz prompt cadence. **Shared-scene performance and LIVE visual acceptance remain with root.** The full existing walk suite currently stops at its older moving-car fixture's assumed four-second plant interval while root is changing moving-target settling; that failure is outside this presentation scope and was reported to root rather than changing core behavior.
