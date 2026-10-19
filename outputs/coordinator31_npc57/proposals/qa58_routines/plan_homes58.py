"""Source-map planning adapted from plan_sites29.py; native placement is mandatory."""
from pathlib import Path
import collections, hashlib, json, math, re

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
GAME = ROOT / 'outputs/coordinator31_npc57/game'
SOURCE = GAME / 'data/city_block.json'
VENUES = GAME / 'data/venue_sites29.json'
HISTORY = HERE.parent / 'qa58_merged/runs/merged58_1200_02/stdout.log'
ORIGINAL = ROOT / 'outputs/coordinator29_npc53/proposals/venues29_sites/qa/plan_sites29.py'
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()

def main():
    data = json.loads(SOURCE.read_text(encoding='utf-8'))
    surface = data['surface']; grid = surface['grid']; masks = surface['masks']; cell = surface['cellSize']
    ox, _, oz = data['originM']; cols = surface['cols']; rows = surface['rows']
    def rc(x,z): return math.floor((z+oz)/cell)-surface['startRow'], math.floor((x+ox)/cell)-surface['startCol']
    def centre(r,c): return ((c+surface['startCol']+.5)*cell-ox, (r+surface['startRow']+.5)*cell-oz)
    def good(x,z,grass=False):
        r,c=rc(x,z)
        return 0<=r<rows and 0<=c<cols and not masks['protectedMask'][r][c] and bool(masks['walkableMask'][r][c]) and (grid[r][c]==8 if grass else grid[r][c] not in [16,19])
    boxes=[]
    for record in data['buildings']+data['decor']:
        for body in record.get('collisionBodiesM',[]):
            points=body['polygonXZ']; boxes.append((min(p[0] for p in points),min(p[1] for p in points),max(p[0] for p in points),max(p[1] for p in points)))
    source_boxes=len(boxes)
    # Actual frozen launch uses clone-step=22. Conservatively reserve original
    # Palazzo plus all four clone grounds/benches and their door aprons.
    boxes.extend((48.5+i*22-11,-13,48.5+i*22+11,13) for i in range(5))
    venues=json.loads(VENUES.read_text(encoding='utf-8'))['entries']
    for venue in venues:
        boxes.extend([venue['footprint_xz'],venue['apron_xz']])
    def intersects(a,b,pad=0): return a[0]<b[2]+pad and a[2]>b[0]-pad and a[1]<b[3]+pad and a[3]>b[1]-pad
    spawn=data['hero']['spawnLocalM']; sr,sc=rc(spawn[0],spawn[2])
    visited={(sr,sc)}; todo=collections.deque([(sr,sc)])
    while todo:
        r,c=todo.popleft()
        for nr,nc in [(r+1,c),(r-1,c),(r,c+1),(r,c-1)]:
            if (nr,nc) in visited or not (0<=nr<rows and 0<=nc<cols):continue
            if masks['walkableMask'][nr][nc] and not masks['policeMask'][nr][nc] and grid[nr][nc]!=16:
                visited.add((nr,nc));todo.append((nr,nc))
    starts={}
    with HISTORY.open(encoding='utf-8-sig') as stream:
        for line in stream:
            match=re.search(r'NPC_ROAM51 id=(resident_\d+) result=started from=\(([^)]+)\)',line)
            if match and match[1] not in starts: starts[match[1]]=[float(v) for v in match[2].split(',')]
            if len(starts)==10:break
    assert set(starts)=={f'resident_{i}' for i in range(1,11)}
    candidates=[]
    for r in range(rows):
        for c in range(cols):
            if grid[r][c]!=8:continue
            x,z=centre(r,c)
            for dx,dz,yaw in [(0,1,0),(1,0,math.pi/2),(0,-1,math.pi),(-1,0,-math.pi/2)]:
                tx,tz=dz,-dx
                def world(a,b):return x+tx*a+dx*b,z+tz*a+dz*b
                def bounds(points):return [min(p[0] for p in points),min(p[1] for p in points),max(p[0] for p in points),max(p[1] for p in points)]
                # Same native placement shell (8.7 x 7.8), plus a conservative
                # margin covering cornices. No zero-volume/source-only exemption.
                bbox=bounds([world(a,b) for a in [-4.6,4.6] for b in [-4,4]])
                if any(intersects(bbox,b,1) for b in boxes):continue
                if not all(good(*world(a,b),True) for a in range(-5,6) for b in range(-4,5)):continue
                road=None
                for distance in range(8,23):
                    ax,az=world(0,distance); ar,ac=rc(ax,az)
                    if not good(ax,az):break
                    if grid[ar][ac]==0 and (ar,ac) in visited:road=(ax,az,distance);break
                if road is None:continue
                if not all(good(*world(a,b)) for a in range(-6,7) for b in range(4,road[2]+1)):continue
                ab=bounds([world(a,b) for a in [-6,6] for b in [3.5,road[2]]])
                if any(intersects(ab,b,.5) for b in boxes):continue
                candidates.append(dict(x=x,z=z,yaw=yaw,road=road,bounds=bbox,apron=ab))
    groups=[[1,8,9],[2,6,7],[3,5],[4,10]]; chosen=[]; entries=[]
    for number,group in enumerate(groups,1):
        ids=[f'resident_{i}' for i in group]
        options=[a for a in candidates if all(not intersects(a['bounds'],b['bounds'],4) and not intersects(a['apron'],b['bounds'],2) and not intersects(a['bounds'],b['apron'],2) for b in chosen)]
        def distances(a):return [math.hypot(a['x']-starts[i][0],a['z']-starts[i][2]) for i in ids]
        # Minimax plus mean makes the geographically dispersed western group
        # reasonable for every member rather than stranding one far away.
        best=min(options,key=lambda a:max(distances(a))+.25*sum(distances(a))/len(ids)+.2*a['road'][2])
        chosen.append(best)
        entries.append({'id':f'HOME58-{number:03d}','number':number,'residents':ids,'kind':'home','sign':f'ДОМ {number}',
                        'position':[round(best['x'],4),0,round(best['z'],4)],'yaw':best['yaw'],
                        'road_point':[round(best['road'][0],4),0,round(best['road'][1],4)],
                        'source_ground':'grass, unprotected, dry','road_distance_from_centre_m':best['road'][2],
                        'footprint_xz':best['bounds'],'apron_xz':best['apron'],
                        'initial_native_walk_origin_distance_m':{i:round(d,3) for i,d in zip(ids,distances(best))}})
    report={'schema':'mafiozi.homes58/v1','source_sha256':sha(SOURCE),'source_coordinate_frame':'main local X/Z metres; world identity required',
            'native_acceptance':'PENDING','existing_models_reintroduced':False,'entries':entries,
            'source_evidence':{'planner_reused':str(ORIGINAL.relative_to(ROOT)),'planner_sha256':sha(ORIGINAL),'venue_plan_sha256':sha(VENUES),
                               'native_initial_walk_log_sha256':sha(HISTORY),'native_initial_walk_origins':starts,'source_candidates':len(candidates),
                               'connected_source_cells':len(visited),'source_collision_boxes_excluded':source_boxes,
                               'reserved_palazzo_and_clones':5,'reserved_current_venues':8,
                               'limit':'Dry source proof is conservative, not native terrain/placement/route acceptance; historical first walk origins, not current live positions.'}}
    (HERE/'homes58.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'source_candidates':len(candidates),'entries':entries},ensure_ascii=False))

if __name__=='__main__':main()
