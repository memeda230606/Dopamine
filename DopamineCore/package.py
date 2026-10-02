#!/usr/bin/env python3
"""Package the already-built no-reboot app; does not install or publish."""
from pathlib import Path
import hashlib,json,os,plistlib,shutil,struct,subprocess,zipfile
root=Path(__file__).resolve().parent.parent
out=root/'.build/decoupling';stage=out/'package';app=stage/'Payload/Dopamine.app'
if stage.exists():shutil.rmtree(stage)
app.parent.mkdir(parents=True)
shutil.copytree(root/'Application/build/Build/Products/Debug-iphoneos/Dopamine.app',app,symlinks=True)
info=plistlib.loads((app/'Info.plist').read_bytes())
assert info['CFBundleVersion']=='4' and info['CFBundleShortVersionString']=='3.0.10'
ldid=os.environ.get('LDID',str(root/'.build/tools/ldid/ldid'))
subprocess.run([ldid,'-S'+str(root/'Application/Dopamine/Dopamine.entitlements'),str(app/'Dopamine')],check=True)
subprocess.run([ldid,'-s',str(app)],check=True)
binary=(app/'Dopamine').read_bytes()
assert all(symbol in binary for symbol in (b'DOCoreContext',b'DOAppCoreHost',b'DOCoreDiagnostics',b'[CORE_DIAGNOSTICS]',b'[NOREBOOT_TEST]'))
ent=plistlib.loads(subprocess.check_output([ldid,'-e',str(app/'Dopamine')]))
assert ent==plistlib.loads((root/'Application/Dopamine/Dopamine.entitlements').read_bytes())
assert binary[:4]==b'\xcf\xfa\xed\xfe'
pos=32;sig=None
for _ in range(struct.unpack_from('<I',binary,16)[0]):
 cmd,size=struct.unpack_from('<II',binary,pos)
 if cmd==0x1d:
  offset,length=struct.unpack_from('<II',binary,pos+8);sig=binary[offset:offset+length]
 pos+=size
assert sig and struct.unpack_from('>I',sig)[0]==0xfade0cc0
pages=[]
for n in range(struct.unpack_from('>I',sig,8)[0]):
 slot,offset=struct.unpack_from('>II',sig,12+8*n)
 if slot!=0 and not 0x1000<=slot<=0x1005:continue
 cd=sig[offset:];assert struct.unpack_from('>I',cd)[0]==0xfade0c02
 hash_offset,_,_,count,code_limit=struct.unpack_from('>IIIII',cd,16)
 hash_size,hash_type,_,page_exp=struct.unpack_from('BBBB',cd,36)
 alg={1:'sha1',2:'sha256',3:'sha256',4:'sha384'}[hash_type];page=1<<page_exp
 for i in range(count):
  expected=cd[hash_offset+i*hash_size:hash_offset+(i+1)*hash_size]
  assert hashlib.new(alg,binary[i*page:min((i+1)*page,code_limit)]).digest()[:hash_size]==expected
 pages.append({'algorithm':alg,'pages':count})
assert pages
with zipfile.ZipFile(root/'.build/downloads/Dopamine-3.0.10-noreboot-test-build3.ipa') as old:
 for name in ('basebin.tar','bootstrap_1800.tar.zst','bootstrap_1900.tar.zst','libjailbreak.dylib'):
  assert (app/name).read_bytes()==old.read('Payload/Dopamine.app/'+name),name
ipa=out/'Dopamine-3.0.10-core-build4.ipa'
with zipfile.ZipFile(ipa,'w',zipfile.ZIP_DEFLATED) as z:
 for file in sorted(stage.rglob('*')):
  if file.is_file():z.write(file,file.relative_to(stage))
with zipfile.ZipFile(ipa) as z:assert z.testzip() is None
meta={'filename':ipa.name,'version':'3.0.10','build':'4','bytes':ipa.stat().st_size,'sha256':hashlib.sha256(ipa.read_bytes()).hexdigest(),'source_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip(),'source_modified':True,'automatic_userspace_reboot':False,'main_code_directory_verified':pages,'main_entitlements_verified':True,'baseline_runtime_payload_unchanged':True,'device_test':'pending_installation','full_jailbreak_flow_test':'pending separate cold-boot validation'}
(out/'build-info.json').write_text(json.dumps(meta,indent=2)+'\n')
print(json.dumps(meta,indent=2))
