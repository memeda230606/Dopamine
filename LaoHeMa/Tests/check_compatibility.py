#!/usr/bin/env python3
"""Check the shipped compatibility data against upstream source, not a copied manifest."""
import argparse
import hashlib
import json
import plistlib
import subprocess
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'DopamineCore/tools'))
from project import ROOT, upstream, components

parser = argparse.ArgumentParser()
parser.add_argument('--baseline', required=True)
parser.add_argument('--app', type=Path, default=ROOT / '.build/laohema/package/Payload/LaoHeMa.app')
args = parser.parse_args()
project = upstream(); objects = project['objects']; comp = components(project)
new_project = json.loads(subprocess.check_output(['plutil', '-convert', 'json', '-o', '-', str(ROOT / 'LaoHeMa/LaoHeMa.xcodeproj/project.pbxproj')]))
new_objects = new_project['objects']
target = next(o for o in new_objects.values() if o.get('isa') == 'PBXNativeTarget')
assert not target['dependencies'], 'Consumer must not build upstream targets'
assert not new_objects[new_project['rootObject']]['projectReferences']
results = {}
for key, target in comp.items():
    if target['name'] == 'DopamineCore': continue
    settings = objects[objects[target['buildConfigurationList']]['buildConfigurations'][0]]['buildSettings']
    path = settings['INFOPLIST_FILE'].replace('$(SRCROOT)', str(ROOT / 'Application'))
    path = Path(path) if Path(path).is_absolute() else ROOT / 'Application' / path
    source = plistlib.loads(path.read_bytes())
    actual = plistlib.loads((args.app / 'Frameworks' / (target['name'] + '.framework') / 'Info.plist').read_bytes())
    original_data = {k: v for k, v in source.items() if k.startswith('DP')}
    assert original_data == {k: v for k, v in actual.items() if k.startswith('DP')}, target['name']
    executable = args.app / 'Frameworks' / (target['name'] + '.framework') / actual['CFBundleExecutable']
    architectures = subprocess.check_output(['lipo', '-archs', str(executable)], text=True).strip()
    results[target['name']] = {'type': actual['DPExploitType'], 'variants': sorted(actual['DPExploitFlavors']), 'architectures': architectures, 'support_metadata_unchanged': True}
core = ROOT / 'DopamineCore/Implementation'
unchanged = {}
for name in ['DOJailbreaker.m', 'DOExploit.m', 'DOExploitManager.m', 'DOEnvironmentManager.m', 'DOBootstrapper.m', 'DOBootstrapper+zstd.m']:
    path = core / name; relative = 'Application/Dopamine/Jailbreak/' + name
    baseline = subprocess.check_output(['git', 'show', args.baseline + ':' + relative], cwd=ROOT)
    assert path.read_bytes() == baseline, 'Core behavior changed: ' + name
    unchanged[name] = hashlib.sha256(baseline).hexdigest()
report = {'passed': True, 'frameworks': results, 'framework_count': len(results), 'variant_count': sum(len(v['variants']) for v in results.values()), 'no_upstream_target_dependency': True, 'core_unchanged_from': args.baseline, 'core_sha256': unchanged, 'hardware_matrix_tested': False}
out = ROOT / '.build/laohema/tests'; out.mkdir(parents=True, exist_ok=True)
(out / 'compatibility.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(report, indent=2))
