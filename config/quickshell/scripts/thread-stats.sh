#!/usr/bin/env bash
# Per-logical-CPU busy percentages for the System Monitor card, one per line
# ("cpu0=12"). Polled only while the card is open. Deltas come from a runtime
# cache; a cache older than the guard is discarded so the first sample after
# reopening the card describes now instead of the gap.
set -uo pipefail

STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/kmdot"
STATE="$STATE_DIR/thread-stats"
mkdir -p "$STATE_DIR" 2>/dev/null || true

now=${EPOCHSECONDS:-$(date +%s)}

read_counters() {
  local -n _total=$1
  local -n _idle=$2
  local key user nice system idle iowait irq softirq steal _
  _total=()
  _idle=()
  while read -r key user nice system idle iowait irq softirq steal _; do
    [[ $key =~ ^cpu[0-9]+$ ]] || continue
    _total[$key]=$(( user + nice + system + idle + iowait + irq + softirq + steal ))
    _idle[$key]=$(( idle + iowait ))
  done < /proc/stat
}

declare -A prev_total=()
declare -A prev_idle=()
prev_ts=0
if [[ -r "$STATE" ]]; then
  read -r prev_ts < "$STATE" || true
  while read -r key total idle; do
    [[ $key =~ ^cpu[0-9]+$ ]] || continue
    prev_total[$key]=$total
    prev_idle[$key]=$idle
  done < <(tail -n +2 "$STATE")
fi

declare -A cur_total=()
declare -A cur_idle=()
read_counters cur_total cur_idle

age=$(( now - prev_ts ))
stale=1
if (( age >= 0 && age <= 5 )) && (( ${#prev_total[@]} > 0 )); then
  stale=0
  for key in "${!cur_total[@]}"; do
    if [[ -z "${prev_total[$key]:-}" ]]; then
      stale=1
      break
    fi
  done
fi

if (( stale )); then
  sleep 0.2
  now=${EPOCHSECONDS:-$(date +%s)}
  prev_total=()
  prev_idle=()
  for key in "${!cur_total[@]}"; do
    prev_total[$key]=${cur_total[$key]}
    prev_idle[$key]=${cur_idle[$key]}
  done
  read_counters cur_total cur_idle
fi

{
  printf '%s\n' "$now"
  for key in "${!cur_total[@]}"; do
    printf '%s %s %s\n' "$key" "${cur_total[$key]}" "${cur_idle[$key]}"
  done
} > "$STATE"

for key in "${!cur_total[@]}"; do
  d_total=$(( ${cur_total[$key]} - ${prev_total[$key]:-0} ))
  d_idle=$(( ${cur_idle[$key]} - ${prev_idle[$key]:-0} ))
  pct=0
  if (( d_total > 0 )); then
    pct=$(( 100 * (d_total - d_idle) / d_total ))
  fi
  (( pct < 0 )) && pct=0
  (( pct > 100 )) && pct=100
  printf '%s=%d\n' "$key" "$pct"
done | sort -V
