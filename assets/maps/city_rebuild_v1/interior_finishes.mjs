const finishCaches=new WeakMap(),finishRecords=new Set();let finishCacheHits=0,finishCacheMisses=0;

// World-metre patterns remain the same size on scaled walls and instanced slabs.
export function createInteriorFinish(T,{color='#c9bbab',finish='plaster',floor=false}={}){
 const material=new T.MeshStandardMaterial({color,roughness:finish==='tile'?.48:.82,side:T.DoubleSide});
 material.name='InteriorFinish_'+finish;
 const styles={brick:1,wood:2,wallpaper:3,concrete:4,tile:5,plaster:0,stone:5,parquet:2,panels:2};
 const mode=styles[finish]??0;
 material.onBeforeCompile=shader=>{
  shader.vertexShader='varying vec3 vInteriorMetric;\n'+shader.vertexShader;
  shader.vertexShader=shader.vertexShader.replace('#include <project_vertex>',`#include <project_vertex>
   vec4 interiorMetric=vec4(transformed,1.0);
   #ifdef USE_INSTANCING
    interiorMetric=instanceMatrix*interiorMetric;
   #endif
   vInteriorMetric=(modelMatrix*interiorMetric).xyz;`);
  shader.fragmentShader='varying vec3 vInteriorMetric;\n'+shader.fragmentShader;
  shader.fragmentShader=shader.fragmentShader.replace('#include <color_fragment>',`#include <color_fragment>
   vec3 interiorNormal=abs(cross(dFdx(vInteriorMetric),dFdy(vInteriorMetric)));
   vec2 ip=${floor?'vInteriorMetric.xz':'interiorNormal.x>interiorNormal.z?vInteriorMetric.zy:vInteriorMetric.xy'};
   float surfaceTone=1.0;
   ${mode===1?`vec2 brick=ip/vec2(.42,.20);brick.x+=mod(floor(brick.y),2.0)*.5;vec2 joint=abs(fract(brick)-.5);float mortar=smoothstep(.455,.48,max(joint.x,joint.y));surfaceTone=mix(.89+sin(floor(brick.x)*3.1+floor(brick.y)*7.3)*.045,1.16,mortar);`:''}
   ${mode===2?`vec2 board=ip/vec2(.20,1.8);float seam=smoothstep(.475,.499,abs(fract(board.x)-.5));surfaceTone=.94+.035*sin(ip.y*14.0+sin(ip.x*31.0)*1.4)-.14*seam;`:''}
   ${mode===3?`vec2 motif=fract(ip/vec2(.32,.42))-.5;float diamond=abs(motif.x)+abs(motif.y);float ornament=1.0-smoothstep(.015,.045,abs(diamond-.28));float dotMark=1.0-smoothstep(.025,.07,length(motif));surfaceTone=1.0-.14*ornament-.1*dotMark;`:''}
   ${mode===4?`surfaceTone=.97+.025*sin(ip.x*3.2+sin(ip.y*5.0))+.013*sin(ip.y*32.0+ip.x*27.0);`:''}
   ${mode===5?`vec2 joint=abs(fract(ip/.55)-.5);surfaceTone=mix(1.0,.78,smoothstep(.477,.499,max(joint.x,joint.y)));`:''}
   ${floor?'':'if(interiorNormal.y>max(interiorNormal.x,interiorNormal.z))surfaceTone=1.0;'}
   diffuseColor.rgb*=surfaceTone;`);
 };
 material.customProgramCacheKey=()=>`interior-finish-v1-${mode}-${floor}`;
 return material;
}

// Interior finishes are immutable after construction.  Reusing a material for
// equal palettes avoids compiling and retaining one identical shader material
// per placed building, while each caller still owns one release handle.
export function acquireInteriorFinish(T,options={}){
 const {color='#c9bbab',finish='plaster',floor=false}=options,key=[new T.Color(color).getHexString(),finish,!!floor].join('|');
 let cache=finishCaches.get(T);if(!cache)finishCaches.set(T,cache=new Map());
 let record=cache.get(key);
 if(record){record.refs++;finishCacheHits++;}
 else {record={cache,key,material:createInteriorFinish(T,{color,finish,floor}),refs:1};cache.set(key,record);finishRecords.add(record);finishCacheMisses++;}
 let released=false;
 return {material:record.material,dispose(){if(released)return;released=true;if(--record.refs)return;record.cache.delete(record.key);record.material.dispose();finishRecords.delete(record);}};
}

export function interiorFinishCacheStats(){return{entries:finishRecords.size,refs:[...finishRecords].reduce((sum,record)=>sum+record.refs,0),hits:finishCacheHits,misses:finishCacheMisses};}
