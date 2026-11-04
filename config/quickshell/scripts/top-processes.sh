#!/usr/bin/env bash
# Top six processes for the System Monitor card, as CPU% <tab> MEM% <tab> name.
# Batch top needs two samples: the first screen has no previous delta, so its
# %CPU is the process lifetime average instead of current load.
set -euo pipefail

mode="${1:-cpu}"
case "$mode" in
  cpu) sort_key="%CPU" ;;
  mem) sort_key="%MEM" ;;
  *)
    printf 'usage: %s {cpu|mem}\n' "$0" >&2
    exit 2
    ;;
esac

# Never close the pipe early (head/exit would SIGPIPE top under pipefail);
# print the first six rows and let both processes finish cleanly.
top -b -n 2 -d 0.3 -o "$sort_key" -w 512 2>/dev/null \
  | awk '/^ *PID/ { n++; next }
    n == 2 && NF >= 12 && shown < 6 {
      shown++
      printf "%s\t%s\t", $9, $10
      for (i = 12; i <= NF; i++) printf "%s%s", $i, (i < NF ? " " : "")
      printf "\n"
    }'
