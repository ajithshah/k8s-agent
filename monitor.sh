#!/bin/bash

CGROUP_MEM_USAGE="/sys/fs/cgroup/memory.current"
CGROUP_MEM_LIMIT="/sys/fs/cgroup/memory.max"
CGROUP_CPU_STAT="/sys/fs/cgroup/cpu.stat"
CGROUP_V1_MEM_USAGE="/sys/fs/cgroup/memory/memory.usage_in_bytes"
CGROUP_V1_MEM_LIMIT="/sys/fs/cgroup/memory/memory.limit_in_bytes"
CGROUP_V1_CPU="/sys/fs/cgroup/cpuacct/cpuacct.usage"

get_mem() {
  if [ -f "$CGROUP_MEM_USAGE" ]; then
    used=$(cat "$CGROUP_MEM_USAGE")
    limit=$(cat "$CGROUP_MEM_LIMIT")
    [ "$limit" = "max" ] && limit=$(awk '/MemTotal/{print $2*1024}' /proc/meminfo)
    used_mb=$((used / 1024 / 1024))
    limit_mb=$((limit / 1024 / 1024))
    pct=$(echo "scale=1; $used * 100 / $limit" | bc)
    echo "Used: ${used_mb} MB / ${limit_mb} MB (${pct}%)"
  elif [ -f "$CGROUP_V1_MEM_USAGE" ]; then
    used=$(cat "$CGROUP_V1_MEM_USAGE")
    limit=$(cat "$CGROUP_V1_MEM_LIMIT")
    used_mb=$((used / 1024 / 1024))
    limit_mb=$((limit / 1024 / 1024))
    pct=$(echo "scale=1; $used * 100 / $limit" | bc)
    echo "Used: ${used_mb} MB / ${limit_mb} MB (${pct}%)"
  else
    echo "cgroup memory stats not available"
  fi
}

get_cpu() {
  if [ -f "$CGROUP_CPU_STAT" ]; then
    t1=$(grep '^usage_usec' "$CGROUP_CPU_STAT" | awk '{print $2}')
    sleep 1
    t2=$(grep '^usage_usec' "$CGROUP_CPU_STAT" | awk '{print $2}')
    pct=$(echo "scale=1; ($t2 - $t1) / 10000" | bc)
    echo "Usage: ${pct}%"
  elif [ -f "$CGROUP_V1_CPU" ]; then
    t1=$(cat "$CGROUP_V1_CPU")
    sleep 1
    t2=$(cat "$CGROUP_V1_CPU")
    pct=$(echo "scale=1; ($t2 - $t1) / 10000000" | bc)
    echo "Usage: ${pct}%"
  else
    echo "cgroup cpu stats not available"
  fi
}

# Accumulate memory by growing a bash variable ~20MB per iteration
pressure=""
iter=0

while true; do
  iter=$((iter + 1))
  echo "=== $(date) === [iteration $iter]"
  echo "-- Memory --"
  get_mem
  echo "-- CPU --"
  get_cpu

  # Grow pressure by ~20MB — bash holds this string in process memory
  pressure="${pressure}$(head -c 20971520 /dev/zero | tr '\0' 'A')"
  echo "Allocated pressure: $((iter * 20)) MB"
  echo ""
done
