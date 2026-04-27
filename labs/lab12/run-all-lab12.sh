#!/usr/bin/env bash
set -euo pipefail

# Runs Lab 12 commands and stores outputs under labs/lab12/.
# Requires: sudo, containerd, nerdctl, curl, jq, awk, zstd

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LAB="${ROOT}/labs/lab12"

mkdir -p "${LAB}"/{setup,runc,kata,isolation,bench,analysis}

echo "[lab12] Task 1: install kata assets (GitHub release)"
sudo bash "${LAB}/scripts/install-kata-assets.sh"

echo "[lab12] Task 1: configure containerd for kata runtime"
sudo bash "${LAB}/scripts/configure-containerd-kata.sh"
sudo systemctl restart containerd

echo "[lab12] Task 1: kata test run"
sudo nerdctl run --rm --runtime io.containerd.kata.v2 alpine:3.19 uname -a | tee "${LAB}/setup/kata-test-uname.txt"

echo "[lab12] Task 2: runc juice shop (detached)"
sudo nerdctl rm -f juice-runc >/dev/null 2>&1 || true
sudo nerdctl run -d --name juice-runc -p 3012:3000 bkimminich/juice-shop:v19.0.0
sleep 10
curl -s -o /dev/null -w "juice-runc: HTTP %{http_code}\n" http://localhost:3012 | tee "${LAB}/runc/health.txt"

echo "[lab12] Task 2: kata alpine tests"
sudo nerdctl run --rm --runtime io.containerd.kata.v2 alpine:3.19 uname -a | tee "${LAB}/kata/test1.txt"
sudo nerdctl run --rm --runtime io.containerd.kata.v2 alpine:3.19 uname -r | tee "${LAB}/kata/kernel.txt"
sudo nerdctl run --rm --runtime io.containerd.kata.v2 alpine:3.19 sh -c "grep 'model name' /proc/cpuinfo | head -1" | tee "${LAB}/kata/cpu.txt"

echo "=== Kernel Version Comparison ===" | tee "${LAB}/analysis/kernel-comparison.txt"
echo -n "Host kernel (runc uses this): " | tee -a "${LAB}/analysis/kernel-comparison.txt"
uname -r | tee -a "${LAB}/analysis/kernel-comparison.txt"
echo -n "Kata guest kernel: " | tee -a "${LAB}/analysis/kernel-comparison.txt"
sudo nerdctl run --rm --runtime io.containerd.kata.v2 alpine:3.19 cat /proc/version | tee -a "${LAB}/analysis/kernel-comparison.txt"

echo "=== CPU Model Comparison ===" | tee "${LAB}/analysis/cpu-comparison.txt"
echo "Host CPU:" | tee -a "${LAB}/analysis/cpu-comparison.txt"
grep "model name" /proc/cpuinfo | head -1 | tee -a "${LAB}/analysis/cpu-comparison.txt"
echo "Kata VM CPU:" | tee -a "${LAB}/analysis/cpu-comparison.txt"
sudo nerdctl run --rm --runtime io.containerd.kata.v2 alpine:3.19 sh -c "grep 'model name' /proc/cpuinfo | head -1" | tee -a "${LAB}/analysis/cpu-comparison.txt"

echo "[lab12] Task 3: isolation tests"
echo "=== dmesg Access Test ===" | tee "${LAB}/isolation/dmesg.txt"
echo "Kata VM (separate kernel boot logs):" | tee -a "${LAB}/isolation/dmesg.txt"
sudo nerdctl run --rm --runtime io.containerd.kata.v2 alpine:3.19 dmesg 2>&1 | head -5 | tee -a "${LAB}/isolation/dmesg.txt"

echo "=== /proc Entries Count ===" | tee "${LAB}/isolation/proc.txt"
echo -n "Host: " | tee -a "${LAB}/isolation/proc.txt"
ls /proc | wc -l | tee -a "${LAB}/isolation/proc.txt"
echo -n "Kata VM: " | tee -a "${LAB}/isolation/proc.txt"
sudo nerdctl run --rm --runtime io.containerd.kata.v2 alpine:3.19 sh -c "ls /proc | wc -l" | tee -a "${LAB}/isolation/proc.txt"

echo "=== Network Interfaces ===" | tee "${LAB}/isolation/network.txt"
echo "Kata VM network:" | tee -a "${LAB}/isolation/network.txt"
sudo nerdctl run --rm --runtime io.containerd.kata.v2 alpine:3.19 ip addr | tee -a "${LAB}/isolation/network.txt"

echo "=== Kernel Modules Count ===" | tee "${LAB}/isolation/modules.txt"
echo -n "Host kernel modules: " | tee -a "${LAB}/isolation/modules.txt"
ls /sys/module | wc -l | tee -a "${LAB}/isolation/modules.txt"
echo -n "Kata guest kernel modules: " | tee -a "${LAB}/isolation/modules.txt"
sudo nerdctl run --rm --runtime io.containerd.kata.v2 alpine:3.19 sh -c "ls /sys/module 2>/dev/null | wc -l" | tee -a "${LAB}/isolation/modules.txt"

echo "[lab12] Task 4: performance snapshot"
echo "=== Startup Time Comparison ===" | tee "${LAB}/bench/startup.txt"
echo "runc:" | tee -a "${LAB}/bench/startup.txt"
time sudo nerdctl run --rm alpine:3.19 echo "test" 2>&1 | grep real | tee -a "${LAB}/bench/startup.txt"
echo "Kata:" | tee -a "${LAB}/bench/startup.txt"
time sudo nerdctl run --rm --runtime io.containerd.kata.v2 alpine:3.19 echo "test" 2>&1 | grep real | tee -a "${LAB}/bench/startup.txt"

echo "=== HTTP Latency Test (juice-runc) ===" | tee "${LAB}/bench/http-latency.txt"
out="${LAB}/bench/curl-3012.txt"
: > "${out}"
for i in $(seq 1 50); do
  curl -s -o /dev/null -w "%{time_total}\n" http://localhost:3012/ >> "${out}"
done
min=$(sort -n "${out}" | head -1)
max=$(sort -n "${out}" | tail -1)
awk -v min="${min}" -v max="${max}" '{s+=$1; n+=1} END {if(n>0) printf "avg=%.4fs min=%.4fs max=%.4fs n=%d\n", s/n, min, max, n}' \
  "${out}" | tee -a "${LAB}/bench/http-latency.txt"

echo "[lab12] Done. Populate labs/submission12.md using the generated files under labs/lab12/."

