#!/usr/bin/env python3
"""Build standalone tweak packages and the separate test app; never installs."""
import sys
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT.parent/'RuntimeClient'))
from build import configure
OUT = ROOT / 'build'
APP_BUILD = '3'
PROJECTS = [('LoadProbe', 'MMDLabLoad'), ('MethodProbe', 'MMDLabMethod'),
            ('UIProbe', 'MMDLabUI'), ('FileProbe', 'MMDLabFile'),
            ('NotificationProbe', 'MMDLabNotification')]


def run(args, **kwargs):
    subprocess.run([str(x) for x in args], check=True, **kwargs)


def build(simulator=False):
    theos = Path(os.environ.get('THEOS', ROOT.parent / '.build/tools/theos')).resolve()
    ldid = Path(os.environ.get('LDID', ROOT.parent / '.build/tools/ldid/ldid')).resolve()
    if not (theos / 'makefiles/common.mk').exists():
        raise SystemExit('Set THEOS to your existing Theos installation.')
    OUT.mkdir(exist_ok=True)
    logs = OUT / 'logs'; logs.mkdir(exist_ok=True)
    sdkname = 'iphonesimulator' if simulator else 'iphoneos'
    sdk = subprocess.check_output(['xcrun', '--sdk', sdkname, '--show-sdk-path'], text=True).strip()
    target = 'arm64-apple-ios15.0-simulator' if simulator else 'arm64-apple-ios15.0'
    flags = ['xcrun', 'clang', '-target', target, '-isysroot', sdk,
             '-fobjc-arc', '-fblocks', '-framework', 'Foundation', '-framework', 'UIKit']
    variant = OUT / ('simulator' if simulator else 'device'); variant.mkdir(exist_ok=True)
    manifest = {'format': 1, 'plugins': []}
    env = os.environ.copy()
    env.update(THEOS=str(theos), TARGET_CODESIGN_FLAGS='-Cadhoc -S')
    env['PATH'] = str(ldid.parent) + ':/opt/homebrew/bin:' + env.get('PATH', '')
    package_dir = OUT / 'packages'; package_dir.mkdir(exist_ok=True)
    for project, name in PROJECTS:
        source = ROOT / project
        if simulator:
            generated = variant / (name + '.m')
            generated.write_bytes(subprocess.check_output(['perl', str(theos / 'vendor/logos/bin/logos.pl'),
                '-c', 'generator=internal', str(source / 'Tweak.x')]))
            binary = variant / (name + '.dylib')
            run(flags + ['-dynamiclib', str(generated), '-o', str(binary)])
            run(['codesign', '--force', '--sign', '-', binary], capture_output=True)
        else:
            with (logs / (project + '.log')).open('w') as log:
                run(['gmake', '-C', source, 'package', 'FINALPACKAGE=1', 'PACKAGE_VERSION=1.0.0', '-j4'],
                    env=env, stdout=log, stderr=subprocess.STDOUT)
            binary = source / '.theos/_/var/jb/Library/MobileSubstrate/DynamicLibraries' / (name + '.dylib')
            for package in (source / 'packages').glob('*.deb'):
                shutil.copy2(package, package_dir / package.name)
        data = binary.read_bytes()
        manifest['plugins'].append({'project': project, 'name': name,
            'sha256': hashlib.sha256(data).hexdigest(), 'binary': base64.b64encode(data).decode()})
        print('Built', project, 'simulator' if simulator else 'rootless .deb', flush=True)
    app = variant / 'PluginLab.app'; app.mkdir(exist_ok=True)
    (app / 'plugins.json').write_text(json.dumps(manifest))
    info = {'CFBundleIdentifier': 'com.mmd.PluginLab', 'CFBundleExecutable': 'PluginLab',
        'CFBundlePackageType': 'APPL', 'CFBundleName': 'PluginLab', 'CFBundleDisplayName': '插件实验室',
        'CFBundleVersion': APP_BUILD, 'CFBundleShortVersionString': '1.0.0', 'MinimumOSVersion': '15.0',
        'UIDeviceFamily': [1, 2], 'UILaunchScreen': {}, 'UISupportedInterfaceOrientations': ['UIInterfaceOrientationPortrait'],
        'UIFileSharingEnabled': True, 'LSSupportsOpeningDocumentsInPlace': True}
    (app / 'Info.plist').write_bytes(plistlib.dumps(info))
    with (logs / (sdkname + '-app.log')).open('w') as log:
        run(flags + configure(app) + [ROOT / 'App/main.m', '-o', app / 'PluginLab'], stdout=log, stderr=subprocess.STDOUT)
    if simulator:
        run(['codesign', '--force', '--sign', '-', app], capture_output=True)
    else:
        run(['codesign', '--force', '--sign', '-', '--entitlements', ROOT / 'App/PluginLab.entitlements', app], capture_output=True)
        run(['codesign', '--verify', '--strict', app], capture_output=True)
        ipa = OUT / f'PluginLab-1.0.0-build{APP_BUILD}.ipa'
        with zipfile.ZipFile(ipa, 'w', compression=zipfile.ZIP_DEFLATED) as z:
            for file in app.rglob('*'):
                if file.is_file(): z.write(file, 'Payload/PluginLab.app/' + str(file.relative_to(app)))
        assert len(list(package_dir.glob('*.deb'))) == 5
        metadata = {'app': ipa.name, 'sha256': hashlib.sha256(ipa.read_bytes()).hexdigest(),
            'plugins': [{k: v for k, v in p.items() if k != 'binary'} for p in manifest['plugins']],
            'loader_mode': 'explicit-app-scoped-dlopen', 'global_automatic_injection_tested': False,
            'device_test': 'pending', 'simulator_test': 'pending'}
        (OUT / 'build-info.json').write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + '\n')
    print(app, flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--simulator', action='store_true')
    build(parser.parse_args().simulator)
