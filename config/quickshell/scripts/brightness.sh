#!/usr/bin/env bash

cur=$(brightnessctl get)
max=$(brightnessctl max)
min=$((max * 5 / 100))

case "${1:-}" in
  up)
    brightnessctl set +1%
    ;;
  down)
    next=$((cur - max / 100))
    if [ "$next" -lt "$min" ]; then
      next=$min
    fi
    brightnessctl set "$next"
    ;;
esac
