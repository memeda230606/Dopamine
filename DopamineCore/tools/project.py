#!/usr/bin/env python3
"""Generate the independent App project, referencing upstream targets without copying them."""
import hashlib
import json
import plistlib
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
APP = ROOT / 'DopamineCore'
UPSTREAM = ROOT / 'Application/Dopamine.xcodeproj/project.pbxproj'

def upstream():
    return json.loads(subprocess.check_output(['plutil', '-convert', 'json', '-o', '-', str(UPSTREAM)]))

def components(project):
    objects = project['objects']
    original = next(o for o in objects.values() if o.get('isa') == 'PBXNativeTarget' and o.get('name') == 'Dopamine')
    targets = {objects[d]['target'] for d in original['dependencies']}
    return {k: objects[k] for k in sorted(targets)}

def generate():
    original = upstream(); source = original['objects']; objects = {}
    def add(identity, isa, **fields):
        key = hashlib.sha256(('DopamineSDK:' + identity).encode()).hexdigest()[:24].upper()
        objects[key] = dict(isa=isa, **fields)
        return key
    def build(ref): return add('build:' + ref, 'PBXBuildFile', fileRef=ref)
    def file(path, kind, tree='SOURCE_ROOT'):
        return add('file:' + path, 'PBXFileReference', path=path, sourceTree=tree, lastKnownFileType=kind)

    project_ref = file('../Application/Dopamine.xcodeproj', 'wrapper.pb-project')
    dependencies = []; remote_products = []; link = []
    for target_id, target in components(original).items():
        name = target['name']
        if name == 'DopamineCore': continue
        product = source[target['productReference']]
        proxy = add(name + ':target-proxy', 'PBXContainerItemProxy', containerPortal=project_ref, proxyType=1, remoteGlobalIDString=target_id, remoteInfo=name)
        dependencies.append(add(name + ':dependency', 'PBXTargetDependency', name=name, targetProxy=proxy))
        product_proxy = add(name + ':product-proxy', 'PBXContainerItemProxy', containerPortal=project_ref, proxyType=2, remoteGlobalIDString=target['productReference'], remoteInfo=name)
        ref = add(name + ':product', 'PBXReferenceProxy', fileType=product['explicitFileType'], path=product['path'], remoteRef=product_proxy, sourceTree='BUILT_PRODUCTS_DIR')
        remote_products.append(ref)
        if name == 'DopamineCore': link.append(build(ref))
    remote_group = add('Runtime products', 'PBXGroup', name='Runtime products', children=remote_products, sourceTree='<group>')
    sources = [file(str(f.relative_to(APP)), 'sourcecode.c.c' if f.suffix == '.c' else 'sourcecode.c.objc') for f in sorted(APP.glob('*.m')) + sorted((APP / 'Implementation').glob('*.m')) + sorted((APP / 'Implementation').glob('*.c'))]
    headers = [file(f.name, 'sourcecode.c.h') for f in sorted(APP.glob('*.h'))]
    app_product = add('App product', 'PBXFileReference', path='libDopamineCore.a', sourceTree='BUILT_PRODUCTS_DIR', explicitFileType='archive.ar', includeInIndex=0)
    products = add('Products', 'PBXGroup', name='Products', children=[app_product], sourceTree='<group>')
    package = add('zstd', 'XCRemoteSwiftPackageReference', repositoryURL='https://github.com/facebook/zstd.git', requirement={'kind': 'branch', 'branch': 'dev'})
    package_product = add('libzstd', 'XCSwiftPackageProductDependency', package=package, productName='libzstd')
    link.append(add('zstd build', 'PBXBuildFile', productRef=package_product))
    phases = [
        add('Sources', 'PBXSourcesBuildPhase', buildActionMask=2147483647, files=[build(f) for f in sources], runOnlyForDeploymentPostprocessing=0),
        add('Frameworks', 'PBXFrameworksBuildPhase', buildActionMask=2147483647, files=link, runOnlyForDeploymentPostprocessing=0),

    ]
    settings = {
        'SDKROOT': 'iphoneos', 'IPHONEOS_DEPLOYMENT_TARGET': '15.0', 'TARGETED_DEVICE_FAMILY': '1,2',
        'PRODUCT_NAME': 'DopamineCore', 'PRODUCT_BUNDLE_IDENTIFIER': 'com.mmd.LaoHeMa',
        'CURRENT_PROJECT_VERSION': '3', 'MARKETING_VERSION': '1.0.0', 'INFOPLIST_FILE': 'Info.plist',
        'GENERATE_INFOPLIST_FILE': 'NO', 'CLANG_ENABLE_OBJC_ARC': 'YES', 'CLANG_ENABLE_MODULES': 'YES',
        'CLANG_ENABLE_OBJC_WEAK': 'YES', 'ENABLE_USER_SCRIPT_SANDBOXING': 'NO',
        'CODE_SIGNING_ALLOWED': 'NO', 'FRAMEWORK_SEARCH_PATHS': ['$(SRCROOT)/../BaseBin/_external/frameworks'],
        'HEADER_SEARCH_PATHS': ['$(SRCROOT)', '$(SRCROOT)/Implementation', '$(SRCROOT)/PrivateHeaders', '$(SRCROOT)/../Application/Dopamine/Dependencies', '$(SRCROOT)/../BaseBin/.include'],
        'LIBRARY_SEARCH_PATHS': ['$(SRCROOT)/../BaseBin/.build', '$(SRCROOT)/../Application/Dopamine/Dependencies'],
        'LD_RUNPATH_SEARCH_PATHS': ['@executable_path/Frameworks', '@executable_path'],
        'OTHER_LDFLAGS': ['-ObjC', '-ljailbreak', '-lxpf', '-lchoma', '-lgrabkernel2', '-lpartial', '-lz', '-lcompression', '-lMobileGestalt', '-framework', 'UIKit', '-framework', 'Foundation', '-framework', 'CoreServices', '-framework', 'IOKit', '-framework', 'IOSurface', '-framework', 'LocalAuthentication'],
        'GCC_WARN_ABOUT_RETURN_TYPE': 'YES_ERROR', 'GCC_WARN_UNUSED_VARIABLE': 'YES',
    }
    configs = [add(n, 'XCBuildConfiguration', name=n, buildSettings=dict(settings, GCC_OPTIMIZATION_LEVEL='0' if n == 'Debug' else 's')) for n in ['Debug', 'Release']]
    config_list = add('Configurations', 'XCConfigurationList', buildConfigurations=configs, defaultConfigurationIsVisible=0, defaultConfigurationName='Release')
    target = add('App target', 'PBXNativeTarget', name='DopamineSDK', productName='DopamineCore', productType='com.apple.product-type.library.static', productReference=app_product, buildConfigurationList=config_list, buildPhases=phases, buildRules=[], dependencies=dependencies, packageProductDependencies=[package_product])
    group = add('Main group', 'PBXGroup', children=sources + headers + [project_ref, products], sourceTree='<group>')
    project_configs = [add(n + ':project', 'XCBuildConfiguration', name=n, buildSettings={}) for n in ['Debug', 'Release']]
    project_config_list = add('Project configurations', 'XCConfigurationList', buildConfigurations=project_configs, defaultConfigurationIsVisible=0, defaultConfigurationName='Release')
    project = add('Project', 'PBXProject', attributes={'LastUpgradeCheck': '1630'}, buildConfigurationList=project_config_list, compatibilityVersion='Xcode 14.0', developmentRegion='zh-Hans', knownRegions=['zh-Hans', 'en', 'Base'], mainGroup=group, productRefGroup=products, projectDirPath='', projectRoot='', targets=[target], packageReferences=[package], projectReferences=[{'ProjectRef': project_ref, 'ProductGroup': remote_group}])
    def encode(value, indent=0):
        tab = '\t' * indent
        if isinstance(value, dict):
            return '{\n' + ''.join('\t' * (indent + 1) + json.dumps(k) + ' = ' + encode(v, indent + 1) + ';\n' for k, v in value.items()) + tab + '}'
        if isinstance(value, list): return '(\n' + ''.join('\t' * (indent + 1) + encode(v, indent + 1) + ',\n' for v in value) + tab + ')'
        return json.dumps(value, ensure_ascii=False)
    project_dir = APP / 'DopamineCore.xcodeproj'; project_dir.mkdir(exist_ok=True)
    (project_dir / 'project.pbxproj').write_text('// !$*UTF8*$!\n' + encode({'archiveVersion': 1, 'classes': {}, 'objectVersion': 56, 'objects': objects, 'rootObject': project}) + '\n')
    schemes = project_dir / 'xcshareddata/xcschemes'; schemes.mkdir(parents=True, exist_ok=True)
    reference = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="libDopamineCore.a" BlueprintName="DopamineSDK" ReferencedContainer="container:DopamineCore.xcodeproj"/>'
    (schemes / 'DopamineSDK.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1630" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{reference}</BuildActionEntry></BuildActionEntries></BuildAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>\n''')
    return project_dir

if __name__ == '__main__': print(generate())
