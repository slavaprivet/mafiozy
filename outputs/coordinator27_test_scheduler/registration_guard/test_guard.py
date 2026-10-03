"""CPU-only: actual Python child and private real Lease registry, no Godot."""
import copy
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
import time
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
    return module


s = load('registration_test_scheduler', ROOT/'tools/godot/test_scheduler.py')
g = load('registration_scoped_guard', HERE/'guard.py')
REAL_INVENTORY = s.inventory
SCHEDULER_SHA = '6f86204fdb510a9f3d850792891fc9902301ad68b5a67688080d0ac888c3cad9'


class GuardTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.store = Path(self.temp.name); self.project = self.store/'project'; self.project.mkdir()
        # Isolated queue ignores unrelated Godot inventory; only Python starts.
        self.mock = patch.object(s, 'inventory', lambda pid=None: REAL_INVENTORY(pid) if pid else [])
        self.mock.start()
        self.lease = s.Lease('headless', self.project, _store=self.store); self.lease.__enter__()
        self.command = [sys.executable, '-B', '-c', 'import time; time.sleep(30)', '--headless', '--path', str(self.project)]
        self.child = subprocess.Popen(self.command, creationflags=subprocess.CREATE_NO_WINDOW)
        row = REAL_INVENTORY(self.child.pid)[0]
        self.assertEqual(row['parent_pid'], os.getpid())
        self.row = {'ProcessId':row['pid'], 'ParentProcessId':row['parent_pid'], 'CreationFiletime':row['creation_filetime'],
                    'Name':row['name'], 'ExecutablePath':row['executable'], 'CommandLine':row['command_line'], 'MainWindowTitle':''}
        self.schedule = {name:getattr(s,name) for name in ('identity','alive','canonical')}
        self.schedule['STORE'] = self.store
        self.ns = {'SCHEDULE':self.schedule, 'ENGINE':Path(row['executable']), 'ACTIVE_MODE':'graphical',
                   'EDITOR_COMMAND':'unused editor', 'EDITOR_TITLE':'unused editor',
                   'MANAGER_EXE':self.store/'unused.exe', 'MANAGER_COMMAND':'unused', 'MANAGER_TITLE':'unused'}
        self.guard = g.RegistrationGuard(self.ns, lambda:time.monotonic()+5, wait_seconds=1.5)
        # Command/executable/parent are immutable from actual CIM. Each refresh
        # validates the still-live native creation identity; no engine evidence.
        self.guard.inventory = lambda timeout=2:[dict(self.row)] if s.identity(self.child.pid) else []
        self.threads = []

    def tearDown(self):
        for thread in self.threads: thread.join(4)
        if self.child.poll() is None: self.child.terminate(); self.child.wait(5)
        self.lease.__exit__(None,None,None)
        self.mock.stop(); self.temp.cleanup()

    def publish(self):
        # Use the real registration path: CIM, parent identity, exact command,
        # affinity assignment and atomic registry publication are all exercised.
        return self.lease.register_child(self.child)

    def delayed(self, callback, delay=.7):
        def work():
            until=time.monotonic()+2
            while not self.guard.events and time.monotonic()<until: time.sleep(.005)
            time.sleep(delay); callback()
        thread=threading.Thread(target=work); thread.start(); self.threads.append(thread)

    def fail(self, text=None):
        with self.assertRaisesRegex(RuntimeError,text or 'REGISTRATION_GUARD'):
            self.guard.classify([self.row])

    def test_actual_delayed_registration(self):
        self.guard.wait_seconds=4
        self.delayed(self.publish)
        started=time.monotonic(); self.assertEqual(self.guard.classify([self.row]),{'editor':0,'manager':0,'owned':0})
        self.assertGreater(time.monotonic()-started,.7)
        self.assertEqual(self.guard.events[0]['status'],'REGISTERED')
        with s.state_lock(self.store) as state:
            registered=state['active'][0]['children'][0]
        self.assertEqual(registered['pid'],self.child.pid)
        self.assertEqual(registered['creation_filetime'],self.row['CreationFiletime'])
        self.assertEqual(registered['logical_cpu_limit'],2)

    def test_no_registration_expires(self):
        self.guard.wait_seconds=.3
        start=time.monotonic(); self.fail('deadline expired')
        self.assertLess(time.monotonic()-start,.6)
        self.assertIsNone(self.child.poll())
        self.assertEqual(self.guard.events[0]['status'],'WAITING_FOR_REGISTRATION')

    def test_original_watchdog_never_renewed(self):
        end=time.monotonic()+.18; self.guard.deadline=lambda:end
        start=time.monotonic(); self.fail('deadline expired')
        self.assertLess(time.monotonic()-start,.4)

    def test_unknown_without_issued_lease_rejected_immediately(self):
        with s.state_lock(self.store) as state: state['active']=[]
        self.fail('no exact issued'); self.assertFalse(self.guard.events)

    def test_reused_parent_identity_rejected(self):
        with s.state_lock(self.store) as state: state['active'][0]['owner']['creation_filetime']='1'
        self.fail('no exact issued'); self.assertFalse(self.guard.events)

    def test_reused_child_creation_identity_rejected(self):
        self.row['CreationFiletime']='1'
        self.fail('process creation identity changed'); self.assertFalse(self.guard.events)

    def test_pending_parent_identity_drift_rejected(self):
        original=self.schedule['alive']; owner=self.lease.request['owner']; changed=threading.Event()
        self.schedule['alive']=lambda value: False if changed.is_set() and value==owner else original(value)
        self.delayed(changed.set,delay=.1)
        self.fail('awaited parent identity changed')

    def test_pending_child_exit_is_not_registration(self):
        self.delayed(lambda:self.child.terminate(),delay=.1)
        self.fail('awaited child exited')

    def test_wrong_project_cannot_wait(self):
        args=list(self.command); args[-1]=str(self.store/'other')
        self.row['CommandLine']=subprocess.list2cmdline(args)
        self.fail('no exact issued'); self.assertFalse(self.guard.events)

    def test_perf_never_waits_or_accepts_foreign_registered_child(self):
        self.ns['ACTIVE_MODE']='perf'
        self.fail('no functional grace'); self.assertFalse(self.guard.events)
        self.publish(); self.fail('no functional grace')

    def test_import_requires_write_lease(self):
        args=list(self.command); args.extend(['--editor','--import'])
        self.row['CommandLine']=subprocess.list2cmdline(args)
        self.fail('requires write lease')


if __name__=='__main__':
    start=time.monotonic()
    with (HERE/'CPU_TESTS.log').open('w',encoding='utf-8') as log:
        result=unittest.TextTestRunner(stream=log,verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(GuardTests))
    sha=lambda path:hashlib.sha256(path.read_bytes()).hexdigest()
    report={'passed':result.wasSuccessful(),'tests':result.testsRun,'errors':len(result.errors),'failures':len(result.failures),
            'elapsed_seconds':time.monotonic()-start,'guard_sha256':sha(HERE/'guard.py'),'test_sha256':sha(HERE/'test_guard.py'),
            'scheduler_sha256':sha(ROOT/'tools/godot/test_scheduler.py'),'scheduler_unchanged':sha(ROOT/'tools/godot/test_scheduler.py')==SCHEDULER_SHA,
            'actual_python_child':True,'actual_private_lease_and_register_child':True,'godot_started':False,'gameplay_proven':False}
    (HERE/'CPU_RESULT.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(report)); raise SystemExit(0 if report['passed'] and report['scheduler_unchanged'] else 1)
