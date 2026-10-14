# Initial placement: missing current runtime consumer seam

Readonly current integration inspection, 27September04:25MSK continuation. Algorithm packet7450 is ready; no physical admission or scene insertion was made by Artist21.

Pinned current files:
- scripts/npc_visual/preview_resident_host.gd SHA c8f3019aed3df7c6c908852ef95d2d70ee36750dd2b143c4574cc85f1ea71b06
- scripts/preview_population.gd SHA91815fd8851151fe8443a85b84b268a95a04c07ff39f0a136c60c631f58fe37c
- scripts/npc_visual/npc_preview_source_provider.gd SHA017d46e68a629516703cb9899169d1c688b29a4d3aa996d44c49bc1b01ac0efa
- scripts/npc_visual/preview_resident_world_policy.gd SHAf4e35012690fd4c6cd2c43a6973a8bb9d92b7ad34d493eba5084715eb6ed17f8

Confirmed missing seam: host _admit_record line128 constructs native point exclusively from record.row.source_raw.r/c, the immutable accepted birth row. admit_next line100 has no candidate argument. retry_pending line161 only resets attempted=false; it consequently retries the same raw birth position. preview_population.setup line48 calls admit_next once per original row, with no initial-placement solver. Adding a provider alone therefore cannot consume the new relocation proposals. This is a missing integration, not a regression in a frozen prepared model or a reason to rewrite e926 raw positions.

Root needs an explicit admitted-candidate seam alongside source_raw, retaining original source_id/bridge_id/descriptor hash. Match event.raw_id to immutable row.source_id (resident_72/169/252); object_key is only the full-context alias reference and must never replace the source ID. Validate event context/source/session/provider receipt/current life generation and source role before conversion. Keep the complete326 spacing solve before selecting the cropped3 actors. Ordinary road access must remain denied by the actual source BODY policy. Never reuse synthetic oracle candidates as scene positions.

Host support provider and _source_admits / _physical_clear must rerun on the current proposed point before cache instantiation. Source admission and physical admission are distinct; an event carries physical_admission=false until the root host proves support/collision under the current scene/lease. Last-minute death, scene/door/provider/ownership/epoch changes cannot be covered by the frozen startup dictionary. Unknown provider or missing current proof remains pending/faulted.

Coordinate conversion is source float64 r/c -> native x=c*4.1-395.65,z=r*4.1-45.1 only at the final host boundary. Source immutable heading/HP/look and prepared asset scale stay intact. No mutable placement field is added to the raw packet or source provider.

Root owns main/population/host integration. A new independent ROLE_BODY adapter has been proposed to root as the next Artist21 scope; no unsanctioned adapter/host implementation was started. This note is static interface evidence, not an actual-main/physics/LIVE/FPS test.
