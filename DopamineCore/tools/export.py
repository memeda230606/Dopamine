#!/usr/bin/env python3
"""Export a relocatable arm64 iOS SDK, including runtime payload and licenses."""
import hashlib, json, plistlib, shutil, subprocess
from pathlib import Path
from project import ROOT, upstream
from runtime import copy_runtime

out = ROOT / '.build/sdk/DopamineSDK'
products = ROOT / '.build/sdk/DerivedData/Build/Products/Release-iphoneos'
if out.exists(): shutil.rmtree(out)
for name in ('Headers', 'Lib', 'Runtime'): (out / name).mkdir(parents=True)
for name in ('DOCore', 'DOEngine', 'DOCoreDiagnostics', 'DOCommandLine'):
    shutil.copy2(ROOT / 'DopamineCore' / (name + '.h'), out / 'Headers')
copy_runtime(out / 'Runtime', products)
for name in ('libDopamineCore.a', 'libzstd.o'): shutil.copy2(products / name, out / 'Lib')
for name in ('libgrabkernel2.a', 'libpartial.a'):
    shutil.copy2(ROOT / 'Application/Dopamine/Dependencies' / name, out / 'Lib')
for name in ('libjailbreak.dylib', 'libxpf.dylib', 'libchoma.dylib'):
    shutil.copy2(out / 'Runtime' / name, out / 'Lib')
shutil.copy2(ROOT / 'Application/Dopamine/Dopamine.entitlements', out / 'Host.entitlements')
manifest = plistlib.loads((out / 'Runtime/RuntimeManifest.plist').read_bytes())
objects = upstream()['objects']
target = next(o for o in objects.values() if o.get('isa') == 'PBXNativeTarget' and o.get('name') == 'Dopamine')
config = objects[objects[target['buildConfigurationList']]['buildConfigurations'][0]]
manifest.update(format=1, architecture='arm64', minimum_ios='15.0', runtime_version=config['buildSettings']['MARKETING_VERSION'],
                required_link_flags=['-ObjC', '-ljailbreak', '-lxpf', '-lchoma', '-lz', '-lcompression', '-lMobileGestalt'],
                system_frameworks=['UIKit', 'Foundation', 'CoreServices', 'IOKit', 'IOSurface', 'LocalAuthentication'])
shutil.copytree(ROOT / 'DopamineCore/Examples', out / 'Examples')
manifest['files_sha256'] = {str(p.relative_to(out)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(out.rglob('*')) if p.is_file()}
(out / 'SDKManifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
symbols = subprocess.check_output(['nm', '--defined-only', str(out / 'Lib/libDopamineCore.a')], text=True)
assert '_OBJC_CLASS_$_DOEngine' in symbols and '_DOHandleCommandLine' in symbols
assert '_OBJC_CLASS_$_DOPreferenceManager' not in symbols
print(json.dumps({'sdk': str(out), 'frameworks': len(manifest['exploit_metadata']), 'files': len(manifest['files_sha256'])}))
