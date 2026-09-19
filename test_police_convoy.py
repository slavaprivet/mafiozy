import unittest, types, time, statistics
import police_convoy as pc
class ConvoyTests(unittest.TestCase):
 def setUp(self):
  self.w=types.SimpleNamespace(players={'a':dict(x=10,y=10,hp=100,_wanted=3,_crew_id='crew'),'b':dict(x=10.9,y=10,hp=100,_crew_id='crew')},cops=[dict(id='real',x=10,y=10,hp=100,alive=True)],quest_cars={},_police_convoys={})
  self.r=pc.begin(self.w,'a',dict(x=10,y=10,ang=0,response_vehicle='local'),dict(ok=True,server_cop_id='real'),100)
  self.base=dict(custody_id=self.r['custody_id'],token=self.r['token'])
 def act(self,action,at=101,uid='a',**kwargs):return pc.action(self.w,uid,dict(self.base,action=action,**kwargs),at,lambda *p:True,lambda *p:False)
 def test_identity(self):
  self.assertEqual(self.r['driver_cop_id'],'real');self.assertEqual(self.w.players['a']['_wanted'],3);self.assertNotIn('_jail_until',self.w.players['a'])
  self.assertEqual(pc.begin(self.w,'a',{},dict(ok=True),101)['custody_id'],self.r['custody_id'])
  self.assertFalse(pc.begin(self.w,'b',dict(x=10,y=10),dict(ok=True,server_cop_id='fabricated'),101)['ok'])
 def test_motion_blockade_and_driver(self):
  self.assertTrue(self.act('motion',100.1,x=10.4,y=10,seq=0)['ok'])
  self.w.quest_cars['barrier']=dict(x=11,y=10)
  self.assertTrue(self.act('motion',100.2,x=10.8,y=10,seq=1)['stopped'])
  self.assertEqual(pc.active(self.w,'a')['x'],10.4)
  self.w.quest_cars.pop('barrier');self.w.cops[0]['hp']=0;pc.tick(self.w,100.3)
  self.assertTrue(self.act('motion',100.4,x=10.8,y=10,seq=2,driver_hp=100)['stopped'])
 def test_admission(self):
  self.assertFalse(self.act('motion',100.1,x=30,y=10,seq=0)['ok'])
  self.assertFalse(self.act('motion',100.1,x=float('nan'),y=10,seq=0)['ok'])
  self.assertFalse(self.act('motion',100.1,x=10,y=10,seq=0,token='spoof')['ok'])
  wall=pc.action(self.w,'a',dict(self.base,action='motion',x=10.5,y=10,seq=0),100.1,lambda *p:False,lambda *p:False)
  self.assertEqual(wall['reason'],'wall')
 def test_rescue(self):
  self.assertEqual(self.act('rescue_begin',uid='b')['reason'],'driver_active')
  self.w.cops[0]['alive']=False;pc.tick(self.w,101)
  self.w.players['b']['_crew_id']='enemy';self.assertEqual(self.act('rescue_begin',uid='b')['reason'],'not_ally')
  self.w.players['b']['_crew_id']='crew';self.w.players['b']['x']=30;self.assertEqual(self.act('rescue_begin',uid='b')['reason'],'range_or_wall')
  self.w.players['b']['x']=11
  r=self.act('rescue_begin',uid='b');self.assertTrue(r['ok'])
  self.assertFalse(self.act('rescue_complete',101.2,uid='b',rescue_token=r['rescue_token'])['ok'])
  done=self.act('rescue_complete',102.3,uid='b',rescue_token=r['rescue_token']);self.assertTrue(done['ok']);self.assertEqual(done['wanted'],3)
  self.assertTrue(self.act('rescue_complete',103,uid='b',rescue_token=r['rescue_token'])['replayed'])
  self.assertIsNone(pc.active(self.w,'a'));self.assertNotIn('_npc_convoy_id',self.w.players['a'])
  self.w.cops.append(dict(id='next',x=11,y=10,hp=100,alive=True))
  self.assertTrue(pc.begin(self.w,'a',dict(x=11,y=10),dict(ok=True,server_cop_id='next'),104)['ok'])
 def reset_capture(self):
  self.w._police_convoys.clear();self.w.quest_cars.clear();self.w.players['a'].pop('_npc_convoy_id',None)
  for key in ('_convoy_owner_uid','_convoy_vehicle_id','_convoy_seat_id'):self.w.cops[0].pop(key,None)
 def test_capture_no_teleport_then_board(self):
  self.reset_capture();r=pc.capture(self.w,'a',dict(x=999,y=999),dict(ok=True,server_cop_id='real'),100)
  self.assertTrue(r['ok']);self.assertEqual(r['phase'],'escort');self.assertEqual(self.w.players['a']['x'],10);self.assertFalse(self.w.quest_cars);self.assertEqual(self.w.players['a']['_wanted'],3)
  self.base=dict(custody_id=r['custody_id'],token=r['token'])
  self.assertTrue(self.act('escort',100.1,x=10.3,y=10)['ok'])
  self.assertEqual(self.act('board',100.2,x=14,y=10)['reason'],'boarding_range')
  boarded=self.act('board',100.3,x=10.5,y=10);self.assertTrue(boarded['ok']);self.assertEqual(boarded['custody_id'],r['custody_id']);self.assertEqual(len(self.w.quest_cars),1);self.assertEqual(self.w.players['a']['x'],10.5)
 def test_invalid_capture_and_guard_death(self):
  self.reset_capture();self.assertFalse(pc.capture(self.w,'a',{},dict(ok=False),100)['ok']);self.assertNotIn('_npc_convoy_id',self.w.players['a'])
  pc.capture(self.w,'a',{},dict(ok=True,server_cop_id='real'),100);self.w.cops[0]['hp']=0
  events=pc.tick(self.w,101);self.assertEqual(events[0]['action'],'guard_down');self.assertNotIn('_npc_convoy_id',self.w.players['a']);self.assertEqual(self.w.players['a']['_wanted'],3);self.assertEqual(pc.tick(self.w,102),[])
 def test_disconnect_snapshot_and_true_death(self):
  state=pc.snapshot(self.w,'a');self.assertEqual(state['driver_cop_id'],'real');self.assertEqual(state['token'],self.r['token'])
  old=self.w.players.pop('a');pc.tick(self.w,101);self.assertIsNotNone(pc.active(self.w,'a'))
  self.w.players['a']=dict(old,x=99,y=99);pc.tick(self.w,102);self.assertEqual(self.w.players['a']['x'],10)
  self.w.players['a']['dead']=True;events=pc.tick(self.w,103);self.assertEqual(events[0]['phase'],'dead');self.assertIsNone(pc.active(self.w,'a'));self.assertTrue(self.w.players['a']['dead'])
 def test_contact_wall_is_not_admitted(self):
  self.assertFalse(pc.begin(self.w,'b',dict(x=11,y=10),dict(ok=True,server_cop_id='real'),101,lambda *a:False,lambda *a:False)['ok'])
 def test_booking_registry_and_replay(self):
  self.assertEqual(self.act('arrive',destination_id='missing')['reason'],'destination_unavailable')
  dest={'real':dict(nativeReady=True,stop=dict(r=10,c=10),intake=dict(r=10,c=11),release=dict(r=10,c=12))}
  def book(act,t):return pc.action(self.w,'a',dict(self.base,action=act,destination_id='real'),t,lambda *a:True,lambda *a:False,dest)
  self.assertFalse(book('book',101)['ok']);self.assertTrue(book('arrive',101)['ok']);self.assertTrue(book('arrive',102)['replayed'])
  self.assertFalse(book('book',102)['ok']);self.assertTrue(pc.action(self.w,'a',dict(self.base,action='escort',x=10.5,y=10),102.2,lambda *a:True,lambda *a:False,dest)['ok']);self.assertTrue(book('book',104)['ok']);self.assertTrue(book('book',105)['replayed'])
if __name__=='__main__':unittest.main()
