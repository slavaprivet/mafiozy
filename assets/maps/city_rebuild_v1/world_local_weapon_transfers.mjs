import {weaponArtId} from './world_weapon_transfers.mjs';

// Session-only drops for the loopback world showcase. Source world still owns
// selection, ammunition and availability; authenticated games never use this.
export function createLocalWorldWeaponTransfers({allowed,getPlayer,getWeapon,getAmmo,isAvailable,setAvailable,setWeapon,setMagazine,canPlace,changed=()=>{},now=()=>performance.now()}={}) {
  const drops=new Map();let sequence=0;
  const copy=d=>({...d,position:{...d.position},fireState:{...d.fireState}});
  function sweep(){const at=now();for(const [id,d] of drops)if(at>=d.expiresAt)drops.delete(id);}
  function player(){const p=getPlayer();return p&&[p.r,p.c,p.ang].every(Number.isFinite)?p:null;}
  return {
    getDrops(){if(!allowed())return [];sweep();return [...drops.values()].map(copy);},
    drop(){
      if(!allowed())return {ok:false,error:'unavailable'};
      sweep();const itemId=getWeapon(),weaponId=weaponArtId(itemId),p=player();
      if(!weaponId||!isAvailable(itemId))return {ok:false,error:'not_equipped_weapon'};
      if(!p||p.interior)return {ok:false,error:'unsupported_surface'};
      if(drops.size>=256)return {ok:false,error:'drop_limit'};
      let position;
      for(const distance of [.8,.55,.3,0]){
        const c=p.c+Math.cos(p.ang)*distance/4.1,r=p.r+Math.sin(p.ang)*distance/4.1;
        if([0,.25,.5,.75,1].every(t=>canPlace(p.r+(r-p.r)*t,p.c+(c-p.c)*t))){position={x:c*4.1,y:0,z:r*4.1};break;}
      }
      if(!position)return {ok:false,error:'blocked_surface'};
      const magazine=getAmmo(itemId);
      if(!Number.isInteger(magazine)||magazine<0)return {ok:false,error:'invalid_ammo'};
      const uid=`local-world-weapon-${++sequence}`,d={uid,itemId,weaponId,position,yaw:Math.PI/2-p.ang,expiresAt:now()+300000,fireState:{magazine,reserveAmmo:0}};
      setMagazine(itemId,0);setAvailable(itemId,false);setWeapon(null);drops.set(uid,d);changed();
      return {ok:true,action:'drop',drop:copy(d)};
    },
    pickup(uid){
      if(!allowed())return {ok:false,error:'unavailable'};
      sweep();const d=drops.get(uid),p=player();
      if(!d)return {ok:false,error:'drop_unavailable'};
      if(!p||p.interior)return {ok:false,error:'unsupported_surface'};
      if(Math.hypot(p.c*4.1-d.position.x,p.r*4.1-d.position.z)>1.6)return {ok:false,error:'out_of_reach'};
      if(![0,.25,.5,.75,1].every(t=>canPlace(p.r+(d.position.z/4.1-p.r)*t,p.c+(d.position.x/4.1-p.c)*t)))return {ok:false,error:'blocked_surface'};
      if(isAvailable(d.itemId))return {ok:false,error:'already_owned'};
      setMagazine(d.itemId,d.fireState.magazine);setAvailable(d.itemId,true);drops.delete(uid);changed();
      // Collecting never changes the currently held weapon or its reload.
      return {ok:true,action:'pickup',drop:copy(d)};
    }
  };
}
