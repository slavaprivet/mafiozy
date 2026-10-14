import copy
from datetime import date
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import urllib.error

import pipeline as p


class PipelineTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        p.git(self.root,'init','--quiet')
        (self.root/'a.mjs').write_text('export const value = 1;\n',encoding='utf-8')
        p.git(self.root,'add','a.mjs')
        p.git(self.root,'-c','user.name=Test','-c','user.email=test@example.invalid','commit','-qm','fixture')
        self.task = {'TASK_ID':'test-task','ROLE':'PERFORMANCE_ARCHITECTURE','GOAL':'Review value',
                     'SCOPE':'a','ALLOWED_FILES':['a.mjs'],'CONTEXT_FILES':['a.mjs'],
                     'CONSTRAINTS':['Keep behavior'],'ACCEPTANCE_CRITERIA':['Prove findings'],'CHECKS':[]}
        self.config = p.read_json(p.HERE/'config.json')
        self.config['pricing_checked_on'] = date.today().isoformat()
        self.package = p.collect(self.root,self.task,self.config)
        self.state = p.state_dir(self.root)
        self.report = p.mock_result(self.package)

    def approval(self, **changes):
        a = {'provider':'deepseek','model':self.config['model'],'snapshot_id':self.package['snapshot_id'],
             'allow_external_code':True,'expires_on':date.today().isoformat(),
             'task_usd':1,'period_usd':1,'max_calls':2}
        a.update(changes)
        p.save(self.state/'approval.json',a)

    def envelope(self, report=None):
        return {'choices':[{'finish_reason':'stop','message':{'content':json.dumps(report or self.report)}}],
                'usage':{'prompt_tokens':100,'completion_tokens':50}}

    def live(self, transport):
        with patch.dict(os.environ,{'DEEPSEEK_API_KEY':'test-only-not-a-real-provider-key'}):
            return p.live_result(self.state,self.package,self.config,transport)

    def test_dirty_snapshot_is_not_head(self):
        (self.root/'a.mjs').write_text('export const value = 2;\n',encoding='utf-8')
        changed = p.collect(self.root,self.task,self.config)
        self.assertEqual(changed['BASE_SHA'],self.package['BASE_SHA'])
        self.assertNotEqual(changed['snapshot_id'],self.package['snapshot_id'])
        self.assertIn('a.mjs',changed['selected_worktree_status'])

    def test_stale_source_rejected(self):
        (self.root/'a.mjs').write_text('changed')
        with self.assertRaisesRegex(p.Rejected,'STALE_FILES'): p.verify_current(self.root,self.package)

    def test_path_escape_and_sensitive_files(self):
        for name in ('../a.mjs','C:/a.mjs','/a.mjs','a\\b.mjs','.env','secrets.py','a/../a.mjs','nul.txt','a.mjs:stream','a.mjs.'):
            with self.subTest(name=name), self.assertRaises(p.Rejected): p.source_path(self.root,name)

    def test_symlink_or_hardlink_rejected(self):
        os.link(self.root/'a.mjs',self.root/'linked.mjs')
        with self.assertRaisesRegex(p.Rejected,'HARDLINK'): p.source_path(self.root,'linked.mjs')

    def test_secret_input_rejected_without_echo(self):
        secret = 'sk-' + 'a'*32
        (self.root/'a.mjs').write_text(secret)
        with self.assertRaises(p.Rejected) as result: p.collect(self.root,self.task,self.config)
        self.assertNotIn(secret,str(result.exception))

    def test_secret_output_rejected(self):
        self.report['HANDOFF'] = 'sk-' + 'b'*32
        with self.assertRaisesRegex(p.Rejected,'SECRET'): p.validate_report(self.report,self.package)

    def test_oversize_not_silently_truncated(self):
        self.config['max_context_bytes'] = 1
        with self.assertRaisesRegex(p.Rejected,'CONTEXT_TOO_LARGE'): p.collect(self.root,self.task,self.config)

    def test_mock_honest_no_calls(self):
        self.assertEqual(p.validate_report(self.report,self.package)['FINDINGS'],[])
        self.assertFalse((self.state/'ledger.json').exists())
        self.assertIn('MOCK',self.report['HANDOFF'])

    def test_report_schema_and_unperformed_tests(self):
        for mutation in ({'BASE_SHA':'wrong'},{'CHECKS_ACTUALLY_RUN':['npm test']},{'FILES_READ':['missing.mjs']}, {'ROLE':'wrong'},{'PATCH':[]},{'FINDINGS':[{}]}):
            bad = copy.deepcopy(self.report)
            bad.update(mutation)
            with self.subTest(mutation=mutation),self.assertRaises(p.Rejected): p.validate_report(bad,self.package)

    def test_extra_report_commands_rejected(self):
        self.report['RUN'] = 'arbitrary command'
        with self.assertRaisesRegex(p.Rejected,'FIELDS'): p.validate_report(self.report,self.package)

    def test_same_head_old_dirty_snapshot_report_rejected(self):
        (self.root/'a.mjs').write_text('export const value = 3;\n',encoding='utf-8')
        changed = p.collect(self.root,self.task,self.config)
        with self.assertRaisesRegex(p.Rejected,'SNAPSHOT'): p.validate_report(self.report,changed)

    def test_valid_patch_isolated_no_execution(self):
        self.report['PATCH'] = '--- a/a.mjs\n+++ b/a.mjs\n@@ -1 +1 @@\n-export const value = 1;\n+export const value = 2;\n'
        run = self.root/'review'
        run.mkdir()
        result = p.inspect_patch(self.package,self.report,run)
        self.assertFalse(result['executed_generated_code'])
        self.assertIn('value = 1',(self.root/'a.mjs').read_text())
        self.assertIn('value = 2',(run/'patch-review/a.mjs').read_text())

    def test_outside_scope_patch(self):
        for target in ('../a.mjs','.github/workflows/ci.yml','package.json','test_a.mjs'):
            diff = f'--- a/{target}\n+++ b/{target}\n@@ -1 +1 @@\n-a\n+b\n'
            with self.subTest(target=target),self.assertRaises(p.Rejected): p.patch_paths(diff,['a.mjs'])

    def test_rename_binary_and_mode_patches_rejected(self):
        for line in ('new file mode 100644','new mode 100755','rename from a.mjs','GIT binary patch'):
            with self.subTest(line=line),self.assertRaises(p.Rejected): p.patch_paths(line,['a.mjs'])

    def test_nonapplicable_patch_rejected(self):
        self.report['PATCH'] = '--- a/a.mjs\n+++ b/a.mjs\n@@ -1 +1 @@\n-not here\n+changed\n'
        run = self.root/'review'; run.mkdir()
        with self.assertRaisesRegex(p.Rejected,'NOT_APPLICABLE'): p.inspect_patch(self.package,self.report,run)

    def test_live_requires_approval_no_network(self):
        called = []
        with self.assertRaisesRegex(p.Rejected,'APPROVAL'): self.live(lambda *a: called.append(True))
        self.assertEqual(called,[])

    def test_live_requires_key(self):
        self.approval()
        with patch.dict(os.environ,{},clear=True),self.assertRaisesRegex(p.Rejected,'KEY_REQUIRED'):
            p.live_result(self.state,self.package,self.config)

    def test_success_usage_and_persistent_call_limit(self):
        self.approval()
        for _ in range(2): self.live(lambda *a:self.envelope())
        with self.assertRaisesRegex(p.Rejected,'CALL_LIMIT'): self.live(lambda *a:self.fail('network must not run'))
        entries = p.read_json(self.state/'ledger.json')
        self.assertEqual(len(entries),2)
        self.assertEqual(entries[0]['TOKEN_USAGE']['prompt_tokens'],100)
        self.assertGreater(entries[0]['reserved_usd'],0)

    def test_task_period_budget(self):
        for key in ('task_usd','period_usd'):
            self.approval(**{key:0.0000001})
            with self.subTest(key=key),self.assertRaisesRegex(p.Rejected,'BUDGET'): self.live(lambda *a:self.fail('network'))

    def test_approval_bound_to_snapshot_provider_expiry(self):
        for change in ({'snapshot_id':'other'},{'model':'other'},{'allow_external_code':False},{'expires_on':'2000-01-01'},{'max_calls':3}):
            self.approval(**change)
            with self.subTest(change=change),self.assertRaises(p.Rejected): self.live(lambda *a:self.fail('network'))

    def test_expired_prices_rejected(self):
        self.approval(); self.config['pricing_checked_on']='2020-01-01'
        with self.assertRaisesRegex(p.Rejected,'PRICING'): self.live(lambda *a:self.fail('network'))

    def test_timeout_auth_rate_limit_consume_one_attempt_no_retry(self):
        self.approval()
        for status in ('API_AUTH_FAILED','API_RATE_LIMIT'):
            def failure(*a): raise p.Rejected(status)
            with self.assertRaisesRegex(p.Rejected,status): self.live(failure)
        entries = p.read_json(self.state/'ledger.json')
        self.assertEqual([e['STATUS'] for e in entries],['API_AUTH_FAILED','API_RATE_LIMIT'])
        self.assertTrue(all(e['reserved_usd'] > 0 for e in entries))

    def test_timeout_ledger_survives(self):
        self.approval()
        def failure(*a): raise p.Rejected('API_TIMEOUT_OR_NETWORK_ERROR')
        with self.assertRaises(p.Rejected): self.live(failure)
        self.assertEqual(len(p.read_json(self.state/'ledger.json')),1)

    def test_invalid_and_truncated_response_not_retried(self):
        self.approval()
        invalid=self.envelope(); invalid['choices'][0]['message']['content']='not json'
        with self.assertRaisesRegex(p.Rejected,'INVALID_API_RESPONSE'): self.live(lambda *a:invalid)
        truncated=self.envelope(); truncated['choices'][0]['finish_reason']='length'
        with self.assertRaisesRegex(p.Rejected,'INCOMPLETE'): self.live(lambda *a:truncated)
        self.assertEqual(len(p.read_json(self.state/'ledger.json')),2)

    def test_parallel_lock_rejects_second_process(self):
        with p.lock(self.state):
            with self.assertRaisesRegex(p.Rejected,'BUSY'):
                with p.lock(self.state): pass

    def test_http_maps_errors_without_body_leak(self):
        for error, expected in ((urllib.error.HTTPError(p.ENDPOINT,401,'secret',{},None),'AUTH'),
                                (urllib.error.HTTPError(p.ENDPOINT,429,'secret',{},None),'RATE'),
                                (TimeoutError('private'), 'TIMEOUT')):
            with patch('urllib.request.OpenerDirector.open',side_effect=error),self.subTest(expected=expected):
                with self.assertRaisesRegex(p.Rejected,expected): p.http_call({},'fake',1)

    def test_redirect_blocked(self):
        with self.assertRaisesRegex(p.Rejected,'REDIRECT'):
            p.NoRedirect().redirect_request(None,None,302,'',{},'https://elsewhere.invalid')

    def test_env_excludes_provider_and_interpreter_injection(self):
        with patch.dict(os.environ,{'DEEPSEEK_API_KEY':'fake','NODE_OPTIONS':'bad','GIT_CONFIG_COUNT':'1'}):
            for key in ('DEEPSEEK_API_KEY','NODE_OPTIONS','GIT_CONFIG_COUNT'):
                self.assertNotIn(key,p.clean_env())


if __name__ == '__main__':
    unittest.main()
