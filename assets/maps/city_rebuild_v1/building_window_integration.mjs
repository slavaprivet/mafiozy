import {applyResidentialWindows} from './residential_windows.mjs';
import {createBuildingEntry,subtractBoxFromGeometry} from './building_entry.mjs';
import {applyBuildingSizeTransform,describeWorldRoom} from './building_size_policy.mjs';

// Discover all authored panes before room CSG removes their old opaque backing.
// Instanced recesses are excluded from ordinary-mesh entry clipping, then only
// the new inner room walls receive matching recess volumes.
export function createWindowedBuildingEntry({THREE:T,visual,instance,metresPerCell=4.1}){
 applyBuildingSizeTransform(visual,instance,T);
 const windows=applyResidentialWindows({THREE:T,visual,instance}),originalVisibility=windows?.group.visible;let entry;
 try{if(windows)windows.group.visible=false;entry=createBuildingEntry({THREE:T,visual,instance,metresPerCell})}catch(error){windows?.dispose();throw error}finally{if(windows)windows.group.visible=originalVisibility}
 const originals=[],owned=[];
 if(windows&&entry){
  visual.updateWorldMatrix(true,true);const inverse=visual.matrixWorld.clone().invert();
  entry.object.traverse(node=>{
   if(!node.isMesh||!/^Entry_(Interior_(Left|Right|Rear|Front|Header)|Corridor_Wall)$/.test(node.name))return;
   const transform=new T.Matrix4().multiplyMatrices(inverse,node.matrixWorld),bounds=new T.Box3().setFromBufferAttribute(node.geometry.attributes.position).applyMatrix4(transform),cuts=windows.panes.filter(p=>bounds.intersectsBox(p.cut));if(!cuts.length)return;
   let geometry=node.geometry;for(const pane of cuts){const next=subtractBoxFromGeometry(T,geometry,transform,pane.cut);if(geometry!==node.geometry)geometry.dispose();geometry=next}originals.push([node,node.geometry]);owned.push(geometry);node.geometry=geometry;
  });
 }
 let disposed=false;const roomReveals={dispose(){if(disposed)return;disposed=true;for(const[n,g]of originals)n.geometry=g;for(const g of owned)g.dispose()}};
 describeWorldRoom(entry);
 return {windows,entry,roomReveals};
}
