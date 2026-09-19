// Civilian routine time, applied only to the final ordinary foot movement.
// Existing combat, vehicle, special-role and physics clocks remain unchanged.
const _npcCivilianElapsedState={epoch:1,frame:0,enabled:false,seconds:0};
function _npcResetCivilianElapsed(){const s=_npcCivilianElapsedState;s.epoch++;s.enabled=false;s.seconds=0;}
function _npcBeginCivilianElapsedFrame(elapsed,context){
 const s=_npcCivilianElapsedState;s.frame++;
 const enabled=!!context?.native&&!context.hidden&&!context.battle&&!context.hitStop&&!context.resuming&&Number.isFinite(elapsed)&&elapsed>0&&elapsed<=.5;
 if(!enabled||!s.enabled)s.epoch++;
 s.enabled=enabled;s.seconds=enabled?Math.min(.35,elapsed):0;
}
function _npcCivilianElapsedEligible(n,now){
 if(!n||typeof n.id!=='string'||!n.id.startsWith('resident_'))return false;
 if(n.dead||n.alive===false||Number.isFinite(n.hp)&&n.hp<=0||n._npcInitialPlacementPending||n._uniqueNpc||n._said||n._invulnerable||n._empireBoss||n._empireCrew||n._gang||n._arcKey==='bandit'||n._guard||n._cashier||n._policeCriminal||n.police||n._clientOfBiz||n._medicalCrewVehicleId||n._botCorpse||n._transientCorpseId||n._beach)return false;
 if(n._civilianActivity||n._civilianSeat||n._civilianTrip||n._civilianTripRiding||n._residentNativeVisit||n._residentIndoors||n._ambientTrafficDriver||n._inVehicle||n._inCar||n._vehicleHijackControlled||n._corpsePhoneCall||n._hijackReaction||n._medicalDowned||n._forcedCrawl||n._waterEscaping||n._evacuated||n._carriedByAmbulance||n._ambulanceInTransit)return false;
 if(n.snitching||n._hostile||n._fighting||n._fightingMelee||n._policeCuffed||n._playerConversationOpen||n._playerConversationUntil>now||n.panicUntil>now||n._knockedUntil>now||n._meleeStunnedUntil>now||n._burnUntil>now||n._npcSurrenderUntil>now||n._npcHelpingUntil>now||n._alertUntil>now||n._talking>now)return false;
 const state=n._lifeState;return !state||state==='idle'||state==='routine';
}
function _npcDropCivilianElapsed(n){
 // Only this helper's own participants have their old cadence debt discarded.
 // Do not change the existing cadence state of bosses/police/other actors.
 if(n._civilianElapsedOwned){n._npcSimCarry=0;n._npcSimDue=0;}
 n._civilianElapsedOwned=false;n._civilianElapsedDebt=0;n._civilianElapsedEpoch=0;
}
function _npcAccumulateCivilianElapsed(n,now){
 const s=_npcCivilianElapsedState;
 if(!s.enabled||!_npcCivilianElapsedEligible(n,now)){if(n._civilianElapsedOwned)_npcDropCivilianElapsed(n);return;}
 if(n._civilianElapsedOwned&&n._civilianElapsedEpoch!==s.epoch)_npcDropCivilianElapsed(n);
 // A repeated caller in this accepted frame cannot add elapsed twice.
 if(n._civilianElapsedOwned&&n._civilianElapsedFrame===s.frame)return;
 n._civilianElapsedOwned=true;n._civilianElapsedEpoch=s.epoch;n._civilianElapsedFrame=s.frame;
 n._civilianElapsedDebt=Math.min(.5,(n._civilianElapsedDebt||0)+s.seconds);
}
function _npcConsumeCivilianElapsed(n,physicsDt,now){
 const s=_npcCivilianElapsedState,debt=n._civilianElapsedDebt||0;
 const admitted=s.enabled&&n._civilianElapsedOwned&&n._civilianElapsedEpoch===s.epoch&&n._civilianElapsedFrame===s.frame&&_npcCivilianElapsedEligible(n,now);
 n._civilianElapsedDebt=0;
 if(!admitted){if(n._civilianElapsedOwned)_npcDropCivilianElapsed(n);return physicsDt;}
 return debt>0?debt:physicsDt;
}
