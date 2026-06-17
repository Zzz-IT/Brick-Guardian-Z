#!/system/bin/sh
# KSU Safe Guardian lib.sh

# 如果 MODDIR 尚未设置，则基于脚本当前位置推断
if [ -z "$MODDIR" ]; then
  MODDIR="$(dirname "$(dirname "$(readlink -f "$0")")")"
fi

rotate_log() {
  local log_file="$MODDIR/logs/guardian.log"
  if [ -f "$log_file" ]; then
    local size=$(stat -c %s "$log_file" 2>/dev/null || echo 0)
    if [ "$size" -gt 512000 ]; then
      mv -f "$log_file" "$log_file.bak"
    fi
  fi
}

log_info() {
  rotate_log
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] $1" >> "$MODDIR/logs/guardian.log"
}

log_warn() {
  rotate_log
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] [WARN] $1" >> "$MODDIR/logs/guardian.log"
}

log_error() {
  rotate_log
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] $1" >> "$MODDIR/logs/guardian.log"
}

get_config() {
  local key="$1"
  local default_val="$2"
  local val
  if [ -f "$MODDIR/config/default.conf" ]; then
    val=$(grep "^${key}=" "$MODDIR/config/default.conf" | cut -d'=' -f2)
  fi
  if [ -n "$val" ]; then
    echo "$val"
  else
    echo "$default_val"
  fi
}

is_whitelisted() {
  local id="$1"
  if [ -f "$MODDIR/config/whitelist.conf" ]; then
    if grep -Fxq "${id}" "$MODDIR/config/whitelist.conf"; then
      return 0
    fi
  fi
  # 如果已经导入，同时检查旧版白名单
  if [ -f "$MODDIR/quarantine/legacy/whitelist.conf" ]; then
    if grep -Fxq "${id}" "$MODDIR/quarantine/legacy/whitelist.conf"; then
      return 0
    fi
  fi
  return 1
}

is_valid_module_id() {
  local id="$1"
  # 官方要求：首字符为字母，其余为字母、数字、下划线、破折号或点号
  echo "$id" | grep -Eq '^[a-zA-Z][a-zA-Z0-9._-]+$'
}
