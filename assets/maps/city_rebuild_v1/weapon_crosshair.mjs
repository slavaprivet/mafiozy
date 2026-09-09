import {sampleWeaponAccuracy} from './hero_weapon_fire.mjs';

export function weaponCrosshairGap(state,input,{height=720,fov=60}={}){
 const sample=sampleWeaponAccuracy(state,input),pixels=Math.tan(sample.spread)*height/(2*Math.tan(fov*Math.PI/360));
 return {gap:Math.max(3,Math.min(64,3+pixels)),...sample};
}

export function createWeaponCrosshair({host,document:doc=globalThis.document}){
 const dot=doc.createElement('i'),arms=[];host.replaceChildren();host.style.width='0';host.style.height='0';
 dot.style.cssText='position:absolute;left:-1px;top:-1px;width:2px;height:2px;background:#fff;box-shadow:0 0 2px 1px #111';host.append(dot);
 for(let i=0;i<4;i++){const arm=doc.createElement('i');arm.style.cssText='position:absolute;background:#f7f4e8;border-radius:1px;box-shadow:0 0 2px 1px #111';host.append(arm);arms.push(arm)}
 let lastGap=-1,lastSpread='';
 return {update(state,input,view){const sample=weaponCrosshairGap(state,input,view),gap=Math.round(sample.gap);if(gap!==lastGap){lastGap=gap;for(let i=0;i<4;i++){const horizontal=i<2;arms[i].style.width=horizontal?'6px':'2px';arms[i].style.height=horizontal?'2px':'6px';arms[i].style.left=horizontal?(i===0?-gap-6:gap)+'px':'-1px';arms[i].style.top=horizontal?'-1px':(i===2?-gap-6:gap)+'px'}}const spread=sample.spread.toFixed(5);if(spread!==lastSpread){lastSpread=spread;host.dataset.spread=spread}return sample;},dispose(){host.replaceChildren()}};
}
