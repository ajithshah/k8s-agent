#!/bin/bash
while true; do
  echo "=== $(date) ==="

  echo "-- Memory --"
  awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END{
    used=(t-a)/1024
    total=t/1024
    pct=(t-a)*100/t
    printf "Used: %.0f MB / %.0f MB (%.1f%%)\n", used, total, pct
  }' /proc/meminfo

  echo "-- CPU --"
  read cpu user nice sys idle rest < <(grep '^cpu ' /proc/stat)
  sleep 1
  read cpu2 user2 nice2 sys2 idle2 rest2 < <(grep '^cpu ' /proc/stat)
  total=$(( (user2+nice2+sys2+idle2) - (user+nice+sys+idle) ))
  used=$(( (user2+nice2+sys2) - (user+nice+sys) ))
  printf "Usage: %.1f%%\n" "$(echo "scale=2; $used*100/$total" | bc)"

  echo ""
  sleep 4
done
