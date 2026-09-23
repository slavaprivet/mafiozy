// BatchedMesh aggregate bounds are not refreshed by setMatrixAt(). Owners
// stamp the exact buffers only after recomputing bounds; later mutations make
// shadow rejection fail open until the owner recomputes and stamps again.
const INVALIDATING_MUTATORS=['addInstance','addGeometry','setGeometryAt','deleteGeometry','deleteInstance','optimize','setMatrixAt','setGeometryIdAt','setInstanceCount','setGeometrySize','copy'];
const guarded=new WeakSet();

function installMutationGuard(batch){
 if(guarded.has(batch))return;
 for(const name of INVALIDATING_MUTATORS){
  const original=batch[name];if(typeof original!=='function')continue;
  batch[name]=function(...args){delete this.userData.shadowCullBoundsStamp;try{return original.apply(this,args)}finally{delete this.userData.shadowCullBoundsStamp}};
 }
 guarded.add(batch);
}

export function stampBatchedShadowBounds(batch){
 if(!batch?.isBatchedMesh)return batch;
 installMutationGuard(batch);
 const position=batch.geometry?.attributes?.position,index=batch.geometry?.index,matrices=batch._matricesTexture;
 batch.userData.shadowCullBoundsStamp={matrices,matricesVersion:matrices?.version,position,positionVersion:position?.version,positionArray:position?.array,positionCount:position?.count,index,indexVersion:index?.version,indexArray:index?.array,indexCount:index?.count,geometryCount:batch._geometryCount};
 return batch;
}

export function batchedShadowBoundsCurrent(batch){
 const stamp=batch?.userData?.shadowCullBoundsStamp,position=batch?.geometry?.attributes?.position,index=batch?.geometry?.index,matrices=batch?._matricesTexture;
 return !!stamp&&stamp.matrices===matrices&&stamp.matricesVersion===matrices?.version&&stamp.position===position&&stamp.positionVersion===position?.version&&stamp.positionArray===position?.array&&stamp.positionCount===position?.count&&stamp.index===index&&stamp.indexVersion===index?.version&&stamp.indexArray===index?.array&&stamp.indexCount===index?.count&&stamp.geometryCount===batch?._geometryCount;
}
