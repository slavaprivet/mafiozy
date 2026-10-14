const captures=new WeakSet();

const finite=value=>Number.isFinite(value)?value:null;
const vector=value=>value&&[value.x,value.y,value.z].every(Number.isFinite)?[value.x,value.y,value.z]:null;
const quaternion=value=>value&&[value.x,value.y,value.z,value.w].every(Number.isFinite)?[value.x,value.y,value.z,value.w]:null;
const color=value=>value&&typeof value.getHex==='function'?value.getHex():value&&Number.isFinite(value.r)&&Number.isFinite(value.g)&&Number.isFinite(value.b)?[value.r,value.g,value.b]:null;
const texture=map=>map?Object.freeze({ref:map,name:String(map.name||''),colorSpace:String(map.colorSpace||''),channel:finite(map.channel),flipY:map.flipY!==false,wrapS:finite(map.wrapS),wrapT:finite(map.wrapT),magFilter:finite(map.magFilter),minFilter:finite(map.minFilter),anisotropy:finite(map.anisotropy)}):null;
const geometry=value=>value?Object.freeze({ref:value,indexCount:value.index?.count??null,drawRange:[value.drawRange?.start??0,value.drawRange?.count??Infinity],groups:(value.groups||[]).map(group=>[group.start,group.count,group.materialIndex]),attributes:Object.fromEntries(Object.entries(value.attributes||{}).sort(([a],[b])=>a.localeCompare(b)).map(([name,attribute])=>[name,[attribute.count,attribute.itemSize,attribute.normalized===true,attribute.usage??null]]))}):null;
function material(value){if(!value)return null;return Object.freeze({ref:value,type:String(value.type||''),name:String(value.name||''),side:finite(value.side),transparent:value.transparent===true,opacity:finite(value.opacity),alphaTest:finite(value.alphaTest),depthTest:value.depthTest!==false,depthWrite:value.depthWrite!==false,blending:finite(value.blending),vertexColors:value.vertexColors===true,toneMapped:value.toneMapped!==false,color:color(value.color),emissive:color(value.emissive),roughness:finite(value.roughness),metalness:finite(value.metalness),map:texture(value.map),normalMap:texture(value.normalMap),roughnessMap:texture(value.roughnessMap),metalnessMap:texture(value.metalnessMap),emissiveMap:texture(value.emissiveMap),alphaMap:texture(value.alphaMap)});}
const transform=node=>Object.freeze({position:vector(node.position),quaternion:quaternion(node.quaternion),rotation:node.rotation&&[node.rotation.x,node.rotation.y,node.rotation.z].every(Number.isFinite)?[node.rotation.x,node.rotation.y,node.rotation.z]:null,scale:vector(node.scale)});
const same=(a,b)=>JSON.stringify(a)===JSON.stringify(b);
const withoutRefs=value=>value===null?null:Object.fromEntries(Object.entries(value).filter(([key])=>key!=='ref').map(([key,item])=>[key,item&&typeof item==='object'&&!Array.isArray(item)&&'ref'in item?withoutRefs(item):item]));

function visit(node,path,rootIndex,records){
 const materials=Array.isArray(node.material)?node.material.map(material):node.material?[material(node.material)]:[];
 records.push(Object.freeze({path,rootIndex,node,visible:node.visible!==false,layers:node.layers?.mask??null,castShadow:node.castShadow===true,receiveShadow:node.receiveShadow===true,renderOrder:finite(node.renderOrder),frustumCulled:node.frustumCulled!==false,matrixAutoUpdate:node.matrixAutoUpdate!==false,transform:transform(node),geometry:geometry(node.geometry),materials:Object.freeze(materials)}));
 for(let index=0;index<(node.children?.length||0);index++)visit(node.children[index],`${path}/${index}`,rootIndex,records);
}

/** Explicit QA snapshot. Call only at editor transition/acceptance boundaries. */
export function captureWalkMapEditorVisualParity(roots,{label='visual-parity'}={}){
 if(!Array.isArray(roots)||roots.some(root=>!root||typeof root!=='object'))throw new Error('Visual parity capture requires object roots');
 const records=[];for(let index=0;index<roots.length;index++)visit(roots[index],String(index),index,records);
 const result=Object.freeze({label:String(label),rootCount:roots.length,records:Object.freeze(records)});captures.add(result);return result;
}

export function compareWalkMapEditorVisualParity(before,roots,{allowRootTransform=false,allowRootVisibility=false,allowRootIndices=[],allowResourceReplacement=false}={}){
 if(!captures.has(before))throw new Error('Visual parity comparison requires a trusted capture');
 const after=captureWalkMapEditorVisualParity(roots,{label:`${before.label}:after`}),allowed=new Set(allowRootIndices),issues=[];
 if(after.rootCount!==before.rootCount)issues.push({code:'ROOT_COUNT_CHANGED',before:before.rootCount,after:after.rootCount});
 const current=new Map(after.records.map(record=>[record.path,record]));
 for(const expected of before.records){
  const actual=current.get(expected.path);if(!actual){issues.push({code:'NODE_REMOVED',path:expected.path});continue}current.delete(expected.path);
  const rootAllowed=allowed.has(expected.rootIndex),root=expected.path===String(expected.rootIndex);
  if(expected.node!==actual.node&&!allowResourceReplacement)issues.push({code:'NODE_REPLACED',path:expected.path});
  if((expected.geometry?.ref!==actual.geometry?.ref&&!allowResourceReplacement)||!same(withoutRefs(expected.geometry),withoutRefs(actual.geometry)))issues.push({code:'GEOMETRY_CHANGED',path:expected.path});
  if(expected.materials.length!==actual.materials.length)issues.push({code:'MATERIAL_COUNT_CHANGED',path:expected.path});
  else for(let index=0;index<expected.materials.length;index++)if((expected.materials[index]?.ref!==actual.materials[index]?.ref&&!allowResourceReplacement)||!same(withoutRefs(expected.materials[index]),withoutRefs(actual.materials[index])))issues.push({code:'MATERIAL_CHANGED',path:expected.path,index});
  for(const key of ['layers','castShadow','receiveShadow','renderOrder','frustumCulled','matrixAutoUpdate'])if(expected[key]!==actual[key])issues.push({code:`${key.toUpperCase()}_CHANGED`,path:expected.path});
  if(expected.visible!==actual.visible&&!(root&&rootAllowed&&allowRootVisibility))issues.push({code:'VISIBILITY_CHANGED',path:expected.path});
  if(!same(expected.transform,actual.transform)&&!(root&&rootAllowed&&allowRootTransform))issues.push({code:'TRANSFORM_CHANGED',path:expected.path});
 }
 for(const path of current.keys())issues.push({code:'NODE_ADDED',path});
 return Object.freeze({ok:issues.length===0,label:before.label,beforeNodes:before.records.length,afterNodes:after.records.length,issues:Object.freeze(issues.map(Object.freeze))});
}
