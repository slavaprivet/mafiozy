// Read-only exact source inventory. No renderer/resource admission is generated.
import fs from 'node:fs';
import crypto from 'node:crypto';
const file = 'godot/mafiozi_walk/data/printshop_interior.json';
const raw = fs.readFileSync(file);
const source = JSON.parse(raw);
const hash = value => crypto.createHash('sha256').update(JSON.stringify(value)).digest('hex');
const batches = source.meshes.flatMap((record, index) => {
  if (!record.instances) return [];
  if (record.instances.some(matrix => matrix.length !== 16 || matrix.some(n => !Number.isFinite(n)))) throw Error('Invalid matrix');
  if (record.instanceColorsLinear && record.instanceColorsLinear.length !== record.instances.length) throw Error('Color count mismatch');
  return [{descriptorIndex:index, sourceName:record.name, motion:record.motion, geometryIndex:record.geometry,
    materialIndices:record.materials, materialNames:record.materials.map(i=>source.materials[i].name),
    instanceCount:record.instances.length, colorCount:record.instanceColorsLinear?.length || 0,
    floorCollision:record.floorCollision, descriptorSha256:hash(record), geometrySha256:hash(source.geometry[record.geometry]),
    instanceMatricesSha256:hash(record.instances), instanceColorsSha256:record.instanceColorsLinear?hash(record.instanceColorsLinear):null}];
});
const total = batches.reduce((sum, record)=>sum+record.instanceCount,0);
if (batches.length !== 15 || total !== 280) throw Error('Actual source inventory changed; re-review lifecycle contract');
console.log(JSON.stringify({schema:'printshop-multimesh-readonly-inventory-v1',sourceFile:file,
  sourceSha256:crypto.createHash('sha256').update(raw).digest('hex'),batches,instanceCount:total,
  coloredInstanceCount:batches.reduce((sum,record)=>sum+record.colorCount,0),
  editorAdmission:false, nativeStorageParity:'HOLD',gpu:false},null,2));
