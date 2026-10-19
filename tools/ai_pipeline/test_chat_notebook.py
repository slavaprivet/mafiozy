from pathlib import Path
import tempfile
import unittest

import chat_notebook as n
import pipeline as p


class NotebookTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.folder=Path(self.tmp.name)
        self.data={'thread':{'id':'test-chat','kind':'chatgpt','title':'Test','preview':'never copy preview'},
                   'turns':[{'items':[{'type':'userMessage','text':'never copy original context'},
                                      {'type':'agentMessage','id':'answer-1','text':'short result'}]}]}

    def test_only_agent_content_archived(self):
        result=n.archive(self.data,self.folder)
        self.assertEqual(result['saved_replies'],1)
        texts='\n'.join(f.read_text(encoding='utf-8') for f in self.folder.rglob('*') if f.is_file())
        self.assertNotIn('never copy',texts)
        self.assertIn('short result',texts)

    def test_repeated_read_does_not_duplicate(self):
        n.archive(self.data,self.folder)
        self.assertEqual(n.archive(self.data,self.folder)['added'],0)

    def test_partial_response_is_not_full_report(self):
        item=self.data['turns'][0]['items'][1]
        item['truncated']=True
        receipt=n.archive(self.data,self.folder)['receipts'][0]
        self.assertTrue(receipt['partial'])
        self.assertEqual(receipt['format'],'partial_text')
        item['truncated']=False
        result=n.archive(self.data,self.folder)
        self.assertEqual(result['saved_replies'],1)
        self.assertFalse(result['receipts'][0]['partial'])

    def test_stdout_receipt_is_bounded(self):
        self.data['turns'][0]['items'][1]['text']='a'*20000
        receipt=n.archive(self.data,self.folder)['receipts'][0]
        self.assertEqual(receipt['characters'],20000)
        self.assertLessEqual(len(receipt['summary']),700)

    def test_reject_path_and_secrets(self):
        self.data['thread']['id']='../../escape'
        with self.assertRaises(p.Rejected): n.archive(self.data,self.folder)
        self.data['thread']['id']='test-chat'
        self.data['turns'][0]['items'][1]['text']='sk-'+'x'*30
        with self.assertRaises(p.Rejected): n.archive(self.data,self.folder)


if __name__=='__main__':
    unittest.main()
