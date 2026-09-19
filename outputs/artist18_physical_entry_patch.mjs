// Staged only: no filesystem writes. User requires Walk physical doors, no
// legacy button/marker entry. Preserve the 2D game and non-entry actions.
export function stagePhysicalEntryPatch(source){
 function once(before,after){if(source.split(before).length!==2)throw Error('Expected unique anchor: '+before.slice(0,100));source=source.replace(before,after);}
 once('function _buildingInteriorTypeAt(r,c) {',`function _walkPhysicalEntryOnly(){return _walkRendererActive()&&!_buildingInt&&!_bankInt;}

function _buildingInteriorTypeAt(r,c) {`);
 for(const [signature,result]of [
  ['function _currentBuildingEntryTarget() {','null'],
  ['function _nearbyBuildingInteractionFor3D() {','null'],
  ['function _activateSelectedBuildingIfNear() {','false'],
  ['function activateCurrentBuildingEntry() {','false'],
  ['function _activateApartmentGuestEntry(){','false'],
  ['function _activateBankEntryFrom3D(bank) {',"{ok:false,reason:'physical-door'}"],
  ['function toggleNearbyBuildingActionsFrom3D(screenX=null,screenY=null) {',"{ok:false,reason:'physical-door'}"],
 ])once(signature,signature+'\n  if(_walkPhysicalEntryOnly())return '+result+';');
 // Keep explicit property dossier/ownership selection; entry actions themselves
 // are removed below, and selecting a bank cannot enter it programmatically.
 once('  // Чёрный рынок всегда важнее вручную выбранного соседнего дома.', '  if(!_walkPhysicalEntryOnly()){\n  // Чёрный рынок всегда важнее вручную выбранного соседнего дома.');
 once('  // Лидер постоянной банды зовёт прохожего в состав.', '  } // Walk uses its physical door interaction; continue to NPC/car actions.\n  // Лидер постоянной банды зовёт прохожего в состав.');
 once("  // Проверяем близость к банкам (приоритет — своя кнопка через _bankZoneCur)", `  if(_walkPhysicalEntryOnly()){
    _zoneCur=null;_bankZoneCur=null;document.body.classList.remove('near-business');
    const pvp=inArena(player.r,player.c);_pvpBn.style.display=pvp?'block':'none';document.body.classList.toggle('in-pvp',pvp);return;
  }
  // Проверяем близость к банкам (приоритет — своя кнопка через _bankZoneCur)`);
 once("_zoneEl.addEventListener('click', () => {", "_zoneEl.addEventListener('click', () => {\n  if(_walkPhysicalEntryOnly())return;");
 once("_gtaBtn.addEventListener('click', () => {", "_gtaBtn.addEventListener('click', () => {\n  if(_walkPhysicalEntryOnly()&&['building_enter','apt_guest_enter','major_enter'].includes(_gtaActionKind))return;");
 once("  if(sel.kind==='building')actions.push(['building'", "  if(!_walkPhysicalEntryOnly()&&sel.kind==='building')actions.push(['building'");
 once("  if(sel.kind==='business'&&_zoneEl.dataset.bizId===sel.id", "  if(!_walkPhysicalEntryOnly()&&sel.kind==='business'&&_zoneEl.dataset.bizId===sel.id");
 once("  if(_gtaBtn.style.display==='block'&&String(_gtaActionCarId)===String(sel.id))actions.push", "  if(!(_walkPhysicalEntryOnly()&&['building_enter','apt_guest_enter','major_enter'].includes(_gtaActionKind))&&_gtaBtn.style.display==='block'&&String(_gtaActionCarId)===String(sel.id))actions.push");
 once("  const landmarkAuthority=sel.kind==='business'?_selectedBusinessAuthorityDossier(sel.id):null;", "  if(!actions.length){_businessActionCard.classList.remove('show');return;}\n  const landmarkAuthority=sel.kind==='business'?_selectedBusinessAuthorityDossier(sel.id):null;");
 // _prepareSelectedEstablishmentActions also produces major_enter directly.
 once("  _gtaActionKind='major_enter';_gtaActionCarId=poi.id;_gtaBtn.dataset.establishmentAction='1';", "  if(_walkPhysicalEntryOnly()){if(['major_enter','building_enter','apt_guest_enter'].includes(_gtaActionKind)){_gtaActionKind=null;_gtaActionCarId=null;_gtaBtn.style.display='none';}}else{\n  _gtaActionKind='major_enter';_gtaActionCarId=poi.id;_gtaBtn.dataset.establishmentAction='1';");
 once("  _gtaBtn.textContent=`🚪 Войти: ${poi.name}`;_gtaBtn.style.display='block';", "  _gtaBtn.textContent=`🚪 Войти: ${poi.name}`;_gtaBtn.style.display='block';\n  }");
 return source;
}
