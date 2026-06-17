#!/system/bin/sh
# Brick Guardian Z uninstall.sh

# 模块自身的状态和日志文件都保存在模块目录内，
# Magisk/KernelSU 会在卸载时自动删除整个目录。
# 我们明确不在这里盲目地恢复其他模块的 'disable' 文件，
# 或重置全局脚本的 'chmod 000' 状态，
# 因为在卸载时这么做极容易触发最初导致系统崩溃的 Bootloop。

exit 0
