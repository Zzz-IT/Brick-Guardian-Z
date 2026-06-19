# Brick Guardian Z

Brick Guardian Z 是一个为 Magisk、KernelSU 和 APatch 设计的无感、自动化防砖守护模块。它通过启动模式判定、健康采样、Zygote 稳定性检测、模块快照和全局脚本快照，在启动异常时按阶段自动禁用嫌疑项，帮助系统恢复到可启动状态。

本模块不会自动恢复任何模块或脚本。被禁用的模块或脚本应由用户在 Root 管理器或终端中手动恢复。

## 核心功能

### 1. 启动模式判定与动态超时

Brick Guardian Z 会根据启动环境选择不同的等待时间：

- 普通启动：使用 `BOOT_TIMEOUT_SEC`，默认 `120` 秒。
- 首次基线启动：当尚未记录健康系统版本时，使用 `FIRST_BOOT_TIMEOUT_SEC`，默认 `360` 秒；此模式下跳过 early rescue，用于安全建立初始健康快照。
- OTA-like 启动：当当前 `ro.system.build.version.incremental` 与上次健康启动记录的系统版本不同，使用 `OTA_BOOT_TIMEOUT_SEC`，默认 `900` 秒；此模式下固定跳过 early rescue，避免系统升级或缓存重建期间误判。
- OTA-like 后续异常启动：当 OTA-like 启动不是第一次尝试时，使用 `OTA_RESCUE_TIMEOUT_SEC`，默认 `360` 秒。

### 2. 双重检测机制

- 健康采样：系统需要连续满足健康条件，包括 `sys.boot_completed=1`、`system_server` 存在、`bootanim=stopped` 或 `dev.bootcomplete=1`。
- Zygote 稳定性检测：普通启动且异常启动次数达到阈值后，会观察 `zygote64` 和 `zygote` 的 PID 快照。如果短时间内 Zygote 反复重启，会提前进入救砖判定。

默认 Zygote 参数：

```properties
ZYGOTE_MONITOR_WINDOW_SEC=45
ZYGOTE_RESTART_THRESHOLD=3
ZYGOTE_MIN_ATTEMPT=2
```

Zygote 检测与健康采样共用 `HEALTH_SAMPLE_INTERVAL_SEC`，不单独提供 Zygote 采样间隔配置。

### 3. Early Rescue

Early Rescue 只在普通启动模式下启用。

在 `post-fs-data` 阶段，如果异常启动次数达到阈值，模块会尝试提前执行救砖动作：

- 第 2～3 次异常：精准禁用嫌疑模块和嫌疑脚本。
- 第 4 次异常：大范围禁用非白名单模块和非白名单脚本。
- 第 5 次异常：Brick Guardian Z 自我禁用。

首次基线启动和 OTA-like 启动会固定跳过 Early Rescue。

### 4. 模块快照与脚本快照

健康启动后，模块会记录：

- 已安装模块的健康快照。
- 全局脚本的健康快照。

模块快照用于识别：

- 新安装模块。
- 刚启用模块。
- 更新或修改过的模块。

脚本快照用于识别：

- 新增脚本。
- 修改过的脚本。
- 从不可执行变为可执行的脚本。

脚本保护范围包括：

```text
/data/adb/service.d
/data/adb/post-fs-data.d
/data/adb/post-mount.d
/data/adb/boot-completed.d
```

脚本处理方式为 `chmod 0644`，不会删除脚本，不会 `chmod 000`，不会自动恢复脚本执行权限，并且会跳过 symlink。

### 5. 分级救砖状态机

状态机由 `boot_attempts` 驱动：

- `TARGETED_RECOVERY_THRESHOLD=2`：进入精准禁用阶段。
- `BROAD_RECOVERY_THRESHOLD=4`：进入大范围禁用阶段。
- `SELF_DISABLE_THRESHOLD=5`：进入自我禁用阶段。

`rescue_count` 只统计实际执行过的救砖动作次数，例如禁用模块、禁用脚本或自我禁用。它不是状态机驱动计数。

### 6. 白名单

模块白名单：

```text
config/whitelist.conf
```

脚本白名单：

```text
config/script_whitelist.conf
```

大范围禁用和精准禁用都会尊重白名单。

### 7. 日志管理

日志会自动轮转并限制大小。系统健康启动后，模块会在下次启动时清理历史日志，避免长期占用存储空间。

## 默认配置

```properties
ENABLED=1

BOOT_TIMEOUT_SEC=120
FIRST_BOOT_TIMEOUT_SEC=360
OTA_BOOT_TIMEOUT_SEC=900
OTA_RESCUE_TIMEOUT_SEC=360

HEALTH_STABLE_SAMPLES=3
HEALTH_SAMPLE_INTERVAL_SEC=5

ENABLE_EARLY_RESCUE=1

ENABLE_ZYGOTE_MONITOR=1
ZYGOTE_MONITOR_WINDOW_SEC=45
ZYGOTE_RESTART_THRESHOLD=3
ZYGOTE_MIN_ATTEMPT=2

TARGETED_RECOVERY_THRESHOLD=2
BROAD_RECOVERY_THRESHOLD=4
SELF_DISABLE_THRESHOLD=5

ALLOW_BROAD_DISABLE=1
ALLOW_SELF_DISABLE=1

ALLOW_TARGETED_MODULE_DISABLE=1
ALLOW_BROAD_MODULE_DISABLE=1

ALLOW_TARGETED_SCRIPT_DISABLE=1
ALLOW_BROAD_SCRIPT_DISABLE=1
```

## 工程目录结构

- `action.sh` : Action 脚本，用于在管理器中查看守护状态、快照与最近异常禁用记录
- `boot-completed.sh` : 启动完成后的 hook，用于清理临时状态
- `customize.sh` : 模块刷入安装脚本
- `post-fs-data.sh` : 早期 `post-fs-data` 阶段脚本，处理早期救砖与启动计数
- `service.sh` : `late_start_service` 阶段脚本，拉起 Zygote 监视器并处理超时检测
- `uninstall.sh` : 模块卸载脚本
- `config/default.conf` : 核心参数配置（包含各超时时间、救砖阈值等）
- `config/script_whitelist.conf` : 脚本白名单，每行一个相对路径
- `config/whitelist.conf` : 模块白名单，每行一个模块 ID
- `scripts/lib.sh` : 通用逻辑、文件锁与配置校验等工具函数
- `scripts/boot_mode.sh` : 启动模式判定与有效超时时间计算
- `scripts/zygote_monitor.sh` : Zygote 状态检测守护进程
- `scripts/snapshot.sh` : 模块与全局脚本的快照创建及对比管理
- `scripts/recovery.sh` : 核心救砖逻辑、嫌疑识别与分级决策执行
- `scripts/script_guard.sh` : 全局脚本安全禁用及快照校验辅助逻辑

## 兼容性

本模块为 KernelSU 优先设计，但同样兼容 Magisk 和 APatch。

- KernelSU : 主要设计与推荐运行环境。
- Magisk : 兼容标准的模块生命周期与 Action 触发。
- APatch : 兼容标准的模块生命周期与 Action 触发。

支持 Android 10 及以上系统。

## 不会做的事

Brick Guardian Z 不会：

- 自动恢复模块。
- 自动恢复脚本执行权限。
- 联网下载或执行代码。
- 在线检查更新。
- 修改 system、vendor 或 product 分区。
- 接管 `/data/adb/modules_update`。
- 删除 `package-restrictions.xml`。
- 继承旧版模块状态。
- 处理旧版恢复队列。
- 对全局脚本目录执行 `chmod 000`。
- 删除用户脚本。

## 许可证

本项目采用 MIT 许可证。
