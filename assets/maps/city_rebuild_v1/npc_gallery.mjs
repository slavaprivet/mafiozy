// Opt-in visual fitting room. Actors are qa: copies, never the authoritative population.
import {describeNpcAppearance,NPC_HAIRSTYLES} from './npc_appearance.mjs';
import {bossArtDirectionForId} from './npc_boss_art_direction.mjs';
const DURATIONS={punch:.34,kick:.62,heavy:.50,dropkick:1.25};
export function createNpcGallery({THREE,scene,createActor,anchor={x:0,y:0,z:0},groundHeight=()=>anchor.y||0,columns=4,spacing=2.6}={}){
 if(!THREE||!scene?.isObject3D||typeof createActor!=='function')throw Error('NPC gallery needs THREE, scene and actor factory');
 const records=[];let disposed=false,generation=0,time=0,pose='stand',custom=null;
 const layout={columns:Math.max(1,Math.min(8,columns|0)),spacing:Math.max(2.1,Math.min(5,spacing)),anchor:{x:Number(anchor.x)||0,y:Number(anchor.y)||0,z:Number(anchor.z)||0}};
 const release=record=>{record.actor.dispose();record.actor.object?.removeFromParent()};
 async function populate(rows){
  if(disposed)throw Error('Gallery disposed');if(!Array.isArray(rows)||rows.length>40)throw Error('Gallery accepts up to 40 supplied catalogue rows');
  for(const row of rows)if(!row||row.id===undefined||row.id===null||!String(row.id))throw Error('Gallery requires source catalogue id for every row');
  const token=++generation,prepared=[];
  try{
   for(let i=0;i<rows.length;i++){
    const row=rows[i],sourceId=String(row.sourceId??row.id),id='qa:npc-gallery:'+String(row.id)+':'+i;
    const authored=bossArtDirectionForId(sourceId);
    const descriptor=describeNpcAppearance(id,{...row.appearance,...authored,sex:row.sex??row.appearance?.sex,role:row.role??row.appearance?.role??'civilian',hairstyle:row.hairstyle??authored?.hairstyle??row.appearance?.hairstyle??NPC_HAIRSTYLES[i%NPC_HAIRSTYLES.length]});
    const col=i%layout.columns,line=Math.floor(i/layout.columns),x=layout.anchor.x+(col-(layout.columns-1)/2)*layout.spacing,z=layout.anchor.z+line*layout.spacing;
    const y=typeof groundHeight==='function'?groundHeight(x,z):Number(groundHeight);if(!Number.isFinite(y))throw Error('Gallery ground height must be finite');
    const actor=await createActor({id,sourceId,descriptor,sex:descriptor.sex,height:descriptor.height,build:descriptor.build,role:descriptor.role,scene,qa:true});
    if(!actor?.object||typeof actor.update!=='function'||typeof actor.dispose!=='function'){actor?.dispose?.();actor?.object?.removeFromParent?.();throw Error('Gallery factory must return an NPC actor')}
    const record={id,sourceId,label:String(row.label??row.name??sourceId),descriptor,actor,position:{x,y,z},index:i};prepared.push(record);
    if(disposed||token!==generation){for(const item of prepared)release(item);return []}
    actor.object.userData={...actor.object.userData,qa:true,qaMode:'примерка NPC',sourceId};actor.update(0,{position:record.position,yaw:0});
   }
   for(const record of records)release(record);records.splice(0,records.length,...prepared);time=0;update(0);return records.slice();
  }catch(error){for(const record of prepared)release(record);throw error;}
 }
 function setPose(value='stand'){
  if(disposed)return;
  if(value&&typeof value==='object'){custom={...value};pose='custom'}else{if(!['stand','crouch','prone','walk','run','block',...Object.keys(DURATIONS)].includes(value))throw Error('Unknown gallery pose '+value);pose=value;custom=null}
  time=0;update(0);
 }
 function update(dt=0){
  if(disposed)return;if(!Number.isFinite(dt)||dt<0)throw Error('Gallery dt must be finite and non-negative');time+=Math.min(.1,dt);
  for(const record of records){
   const state={position:record.position,yaw:0,time,moving:pose==='walk'||pose==='run',running:pose==='run',posture:{target:pose==='crouch'?'crouch':pose==='prone'?'prone':'stand',value:pose==='crouch'?1:pose==='prone'?2:0,blocked:false}};
   if(pose==='block')state.action={type:'none',blocking:true};
   if(DURATIONS[pose]){const duration=DURATIONS[pose],phase=time%(duration+.55);state.action={type:pose,progress:Math.min(1,phase/duration),side:record.index%2?-1:1}}
   record.actor.update(Math.min(.1,dt),{...state,...custom,position:record.position});
  }
 }
 function dispose(){if(disposed)return;disposed=true;generation++;for(const record of records)release(record);records.length=0}
 return {populate,setPose,update,dispose,records,layout,get mode(){return 'примерка NPC'},get pose(){return pose}};
}

// Preserve real source labels/roles; variants are explicitly test copies of supplied catalogue entries.
export function npcGalleryVariants(catalogueRows){
 if(!Array.isArray(catalogueRows)||!catalogueRows.length)return [];
 return NPC_HAIRSTYLES.map((hairstyle,i)=>{const row=catalogueRows[i%catalogueRows.length];if(row.id===undefined||row.id===null)throw Error('Source catalogue id required');return {...row,sourceId:row.id,id:String(row.id)+':look:'+i,hairstyle,label:String(row.label??row.name??row.id)+' · '+hairstyle}});
}

export function createNpcGalleryPanel({document,parent,gallery,rows=[]}={}){
 if(!document?.createElement||!parent||!gallery)throw Error('Gallery panel needs document, parent and gallery');
 const panel=document.createElement('section');panel.setAttribute('aria-label','Примерка NPC');panel.style.cssText='position:absolute;top:72px;left:12px;max-width:350px;padding:12px;border:1px solid #b7a26e;border-radius:10px;background:#23343aed;color:#f0e6d2;font:13px system-ui;z-index:50';
 const title=document.createElement('strong');title.textContent='Примерка NPC · тестовые копии';panel.appendChild(title);
 const note=document.createElement('p');note.textContent='Отдельная проверка внешности и анимаций. Исходные жители города не меняются.';panel.appendChild(note);
 const status=document.createElement('div');status.setAttribute('role','status');status.textContent='Показ выключен';
 const make=(label,handler)=>{const b=document.createElement('button');b.type='button';b.textContent=label;b.style.cssText='margin:3px;padding:6px;border-radius:5px;border:1px solid #87999b;background:#344b56;color:#f4ecd9';b.onclick=handler;panel.appendChild(b);return b};
 let closed=false;const show=make('Показать 13 вариантов',async()=>{show.disabled=true;status.textContent='Подготовка…';try{const items=await gallery.populate(npcGalleryVariants(rows));if(!closed)status.textContent='Тестовых копий: '+items.length}catch(error){if(!closed)status.textContent='Не удалось создать примерку: '+error.message}finally{if(!closed)show.disabled=false}});
 for(const [key,label]of [['stand','Стоять'],['crouch','Присесть'],['prone','Лечь'],['walk','Ходьба'],['run','Бег'],['punch','Кулак'],['kick','Нога'],['heavy','Бэкфист'],['dropkick','Дропкик'],['block','Блок']])make(label,()=>gallery.setPose(key));
 make('Убрать копии',()=>{gallery.populate([]).then(()=>{if(!closed)status.textContent='Показ выключен'})});panel.appendChild(status);parent.appendChild(panel);
 return {element:panel,dispose(){if(closed)return;closed=true;panel.remove();gallery.dispose()}};
}

