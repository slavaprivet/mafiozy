// The police envelope reserves placement space; its paved outdoor paths are
// not solid walls. Actual building/door colliders remain a separate narrowphase.
// Keep source masks intact for placement, vehicles and the authoritative world.
export function nativePedestrianLand(topology,row,column){
 if(!Number.isFinite(row)||!Number.isFinite(column))return false;
 const r=Math.floor(row),c=Math.floor(column),tile=topology?.grid?.[r]?.[c];
 if(tile===undefined)return false;
 return !!topology.walkableMask?.[r]?.[c]||(tile===9&&topology.policeMask?.[r]?.[c]===1);
}
