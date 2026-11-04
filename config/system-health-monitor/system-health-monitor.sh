#!/usr/bin/env bash
set -u

umask 077
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/kmdot/system-health"
INTERVAL_SECONDS=10
RETENTION_DAYS=7

mkdir -p "$STATE_DIR"

while :; do
  timestamp="$(date --iso-8601=seconds)"
  logfile="$STATE_DIR/health-$(date +%F).log"

  {
    printf '\n=== sample %s ===\n' "$timestamp"
    printf '%s\n' '[uptime/load]'
    cat /proc/uptime /proc/loadavg

    printf '%s\n' '[memory]'
    printf '%s\n' '[power supply readings: sysfs units, energy uWh, power uW, voltage uV]'
    for supply in /sys/class/power_supply/*; do
      [[ -d "$supply" ]] || continue
      for field in type online status capacity energy_now energy_full energy_full_design charge_now charge_full voltage_now current_now power_now; do
        [[ -r "$supply/$field" ]] || continue
        printf '%s/%s ' "${supply##*/}" "$field"
        cat "$supply/$field" 2>/dev/null || true
      done
    done

    awk '/^(MemTotal|MemFree|MemAvailable|Buffers|Cached|SwapTotal|SwapFree|Shmem|Dirty|Writeback):/ { print }' /proc/meminfo

    printf '%s\n' '[pressure: cpu]'
    cat /proc/pressure/cpu 2>/dev/null || true
    printf '%s\n' '[pressure: memory]'
    cat /proc/pressure/memory 2>/dev/null || true
    printf '%s\n' '[pressure: io]'
    cat /proc/pressure/io 2>/dev/null || true

    printf '%s\n' '[vm counters]'
    awk '/^(oom_kill|allocstall|allocstall_normal|pgmajfault|pswpin|pswpout|pgscan_kswapd|pgsteal_kswapd) / { print }' /proc/vmstat

    printf '%s\n' '[interrupt counters: ACPI and IO-APIC]'
    awk 'NR == 1 || /acpi|IR-IO-APIC/' /proc/interrupts 2>/dev/null || true

    printf '%s\n' '[ACPI GPE counters]'
    for gpe in gpe_all sci gpe6E sci_not error; do
      gpe_file="/sys/firmware/acpi/interrupts/$gpe"
      [[ -r "$gpe_file" ]] || continue
      printf '%s ' "$gpe"
      tr '\n' ' ' < "$gpe_file"
      printf '\n'
    done

    printf '%s\n' '[block device counters]'
    awk '/nvme|dm-/' /proc/diskstats 2>/dev/null || true

    printf '%s\n' '[Intel GPU frequency and render clients]'
    seen_gpu_dirs=' '
    for freq_file in /sys/class/drm/card*-*/device/gt_cur_freq_mhz; do
      [[ -r "$freq_file" ]] || continue
      gpu_dir="$(readlink -f "${freq_file%/gt_cur_freq_mhz}")"
      [[ "$seen_gpu_dirs" == *" $gpu_dir "* ]] && continue
      seen_gpu_dirs+="$gpu_dir "
      printf '%s cur_mhz=' "${gpu_dir##*/}"
      cat "$gpu_dir/gt_cur_freq_mhz"
      if [[ -r "$gpu_dir/gt_act_freq_mhz" ]]; then
        printf '%s act_mhz=' "${gpu_dir##*/}"
        cat "$gpu_dir/gt_act_freq_mhz"
      fi
    done
    gpu_pids="$(fuser /dev/dri/renderD128 2>/dev/null || true)"
    if [[ -n "$gpu_pids" ]]; then
      for gpu_pid in $gpu_pids; do
        ps -p "$gpu_pid" -o pid,user,pcpu,comm --no-headers 2>/dev/null || true
      done
    else
      printf '%s\n' 'no render-node clients found'
    fi

    printf '%s\n' '[disk space]'
    df -Pk / "$HOME" 2>&1

    printf '%s\n' '[thermal zones: millidegrees Celsius]'
    found_thermal=0
    for zone in /sys/class/thermal/thermal_zone*; do
      [[ -r "$zone/temp" ]] || continue
      printf '%s ' "${zone##*/}"
      cat "$zone/temp"
      found_thermal=1
    done
    (( found_thermal )) || printf '%s\n' 'no readable thermal zones'

    printf '%s\n' '[CPU thermal throttle counters]'
    for counter in /sys/devices/system/cpu/cpu0/thermal_throttle/{core_throttle_count,core_throttle_total_time_ms,package_throttle_count,package_throttle_total_time_ms}; do
      [[ -r "$counter" ]] || continue
      printf '%s ' "${counter##*/}"
      cat "$counter"
    done

    printf '%s\n' '[top processes by resident memory; command names only]'
    ps -eo pid,ppid,user,pcpu,pmem,rss,vsz,stat,comm --sort=-rss | head -n 11

    printf '%s\n' '[top processes by CPU; command names only]'
    ps -eo pid,ppid,user,pcpu,pmem,rss,vsz,stat,comm --sort=-pcpu | head -n 11

    printf '%s\n' '[uninterruptible blocked tasks]'
    ps -eo pid,ppid,state,wchan:32,comm | awk 'NR == 1 || $3 ~ /D/'
  } >> "$logfile" 2>&1

  # Let normal kernel writeback flush the small append; forcing a disk sync at
  # every sample could add avoidable I/O stalls on a busy or failing drive.
  find "$STATE_DIR" -maxdepth 1 -type f -name 'health-*.log' -mtime "+$RETENTION_DAYS" -delete 2>/dev/null || true
  sleep "$INTERVAL_SECONDS"
done
