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
function _npcCivilianElapsedEligible(n,now,purposeful=false){
 if(!n||typeof n.id!=='string'||!n.id.startsWith('resident_'))return false;
 if(n.dead||n.alive===false||Number.isFinite(n.hp)&&n.hp<=0||n._npcInitialPlacementPending||n._uniqueNpc||n._said||n._invulnerable||n._empireBoss||n._empireCrew||n._gang||n._arcKey==='bandit'||n._guard||n._cashier||n._policeCriminal||n.police||n._clientOfBiz||n._medicalCrewVehicleId||n._botCorpse||n._transientCorpseId||n._beach)return false;
 if(!purposeful&&(n._civilianActivity||n._residentNativeVisit)||n._civilianSeat||n._civilianTrip||n._civilianTripRiding||n._residentIndoors||n._ambientTrafficDriver||n._inVehicle||n._inCar||n._vehicleHijackControlled||n._corpsePhoneCall||n._hijackReaction||n._medicalDowned||n._forcedCrawl||n._waterEscaping||n._evacuated||n._carriedByAmbulance||n._ambulanceInTransit)return false;
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
// Only these peaceful movements borrow wall time. Their existing movement
// functions still own every collision sweep, reservation and state transition.
function _npcActivityElapsedTarget(n,now){
 const visit=n._residentNativeVisit,a=n._civilianActivity;
 if(!visit&&!a)return null;
 if(!_npcCivilianElapsedEligible(n,now,true))return null;
 if(visit&&!a&&!visit.recovering&&['entering','exiting'].includes(visit.phase))return visit;
 if(!visit&&a&&(a.kind==='jog'&&a.phase==='active'||a.kind==='talk'&&a.phase==='approach'))return a;
 return null;
}
function _npcDropActivityElapsed(n){
 if(n._activityElapsedTarget){n._npcSimCarry=0;n._npcSimDue=0;}
 n._activityElapsedTarget=null;n._activityElapsedDebt=0;n._activityElapsedEpoch=0;
}
function _npcAccumulateActivityElapsed(n,now){
 const s=_npcCivilianElapsedState,target=s.enabled?_npcActivityElapsedTarget(n,now):null;
 if(!target){if(n._activityElapsedTarget)_npcDropActivityElapsed(n);return;}
 if(n._activityElapsedTarget&&(n._activityElapsedTarget!==target||n._activityElapsedPhase!==target.phase||n._activityElapsedEpoch!==s.epoch))_npcDropActivityElapsed(n);
 if(n._activityElapsedTarget===target&&n._activityElapsedFrame===s.frame)return;
 n._activityElapsedTarget=target;n._activityElapsedPhase=target.phase;n._activityElapsedEpoch=s.epoch;n._activityElapsedFrame=s.frame;
 n._activityElapsedDebt=Math.min(.5,(n._activityElapsedDebt||0)+s.seconds);
}
function _npcConsumeActivityElapsed(n,now){
 const s=_npcCivilianElapsedState,target=_npcActivityElapsedTarget(n,now),debt=n._activityElapsedDebt||0;
 const valid=s.enabled&&target&&n._activityElapsedTarget===target&&n._activityElapsedPhase===target.phase&&n._activityElapsedEpoch===s.epoch&&n._activityElapsedFrame===s.frame;
 n._activityElapsedDebt=0;
 if(!valid){if(n._activityElapsedTarget)_npcDropActivityElapsed(n);return null;}
 return {target,phase:target.phase,seconds:debt,epoch:s.epoch,frame:s.frame};
}
function _npcRunActivityElapsed(n,elapsed,physicsDt,now,tick){
 const s=_npcCivilianElapsedState;
 if(!elapsed||!s.enabled||elapsed.epoch!==s.epoch||elapsed.frame!==s.frame||_npcActivityElapsedTarget(n,now)!==elapsed.target||elapsed.target.phase!==elapsed.phase)return tick(n,physicsDt,now);
 let left=elapsed.seconds,result=false;
 for(let i=0;i<5&&left>1e-9;i++){
  if(_npcActivityElapsedTarget(n,now)!==elapsed.target||elapsed.target.phase!==elapsed.phase)break;
  const step=Math.min(.1,left);left-=step;result=tick(n,step,now);
  // A blocked step or completed phase cannot accumulate a later burst.
  if(!result||!n.walking)break;
 }
 return result;
}
