#!/usr/bin/env bash
# CPU temperature readings for the System Monitor card, in Celsius, one
# "key=value" per line:
#
#   temp_package=97   package / overall CPU temperature
#   temp_cpu0=94      logical CPU 0 (mapped to its physical core's sensor)
#
# Best effort: only what the machine actually exposes is printed, so the card
# can omit the temperature column entirely. Intel's coretemp driver gives one
# sensor per physical core plus a package sensor; SMT siblings share a core
# sensor, which is physically accurate. AMD's k10temp / zenpower only publish
# package-level sensors, so those machines get the package reading only.
set -uo pipefail

HWMON=/sys/class/hwmon
declare -A core_temp=()
package=""

read_coretemp() {
  local d name f label raw c
  for d in "$HWMON"/hwmon*; do
    name=$(cat "$d/name" 2>/dev/null) || continue
    [[ $name == "coretemp" ]] || continue
    for f in "$d"/temp*_input; do
      [[ -r $f ]] || continue
      label=$(cat "${f%_input}_label" 2>/dev/null) || continue
      raw=$(cat "$f" 2>/dev/null) || continue
      [[ $raw =~ ^[0-9]+$ ]] || continue
      c=$(( raw / 1000 ))
      (( c > 0 && c < 150 )) || continue
      if [[ $label == "Package id 0" ]]; then
        package=$c
      elif [[ $label =~ ^Core\ ([0-9]+)$ ]]; then
        core_temp[${BASH_REMATCH[1]}]=$c
      fi
    done
    return 0
  done
  return 1
}

read_package_sensor() {
  local d name f label raw c
  for d in "$HWMON"/hwmon*; do
    name=$(cat "$d/name" 2>/dev/null) || continue
    case "$name" in
      k10temp|zenpower) ;;
      *) continue ;;
    esac
    for f in "$d"/temp*_input; do
      [[ -r $f ]] || continue
      label=$(cat "${f%_input}_label" 2>/dev/null) || continue
      case "$label" in
        Tctl|Tdie) ;;
        *) continue ;;
      esac
      raw=$(cat "$f" 2>/dev/null) || continue
      [[ $raw =~ ^[0-9]+$ ]] || continue
      c=$(( raw / 1000 ))
      (( c > 0 && c < 150 )) || continue
      package=$c
      return 0
    done
  done
  return 1
}

read_thermal_zone() {
  local z type raw c
  for z in /sys/class/thermal/thermal_zone*; do
    [[ -r $z/type && -r $z/temp ]] || continue
    type=$(cat "$z/type" 2>/dev/null) || continue
    [[ $type == "x86_pkg_temp" ]] || continue
    raw=$(cat "$z/temp" 2>/dev/null) || continue
    [[ $raw =~ ^[0-9]+$ ]] || continue
    c=$(( raw / 1000 ))
    (( c > 0 && c < 150 )) || continue
    package=$c
    return 0
  done
  return 1
}

if ! read_coretemp; then
  read_package_sensor || read_thermal_zone || true
fi

# A package sensor is not guaranteed even when per-core sensors exist; the
# hottest core is a fair stand-in for the overall reading.
if [[ -z $package ]] && (( ${#core_temp[@]} > 0 )); then
  for c in "${core_temp[@]}"; do
    (( c > ${package:-0} )) && package=$c
  done
fi

# Map each logical CPU to its physical core via topology. core_id matches the
# "Core N" label coretemp uses; thread_siblings_list is the fallback.
declare -A cpu_temp=()
if (( ${#core_temp[@]} > 0 )); then
  for c in /sys/devices/system/cpu/cpu[0-9]*; do
    [[ -d $c/topology ]] || continue
    n=${c##*cpu}
    [[ $n =~ ^[0-9]+$ ]] || continue
    core=$(cat "$c/topology/core_id" 2>/dev/null || true)
    if [[ ! $core =~ ^[0-9]+$ ]] || [[ -z ${core_temp[$core]:-} ]]; then
      siblings=$(cat "$c/topology/thread_siblings_list" 2>/dev/null || true)
      core=${siblings%%,*}
    fi
    [[ $core =~ ^[0-9]+$ ]] || continue
    [[ -n ${core_temp[$core]:-} ]] || continue
    cpu_temp[$n]=${core_temp[$core]}
  done
fi

[[ -n $package ]] && printf 'temp_package=%d\n' "$package"
if (( ${#cpu_temp[@]} > 0 )); then
  while read -r n; do
    printf 'temp_cpu%s=%s\n' "$n" "${cpu_temp[$n]}"
  done < <(printf '%s\n' "${!cpu_temp[@]}" | sort -n)
fi
