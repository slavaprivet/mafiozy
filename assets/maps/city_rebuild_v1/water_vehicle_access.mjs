// A single bounded connector across existing gentle terrain. Does not flatten
// ground or remove colliders. Deep water admission is separate from the dry
// connector: vehicle_water_state owns engine flooding and sinking after entry.
const start=Object.freeze({x:783.808767748649,z:394.79997314625217});
const shore=Object.freeze({x:822,z:406});
const dx=shore.x-start.x,dz=shore.z-start.z,length=Math.hypot(dx,dz);
const direction=Object.freeze({x:dx/length,z:dz/length});
export const WATER_VEHICLE_ACCESS=Object.freeze({
 id:'east-lake-shallow-access',start,shore,direction,
 end:Object.freeze({x:shore.x+direction.x*3,z:shore.z+direction.z*3}),
 width:8,halfWidth:4,maxSlope:.27,maxDepth:.45,length:length+3,
 yaw:Math.atan2(direction.x,direction.z)
});
export function waterVehicleAccessPoint(distance,lateral=0){
 return {x:start.x+direction.x*distance+direction.z*lateral,z:start.z+direction.z*distance-direction.x*lateral};
}
export function isWaterVehicleAccess(terrain,x,z){
 if(!Number.isFinite(x)||!Number.isFinite(z)||!terrain?.contains?.(x,z))return false;
 // Explicitly protect the native city even if a supplied contains implementation
 // includes it. Native road/water/police admission remains with the original world.
 if(x>=0&&x<738&&z>=0&&z<820)return false;
 const a=x-start.x,b=z-start.z,along=a*direction.x+b*direction.z,side=a*direction.z-b*direction.x;
 if(along<0||along>WATER_VEHICLE_ACCESS.length||Math.abs(side)>4)return false;
 const slope=terrain.slopeAt?.(x,z);
 if(!Number.isFinite(slope)||slope>.27)return false;
 const water=terrain.waterAt?.(x,z);
 return !water||(Number.isFinite(water.depth)&&water.depth>=0&&water.depth<=.45);
}

// Surface permission only. Static/dynamic colliders still run in createCarWorld.
// Do not impose a water-depth wall: a flooded engine, not an invisible shoreline
// barrier, removes propulsion. Protected native cells keep their old boundary.
export function waterVehicleSurfaceAt({terrain,topology,waterAt,metresPerCell=4.1},x,z){
 if(!Number.isFinite(x)||!Number.isFinite(z))return false;
 const r=Math.floor(z/metresPerCell),c=Math.floor(x/metresPerCell);
 if(topology?.policeMask?.[r]?.[c]||topology?.protectedMask?.[r]?.[c])return false;
 const water=waterAt?.(x,z);
 if(water&&Number.isFinite(water.level)&&Number.isFinite(water.floor)&&water.depth>0)return true;
 return terrain?.contains?.(x,z)?(terrain.canDrive(x,z)||isWaterVehicleAccess(terrain,x,z)):undefined;
}
