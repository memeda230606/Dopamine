#!/usr/bin/env python3
"""Return measured host results to the matching device run, without starting tests."""
import argparse,base64,json,subprocess
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--device',required=True)
for name in ('prepare','ssh','frida','output'):p.add_argument('--'+name,type=Path,required=True)
a=p.parse_args();pending=json.loads(a.prepare.read_text())['prepare']
result={'run_id':pending['run_id'],'boot_uuid':pending['before']['boot_uuid'],
        'ssh_passed':json.loads(a.ssh.read_text()).get('passed') is True,
        'frida_passed':json.loads(a.frida.read_text()).get('passed') is True}
a.output.write_text(json.dumps(result,indent=2)+'\n')
encoded=base64.b64encode(json.dumps(result).encode()).decode()
subprocess.run(['pymobiledevice3','developer','dvt','launch','--udid',a.device,'--kill-existing',
                '--env','RESEARCHLAB_HOST_RESULT',encoded,'com.mmd.ResearchLab'],check=True,timeout=45)
