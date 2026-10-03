# DopamineCore：第一轮解耦

本目录提供核心接口、独立静态库构建目标和契约测试。原界面通过 `DOAppCoreHost` 适配核心，越狱算法与原有步骤顺序保持不变。当前交付是 **build 4 不自动重启实验版**。

## 已完成的边界

- `DOCoreHost`：由入口提供配置、资源目录、报告目录、应用身份、版本、包管理器选择、开机图片数据、日志、翻译和收尾策略。
- `DOConfiguration`：每次操作开始时深复制设置；执行期间配置固定，写回设置不改变当前快照。
- `DOResult`：返回错误、移除状态、日志展示提示和后续操作。失败或完成移除时不请求重启。
- `DOCoreContext`：显式安装宿主；同进程只允许一个活动操作。操作结束释放锁。
- `DOJailbreaker.run`：原有流程的结构化入口。`finalize` 独立调用，要求成功结果；实验宏强制禁止自动用户空间重启。
- `DOCoreDiagnostics`：只读检查已有状态、资源发现、漏洞选择和运行策略，不执行漏洞、不安装环境、不重启。
- Xcode `DopamineCore` target：生成 `libDopamineCore.a`。原 App 链接静态库，核心源文件不再同时编进 App target。

核心实现暂时保留在 `Application/Dopamine/Jailbreak` 原路径，降低文件迁移对上游合并的影响；由新 target 编译。`DOPreferenceManager` 留在 App 层。`NSData+Hex.m`、`NSString+Version.m` 和 `clock_alarm.c` 为核心所需支持代码。宿主链接时必须保留 `-ObjC`，以加载静态库中的 Objective-C 分类实现。

核心源码不导入 UIKit、DOUIManager、DOPreferenceManager，不直接访问 NSBundle.mainBundle。底层 iOS 私有框架、libjailbreak、XPF、资源包以及签名/启动条件仍然必需；静态库不是任意普通 App 可直接使用的越狱授权。

## 入口适配

App 在 `main` 中先调用 `DOAppCoreHost.install`，再创建环境管理器。报告目录在权限变化前固定，避免 HOME 改变后写到错误目录。图片渲染在主线程完成，只把编码后的数据传给核心。UI 继续负责弹窗、按钮、中文展示和配置保存。

现有 `BaseBin/dopamine` 无界面工具也改用 `DOCommandLineCoreHost`，不再通过 `ui-stub` 模拟 DOUIManager。它仍依赖 Corellium 提供内核能力，不能当作当前实体 iPhone 的完整命令行越狱工具。

当前保留上游全局 primitives 和 manager 单例。宿主在一个进程中安装一次，操作按序执行；这不是可以并行创建多个独立越狱会话的 SDK。翻译仍经宿主回调以保持原界面文本，事件目前以日志文字传递，后续可以再细化阶段标识。

## 构建和检查

在已经具备本仓库原有依赖的工作区根目录执行：

```sh
DopamineCore/Tests/run.sh
DopamineCore/build-app.sh
python3 DopamineCore/Tests/check_boundaries.py --library Application/build/Build/Products/Debug-iphoneos/libDopamineCore.a
```

输出 `.build/decoupling/Dopamine-3.0.10-core-build4.ipa`。打包脚本校验 build 4、实验标识、签名 CodeDirectory 页哈希、entitlements、ZIP 完整性，并核对关键底层资源与已保存的 build 3 一致。`LDID` 可以覆盖本地签名工具路径。此脚本不安装、不发布 IPA。

独立编译普通模式核心：

```sh
xcodebuild -project Application/Dopamine.xcodeproj -scheme DopamineCore -configuration Release -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO
```

## 安装后的只读验收

用 TrollStore 覆盖安装 build 4，不重新触发越狱。电脑可带 `DOPAMINE_CORE_CHECK=1` 环境变量启动 Dopamine。原界面应显示“核心解耦测试版 · build 4”；系统日志中出现 `[CORE_DIAGNOSTICS]`，包含 build、核心接口版本、资源检测、当前越狱状态和禁止自动重启策略。

该检查证明新 App 的核心连接和只读状态查询，不能替代完整漏洞流程验证。手机重启后的重新越狱需要单独测试窗口。

2026-10-02 已在 iPhone 13 / iOS 16.2 上完成 build 4 安装后验收：界面标识、核心接口版本 1、资源发现、当前越狱状态、漏洞选择和禁止自动重启策略均符合预期。启动 App 前后系统、桌面及既有 SSH/Frida 服务的进程与启动时间未变化；未重新触发越狱。证据见 `diagnostics/2026-10-02/decoupling-build4/build4-readonly-validation.json`。

## 基线、验证与剩余工作

基线存于 `.build/decoupling/baseline`：原修改补丁、原源码、Git 状态和三个已验证 IPA 的 SHA-256。没有覆盖旧下载文件。

已通过：契约测试（配置深复制、单操作互斥、配置写回、资源路径约束、日志/翻译适配、收尾结果）、独立 target/符号依赖检查、18 个原流程调用的顺序比较、不重启 App 编译、普通模式核心编译、现有无界面工具编译。

真机环境回归结果存于 `diagnostics/2026-10-02/decoupling-build4`。两实验室仍使用之前安装的 build 2，这些测试只验证已有运行环境，不能记成 build 4 完整越狱成功。

2026-10-03，独立宿主“老河马”build 2 已通过 iPhone 13／iOS 16.2 从未越狱状态恢复环境的完整流程，含正常用户空间重启及重启后状态确认。此次复用了已有 bootstrap；它验证了新 UI、宿主适配和共享核心的完整调用链，未验证首次 bootstrap 安装或全部机型。

后续阶段：统一运行环境客户端及 ABI 版本检查；抽取两个实验室的公共组件；确认服务真正退出并回传电脑端测试结果；补齐并验证实体设备可用的无界面入口；整理可独立交付的核心及资源依赖。两个实验室仍直接使用既有运行环境接口。原有定向加载插件、内核读取、SSH/Frida 结果需要在老河马建立的环境下回归；全局自动注入尚未验证。
