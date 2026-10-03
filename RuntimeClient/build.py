"""Shared laboratory build inputs and exact runtime ABI compatibility lock."""
import hashlib, io, plistlib, tarfile
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
def configure(app):
    canonical = ROOT / 'BaseBin/libjailbreak/src/info.h'
    assert canonical.read_bytes() == (ROOT / 'BaseBin/.include/libjailbreak/info.h').read_bytes(), 'Rebuild BaseBin headers before packaging'
    backends = [(ROOT / 'BaseBin/.build/libjailbreak.dylib').read_bytes()]
    with tarfile.open(ROOT / 'BaseBin/basebin.tar') as archive:
        entries = [e for e in archive if e.name.endswith('/libjailbreak.dylib') or e.name == 'libjailbreak.dylib']
        assert len(entries) == 1
        backends.append(archive.extractfile(entries[0]).read())
    data = {'format': 1, 'abi_header_sha256': hashlib.sha256(canonical.read_bytes()).hexdigest(),
            'backend_sha256': sorted({hashlib.sha256(b).hexdigest() for b in backends})}
    (app / 'RuntimeABI.plist').write_bytes(plistlib.dumps(data))
    return ['-I' + str(ROOT / 'RuntimeClient'), '-I' + str(ROOT / 'LabSupport'),
            str(ROOT / 'RuntimeClient/RuntimeClient.m'), str(ROOT / 'LabSupport/LabSupport.m')]
