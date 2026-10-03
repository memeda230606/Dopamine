#!/usr/bin/env python3
import argparse, json, threading, socket, subprocess, time
from pathlib import Path
import frida
p=argparse.ArgumentParser()
p.add_argument('--device', default='00008110-001A6D993A28401E')
p.add_argument('--local-port', type=int, default=27043)
p.add_argument('--output', type=Path, required=True)
a=p.parse_args()
result={'client_version':frida.__version__, 'target_identifier':'com.mmd.ResearchLab'}
done=threading.Event()
def message(m,data):
    if m['type']=='send': result['agent']=m['payload']
    else: result['error']=m
    done.set()
session=None
script=None
forward=None
try:
    forward=subprocess.Popen(['iproxy','-u',a.device,'-s','127.0.0.1',f'{a.local_port}:27043'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    for _ in range(30):
        if forward.poll() is not None:raise RuntimeError('USB forwarder failed')
        try:
            with socket.create_connection(('127.0.0.1',a.local_port),.2):break
        except OSError:time.sleep(.1)
    device=frida.get_device_manager().add_remote_device(f'127.0.0.1:{a.local_port}')
    access=device.query_system_parameters().get('access')
    result['access']=access
    if access != 'full': raise RuntimeError(f'Expected actual Frida Server, access={access!r}; jailed/Gadget fallback is not this test.')
    applications=[x for x in device.enumerate_applications() if x.identifier == result['target_identifier']]
    if len(applications) != 1 or not applications[0].pid: raise RuntimeError('Own ResearchLab app is not running')
    result['target_pid']=applications[0].pid
    session=device.attach(applications[0].pid)
    script=session.create_script(Path(__file__).with_name('probe.js').read_text())
    script.on('message',message);script.load()
    if not done.wait(15):result['error']='agent timeout'
except Exception as e:
    result['error']=f'{type(e).__name__}: {e}'
finally:
    if script:
        try:script.unload()
        except frida.InvalidOperationError:pass
    if session:
        try:session.detach()
        except frida.InvalidOperationError:pass
    if forward:
        forward.terminate()
        try:forward.wait(timeout=3)
        except subprocess.TimeoutExpired:forward.kill();forward.wait()
result['passed']=bool(result.get('agent',{}).get('passed'))
a.output.parent.mkdir(parents=True,exist_ok=True)
a.output.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(result,ensure_ascii=False,indent=2))
raise SystemExit(0 if result.get('agent',{}).get('passed') else 1)
