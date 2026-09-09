import {createNpcActor,loadNpcSources} from './npc_actor.mjs';
import {applyNpcAppearance} from './npc_appearance.mjs';
import {createNpcGallery,createNpcGalleryPanel,npcGalleryVariants} from './npc_gallery.mjs';
import {NPC_DISPLAY_CATALOGUE} from './npc_role_catalogue.mjs';

export const NPC_GALLERY_ROWS=Object.freeze(NPC_DISPLAY_CATALOGUE.map(row=>Object.freeze({...row,role:row.appearance?.role||row.displayRole||row.role})));
export function npcGallerySampleRows(){
 const chosen=[],add=row=>{if(row&&!chosen.includes(row))chosen.push(row)};
 for(const role of ['boss','civilian','police','medic','guard'])add(NPC_GALLERY_ROWS.find(row=>row.role===role));
 add(NPC_GALLERY_ROWS.find(row=>row.appearance?.prisonGear));
 for(const row of NPC_GALLERY_ROWS)add(row);
 return chosen.slice(0,13);
}

// Caller explicitly opts in with ?npcgallery=1. This module never joins the
// authoritative population, consumes receipts, or creates gameplay identities.
export async function createNpcGalleryHost({THREE,scene,loader,cloneSkeleton,groundHeight,anchor,parent,document:doc=globalThis.document,loadSources=loadNpcSources,actorFactory=createNpcActor}={}){
 if(!doc||!parent)throw Error('Gallery host requires an explicit QA panel parent');
 const sources=await loadSources({loader});let disposed=false;
 const gallery=createNpcGallery({THREE,scene,groundHeight,anchor,createActor:options=>actorFactory({THREE,scene,source:sources[options.sex],cloneSkeleton,id:options.id,sex:options.sex,height:options.height,build:options.build,appearanceOwnsResources:true,applyAppearance:source=>applyNpcAppearance({THREE,scene:source,descriptor:options.descriptor,cloneTextures:true})})});
 const panel=createNpcGalleryPanel({document:doc,parent,gallery,rows:npcGallerySampleRows()});
 const select=doc.createElement('select');select.setAttribute('aria-label','Исходный персонаж или служебная роль');select.style.cssText='display:block;width:100%;margin-top:8px';
 for(const row of NPC_GALLERY_ROWS){const option=doc.createElement('option');option.value=row.id;option.textContent=row.label+(row.title?' · '+row.title:'');select.appendChild(option)}
 const button=doc.createElement('button');button.type='button';button.textContent='13 причёсок выбранного персонажа';
 const labels=doc.createElement('div');labels.style.cssText='max-height:150px;overflow:auto;font-size:11px';labels.setAttribute('aria-label','Имена тестовых копий по рядам');
 const originalPopulate=gallery.populate;
 gallery.populate=async rows=>{const records=await originalPopulate(rows);if(!disposed)labels.textContent=records.map((r,i)=>`${i+1}. ${r.label}`).join(' | ');return records};
 button.onclick=async()=>{button.disabled=true;try{await gallery.populate(npcGalleryVariants([NPC_GALLERY_ROWS.find(row=>row.id===select.value)||NPC_GALLERY_ROWS[0]]))}catch(error){if(!disposed)labels.textContent='Ошибка примерки: '+error.message}finally{if(!disposed)button.disabled=false}};
 panel.element.appendChild(select);panel.element.appendChild(button);panel.element.appendChild(labels);
 const sourceResources=new Set();for(const source of Object.values(sources))source.traverse(object=>{if(object.geometry)sourceResources.add(object.geometry);for(const material of Array.isArray(object.material)?object.material:object.material?[object.material]:[]){sourceResources.add(material);for(const value of Object.values(material))if(value?.isTexture)sourceResources.add(value)}});
 return {gallery,panel:panel.element,catalogue:NPC_GALLERY_ROWS,update:dt=>gallery.update(dt),dispose(){if(disposed)return;disposed=true;panel.dispose();for(const resource of sourceResources)resource.dispose();}};
}
