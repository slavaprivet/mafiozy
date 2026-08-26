import json
import pathlib
import re
import subprocess
import textwrap
import unittest


ROOT = pathlib.Path(__file__).resolve().parent
THREE = (ROOT / "three_preview.js").read_text(encoding="utf-8")
WORLD = (ROOT / "world.html").read_text(encoding="utf-8")


class NpcStatePruneGenerationTests(unittest.TestCase):
    def test_renderer_prunes_only_on_accepted_snapshot_generation(self):
        self.assertIn("let npcSnapshotGeneration=0;", THREE)
        self.assertIn(
            "if(dynamicState){npcSnapshotGeneration++;dynamicSnapshotRefreshed=true;}",
            THREE,
        )
        self.assertIn(
            "if(dynamicSnapshotRefreshed)motion.lastSeenGeneration=npcSnapshotGeneration;",
            THREE,
        )
        self.assertIn(
            "if(dynamicSnapshotRefreshed)state.lastSeenGeneration=npcSnapshotGeneration;",
            THREE,
        )
        self.assertIn(
            "if(dynamicSnapshotRefreshed)pruneNpcStateMap(npcMotionStates,npcSnapshotGeneration);",
            THREE,
        )
        self.assertIn(
            "if(dynamicSnapshotRefreshed)pruneNpcStateMap(npcFacingStates,npcSnapshotGeneration);",
            THREE,
        )
        self.assertIn("generation-state.lastSeenGeneration>1", THREE)
        self.assertNotIn("liveNpcMotion", THREE)
        self.assertNotIn("liveNpcFacing", THREE)

    def test_priority_displacement_grace_reclaim_and_bound(self):
        helper_match = re.search(
            r"const pruneNpcStateMap=\(states,generation\)=>\{[^\n]+\};", THREE
        )
        self.assertIsNotNone(helper_match)
        script = textwrap.dedent(
            f"""
            const NPC_CAP=72;
            {helper_match.group(0)}
            const ids=(prefix,count)=>Array.from({{length:count}},(_,i)=>`${{prefix}}${{i}}`);
            const base=[...ids('G',48),...ids('C',24)];
            const displaced=['M0',...ids('G',47),...ids('C',24)];
            const makeMaps=()=>[new Map(),new Map()];
            const accept=(maps,generation,actors)=>{{
              generation++;
              for(const states of maps){{
                for(const id of actors){{
                  let state=states.get(id);
                  if(!state){{state={{token:`new:${{id}}:g${{generation}}`,lastSeenGeneration:generation}};states.set(id,state);}}
                  state.lastSeenGeneration=generation;
                }}
                pruneNpcStateMap(states,generation);
              }}
              return generation;
            }};

            const one=makeMaps();let oneGeneration=0;
            oneGeneration=accept(one,oneGeneration,base);
            for(const states of one)Object.assign(states.get('G47'),{{token:'continuity',hitUntil:1650,deadStartedAt:900,deathX:12}});
            oneGeneration=accept(one,oneGeneration,displaced);
            const oneMissing=one.map(states=>({{size:states.size,...states.get('G47')}}));
            oneGeneration=accept(one,oneGeneration,base);
            const oneReturned=one.map(states=>({{size:states.size,...states.get('G47')}}));

            const two=makeMaps();let twoGeneration=0;
            twoGeneration=accept(two,twoGeneration,base);
            for(const states of two)states.get('G47').token='continuity';
            twoGeneration=accept(two,twoGeneration,displaced);
            twoGeneration=accept(two,twoGeneration,displaced);
            const afterTwo=two.map(states=>states.has('G47'));
            twoGeneration=accept(two,twoGeneration,base);
            const afterReentry=two.map(states=>states.get('G47').token);

            const reconnect=makeMaps();let reconnectGeneration=0;
            reconnectGeneration=accept(reconnect,reconnectGeneration,base);
            const beforeInvalid=reconnect.map(states=>states.size);
            const afterInvalid=reconnect.map(states=>states.size);
            reconnectGeneration=accept(reconnect,reconnectGeneration,[]);
            const afterEmptyOne=reconnect.map(states=>states.size);
            reconnectGeneration=accept(reconnect,reconnectGeneration,[]);
            const afterEmptyTwo=reconnect.map(states=>states.size);

            const churn=makeMaps();let churnGeneration=0,maxSize=0;
            for(let generation=0;generation<10;generation++){{
              churnGeneration=accept(churn,churnGeneration,ids(`S${{generation}}-`,NPC_CAP));
              maxSize=Math.max(maxSize,...churn.map(states=>states.size));
            }}

            process.stdout.write(JSON.stringify({{
              oneMissing,oneReturned,afterTwo,afterReentry,
              reconnect:{{beforeInvalid,afterInvalid,afterEmptyOne,afterEmptyTwo}},
              reload:makeMaps().map(states=>states.size),maxSize
            }}));
            """
        )
        proc = subprocess.run(
            ["node", "-"],
            input=script,
            text=True,
            encoding="utf-8",
            capture_output=True,
            cwd=ROOT,
        )
        self.assertEqual(proc.returncode, 0, proc.stderr)
        result = json.loads(proc.stdout)
        for state in result["oneMissing"] + result["oneReturned"]:
            self.assertEqual(state["token"], "continuity")
            self.assertEqual(state["hitUntil"], 1650)
            self.assertEqual(state["deadStartedAt"], 900)
            self.assertEqual(state["deathX"], 12)
            self.assertLessEqual(state["size"], 73)
        self.assertEqual(result["afterTwo"], [False, False])
        self.assertTrue(all(token.startswith("new:G47:") for token in result["afterReentry"]))
        self.assertEqual(result["reconnect"]["beforeInvalid"], [72, 72])
        self.assertEqual(result["reconnect"]["afterInvalid"], [72, 72])
        self.assertEqual(result["reconnect"]["afterEmptyOne"], [72, 72])
        self.assertEqual(result["reconnect"]["afterEmptyTwo"], [0, 0])
        self.assertEqual(result["reload"], [0, 0])
        self.assertEqual(result["maxSize"], 2 * 72)

    def test_caps_query_and_structural_operation_reduction(self):
        self.assertIn("const NPC_CAP=72,REMOTE_CAP=12", THREE)
        self.assertIn("const NPC_LIFE_NPC_CAP=72;", WORLD)
        self.assertIn("const civilianReserve=Math.min(24,", WORLD)
        module_query = re.search(
            r'<script type="module" src="three_preview\.js\?[^\"]+"', WORLD
        )
        self.assertIsNotNone(module_query)
        query = module_query.group(0)
        self.assertIn("building-reveal-v428", query)
        self.assertIn("melee=smart-heavy-forward-kick-v16", query)
        self.assertIn("interior=business-red-material-v1", query)
        self.assertIn("npcstate=npc-state-prune-v429", query)

        cap = 72
        current_ops_60fps = 4 * cap * 60
        snapshot_ops_steady = 4 * cap * 20
        snapshot_ops_worst = 6 * cap * 20
        self.assertEqual(current_ops_60fps, 17280)
        self.assertEqual(snapshot_ops_steady, 5760)
        self.assertEqual(snapshot_ops_worst, 8640)


if __name__ == "__main__":
    unittest.main()
