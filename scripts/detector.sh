#!/system/bin/sh
# KSU Safe Guardian detector.sh

# 启动卡死（Bootloop）检测逻辑主要由 healthcheck.sh 中的 wait_healthy 循环处理，
# 并由 service.sh 调用执行。
# 此文件保留供未来添加高级或自定义崩溃检测触发器使用。
