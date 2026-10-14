import assert from 'node:assert/strict';
import test from 'node:test';
import {captureWalkMapEditorVisualParity,compareWalkMapEditorVisualParity} from './walk_map_editor_visual_parity.mjs';

const vec=(x=0,y=0,z=0)=>({x,y,z}),quat=()=>({x:0,y:0,z:0,w:1});
function node({geometry=null,material=null,children=[]}={}){return {visible:true,layers:{mask:1},castShadow:true,receiveShadow:true,renderOrder:0,frustumCulled:true,matrixAutoUpdate:true,position:vec(),rotation:vec(),quaternion:quat(),scale:vec(1,1,1),geometry,material,children};}
const texture=()=>({name:'brick',colorSpace:'srgb',channel:0,flipY:true,wrapS:1000,wrapT:1000,magFilter:1006,minFilter:1008,anisotropy:4});
const material=()=>({type:'MeshStandardMaterial',name:'wall',side:0,transparent:false,opacity:1,alphaTest:0,depthTest:true,depthWrite:true,blending:1,vertexColors:false,toneMapped:true,color:{getHex:()=>0x884422},emissive:{getHex:()=>0},roughness:.7,metalness:.1,map:texture()});
const geometry=()=>({index:{count:36},drawRange:{start:0,count:36},groups:[{start:0,count:36,materialIndex:0}],attributes:{position:{count:24,itemSize:3,normalized:false,usage:35044},normal:{count:24,itemSize:3,normalized:false,usage:35044}}});
function fixture(){const mesh=node({geometry:geometry(),material:material()}),root=node({children:[mesh]});return {root,mesh}}

test('idle editor leaves exact visual graph and resources untouched',()=>{const {root}=fixture(),before=captureWalkMapEditorVisualParity([root]);assert.deepEqual(compareWalkMapEditorVisualParity(before,[root]),{ok:true,label:'visual-parity',beforeNodes:2,afterNodes:2,issues:[]})});

test('preview may move only the explicitly allowed whole-object root',()=>{const {root,mesh}=fixture(),before=captureWalkMapEditorVisualParity([root]);root.position.x=12;root.rotation.y=Math.PI/2;root.quaternion.y=Math.sin(Math.PI/4);root.quaternion.w=Math.cos(Math.PI/4);assert.equal(compareWalkMapEditorVisualParity(before,[root],{allowRootTransform:true,allowRootIndices:[0]}).ok,true);mesh.position.y=.25;const report=compareWalkMapEditorVisualParity(before,[root],{allowRootTransform:true,allowRootIndices:[0]});assert.equal(report.ok,false);assert.ok(report.issues.some(issue=>issue.code==='TRANSFORM_CHANGED'&&issue.path==='0/0'))});

test('material, texture and geometry quality regressions are reported',()=>{const {root,mesh}=fixture(),before=captureWalkMapEditorVisualParity([root]);mesh.material.roughness=.1;mesh.material.map.anisotropy=1;mesh.geometry.attributes.position.count=12;const codes=new Set(compareWalkMapEditorVisualParity(before,[root]).issues.map(issue=>issue.code));assert.ok(codes.has('MATERIAL_CHANGED'));assert.ok(codes.has('GEOMETRY_CHANGED'))});

test('resource replacement fails even when its visible descriptors match',()=>{const {root,mesh}=fixture(),before=captureWalkMapEditorVisualParity([root]);mesh.material={...mesh.material};mesh.geometry={...mesh.geometry};const codes=new Set(compareWalkMapEditorVisualParity(before,[root]).issues.map(issue=>issue.code));assert.ok(codes.has('MATERIAL_CHANGED'));assert.ok(codes.has('GEOMETRY_CHANGED'))});

test('reload descriptor mode accepts replacement only when visual quality is identical',()=>{const beforeFixture=fixture(),before=captureWalkMapEditorVisualParity([beforeFixture.root]),reloaded=fixture();assert.equal(compareWalkMapEditorVisualParity(before,[reloaded.root],{allowResourceReplacement:true}).ok,true);reloaded.mesh.material.map.anisotropy=1;const report=compareWalkMapEditorVisualParity(before,[reloaded.root],{allowResourceReplacement:true});assert.equal(report.ok,false);assert.ok(report.issues.some(issue=>issue.code==='MATERIAL_CHANGED'))});

test('delete preview may hide only the allowed root and detects graph changes',()=>{const {root}=fixture(),before=captureWalkMapEditorVisualParity([root]);root.visible=false;assert.equal(compareWalkMapEditorVisualParity(before,[root],{allowRootVisibility:true,allowRootIndices:[0]}).ok,true);root.children.push(node());const report=compareWalkMapEditorVisualParity(before,[root],{allowRootVisibility:true,allowRootIndices:[0]});assert.ok(report.issues.some(issue=>issue.code==='NODE_ADDED'))});

test('captures are required and inputs are validated',()=>{assert.throws(()=>captureWalkMapEditorVisualParity([null]),/object roots/);assert.throws(()=>compareWalkMapEditorVisualParity({},[]),/trusted capture/) });
