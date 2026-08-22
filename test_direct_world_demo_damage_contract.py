import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parent
WORLD = (ROOT / "world.html").read_text(encoding="utf-8")


class DirectWorldDemoDamageContractTests(unittest.TestCase):
    def test_direct_demo_never_bypasses_world_auth(self):
        self.assertIn("_LOCAL_PREVIEW && _DIRECT_WORLD_ENTRY && _UP.get('combatdemo') === '1'", WORLD)
        auth = WORLD.split("async function _worldTokenForSocket(){", 1)[1].split(
            "async function wsConnect()", 1
        )[0]
        self.assertIn("/auth/world/", auth)
        self.assertIn("_apiRequest", auth)
        self.assertNotIn("_DIRECT_WORLD_ENTRY", auth)
        self.assertNotIn("return 'owner'", auth)
        connect = WORLD.split("async function wsConnect() {", 1)[1].split(
            "function wsSend", 1
        )[0]
        self.assertIn("catch(e)", connect)
        self.assertIn("_DIRECT_WORLD_ENTRY&&!_LOCAL_PREVIEW", connect)
        self.assertIn("startDirectWorldCombatDemo();return;", connect)
        self.assertIn("if(_DIRECT_COMBAT_DEMO){startDirectWorldCombatDemo();return;}", connect)

    def test_demo_is_explicit_ephemeral_and_has_no_server_write(self):
        demo = WORLD.split("function startDirectWorldCombatDemo() {", 1)[1].split(
            "let _wsAuthPending", 1
        )[0]
        self.assertIn("worldAccess='demo-local-combat'", demo)
        self.assertIn("_setDirectWorldNetworkSilence(true)", demo)
        self.assertIn("_worldDirectCombatDemo=true", demo)
        self.assertNotIn("WebSocket", demo)
        self.assertNotIn("_apiRequest", demo)
        self.assertNotIn("fetch(", demo)

        silence = WORLD.split("function _setDirectWorldNetworkSilence(active){", 1)[1].split(
            "function resetDirectWorldCombatDemo", 1
        )[0]
        self.assertIn("window.fetch=()=>Promise.reject", silence)
        self.assertIn("window.fetch=_worldDirectDemoNativeFetch", silence)
        self.assertIn("p.getItem=()=>null", silence)
        self.assertIn("p.setItem=()=>{}", silence)

        self.assertIn('id="directDemoBadge"', WORLD)
        self.assertIn("урон и прогресс не сохраняются", WORLD)
        self.assertIn('id="directDemoReset"', WORLD)
        self.assertIn('id="directDemoHit"', WORLD)
        self.assertIn("if(_DIRECT_COMBAT_DEMO&&_qInt('demoqa',0)===1)", demo)
        self.assertIn("QP.uid='demo';QP.character_uid='';QP.account_uid='demo';QP.api=''", demo)

    def test_demo_damage_consumes_armor_then_body_and_can_kill(self):
        hurt = WORLD.split("function _hurtLocal(dmg, by", 1)[1].split(
            "let myKills", 1
        )[0]
        self.assertIn("if(!_LOCAL_PREVIEW&&!_worldDirectCombatDemo)return", hurt)
        self.assertIn("absorbed=Math.min", hurt)
        self.assertIn("bodyDamage-=absorbed", hurt)
        self.assertIn("myHp=Math.max(0,myHp-bodyDamage)", hurt)
        self.assertIn("dead:myHp<=0", hurt)
        self.assertIn("БРОНЯ СЛОМАНА", hurt)
        self.assertIn("bodyDamage} HP", hurt)
        self.assertIn("_renderDirectDemoArmorHud()", hurt)
        self.assertIn("if (myHp <= 0 && !myDead)", hurt)
        self.assertIn("myDeathLeft = _worldDirectCombatDemo ? 0 : 18", hurt)
        self.assertIn("if(_worldDirectCombatDemo)", hurt)
        self.assertIn("else _dispatchPlayerAmbulance()", hurt)
        self.assertNotIn("ws.send", hurt)
        self.assertNotIn("_apiRequest", hurt)
        self.assertIn("&& !_worldDirectCombatDemo", WORLD)

    def test_demo_reset_is_atomic_and_local(self):
        reset = WORLD.split("function resetDirectWorldCombatDemo(){", 1)[1].split(
            "function startDirectWorldCombatDemo", 1
        )[0]
        for expected in (
            "body:{current:bodyMax,max:bodyMax,dead:false}",
            "current:armorMax,max:armorMax",
            "myHp=bodyMax;myDead=false;_localDeath=false",
            "screenFlash=0;camShake=0;camKickX=0;camKickY=0",
            "_suppressedUntil=0",
            "impacts.length=0;floatTexts.length=0",
            "delete death.dataset.demo",
        ):
            self.assertIn(expected, reset)
        self.assertNotIn("fetch(", reset)
        self.assertNotIn("ws.send", reset)

    def test_demo_fallback_requires_explicit_auth_rejection(self):
        token = WORLD.split("async function _worldTokenForSocket(){", 1)[1].split(
            "async function wsConnect()", 1
        )[0]
        self.assertIn("e.status=r.status", token)
        connect = WORLD.split("async function wsConnect() {", 1)[1].split(
            "function wsSend", 1
        )[0]
        self.assertIn("e?.status===401||e?.status===403", connect)

    def test_authenticated_socket_disables_demo_state(self):
        opened = WORLD.split("socket.onopen = () => {", 1)[1].split(
            "socket.onmessage", 1
        )[0]
        self.assertIn("_worldDirectCombatDemo=false", opened)
        self.assertIn("_setDirectWorldNetworkSilence(false)", opened)
        self.assertIn("worldAccess='authenticated'", opened)
        self.assertIn("setConnecting(null)", opened)


if __name__ == "__main__":
    unittest.main()
