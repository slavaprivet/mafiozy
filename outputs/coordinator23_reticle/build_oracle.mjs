import fs from 'node:fs';import {createWeaponFireState,stepWeaponFire,FIREARM_IDS} from '../../assets/maps/city_rebuild_v1/hero_weapon_fire.mjs';import {createWeaponCrosshair} from '../../assets/maps/city_rebuild_v1/weapon_crosshair.mjs';
const rows=[];
for(const id of FIREARM_IDS)for(const posture of ['stand','crouch','prone'])for(const mode of ['idle','aim_move','hip_run'])for(const view of [{height:720,fov:42},{height:1080,fov:38}]){
 const state=stepWeaponFire(createWeaponFireState(id),{triggerHeld:true},.5).state,input={posture,aiming:mode==='aim_move',moving:mode!=='idle',running:mode==='hip_run'};
 const host={style:{},dataset:{},children:[],append(...n){this.children.push(...n)},replaceChildren(...n){this.children=[...n]}},document={createElement:()=>({style:{}})};const cross=createWeaponCrosshair({host,document}),sample=cross.update(state,input,view);
 const rects=host.children.slice(1).map(x=>[parseFloat(x.style.left),parseFloat(x.style.top),parseFloat(x.style.width),parseFloat(x.style.height)]);rows.push({id,state,input,view,gap:sample.gap,spread:sample.spread,rounded_gap:Math.round(sample.gap),rects});cross.dispose();
}
fs.writeFileSync('outputs/coordinator23_reticle/ORACLE.json',JSON.stringify({source:'Original createWeaponCrosshair/weaponCrosshairGap/sampleWeaponAccuracy, actual DOM-style geometry writes captured',rows},null,2));console.log('RETICLE_ORACLE',rows.length);
