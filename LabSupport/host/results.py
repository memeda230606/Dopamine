"""Decode complete laboratory log records; never treat a partial chunk as a result."""
import base64, json

def decode(records, prefix):
    result={};chunks={};errors=[]
    for record in records:
        message=record.get('eventMessage','')
        try:
            if f'[{prefix}] ' in message:
                phase,body=message.split(f'[{prefix}] ',1)[1].split(' ',1)
                if phase=='launch':result={};chunks={};errors=[]
                result[phase]=json.loads(body)
            elif f'[{prefix}_CHUNK] ' in message:
                identifier,phase,position,part=message.split(f'[{prefix}_CHUNK] ',1)[1].split(' ',3)
                index,total=map(int,position.split('/'))
                if not 0<=index<total<=10000:raise ValueError('invalid chunk position')
                entry=chunks.setdefault(identifier,{'phase':phase,'total':total,'parts':{}})
                if entry['phase']!=phase or entry['total']!=total:raise ValueError('inconsistent chunks')
                if index in entry['parts'] and entry['parts'][index]!=part:raise ValueError('conflicting chunk')
                entry['parts'][index]=part
                if len(entry['parts'])==total:
                    result[phase]=json.loads(base64.b64decode(''.join(entry['parts'][i] for i in range(total)),validate=True))
        except (ValueError,KeyError,TypeError) as error:errors.append(str(error))
    incomplete=[c['phase'] for c in chunks.values() if len(c['parts'])!=c['total']]
    if incomplete:result['incomplete_records']=incomplete
    if errors:result['decode_errors']=errors
    return result
