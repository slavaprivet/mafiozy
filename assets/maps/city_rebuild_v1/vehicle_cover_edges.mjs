import {collisionPolygon} from './vehicle_collision_shape.mjs';
// A tyre bevel is not a firing corner. Cover follows four continuous sides of
// the closed body envelope; driving retains its detailed convex contact hull.
export function vehicleCoverPolygon(x,z,yaw,profile={}){
 const hull=profile.collisionHull;
 if(!Array.isArray(hull)||hull.length<3)return collisionPolygon(x,z,yaw,profile).map(([x,z])=>({x,z}));
 const xs=hull.map(p=>p[0]),zs=hull.map(p=>p[1]),minX=Math.min(...xs),maxX=Math.max(...xs),minZ=Math.min(...zs),maxZ=Math.max(...zs);
 return collisionPolygon(x,z,yaw,{...profile,collisionHull:[[minX,minZ],[maxX,minZ],[maxX,maxZ],[minX,maxZ]]}).map(([x,z])=>({x,z}));
}
