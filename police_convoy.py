"""Staged NPC custody backed by canonical WorldSim police and quest-car objects.
Native driving proposes motion; this module admits bounded server poses, never
client HP or a claimed driver death. Booking only uses the committed registry.
"""
import json
import math
import secrets
import time
from pathlib import Path

REGISTRY_PATH = Path(__file__).parent / 'assets/maps/city_rebuild_v1/detention_destinations.v1.json'
_ACTIVE = {'escort', 'transport', 'arrived'}

_registry_cache={};_registry_at=-1.
def registry():
    global _registry_cache,_registry_at
    now=time.monotonic()
    if now-_registry_at<1:return _registry_cache
    _registry_at=now
    try:
        data = json.loads(REGISTRY_PATH.read_text(encoding='utf-8-sig'))
        _registry_cache={str(q['id']): q for q in data.get('destinations', [])
                if q.get('nativeReady') is True and all(isinstance(q.get(k), dict) for k in ('stop','intake','release'))}
        return _registry_cache
    except (OSError, ValueError, KeyError, TypeError):
        _registry_cache={}
        return _registry_cache

def _records(world):
    return world._police_convoys

def active(world, uid):
    q = _records(world).get(str(uid))
    return q if q and q['phase'] in _ACTIVE else None

def _driver(world, q):
    return next((c for c in world.cops if str(c.get('id')) == q['driver_id']), None)

def _car(world, q):
    return world.quest_cars.get(q['vehicle_id'])

def _point(data):
    try:
        x,y,ang = float(data['x']),float(data['y']),float(data.get('ang',0))
        return (x,y,ang) if all(math.isfinite(v) for v in (x,y,ang)) else None
    except (ValueError,TypeError,KeyError,OverflowError):
        return None

def _reply(q, **extra):
    return dict(ok=True,custody_id=q['id'],vehicle_id=q['vehicle_id'],driver_cop_id=q['driver_id'],phase=q['phase'],**extra)

def capture(world,uid,body,contact,now):
    uid=str(uid);p=world.players.get(uid)
    if not p or p.get('dead') or float(p.get('hp') or 0)<=0 or not contact.get('ok'):return dict(ok=False,reason='invalid_capture')
    old=active(world,uid)
    if old:return _reply(old,token=old['token'])
    driver=next((c for c in world.cops if str(c.get('id'))==str(contact.get('server_cop_id')) and c.get('alive') and float(c.get('hp') or 0)>0),None)
    if not driver:return dict(ok=False,reason='driver_missing')
    q=dict(id='convoy_'+secrets.token_hex(8),owner_uid=uid,token=secrets.token_urlsafe(24),vehicle_id='',driver_id=str(driver['id']),phase='escort',x=float(p['x']),y=float(p['y']),ang=float(p.get('ang') or 0),capture_x=float(p['x']),capture_y=float(p['y']),started_at=now,motion_at=now,escort_at=now,last_seq=-1,wanted_before=float(p.get('_wanted') or 0),source_vehicle='',rescue={},rescue_result=None)
    _records(world)[uid]=q;p['_npc_convoy_id']=q['id'];p['walking']=False;driver['_convoy_owner_uid']=uid
    return _reply(q,token=q['token'],x=q['x'],y=q['y'])

def board(world,uid,q,body,now,los,is_wall):
    if q['phase']=='transport':return _reply(q,token=q['token'],replayed=True,x=q['x'],y=q['y'])
    if q['phase']!='escort':return dict(ok=False,reason='phase')
    p=world.players.get(uid);driver=_driver(world,q);pose=_point(body)
    if not p or p.get('dead') or not driver or not driver.get('alive') or float(driver.get('hp') or 0)<=0:return dict(ok=False,reason='guard_unavailable')
    if not pose or math.hypot(pose[0]-float(p['x']),pose[1]-float(p['y']))>1.6:return dict(ok=False,reason='boarding_range')
    if is_wall(int(pose[1]),int(pose[0])) or not los(float(p['x']),float(p['y']),pose[0],pose[1]):return dict(ok=False,reason='boarding_wall')
    vid='custody_car_'+secrets.token_hex(8);q.update(vehicle_id=vid,phase='transport',x=pose[0],y=pose[1],ang=pose[2],motion_at=now,last_seq=-1)
    q.pop('prisoner_x',None);q.pop('prisoner_y',None)
    world.quest_cars[vid]=dict(id=vid,model='police',owner_uid='',driver_uid=None,passenger_uids=[uid],x=q['x'],y=q['y'],ang=q['ang'],vx=0.,vy=0.,hp=360,max_hp=360,reward=0,lock_lvl=99,state='driving',police_patrol=True,siren=True,custody_id=q['id'],custody_owner_uid=uid,custody_driver_id=q['driver_id'],_spawn_t=now,_last_drive_t=now)
    driver['_convoy_vehicle_id']=vid;driver['_convoy_seat_id']='front_left';_sync(world,q,now)
    return _reply(q,token=q['token'],x=q['x'],y=q['y'])

def begin(world, uid, body, contact, now, los=None, is_wall=None):
    uid=str(uid);p=world.players.get(uid)
    if not p or p.get('dead') or not contact.get('ok'):return dict(ok=False,reason='no_server_contact')
    old=active(world,uid)
    if old and old['phase']=='escort':return board(world,uid,old,body,now,los or (lambda *a:True),is_wall or (lambda *a:False))
    if old:return _reply(old,token=old['token'],x=old['x'],y=old['y'],ang=old['ang'])
    driver=next((c for c in world.cops if str(c.get('id'))==str(contact.get('server_cop_id')) and c.get('alive') and float(c.get('hp',0))>0),None)
    if not driver:return dict(ok=False,reason='driver_missing')
    pose=_point(body)
    if not pose or math.hypot(pose[0]-float(p['x']),pose[1]-float(p['y']))>2.8:return dict(ok=False,reason='vehicle_contact')
    if is_wall and is_wall(int(pose[1]),int(pose[0])):return dict(ok=False,reason='vehicle_wall')
    if los and not los(float(p['x']),float(p['y']),pose[0],pose[1]):return dict(ok=False,reason='vehicle_wall')
    token=secrets.token_urlsafe(24);cid='convoy_'+secrets.token_hex(8);vid='custody_car_'+secrets.token_hex(8)
    q=dict(id=cid,owner_uid=uid,token=token,vehicle_id=vid,driver_id=str(driver['id']),phase='transport',
           x=pose[0],y=pose[1],ang=pose[2],started_at=now,motion_at=now,last_seq=-1,
           wanted_before=float(p.get('_wanted') or 0),source_vehicle=str(body.get('response_vehicle') or '')[:80],
           rescue={},rescue_result=None)
    _records(world)[uid]=q
    car=dict(id=vid,model='police',owner_uid='',driver_uid=None,passenger_uids=[uid],
             x=q['x'],y=q['y'],ang=q['ang'],vx=0.,vy=0.,hp=360,max_hp=360,
             reward=0,lock_lvl=99,state='driving',police_patrol=True,siren=True,
             custody_id=cid,custody_owner_uid=uid,custody_driver_id=q['driver_id'],
             _spawn_t=now,_last_drive_t=now)
    world.quest_cars[vid]=car
    driver['_convoy_owner_uid']=uid;driver['_convoy_vehicle_id']=vid;driver['_convoy_seat_id']='front_left'
    p['_npc_convoy_id']=cid;p['x']=q['x'];p['y']=q['y'];p['walking']=False
    return _reply(q,token=token,x=q['x'],y=q['y'])

def _stopped_driver(world,q):
    driver=_driver(world,q);car=_car(world,q)
    return not driver or not driver.get('alive') or float(driver.get('hp') or 0)<=0 or not car or car.get('wrecked') or float(car.get('hp') or 0)<=0

def _sync(world,q,now):
    car=_car(world,q);driver=_driver(world,q);p=world.players.get(q['owner_uid'])
    if car:
        car.update(x=q['x'],y=q['y'],ang=q['ang'],_last_drive_t=now)
        if _stopped_driver(world,q):car.update(vx=0.,vy=0.,state='idle')
    if driver:
        dx,dy=(q.get('prisoner_x',q['x']),q.get('prisoner_y',q['y'])) if q['phase'] in ('escort','arrived') else (q['x'],q['y'])
        driver['x']=dx+math.cos(q['ang'])*.15-math.sin(q['ang'])*.17
        driver['y']=dy+math.sin(q['ang'])*.15+math.cos(q['ang'])*.17
        driver['ang']=q['ang'];driver['walking']=False
    if p:
        p['_npc_convoy_id']=q['id'];p['x']=q.get('prisoner_x',q['x']);p['y']=q.get('prisoner_y',q['y']);p['ang']=q['ang'];p['walking']=False

def tick(world,now):
    events=[]
    for uid,q in list(_records(world).items()):
        if q['phase'] not in _ACTIVE:
            if now-float(q.get('ended_at') or now)>600:_records(world).pop(uid,None)
            continue
        p=world.players.get(uid)
        pending=q.get('rescue') or {}
        if pending:
            ally=world.players.get(pending.get('by'))
            if not ally or ally.get('dead') or math.hypot(float(ally.get('x') or 0)-q['x'],float(ally.get('y') or 0)-q['y'])>2.4 or now-float(pending.get('at') or now)>6:q['rescue']={}
        if p and p.get('dead'):
            q['phase']='dead';q['ended_at']=now;p.pop('_npc_convoy_id',None)
            driver=_driver(world,q);car=_car(world,q)
            if driver:
                for key in ('_convoy_owner_uid','_convoy_vehicle_id','_convoy_seat_id'):driver.pop(key,None)
            if car:car.update(custody_owner_uid='',passenger_uids=[],state='idle',vx=0.,vy=0.)
            events.append(dict(_reply(q),kind='police_convoy_reply',action='death',target_uid=uid))
            continue
        driver=_driver(world,q)
        if q['phase']=='escort' and (not driver or not driver.get('alive') or float(driver.get('hp') or 0)<=0):
            q['phase']='rescued';q['ended_at']=now
            if p:p.pop('_npc_convoy_id',None)
            if driver:driver.pop('_convoy_owner_uid',None)
            events.append(dict(_reply(q),kind='police_convoy_reply',action='guard_down',target_uid=uid,x=float((p or {}).get('x',q['x'])),y=float((p or {}).get('y',q['y'])),wanted=float((p or {}).get('_wanted',q['wanted_before']))))
            continue
        _sync(world,q,now)
    return events


def action(world,uid,body,now,los,is_wall,destinations=None):
    uid=str(uid);p=world.players.get(uid)
    if not p or not isinstance(body,dict):return dict(ok=False,reason='player')
    act=body.get('action');cid=str(body.get('custody_id') or '')
    q=next((q for q in _records(world).values() if q['id']==cid),None)
    if not q:return dict(ok=False,reason='custody')
    if act in ('rescue_begin','rescue_complete'):
        return rescue(world,uid,q,body,now,los,is_wall)
    if q['owner_uid']!=uid or not secrets.compare_digest(str(body.get('token') or ''),q['token']):return dict(ok=False,reason='owner')
    if q['phase']=='booked' and act=='book':return _reply(q,jail_s=60,destination_id=q.get('destination_id'),replayed=True)
    if q['phase'] not in _ACTIVE:return dict(ok=False,reason='terminal',phase=q['phase'])
    _sync(world,q,now)
    if act=='board':return board(world,uid,q,body,now,los,is_wall)
    if act=='escort' and q['phase']=='escort':
        pose=_point(body);px,py=float(p['x']),float(p['y']);dt=now-q.get('escort_at',q['started_at'])
        if not pose or dt<.08 or math.hypot(pose[0]-px,pose[1]-py)>min(dt,.6)*3+.03:return dict(ok=False,reason='escort_speed')
        if math.hypot(pose[0]-q['capture_x'],pose[1]-q['capture_y'])>20 or not los(px,py,pose[0],pose[1]) or is_wall(int(pose[1]),int(pose[0])):return dict(ok=False,reason='escort_path')
        q.update(prisoner_x=pose[0],prisoner_y=pose[1],escort_at=now);_sync(world,q,now);return _reply(q,x=pose[0],y=pose[1])
    if act=='motion':
        if q['phase']!='transport':return dict(ok=False,reason='phase')
        if _stopped_driver(world,q):return _reply(q,stopped=True,reason='driver_or_vehicle_down',x=q['x'],y=q['y'])
        pose=_point(body);seq=body.get('seq')
        if not pose or isinstance(seq,bool) or not isinstance(seq,int) or seq<=q['last_seq']:return dict(ok=False,reason='sequence')
        dt=now-q['motion_at']
        if dt<.08:return dict(ok=False,reason='cadence')
        distance=math.hypot(pose[0]-q['x'],pose[1]-q['y'])
        if distance>min(dt,.6)*12+.025:return dict(ok=False,reason='speed')
        if is_wall(int(pose[1]),int(pose[0])) or not los(q['x'],q['y'],pose[0],pose[1]):return dict(ok=False,reason='wall')
        for other_id,other in world.quest_cars.items():
            if other_id==q['vehicle_id'] or other.get('wrecked'):continue
            # Conservative server vehicle footprint; native geometry is checked by source too.
            ox,oy=float(other.get('x') or 0),float(other.get('y') or 0)
            dx,dy=pose[0]-q['x'],pose[1]-q['y'];length2=dx*dx+dy*dy
            u=max(0.,min(1.,((ox-q['x'])*dx+(oy-q['y'])*dy)/length2)) if length2 else 0.
            if math.hypot(q['x']+dx*u-ox,q['y']+dy*u-oy)<.9:return _reply(q,stopped=True,reason='vehicle_blockade',x=q['x'],y=q['y'])
        q.update(x=pose[0],y=pose[1],ang=pose[2],motion_at=now,last_seq=seq)
        car=_car(world,q)
        if car:car.update(vx=math.cos(q['ang'])*distance/dt,vy=math.sin(q['ang'])*distance/dt,state='driving')
        _sync(world,q,now);return _reply(q,x=q['x'],y=q['y'],seq=seq)
    if act=='escort':
        if q['phase']!='arrived':return dict(ok=False,reason='phase')
        pose=_point(body);dest=(registry() if destinations is None else destinations).get(q.get('destination_id'))
        if not pose or not dest:return dict(ok=False,reason='destination_unavailable')
        px,py=q.get('prisoner_x',q['x']),q.get('prisoner_y',q['y']);dt=now-q.get('escort_at',q['arrived_at'])
        if dt<.08 or math.hypot(pose[0]-px,pose[1]-py)>min(.6,dt)*3+.03:return dict(ok=False,reason='escort_speed')
        if math.hypot(pose[0]-float(dest['intake']['c']),pose[1]-float(dest['intake']['r']))>8 or not los(px,py,pose[0],pose[1]):return dict(ok=False,reason='escort_path')
        q.update(prisoner_x=pose[0],prisoner_y=pose[1],escort_at=now);_sync(world,q,now)
        return _reply(q,x=pose[0],y=pose[1])
    if act in ('arrive','book'):
        dest_id=str(body.get('destination_id') or '');dest=(registry() if destinations is None else destinations).get(dest_id)
        if not dest or dest.get('nativeReady') is not True:return dict(ok=False,reason='destination_unavailable')
        stop=dest['stop'];radius=float(dest.get('bookingRadius') or 2.5)
        if math.hypot(q['x']-float(stop['c']),q['y']-float(stop['r']))>radius:return dict(ok=False,reason='not_at_destination')
        if act=='arrive':
            if _stopped_driver(world,q):return dict(ok=False,reason='driver_down_before_handoff')
            if q['phase']=='arrived':return _reply(q,replayed=True)
            q['phase']='arrived';q['arrived_at']=now;q['destination_id']=dest_id
            driver=_driver(world,q)
            if driver:driver.pop('_convoy_vehicle_id',None);driver.pop('_convoy_seat_id',None)
            return _reply(q)
        if q['phase']!='arrived' or q.get('destination_id')!=dest_id:return dict(ok=False,reason='no_handoff')
        if math.hypot(q.get('prisoner_x',q['x'])-float(dest['intake']['c']),q.get('prisoner_y',q['y'])-float(dest['intake']['r']))>.9:return dict(ok=False,reason='not_at_intake')
        if now-q.get('arrived_at',now)<2.7:return dict(ok=False,reason='booking_too_early')
        # Caller persists jail once; replay is handled by the terminal receipt.
        q['phase']='booked';q['ended_at']=now;p.pop('_npc_convoy_id',None)
        driver=_driver(world,q)
        if driver:driver.pop('_convoy_owner_uid',None);driver.pop('_convoy_vehicle_id',None);driver.pop('_convoy_seat_id',None)
        car=_car(world,q)
        if car:car.update(state='idle',vx=0.,vy=0.,passenger_uids=[],custody_owner_uid='',_last_drive_t=now)
        return _reply(q,jail_s=60,destination_id=dest_id)
    return dict(ok=False,reason='action')


def rescue(world,rescuer_uid,q,body,now,los,is_wall):
    rescuer=world.players.get(rescuer_uid);target=world.players.get(q['owner_uid'])
    if q['phase']=='rescued' and (q.get('rescue_result') or {}).get('rescuer_uid')==rescuer_uid:return dict(q['rescue_result'],replayed=True)
    if q['phase']!='transport':return dict(ok=False,reason='not_rescuable')
    if not rescuer or not target or float(rescuer.get('hp',100))<=0 or rescuer_uid==q['owner_uid'] or rescuer.get('dead') or rescuer.get('_npc_convoy_id') or (rescuer.get('_jail_until') or 0)>now:return dict(ok=False,reason='rescuer')
    crew=str(target.get('_crew_id') or '')
    if not crew or str(rescuer.get('_crew_id') or '')!=crew:return dict(ok=False,reason='not_ally')
    car=_car(world,q)
    if not _stopped_driver(world,q):return dict(ok=False,reason='driver_active')
    if car and math.hypot(float(car.get('vx') or 0),float(car.get('vy') or 0))>.1:return dict(ok=False,reason='moving')
    rx,ry=float(rescuer['x']),float(rescuer['y'])
    if not all(math.isfinite(v) for v in (rx,ry)) or math.hypot(rx-q['x'],ry-q['y'])>2.4 or not los(rx,ry,q['x'],q['y']):return dict(ok=False,reason='range_or_wall')
    if body.get('action')=='rescue_begin':
        token=secrets.token_urlsafe(16);q['rescue']={"by":rescuer_uid,"at":now,"token":token}
        return _reply(q,rescue_token=token,hold_s=1.2)
    pending=q.get('rescue') or {}
    if pending.get('by')!=rescuer_uid or not secrets.compare_digest(str(body.get('rescue_token') or ''),str(pending.get('token') or '')) or not 1.2<=now-float(pending.get('at') or now)<=6:return dict(ok=False,reason='hold')
    exit_pos=None
    for off in (.65,1.,1.4):
        dx,dy=rx-q['x'],ry-q['y'];distance=math.hypot(dx,dy) or 1
        x,y=q['x']+dx/distance*off,q['y']+dy/distance*off
        if not is_wall(int(y),int(x)) and los(rx,ry,x,y):exit_pos=(x,y);break
    if exit_pos is None:return dict(ok=False,reason='exit_blocked')
    target.pop('_npc_convoy_id',None);target['x'],target['y']=exit_pos;target['walking']=False
    target['_wanted']=max(float(target.get('_wanted') or 0),q['wanted_before'])
    q['phase']='rescued';q['ended_at']=now
    driver=_driver(world,q)
    if driver:
        for key in ('_convoy_owner_uid','_convoy_vehicle_id','_convoy_seat_id'):driver.pop(key,None)
    if car:car.update(passenger_uids=[],custody_owner_uid='',state='idle',vx=0.,vy=0.)
    q['rescue_result']=_reply(q,target_uid=q['owner_uid'],rescuer_uid=rescuer_uid,x=exit_pos[0],y=exit_pos[1],wanted=target['_wanted'])
    return q['rescue_result']


def detention(world,uid):
    q=_records(world).get(str(uid))
    if not q or q.get('phase')!='booked':return None
    return registry().get(q.get('destination_id'))


def snapshot(world,uid):
    q=active(world,uid)
    if not q:return None
    driver=_driver(world,q);car=_car(world,q)
    return _reply(q,token=q['token'],x=q['x'],y=q['y'],ang=q['ang'],prisoner_x=q.get('prisoner_x',q['x']),prisoner_y=q.get('prisoner_y',q['y']),destination_id=q.get('destination_id',''),driver_hp=float((driver or {}).get('hp') or 0),driver_alive=bool(driver and driver.get('alive') and float(driver.get('hp') or 0)>0),vehicle_hp=float((car or {}).get('hp') or 0),last_seq=q.get('last_seq',-1))
