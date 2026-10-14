APPLIED by Artist21 under explicit Coordinator20 release after independent ACCEPT.
Only commerce source delta applied; no registry/world/Walk activation.

# Certified service arrival — exact proposal, NOT APPLIED

Imported commerce remains frozen21e101. Root review-only transformer
npc_service_arrival23_patch_candidate.mjs produces the exact proposed change.
No world/Walk/registry changes made. Source diff generated beside this document.

Registered provider can add getServiceArrivalTarget({npc,visit,now}) returning
{r,c,y,stamp}; it must certify current building/revision/customer generation/
reserved visit+slot. stamp is stable for that visit and location. It must return
null for stale/invalid layout/slot, never use availability of a dead seller to
pretend the buyer has arrived. Seller eligibility remains a separate atomic check.
Getter must be O(1), with precomputed certified geometry; no global scene scan.

Resolver pins registration token+coordinates+stamp on the visit, no closures.
A changed provider, coordinates, stamp, thrown exception or removed registration
fails closed after pinning; it never falls back to an entrance checkout. Existing
providers WITHOUT this opt-in getter and unregistered buildings retain old target.
Pilot activation MUST supply the getter before registration. Both source Arrive
and Tick use the same getter, while canServe checks actual seller/buyer 3D poses.

Root world integration still required:
1. Preserve visit.door.inside and returnPoint/entryAlignment. Existing entrance
   movement gets physically inside before activating separate service approach.
2. Certified route is entrance -> customerVia -> customer, reverse for exit;
   do not steer diagonally through old jamb or solid counter. Pin site+visit
   before walking and use existing slot/control ownership, not a global override.
3. Service approach uses precise executor and same resolved final target. Until
   physical arrival, do not set browsing or create a commerce order. Validate
   floor/occupancy even at matching XZ. Awaiting seller/slot is bounded and exits
   through certified reverse route, releasing the existing building reservation.
4. Once physically there, browsing uses source Arrive/Tick unchanged apart from
   proposed target resolver. Death/replacement/panic/custody interrupts purchase.
5. Exit uses reverse customer route to original inside, then existing returnPoint;
   a cancelled visit must not take straight path across counter to outside.
6. Persist only primitives; unregister/site teardown invalidates pending visit.

This proposal only changes source arrival selection. It does not instantiate a
seller, grant spawn authority/HP/generation, certify camera occlusion, register
provider or activate a bank/hospital economy.

Actual geometry + exact proposed checkout source test:
node assets/maps/city_rebuild_v1/test_npc_service_arrival23_candidate.mjs
26 checks PASS. Physical entrance->customerVia->counter at60/7/3Hz;
entrance refuses purchase, actual arrival enables one debit+inventory, dead seller
cancels unpaid order, changed target/provider/removal fail closed, malformed
coordinates rejected, other buildings keep old target. No fake arrival boolean.
Actor records/slot/source lifecycle are fixture inputs, no world movement hook.

First seen opt-in registration is pinned even when getter returns null: later
unregister cannot turn a waiting rejected service visit into entrance checkout.
Patch uses LF bytes; git apply --check validates without source mutation.
