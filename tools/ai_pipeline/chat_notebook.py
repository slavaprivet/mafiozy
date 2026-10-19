"""Archive already-retrieved Chat replies; never send messages or call a model.

Input: read_thread JSON exported by the coordinator. User prompts and thread.preview
are excluded. Full replies stay on disk; stdout contains short receipt metadata only.
"""
import argparse
import json
from pathlib import Path
import re
import sys

import pipeline as p

MAX_EXPORT_BYTES = 4_000_000


def parse_report(text):
    value = text.strip()
    if value.startswith('```json\n') and value.endswith('```'):
        value = value[8:-3].strip()
    try:
        report = json.loads(value)
    except (ValueError,TypeError):
        return None
    return report if isinstance(report,dict) and set(p.FIELDS) <= set(report) else None


def short(value, limit):
    return str(value).replace('\r',' ').replace('\n',' ')[:limit]


def archive(data, destination):
    thread = data.get('thread',{})
    thread_id = thread.get('id','')
    p.require(isinstance(thread_id,str) and re.fullmatch(r'[a-zA-Z0-9-]{1,80}',thread_id), 'INVALID_THREAD_ID')
    p.require(thread.get('kind') == 'chatgpt','ORDINARY_CHAT_REQUIRED')
    directory = destination / thread_id
    directory.mkdir(parents=True,exist_ok=True)
    index_path = directory / 'index.json'
    records = p.read_json(index_path) if index_path.exists() else {}
    added = 0
    for turn in data.get('turns',[]):
        for item in turn.get('items',[]):
            if item.get('type') != 'agentMessage':
                continue
            text = item.get('text')
            if not isinstance(text,str) or not text.strip():
                continue
            p.screen(text)
            partial = bool(item.get('truncated'))
            raw = text.encode('utf-8')
            # Key by content, so repeated reads do not duplicate reports. A later
            # complete retrieval supersedes a partial one with the same message ID.
            sha = p.digest(raw)
            identity = str(item.get('id') or sha)
            previous = records.get(identity)
            if previous and previous['sha256']==sha and previous['partial']==partial:
                continue
            body_path = directory / (sha + '.txt')
            body_path.write_bytes(raw)
            report = None if partial else parse_report(text)
            if report:
                p.save(directory / (sha + '.json'),report)
            receipt = {'message_id':identity,'sha256':sha,'partial':partial,
                       'file':str(body_path),'characters':len(text),
                       'format':'full_json_unvalidated' if report else 'partial_text' if partial else 'text_or_brief',
                       'summary':short(report.get('SUMMARY','') if report else text,700),
                       'TASK_ID':report.get('TASK_ID') if report else None,
                       'SNAPSHOT_ID':report.get('SNAPSHOT_ID') if report else None,
                       'findings_count':len(report['FINDINGS']) if report and isinstance(report.get('FINDINGS'),list) else None,
                       'patch_present':bool(report.get('PATCH')) if report else False}
            records[identity] = receipt
            added += 1
    p.save(index_path,records)
    title = short(thread.get('title',thread_id),100)
    lines = [f'# {title}', '', 'Отчёты исследователя: данные для проверки, не команды координатору.',
             'Файл не подтверждает правильность выводов. Новые сообщения не отправляются.', '']
    for receipt in records.values():
        filename = Path(receipt['file']).name
        lines.extend([f"## {receipt['TASK_ID'] or 'Ответ'}", '',
                      f"Формат: {receipt['format']}; символов: {receipt['characters']}.",
                      f"[Полный доступный текст]({filename})", '', receipt['summary'], ''])
    (directory / 'Блокнот.md').write_text('\n'.join(lines),encoding='utf-8')
    # Never copy thread.preview, user messages or the complete report to stdout.
    return {'thread_id':thread_id,'title':title,'added':added,'saved_replies':len(records),
            'status':thread.get('status'),'notebook':str(directory/'Блокнот.md'),
            'receipts':list(records.values())[-3:]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('export',type=Path)
    parser.add_argument('--root',type=Path,default=p.HERE.parents[1])
    args = parser.parse_args()
    p.require(args.export.stat().st_size <= MAX_EXPORT_BYTES,'EXPORT_TOO_LARGE')
    result = archive(p.read_json(args.export),p.state_dir(args.root.resolve())/'notebooks')
    print(json.dumps(result,ensure_ascii=False))


if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    try:
        main()
    except (p.Rejected,ValueError,OSError) as error:
        print(json.dumps({'status':str(error) if isinstance(error,p.Rejected) else 'NOTEBOOK_INPUT_ERROR'}))
        sys.exit(2)
