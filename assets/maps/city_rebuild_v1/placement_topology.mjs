import {compileAddendum} from './addendum.mjs';
import {pointInPolygon} from './topology.mjs';
const clone=x=>JSON.parse(JSON.stringify(x));
/** Placement / isolated pedestrian preview only. Never returns an approved
 * vehicle/gameplay world. No synthetic police snapshot is presented as host data.
 * Pass actual post-buildMap cells AND policeSnapshotAuthority:'host-buildMap'
 * to remove pendingHostSnapshot; host migration still requires its own gates.
 */
export function buildPlacementTopology(addendum,{base,policeProtectedCells,policeSnapshotAuthority}={}){
  const realHost=policeSnapshotAuthority==='host-buildMap'&&Array.isArray(policeProtectedCells);
  if(policeProtectedCells&&!realHost)throw new Error('Police snapshot needs explicit host-buildMap authority; placeholders are not accepted');
  const result=compileAddendum(addendum,{base,policeProtectedCells:realHost?policeProtectedCells:undefined});
  const blockers=result.validation.errors.filter(e=>e.code!=='EXACT_HOST_POLICE_TILES_REQUIRED');
  if(blockers.length){const e=new Error('Placement topology rejected: '+blockers.map(x=>x.code+':'+x.id).join(', '));e.findings=blockers;throw e;}
  if(result.validation.connectivity.length!==1||result.validation.roadOnWater||result.validation.bridgeOutsideEnvelope||result.validation.subsurfaceBridges)throw new Error('Native invariants rejected placement output');
  const grid=clone(result.analysisGrid),police=new Set(result.protectedPoliceCellsRC.map(([r,c])=>r*180+c));
  const bridges=addendum.crossings.filter(x=>x.layer==='bridge_deck'&&x.status.startsWith('enabled_'));
  const matrix=()=>Array.from({length:200},()=>Array(180).fill(0));
  const roadMask=matrix(),walkableMask=matrix(),protectedMask=matrix(),policeMask=matrix(),bridgeDeckMask=matrix();
  for(let r=0;r<200;r++)for(let c=0;c<180;c++){
    const p=[c+.5,r+.5],isPolice=police.has(r*180+c),isDeck=bridges.some(b=>pointInPolygon(p,b.deck_envelope_polygon_grid_cr));
    policeMask[r][c]=isPolice?1:0;bridgeDeckMask[r][c]=isDeck?1:0;
    protectedMask[r][c]=isPolice||isDeck?1:0;
    roadMask[r][c]=[0,19].includes(grid[r][c])?1:0;
    // Police is reserved from this isolated walker even with a host snapshot:
    // visual island/solid-body gameplay is owned by a different host adapter.
    walkableMask[r][c]=!isPolice&&[0,8,9,14,19].includes(grid[r][c])?1:0;
  }
  return {schema:'mafiozy.city-rebuild-placement-topology/v1',status:realHost?'ISOLATED_TOPOLOGY_HOST_TILES_CAPTURED':'ISOLATED_WALK_TOPOLOGY_PENDING_HOST',
    scope:'isolated-pedestrian-preview-and-placement-only',pendingHostSnapshot:!realHost,vehicleReady:false,gameplayReady:false,productionReady:false,
    coordinateConvention:'grid and masks [row][column]; topology polygons and source points [column,row]',map:{rows:200,cols:180,worldUnitsPerCell:4.1},
    grid,roadMask,walkableMask,protectedMask,policeMask,bridgeDeckMask,
    maskSemantics:{roadMask:'tile0 or19; collision/navigation not vehicle-approved',walkableMask:'land or supported deck excluding reserved police; add placed-building colliders separately',protectedMask:'exact police footprint overlap OR enabled bridge-deck polygon; do not place buildings/decor here',policeMask:'reserved actual union; tile9 is an isolated placeholder until host snapshot',bridgeDeckMask:'explicit enabled surface crossing decks; not deferred tunnels'},
    crossings:clone(addendum.crossings),districts:clone(base.districts),terrain:{waterbodies:clone(addendum.waterbodies),islets:clone(base.water.islets),greenPublic:clone(base.green_public)},
    sourceRevision:{version:addendum.version,schema:addendum.schema,authoritativeBase:clone(addendum.sources.authoritative_handoff_v1)},
    sourceCorrections:clone(addendum.envelope_correction||{}),runtimeRepairs:[],
    validation:{structuralChecksPassed:true,hostSnapshotPending:!realHost,underlyingCompilerStatus:result.status,underlyingCompilerErrors:clone(result.validation.errors),
      counts:clone(result.validation.counts),connectedRoadCells:result.validation.connectivity[0].cells,roadComponentCount:1,
      roadCount:result.validation.roadCount,fragmentCount:result.validation.fragmentCount,gapCount:result.validation.gapCount,
      roadOnWater:0,bridgeOutsideEnvelope:0,subsurfaceBridges:0,terrestrialFallback:clone(result.validation.terrestrialFallback),
      deferredCrossings:clone(result.validation.deferredCrossings),protectedPoliceCells:police.size,
      emptyRoadIds:addendum.roads.filter(r=>!r.land_fragments_grid_cr.length).map(r=>r.id),
      notValidated:['real post-buildMap police tiles','placed building/decor collisions','character controller','vehicles and turning radii','gameplay ID migration','server authority','live rendering']}};
}
