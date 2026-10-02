'use strict';
// Only use with our own ResearchLab app. No third-party processes are targeted.
if (Process.mainModule.name !== 'ResearchLab') throw new Error('Unexpected target');
const targetModule = Process.mainModule;
const marker = targetModule.getExportByName('RLResearchMarker');
const value = targetModule.getExportByName('RLResearchValue');
const calculate = targetModule.getExportByName('RLResearchCalculate');
const call = new NativeFunction(calculate, 'int', ['int']);
const initial = call(11);
let hits = 0;
const hook = Interceptor.attach(calculate, {
  onEnter(args) { this.input = args[0].toInt32(); },
  onLeave(retval) { hits++; retval.replace(retval.toInt32() + 7); }
});
Interceptor.flush();
const intercepted = call(11);
hook.detach();
Interceptor.flush();
const restored = call(11);
const getuid = new NativeFunction(Module.getGlobalExportByName('getuid'), 'uint', []);
const geteuid = new NativeFunction(Module.getGlobalExportByName('geteuid'), 'uint', []);
send({type: 'research-result', pid: Process.id, uid: getuid(), euid: geteuid(),
  arch: Process.arch, module: targetModule.name, moduleCount: Process.enumerateModules().length,
  marker: marker.readUtf8String(), dataValue: value.readU32(), initial, intercepted,
  restored, hits, passed: marker.readUtf8String() === 'ResearchLab-owned-target' &&
    value.readU32() === 20261002 && initial === 22 && intercepted === 29 && restored === 22 && hits === 1});
