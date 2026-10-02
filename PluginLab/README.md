# 独立插件实验室

这是独立于 Dopamine 应用源码的工程。五个插件各有自己的源码、Makefile、过滤文件和 control，可以分别编译为 rootless `.deb`。`App` 是单独的测试宿主，不把插件代码静态编译进宿主，也不修改 Dopamine。

| 工程 | 验证内容 | 成功条件 |
| --- | --- | --- |
| LoadProbe | 动态库加载和构造函数 | 独立动态库的导出函数返回约定标记，记录真实加载路径 |
| MethodProbe | Objective-C 方法拦截 | 调用原实现后加 7；三个输入从 22/0/-6 变为 29/7/1 |
| UIProbe | 界面修改 | 仅改变实验室内的提示文字、颜色及可访问性标识 |
| FileProbe | 文件写入、读取、清理 | 在本 App Documents 下创建随机目录，验证 JSON 往返，再删除 |
| NotificationProbe | 进程内通知回调 | 回调收到本轮随机生成的 nonce |

## 编译

需要 macOS、Xcode、Theos、GNU make 和支持 iOS 的 ldid。当前工作区已有这些依赖。

```sh
python3 build.py
```

若将此目录复制到其他位置，请通过环境变量指定 `THEOS` 和 `LDID`。每个插件也可以在自己的目录独立执行：

```sh
gmake package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless
```

输出为 `build/PluginLab-1.0.0-build2.ipa` 和 `build/packages/` 下五个 `.deb`。IPA 用 TrollStore 安装。五个包也可在已经正常工作的 rootless 插件环境中通过包管理工具安装。

所有插件的过滤器都只匹配 `com.mmd.PluginLab`，源码的构造函数还会再次检查该标识。三个方法拦截插件使用 Theos Logos 的 `internal` 后端，通过 Objective-C runtime 安装方法拦截，不依赖 ElleKit 的方法拦截接口。

## 本次无重启测试的准确范围

本次实验使用 **App 内定向加载**，不是“全局自动注入已经正常”的证明。

1. 记录系统启动 UUID、SpringBoard PID/启动时间，以及未加载插件时的行为。
2. 通过 TrollStore 支持的 root 辅助进程，把本工程五个经过 SHA-256 校验的动态库与过滤文件写入 `/var/jb/Library/MobileSubstrate/DynamicLibraries/`。
3. 调用设备上已有的 Dopamine 越狱服务，为这五个动态库建立签名信任；不清空信任缓存。
4. 宿主从上述外部目录逐个 `dlopen` 独立动态库，执行五类检查。
5. 再次读取启动标识和桌面进程身份，并保存实际结果。

为避免 TrollStore 在安装 IPA 时改写测试动态库签名，IPA 中保存的是编码后的构建产物；辅助进程在安装后解码并校验。插件不会作为普通应用内嵌 Framework 被隐式加载。

实验室的定向安装直接管理这五个固定名字的文件，不登记 dpkg 安装状态；这是测试部署方式。`.deb` 则提供标准 rootless 包格式。当前宿主不改变 Dopamine 的全局插件开关，不触发重启、注销桌面或启动其他系统服务。

文件读写只验证插件在宿主进程中的文件操作，不验证其他 App 数据访问或沙箱绕过。通知测试仅验证进程内通知。root 安装辅助进程来自 TrollStore 的能力，不能单独作为越狱成功的证据。

宿主同时使用 `platform-application` 和 `no-sandbox`，因此按 [TrollStore 官方说明](https://github.com/opa334/TrollStore#unsandboxing) 添加 `com.apple.private.security.storage.AppDataContainers`，以访问自己的 Documents。该权限本身允许更广的数据容器访问，但本工程的文件测试和报告保存仅操作本 App 数据目录。

## 真机验证记录

2026-10-02，iPhone 13 / iOS 16.2，build 1：五个独立动态库均成功建立信任并加载；加载、方法拦截、界面修改、通知回调四项通过。文件操作及报告保存被系统策略拒绝，日志显示对自身 Documents 的 `file-write-create` 拦截。测试前后系统启动 UUID 和 SpringBoard PID/启动时间一致，确认系统和桌面未重启。

build 2 补充上述宿主数据容器权限，更新构建号，并使用 codesign 为宿主生成可校验的临时签名；TrollStore 安装时仍会重新签名。五个插件的代码保持不变。

build 1 的五个测试插件已通过宿主清理功能移除，五项清理结果均成功，方便新构建重新部署。

2026-10-02 12:12，build 2 真机复测 **5/5 全部通过**：

- 五个外部动态库的签名信任与加载全部成功。
- 对比加载前的干净基线，方法结果从 22/0/-6 变为 29/7/1，界面及通知检查成功。
- 在本 App Documents 内完成 JSON 写入、读取一致性检查及临时目录清理，无错误；完整报告成功保存。
- 测试前后启动 UUID 均为 `DEF3D6B9-1C1F-407A-AB1F-2418B10D37F2`，SpringBoard PID 为 32、启动时间未变。电脑独立查询的 launchd 和 SpringBoard 记录也一致，确认系统和桌面均未重启。
- 结果仍限于本 App 定向加载；未验证全局自动注入或其他 App。

工作区中的真机证据：`../diagnostics/2026-10-02/pluginlab-build2-device-result.json`、`../diagnostics/2026-10-02/pluginlab-device-build2.png`，以及同目录的 `pluginlab-build2-before-processes.json` 和 `pluginlab-build2-after-processes.json`。这些含设备信息的原始记录不放入手机公共下载目录。

## 运行与复测

打开“插件实验室”并点击“运行五项测试”。也可由电脑通过开发连接设置 `PLUGINLAB_MODE=run` 启动本 App。每次完整复测需仅结束并重新打开此 App，因为已经安装的方法拦截不能通过卸载文件自动撤销。

报告保存在 App 的 Documents，文件名为 `PluginLab-<UUID>.json`；同时写入系统日志，subsystem 为 `com.mmd.PluginLab`，category 为 `Test`。报告分别标明模拟器或真机、定向加载方式、干净基线、每个检查结果和是否重启。模拟器成功不能替代真机成功。

“移除这五个测试插件”只移除本工程同版本的动态库和匹配过滤文件。随后重新打开本 App 才会退出内存里已经加载的插件代码。不会调用清空系统信任缓存的操作。

## 后续开发

每个插件的 `Tweak.x` 都是独立入口。改变目标时，应同时修改过滤文件和源码中的 Bundle ID 检查。将插件作用于真实目标 App 前，需要确认该 App 的类/方法、系统版本和加载环境；此实验室结果不能直接推导出任意 App 或 SpringBoard 插件均可用。
