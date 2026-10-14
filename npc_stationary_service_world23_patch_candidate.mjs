// Review-only exact world delta. Does not write files or activate the station.
const install=String.raw`let _stationaryServicePilot23=null;
function _installStationaryServicePilot23(factory,station,geometryHost){
 if(typeof factory!=='function'||!_walkRendererActive()||_stationaryServicePilot23||station?.layout?.buildingId!=='REBUILD-VISUAL-print_shop-001')return null;
 const controller=factory({station,host:{...geometryHost,npcs:NPCS,spawnNpc,
  canControl:(n,now)=>!_civilianPlanInterrupted(n,now)&&!n._vehicleHijackControlled&&!n._civilianTrip&&!n._civilianTripRiding&&!n._ambulanceInTransit&&!n._medicalCrewVehicleId&&!n._playerConversationOpen&&!(n._playerConversationUntil>now)&&!(n.idleUntil>now),
  verifyDeath:(n,now)=>n.dead===true&&!n._medicalDowned&&Number.isFinite(n.deadAt)&&n.deadAt<=now&&n._deathRecord20?.confirmed===true&&n._deathRecord20.fatal===true&&n._deathRecord20.targetId===_threeNpcEntityId(n)&&n._deathRecord20.deathKey===String(n.deadAt)}});
 _stationaryServicePilot23=controller;
 return{controller,unregister(){if(_stationaryServicePilot23!==controller)return false;_stationaryServicePilot23=null;controller.dispose();return true;}};
}
`;
export function stationaryServiceWorldCandidate(source){
 const newline=source.includes('\r\n')?'\r\n':'\n';source=source.replace(/\r\n/g,'\n');
 const replaceOnce=(a,b)=>{if(source.indexOf(a)<0||source.indexOf(a)!==source.lastIndexOf(a))throw Error('Stationary source anchor changed: '+a.slice(0,90));source=source.replace(a,b);};
 replaceOnce('function _isRespawnableResident(npc) {',install+'function _isRespawnableResident(npc) {');
 replaceOnce('return !!npc&&!npc._medicalCrewVehicleId&&!npc._civilianTrip','return !!npc&&!npc._stationaryService&&!npc._medicalCrewVehicleId&&!npc._civilianTrip');
 replaceOnce('function _respawnResidentImmediately(deadNpc,now=performance.now()) {',
 `function _respawnResidentImmediately(deadNpc,now=performance.now()) {
  if(deadNpc?._stationaryService){
    // This call follows a definitive source death, including medical bleedout.
    // Preserve an existing bullet/blast record; do not turn downing into death.
    if(_stationaryServicePilot23?.owns(deadNpc)&&deadNpc.dead===true&&deadNpc.hp<=0&&!deadNpc._medicalDowned&&Number.isFinite(deadNpc.deadAt)&&deadNpc.deadAt>0&&deadNpc.deadAt<=now&&typeof createNpcFatalRecord20==='function')deadNpc._deathRecord20=createNpcFatalRecord20({entity:deadNpc,targetId:_threeNpcEntityId(deadNpc),weapon:'unknown',dirR:0,dirC:0,now:deadNpc.deadAt});
    return false;
  }`);
 replaceOnce('function pickNpcWaypoint(npc) {','function pickNpcWaypoint(npc) {\n  if(npc?._stationaryService){npc._npcWanderSearch=null;return false;}');
 replaceOnce('function _residentCanSocialize(n,now){','function _residentCanSocialize(n,now){\n  if(n?._stationaryService)return false;');
 replaceOnce('if(!_npcLifeEligible(n)||n===patient||n.dead','if(!_npcLifeEligible(n)||n._stationaryService||n===patient||n.dead');
 replaceOnce('    if (now < n.idleUntil) {\n      n.walkPhase = 0;',
 '    if(_stationaryServicePilot23?.ownsCalmMovement(n,now)){n.walking=false;continue;}\n    if (now < n.idleUntil) {\n      n.walkPhase = 0;');
 replaceOnce('  // Entries are collected after iteration so removing one resident cannot',
 '  _stationaryServicePilot23?.tick(now,simulationFrameDt);\n  // Entries are collected after iteration so removing one resident cannot');
 replaceOnce('window.Mafiozi3DBridge = Object.freeze({',
 'window.Mafiozi3DBridge = Object.freeze({\n  installStationaryServicePilot23(factory,station,geometryHost){return _installStationaryServicePilot23(factory,station,geometryHost);},');
 return newline==='\r\n'?source.replace(/\n/g,'\r\n'):source;
}
