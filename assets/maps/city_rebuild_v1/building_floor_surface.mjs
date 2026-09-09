// Immutable, local-space heightfield of actual upward-facing authored triangles.
// No scene traversal/raycast or matrix inversion occurs during walking queries.
export function createTriangleFloorSampler(THREE,mesh,toReference){
 const p=mesh.geometry.attributes.position,ix=mesh.geometry.index,count=ix?.count??p.count,triangles=[];
 for(let i=0;i<count;i+=3){
  const [a,b,c]=[0,1,2].map(j=>new THREE.Vector3().fromBufferAttribute(p,ix?ix.getX(i+j):i+j).applyMatrix4(toReference));
  const normal=new THREE.Vector3().subVectors(b,a).cross(new THREE.Vector3().subVectors(c,a));
  if(normal.y<=1e-9)continue;const denominator=(b.z-c.z)*(a.x-c.x)+(c.x-b.x)*(a.z-c.z);if(Math.abs(denominator)<1e-10)continue;
  triangles.push({a,b,c,denominator,minX:Math.min(a.x,b.x,c.x),maxX:Math.max(a.x,b.x,c.x),minZ:Math.min(a.z,b.z,c.z),maxZ:Math.max(a.z,b.z,c.z)});
 }
 return (x,z)=>{let height=null;for(const t of triangles){if(x<t.minX-1e-6||x>t.maxX+1e-6||z<t.minZ-1e-6||z>t.maxZ+1e-6)continue;
  const u=((t.b.z-t.c.z)*(x-t.c.x)+(t.c.x-t.b.x)*(z-t.c.z))/t.denominator,v=((t.c.z-t.a.z)*(x-t.c.x)+(t.a.x-t.c.x)*(z-t.c.z))/t.denominator,w=1-u-v;
  if(u>=-1e-6&&v>=-1e-6&&w>=-1e-6){const y=u*t.a.y+v*t.b.y+w*t.c.y;height=height===null?y:Math.max(height,y)}
 }return height};
}
