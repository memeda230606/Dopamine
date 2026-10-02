# 老河马

独立的 iPhone / iPad App，显示名称“老河马”，应用标识 `com.mmd.LaoHeMa`。首页只有一个按钮：iPhone 显示“解放 iPhone”，iPad 显示“解放 iPad”；运行时显示“正在解放”，已有环境时显示“已解放”。没有广告、推广标语、更新检查或额外设置入口。

## 工程边界

打开 `LaoHeMa.xcodeproj`，使用 `LaoHeMa` scheme。新 App 有自己的入口、界面、宿主适配、版本和偏好文件，可与原 Dopamine 同时安装。它直接依赖上层仓库中的 `DopamineCore` 和全部原有漏洞 target，不编译或链接 Dopamine 原 UI。独立 App 并不意味着只复制一个静态库就能运行：工程仍需要完整核心依赖、漏洞组件、资源包和原有权限/安装条件。

`LMCoreHost` 提供资源、配置、日志和本地化；`LMJailbreakController` 调用完整 `DOJailbreaker.run`，成功后根据结构化结果调用 `finalize`。显示版本为 1.0.0，核心使用的运行环境版本保持 3.0.10，避免品牌版本影响环境迁移判断。

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

输出为 `.build/laohema/LaoHeMa-1.0.0-build1.ipa`。构建脚本只编译和打包，不安装到手机、不启动 App，也不发布文件。`LDID` 可指定签名工具，否则使用现有 `.build/tools/ldid/ldid`。与原版一致保留 entitlements；本轮研究机使用 TrollStore 安装，新名称不会扩大可安装系统范围。

`tools/project.py` 根据原 App 的 target 依赖生成独立 Xcode 工程；新增上游漏洞 target 后重新生成即可纳入，检查脚本会核对依赖集合。`tools/runtime.py` 从原资源阶段自动收集运行资源及许可文本，省略原界面素材。`tools/package.py` 校验全部组件、元数据、资源、权限、Mach-O 签名页及 ZIP 完整性。

只读诊断启动环境变量为 `LAOHEMA_DIAGNOSTICS=1`，结果写入系统日志，前缀 `[LAOHEMA_DIAGNOSTICS]`。`jailbreak_active` 表示本应用获准访问对应的管理服务；`environment_active` 同时包含其他工具建立的活动环境。原服务按创建时的 App 标识限制管理接口，新 App 不会改写既有服务权限。

## 验证状态

2026-10-02：独立 App 构建、签名与包完整性检查通过。9 个组件、11 个变体的兼容元数据与上游源文件一致；六个核心流程/兼容源码与基线提交 `16ca07b` 逐字节相同。控制器测试覆盖重复点击、已有环境、不支持设备、资源缺失、点击前复查、准备流程取消、错误后的禁用和成功收尾策略。

模拟器只使用真实 UI 和空实现控制器，未链接越狱核心；用于检查 iPhone/iPad 文案、按钮数量、可见范围与状态，不能当作对应芯片的越狱测试。新 IPA 的手机安装、只读验收及冷启动后的完整流程仍待完成；没有声称全部支持机型已逐一真机验证。

## 许可

遵循仓库 MIT 及各第三方组件自身许可。原版权与许可文本随 App 完整保留，在 iOS 系统“设置 → 老河马”中可查看。新品牌不代表上游作者背书。

This product includes software developed by the Sileo Team.
