// Resident-owned session economy. Server business income remains authoritative.
// Called only on destination choice and the existing physical interior visit tick.
const _residentShopCatalog=Object.freeze({
 print_shop:Object.freeze({item:'newspaper',label:'газету',price:3,need:'reading'}),
 pawnshop:Object.freeze({item:'used_watch',label:'часы',price:24,need:'personal'}),
 gun_shop:Object.freeze({item:'cleaning_kit',label:'набор для чистки',price:12,need:'supplies'})
});
const _residentCommerceStats={purchases:0,spent:0,insufficientFunds:0,interrupted:0};
function _residentCommerceUnit(n,salt){let h=2166136261;for(const ch of `${n.id}:${salt}`){h^=ch.charCodeAt(0);h=Math.imul(h,16777619);}return (h>>>0)/4294967296;}
function _residentCommerceAccount(n){
 return n._residentWallet??=( {balance:35+Math.floor(_residentCommerceUnit(n,'wallet')*85),inventory:{},receipts:[],serial:0} );
}
function _residentDoorPurpose(door){
 if(_residentShopCatalog[door?.assetId])return 'shop';
 if(door?.sourceKind==='bank'||/^bank_/.test(door?.assetId||''))return 'bank';
 if(door?.buildingRole==='residence')return 'home';
 if(['nightclub','strip_club','bookmaker'].includes(door?.assetId))return 'leisure';
 if(['hospital','civic_hall','fire_station'].includes(door?.assetId))return 'service';
 return 'visit';
}
function _residentAffordableShop(n,door,now){
 const item=_residentShopCatalog[door?.assetId];if(!item)return false;
 const wallet=_residentCommerceAccount(n);return wallet.balance>=item.price&&now>=(wallet.inventory[item.item]?.nextNeedAt||0);
}
const _residentPlaceCatalogs=new WeakMap();
function _residentPlaceCatalog(doors,now){
 let catalog=_residentPlaceCatalogs.get(doors);
 // One catalog scan per second across all residents, including same-length
 // replacement/removal by streamed geometry. Destination choice does no sort.
 if(catalog&&catalog.length===doors.length&&now<catalog.until)return catalog;
 const byId=new Map(),groups={home:[],work:[],leisure:[]};
 for(const d of doors){if(!d?.id||d.residentEligible===false)continue;byId.set(d.id,d);const purpose=_residentDoorPurpose(d);if(purpose==='home')groups.home.push(d);if(['service','bank','shop'].includes(purpose))groups.work.push(d);if(purpose==='leisure')groups.leisure.push(d);}
 catalog={byId,groups,length:doors.length,until:now+1000};_residentPlaceCatalogs.set(doors,catalog);return catalog;
}
function _residentPersonalPlaces(n,doors,allDoors,now){
 const catalog=_residentPlaceCatalog(allDoors,now),places=n._residentPersonalPlaces??={homeDoorId:null,workDoorId:null,leisureDoorId:null};
 for(const kind of ['home','work','leisure']){
  const field=kind+'DoorId',existing=catalog.byId.get(places[field]);
  const purpose=existing&&_residentDoorPurpose(existing);
  if(existing&&(kind==='home'?purpose==='home':kind==='leisure'?purpose==='leisure':['service','bank','shop'].includes(purpose)))continue;
  const candidates=catalog.groups[kind];let selected=null,best=Infinity;
  for(const door of candidates){
   if(n._civilianPlan?._failedDoors?.[door.id]>now)continue;
   const distance=Math.hypot((door.r??n.r)-n.r,(door.c??n.c)-n.c),score=distance+_residentCommerceUnit(n,kind+':'+door.id)*3;
   if(score<best){best=score;selected=door;}
  }
  places[field]=selected?.id||null;
 }
 return places;
}
function _residentChoosePurposeDoors(n,doors,routine,now,allDoors=doors){
 if(!doors.length)return doors;
 const places=_residentPersonalPlaces(n,doors,allDoors,now);
 const available=doors.filter(d=>!(n._civilianPlan?._failedDoors?.[d.id]>now));
 const retained=n._civilianPlan?.doorId;if(retained&&available.some(d=>d.id===retained))return available;
 const cycle=n._civilianPlan?.cycle||0;
 const purpose=routine==='home'?'home':routine==='work'||routine==='study'?'service':routine==='errands'||cycle%3===0?'shop':'leisure';
 const personalId=purpose==='home'?places.homeDoorId:purpose==='service'?places.workDoorId:purpose==='leisure'?places.leisureDoorId:null;
 const preferred=personalId&&available.find(d=>d.id===personalId);if(preferred)return [preferred];
 const matching=available.filter(d=>_residentDoorPurpose(d)===purpose&&(purpose!=='shop'||_residentAffordableShop(n,d,now)));
 if(matching.length&&purpose!=='home')return matching;
 // A temporarily blocked or distant home remains the resident's home. Visit
 // an available public place instead of adopting somebody else's house.
 if(purpose==='home'&&personalId){const publicDoors=available.filter(d=>_residentDoorPurpose(d)!=='home');return publicDoors;}
 // Unknown buildings remain visit destinations, never shops with invented stock.
 return matching.length?matching:available;
}
function _residentCommerceArrive(n,visit,now){
 const door=visit?.door;if(visit.commerce||!door?.inside||visit.phase!=='browsing'||Math.hypot(n.r-door.inside.r,n.c-door.inside.c)>.04)return false;
 const purpose=_residentDoorPurpose(door);visit.purpose=purpose;
 n._civilianPlan.purpose=purpose;
 if(purpose!=='shop'||!_residentAffordableShop(n,door,now))return false;
 const wallet=_residentCommerceAccount(n),item=_residentShopCatalog[door.assetId];
 visit.commerce={id:`${n.id}:${++wallet.serial}`,item,phase:'browse',since:now,payAt:now+1800,completeAt:now+3100,settled:false};
 visit.until=Math.max(visit.until,now+3700);return true;
}
function _residentCommerceTick(n,visit,now){
 const order=visit?.commerce;if(!order||order.settled)return false;
 if(visit.phase!=='browsing'||n.dead||n.alive===false||Number.isFinite(n.hp)&&n.hp<=0||typeof _civilianPlanInterrupted==='function'&&_civilianPlanInterrupted(n,now)||Math.hypot(n.r-visit.door.inside.r,n.c-visit.door.inside.c)>.08){order.settled=true;order.phase='cancelled';_residentCommerceStats.interrupted++;return false;}
 order.phase=now<order.payAt?'browse':'pay';
 if(now<order.completeAt)return true;
 const wallet=_residentCommerceAccount(n),item=order.item;order.settled=true;
 if(wallet.balance<item.price){order.phase='declined';_residentCommerceStats.insufficientFunds++;return false;}
 wallet.balance-=item.price;
 const old=wallet.inventory[item.item];wallet.inventory[item.item]={quantity:(old?.quantity||0)+1,nextNeedAt:now+300000};
 wallet.receipts.push({id:order.id,doorId:visit.door.id,item:item.item,price:item.price,at:now});if(wallet.receipts.length>8)wallet.receipts.shift();
 order.phase='complete';_residentCommerceStats.purchases++;_residentCommerceStats.spent+=item.price;
 n.cryText=`Купил${n.gender==='female'?'а':''} ${item.label}. Спасибо!`;n.cryUntil=now+2100;
 return false;
}
function _residentCommerceActivity(n){
 const order=n._residentNativeVisit?.commerce;if(!order||order.settled||n._residentNativeVisit.phase!=='browsing')return null;
 return {kind:'shop',phase:order.phase,since:order.since,payAt:order.payAt,until:order.completeAt};
}
function _residentNativeSegmentPassable(fromR,fromC,toR,toC){
 // This custom native-entry predicate includes terrain/water/vehicle gates.
 // _npcPathPassable intentionally does not add sweeps for custom callbacks,
 // so entry movement must explicitly retain the authored-solid capsule test.
 if(!_npcPathPassable(fromR,fromC,toR,toC,_residentNativePassable))return false;
 if(typeof _walkNpcNavigationResolver!=='function')return false;
 const swept=_walkNpcNavigationResolver({mode:'sweep',from:{r:fromR,c:fromC},to:{r:toR,c:toC},radius:.18});
 return !(swept?.swept===true&&swept.blocked);
}
function _residentNativeEntryLane(n,visit){
 if(visit.entryLaneChecked||visit.phase!=='entering')return;visit.entryLaneChecked=true;
 const door=visit.door,inside=door?.inside;if(!inside)return;
 const vr=inside.r-door.r,vc=inside.c-door.c,length=Math.hypot(vr,vc);if(length<.001)return;
 // Open leaves occupy one side of an otherwise wide enough doorway. Retain
 // the NPC footprint: find a small physically clear lane, do not shrink it.
 for(const offset of [0,.0125,-.0125,.025,-.025,.05,-.05,.08,-.08]){
  const dr=vc/length*offset,dc=-vr/length*offset,outside={r:door.r+dr,c:door.c+dc},target={r:inside.r+dr,c:inside.c+dc};
  if(!_residentNativeSegmentPassable(n.r,n.c,outside.r,outside.c)||!_residentNativeSegmentPassable(outside.r,outside.c,target.r,target.c)||!_residentNativeSegmentPassable(target.r,target.c,outside.r,outside.c))continue;
  visit.door={...door,...outside,inside:target};visit.entryLaneOffset=offset;
  if(offset)visit.entryAlignment=outside;
  return;
 }
}
