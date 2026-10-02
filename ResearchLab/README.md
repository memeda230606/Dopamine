# 权限实验室

独立于 Dopamine 和 PluginLab 的研究测试 App，Bundle ID 为 `com.mmd.ResearchLab`。它使用手机现有的 Dopamine 越狱服务，不再次运行漏洞利用，不请求系统重启或桌面重启。

## 先区分权限

PluginLab build 2 的五个插件运行于宿主的 UID/EUID 501；安装及签名信任辅助进程为 UID/EUID 0。root 来自 TrollStore 的辅助进程机制，不能单独证明越狱成功或拥有内核能力。

Frida Server 和 OpenSSH 都是用户态工具。SSH root 登录、Frida 跨进程附加和内核读写是不同能力，必须分别验证。Frida 的普通调试/Gadget 模式不能替代本轮实际 Server 模式验证。

## 本轮验证

| 项目 | 实际检查 | 成功证据 |
| --- | --- | --- |
| root | 辅助进程身份、专属 root 目录文件、普通子进程执行 `id -u` | UID/EUID 0，文件 root 所有且权限 0600，写入读回清理成功，命令返回 0 |
| 内核读取 | 从现有 libjailbreak 取得访问能力并读取内核头部 4 字节 | 初始化及读取返回 0，读取值为 `0xfeedfacf` |
| OpenSSH | USB 转发到手机回环地址，专用密钥登录；SFTP 随机文件往返和删除 | 远端 `id -u` 为 0，文件字节一致且清理成功 |
| Frida | 真实 Frida Server 附加本 App，枚举模块、读取自有数据、拦截函数，再解除拦截 | `access=full`；函数输入 11 的结果依次为 22、29、22；标记和内存值匹配 |
| 不重启 | App 内启动 UUID、SpringBoard 身份及电脑独立进程记录 | 前后一致 |

内核读取使用现有越狱服务初始化所需映射；测试不调用 `kwrite`，不测试任意内核写入。不能把读测试通过记成内核写入或任意系统进程注入通过。

## 运行

用 TrollStore 安装 `build/ResearchLab-1.0.0-build2.ipa`，保持 USB 连接并打开“权限实验室”。电脑可设置 `RESEARCHLAB_MODE=run` 启动 App，或手工点击“准备并运行基础测试”。完成后 App 会显示准备状态；**服务监听成功仍需电脑端实际功能验证**。

测试服务为手工启动的独立进程，不注册开机启动项：

- 内置 Frida 17.0.7；手机已有 Frida 时保留并复用现有版本，记录其实际版本供电脑匹配。仅监听 `127.0.0.1:27042`。
- OpenSSH 9.7p1-1：仅监听 `127.0.0.1:22222`；只允许 root 的专用公钥认证，密码认证关闭。
- 电脑生成的 SSH 私钥仅存于工作区 `.build/research-private/client_key`，权限 0600；IPA 和下载源码只允许包含公钥。SSH 主机私钥在手机生成。
- 使用“停止本次测试服务”或 `RESEARCHLAB_MODE=stop` 关闭本次记录的进程；停止前核对 PID 对应的可执行文件路径。

build 2 的停止按钮只确认终止信号已发送，不能证明进程已经退出。本轮 SSH 正常退出，Frida 收到 SIGTERM 后仍在监听；电脑核对本次记录的 Frida PID 后结束该进程，并再次确认两个端口都关闭。后续测试也应以实际进程和端口状态为准。

服务状态、SSH 配置和主机密钥保存在 `/var/jb/var/root/ResearchLab`。独立 SSH 二进制保存在 `/var/jb/usr/local/lib/ResearchLab`。Frida 使用官方包的 `/var/jb/usr/sbin/frida-server` 和 `/var/jb/usr/lib/frida/frida-agent.dylib` 路径。PAM 使用官方 `/var/jb/etc/pam.d/sshd`。已有 Frida 和 PAM 配置会保留复用，Frida 文件另记实际哈希与版本；实验室专属目录内遇到不同版本文件仍会保留并报告失败。不会修改账号密码，也不会写入现有 `authorized_keys`。

该测试部署直接放置和校验固定文件，不登记 dpkg；原有 PluginLab 插件保持不变。会为本轮确实需要的已有命令和动态库逐项建立签名信任，不清空信任缓存。

## 电脑端验证

`host/test_frida.py` 使用 Frida Python API，明确拒绝 `access=jailed` 的替代路径；按 Bundle ID `com.mmd.ResearchLab` 选择运行中的 App，再由脚本确认主模块为 `ResearchLab`。显示名称会本地化，不能用英文进程显示名称定位。电脑端应匹配报告中的 `frida_server_version`；本轮在项目的独立虚拟环境 `.build/research-frida-17.19.0` 安装客户端 17.19.0，未修改全局 Frida。

```sh
python3 host/test_frida.py --output /path/to/frida-result.json
```

`host/test_ssh.py` 自行启动和关闭只绑定电脑回环地址的 USB 转发，固定验证手机端通过 USB 导出的主机公钥：

```sh
python3 host/test_ssh.py --key /path/to/client_key --host-key /path/to/phone-host-key.pub --output /path/to/ssh-result.json
```

主机公钥由准备报告的 `ssh_host_public_key` 提供。报告位于 App Documents 下的 `helper-<UUID>.json`，同时记录系统日志，subsystem 为 `com.mmd.ResearchLab`、category 为 `Test`。长日志使用 `[RESEARCHLAB_CHUNK]` 分块，电脑通过 `host/read_result.py` 重组。原始日志保留在本地，不放进手机公共下载目录。

## 编译和当前状态

需要 Xcode。`build.py` 通过 `RESEARCH_ASSETS` 指定已解包的官方依赖缓存，通过 `RESEARCH_CLIENT_PUBLIC_KEY` 指定专用公钥；默认使用当前工作区的 `.build/research-assets` 和 `.build/research-private/client_key.pub`。

```sh
python3 build.py
```

`App/JBInfo.h` 是本项目 Dopamine 的 libjailbreak 接口结构快照，供只读定位内核基址使用；更换底层 Dopamine 版本时应同步确认结构。

本地已完成构建、IPA 完整性、App 和四个附带二进制的签名、导出符号、依赖列表、Python/JavaScript 语法检查。2026-10-02，build 2 在 iPhone 13 / iOS 16.2 上完成真机验证：

- root 辅助进程 UID/EUID 为 0；root 文件写入、读回、删除及普通 `id -u` 子进程均通过。
- 内核初始化、读取返回 0，读取 4 字节得到 `0xfeedfacf`；未测试内核写入。
- OpenSSH 专用密钥实际登录 root 成功，SFTP 随机文件上传、下载、比对、删除均通过。
- 复用手机已有 Frida Server 17.19.0，匹配客户端后 `access=full`。附加实验室 App，枚举 663 个模块，读取标记和数值，函数结果按 22 → 29 → 22 变化；拦截次数为 1。
- 被附加的 App 仍为 UID/EUID 501。Frida 服务能力、App 自身身份和内核读取能力分别记录，不能混为一谈。
- 测试前后启动 UUID、launchd 和 SpringBoard 的 PID/启动时间一致；系统和桌面均未重启。仅在服务清理阶段重新启动了实验室 App。
- 本次测试服务已关闭，手机端 22222、27042 均不再监听；未设置开机自启。

完整报告：`../diagnostics/2026-10-02/researchlab-build2-verification.md`，原始结果在同目录 JSON 文件中。电脑验证结果未回写 App 界面，手机的“等待电脑验证”只表示该页面没有收到电脑结果；以本报告为准。未验证第三方 App、系统进程注入或全局插件注入。

历史：build 1 已验证 root 身份和内核读取，但服务部署因已有 Frida 文件保护而中止，普通调试/Gadget 附加也失败。build 2 复用现有 Frida 并分块导出长日志后，本轮服务功能验证全部通过。IPA 未因电脑脚本修正而重新编译，已安装的仍为 build 2。

来源：[Frida iOS 官方文档](https://frida.re/docs/ios/)、[Frida 17.0.7 官方发布](https://github.com/frida/frida/releases/tag/17.0.7)、[Procursus iOS 16 rootless 索引](https://apt.procurs.us/dists/1900/main/binary-iphoneos-arm64/)、[OpenSSH 配置文档](https://man.openbsd.org/sshd_config)。OpenSSH 安装包按仓库索引 SHA-256 校验；Frida 固定包的本地校验值为 `1bd2db276db4ba3456a3d69de30f405e9f1c053cce863b52037cfc43de071701`。
