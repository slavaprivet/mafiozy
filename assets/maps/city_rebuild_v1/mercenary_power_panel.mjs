import {MERCENARY_FENCE_SITE} from './mercenary_fences.mjs';

// One authored circuit. No timer, traversal or scene-wide lighting mutation.
export const MERCENARY_POWER_SITE=Object.freeze({id:'service-yard:print_shop-001:power',x:MERCENARY_FENCE_SITE.x+2.15,z:MERCENARY_FENCE_SITE.z-2.75});
export function createMercenaryPowerPanel({THREE,groundHeight=()=>0,powered=true,onPowerChange,persistPower=()=>{},site=MERCENARY_POWER_SITE}){
 const object=new THREE.Group();object.name='Service_Yard_Power_Panel';object.position.set(site.x,groundHeight(site.x,site.z),site.z);
 const geometry=new THREE.BoxGeometry(1,1,1),steel=new THREE.MeshStandardMaterial({color:0x586967,roughness:.63,metalness:.6}),dark=new THREE.MeshStandardMaterial({color:0x232927,roughness:.75}),warning=new THREE.MeshStandardMaterial({color:0xe6b343,roughness:.65}),bulb=new THREE.MeshStandardMaterial({color:0xe6dfb9,emissive:0xffdb8f,emissiveIntensity:1.5,roughness:.35});
 const mesh=(name,size,position,material,parent=object)=>{const m=new THREE.Mesh(geometry,material);m.name=name;m.scale.set(...size);m.position.set(...position);m.castShadow=m.receiveShadow=true;parent.add(m);return m;};
 mesh('Panel_Post',[.12,1.1,.12],[0,.55,0],dark);mesh('Steel_Fuse_Box',[.66,.87,.28],[0,1.33,0],steel);mesh('Recessed_Switch_Plate',[.53,.66,.025],[0,1.33,-.153],dark);
 mesh('Warning_Plate',[.14,.12,.012],[.17,1.52,-.173],warning);
 const lever=new THREE.Group();lever.name='Main_Isolation_Lever';lever.position.set(-.11,1.35,-.19);object.add(lever);mesh('Insulated_Lever',[.075,.23,.075],[0,.085,0],warning,lever);
 const lamps=[],lights=[];for(const x of[-4.15,0]){mesh('Yard_Lamp_Bracket',[.1,.15,.46],[x,2.05,4.8],steel);const lamp=mesh('Yard_Work_Lamp',[.32,.08,.22],[x,1.97,4.95],bulb);lamp.castShadow=false;lamps.push(lamp);const light=new THREE.PointLight(0xffe4b5,2.2,7,2);light.position.set(x,1.88,4.95);light.castShadow=false;object.add(light);lights.push(light);}
 let disposed=false,isPowered=powered!==false,pending=null,nearby=true;
 const approach=new THREE.Vector3(),contact=new THREE.Vector3(),normal=new THREE.Vector3(),meta={id:site.id,kind:'power_panel',workRange:.08,label:'Щиток освещения клетки',highlightBounds:{min:[-.37,.86,-.24],max:[.37,1.8,.18]},powered:isPowered,disablePower,getApproachPosition(){object.updateWorldMatrix(true,false);return object.localToWorld(approach.set(0,0,-1.02));},getWorkPoint(){return object.localToWorld(contact.set(-.11,1.4,-.22));},getWorkNormal(){return normal.set(0,0,-1).transformDirection(object.matrixWorld);}};object.userData.mercenaryTarget=meta;
 function visual(){meta.powered=isPowered;object.userData.powered=isPowered;lever.rotation.x=isPowered?-.6:.8;bulb.emissiveIntensity=isPowered?1.5:0;for(const light of lights)light.visible=isPowered&&nearby;}
 function updateVisibility(focus,maxDistance=60){if(disposed)return false;const distance=Number.isFinite(maxDistance)?Math.max(0,maxDistance):60;nearby=Number.isFinite(focus?.x)&&Number.isFinite(focus?.z)&&(focus.x-object.position.x)**2+(focus.z-object.position.z)**2<=distance*distance;for(const light of lights)light.visible=isPowered&&nearby;return isPowered&&nearby;}
 function confirm(receipt){if(disposed)return {ok:false,reason:'disposed'};if(receipt!==true&&receipt?.ok!==true)return {ok:false,reason:receipt?.reason||'power_change_rejected'};isPowered=false;visual();try{persistPower(site.id,false);}catch{}return {ok:true,powered:false,targetId:site.id};}
 function disablePower(context={}){
  if(disposed)return {ok:false,reason:'disposed'};if(!isPowered)return {ok:true,alreadyOff:true,powered:false};if(pending)return pending;
  if(typeof onPowerChange!=='function')return {ok:false,reason:'power_not_connected'};
  try{const receipt=onPowerChange({id:site.id,powered:false,context});if(receipt?.then){pending=Promise.resolve(receipt).then(confirm,()=>({ok:false,reason:'power_change_rejected'})).finally(()=>{pending=null;});return pending;}return confirm(receipt);}catch{return {ok:false,reason:'power_change_rejected'};}
 }
 visual();const y=object.position.y,colliders=[{id:site.id,mercenaryPowerPanel:true,polygonCR:[[-.36,-.18],[.36,-.18],[.36,.18],[-.36,.18]].map(([x,z])=>[(site.x+x)/4.1,(site.z+z)/4.1]),minYM:y,maxYM:y+1.8}];
 return {object,colliders,disablePower,updateVisibility,getTargets:()=>disposed?[]:[{id:site.id,kind:'power_panel',object}],getState:()=>({powered:isPowered,pending:!!pending,disposed,lightsVisible:isPowered&&nearby&&!disposed}),dispose(){if(disposed)return;disposed=true;object.removeFromParent();for(const light of lights)light.dispose();geometry.dispose();for(const material of[steel,dark,warning,bulb])material.dispose();}};
}
