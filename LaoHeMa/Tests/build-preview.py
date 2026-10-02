#!/usr/bin/env python3
import plistlib
import subprocess
from pathlib import Path
root = Path(__file__).resolve().parents[2]
app = root / '.build/laohema/Preview.app'; app.mkdir(parents=True, exist_ok=True)
info = {'CFBundleIdentifier': 'com.mmd.LaoHeMa.Preview', 'CFBundleExecutable': 'Preview', 'CFBundleName': '老河马预览', 'CFBundlePackageType': 'APPL', 'CFBundleVersion': '1', 'CFBundleShortVersionString': '1.0', 'MinimumOSVersion': '15.0', 'UIDeviceFamily': [1, 2], 'UILaunchScreen': {}, 'UISupportedInterfaceOrientations': ['UIInterfaceOrientationPortrait', 'UIInterfaceOrientationLandscapeLeft', 'UIInterfaceOrientationLandscapeRight']}
(app / 'Info.plist').write_bytes(plistlib.dumps(info))
sdk = subprocess.check_output(['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-path'], text=True).strip()
subprocess.run(['xcrun', 'clang', '-target', 'arm64-apple-ios15.0-simulator', '-isysroot', sdk, '-fobjc-arc', '-fblocks', '-framework', 'UIKit', '-framework', 'Foundation', '-framework', 'CoreGraphics', '-I' + str(root / 'LaoHeMa/App'), str(root / 'LaoHeMa/App/LMViewController.m'), str(root / 'LaoHeMa/Tests/preview.m'), '-o', str(app / 'Preview')], check=True)
subprocess.run(['codesign', '--force', '--sign', '-', str(app)], check=True)
print(app)
