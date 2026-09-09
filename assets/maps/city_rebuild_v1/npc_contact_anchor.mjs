// A local rendering anchor only. No skin coordinates are damage authority or
// sent over the network: an accepted source receipt is still required.
const finiteVector=v=>v&&Number.isFinite(v.x)&&Number.isFinite(v.y)&&Number.isFinite(v.z);
const visible=node=>{for(let n=node;n;n=n.parent)if(!n.visible)return false;return true;};
function pathTo(root,node){
 const path=[];
 for(let current=node;current!==root;current=current.parent){
  const parent=current?.parent;if(!parent)return null;
  let ordinal=0,found=false;
  for(const peer of parent.children){if(peer.name!==current.name||peer.type!==current.type)continue;if(peer===current){found=true;break}ordinal++;}
  if(!found)return null;
  path.unshift({name:current.name,type:current.type,ordinal});
 }
 return path;
}
function atPath(root,path){
 let node=root;
 for(const part of path){if(!node)return null;let ordinal=0,next=null;for(const child of node.children){if(child.name!==part.name||child.type!==part.type)continue;if(ordinal++===part.ordinal){next=child;break}}node=next;if(!node)return null;}
 return node;
}
function triangle(THREE,mesh,indices){
 const count=mesh.geometry?.attributes.position?.count;
 if(!count||!indices.every(i=>Number.isInteger(i)&&i>=0&&i<count))return null;
 mesh.updateMatrixWorld(true);mesh.skeleton?.update();
 const vertices=indices.map(i=>mesh.getVertexPosition(i,new THREE.Vector3()).applyMatrix4(mesh.matrixWorld));
 return vertices.every(finiteVector)?vertices:null;
}
export function captureNpcContactAnchor({THREE,record,mesh,face,point,normal}){
 if(!record?.object||!mesh?.isSkinnedMesh||!face||!finiteVector(point)||!finiteVector(normal))return null;
 const path=pathTo(record.object,mesh);if(!path)return null;
 const indices=[face.a,face.b,face.c],vertices=triangle(THREE,mesh,indices);if(!vertices)return null;
 const [a,b,c]=vertices,weights=THREE.Triangle.getBarycoord(point,a,b,c,new THREE.Vector3());
 if(!finiteVector(weights)||[weights.x,weights.y,weights.z].some(w=>w<-.0001||w>1.0001))return null;
 const faceNormal=b.clone().sub(a).cross(c.clone().sub(a));if(faceNormal.lengthSq()<1e-18)return null;
 return {version:1,npcId:String(record.id),actorUuid:record.object.uuid,meshPath:path,meshUuid:mesh.uuid,geometryUuid:mesh.geometry.uuid,
  vertexCount:mesh.geometry.attributes.position.count,indexCount:mesh.geometry.index?.count??0,indices,
  weights:[weights.x,weights.y,weights.z],normalSide:faceNormal.dot(normal)<0?-1:1};
}
export function resolveNpcContactAnchor({THREE,record,anchor}){
 if(anchor?.version!==1||!record?.object||String(record.id)!==anchor.npcId||record.object.uuid!==anchor.actorUuid||!visible(record.object))return null;
 if(!Array.isArray(anchor.meshPath)||!Array.isArray(anchor.indices)||anchor.indices.length!==3||!Array.isArray(anchor.weights)||anchor.weights.length!==3||!anchor.weights.every(Number.isFinite))return null;
 if(anchor.weights.some(w=>w<-.0001||w>1.0001)||Math.abs(anchor.weights.reduce((sum,w)=>sum+w,0)-1)>.0001||![1,-1].includes(anchor.normalSide))return null;
 const mesh=atPath(record.object,anchor.meshPath);
 if(!mesh?.isSkinnedMesh||!visible(mesh)||mesh.uuid!==anchor.meshUuid||mesh.geometry?.uuid!==anchor.geometryUuid||mesh.geometry.attributes.position?.count!==anchor.vertexCount||(mesh.geometry.index?.count??0)!==anchor.indexCount)return null;
 // updateMatrixWorld (not only updateWorldMatrix) refreshes the SkinnedMesh
 // bind inverse after a root move, exactly as the actual contact ray does.
 record.object.updateWorldMatrix(true,false);record.object.updateMatrixWorld(true);
 const vertices=triangle(THREE,mesh,anchor.indices);if(!vertices)return null;
 const [a,b,c]=vertices,point=new THREE.Vector3();vertices.forEach((v,i)=>point.addScaledVector(v,anchor.weights[i]));
 const normal=b.clone().sub(a).cross(c.clone().sub(a));if(normal.lengthSq()<1e-18)return null;
 normal.normalize().multiplyScalar(anchor.normalSide===-1?-1:1);
 if(!finiteVector(point)||!finiteVector(normal))return null;
 return {point:{x:point.x,y:point.y,z:point.z},normal:{x:normal.x,y:normal.y,z:normal.z}};
}
