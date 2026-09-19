import {createTriangleFloorSampler} from './building_floor_surface.mjs';

// The hospital's authored public pavement stands on a 0.52 m plinth. Its
// entrance ramp previously started at street height *inside* that plinth, while
// the remaining front strip still had its full collision. Retain those bodies;
// join the real surfaces and expose their exact triangle heights to walking.
export function applyHospitalPublicApproach({THREE:T,entry,visual,instance}){
 if(instance?.assetId!=='hospital'||!entry||entry.hospitalPublicApproach)return entry?.hospitalPublicApproach??null;
 const pad=visual.getObjectByName('PAD_HOSPITAL_EXTERIOR_01'),path=visual.getObjectByName('ROUTE_HOSPITAL_PUBLIC'),ramp=entry.object.getObjectByName('Entry_Continuous_Ramp');
 if(!pad?.geometry?.attributes.position||!path?.geometry?.attributes.position||!ramp?.geometry?.attributes.position)return null;
 visual.updateWorldMatrix(true,true);const frame=entry.object,inverse=frame.matrixWorld.clone().invert(),scale=frame.getWorldScale(new T.Vector3()),origin=frame.getWorldPosition(new T.Vector3());
 const worldBox=node=>new T.Box3().setFromBufferAttribute(node.geometry.attributes.position).applyMatrix4(node.matrixWorld),padWorld=worldBox(pad),pathWorld=worldBox(path),rampLocal=new T.Box3().setFromBufferAttribute(ramp.geometry.attributes.position),pathLocal=new T.Box3().setFromBufferAttribute(path.geometry.attributes.position).applyMatrix4(new T.Matrix4().multiplyMatrices(inverse,path.matrixWorld));
 const halfWidth=Math.min(Math.abs(rampLocal.min.x),Math.abs(rampLocal.max.x)),front=pathLocal.max.z,streetY=padWorld.min.y,apronY=pathWorld.max.y,doorY=origin.y;
 if(![front,streetY,apronY,doorY,halfWidth].every(Number.isFinite)||front<=0||apronY<=streetY||doorY<=apronY||halfWidth<=.4)return null;
 // A 1:8 outer ramp starts on the existing dry public approach. The inner
 // segment rises gently from the actual pavement to the unchanged threshold.
 // Across a 0.36 m capsule radius its rise is below the 0.05 m floor-contact
 // tolerance, so the unchanged pavement body cannot catch the leading edge.
 const toe=front+(apronY-streetY)*8/scale.z,levels=[[0,0],[front,(apronY-doorY)/scale.y],[toe,(streetY-doorY)/scale.y]],positions=[];
 for(let i=1;i<levels.length;i++){const [z0,y0]=levels[i-1],[z1,y1]=levels[i];positions.push(-halfWidth,y0,z0,halfWidth,y1,z1,halfWidth,y0,z0,-halfWidth,y0,z0,-halfWidth,y1,z1,halfWidth,y1,z1);}
 const geometry=new T.BufferGeometry();geometry.setAttribute('position',new T.Float32BufferAttribute(positions,3));geometry.computeVertexNormals();geometry.computeBoundingBox();geometry.computeBoundingSphere();const oldGeometry=ramp.geometry;ramp.geometry=geometry;
 const publicBounds=pathWorld.clone(),floorSources=[pad,path].map(node=>({name:node.name,bounds:worldBox(node),sample:createTriangleFloorSampler(T,node,node.matrixWorld)})),rampBounds=worldBox(ramp),rampSample=createTriangleFloorSampler(T,ramp,ramp.matrixWorld),bounds=publicBounds.clone().union(rampBounds);
 const originalFloor=entry.floorHeight.bind(entry),originalDispose=entry.dispose.bind(entry),previousBounds=entry.sampleBounds;entry.sampleBounds=(previousBounds?.clone()??bounds.clone()).union(bounds);
 const inside=(b,x,z)=>x>=b.min.x-1e-6&&x<=b.max.x+1e-6&&z>=b.min.z-1e-6&&z<=b.max.z+1e-6;
 function sample(x,z){if(!inside(bounds,x,z))return null;let y=inside(rampBounds,x,z)?rampSample(x,z):null;if(inside(publicBounds,x,z))for(const source of floorSources){if(!inside(source.bounds,x,z))continue;const height=source.sample(x,z);if(height!==null)y=y===null?height:Math.max(y,height);}return y;}
 entry.floorHeight=(x,z,referenceY=0)=>{const existing=originalFloor(x,z,referenceY),support=sample(x,z);return support===null?existing:existing===null?support:Math.max(existing,support);};
 const point=(z,y)=>frame.localToWorld(new T.Vector3(0,y,z)),report={sourceNodes:floorSources.map(s=>s.name),collisionBodiesPreserved:true,streetY,apronY,doorY,outerSlope:1/8,addedDraws:0,trianglesBefore:(oldGeometry.index?.count??oldGeometry.attributes.position.count)/3,trianglesAfter:positions.length/9,route:[point(toe,levels[2][1]).toArray(),point(front,levels[1][1]).toArray(),point(0,0).toArray()],bounds:{min:bounds.min.toArray(),max:bounds.max.toArray()}};
 let disposed=false,entryDisposed=false;const api={report,sample,geometry,originalFloor,dispose(){if(disposed)return;disposed=true;ramp.geometry=oldGeometry;geometry.dispose();entry.sampleBounds=previousBounds;entry.floorHeight=originalFloor;delete entry.hospitalPublicApproach;delete entry.report.hospitalPublicApproach;}};
 entry.hospitalPublicApproach=api;entry.report.hospitalPublicApproach=report;entry.dispose=()=>{if(entryDisposed)return;entryDisposed=true;api.dispose();originalDispose();};return api;
}
