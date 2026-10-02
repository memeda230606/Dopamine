#!/usr/bin/env python3
"""Test root SSH command execution and an isolated SFTP file roundtrip over USB."""
import argparse, hashlib, json, os, socket, subprocess, tempfile, time, uuid
from pathlib import Path
p=argparse.ArgumentParser()
p.add_argument('--device', default='00008110-001A6D993A28401E')
p.add_argument('--key', type=Path, required=True)
p.add_argument('--host-key', type=Path, required=True, help='Public host key exported by ResearchLab over USB')
p.add_argument('--output', type=Path, required=True)
p.add_argument('--local-port', type=int, default=22222)
a=p.parse_args()
result={'transport':'USB loopback','port':a.local_port}
forward=subprocess.Popen(['iproxy','-u',a.device,'-s','127.0.0.1',f'{a.local_port}:22222'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
remote='/var/jb/var/root/ResearchLab/ssh-probe-'+uuid.uuid4().hex
try:
    with tempfile.TemporaryDirectory(prefix='researchlab-ssh-') as tmp:
        work=Path(tmp);known=work/'known_hosts'
        key=a.host_key.read_text().strip().split()
        if len(key)<2 or key[0]!='ssh-ed25519':raise ValueError('Unexpected SSH host key')
        known.write_text(f'[127.0.0.1]:{a.local_port} {key[0]} {key[1]}\n')
        options=['-i',str(a.key.resolve()),'-o','BatchMode=yes','-o','IdentitiesOnly=yes','-o','StrictHostKeyChecking=yes',
                 '-o',f'UserKnownHostsFile={known}','-o','ConnectTimeout=8']
        for _ in range(30):
            if forward.poll() is not None:raise RuntimeError('USB forwarder could not bind local port')
            try:
                with socket.create_connection(('127.0.0.1',a.local_port),.2):break
            except OSError:time.sleep(.1)
        command=subprocess.run(['ssh','-p',str(a.local_port),*options,'root@127.0.0.1','/var/jb/usr/bin/id -u'],capture_output=True,text=True,timeout=20)
        result['root_command']={'exit_code':command.returncode,'output':command.stdout.strip(),'error':command.stderr.strip()}
        if command.returncode or command.stdout.strip()!='0':raise RuntimeError('SSH root identity check failed')
        original=os.urandom(128)+b'ResearchLab SFTP roundtrip\n';(work/'input.bin').write_bytes(original)
        batch=work/'batch.txt';batch.write_text(f'put {work}/input.bin {remote}\nget {remote} {work}/output.bin\nrm {remote}\n')
        transfer=subprocess.run(['sftp','-P',str(a.local_port),*options,'-b',str(batch),'root@127.0.0.1'],capture_output=True,text=True,timeout=25)
        downloaded=(work/'output.bin').read_bytes() if (work/'output.bin').exists() else b''
        result['sftp']={'exit_code':transfer.returncode,'roundtrip':downloaded==original,'cleanup_completed':transfer.returncode==0,
                        'sha256':hashlib.sha256(original).hexdigest(),'error':transfer.stderr.strip()}
        if transfer.returncode:
            batch.write_text(f'-rm {remote}\n')
            subprocess.run(['sftp','-P',str(a.local_port),*options,'-b',str(batch),'root@127.0.0.1'],capture_output=True,timeout=15)
        result['passed']=transfer.returncode==0 and downloaded==original
except Exception as e:
    result['passed']=False;result['error']=str(e)
finally:
    forward.terminate()
    try:forward.wait(timeout=3)
    except subprocess.TimeoutExpired:forward.kill();forward.wait()
a.output.parent.mkdir(parents=True,exist_ok=True)
a.output.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(result,ensure_ascii=False,indent=2))
raise SystemExit(0 if result.get('passed') else 1)
