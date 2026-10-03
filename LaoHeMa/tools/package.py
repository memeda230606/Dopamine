#!/usr/bin/env python3
"""Sign and verify the independent App, preserving all original exploit metadata."""
import hashlib
import json
import os
import plistlib
import re
import shutil
import struct
import subprocess
import zipfile
from pathlib import Path
from project import ROOT

def verify_code(data):
    # CodeDirectory hashes are relative to each Mach-O slice.
    if data[:4] == b'\xca\xfe\xba\xbe':
        checked = []
        for i in range(struct.unpack_from('>I', data, 4)[0]):
            _, _, start, length, _ = struct.unpack_from('>IIIII', data, 8 + 20 * i)
            checked.extend(verify_code(data[start:start + length]))
        return checked
    assert data[:4] == b'\xcf\xfa\xed\xfe', 'Expected Mach-O64'
    position = 32; signature = None
    for _ in range(struct.unpack_from('<I', data, 16)[0]):
        cmd, size = struct.unpack_from('<II', data, position)
        if cmd == 0x1d:
            start, length = struct.unpack_from('<II', data, position + 8); signature = data[start:start + length]
        position += size
    assert signature and struct.unpack_from('>I', signature)[0] == 0xfade0cc0
    checked = []
    for index in range(struct.unpack_from('>I', signature, 8)[0]):
        slot, start = struct.unpack_from('>II', signature, 12 + index * 8)
        if slot != 0 and not 0x1000 <= slot <= 0x1005: continue
        cd = signature[start:]; assert struct.unpack_from('>I', cd)[0] == 0xfade0c02
        offset, _, _, count, limit = struct.unpack_from('>IIIII', cd, 16)
        size, kind, _, exponent = struct.unpack_from('BBBB', cd, 36)
        algorithm = {1: 'sha1', 2: 'sha256', 3: 'sha256', 4: 'sha384'}[kind]; page = 1 << exponent
        for i in range(count):
            actual = hashlib.new(algorithm, data[i * page:min((i + 1) * page, limit)]).digest()[:size]
            assert actual == cd[offset + i * size:offset + (i + 1) * size], 'Invalid signature page'
        checked.append({'algorithm': algorithm, 'pages': count})
    assert checked
    return checked

def package():
    out = ROOT / '.build/laohema'; products = out / 'DerivedData/Build/Products/Release-iphoneos'
    source = products / 'LaoHeMa.app'; stage = out / 'package'; app = stage / 'Payload/LaoHeMa.app'
    if stage.exists(): shutil.rmtree(stage)
    app.parent.mkdir(parents=True)
    shutil.copytree(source, app, symlinks=True)
    info = plistlib.loads((app / 'Info.plist').read_bytes())
    assert info['CFBundleIdentifier'] == 'com.mmd.LaoHeMa' and info['CFBundleDisplayName'] == '老河马'
    assert info['MinimumOSVersion'] == '15.0' and info['UIDeviceFamily'] == [1, 2]
    binary = app / 'LaoHeMa'
    assert b'DOCoreContext' in binary.read_bytes() and b'LMCoreHost' in binary.read_bytes()
    assert b'DOUIManager' not in binary.read_bytes() and b'DOPreferenceManager' not in binary.read_bytes()
    assert b'[NOREBOOT_TEST]' not in binary.read_bytes(), 'The complete-flow app must not link the experimental core'
    # A selector reference alone does not provide its Objective-C category implementation.
    symbols = subprocess.check_output(['nm', '--defined-only', str(binary)], text=True)
    assert re.search(r' [tT] -\[NSString\(Version\) numericalVersionRepresentation\]$', symbols, re.M), 'Missing bootstrap version-comparison implementation'
    sdk = ROOT / '.build/sdk/DopamineSDK'
    manifest = json.loads((sdk / 'SDKManifest.json').read_text())
    expected = set(manifest['exploit_metadata'])
    assert {p.name for p in (app / 'Frameworks').glob('*.framework')} == expected
    variants = 0; metadata = {}
    for name in sorted(expected):
        current = plistlib.loads((app / 'Frameworks' / name / 'Info.plist').read_bytes())
        built = plistlib.loads((sdk / 'Runtime/Frameworks' / name / 'Info.plist').read_bytes())
        fields = {k: v for k, v in current.items() if k.startswith('DP') or k == 'CFBundleIdentifier'}
        assert fields == {k: v for k, v in built.items() if k.startswith('DP') or k == 'CFBundleIdentifier'}
        variants += len(current.get('DPExploitFlavors', {})); metadata[name] = fields
    # Verify all non-code payloads before signing (code signatures can legitimately change).
    for name, digest in manifest['source_resource_sha256'].items():
        assert hashlib.sha256((app / name).read_bytes()).hexdigest() == digest, name
    ldid = os.environ.get('LDID', str(ROOT / '.build/tools/ldid/ldid'))
    for framework in sorted((app / 'Frameworks').glob('*.framework')):
        data = plistlib.loads((framework / 'Info.plist').read_bytes())
        subprocess.run([ldid, '-S', str(framework / data['CFBundleExecutable'])], check=True)
    entitlements = sdk / 'Host.entitlements'
    subprocess.run([ldid, '-S' + str(entitlements), str(binary)], check=True)
    subprocess.run([ldid, '-s', str(app)], check=True)
    assert plistlib.loads(subprocess.check_output([ldid, '-e', str(binary)])) == plistlib.loads(entitlements.read_bytes())
    signatures = {}
    for path in app.rglob('*'):
        if path.is_file() and path.read_bytes()[:4] in (b'\xcf\xfa\xed\xfe', b'\xca\xfe\xba\xbe'):
            signatures[str(path.relative_to(app))] = verify_code(path.read_bytes())
    filename = f'LaoHeMa-{info["CFBundleShortVersionString"]}-build{info["CFBundleVersion"]}.ipa'
    ipa = out / filename
    with zipfile.ZipFile(ipa, 'w', zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(stage.rglob('*')):
            if path.is_file(): archive.write(path, path.relative_to(stage))
    with zipfile.ZipFile(ipa) as archive: assert archive.testzip() is None
    meta = {'filename': filename, 'display_name': '老河马', 'bundle_id': info['CFBundleIdentifier'], 'version': info['CFBundleShortVersionString'], 'build': info['CFBundleVersion'], 'runtime_version': info['LMRuntimeVersion'], 'bytes': ipa.stat().st_size, 'sha256': hashlib.sha256(ipa.read_bytes()).hexdigest(), 'source_commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(), 'source_modified': bool(subprocess.check_output(['git', 'status', '--porcelain'], cwd=ROOT).strip()), 'exploit_framework_count': len(expected), 'exploit_variant_count': variants, 'compatibility_metadata': metadata, 'entitlements_match_upstream': True, 'runtime_resources_match_upstream': True, 'no_original_ui_linked': True, 'verified_signatures': signatures, 'automatic_userspace_reboot': True, 'device_test': 'pending_installation', 'cold_boot_full_flow': 'not_tested', 'all_devices_tested': False}
    (out / 'build-info.json').write_text(json.dumps(meta, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({k: v for k, v in meta.items() if k not in ['compatibility_metadata', 'verified_signatures']}, ensure_ascii=False, indent=2))

if __name__ == '__main__': package()
