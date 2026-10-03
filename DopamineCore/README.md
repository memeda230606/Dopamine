# DopamineCore SDK

核心实现位于 `Implementation/`，私有压缩头文件位于 `PrivateHeaders/`。对外只有 `DOCoreHost`、`DOEngine`、`DOCoreDiagnostics` 和 `DOHandleCommandLine` 四组接口；调用者不需要原 App 的 UI、偏好管理器或核心私有头文件。

## 模块边界

- `DOCoreHost` 提供资源、配置、日志、应用身份、版本及收尾策略；配置按每次操作深复制。
- `DOEngine` 提供状态检查、连续内存准备、完整执行与收尾，内部调用原流程。六个原流程/兼容实现文件与 `16ca07b` 保持逐字节相同，只迁移位置。
- `DOResult` 区分失败、移除和成功后的用户空间重启；核心保留原有全局状态，同一进程只允许一个活动操作。
- `DOHandleCommandLine` 提供 `--core-status`、`--core-run`、`--core-prepare`。与 UI 调用同一个引擎，正常启动参数仍进入 UI；准备操作不自动串联执行。
- `RuntimeClient/` 只访问已经建立的运行环境，供实验室共用。它用与当前构建匹配的底层库 SHA-256 锁定 ABI，使用唯一的原始 `info.h`；未知库拒绝载入和结构访问。它不是适配任意 Dopamine 版本的通用协议。
- `LabSupport/` 共用日志分块、报告、启动身份、子进程与测试服务管理。服务记录绑定内核启动标识、PID、启动时间和路径，退出后确认消失。电脑结果必须匹配本轮 ID 和启动标识。

核心自身不导入 UIKit、不调用原 UI、不自行读取主 Bundle。底层 `libgrabkernel2` 使用 UIKit 的设备查询，因此完整链接仍需该系统框架；无界面入口不创建 UIApplication 或窗口。保留上游私有框架、签名及安装条件。

## 构建与交付

先按主仓库流程准备 BaseBin、Packages、bootstrap 等依赖，然后执行：

```sh
DopamineCore/build-sdk.sh
LaoHeMa/build.sh
```

SDK 输出 `.build/sdk/DopamineSDK`：公开 Headers、静态库及链接依赖、全部 Runtime、原权限、许可、Foundation 命令行示例与包含文件哈希的 `SDKManifest.json`。SDK 生产工程复用上游 9 个漏洞组件目标，不构建原 UI；消费者无原工程引用，SDK 可复制到其他目录使用。

消费者必须链接清单中的所有静态库、系统框架及动态库，保留 `-ObjC`，复制 Runtime 并提供宿主适配。SDK 不改变原有 9 个组件、11 个变体的兼容范围，不保证所有机型已实测。

`LaoHeMa` build 4 只引用 SDK。可通过启动参数调用实体设备的无界面入口；示例 `Examples/main.m` 也可单独链接为命令行工具。旧 `BaseBin/dopamine` Corellium 专用入口保持兼容，不作为实体设备验证依据。

旧 `build-app.sh` 仍构建原 UI 的不自动重启实验包，与老河马完整流程包分开保留。

## 回归

```sh
DopamineCore/Tests/run.sh
LaoHeMa/Tests/run.sh
python3 DopamineCore/Tests/standalone_sdk.py
python3 DopamineCore/Tests/check_boundaries.py --library .build/sdk/DopamineSDK/Lib/libDopamineCore.a
python3 LaoHeMa/Tests/check_compatibility.py --baseline 16ca07b
```

`standalone_sdk.py` 把 SDK 和消费工程复制到仓库之外再编译，同时验证命令行工具不依赖 Corellium、不调用 UIApplicationMain。另有 `Tests/cli.m`、`LabSupport/Tests/contracts.m` 覆盖命令行分支、失败不收尾、大输出、超时、PID 复用保护、服务退出及回传结果归属。

本轮真机回归按 `Regression/README.md` 执行。旧 build 2 已验证 iPhone 13 / iOS 16.2 的完整环境恢复及用户空间重启；不能用旧结果替代本轮 build 4 的验证。首次 bootstrap 安装与其他硬件需独立测试设备，不通过清空当前研究机强行覆盖。
