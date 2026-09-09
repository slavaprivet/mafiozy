import fs from 'node:fs';
import {resizeBuildingPlacement} from './resize_building_placement.mjs';
import {placeBankShells} from './place_bank_shells.mjs';
import {BUILDING_ROOM_PROFILES} from './building_room_profiles.mjs';
const dir=new URL('./',import.meta.url),root=new URL('../../../',dir);
const read=url=>JSON.parse(fs.readFileSync(url,'utf8'));
const base=read(new URL('buildings_placement.before_room_sizes.v1.json',dir));
const common={topology:read(new URL('topology_for_placement.json',dir)),source:read(base.inputs[1].path),decor:read(new URL('decor_placement.v1.json',dir)),ledger:read(new URL('docs/city-rebuild/rebuild-ledger.generated.json',root))};
const {plan:resized,report}=resizeBuildingPlacement({base,...common});
for(const row of report){
 const {bounds:[x0,z0,x1,z1],inset}=BUILDING_ROOM_PROFILES[row.assetId];
 row.roomWidthM=+(row.scale[0]*(x1-x0-2*inset)).toFixed(2);
 row.roomDepthM=+(row.scale[1]*(z1-z0-2*inset)).toFixed(2);
 row.roomAreaM2=+((x1-x0-2*inset)*(z1-z0-2*inset)*row.areaMultiplier).toFixed(2);
}
const plan=placeBankShells({plan:resized,manifest:read(new URL('bank_shells/manifest.v1.json',dir)),...common});
fs.writeFileSync(new URL('buildings_placement.v1.json',dir),JSON.stringify(plan,null,2)+'\n');
fs.writeFileSync(new URL('docs/city-rebuild/room_sizes.report.json',root),JSON.stringify(report,null,2)+'\n');
console.log('Generated '+plan.instances.length+' buildings: '+report.length+' enlarged existing shells and 3 divided banks. Run test_room_size_integration.mjs before accepting.');
