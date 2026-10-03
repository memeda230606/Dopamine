#!/usr/bin/env python3
import argparse,json,re,subprocess
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--library',type=Path,required=True);a=p.parse_args()
root=Path(__file__).resolve().parents[2]
project=json.loads(subprocess.check_output(['plutil','-convert','json','-o','-',str(root/'Application/Dopamine.xcodeproj/project.pbxproj')]))['objects']
targets={v['name']:v for v in project.values() if v.get('isa')=='PBXNativeTarget'}
def sources(target):
 result=set()
 for phase in target['buildPhases']:
  phase=project[phase]
  if phase['isa']=='PBXSourcesBuildPhase':
   for build in phase['files']:result.add(project[project[build]['fileRef']]['path'])
 return result
core=sources(targets['DopamineCore']);app=sources(targets['Dopamine'])
assert not core & app,core & app
assert {'DOJailbreaker.m','DOEnvironmentManager.m','DOBootstrapper.m','DOExploit.m','DOExploitManager.m','DOCore.m','DOCoreDiagnostics.m','NSString+Version.m'}<=core
defined=subprocess.check_output(['nm','--defined-only',str(a.library)],text=True)
assert re.search(r' [tT] -\[NSString\(Version\) numericalVersionRepresentation\]$',defined,re.M), 'Core must contain the version-comparison category implementation'
assert 'DOPreferenceManager.m' not in core and 'DOAppCoreHost.m' in app
undefined=subprocess.check_output(['nm','-u',str(a.library)],text=True)
for symbol in ['DOUIManager','DOPreferenceManager','DOAppCoreHost','UIImage','UIApplication','UIView']:
 assert not re.search(r'_OBJC_(?:CLASS|METACLASS)_\$_'+symbol+r'\b',undefined),symbol
for name in core:
 candidates=[root/'DopamineCore'/name,root/'Application/Dopamine/Jailbreak'/name,root/'Application/Dopamine/Extensions'/name]
 file=next(x for x in candidates if x.exists())
 text=file.read_text()
 assert not re.search(r'#(?:import|include).*?(?:UIKit|DOUIManager|DOPreferenceManager|UIImage)',text),str(file)
 assert '[NSBundle' not in text and 'NSBundle.mainBundle' not in text,str(file)
print(json.dumps({'passed':True,'core_sources':sorted(core),'no_duplicate_app_sources':True,'no_ui_preference_or_bundle_dependency':True}))
