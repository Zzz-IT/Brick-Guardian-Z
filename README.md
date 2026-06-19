# Brick Guardian Z

Brick Guardian Z 是一个为 Magisk, KernelSU 和 APatch 设计的无感、自动化防砖模块。它专注于提供高可靠性的系统守护，通过早期防卡死机制、Zygote 状态监控和双重快照对比（模块与全局脚本），在遇到启动异常（Bootloop）时自动进行精细化救砖和禁用，确保设备能够安全启动。

## 核心功能

### 1. 启动模式判定与动态超时

- 普通启动：采用标准的 `BOOT_TIMEOUT_SEC`（默认 120 秒）进行监控。
- 初次基线启动（first_baseline）：当健康快照未生成或被手动清空时触发，此模式下不执行任何救砖动作，仅用于安全建立初始健康快照。
- OTA-like 启动：当检测到系统更新或重建缓存时（通过监测 `/data/system/packages.xml` 的最后修改时间），自动延长超时到 `OTA_BOOT_TIMEOUT_SEC`（默认 600 秒），并无条件跳过 early rescue（早期救砖），避免误判。

### 2. 双重检测机制

- Zygote 状态监控：启动后台守护进程，监测 Zygote 进程的崩溃频率。当 Zygote 连续崩溃次数达到阈值，判定系统处于严重不稳定状态，立即使 service 监控提早退出并触发救砖。
- 早期救砖（Early Rescue）：在 `post-fs-data` 阶段检测到启动计数异常时，在满足普通启动前提下，直接触发救砖尝试，在 `system_server` 拉起前中断崩溃链。

### 3. 双重快照与防护策略

- 模块防护：对比健康启动时记录的模块快照，识别出新增、更新或最近启用的嫌疑模块，并在发生异常时进行精准禁用。在大范围禁用时，仅禁用非 [whitelist.conf](file:///d:/GOLANG/brick-guardian-z/config/whitelist.conf) 白名单内的模块。
- 脚本防护：对比健康启动时记录的全局脚本快照，监控 `service.d` 和 `post-fs-data.d` 下的全局脚本（跳过 symlink 链接）。异常时对嫌疑脚本执行 `chmod 0644` 禁用。在大范围禁用时，仅禁用非 [script_whitelist.conf](file:///d:/GOLANG/brick-guardian-z/config/script_whitelist.conf) 白名单内的脚本。

### 4. 渐进式分级救砖状态机

只有当实际执行了禁用等救砖动作时才会递增 `rescue_count` 计数，以此作为状态机的驱动判定：

- 精准禁用（`rescue_count` <= `TARGETED_DISABLE_THRESHOLD`）：仅禁用嫌疑模块 and 嫌疑脚本。
- 大范围禁用（`rescue_count` = `BROAD_DISABLE_THRESHOLD`）：禁用所有非白名单的模块和非白名单的脚本。
- 自我禁用（`rescue_count` = `SELF_DISABLE_THRESHOLD`）：当尝试多次仍失败，本模块自行禁用以防止守护逻辑本身成为无限重启的源头。

### 5. 日志与空间管理

- 自动清理：当系统正常启动且无任何异常时，将在下次启动时自动清空历史日志，只保留本次日志，避免日志无限膨胀。
- 日志收缩：限制日志文件的最大大小，超出 `LOG_MAX_BYTES`（默认 64KB）时自动截断。

## 兼容性

本模块为 KernelSU 优先设计，但同样兼容 Magisk 和 APatch。

- KernelSU : 主要设计与推荐运行环境。
- Magisk : 兼容标准的模块生命周期与 Action 触发。
- APatch : 兼容标准的模块生命周期与 Action 触发。

支持 Android 10 及以上系统。

## 工程目录结构

- [action.sh](file:///d:/GOLANG/brick-guardian-z/action.sh) : Action 脚本，用于在管理器中查看守护状态、快照与最近异常禁用记录
- [boot-completed.sh](file:///d:/GOLANG/brick-guardian-z/boot-completed.sh) : 启动完成后的 hook，用于清理临时状态
- [customize.sh](file:///d:/GOLANG/brick-guardian-z/customize.sh) : 模块刷入安装脚本
- [post-fs-data.sh](file:///d:/GOLANG/brick-guardian-z/post-fs-data.sh) : 早期 `post-fs-data` 阶段脚本，处理早期救砖与启动计数
- [service.sh](file:///d:/GOLANG/brick-guardian-z/service.sh) : `late_start_service` 阶段脚本，拉起 Zygote 监视器并处理超时检测
- [uninstall.sh](file:///d:/GOLANG/brick-guardian-z/uninstall.sh) : 模块卸载脚本
- [config/default.conf](file:///d:/GOLANG/brick-guardian-z/config/default.conf) : 核心参数配置（包含各超时时间、救砖阈值等）
- [config/restore-policy.conf](file:///d:/GOLANG/brick-guardian-z/config/restore-policy.conf) : 恢复策略配置
- [config/script_whitelist.conf](file:///d:/GOLANG/brick-guardian-z/config/script_whitelist.conf) : 脚本白名单，每行一个相对路径
- [config/whitelist.conf](file:///d:/GOLANG/brick-guardian-z/config/whitelist.conf) : 模块白名单，每行一个模块 ID
- [scripts/lib.sh](file:///d:/GOLANG/brick-guardian-z/scripts/lib.sh) : 通用逻辑、文件锁与配置校验等工具函数
- [scripts/boot_mode.sh](file:///d:/GOLANG/brick-guardian-z/scripts/boot_mode.sh) : 启动模式判定与有效超时时间计算
- [scripts/zygote_monitor.sh](file:///d:/GOLANG/brick-guardian-z/scripts/zygote_monitor.sh) : Zygote 状态检测守护进程
- [scripts/snapshot.sh](file:///d:/GOLANG/brick-guardian-z/scripts/snapshot.sh) : 模块与全局脚本的快照创建及对比管理
- [scripts/recovery.sh](file:///d:/GOLANG/brick-guardian-z/scripts/recovery.sh) : 核心救砖逻辑、嫌疑识别与分级决策执行
- [scripts/script_guard.sh](file:///d:/GOLANG/brick-guardian-z/scripts/script_guard.sh) : 全局脚本安全禁用及快照校验辅助逻辑

## 配置说明

配置文件支持 `KEY=VALUE` 或 `KEY = VALUE` 的写法（支持前导和尾随空格过滤）。

### 核心配置参数

- `BOOT_TIMEOUT_SEC` : 普通启动的最长等待超时时间（秒）。
- `OTA_BOOT_TIMEOUT_SEC` : OTA-like 启动时的最长等待超时时间（秒）。
- `TARGETED_DISABLE_THRESHOLD` : 精准禁用的最大尝试次数阈值。
- `BROAD_DISABLE_THRESHOLD` : 触发大范围禁用的次数阈值。
- `SELF_DISABLE_THRESHOLD` : 触发模块自我禁用的次数阈值。
- `LOG_MAX_BYTES` : 日志文件大小上限（字节）。

### 配置文件书写规范

书写 `/data/adb/modules/brick-guardian-z/config/default.conf` 时，请务必遵守以下规范：

- 支持等号两端包含空格。
- 不支持行尾（Inline）注释，任何注释必须单独写在一行，否则注释符号和文本会被一并解析为配置值。

正确书写示例：

```properties
# 核心参数配置
BOOT_TIMEOUT_SEC=120

# 支持等号两端包含空格
OTA_BOOT_TIMEOUT_SEC = 600
```

错误书写示例：

```properties
# 错误：不支持行尾注释，这会导致参数值被错误解析为 "120 # 启动超时时间"
BOOT_TIMEOUT_SEC=120 # 启动超时时间
```

## 安装与使用

1. 下载 ZIP 包并在 Magisk、KernelSU 或 APatch 中刷入。
2. 重启设备后即自动在后台开始守护，无需用户主动操作。
3. 可随时在管理器中点击本模块的“Action”查看状态、白名单及最近一次的异常禁用记录。

## 许可证

本项目采用 MIT 许可证。
