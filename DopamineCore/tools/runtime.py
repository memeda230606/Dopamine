#!/usr/bin/env python3
"""Copy the same runtime payload and all exploit targets as upstream; omit original UI assets."""
import argparse
import hashlib
import json
import plistlib
import shutil
from pathlib import Path
from project import ROOT, upstream, components

def resource_files(project):
    objects = project['objects']; parents = {}
    for key, obj in objects.items():
        for child in obj.get('children', []): parents[child] = key
    def resolve(key):
        obj = objects[key]; tree = obj.get('sourceTree', '<group>')
        if tree == 'SOURCE_ROOT' or key not in parents: base = ROOT / 'Application'
        elif tree == '<group>': base = resolve(parents[key])
        else: raise ValueError('Unsupported runtime resource tree: ' + tree)
        return (base / obj.get('path', '')).resolve()
    original = next(o for o in objects.values() if o.get('isa') == 'PBXNativeTarget' and o.get('name') == 'Dopamine')
    result = {}
    for phase in original['buildPhases']:
        phase = objects[phase]
        if phase['isa'] != 'PBXResourcesBuildPhase': continue
        for entry in phase['files']:
            key = objects[entry]['fileRef']; obj = objects[key]
            if obj.get('name') == 'Localizable.strings':
                for child in obj['children']:
                    p = resolve(child); result[p.parent.name + '/' + p.name] = p
                continue
            if obj.get('name') == 'LaunchScreen.storyboard': continue
            path = resolve(key)
            if path.name in ['Assets.xcassets', 'LaunchScreen.storyboard', 'Themes.plist', 'Credits.plist']: continue
            result[path.name] = path
    for name in ['libjailbreak.dylib', 'libxpf.dylib', 'libchoma.dylib']:
        result[name] = ROOT / 'BaseBin/.build' / name
    return result

def copy_runtime(destination, products):
    project = upstream(); required = []; hashes = {}
    for name, source in resource_files(project).items():
        if not source.is_file(): raise FileNotFoundError(f'Build the upstream runtime dependency first: {source}')
        target = destination / name; target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
        required.append(name); hashes[name] = hashlib.sha256(target.read_bytes()).hexdigest()
    frameworks = {}
    for target in components(project).values():
        if target['productType'] != 'com.apple.product-type.framework': continue
        name = target['name'] + '.framework'; source = products / name
        target_dir = destination / 'Frameworks' / name
        if target_dir.exists(): shutil.rmtree(target_dir)
        shutil.copytree(source, target_dir, symlinks=True, ignore=shutil.ignore_patterns('Headers', 'PrivateHeaders', 'Modules', '_CodeSignature'))
        info = plistlib.loads((target_dir / 'Info.plist').read_bytes())
        required += ['Frameworks/' + name + '/' + info['CFBundleExecutable'], 'Frameworks/' + name + '/Info.plist']
        frameworks[name] = {k: v for k, v in info.items() if k.startswith('DP') or k == 'CFBundleIdentifier'}
    manifests = {'required_files': sorted(required), 'source_resource_sha256': hashes, 'exploit_metadata': frameworks}
    # Keep UI version and runtime version separate: core migration compares the latter.
    app = next(o for o in project['objects'].values() if o.get('isa') == 'PBXNativeTarget' and o.get('name') == 'Dopamine')
    configs = project['objects'][app['buildConfigurationList']]['buildConfigurations']
    version = project['objects'][configs[0]]['buildSettings']['MARKETING_VERSION']
    manifests['runtime_version'] = version
    (destination / 'RuntimeManifest.plist').write_bytes(plistlib.dumps(manifests))
    # Licenses remain readable through iOS Settings; the App itself has only its main action.
    settings = destination / 'Settings.bundle'; settings.mkdir(exist_ok=True)
    notices = []
    for name in sorted(n for n in required if n.startswith('LICENSE')):
        notices.append({'Type': 'PSGroupSpecifier', 'Title': name, 'FooterText': (destination / name).read_text()})
    notices.insert(0, {'Type': 'PSGroupSpecifier', 'Title': '开源许可', 'FooterText': '基于 Dopamine 及随附开源组件。This product includes software developed by the Sileo Team.'})
    (settings / 'Root.plist').write_bytes(plistlib.dumps({'PreferenceSpecifiers': notices, 'StringsTable': 'Root'}))
    print(json.dumps({'frameworks': len(frameworks), 'runtime_resources': len(required), 'runtime_version': version}))

if __name__ == '__main__':
    parser = argparse.ArgumentParser(); parser.add_argument('--destination', type=Path, required=True); parser.add_argument('--products', type=Path, required=True)
    args = parser.parse_args(); copy_runtime(args.destination, args.products)
