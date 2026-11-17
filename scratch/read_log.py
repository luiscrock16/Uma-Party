import json

with open(r'C:\Users\User\.gemini\antigravity\brain\686f75d0-0f1f-4edc-80cc-f70e68f92af3\.system_generated\logs\transcript_full.jsonl', 'r', encoding='utf-8') as f:
    for i, line in enumerate(f):
        if 3630 <= i <= 3645:
            obj = json.loads(line)
            if 'tool_calls' in obj:
                for tc in obj['tool_calls']:
                    print('Step:', i, tc.get('name'))
                    if 'CommandLine' in tc.get('args', {}):
                        print(tc['args']['CommandLine'][:250])
                    if 'Path' in tc.get('args', {}):
                        print(tc['args']['Path'])
