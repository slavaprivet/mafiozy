const text=value=>typeof value==='string'&&value.trim()?value.trim():null;

// The integrated world keeps its gameplay controls in a ShadowRoot while the
// opt-in car QA panel lives on document.body.  Refresh the exact element owned
// by the panel instead of looking it up through either DOM root.
export function refreshVehicleFleetQaSelect(select,fleet){
 if(!select||!fleet)return {count:0,selectedId:null};
 const document=select.ownerDocument,previous=text(select.value),records=Array.isArray(fleet.records)?fleet.records:[];
 select.replaceChildren();
 const ids=new Set();
 for(const record of records){
  const id=text(record?.id);if(!id)continue;
  const option=document.createElement('option');option.value=id;option.textContent=text(record?.car?.profile?.label)||id;select.append(option);ids.add(id);
 }
 const activeId=text(fleet.activeId),selectedId=ids.has(previous)?previous:ids.has(activeId)?activeId:ids.values().next().value||null;
 if(selectedId)select.value=selectedId;
 select.disabled=!ids.size;
 return {count:ids.size,selectedId};
}
