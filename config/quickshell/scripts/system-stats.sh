#!/usr/bin/env bash
# One line of system vitals for the quickshell bar and System Monitor card.
# CPU is the busy share between the previous poll and this one. The runtime
# cache makes the hidden->visible transition honest: a sample older than the
# guard is discarded and replaced with a short fresh delta instead of reporting
# an average over however long the widget was hidden.
set -uo pipefail

STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/kmdot"
STATE="$STATE_DIR/system-stats"
mkdir -p "$STATE_DIR" 2>/dev/null || true

read_cpu() {
  # Proc stat: cpu user nice system idle iowait irq softirq steal guest guest_nice
  read -r _ user nice system idle iowait irq softirq steal _ < /proc/stat
  total=$(( user + nice + system + idle + iowait + irq + softirq + steal ))
  idle_all=$(( idle + iowait ))
}

now=${EPOCHSECONDS:-$(date +%s)}
read_cpu
cur_total=$total
cur_idle=$idle_all

prev_ts=0
prev_total=0
prev_idle=0
if [[ -r "$STATE" ]]; then
  read -r prev_ts prev_total prev_idle < "$STATE" || true
fi

age=$(( now - prev_ts ))
if (( prev_total > 0 && age >= 0 && age <= 10 && cur_total > prev_total )); then
  d_total=$(( cur_total - prev_total ))
  d_idle=$(( cur_idle - prev_idle ))
else
  sleep 0.2
  now=${EPOCHSECONDS:-$(date +%s)}
  read_cpu
  d_total=$(( total - cur_total ))
  d_idle=$(( idle_all - cur_idle ))
  cur_total=$total
  cur_idle=$idle_all
fi

cpu=0
if (( d_total > 0 )); then
  cpu=$(( 100 * (d_total - d_idle) / d_total ))
fi
(( cpu < 0 )) && cpu=0
(( cpu > 100 )) && cpu=100

printf '%s %s %s\n' "$now" "$cur_total" "$cur_idle" > "$STATE"

mem_total=0
mem_available=0
while read -r key value _; do
  case "$key" in
    MemTotal:) mem_total=$value ;;
    MemAvailable:) mem_available=$value ;;
  esac
done < /proc/meminfo

used=$(( mem_total - mem_available ))
mem_pct=0
if (( mem_total > 0 )); then
  mem_pct=$(( 100 * used / mem_total ))
fi

read -r load1 load5 load15 _ < /proc/loadavg

threads=0
while read -r key _; do
  [[ $key =~ ^cpu[0-9]+$ ]] && (( threads++ ))
done < /proc/stat

printf 'cpu=%d\nmem_pct=%d\nmem_used_kb=%d\nmem_total_kb=%d\nthreads=%d\nload1=%s\nload5=%s\nload15=%s\n' \
  "$cpu" "$mem_pct" "$used" "$mem_total" "$threads" "$load1" "$load5" "$load15"
