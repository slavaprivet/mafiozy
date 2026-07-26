import asyncio, json
from aiohttp.test_utils import TestServer, TestClient
import _preview_ws_server as game

async def recv_kind(ws, kind, timeout=2):
    async def loop():
        while True:
            msg=await ws.receive()
            data=json.loads(msg.data)
            if data.get('t')=='event' and data.get('d',{}).get('kind')==kind:return data['d']
    return await asyncio.wait_for(loop(),timeout)

async def snap_where(ws, predicate, timeout=2):
    async def loop():
        while True:
            msg=await ws.receive(); data=json.loads(msg.data)
            if data.get('t')=='snap' and predicate(data['d']):return data['d']
    return await asyncio.wait_for(loop(),timeout)

async def input_role(ws, mafia, x=32, y=32, gang=None):
    await ws.send_json({'t':'input','d':{'x':x,'y':y,'ang':0,'mafia':mafia,'police':False,'gang':gang or []}})
    await asyncio.sleep(.12)

async def main():
    game.players.clear();game.gang_player_invites.clear()
    server=TestServer(game.app);client=TestClient(server);await client.start_server()
    sockets={u:await client.ws_connect(f'/world/sim?uid={u}') for u in ('leader','a','b','c')}
    for ws in sockets.values(): await ws.receive()
    await sockets['a'].send_json({'t':'input','d':{'x':42,'y':160,'ang':.7,'w':True,'swimming':1,'police':False,'mafia':False}})
    swim_snap=await snap_where(sockets['leader'],lambda d:any(o.get('uid')=='a' and o.get('swimming') for o in d.get('others',[])))
    assert next(o for o in swim_snap['others'] if o['uid']=='a')['swimming'] is True
    # Полный сетевой прогон меню Майкла: угон + коробочная доставка.
    await input_role(sockets['leader'],False,x=42,y=183)
    # Helicopter remains controllable over obstacles, but landing is rejected
    # unless the client and authoritative server agree on a safe pad.
    heli_id='test_heli';game.quest_cars[heli_id]={'id':heli_id,'model':'mafia_heli','owner_uid':'leader','driver_uid':'leader','passenger_uids':[],'x':20.,'y':20.,'ang':0.,'vx':0.,'vy':0.,'hp':650,'max_hp':650,'state':'driving','wrecked':False}
    await sockets['leader'].send_json({'t':'gta_drive','d':{'car_id':heli_id,'x':22,'y':22,'ang':.5,'vx':2,'vy':1}});await asyncio.sleep(.05);assert game.quest_cars[heli_id]['x']==22
    await sockets['leader'].send_json({'t':'gta_exit','d':{'car_id':heli_id,'landing_ok':False}});heli_reject=await recv_kind(sockets['leader'],'gta_exit_reply');assert not heli_reject['ok'] and heli_reject['reason']=='unsafe_landing' and game.quest_cars[heli_id]['driver_uid']=='leader'
    await sockets['leader'].send_json({'t':'gta_exit','d':{'car_id':heli_id,'landing_ok':True}});heli_land=await recv_kind(sockets['leader'],'gta_exit_reply');assert heli_land['ok'] and game.quest_cars[heli_id]['driver_uid'] is None
    game.quest_cars.pop(heli_id,None)
    await input_role(sockets['leader'],False,x=42,y=183)
    await sockets['leader'].send_json({'t':'gta_status','d':{}});assert (await recv_kind(sockets['leader'],'gta_status'))['active'] is None
    await sockets['leader'].send_json({'t':'gta_take','d':{}});gta=await recv_kind(sockets['leader'],'gta_take_reply');assert gta['ok'] and gta['car_id'] in game.quest_cars
    gta_id=gta['car_id'];cash_gta=game.preview_account('leader')['cash'];car=game.quest_cars[gta_id]
    await input_role(sockets['leader'],False,x=car['x'],y=car['y'])
    await sockets['leader'].send_json({'t':'gta_enter','d':{'car_id':gta_id}});await asyncio.sleep(.05);assert game.quest_cars[gta_id]['driver_uid']=='leader'
    await sockets['leader'].send_json({'t':'gta_drive','d':{'car_id':gta_id,'x':40,'y':170,'ang':0,'vx':0,'vy':0}});await asyncio.sleep(.05)
    await sockets['leader'].send_json({'t':'gta_exit','d':{'car_id':gta_id}});gta_done=await recv_kind(sockets['leader'],'gta_exit_reply');assert gta_done['delivered'] and game.preview_account('leader')['cash']==cash_gta+gta_done['reward'] and gta_id not in game.quest_cars
    await input_role(sockets['leader'],False,x=42,y=183)
    await sockets['leader'].send_json({'t':'box_status','d':{}});assert (await recv_kind(sockets['leader'],'box_status'))['active'] is None
    await sockets['leader'].send_json({'t':'box_take','d':{}});box=await recv_kind(sockets['leader'],'box_take_reply')
    assert box['ok'] and (box['pickup_x'],box['pickup_y'])==(40.,166.)
    assert box['business_id'] in game.PREVIEW_BUSINESS_POS
    assert (box['dropoff_x'],box['dropoff_y'])==game.PREVIEW_BUSINESS_POS[box['business_id']]
    await input_role(sockets['leader'],False,x=box['pickup_x'],y=box['pickup_y'])
    await sockets['leader'].send_json({'t':'box_pickup','d':{}});assert (await recv_kind(sockets['leader'],'box_pickup_reply'))['ok']
    await sockets['leader'].send_json({'t':'box_load','d':{'car_id':'test_trunk'}});loaded=await recv_kind(sockets['leader'],'box_load_reply');assert loaded['ok'] and loaded['state']=='loaded'
    await sockets['leader'].send_json({'t':'box_deliver','d':{}});assert not (await recv_kind(sockets['leader'],'box_deliver_reply'))['ok']
    await sockets['leader'].send_json({'t':'box_unload','d':{'car_id':'test_trunk'}});assert (await recv_kind(sockets['leader'],'box_unload_reply'))['ok']
    await sockets['leader'].send_json({'t':'box_pickup','d':{}});assert (await recv_kind(sockets['leader'],'box_pickup_reply'))['ok']
    cash_box=game.preview_account('leader')['cash']
    width=game.PREVIEW_ROB_INTERIOR_WIDTHS[box['business_id']]
    await sockets['leader'].send_json({'t':'input','d':{
        'client_active':True,'x':box['dropoff_x'],'y':box['dropoff_y'],
        'ang':0,'mafia':False,'police':False,'gang':[],
        'interior':{'kind':'business','biz_id':box['business_id'],
                    'x':width/2,'y':2.9}}})
    await asyncio.sleep(.12)
    await sockets['leader'].send_json({'t':'box_deliver','d':{}});delivered=await recv_kind(sockets['leader'],'box_deliver_reply');assert delivered['ok'] and game.preview_account('leader')['cash']==cash_box+delivered['reward']
    # Серверная покупка баллона и полный цикл контракта Бригадира.
    cash0=game.preview_account('leader')['cash']
    await sockets['leader'].send_json({'t':'spray_can_buy','d':{}})
    spray=await recv_kind(sockets['leader'],'spray_can_buy_reply');assert spray['ok'] and spray['cash']==cash0-5 and spray['spray_cans']==1
    await input_role(sockets['leader'],False,x=34,y=44)
    await sockets['leader'].send_json({'t':'brigadir_take','d':{}});assert (await recv_kind(sockets['leader'],'brigadir_take_reply'))['ok']
    await sockets['leader'].send_json({'t':'brigadir_accept','d':{'target_id':'test'}});assert (await recv_kind(sockets['leader'],'brigadir_accept_reply'))['ok']
    await sockets['leader'].send_json({'t':'brigadir_kill','d':{'target_id':'test'}});assert (await recv_kind(sockets['leader'],'brigadir_kill_reply'))['ok']
    await sockets['leader'].send_json({'t':'brigadir_claim','d':{}});claim=await recv_kind(sockets['leader'],'brigadir_claim_reply');assert claim['ok'] and claim['reward']==700
    await input_role(sockets['leader'],False)
    # Гражданские не могут приглашать.
    await sockets['leader'].send_json({'t':'gang_player_invite','d':{'target_uid':'a'}})
    assert (await recv_kind(sockets['leader'],'gang_player_reply'))['reason']=='mafia_only'
    for ws in sockets.values():await input_role(ws,True)
    # Лидер + первый участник.
    await sockets['leader'].send_json({'t':'gang_player_invite','d':{'target_uid':'a'}})
    invite=await recv_kind(sockets['a'],'gang_player_invite');assert invite['from_uid']=='leader'
    await sockets['a'].send_json({'t':'gang_player_answer','d':{'accept':True}})
    await recv_kind(sockets['a'],'gang_player_changed')
    s=await snap_where(sockets['leader'],lambda d:len((d['me'].get('online_gang')or{}).get('members',[]))==2)
    assert {m['uid'] for m in s['me']['online_gang']['members']}=={'leader','a'}
    # Лидер + двое.
    await sockets['leader'].send_json({'t':'gang_player_invite','d':{'target_uid':'b'}})
    await recv_kind(sockets['b'],'gang_player_invite');await sockets['b'].send_json({'t':'gang_player_answer','d':{'accept':True}});await recv_kind(sockets['b'],'gang_player_changed')
    await snap_where(sockets['leader'],lambda d:len((d['me'].get('online_gang')or{}).get('members',[]))==3)
    # У каждого участника независимый ранговый отряд, включая 7 NPC Дона.
    await input_role(sockets['leader'],True,gang=[{'r':32,'c':32}]*7)
    await input_role(sockets['a'],True,gang=[{'r':32,'c':32}]*6)
    await input_role(sockets['b'],True,gang=[{'r':32,'c':32}]*5)
    s=await snap_where(sockets['leader'],lambda d:sum(m['npc_count'] for m in (d['me'].get('online_gang')or{}).get('members',[]))==18)
    assert sorted(m['npc_count'] for m in s['me']['online_gang']['members'])==[5,6,7]
    # Четвёртый запрещён.
    await sockets['leader'].send_json({'t':'gang_player_invite','d':{'target_uid':'c'}})
    assert (await recv_kind(sockets['leader'],'gang_player_reply'))['reason']=='full'
    # Любой участник может кикнуть другого.
    await sockets['a'].send_json({'t':'gang_player_kick','d':{'target_uid':'b'}});await asyncio.sleep(.15)
    await snap_where(sockets['b'],lambda d:d['me'].get('online_gang') is None)
    await snap_where(sockets['leader'],lambda d:len((d['me'].get('online_gang')or{}).get('members',[]))==2)
    # Самостоятельный выход распускает оставшуюся пару.
    await sockets['a'].send_json({'t':'gang_player_leave','d':{}});await asyncio.sleep(.15)
    await snap_where(sockets['leader'],lambda d:d['me'].get('online_gang') is None)
    # Повторное вступление и автоматический выход из фракции.
    await sockets['leader'].send_json({'t':'gang_player_invite','d':{'target_uid':'a'}});await recv_kind(sockets['a'],'gang_player_invite');await sockets['a'].send_json({'t':'gang_player_answer','d':{'accept':True}});await recv_kind(sockets['a'],'gang_player_changed')
    await input_role(sockets['a'],False)
    await snap_where(sockets['leader'],lambda d:d['me'].get('online_gang') is None)
    # Разрыв соединения удаляет офлайн-участника и распускает оставшуюся пару.
    await sockets['leader'].send_json({'t':'gang_player_invite','d':{'target_uid':'c'}});await recv_kind(sockets['c'],'gang_player_invite');await sockets['c'].send_json({'t':'gang_player_answer','d':{'accept':True}});await recv_kind(sockets['c'],'gang_player_changed')
    await sockets['c'].close();await asyncio.sleep(.15)
    await snap_where(sockets['leader'],lambda d:d['me'].get('online_gang') is None)
    print('ONLINE_GANG_E2E_OK')
    for ws in sockets.values():await ws.close()
    await client.close()

asyncio.run(main())
