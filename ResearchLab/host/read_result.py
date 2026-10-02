#!/usr/bin/env python3
"""Reassemble ResearchLab os_log records exported with log show --style json."""
import argparse,base64,json
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('log',type=Path);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
result={};chunks={}
for record in json.loads(a.log.read_text()):
    message=record.get('eventMessage','')
    if '[RESEARCHLAB] ' in message:
        phase,body=message.split('[RESEARCHLAB] ',1)[1].split(' ',1)
        if phase=='launch':result={};chunks={}
        try:result[phase]=json.loads(body)
        except json.JSONDecodeError:result.setdefault('incomplete_records',[]).append(phase)
    elif '[RESEARCHLAB_CHUNK] ' in message:
        identifier,phase,position,part=message.split('[RESEARCHLAB_CHUNK] ',1)[1].split(' ',3)
        index,total=map(int,position.split('/'));entry=chunks.setdefault(identifier,{'phase':phase,'total':total,'parts':{}});entry['parts'][index]=part
        if len(entry['parts'])==total:
            value=base64.b64decode(''.join(entry['parts'][i] for i in range(total)))
            result[phase]=json.loads(value)
for c in chunks.values():
    if len(c['parts'])!=c['total']:result.setdefault('incomplete_records',[]).append(c['phase'])
a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(result,ensure_ascii=False,indent=2))
