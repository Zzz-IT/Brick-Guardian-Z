#!/system/bin/sh
# KSU Safe Guardian healthcheck.sh

is_healthy_once() {
  [ "$(getprop sys.boot_completed)" = "1" ] || return 1
  [ "$(getprop dev.bootcomplete)" = "1" ] || return 1
  [ "$(getprop init.svc.bootanim)" = "stopped" ] || return 1
  pidof system_server >/dev/null 2>&1 || return 1
  return 0
}

wait_healthy() {
  local timeout="${1:-300}"
  local stable_samples="${2:-3}"
  local sample_interval="${3:-5}"
  local stable=0
  local elapsed=0

  while [ "$elapsed" -lt "$timeout" ]; do
    if is_healthy_once; then
      stable=$((stable + 1))
      if [ "$stable" -ge "$stable_samples" ]; then
        return 0
      fi
    else
      stable=0
    fi
    sleep "$sample_interval"
    elapsed=$((elapsed + sample_interval))
  done

  return 1
}
