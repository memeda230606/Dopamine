#!/usr/bin/env python3
"""Generate the independent App project, referencing upstream targets without copying them."""
import hashlib
import json
import plistlib
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
APP = ROOT / 'LaoHeMa'
def generate():
    objects = {}
    def add(identity, isa, **fields):
        key = hashlib.sha256(('LaoHeMa:' + identity).encode()).hexdigest()[:24].upper()
        objects[key] = dict(isa=isa, **fields)
        return key
    def build(ref): return add('build:' + ref, 'PBXBuildFile', fileRef=ref)
    def file(path, kind, tree='SOURCE_ROOT'):
        return add('file:' + path, 'PBXFileReference', path=path, sourceTree=tree, lastKnownFileType=kind)

    dependencies = []; link = []
    sources = [file('App/' + n, 'sourcecode.c.objc') for n in ['main.m', 'LMCoreHost.m', 'LMJailbreakController.m', 'LMViewController.m']]
    headers = [file('App/' + n, 'sourcecode.c.h') for n in ['LMCoreHost.h', 'LMJailbreakController.h', 'LMViewController.h']]
    assets = file('Assets.xcassets', 'folder.assetcatalog')
    app_product = add('App product', 'PBXFileReference', path='LaoHeMa.app', sourceTree='BUILT_PRODUCTS_DIR', explicitFileType='wrapper.application', includeInIndex=0)
    products = add('Products', 'PBXGroup', name='Products', children=[app_product], sourceTree='<group>')
    phases = [
        add('Sources', 'PBXSourcesBuildPhase', buildActionMask=2147483647, files=[build(f) for f in sources], runOnlyForDeploymentPostprocessing=0),
        add('Frameworks', 'PBXFrameworksBuildPhase', buildActionMask=2147483647, files=link, runOnlyForDeploymentPostprocessing=0),
        add('Resources', 'PBXResourcesBuildPhase', buildActionMask=2147483647, files=[build(assets)], runOnlyForDeploymentPostprocessing=0),
        add('Runtime resources', 'PBXShellScriptBuildPhase', buildActionMask=2147483647, files=[], inputPaths=[], outputPaths=[], alwaysOutOfDate=1,
            shellPath='/bin/sh', shellScript='cp -R "$DOPAMINE_SDK_ROOT/Runtime/." "$TARGET_BUILD_DIR/$WRAPPER_NAME/"\n', runOnlyForDeploymentPostprocessing=0)
    ]
    settings = {
        'SDKROOT': 'iphoneos', 'IPHONEOS_DEPLOYMENT_TARGET': '15.0', 'TARGETED_DEVICE_FAMILY': '1,2',
        'PRODUCT_NAME': 'LaoHeMa', 'PRODUCT_BUNDLE_IDENTIFIER': 'com.mmd.LaoHeMa',
        'CURRENT_PROJECT_VERSION': '4', 'MARKETING_VERSION': '1.0.0', 'INFOPLIST_FILE': 'Info.plist',
        'GENERATE_INFOPLIST_FILE': 'NO', 'CLANG_ENABLE_OBJC_ARC': 'YES', 'CLANG_ENABLE_MODULES': 'YES',
        'CLANG_ENABLE_OBJC_WEAK': 'YES', 'ENABLE_USER_SCRIPT_SANDBOXING': 'NO',
        'CODE_SIGNING_ALLOWED': 'NO', 'ASSETCATALOG_COMPILER_APPICON_NAME': 'AppIcon',
        'DOPAMINE_SDK_ROOT': '$(SRCROOT)/../.build/sdk/DopamineSDK', 'HEADER_SEARCH_PATHS': ['$(DOPAMINE_SDK_ROOT)/Headers'],
        'LIBRARY_SEARCH_PATHS': ['$(DOPAMINE_SDK_ROOT)/Lib'],
        'LD_RUNPATH_SEARCH_PATHS': ['@executable_path/Frameworks', '@executable_path'],
        'OTHER_LDFLAGS': ['$(DOPAMINE_SDK_ROOT)/Lib/libDopamineCore.a', '$(DOPAMINE_SDK_ROOT)/Lib/libzstd.o', '$(DOPAMINE_SDK_ROOT)/Lib/libgrabkernel2.a', '$(DOPAMINE_SDK_ROOT)/Lib/libpartial.a', '-ObjC', '-ljailbreak', '-lxpf', '-lchoma', '-lz', '-lcompression', '-lMobileGestalt', '-framework', 'UIKit', '-framework', 'Foundation', '-framework', 'CoreServices', '-framework', 'IOKit', '-framework', 'IOSurface', '-framework', 'LocalAuthentication'],
        'GCC_WARN_ABOUT_RETURN_TYPE': 'YES_ERROR', 'GCC_WARN_UNUSED_VARIABLE': 'YES',
    }
    configs = [add(n, 'XCBuildConfiguration', name=n, buildSettings=dict(settings, GCC_OPTIMIZATION_LEVEL='0' if n == 'Debug' else 's')) for n in ['Debug', 'Release']]
    config_list = add('Configurations', 'XCConfigurationList', buildConfigurations=configs, defaultConfigurationIsVisible=0, defaultConfigurationName='Release')
    target = add('App target', 'PBXNativeTarget', name='LaoHeMa', productName='LaoHeMa', productType='com.apple.product-type.application', productReference=app_product, buildConfigurationList=config_list, buildPhases=phases, buildRules=[], dependencies=dependencies, packageProductDependencies=[])
    group = add('Main group', 'PBXGroup', children=sources + headers + [assets, products], sourceTree='<group>')
    project_configs = [add(n + ':project', 'XCBuildConfiguration', name=n, buildSettings={}) for n in ['Debug', 'Release']]
    project_config_list = add('Project configurations', 'XCConfigurationList', buildConfigurations=project_configs, defaultConfigurationIsVisible=0, defaultConfigurationName='Release')
    project = add('Project', 'PBXProject', attributes={'LastUpgradeCheck': '1630'}, buildConfigurationList=project_config_list, compatibilityVersion='Xcode 14.0', developmentRegion='zh-Hans', knownRegions=['zh-Hans', 'en', 'Base'], mainGroup=group, productRefGroup=products, projectDirPath='', projectRoot='', targets=[target], packageReferences=[], projectReferences=[])
    def encode(value, indent=0):
        tab = '\t' * indent
        if isinstance(value, dict):
            return '{\n' + ''.join('\t' * (indent + 1) + json.dumps(k) + ' = ' + encode(v, indent + 1) + ';\n' for k, v in value.items()) + tab + '}'
        if isinstance(value, list): return '(\n' + ''.join('\t' * (indent + 1) + encode(v, indent + 1) + ',\n' for v in value) + tab + ')'
        return json.dumps(value, ensure_ascii=False)
    project_dir = APP / 'LaoHeMa.xcodeproj'; project_dir.mkdir(exist_ok=True)
    (project_dir / 'project.pbxproj').write_text('// !$*UTF8*$!\n' + encode({'archiveVersion': 1, 'classes': {}, 'objectVersion': 56, 'objects': objects, 'rootObject': project}) + '\n')
    schemes = project_dir / 'xcshareddata/xcschemes'; schemes.mkdir(parents=True, exist_ok=True)
    reference = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="LaoHeMa.app" BlueprintName="LaoHeMa" ReferencedContainer="container:LaoHeMa.xcodeproj"/>'
    (schemes / 'LaoHeMa.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1630" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{reference}</BuildActionEntry></BuildActionEntries></BuildAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>\n''')
    info = {'CFBundleIdentifier': '$(PRODUCT_BUNDLE_IDENTIFIER)', 'CFBundleExecutable': '$(EXECUTABLE_NAME)', 'CFBundleName': 'LaoHeMa', 'CFBundleDisplayName': '老河马', 'CFBundlePackageType': 'APPL', 'CFBundleShortVersionString': '$(MARKETING_VERSION)', 'CFBundleVersion': '$(CURRENT_PROJECT_VERSION)', 'LSRequiresIPhoneOS': True, 'UILaunchScreen': {}, 'UIFileSharingEnabled': True, 'LSSupportsOpeningDocumentsInPlace': True, 'UISupportedInterfaceOrientations': ['UIInterfaceOrientationPortrait', 'UIInterfaceOrientationLandscapeLeft', 'UIInterfaceOrientationLandscapeRight'], 'UISupportedInterfaceOrientations~ipad': ['UIInterfaceOrientationPortrait', 'UIInterfaceOrientationPortraitUpsideDown', 'UIInterfaceOrientationLandscapeLeft', 'UIInterfaceOrientationLandscapeRight']}
    info['LMRuntimeVersion'] = json.loads((ROOT / '.build/sdk/DopamineSDK/SDKManifest.json').read_text())['runtime_version']
    (APP / 'Info.plist').write_bytes(plistlib.dumps(info, sort_keys=False))
    return project_dir

if __name__ == '__main__': print(generate())
