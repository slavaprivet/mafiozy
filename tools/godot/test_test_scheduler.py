"""CPU-only scheduler integration tests. No Godot executable is started."""
import importlib.util
import json
import multiprocessing as mp
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("scheduler", Path(__file__).with_name("test_scheduler.py"))
s = importlib.util.module_from_spec(spec); spec.loader.exec_module(s)
REAL_INVENTORY = s.inventory


def cpu_inventory(pid=None):
    return REAL_INVENTORY(pid) if pid else []


def child(project, duration=20):
    return subprocess.Popen([sys.executable, "-B", "-c", f"import time; time.sleep({duration})",
                             "--headless", "--path", str(project)], creationflags=subprocess.CREATE_NO_WINDOW)


def worker(store, project, name, events, duration):
    s.inventory = cpu_inventory
    with s.Lease("headless", project, wait_seconds=20, _store=store) as lease:
        process = child(project)
        row = lease.register_child(process)
        events.put(("start", name, time.monotonic(), row["affinity_mask"]))
        time.sleep(duration)
        process.terminate(); process.wait(5)
        events.put(("end", name, time.monotonic(), row["affinity_mask"]))


class SchedulerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.store = Path(self.temp.name)
        self.project = self.store / "project"; self.project.mkdir()
        self.mock = patch.object(s, "inventory", cpu_inventory); self.mock.start()

    def tearDown(self):
        self.mock.stop(); self.temp.cleanup()

    def request(self, mode="headless", access="read", ticket=1, project=None):
        return {"mode": mode, "access": access, "ticket": ticket, "project": s.canonical(project or self.project)}

    def test_slots_fifo_and_writer_fairness(self):
        a = self.request(); b = self.request(ticket=2); c = self.request(ticket=3)
        self.assertTrue(s.eligible(b, {"active": [a], "pending": [b]}, lambda _: False))
        self.assertFalse(s.eligible(c, {"active": [a,b], "pending": [c]}, lambda _: False))
        writer = self.request(access="write", ticket=2)
        self.assertFalse(s.eligible(c, {"active": [a], "pending": [writer,c]}, lambda _: False))
        self.assertFalse(s.eligible(writer, {"active": [a], "pending": [writer]}, lambda _: False))
        self.assertTrue(s.eligible(writer, {"active": [], "pending": [writer,c]}, lambda _: False))

    def test_graphical_and_perf_lanes(self):
        graphic = self.request("graphical")
        self.assertFalse(s.eligible(self.request("graphical",ticket=2), {"active":[graphic],"pending":[]},lambda _:False))
        self.assertTrue(s.eligible(self.request(ticket=2), {"active":[graphic],"pending":[]},lambda _:False))
        perf = self.request("perf",ticket=2)
        self.assertFalse(s.eligible(perf,{"active":[graphic],"pending":[perf]},lambda _:False))
        later = self.request(ticket=3)
        self.assertFalse(s.eligible(later,{"active":[graphic],"pending":[perf,later]},lambda _:False))
        self.assertTrue(s.eligible(later,{"active":[graphic],"pending":[perf,later]},lambda r:r["mode"]=="perf"))

    def test_blocked_writer_does_not_idle_an_unrelated_lane(self):
        for active_mode, waiting_mode in (("graphical", "headless"), ("headless", "graphical")):
            active = self.request(active_mode)
            writer = self.request(waiting_mode, access="write", ticket=2)
            unrelated = self.request(waiting_mode, ticket=3, project=self.store / "other")
            state = {"active": [active], "pending": [writer, unrelated]}
            self.assertTrue(s.eligible(unrelated, state, lambda _: False))
            self.assertFalse(s.eligible(self.request(waiting_mode, ticket=4), state, lambda _: False))
            # Once its project is available, the earlier writer wins its lane.
            self.assertFalse(s.eligible(unrelated, {"active": [], "pending": [writer, unrelated]}, lambda _: False))

    def test_exact_external_project_not_prefix_or_user_argument(self):
        project = self.store / "project with space"
        request = self.request(access="write", project=project)
        def editor(path):
            return {"name": "Godot.exe", "command_line": subprocess.list2cmdline(["Godot.exe", "--editor", "--path", str(path)]), "pid": 42}
        self.assertTrue(s.blocked(request, [editor(project)]))
        self.assertFalse(s.blocked(request, [editor(Path(str(project) + "-other"))]))
        row = editor(self.store / "other")
        row["command_line"] += " -- " + subprocess.list2cmdline(["--path", str(project)])
        self.assertFalse(s.blocked(request, [row]))
        self.assertEqual(s.command_project(editor(project)), s.canonical(project))
        with self.assertRaisesRegex(RuntimeError, "Relative"):
            s.blocked(request, [editor(Path("relative-project"))])

    def test_probe_reports_blocker_without_wait_or_new_ticket(self):
        game = {"name": "Godot.exe", "command_line": "Godot.exe --path C:\\UserGame", "pid": 42, "title": "User game"}
        with patch.object(s, "inventory", return_value=[game]):
            result = s.probe("perf", self.project, _store=self.store)
        self.assertFalse(result["eligible_snapshot"])
        self.assertEqual(result["reasons"][0]["code"], "perf_requires_idle_game")
        state = json.loads((self.store / "state.json").read_text())
        self.assertEqual(state["next_ticket"], 1)
        self.assertEqual(state["pending"], [])
        with patch.object(s, "inventory", return_value=[game]):
            self.assertTrue(s.probe("headless", self.project, _store=self.store)["eligible_snapshot"])

    def test_wait_records_duration_and_timeout_explains_lane(self):
        with s.Lease("graphical", self.project, _store=self.store) as lease:
            self.assertGreaterEqual(lease.request["queue_wait_seconds"], 0)
            with self.assertRaisesRegex((RuntimeError, TimeoutError), "lane_full"):
                with s.Lease("graphical", self.project, wait_seconds=.3, _store=self.store):
                    self.fail("second graphical lease admitted")

    def test_wait_budget_begins_at_enqueue_not_constructor(self):
        lease = s.Lease("headless", self.project, wait_seconds=.2, _store=self.store)
        time.sleep(.3)
        with lease:
            self.assertGreater(lease.request["deadline"], time.monotonic())
            self.assertAlmostEqual(lease.request["deadline"] - lease.request["queued_at"], .2)

    def test_user_game_blocks_perf_not_functional_editor_does_not_bypass_legacy(self):
        row={"name":"Godot_v4.7.2-stable_win64.exe", "command_line":'"C:\\Godot.exe" --path "C:\\UserGame"',"title":"Game"}
        self.assertTrue(s.blocked(self.request("perf"),[row]))
        self.assertFalse(s.blocked(self.request(),[row]))
        row["command_line"] += " --editor"
        self.assertTrue(s.is_editor(row)); self.assertFalse(s.stable_user_game(row))
        self.assertFalse(s.blocked(self.request("perf"),[row]))
        row["command_line"] += " --headless --import"
        self.assertTrue(s.blocked(self.request(),[row]))

    def test_identity_and_command_reuse_rejected(self):
        row={"pid":10,"creation_filetime":"123", "command_line":"x", "executable":str(self.project)}
        saved=dict(row, executable=s.canonical(self.project))
        self.assertTrue(s.same_child(row,saved))
        for key,value in [("creation_filetime","124"),("command_line","other"),("pid",11)]:
            self.assertFalse(s.same_child(dict(row,**{key:value}),saved))

    def test_actual_registered_child_affinity_status_and_cleanup(self):
        process = None
        with s.Lease("headless", self.project, _store=self.store) as lease:
            process=child(self.project); row=lease.register_child(process)
            self.assertLessEqual(row["logical_cpu_limit"],2)
            self.assertEqual(row["affinity_mask"].bit_count(),row["logical_cpu_limit"])
            with patch.object(s,"inventory",lambda pid=None:REAL_INVENTORY(process.pid)):
                result=s.status(_store=self.store)
            self.assertEqual(result["coexist_pids"],[process.pid])
            self.assertEqual(result["registered_children"][0]["executable_path"],s.canonical(sys.executable))
        self.assertIsNotNone(process.poll())
        self.assertEqual(s.status(_store=self.store)["active"],[])

    def test_invalid_child_lane_is_stopped_without_touching_other_child(self):
        other=child(self.project)
        try:
            with self.assertRaises(RuntimeError):
                with s.Lease("headless", self.project, _store=self.store) as lease:
                    invalid=subprocess.Popen([sys.executable,"-B","-c","import time;time.sleep(20)","--path",str(self.project)],creationflags=subprocess.CREATE_NO_WINDOW)
                    lease.register_child(invalid)
            self.assertIsNotNone(invalid.poll()); self.assertIsNone(other.poll())
        finally:
            other.terminate();other.wait(5)

    def test_bounded_queue_wait_and_failed_request_removed(self):
        with s.Lease("graphical",self.project,_store=self.store):
            start=time.monotonic()
            with self.assertRaises((RuntimeError,TimeoutError)):
                with s.Lease("graphical",self.project,wait_seconds=.3,_store=self.store):
                    self.fail("second graphical lease admitted")
            self.assertLess(time.monotonic()-start,2)
        self.assertEqual(s.status(_store=self.store)["pending"],[])

    def test_perf_contamination_is_an_exception_not_an_ignored_flag(self):
        game={"name":"Godot.exe","command_line":"Godot.exe --path C:\\UserGame","title":"Game"}
        with patch.object(s,"inventory",side_effect=[[],[game]]):
            with self.assertRaisesRegex(RuntimeError,"PERF_CONTAMINATED"):
                with s.Lease("perf",self.project,_store=self.store):
                    pass

    def test_real_processes_two_slots_overlap_third_waits_distinct_affinity(self):
        ctx=mp.get_context("spawn"); events=ctx.Queue(); processes=[]; data=[]
        try:
            for name in ("a","b","c"):
                proc=ctx.Process(target=worker,args=(str(self.store),str(self.project),name,events,4))
                proc.start(); processes.append(proc)
                if name=="a":data.append(events.get(timeout=15))
            while len(data)<6:data.append(events.get(timeout=30))
            for proc in processes:proc.join(10); self.assertEqual(proc.exitcode,0)
            ordered=sorted(data,key=lambda r:r[2]); active=0;maximum=0
            for event in ordered:
                active += 1 if event[0]=="start" else -1; maximum=max(maximum,active)
            self.assertEqual(maximum,2)
            starts=[e for e in ordered if e[0]=="start"]
            self.assertEqual(starts[0][1],"a")
            spans={name:{row[0]:row for row in data if row[1]==name} for name in ("a","b","c")}
            for i,left in enumerate(spans.values()):
                for right in list(spans.values())[i+1:]:
                    if max(left['start'][2],right['start'][2]) < min(left['end'][2],right['end'][2]):
                        self.assertEqual(left['start'][3]&right['start'][3],0,msg=repr(data))
            self.assertGreater(starts[2][2],min(e[2] for e in ordered if e[0]=="end"))
        finally:
            for proc in processes:
                if proc.is_alive():proc.terminate();proc.join(5)


if __name__ == "__main__":
    unittest.main()
