import {createBuildingInteriorDesign} from './building_interior_design.mjs';
import {createBuildingStoreys} from './building_storeys.mjs';
import {applyResidentialWindows} from './residential_windows.mjs';
import {createBuildingEntry,subtractBoxFromGeometry} from './building_entry.mjs';
import {applyBuildingSizeTransform,describeWorldRoom} from './building_size_policy.mjs';
import {allowRenderFreeze} from './render_freeze_qa.mjs';
import {preserveBuildingGardenSiteScale} from './building_garden_site_scale.mjs';
import {createDetentionNativeEntry} from './detention_native_sites.mjs';
import {applyHospitalPublicApproach} from './hospital_public_approach.mjs';
import {applyTowerPublicApproach} from './tower_public_approach.mjs';

// Explicit local QA comparison loads the saved pre-rebuild interiors and
// placement. Ordinary gameplay never loads the duplicate modules or JSON.
const baselineRequested=typeof location!=='undefined'&&allowRenderFreeze(location.href)&&(new URLSearchParams(location.search).get('standalone')==='1'||new URLSearchParams(location.search).get('previewcity')==='1')&&new URLSearchParams(location.search).get('interiorrevision')==='baseline';
const baseline=baselineRequested?await Promise.all([import('./interior_qa_baseline/building_window_integration.mjs'),fetch(new URL('./interior_qa_baseline/buildings_placement.v1.json',import.meta.url)).then(r=>r.json()).then(p=>new Map(p.instances.map(i=>[i.id,i])))]):null;

const revealGeometryCache=new Map(),revealCacheRecords=new Set();let revealCacheHits=0,revealCacheMisses=0;
function n(value){return Math.round(value*1e5)}
function geometryShapeKey(geometry){
 const b=geometry.boundingBox||(geometry.computeBoundingBox(),geometry.boundingBox);
 return [geometry.attributes.position?.count??0,b.min.x,b.min.y,b.min.z,b.max.x,b.max.y,b.max.z].map(n).join(',');
}
function revealSignature(node,transform,cuts){
 return `${node.name}|${geometryShapeKey(node.geometry)}|${transform.elements.map(n).join(',')}|${cuts.map(p=>[p.cut.min.x,p.cut.min.y,p.cut.min.z,p.cut.max.x,p.cut.max.y,p.cut.max.z].map(n).join(',')).join(';')}`;
}
function acquireRevealGeometry(key,create){
 let record=revealGeometryCache.get(key);if(record){record.refs++;revealCacheHits++;return record}
 record={key,geometry:create(),refs:1};revealGeometryCache.set(key,record);revealCacheRecords.add(record);revealCacheMisses++;return record;
}
function releaseRevealGeometry(record){if(--record.refs>0)return;revealGeometryCache.delete(record.key);record.geometry.dispose();revealCacheRecords.delete(record)}
export function buildingWindowRevealCacheStats(){return{entries:revealCacheRecords.size,refs:[...revealCacheRecords].reduce((sum,r)=>sum+r.refs,0),hits:revealCacheHits,misses:revealCacheMisses}}

// Discover all authored panes before room CSG removes their old opaque backing.
// Instanced recesses are excluded from ordinary-mesh entry clipping, then only
// the new inner room walls receive matching recess volumes.
export function createWindowedBuildingEntry({THREE:T,visual,instance,metresPerCell=4.1}){
 if(instance.role==='district_detention')return{entry:createDetentionNativeEntry({THREE:T,visual,instance}),windows:null,roomReveals:null};
 if(baseline){const old=baseline[1].get(instance.id)??instance,t=old.transform;visual.parent.position.fromArray(t.positionM);visual.parent.rotation.y=t.yawDegrees*Math.PI/180;visual.position.fromArray(t.modelLocalOffsetM);visual.parent.updateMatrixWorld(true);return baseline[0].createWindowedBuildingEntry({THREE:T,visual,instance:old,metresPerCell})}
 applyBuildingSizeTransform(visual,instance,T);
 const garden=preserveBuildingGardenSiteScale({THREE:T,visual,instance,metresPerCell});
 const windows=applyResidentialWindows({THREE:T,visual,instance}),originalVisibility=windows?.group.visible;let entry;
 try{if(windows)windows.group.visible=false;entry=createBuildingEntry({THREE:T,visual,instance,metresPerCell,sizeApplied:true});createBuildingStoreys({THREE:T,entry,visual,instance,metresPerCell,windows})}catch(error){entry?.dispose();windows?.dispose();garden?.restore();throw error}finally{if(windows)windows.group.visible=originalVisibility}
 const originals=[],acquired=[];
 if(windows&&entry){
  visual.updateWorldMatrix(true,true);const inverse=visual.matrixWorld.clone().invert();
  entry.object.traverse(node=>{
   if(!node.isMesh||!/^Entry_(Interior_(Left|Right|Rear|Front|Header)|Corridor_Wall)$/.test(node.name))return;
   const transform=new T.Matrix4().multiplyMatrices(inverse,node.matrixWorld),bounds=new T.Box3().setFromBufferAttribute(node.geometry.attributes.position).applyMatrix4(transform),cuts=windows.panes.filter(p=>bounds.intersectsBox(p.cut));if(!cuts.length)return;
   const record=acquireRevealGeometry(revealSignature(node,transform,cuts),()=>{let geometry=node.geometry;for(const pane of cuts){const next=subtractBoxFromGeometry(T,geometry,transform,pane.cut);if(geometry!==node.geometry)geometry.dispose();geometry=next}return geometry});
   originals.push([node,node.geometry]);acquired.push(record);node.geometry=record.geometry;
  });
 }
 let disposed=false;const roomReveals={dispose(){if(disposed)return;disposed=true;for(const[n,g]of originals)n.geometry=g;for(const record of acquired)releaseRevealGeometry(record)}};
 createBuildingInteriorDesign({THREE:T,entry,visual,instance,metresPerCell});
 if(garden){
  const getBodies=entry.getCollisionBodies.bind(entry),dispose=entry.dispose.bind(entry);let previous=null,cached=null;
  entry.getCollisionBodies=()=>{const bodies=getBodies();if(bodies!==previous){previous=bodies;cached=[...bodies,...garden.collisionBodies]}return cached};
  // Entry/storey CSG first restores its references to our private garden copy.
  entry.dispose=()=>{dispose();windows?.dispose();garden.restore()};entry.gardenSite=garden;
 }
 describeWorldRoom(entry);
 applyHospitalPublicApproach({THREE:T,entry,visual,instance});
 applyTowerPublicApproach({THREE:T,entry,instance});
 return {windows,entry,roomReveals};
}
