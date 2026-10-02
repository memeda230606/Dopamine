#!/usr/bin/env python3
"""Build the isolated test host using cached, official runtime packages."""
import base64, hashlib, json, os, plistlib, re, shutil, subprocess, zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parent
CACHE=Path(os.environ.get('RESEARCH_ASSETS', ROOT.parent/'.build/research-assets'))
KEY=Path(os.environ.get('RESEARCH_CLIENT_PUBLIC_KEY', ROOT.parent/'.build/research-private/client_key.pub'))
OUT=ROOT/'build'; APP=OUT/'ResearchLab.app'; APP.mkdir(parents=True,exist_ok=True)
BOOT=CACHE/'bootstrap'
BIN='/var/jb/usr/local/lib/ResearchLab'
files=[
 (CACHE/'frida/var/jb/usr/sbin/frida-server','/var/jb/usr/sbin/frida-server',True),
 (CACHE/'frida/var/jb/usr/lib/frida/frida-agent.dylib','/var/jb/usr/lib/frida/frida-agent.dylib',True),
 (CACHE/'rootless-openssh-server/var/jb/usr/sbin/sshd',BIN+'/sshd',True),
 (CACHE/'rootless-openssh-client/var/jb/usr/bin/ssh-keygen',BIN+'/ssh-keygen',True),
 (CACHE/'rootless-openssh-server/var/jb/etc/pam.d/sshd','/var/jb/etc/pam.d/sshd',False)]
# Follow only runtime dependencies present in this known bootstrap; never walk the phone filesystem.
seen=set(); dependencies=set()
def walk(file):
    if file in seen:return
    seen.add(file)
    output=subprocess.check_output(['otool','-L',str(file)],text=True)
    for line in output.splitlines()[1:]:
        path=line.strip().split(' (',1)[0]
        if path.startswith('@rpath/'):path='/var/jb/usr/lib/'+path[7:]
        if not path.startswith('/var/jb/'):continue
        candidate=BOOT/path.lstrip('/')
        if not candidate.exists():raise SystemExit(f'Missing cached bootstrap dependency: {path}')
        dependencies.add(path);walk(candidate)
for file,_,executable in files:
    if executable:walk(file)
for path in ['/var/jb/usr/bin/id','/var/jb/usr/bin/sh','/var/jb/usr/bin/bash','/var/jb/usr/bin/zsh',
             '/var/jb/usr/lib/pam/pam_unix.so','/var/jb/usr/lib/pam/pam_nologin.so','/var/jb/usr/lib/pam/pam_permit.so']:
    dependencies.add(path)
    # Resolve the phone's absolute sh symlink inside the cached bootstrap.
    local=BOOT/path.lstrip('/')
    if local.is_symlink():
        link=os.readlink(local)
        local=BOOT/link.lstrip('/') if link.startswith('/') else local.parent/link
    walk(local)
manifest={'files':[],'existing_dependencies':sorted(dependencies)}
for source,path,executable in files:
    data=source.read_bytes();manifest['files'].append({'path':path,'executable':executable,'sha256':hashlib.sha256(data).hexdigest(),'data':base64.b64encode(data).decode()})
(APP/'payload.json').write_text(json.dumps(manifest))
shutil.copyfile(KEY,APP/'client.pub')
info={'CFBundleIdentifier':'com.mmd.ResearchLab','CFBundleExecutable':'ResearchLab','CFBundlePackageType':'APPL',
      'CFBundleName':'ResearchLab','CFBundleDisplayName':'权限实验室','CFBundleVersion':'2','CFBundleShortVersionString':'1.0.0',
      'MinimumOSVersion':'15.0','UIDeviceFamily':[1,2],'UILaunchScreen':{},'UIFileSharingEnabled':True,
      'UISupportedInterfaceOrientations':['UIInterfaceOrientationPortrait']}
(APP/'Info.plist').write_bytes(plistlib.dumps(info))
sdk=subprocess.check_output(['xcrun','--sdk','iphoneos','--show-sdk-path'],text=True).strip()
with (OUT/'build.log').open('w') as log:
    subprocess.run(['xcrun','clang','-target','arm64-apple-ios15.0','-isysroot',sdk,'-fobjc-arc','-fblocks','-O0',
                    '-Wl,-export_dynamic','-framework','UIKit','-framework','Foundation',str(ROOT/'App/main.m'),'-o',str(APP/'ResearchLab')],stdout=log,stderr=subprocess.STDOUT,check=True)
subprocess.run(['codesign','--force','--sign','-','--entitlements',str(ROOT/'App/ResearchLab.entitlements'),str(APP)],check=True)
subprocess.run(['codesign','--verify','--strict',str(APP)],check=True)
ipa=OUT/'ResearchLab-1.0.0-build2.ipa'
with zipfile.ZipFile(ipa,'w',compression=zipfile.ZIP_DEFLATED) as z:
    for file in APP.rglob('*'):
        if file.is_file():z.write(file,'Payload/ResearchLab.app/'+str(file.relative_to(APP)))
metadata={'app':ipa.name,'sha256':hashlib.sha256(ipa.read_bytes()).hexdigest(),'bytes':ipa.stat().st_size,'build':'2',
 'frida_version':'17.0.7','openssh_version':'9.7p1-1','device_test':'pending_installation',
 'kernel_write_tested':False,'files':[{k:v for k,v in f.items() if k!='data'} for f in manifest['files']],
 'existing_dependencies':manifest['existing_dependencies']}
(OUT/'build-info.json').write_text(json.dumps(metadata,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({k:v for k,v in metadata.items() if k not in ['files','existing_dependencies']},indent=2))
