# Focus fire and live work contacts — 19 September 2026

Scope: `mercenary_world.js`, `mercenary_core.mjs`, approved narrow `world.html` `_updateGang` target-validation hook, new `test_mercenary_focus_source.mjs`.

`eliminate` / «Устранить» is a source-owned squad order. It appears for a live supported NPC and requires at least one living armed member. It rejects own crew, unavailable/dead/downed/friendly/invulnerable targets and missing actors. Supported existing damage paths: street NPC (including non-invulnerable bosses), local city police, eligible current interior guards and bank NPCs. No new damage path, remote PvP authority, HP mutation, ammo grant or fire-rate override was added. `_updateGang` keeps existing movement, shooting cadence, hit callbacks and engagement range.

Focus takes precedence over ordinary defense while the exact target object remains valid. Death/despawn/replacement clears that focus, including between two shooters in one frame. Independent `_threat*` state remains available for ordinary combat. Rally/follow clear focus; specialist object commands clear it for their assigned worker. Automatic medic scan cannot replace an active focus. Ordinary unfinished specialist work is cancelled; armed bomb safety and pending receipts finish before that member joins focus.

Core stores and publishes copied finite `workPoint`, `workNormal`, `supportPoint`, refreshed from the current target on each non-awaiting update. Published pose mutation cannot corrupt source contacts. Downed crew/player descriptors preserve root `position` and expose `.75 m` work range, chest point `.35 m` above ground and nearby support point. Working members face the latest work point, including moving objects. Cutting label is now «Прорезать сетку» for the torch animation.

Validation: **87/87** selected core/action/world/record/rally/combat tests passed; then added same-frame kill regression and **7/7** focused/contact tests passed. These execute the real source adapter and extracted real `_updateGang`, with existing damage callbacks instrumented as authority boundaries. Fullscene FPS and visible weapon/IK behavior remain coordinator LIVE work; no browser controlled here.
