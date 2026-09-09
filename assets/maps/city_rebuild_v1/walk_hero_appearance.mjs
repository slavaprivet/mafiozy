import {createHeroWalker} from './hero_walk.mjs';
import {NPC_ASSETS} from './npc_actor.mjs';
import {sourceLookAppearance,WORLD_SKIN_PALETTE} from './npc_role_catalogue.mjs';
import {describeNpcAppearance,applyNpcAppearance,NPC_HAIRSTYLES} from './npc_appearance.mjs';
import {loadVerifiedGlbBytes} from './verified_glb_bytes.mjs';

const HAIR_M=['#1a0e00','#3d2200','#8b6333','#b8860b','#888888','#111111'];
const HAIR_F=['#1a0e00','#8b1a1a','#b8860b','#3d2200','#888888','#c87050','#e0c080'];
// Semantic 3D counterparts of world drawHairM/F IDs, not random NPC hairstyles.
const STYLE_M=['bald','slick','wavy','undercut','crop','bob','curly','part','part','crew'];
const STYLE_F=['bald','ponytail','bob','wavy','curly','braids','bun','wavy','part','crop'];
const SUITS_M=['#1a1a2e','#1a2e1a','#2e1a1a','#1a1e2e'];
const SUITS_F=['#3a1a3a','#1a2a3a','#3a1a1a','#1a3a2a'];
const safeColor=(value,fallback)=>/^#[\da-f]{6}$/i.test(value||'')?value:/^#[\da-f]{3}$/i.test(value||'')?'#'+value.slice(1).split('').map(x=>x+x).join(''):fallback;
const index=(value,count,fallback=0)=>Number.isInteger(Number(value))&&Number(value)>=0?Number(value)%count:fallback;

export function playerAppearanceFromWorld(look={},id='player'){
 const sex=look.gender===1||look.gender==='1'||look.gender==='female'||look.sex==='female'?'female':'male',female=sex==='female',body=index(look.body,4,1),hair=index(look.hair,10),face=index(look.face,10),skin=index(look.skin,WORLD_SKIN_PALETTE.length);
 const source=sourceLookAppearance({...look,gender:female?1:0,skin,body});
 const outfit=safeColor(look.suit||look.outfitColor||look.outfit,(female?SUITS_F:SUITS_M)[body]);
 return describeNpcAppearance(String(id),{...source,sex,role:'player',height:1.9,build:[.94,1,1.04,1.07][body],skin:safeColor(look.skinColor,source.skin),outfit,
  shirt:safeColor(look.shirt||look.shirtColor,'#dddddd'),trousers:safeColor(look.trousers,outfit),
  hairColor:safeColor(look.hairColor,(female?HAIR_F:HAIR_M)[hair%(female?HAIR_F:HAIR_M).length]),
  hairstyle:NPC_HAIRSTYLES.includes(look.hairstyle)?look.hairstyle:(female?STYLE_F:STYLE_M)[hair],browStyle:face%8,
  hat:['none','fedora','police'][Number(look.hat)]||'none',accent:safeColor(look.accent,(female?['#e8c96e','#c0392b','#8e44ad','#2980b9']:['#c0392b','#e8c96e','#8e44ad','#2980b9'])[face%4]),
  sourceLook:{...look},sourceFace:face,sourceHat:Number(look.hat)||0,
 });
}

const collect=root=>{const result=new Set();root.traverse(o=>{if(o.geometry)result.add(o.geometry);for(const m of Array.isArray(o.material)?o.material:o.material?[o.material]:[]){result.add(m);for(const value of Object.values(m))if(value?.isTexture)result.add(value)}});return result};

// A fresh parsed GLB owns all resources. Never modify/recolor the currently live rig.
// Host swaps only after this resolves and preserves authoritative position/actions.
export async function loadAppearanceHero({THREE,loader,look={},id='player',appearance:providedAppearance,targetHeight=1.9,signal,fetch:fetcher=globalThis.fetch}={}){
 if(!THREE||!loader?.parseAsync||!fetcher)throw Error('THREE, GLTFLoader and fetch required');
 const appearance=providedAppearance||playerAppearanceFromWorld(look,id),asset=NPC_ASSETS[appearance.sex],bytes=await loadVerifiedGlbBytes({asset,fetch:fetcher,signal});
 const gltf=await loader.parseAsync(bytes,asset.url.slice(0,asset.url.lastIndexOf('/')+1)),source=gltf.scene,original=collect(source);let hero;
 try{
  applyNpcAppearance({THREE,scene:source,descriptor:appearance});hero=createHeroWalker({THREE,scene:source,targetHeight});
  const current=collect(source);for(const resource of original)if(!current.has(resource))resource.dispose();
  let disposed=false;
  return {hero,appearance,dispose(){if(disposed)return;disposed=true;hero.mountWeapon(null);const skeletons=new Set();source.traverse(o=>{if(o.skeleton)skeletons.add(o.skeleton)});hero.dispose();for(const skeleton of skeletons)skeleton.dispose?.()}};
 }catch(error){for(const resource of new Set([...original,...collect(source)]))resource.dispose();throw error}
}
