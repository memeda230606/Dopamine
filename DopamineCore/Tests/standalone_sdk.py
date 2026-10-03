#!/usr/bin/env python3
"""Build a copied UI and a Foundation CLI outside the repository using only the SDK."""
import json, shutil, subprocess, tempfile
from pathlib import Path
root=Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory(prefix='dopamine-sdk-consumer-') as directory:
    work=Path(directory);sdk=work/'SDK';shutil.copytree(root/'.build/sdk/DopamineSDK',sdk)
    app=work/'LaoHeMa';app.mkdir()
    for name in ('App','Assets.xcassets','LaoHeMa.xcodeproj'):
        shutil.copytree(root/'LaoHeMa'/name,app/name,ignore=shutil.ignore_patterns('xcuserdata'))
    shutil.copy2(root/'LaoHeMa/Info.plist',app/'Info.plist')
    out=root/'.build/decoupling-final'
    with (out/'isolated-ui-build.log').open('w') as log:
        subprocess.run(['xcodebuild','-project',str(app/'LaoHeMa.xcodeproj'),'-scheme','LaoHeMa','-configuration','Release',
            '-derivedDataPath',str(work/'DerivedData'),'-destination','generic/platform=iOS',
            'CODE_SIGNING_ALLOWED=NO','DOPAMINE_SDK_ROOT='+str(sdk)],check=True,stdout=log,stderr=subprocess.STDOUT)
    manifest=json.loads((sdk/'SDKManifest.json').read_text())
    ios=subprocess.check_output(['xcrun','--sdk','iphoneos','--show-sdk-path'],text=True).strip()
    args=['xcrun','clang','-target','arm64-apple-ios15.0','-isysroot',ios,'-fobjc-arc','-fblocks','-I'+str(sdk/'Headers'),
          str(sdk/'Examples/main.m'),*[str(sdk/'Lib'/n) for n in ('libDopamineCore.a','libzstd.o','libgrabkernel2.a','libpartial.a')],
          '-L'+str(sdk/'Lib'),*manifest['required_link_flags']]
    for framework in manifest['system_frameworks']:args+=['-framework',framework]
    args+=['-Wl,-rpath,@executable_path/Runtime','-o',str(work/'DopamineCLI')]
    with (out/'isolated-cli-build.log').open('w') as log:
        subprocess.run(args,check=True,cwd=work,stdout=log,stderr=subprocess.STDOUT)
    linked=subprocess.check_output(['otool','-L',str(work/'DopamineCLI')],text=True)
    assert 'Corellium' not in linked
    undefined=subprocess.check_output(['nm','-u',str(work/'DopamineCLI')],text=True)
    assert '_UIApplicationMain' not in undefined
    shutil.copy2(work/'DopamineCLI',out/'DopamineCLI')
    report={'passed':True,'ui_built_outside_repository':True,'headless_cli_built_without_application_ui':True,'frameworks':len(manifest['exploit_metadata']),'device_execution':'pending'}
    (out/'standalone-sdk.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report))
