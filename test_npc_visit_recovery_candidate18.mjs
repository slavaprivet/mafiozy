// CPU-only staging transform. Does not modify production source.
export const residentVisitRecoveryHelpers=String.raw`
function _residentNativeRecoveryPass(r,c){return _npcBodyPassable(r,c,_residentNativePassable);}
function _residentNativeVisitReleaseUnavailable(n,visit,now){
 _cancelNpcDirectedSearch(n);_clearNpcRoute(n);n._residentNativeVisit=null;n._residentVisitStatus='visit-unavailable';
 n._buildingVisitCooldownUntil=now+18000;n.idleUntil=0;n.tr=n.r;n.tc=n.c;n.walking=false;
 n._civilianPlan={phase:'seek_shop',cycle:(n._civilianPlan?.cycle||0)+1,retryAt:now+18000};
}
function _residentNativeRecoveryTick(n,visit,now,dt){
 const target=visit.returnPoint;if(!target||!Number.isFinite(target.r+target.c)){n._residentVisitStatus='invalid-exit';n.walking=false;return true;}
 if(Math.hypot(n.r-target.r,n.c-target.c)<=.025){visit.recovering=false;_cancelNpcDirectedSearch(n);_clearNpcRoute(n);return false;}
 if(now<(visit.exitRetryAt||0)){n.walking=false;return true;}
 if(!n._route?.length){
  const ready=_planNpcRouteTo(n,target.r,target.c,_residentNativeRecoveryPass,.025,768,'building_entry');
  if(!ready){n.walking=false;n._residentVisitStatus=n._routeSearchPending?'exit-route-pending':'exit-path-blocked';if(!n._routeSearchPending)visit.exitRetryAt=now+1000;return true;}
 }
 let budget=Math.max(0,dt)*_npcEffectiveSpeed(n),moved=0;
 for(let i=0;i<8&&budget>1e-9&&n._route?.length;i++){
  const p=n._route[n._routeIndex||0],dr=p.r-n.r,dc=p.c-n.c,d=Math.hypot(dr,dc);
  if(d<1e-6){if(++n._routeIndex>=n._route.length){_clearNpcRoute(n);break;}continue;}
  const step=Math.min(budget,d),r=n.r+dr/d*step,c=n.c+dc/d*step;
  if(!_residentNativeSegmentPassable(n.r,n.c,r,c)){_cancelNpcDirectedSearch(n);_clearNpcRoute(n);visit.exitRetryAt=now+1000;n._residentVisitStatus='exit-path-blocked';break;}
  n.r=r;n.c=c;n.tr=p.r;n.tc=p.c;n.ang=Math.atan2(dr,dc);budget-=step;moved+=step;
 }
 n.walking=moved>0;n.walkPhase=(n.walkPhase||0)+moved*8;if(moved)n._residentVisitStatus='leaving-building';return true;
}
`;
export function stageResidentVisitRecovery(source){
 const patch=(before,after)=>{if(!source.includes(before))throw Error('Visit recovery staging anchor changed: '+before);source=source.replace(before,after);};
 patch('function _residentNativeVisitTick(n,dt,now){',residentVisitRecoveryHelpers+'\nfunction _residentNativeVisitTick(n,dt,now){');
 patch("if(n.dead||n.alive===false||n._medicalDowned){n._residentNativeVisit=null;", "if(n.dead||n.alive===false||n._medicalDowned){if(visit.recovering){_cancelNpcDirectedSearch(n);_clearNpcRoute(n);}n._residentNativeVisit=null;");
 patch('  let door=visit.door;', "  let door=visit.door;if(!visit.returnPoint&&Number.isFinite(door?.r)&&Number.isFinite(door?.c))visit.returnPoint={r:door.r,c:door.c};");
 patch("  if(!access?.ready){n._residentVisitStatus='waiting-for-door';n.walking=false;return true;}",
 `  if(!access?.ready){
   visit.accessWaitAt??=now;n._residentVisitStatus='waiting-for-door';n.walking=false;
   if(now-visit.accessWaitAt<3000)return true;
   if(visit.returnPoint&&Math.hypot(n.r-visit.returnPoint.r,n.c-visit.returnPoint.c)<=.10){_residentNativeVisitReleaseUnavailable(n,visit,now);return false;}
   visit.phase='exiting';visit.recovering=true;
  }else visit.accessWaitAt=null;`);
 patch("  const target=visit.phase==='entering'?(visit.entryAlignment||door.inside):door;", "  if(visit.recovering&&_residentNativeRecoveryTick(n,visit,now,dt))return true;\n  const target=visit.phase==='entering'?(visit.entryAlignment||door.inside):(visit.returnPoint||door);");
 patch("  if(!target||!Number.isFinite(target.r)||!Number.isFinite(target.c)){n._residentVisitStatus='invalid-entry';return true;}", "  if(!target||!Number.isFinite(target.r)||!Number.isFinite(target.c)){n._residentVisitStatus='invalid-entry';visit.phase='exiting';visit.recovering=true;return true;}");
 patch("    if(visit.phase==='entering'&&now-visit.blockedAt>3000){visit.phase='exiting';visit.blockedAt=0;}", "    if(now-visit.blockedAt>3000){visit.phase='exiting';visit.recovering=true;visit.blockedAt=0;}");
 patch("npc._residentNativeVisit={phase:'entering',door,since:now,blockedAt:0}","npc._residentNativeVisit={phase:'entering',door,returnPoint:{r:npc.r,c:npc.c},since:now,blockedAt:0}");
 return source;
}
