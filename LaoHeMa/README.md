# 老河马

独立的 iPhone / iPad App，显示名称“老河马”，应用标识 `com.mmd.LaoHeMa`。首页只有一个按钮：iPhone 和 iPad 均显示“测试”，运行时显示“测试中”，成功或已有活动环境时显示“ok”。按钮仍执行完整越狱流程，文案变化不代表只读检查。没有广告、推广标语、更新检查或额外设置入口。

## 工程边界

打开 `LaoHeMa.xcodeproj`，使用 `LaoHeMa` scheme。新 App 有自己的入口、界面、宿主适配、版本和偏好文件，可与原 Dopamine 同时安装。它只消费导出的 `DopamineSDK`，不引用原 Xcode 工程或私有核心头文件，不编译或链接 Dopamine 原 UI。独立 App 并不意味着只复制一个静态库就能运行：工程仍需要完整核心依赖、漏洞组件、资源包和原有权限/安装条件。

`LMCoreHost` 提供资源、配置、日志和本地化；`LMJailbreakController` 通过公开 `DOEngine` 调用完整流程，成功后根据结构化结果调用 `finalize`。显示版本为 1.0.0，核心使用的运行环境版本保持 3.0.10，避免品牌版本影响环境迁移判断。

原有 `DOExploit` / `DOExploitManager` / `DOEnvironmentManager` 的机型、芯片、系统版本、版本例外、PAC/PPL 要求和自动优先级逻辑不变。新包带齐 9 个漏洞 framework、11 个变体；不是只固定当前研究机的 physpuppet / dmaFail 组合。兼容范围以当前核心和组件元数据为准，不以品牌文案或模拟器型号推断。

## 默认行为

- 用户点击按钮才执行流程；启动、显示页面和只读诊断均不会启动漏洞利用。
- 已有本 App 或其他工具建立的活动环境时禁用按钮，避免重复执行。
- 新环境默认安装 Sileo；已有环境保留原有包管理器。所有原版运行资源和两个包管理器包仍完整携带。
- 保留已有安全模式选择；全新环境采用原版插件注入默认值。不开启 idownload，不提供移除环境功能，不启用开机图片。
- 保留原版的完整收尾和用户空间重启，不启用 `DOPAMINE_NO_REBOOT_TEST`。旧的不重启实验版由原 `DopamineCore/build-app.sh` 单独保留。
- 需要连续内存准备的设备保留原有处理：出现说明后由用户选择继续，桌面重启后重新打开 App。不能承诺这些原本就需要额外准备的设备一次点击完全无中断。
- 失败后保留错误并要求重新打开 App，避免在残留全局状态的进程中重跑。
- 运行日志写入本 App Documents 的 `latest.log`，下次启动保留为 `previous.log`；同时记录系统日志 `com.mmd.LaoHeMa / Jailbreak`。这些本地记录不上传。

## 构建与检查

先按主仓库流程准备 BaseBin、Packages、bootstrap 和其他原有构建依赖，再从仓库根目录运行：

```sh
LaoHeMa/build.sh
LaoHeMa/Tests/run.sh
python3 LaoHeMa/Tests/check_compatibility.py --baseline 16ca07b
```

输出为 `.build/laohema/LaoHeMa-1.0.0-build4.ipa`。构建脚本只编译和打包，不安装到手机、不启动 App，也不发布文件。`LDID` 可指定签名工具，否则使用现有 `.build/tools/ldid/ldid`。与原版一致保留 entitlements；本轮研究机使用 TrollStore 安装，新名称不会扩大可安装系统范围。

`DopamineCore/build-sdk.sh` 生产完整 SDK；`tools/project.py` 生成只有 App 源码和 SDK 链接配置的消费工程。运行资源与许可由 SDK 提供。`tools/package.py` 对照 SDK 清单验证组件、元数据、资源、权限、Mach-O 签名页及 ZIP 完整性。

只读诊断启动环境变量为 `LAOHEMA_DIAGNOSTICS=1`，结果写入系统日志，前缀 `[LAOHEMA_DIAGNOSTICS]`。`jailbreak_active` 表示本应用获准访问对应的管理服务；`environment_active` 同时包含其他工具建立的活动环境。原服务按创建时的 App 标识限制管理接口，新 App 不会改写既有服务权限。

## 本轮与历史验证

build 4 完成 SDK 消费边界及实体设备无界面入口接入，保留“测试 → ok”界面。`--core-status` 只读，`--core-run` 调用完整引擎，`--core-prepare` 仅执行所需准备。新包真机回归按 `Regression/README.md` 执行；下面的历史结果不能代替本轮验收。

2026-10-02：独立 App 构建、签名与包完整性检查通过。9 个组件、11 个变体的兼容元数据与上游源文件一致；六个核心流程/兼容源码与基线提交 `16ca07b` 逐字节相同。控制器测试覆盖重复点击、已有环境、不支持设备、资源缺失、点击前复查、准备流程取消、错误后的禁用和成功收尾策略。

模拟器只使用真实 UI 和空实现控制器，未链接越狱核心；用于检查 iPhone/iPad 文案、按钮数量、可见范围与状态，不能当作对应芯片的越狱测试。build 1 已在 iPhone 13／iOS 16.2 完成安装和只读验收。随后从未越狱状态执行时，在 bootstrap 包版本比较处因缺少 `NSString (Version)` 实现而崩溃；已有活动环境让重新打开后的按钮显示“已解放”，但完整收尾和用户空间重启尚未完成。

2026-10-03：build 2 将原有 `NSString+Version.m` 纳入共享核心，保留 `-ObjC` 分类加载，同时从原 App 的源文件阶段移除，避免重复编译。打包和核心边界检查要求实际方法实现存在；启动前也验证方法可用，缺失时阻止执行。只读诊断新增 `version_comparison_available`。已通过构建、签名、资源、核心边界、控制器和兼容配置检查；静态库分类加载回归测试通过，旧 build 1 的二进制会被新增打包检查拒绝。不更改原有漏洞算法和兼容判断。

同日 build 2 已在 iPhone 13／iOS 16.2 上通过从未越狱状态恢复环境的完整流程：12:40:55 开始，12:40:58 完成收尾并主动请求用户空间重启。系统记录调用方为老河马启动的 `jbctl`；重启前后内核启动标识相同，桌面进程重新启动。重新打开后的只读检查确认 `jailbreak_active=true`、资源完整、版本比较组件可用，未发现新增的 App 崩溃或内核崩溃报告。此次复用了已安装的 bootstrap；首次安装 bootstrap、其他机型和插件功能不在本次验收范围。证据保存在本地忽略目录 `diagnostics/2026-10-03/laohema-build2-full-flow/verification.json`。

## 许可

遵循仓库 MIT 及各第三方组件自身许可。原版权与许可文本随 App 完整保留，在 iOS 系统“设置 → 老河马”中可查看。新品牌不代表上游作者背书。

This product includes software developed by the Sileo Team.
