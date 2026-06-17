#!/system/bin/sh
# Brick Guardian Z 核心库函数

# 测试环境注入桩
export ADB_ROOT="${ADB_ROOT:-/data/adb}"

if [ -z "$MODDIR" ]; then
  MODDIR="$(dirname "$(dirname "$(readlink -f "$0")")")"
fi

LOG_MAX_BYTES="${LOG_MAX_BYTES:-262144}"
LOG_MAX_BACKUPS="${LOG_MAX_BACKUPS:-3}"

rotate_log() {
  local log_file="$MODDIR/logs/guardian.log"
  local size

  mkdir -p "$MODDIR/logs" 2>/dev/null

  [ -f "$log_file" ] || return 0

  size="$(wc -c < "$log_file" 2>/dev/null || echo 0)"
  case "$size" in
    ''|*[!0-9]*) size=0 ;;
  esac

  [ "$size" -gt "$LOG_MAX_BYTES" ] || return 0

  rm -f "$log_file.$LOG_MAX_BACKUPS" 2>/dev/null

  local i="$LOG_MAX_BACKUPS"
  while [ "$i" -gt 1 ]; do
    local prev=$((i - 1))
    [ -f "$log_file.$prev" ] && mv -f "$log_file.$prev" "$log_file.$i" 2>/dev/null
    i=$prev
  done

  mv -f "$log_file" "$log_file.1" 2>/dev/null
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
  local default_val="${2:-}"
  local val=""

  if [ -f "$MODDIR/config/default.conf" ]; then
    val="$(
      awk -F= -v key="$key" '
        /^[[:space:]]*#/ {next}
        NF >= 2 {
          k=$1
          v=$0
          sub(/^[^=]*=/, "", v)
          gsub(/^[[:space:]]+|[[:space:]]+$/, "", k)
          gsub(/^[[:space:]]+|[[:space:]]+$/, "", v)
          if (k == key) {
            print v
            exit
          }
        }
      ' "$MODDIR/config/default.conf"
    )"
  fi

  if [ -n "$val" ]; then
    echo "$val"
  else
    echo "$default_val"
  fi
}

is_whitelisted() {
  local id="$1"
  local file="$MODDIR/config/whitelist.conf"

  is_valid_module_id "$id" || return 1
  [ -f "$file" ] || return 1

  awk -v id="$id" '
    {
      line=$0
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
    }
    line == "" {next}
    line ~ /^#/ {next}
    line == id {found=1}
    END {exit found ? 0 : 1}
  ' "$file"
}

is_guardian_self() {
  local id="$1"
  [ "$id" = "brick-guardian-z" ]
}

is_valid_module_id() {
  local id="$1"
  echo "$id" | grep -Eq '^[a-zA-Z][a-zA-Z0-9._-]+$'
}

append_unique_line() {
  local file="$1"
  local value="$2"
  [ -n "$value" ] || return 0
  if [ -f "$file" ] && grep -Fxq "$value" "$file"; then
    return 0
  fi
  echo "$value" >> "$file"
}
